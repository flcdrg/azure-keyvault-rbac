#Requires -Version 7.0
<#
.SYNOPSIS
    Validate Azure and GitHub setup configuration.

.DESCRIPTION
    Performs comprehensive checks on your Azure and GitHub setup:
    - Azure CLI authentication and subscription
    - GitHub CLI authentication and repository access
    - Service principals and federated credentials
    - GitHub repository secrets
    - Bicep template validity
    - Resource group and resources

.EXAMPLE
    .\Validate-Setup.ps1
    Runs all validation checks.

.EXAMPLE
    .\Validate-Setup.ps1 -ResourceGroupName "rg-myapp-dev"
    Validates specific resource group.
#>

param(
    [string]$ResourceGroupName
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

function Write-CheckResult {
    param([string]$Text, [bool]$Pass, [string]$Detail)

    $icon = if ($Pass) { "✓" } else { "✗" }
    $color = if ($Pass) { "Green" } else { "Red" }

    Write-Host "  $icon $Text" -ForegroundColor $color -NoNewline

    if ($Detail) {
        Write-Host " ($Detail)" -ForegroundColor Gray
    }
    else {
        Write-Host ""
    }

    return $Pass
}

function Write-Info {
    param([string]$Text)
    Write-Host "ℹ $Text" -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Text)
    Write-Host "⚠ $Text" -ForegroundColor Yellow
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

function Test-CommandExists {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Validate-Prerequisites {
    Write-Host ""
    Write-Info "Checking Prerequisites..."

    $allPass = $true

    $allPass = (Write-CheckResult "Azure CLI installed" (Test-CommandExists 'az')) -and $allPass
    $allPass = (Write-CheckResult "Git installed" (Test-CommandExists 'git')) -and $allPass

    $ghExists = Test-CommandExists 'gh'
    Write-CheckResult "GitHub CLI installed" $ghExists "(optional)"

    return $allPass
}

function Validate-AzureAuth {
    Write-Host ""
    Write-Info "Validating Azure Authentication..."

    try {
        $account = & az account show --output json | ConvertFrom-Json
        Write-CheckResult "Azure login" $true $($account.user.name)

        $subId = $account.id
        $tenantId = $account.tenantId

        Write-Host "    Subscription: $subId" -ForegroundColor Gray
        Write-Host "    Tenant: $tenantId" -ForegroundColor Gray

        return $true
    }
    catch {
        Write-CheckResult "Azure login" $false "Run 'az login'"
        return $false
    }
}

function Validate-GitHubAuth {
    Write-Host ""
    Write-Info "Validating GitHub Authentication..."

    if (-not (Test-CommandExists 'gh')) {
        Write-CheckResult "GitHub CLI installed" $false "(optional)"
        return $false
    }

    try {
        $user = & gh auth status 2>&1
        if ($user -match "Logged in") {
            Write-CheckResult "GitHub login" $true
            return $true
        }
        else {
            Write-CheckResult "GitHub login" $false "Run 'gh auth login'"
            return $false
        }
    }
    catch {
        Write-CheckResult "GitHub login" $false "Run 'gh auth login'"
        return $false
    }
}

function Validate-GitHubRepo {
    Write-Host ""
    Write-Info "Validating GitHub Repository..."

    try {
        $gitRemote = & git config --get remote.origin.url 2>$null
        if (-not $gitRemote) {
            Write-CheckResult "Git repository" $false "Not in a Git repo"
            return $false
        }

        Write-CheckResult "Git remote" $true $gitRemote

        if ($gitRemote -match 'github\.com[:/]([^/]+)/(.+?)(?:\.git)?$') {
            $org = $matches[1]
            $repo = $matches[2] -replace '\.git$', ''

            if (Test-CommandExists 'gh') {
                try {
                    $repoInfo = & gh repo view $org/$repo --json nameWithOwner --jq '.nameWithOwner' 2>$null
                    Write-CheckResult "GitHub repository access" $true "$org/$repo"
                    return $true
                }
                catch {
                    Write-CheckResult "GitHub repository access" $false "Cannot access $org/$repo"
                    return $false
                }
            }
            else {
                Write-CheckResult "GitHub repository" $true "$org/$repo (not verified)"
                return $true
            }
        }
        else {
            Write-CheckResult "GitHub repository" $false "Could not parse remote URL"
            return $false
        }
    }
    catch {
        Write-CheckResult "Git repository" $false $_
        return $false
    }
}

function Validate-ServicePrincipal {
    param([string]$ClientId)

    Write-Host ""
    Write-Info "Validating Service Principal..."

    if (-not $ClientId) {
        Write-Warning "No client ID provided, skipping service principal check"
        return $false
    }

    try {
        $sp = & az ad sp show --id $ClientId --output json | ConvertFrom-Json
        Write-CheckResult "Service Principal exists" $true $($sp.displayName)

        # Check role assignments
        $roles = & az role assignment list --assignee $ClientId --output json | ConvertFrom-Json
        if ($roles.Count -gt 0) {
            Write-CheckResult "Role assignments" $true "$($roles.Count) role(s)"
            $roles | ForEach-Object {
                Write-Host "      - $($_.roleDefinitionName)" -ForegroundColor Gray
            }
        }
        else {
            Write-CheckResult "Role assignments" $false "No roles assigned"
            return $false
        }

        # Check federated credentials
        $creds = & az ad app federated-credential list --id $ClientId --output json 2>/dev/null | ConvertFrom-Json
        if ($creds.Count -gt 0) {
            Write-CheckResult "Federated credentials" $true "$($creds.Count) credential(s)"
            $creds | ForEach-Object {
                Write-Host "      - $($_.name)" -ForegroundColor Gray
            }
        }
        else {
            Write-CheckResult "Federated credentials" $false "No credentials configured"
            return $false
        }

        return $true
    }
    catch {
        Write-CheckResult "Service Principal" $false $_
        return $false
    }
}

function Validate-GitHubSecrets {
    param([string]$Org, [string]$Repo)

    Write-Host ""
    Write-Info "Validating GitHub Secrets..."

    if (-not (Test-CommandExists 'gh')) {
        Write-Warning "GitHub CLI not available, skipping secret check"
        return $false
    }

    if (-not $Org -or -not $Repo) {
        Write-Warning "GitHub org/repo not provided"
        return $false
    }

    try {
        $secrets = & gh secret list --repo $Org/$Repo --json name --jq '.[].name' 2>$null
        $secretArray = @($secrets) | Where-Object { $_ }

        $required = @('AZURE_TENANT_ID', 'AZURE_CLIENT_ID', 'AZURE_SUBSCRIPTION_ID', 'RESOURCE_GROUP_NAME')

        Write-CheckResult "GitHub repository secrets" $($secretArray.Count -ge 4) "$($secretArray.Count) secret(s)"

        foreach ($secret in $required) {
            $exists = $secretArray -contains $secret
            Write-CheckResult "  Secret: $secret" $exists
        }

        return ($secretArray.Count -ge 4)
    }
    catch {
        Write-CheckResult "GitHub secrets" $false $_
        return $false
    }
}

function Validate-ResourceGroup {
    param([string]$Name)

    Write-Host ""
    Write-Info "Validating Azure Resource Group..."

    if (-not $Name) {
        Write-Warning "No resource group name provided, skipping"
        return $false
    }

    try {
        $exists = & az group exists --name $Name
        if ($exists -ne 'true') {
            Write-CheckResult "Resource group exists" $false $Name
            return $false
        }

        Write-CheckResult "Resource group exists" $true $Name

        # Get resource group details
        $rg = & az group show --name $Name --output json | ConvertFrom-Json
        Write-Host "    Location: $($rg.location)" -ForegroundColor Gray

        # List resources
        $resources = & az resource list --resource-group $Name --output json | ConvertFrom-Json
        Write-CheckResult "Resources" $($resources.Count -gt 0) "$($resources.Count) resource(s)"

        return $true
    }
    catch {
        Write-CheckResult "Resource group" $false $_
        return $false
    }
}

function Validate-BicepTemplate {
    Write-Host ""
    Write-Info "Validating Bicep Templates..."

    $bicepFile = Join-Path (Get-Location) "infra" "main.bicep"

    if (-not (Test-Path $bicepFile)) {
        Write-CheckResult "Bicep template exists" $false "infra/main.bicep not found"
        return $false
    }

    Write-CheckResult "Bicep template exists" $true "infra/main.bicep"

    try {
        $output = & az bicep build --file $bicepFile --outdir ([System.IO.Path]::GetTempPath()) 2>&1
        Write-CheckResult "Bicep syntax valid" $true

        # Check parameters
        $paramFile = Join-Path (Get-Location) "infra" "main.bicepparam"
        if (Test-Path $paramFile) {
            Write-CheckResult "Bicep parameters exist" $true "main.bicepparam"
        }
        else {
            Write-CheckResult "Bicep parameters exist" $false "main.bicepparam not found"
        }

        return $true
    }
    catch {
        Write-CheckResult "Bicep validation" $false $_
        return $false
    }
}

function Validate-LocalConfig {
    Write-Host ""
    Write-Info "Validating Local Configuration..."

    $configFile = Join-Path (Get-Location) ".env.setup.local"

    if (Test-Path $configFile) {
        Write-CheckResult "Local config exists" $true ".env.setup.local"

        $config = @{}
        Get-Content $configFile | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                $config[$matches[1]] = $matches[2]
            }
        }

        $required = @('AZURE_SUBSCRIPTION_ID', 'AZURE_TENANT_ID', 'AZURE_CLIENT_ID', 'RESOURCE_GROUP_NAME')
        foreach ($key in $required) {
            $hasKey = $config.ContainsKey($key)
            $value = if ($hasKey) { $config[$key].Substring(0, [Math]::Min(20, $config[$key].Length)) + "..." } else { "" }
            Write-CheckResult "  $key" $hasKey $value
        }

        # Warn if in git
        if ((& git ls-files $configFile 2>$null)) {
            Write-Warning ".env.setup.local is tracked by Git! Remove it from git tracking."
        }
        else {
            Write-CheckResult "  Not in Git" $true "(gitignored)"
        }

        return $true
    }
    else {
        Write-CheckResult "Local config exists" $false "Run Setup-AzureGitHubOIDC.ps1"
        return $false
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Main {
    Write-Header "Azure Setup Validation"

    $allPass = $true

    # Prerequisites
    $allPass = (Validate-Prerequisites) -and $allPass

    # Azure
    $azurePass = Validate-AzureAuth
    $allPass = $azurePass -and $allPass

    # GitHub
    Validate-GitHubAuth | Out-Null
    $gitHubRepoPass = Validate-GitHubRepo
    $allPass = $gitHubRepoPass -and $allPass

    # Extract org/repo for later checks
    $gitRemote = & git config --get remote.origin.url 2>$null
    $org = $null
    $repo = $null
    if ($gitRemote -match 'github\.com[:/]([^/]+)/(.+?)(?:\.git)?$') {
        $org = $matches[1]
        $repo = $matches[2] -replace '\.git$', ''
    }

    # Load config if available
    $config = @{}
    $configFile = Join-Path (Get-Location) ".env.setup.local"
    if (Test-Path $configFile) {
        Get-Content $configFile | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                $config[$matches[1]] = $matches[2]
            }
        }
    }

    $clientId = if ($config.ContainsKey('AZURE_CLIENT_ID')) { $config['AZURE_CLIENT_ID'] } else { $null }
    $rg = if ($ResourceGroupName) { $ResourceGroupName } elseif ($config.ContainsKey('RESOURCE_GROUP_NAME')) { $config['RESOURCE_GROUP_NAME'] } else { $null }

    # Service Principal
    if ($clientId -and $azurePass) {
        Validate-ServicePrincipal -ClientId $clientId | Out-Null
    }

    # GitHub Secrets
    if ($org -and $repo) {
        Validate-GitHubSecrets -Org $org -Repo $repo | Out-Null
    }

    # Resource Group
    if ($rg -and $azurePass) {
        Validate-ResourceGroup -Name $rg | Out-Null
    }

    # Bicep
    Validate-BicepTemplate | Out-Null

    # Local Config
    Validate-LocalConfig | Out-Null

    # Summary
    Write-Host ""
    Write-Header "Validation Summary"

    if ($allPass) {
        Write-Host "✓ All checks passed! Your setup is ready to go." -ForegroundColor Green
        Write-Host ""
        Write-Info "Next steps:"
        Write-Host "  1. Create a test PR to validate workflows" -ForegroundColor Cyan
        Write-Host "  2. Monitor the deploy-what-if workflow" -ForegroundColor Cyan
        Write-Host "  3. Merge to main to trigger deployment" -ForegroundColor Cyan
    }
    else {
        Write-Host "⚠ Some checks failed. Please review the items above." -ForegroundColor Yellow
        Write-Host ""
        Write-Info "For help:"
        Write-Host "  - Setup Guide: docs/AZURE_SETUP.md" -ForegroundColor Cyan
        Write-Host "  - Script Help: .\scripts\README.md" -ForegroundColor Cyan
    }

    Write-Host ""
}

try {
    Main
}
catch {
    Write-Host ""
    Write-Host "✗ Validation failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
