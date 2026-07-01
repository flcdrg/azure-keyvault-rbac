#Requires -Version 7.0
<#
.SYNOPSIS
    Automated Azure setup script for GitHub Actions OIDC authentication.

.DESCRIPTION
    This script automates the Azure setup process for deploying infrastructure
    using GitHub Actions with OIDC federated credentials. It:
    - Creates or validates Azure resource groups
    - Creates service principals
    - Sets up OIDC federated credentials
    - Configures GitHub repository secrets
    - Creates GitHub environments

.PARAMETER Environment
    Deployment environment name (dev, staging, prod). Defaults to 'dev'.

.PARAMETER SkipGitHubSetup
    Skip GitHub secret and environment configuration. Default: $false.

.PARAMETER SkipBicepParameters
    Skip updating bicep parameter files. Default: $false.

.EXAMPLE
    .\Setup-AzureGitHubOIDC.ps1
    Runs the full interactive setup.

.EXAMPLE
    .\Setup-AzureGitHubOIDC.ps1 -Environment staging -SkipGitHubSetup
    Sets up Azure for staging environment, skipping GitHub setup.
#>

param(
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment = 'dev',

    [switch]$SkipGitHubSetup,

    [switch]$SkipBicepParameters
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ============================================================================
# COLORS AND FORMATTING
# ============================================================================

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $($Text.PadRight(58)) ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Text, [int]$StepNumber)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
    Write-Host "Step $StepNumber : $Text" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Text)
    Write-Host "✓ $Text" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Text)
    Write-Host "⚠ $Text" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Text)
    Write-Host "✗ $Text" -ForegroundColor Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "ℹ $Text" -ForegroundColor Cyan
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Test-CommandExists {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Test-Prerequisites {
    Write-Header "Checking Prerequisites"

    $missing = @()

    if (-not (Test-CommandExists 'az')) {
        $missing += 'Azure CLI (az)'
    }
    if (-not (Test-CommandExists 'git')) {
        $missing += 'Git'
    }
    if (-not (Test-CommandExists 'gh')) {
        Write-Warning "GitHub CLI (gh) not found - will prompt for GitHub setup instead"
    }

    if ($missing.Count -gt 0) {
        Write-Error "Missing required tools:"
        $missing | ForEach-Object { Write-Error "  - $_" }
        Write-Info "Install: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    }

    Write-Success "All required tools are installed"
}

function Get-GitHubInfo {
    param([hashtable]$LoadedConfig)
    
    Write-Header "Gathering GitHub Repository Information"

    $gitRemote = & git config --get remote.origin.url 2>$null
    if (-not $gitRemote) {
        Write-Error "Not in a Git repository. Please run this script from the repository root."
        exit 1
    }

    # Parse GitHub org and repo from git remote URL
    # Supports: https://github.com/org/repo.git or git@github.com:org/repo.git
    if ($gitRemote -match 'github\.com[:/]([^/]+)/(.+?)(?:\.git)?$') {
        $org = $matches[1]
        $repo = $matches[2] -replace '\.git$', ''
        
        # Override with loaded config if available
        if ($LoadedConfig -and $LoadedConfig['GITHUB_ORG']) {
            $org = $LoadedConfig['GITHUB_ORG']
        }
        if ($LoadedConfig -and $LoadedConfig['GITHUB_REPO']) {
            $repo = $LoadedConfig['GITHUB_REPO']
        }
        
        Write-Success "Detected GitHub: $org/$repo"
        return @{
            Organization = $org
            Repository   = $repo
            RemoteUrl    = $gitRemote
        }
    }

    Write-Error "Could not parse GitHub organization/repo from remote URL: $gitRemote"
    exit 1
}

function Get-CurrentUser {
    Write-Info "Detecting current Azure user..."
    $account = & az account show --output json | ConvertFrom-Json
    Write-Success "Logged in as: $($account.user.name) ($($account.user.type))"
    return $account
}

function Read-Input {
    param(
        [string]$Prompt,
        [string]$DefaultValue = '',
        [string]$Description = '',
        [switch]$Secret = $false,
        [string[]]$ValidateSet = @(),
        [scriptblock]$Validate = $null
    )

    $displayDefault = if ($DefaultValue) { " [$DefaultValue]" } else { "" }
    $descText = if ($Description) { "`n  $Description`n" } else { "" }

    if ($ValidateSet.Count -gt 0) {
        Write-Host ""
        Write-Host "  $Prompt$descText" -NoNewline
        Write-Host "Options: $($ValidateSet -join ', ')" -ForegroundColor Gray
        do {
            $userInput = Read-Host "  Enter choice$displayDefault"
            $userInput = if ([string]::IsNullOrWhiteSpace($userInput)) { $DefaultValue } else { $userInput }
            if ($userInput -notin $ValidateSet) {
                Write-Warning "Invalid selection. Choose from: $($ValidateSet -join ', ')"
            }
        } while ($userInput -notin $ValidateSet)
        return $userInput
    }

    Write-Host ""
    Write-Host "  $Prompt$descText" -NoNewline

    if ($Secret) {
        $userInput = Read-Host -AsSecureString
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($userInput))
    }
    else {
        $promptText = $Prompt + $displayDefault
        $userInput = Read-Host -Prompt $promptText
        $userInput = if ([string]::IsNullOrWhiteSpace($userInput)) { $DefaultValue } else { $userInput }

        # Only validate non-empty values or if a value was explicitly entered
        if ($Validate -and -not [string]::IsNullOrWhiteSpace($userInput)) {
            $validationResult = $Validate.Invoke($userInput)
            if (-not $validationResult) {
                Write-Error "Invalid input. Please try again."
                return Read-Input -Prompt $Prompt -DefaultValue $DefaultValue -Description $Description -Validate $Validate
            }
        }

        return $userInput
    }
}

# ============================================================================
# AZURE SETUP FUNCTIONS
# ============================================================================

function Get-AzureInfo {
    param([hashtable]$LoadedConfig)
    
    Write-Step "Azure Account Information" 1

    Write-Info "Fetching your Azure account details..."
    $account = & az account show --output json | ConvertFrom-Json

    $subscriptionId = $account.id
    $tenantId = $account.tenantId
    
    # Override with loaded config if available
    if ($LoadedConfig -and $LoadedConfig['AZURE_SUBSCRIPTION_ID']) {
        $subscriptionId = $LoadedConfig['AZURE_SUBSCRIPTION_ID']
    }
    if ($LoadedConfig -and $LoadedConfig['AZURE_TENANT_ID']) {
        $tenantId = $LoadedConfig['AZURE_TENANT_ID']
    }

    Write-Success "Subscription ID: $subscriptionId"
    Write-Success "Tenant ID: $tenantId"

    return @{
        SubscriptionId = $subscriptionId
        TenantId       = $tenantId
    }
}

function Get-AzureSettings {
    param([hashtable]$LoadedConfig)
    
    Write-Step "Azure Configuration" 2

    $defaultRegion = "australiaeast"
    if ($LoadedConfig -and $LoadedConfig['AZURE_REGION']) {
        $defaultRegion = $LoadedConfig['AZURE_REGION']
    }

    $region = Read-Input `
        -Prompt "Azure Region" `
        -DefaultValue $defaultRegion `
        -Description "Region for resource deployment (e.g., eastus, westus2, northeurope)"

    $defaultRG = "rg-$($global:AppName)-$Environment"
    if ($LoadedConfig -and $LoadedConfig['RESOURCE_GROUP_NAME']) {
        $defaultRG = $LoadedConfig['RESOURCE_GROUP_NAME']
    }

    $resourceGroupName = Read-Input `
        -Prompt "Resource Group Name" `
        -DefaultValue $defaultRG `
        -Description "Azure resource group for all resources"

    return @{
        Region               = $region
        ResourceGroupName    = $resourceGroupName
    }
}

function Get-ApplicationSettings {
    param([hashtable]$LoadedConfig)
    
    Write-Step "Application Settings" 3

    $defaultAppName = "myapp"
    if ($LoadedConfig -and $LoadedConfig['APP_NAME']) {
        $defaultAppName = $LoadedConfig['APP_NAME']
    }

    $appName = Read-Input `
        -Prompt "Application Name" `
        -DefaultValue $defaultAppName `
        -Description "Used in naming conventions for Azure resources (lowercase letters, numbers, hyphens)" `
        -Validate { param($val) if ($val -match '^[a-z][a-z0-9-]*[a-z0-9]$|^[a-z]$') { $true } else { $false } }

    $defaultOrgPrefix = ""
    if ($LoadedConfig -and $LoadedConfig['ORG_PREFIX']) {
        $defaultOrgPrefix = $LoadedConfig['ORG_PREFIX']
    }

    $orgPrefix = Read-Input `
        -Prompt "Organization Prefix" `
        -DefaultValue $defaultOrgPrefix `
        -Description "Prefix for resource naming (2-5 lowercase letters, optional)" `
        -Validate { param($val) if ($val -match '^$|^[a-z]{2,5}$') { $true } else { $false } }

    $global:AppName = $appName

    return @{
        AppName    = $appName
        OrgPrefix  = $orgPrefix
    }
}

function New-ResourceGroup {
    param(
        [string]$Name,
        [string]$Location
    )

    Write-Step "Creating Resource Group" 4

    Write-Info "Checking if resource group '$Name' exists..."
    $existing = & az group exists --name $Name

    if ($existing -eq 'true') {
        Write-Success "Resource group already exists: $Name"
        return
    }

    Write-Info "Creating resource group in $Location..."
    & az group create `
        --name $Name `
        --location $Location `
        --output none

    Write-Success "Resource group created: $Name"
}

function New-ServicePrincipal {
    param(
        [string]$AppName,
        [string]$Environment,
        [string]$SubscriptionId,
        [string]$ResourceGroupName
    )

    Write-Step "Creating Service Principal" 5

    $spName = "sp-github-$AppName-$Environment"
    $scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"

    Write-Info "Creating service principal: $spName"
    Write-Info "  Scope: $scope"

    $sp = & az ad sp create-for-rbac `
        --name $spName `
        --role Contributor `
        --scopes $scope `
        --output json | ConvertFrom-Json

    Write-Success "Service Principal created"
    Write-Success "  App ID: $($sp.appId)"
    Write-Success "  Name: $($sp.displayName)"

    # Assign Role Based Access Control Administrator role for federated credential management
    Write-Info "Assigning RBAC Administrator role..."
    & az role assignment create `
        --assignee $sp.appId `
        --role "Role Based Access Control Administrator" `
        --scope $scope `
        --output none

    Write-Success "RBAC Administrator role assigned"

    return @{
        AppId           = $sp.appId
        DisplayName     = $sp.displayName
        TenantId        = $sp.tenant
    }
}

function New-FederatedCredentials {
    param(
        [string]$ClientId,
        [string]$GitHubOrg,
        [string]$GitHubRepo
    )

    Write-Step "Creating OIDC Federated Credentials" 6

    $credentials = @(
        @{
            name        = "GitHub-Deployments-Main"
            description = "GitHub Actions deployment from main branch"
            subject     = "repo:$GitHubOrg/$GitHubRepo`:ref:refs/heads/main"
        },
        @{
            name        = "GitHub-PRs"
            description = "GitHub Actions validation for pull requests"
            subject     = "repo:$GitHubOrg/$GitHubRepo`:pull_request"
        },
        @{
            name        = "GitHub-$Environment-Environment"
            description = "GitHub Actions deployments to $Environment environment"
            subject     = "repo:$GitHubOrg/$GitHubRepo`:environment:$Environment"
        }
    )

    $created = @()

    foreach ($cred in $credentials) {
        Write-Info "Creating federated credential: $($cred.name)"

        $fedCred = @{
            name      = $cred.name
            issuer    = "https://token.actions.githubusercontent.com"
            subject   = $cred.subject
            audiences = @("api://AzureADTokenExchange")
            description = $cred.description
        } | ConvertTo-Json

        try {
            $fedCred | & az ad app federated-credential create `
                --id $ClientId `
                --parameters "@-" `
                --output none 2>&1 | Where-Object { $_ -notmatch 'Federated credential|-->' }

            Write-Success "  Created: $($cred.name)"
            $created += $cred.name
        }
        catch {
            if ($_ -match 'already exists') {
                Write-Warning "  Already exists: $($cred.name)"
            }
            else {
                throw $_
            }
        }
    }

    if ($created.Count -gt 0) {
        Write-Success "Federated credentials configured ($($created.Count) created)"
    }
}

# ============================================================================
# GITHUB SETUP FUNCTIONS
# ============================================================================

function Test-GitHubCLI {
    return (Test-CommandExists 'gh')
}

function Get-GitHubStatus {
    param([string]$Org, [string]$Repo)

    Write-Info "Checking GitHub authentication and repository access..."

    try {
        $repoInfo = & gh repo view $Org/$Repo --json nameWithOwner --jq '.nameWithOwner' 2>$null
        if ($repoInfo -match $Repo) {
            Write-Success "GitHub repository access confirmed"
            return $true
        }
    }
    catch {
        return $false
    }

    return $false
}

function New-GitHubSecrets {
    param(
        [hashtable]$Secrets,
        [string]$Org,
        [string]$Repo
    )

    Write-Step "Configuring GitHub Secrets" 7

    if (-not (Test-GitHubCLI)) {
        Write-Warning "GitHub CLI not available. Please set secrets manually:"
        Write-Info "Go to: https://github.com/$Org/$Repo/settings/secrets/actions"
        foreach ($key in $Secrets.Keys) {
            Write-Info "  $key = $($Secrets[$key])"
        }
        return
    }

    if (-not (Get-GitHubStatus -Org $Org -Repo $Repo)) {
        Write-Warning "GitHub CLI authentication failed. Please set secrets manually:"
        Write-Info "Go to: https://github.com/$Org/$Repo/settings/secrets/actions"
        foreach ($key in $Secrets.Keys) {
            Write-Info "  $key = $($Secrets[$key])"
        }
        return
    }

    foreach ($key in $Secrets.Keys) {
        Write-Info "Setting secret: $key to $($Secrets[$key])"
        & gh secret set $key --repo $Org/$Repo --body $Secrets[$key] 2>&1 | Where-Object { $_ -notmatch '✓ Set secret' } | ForEach-Object {
            if ($_ -and $_ -notmatch '^$') { Write-Info "  $_" }
        }
        Write-Success "  Configured: $key"
    }

    Write-Success "GitHub secrets configured"
}

function New-GitHubEnvironment {
    param(
        [string]$EnvironmentName,
        [string]$Org,
        [string]$Repo
    )

    Write-Info "Setting up GitHub environment: $EnvironmentName"

    if (-not (Test-GitHubCLI)) {
        Write-Warning "GitHub CLI not available. Create environment manually:"
        Write-Info "Go to: https://github.com/$Org/$Repo/settings/environments/new"
        Write-Info "Name: $EnvironmentName"
        return
    }

    try {
        # GitHub CLI doesn't have direct environment creation, but we can check if it exists
        $environments = & gh api repos/$Org/$Repo/environments --jq '.[].name' 2>$null
        if ($environments -contains $EnvironmentName) {
            Write-Success "Environment exists: $EnvironmentName"
            return
        }

        Write-Warning "Please create environment manually:"
        Write-Info "Go to: https://github.com/$Org/$Repo/settings/environments/new"
        Write-Info "Name: $EnvironmentName"
    }
    catch {
        Write-Warning "Could not verify GitHub environment. Create manually:"
        Write-Info "Go to: https://github.com/$Org/$Repo/settings/environments/new"
        Write-Info "Name: $EnvironmentName"
    }
}

# ============================================================================
# BICEP PARAMETER UPDATE
# ============================================================================

function Update-BicepParameters {
    param(
        [string]$ProjectName,
        [AllowNull()]
        [AllowEmptyString()]
        [string]$OrgPrefix,
        [string]$Location,
        [string]$Environment
    )

    if ($SkipBicepParameters) {
        Write-Info "Skipping bicep parameter update"
        return
    }

    Write-Step "Updating Bicep Parameters" 8

    $paramFile = if ($Environment -eq 'dev') {
        Join-Path (Get-Location) "infra" "main.bicepparam"
    }
    else {
        Join-Path (Get-Location) "infra" "main.bicepparam.$Environment"
    }

    if (-not (Test-Path $paramFile)) {
        Write-Warning "Parameter file not found: $paramFile"
        $createNew = Read-Input `
            -Prompt "Create new parameter file?" `
            -DefaultValue "Y" `
            -ValidateSet @('Y', 'N')

        if ($createNew -ne 'Y') {
            return
        }

        # Copy from dev if it exists
        $devFile = Join-Path (Get-Location) "infra" "main.bicepparam"
        if (Test-Path $devFile) {
            Copy-Item $devFile $paramFile
            Write-Success "Created from dev template: $paramFile"
        }
        else {
            Write-Warning "Dev parameter file not found either"
            return
        }
    }

    Write-Info "Updating parameter file: $paramFile"

    $content = Get-Content $paramFile -Raw

    # Update parameters using string replacement (simple approach for bicepparam files)
    $content = $content -replace "param location = '[^']*'", "param location = '$Location'"
    $content = $content -replace "param environment = '[^']*'", "param environment = '$Environment'"
    $content = $content -replace "param projectName = '[^']*'", "param projectName = '$ProjectName'"
    if ($OrgPrefix) {
        $content = $content -replace "param orgPrefix = '[^']*'", "param orgPrefix = '$OrgPrefix'"
    }

    Set-Content $paramFile $content -Encoding UTF8 -NoNewline

    Write-Success "Parameter file updated: $paramFile"
}

# ============================================================================
# VALIDATION AND TESTING
# ============================================================================

function Test-Bicep {
    Write-Step "Validating Bicep Templates" 9

    $bicepFile = Join-Path (Get-Location) "infra" "main.bicep"

    if (-not (Test-Path $bicepFile)) {
        Write-Warning "Bicep file not found: $bicepFile"
        return $false
    }

    Write-Info "Building Bicep template: $bicepFile"
    try {
        $output = & az bicep build --file $bicepFile --outdir ([System.IO.Path]::GetTempPath()) 2>&1
        Write-Success "Bicep template is valid"
        return $true
    }
    catch {
        Write-Error "Bicep validation failed: $_"
        return $false
    }
}

function Test-Deployment {
    param(
        [string]$ResourceGroupName,
        [string]$TemplateFile,
        [string]$ParameterFile
    )

    Write-Step "Validating Deployment" 10

    Write-Info "Validating deployment configuration..."
    try {
        & az deployment group validate `
            --resource-group $ResourceGroupName `
            --template-file $TemplateFile `
            --parameters $ParameterFile `
            --output none

        Write-Success "Deployment validation successful"
        return $true
    }
    catch {
        Write-Error "Deployment validation failed: $_"
        return $false
    }
}

# ============================================================================
# SUMMARY AND OUTPUT
# ============================================================================

function Write-Summary {
    param(
        [hashtable]$Config
    )

    Write-Header "Setup Summary"

    Write-Info "Azure Configuration:"
    Write-Host "  Subscription ID: $($Config.SubscriptionId)" -ForegroundColor Gray
    Write-Host "  Tenant ID: $($Config.TenantId)" -ForegroundColor Gray
    Write-Host "  Region: $($Config.Region)" -ForegroundColor Gray
    Write-Host "  Resource Group: $($Config.ResourceGroupName)" -ForegroundColor Gray

    Write-Info "Service Principal:"
    Write-Host "  App ID: $($Config.ServicePrincipal.AppId)" -ForegroundColor Gray
    Write-Host "  Name: $($Config.ServicePrincipal.DisplayName)" -ForegroundColor Gray

    Write-Info "GitHub Configuration:"
    Write-Host "  Organization: $($Config.GitHub.Organization)" -ForegroundColor Gray
    Write-Host "  Repository: $($Config.GitHub.Repository)" -ForegroundColor Gray
    Write-Host "  Environment: $Environment" -ForegroundColor Gray

    Write-Info "Application Settings:"
    Write-Host "  App Name: $($Config.App.AppName)" -ForegroundColor Gray
    Write-Host "  Org Prefix: $($Config.App.OrgPrefix)" -ForegroundColor Gray

    Write-Host ""
}

function Save-Configuration {
    param([hashtable]$Config)

    $configPath = Join-Path (Get-Location) ".env.setup.local"

    $content = @"
# Azure Setup Configuration - DO NOT COMMIT TO GIT
# Generated: $(Get-Date -Format 'o')

AZURE_SUBSCRIPTION_ID=$($Config.SubscriptionId)
AZURE_TENANT_ID=$($Config.TenantId)
AZURE_CLIENT_ID=$($Config.ServicePrincipal.AppId)
AZURE_REGION=$($Config.Region)
RESOURCE_GROUP_NAME=$($Config.ResourceGroupName)

# Application
APP_NAME=$($Config.App.AppName)
ORG_PREFIX=$($Config.App.OrgPrefix)
ENVIRONMENT=$Environment

# GitHub
GITHUB_ORG=$($Config.GitHub.Organization)
GITHUB_REPO=$($Config.GitHub.Repository)
"@

    Set-Content $configPath $content -Encoding UTF8
    Write-Success "Configuration saved to: $configPath"
    Write-Info "Add to .gitignore to prevent accidental commits"
}

function Load-Configuration {
    $configPath = Join-Path (Get-Location) ".env.setup.local"

    if (-not (Test-Path $configPath)) {
        return $null
    }

    Write-Info "Loading configuration from: $configPath"

    $config = @{}
    Get-Content $configPath | ForEach-Object {
        if ($_ -match '^([^=#]+)=(.*)$' -and -not $_.StartsWith('#')) {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $config[$key] = $value
        }
    }

    return $config
}

function Add-ToGitIgnore {
    $gitIgnorePath = Join-Path (Get-Location) ".gitignore"
    $entry = ".env.setup.local"

    if (-not (Test-Path $gitIgnorePath)) {
        # Create .gitignore if it doesn't exist
        Write-Info "Creating .gitignore"
        Set-Content $gitIgnorePath $entry -Encoding UTF8
        Write-Success "Added $entry to new .gitignore"
        return
    }

    $content = Get-Content $gitIgnorePath -Raw
    if ($content -match [regex]::Escape($entry)) {
        Write-Info "$entry already in .gitignore"
        return
    }

    # Add entry if not present
    Write-Info "Adding $entry to .gitignore"
    Add-Content $gitIgnorePath $entry -Encoding UTF8
    Write-Success "Added $entry to .gitignore"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Main {
    Write-Header "Azure GitHub Actions OIDC Setup"

    try {
        # Add to gitignore early
        Add-ToGitIgnore

        # Load existing config if available
        $loadedConfig = Load-Configuration
        if ($loadedConfig) {
            Write-Success "Loaded previous configuration"
        }

        # Prerequisites
        Test-Prerequisites

        # Gather information
        $github = Get-GitHubInfo -LoadedConfig $loadedConfig
        $azure = Get-AzureInfo -LoadedConfig $loadedConfig
        $azureSettings = Get-AzureSettings -LoadedConfig $loadedConfig
        $appSettings = Get-ApplicationSettings -LoadedConfig $loadedConfig

        # Create Azure resources
        New-ResourceGroup -Name $azureSettings.ResourceGroupName -Location $azureSettings.Region
        $sp = New-ServicePrincipal `
            -AppName $appSettings.AppName `
            -Environment $Environment `
            -SubscriptionId $azure.SubscriptionId `
            -ResourceGroupName $azureSettings.ResourceGroupName

        New-FederatedCredentials `
            -ClientId $sp.AppId `
            -GitHubOrg $github.Organization `
            -GitHubRepo $github.Repository

        # GitHub setup
        if (-not $SkipGitHubSetup) {
            $secrets = @{
                AZURE_TENANT_ID       = $azure.TenantId
                AZURE_CLIENT_ID       = $sp.AppId
                AZURE_SUBSCRIPTION_ID = $azure.SubscriptionId
                RESOURCE_GROUP_NAME   = $azureSettings.ResourceGroupName
            }

            New-GitHubSecrets `
                -Secrets $secrets `
                -Org $github.Organization `
                -Repo $github.Repository

            New-GitHubEnvironment `
                -EnvironmentName $Environment `
                -Org $github.Organization `
                -Repo $github.Repository
        }

        # Update bicep parameters
        Update-BicepParameters `
            -ProjectName $appSettings.AppName `
            -OrgPrefix $appSettings.OrgPrefix `
            -Location $azureSettings.Region `
            -Environment $Environment

        # Validation
        Test-Bicep | Out-Null

        $paramFile = if ($Environment -eq 'dev') {
            Join-Path (Get-Location) "infra" "main.bicepparam"
        }
        else {
            Join-Path (Get-Location) "infra" "main.bicepparam.$Environment"
        }

        if (Test-Path $paramFile) {
            Test-Deployment `
                -ResourceGroupName $azureSettings.ResourceGroupName `
                -TemplateFile (Join-Path (Get-Location) "infra" "main.bicep") `
                -ParameterFile $paramFile | Out-Null
        }

        # Save configuration
        $config = @{
            SubscriptionId   = $azure.SubscriptionId
            TenantId         = $azure.TenantId
            Region           = $azureSettings.Region
            ResourceGroupName = $azureSettings.ResourceGroupName
            ServicePrincipal = $sp
            App              = $appSettings
            GitHub           = $github
        }

        Write-Summary -Config $config
        Save-Configuration -Config $config

        Write-Header "Setup Complete! ✓"
        Write-Host ""
        Write-Info "Next steps:"
        Write-Host "  1. Verify secrets in GitHub: https://github.com/$($github.Organization)/$($github.Repository)/settings/secrets" -ForegroundColor Cyan
        Write-Host "  2. Create a test PR to validate the deploy-what-if workflow" -ForegroundColor Cyan
        Write-Host "  3. Merge PR to trigger deployment via deploy-stack workflow" -ForegroundColor Cyan
        Write-Host ""
        Write-Info "Resources:"
        Write-Host "  - Setup Guide: docs/AZURE_SETUP.md" -ForegroundColor Cyan
        Write-Host "  - Infrastructure: infra/README.md" -ForegroundColor Cyan
        Write-Host ""
    }
    catch {
        Write-Error "Setup failed: $_"
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        exit 1
    }
}

Main
