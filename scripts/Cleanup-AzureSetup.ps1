#Requires -Version 7.0
<#
.SYNOPSIS
    Clean up Azure resources created during setup.

.DESCRIPTION
    Removes all Azure resources and GitHub secrets created by the setup script:
    - Service principals
    - Federated credentials
    - Resource groups (optional)
    - GitHub repository secrets (optional)

.PARAMETER ResourceGroupName
    Name of the resource group to delete. If not provided, prompts interactively.

.PARAMETER DeleteResourceGroup
    Delete the Azure resource group and all resources. Default: interactive prompt.

.PARAMETER DeleteGitHubSecrets
    Delete GitHub repository secrets. Default: interactive prompt.

.EXAMPLE
    .\Cleanup-AzureSetup.ps1
    Runs interactive cleanup.

.EXAMPLE
    .\Cleanup-AzureSetup.ps1 -ResourceGroupName "rg-myapp-dev" -DeleteResourceGroup -DeleteGitHubSecrets
    Deletes resource group and GitHub secrets without prompting.
#>

param(
    [string]$ResourceGroupName,
    [switch]$DeleteResourceGroup,
    [switch]$DeleteGitHubSecrets
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ============================================================================
# COLORS AND FORMATTING
# ============================================================================

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║ $($Text.PadRight(58)) ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
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

function Confirm-Action {
    param([string]$Action)
    Write-Host ""
    $response = Read-Host "Do you want to $Action? (yes/no)"
    return $response -eq 'yes'
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Test-CommandExists {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Get-GitHubInfo {
    $gitRemote = & git config --get remote.origin.url 2>$null
    if (-not $gitRemote) {
        Write-Error "Not in a Git repository."
        exit 1
    }

    if ($gitRemote -match 'github\.com[:/]([^/]+)/(.+?)(?:\.git)?$') {
        return @{
            Organization = $matches[1]
            Repository   = $matches[2] -replace '\.git$', ''
        }
    }

    Write-Error "Could not parse GitHub info from remote URL"
    exit 1
}

# ============================================================================
# CLEANUP FUNCTIONS
# ============================================================================

function Get-ServicePrincipals {
    param([string]$Filter)

    Write-Info "Searching for service principals matching: $Filter"
    $sps = & az ad sp list --display-name $Filter --output json | ConvertFrom-Json

    return $sps
}

function Remove-ServicePrincipal {
    param([string]$ClientId)

    Write-Info "Deleting service principal: $ClientId"

    try {
        # First delete federated credentials
        $creds = & az ad app federated-credential list --id $ClientId --output json | ConvertFrom-Json

        foreach ($cred in $creds) {
            Write-Info "  Deleting federated credential: $($cred.name)"
            & az ad app federated-credential delete `
                --id $ClientId `
                --federated-credential-id $cred.id `
                --output none 2>$null
        }

        # Then delete the service principal
        & az ad sp delete --id $ClientId --output none

        Write-Success "Service principal deleted"
    }
    catch {
        Write-Warning "Could not fully delete service principal: $_"
    }
}

function Remove-ResourceGroup {
    param([string]$Name)

    Write-Info "Checking if resource group exists: $Name"

    $exists = & az group exists --name $Name
    if ($exists -ne 'true') {
        Write-Warning "Resource group not found: $Name"
        return
    }

    Write-Warning "This will delete the resource group and ALL resources in it!"
    Write-Info "Resources: "
    & az resource list --resource-group $Name --output table

    if (-not (Confirm-Action "delete resource group '$Name' and all its resources")) {
        Write-Info "Cancelled"
        return
    }

    Write-Info "Deleting resource group: $Name"
    & az group delete --name $Name --yes --output none

    Write-Success "Resource group deleted"
}

function Remove-GitHubSecrets {
    param([string]$Org, [string]$Repo)

    Write-Info "Retrieving GitHub secrets..."

    if (-not (Test-CommandExists 'gh')) {
        Write-Warning "GitHub CLI not available. Please delete secrets manually:"
        Write-Info "Go to: https://github.com/$Org/$Repo/settings/secrets/actions"
        return
    }

    $secrets = @('AZURE_TENANT_ID', 'AZURE_CLIENT_ID', 'AZURE_SUBSCRIPTION_ID', 'RESOURCE_GROUP_NAME')

    foreach ($secret in $secrets) {
        try {
            $exists = & gh secret list --repo $Org/$Repo | Select-String $secret
            if ($exists) {
                Write-Info "Deleting GitHub secret: $secret"
                & gh secret delete $secret --repo $Org/$Repo --force 2>$null
                Write-Success "  Deleted: $secret"
            }
        }
        catch {
            Write-Warning "  Could not delete secret: $secret"
        }
    }

    Write-Success "GitHub secrets cleanup completed"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Main {
    Write-Header "Azure Setup Cleanup"

    try {
        # Get resource group name if not provided
        if (-not $ResourceGroupName) {
            Write-Host ""
            $ResourceGroupName = Read-Host "Enter the resource group name to clean up (or press Enter to cancel)"

            if (-not $ResourceGroupName) {
                Write-Info "Cancelled"
                exit 0
            }
        }

        # Get GitHub info
        $github = Get-GitHubInfo

        # Confirm before proceeding
        Write-Host ""
        Write-Warning "This will perform the following cleanup:"
        Write-Host "  • Delete service principal: sp-github-*" -ForegroundColor Yellow
        Write-Host "  • Delete federated credentials" -ForegroundColor Yellow
        Write-Host "  • Optionally delete resource group: $ResourceGroupName" -ForegroundColor Yellow
        Write-Host "  • Optionally delete GitHub secrets" -ForegroundColor Yellow

        if (-not (Confirm-Action "proceed with cleanup")) {
            Write-Info "Cancelled"
            exit 0
        }

        # Delete service principals
        Write-Host ""
        Write-Info "Step 1: Removing Service Principals"
        $sps = Get-ServicePrincipals "sp-github-*"

        if ($sps.Count -eq 0) {
            Write-Info "No matching service principals found"
        }
        else {
            foreach ($sp in $sps) {
                Remove-ServicePrincipal -ClientId $sp.appId
            }
        }

        # Delete resource group
        Write-Host ""
        Write-Info "Step 2: Resource Group Cleanup"

        if ($DeleteResourceGroup) {
            Remove-ResourceGroup -Name $ResourceGroupName
        }
        else {
            if (Confirm-Action "delete resource group '$ResourceGroupName'") {
                Remove-ResourceGroup -Name $ResourceGroupName
            }
        }

        # Delete GitHub secrets
        Write-Host ""
        Write-Info "Step 3: GitHub Secrets Cleanup"

        if ($DeleteGitHubSecrets) {
            Remove-GitHubSecrets -Org $github.Organization -Repo $github.Repository
        }
        else {
            if (Confirm-Action "delete GitHub secrets from $($github.Organization)/$($github.Repository)") {
                Remove-GitHubSecrets -Org $github.Organization -Repo $github.Repository
            }
        }

        # Remove local config file
        Write-Host ""
        Write-Info "Step 4: Local Configuration"

        $localConfig = Join-Path (Get-Location) ".env.setup.local"
        if (Test-Path $localConfig) {
            Write-Info "Removing local configuration file: $localConfig"
            Remove-Item $localConfig -Force
            Write-Success "Local configuration removed"
        }

        Write-Header "Cleanup Complete ✓"
        Write-Host ""
        Write-Info "Additional manual steps (if needed):"
        Write-Host "  • Remove GitHub environment: https://github.com/$($github.Organization)/$($github.Repository)/settings/environments" -ForegroundColor Cyan
        Write-Host "  • Verify resource deletion in Azure Portal" -ForegroundColor Cyan
        Write-Host ""
    }
    catch {
        Write-Error "Cleanup failed: $_"
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        exit 1
    }
}

Main
