# Azure Setup Automation

Complete automation of the Azure + GitHub Actions OIDC setup process using PowerShell scripts.

## Overview

This package provides three production-ready PowerShell scripts to automate Azure infrastructure setup:

1. **Setup-AzureGitHubOIDC.ps1** - Complete interactive setup
2. **Validate-Setup.ps1** - Comprehensive validation and diagnostics
3. **Cleanup-AzureSetup.ps1** - Safe resource cleanup

All scripts include intelligent prompting, Git/GitHub inference, and comprehensive error handling.

## Quick Start

```powershell
# 1. Navigate to repository
cd path/to/azure-gh-actions-template

# 2. Run setup (interactive)
.\scripts\Setup-AzureGitHubOIDC.ps1

# 3. Verify everything is configured
.\scripts\Validate-Setup.ps1

# 4. Create test PR and merge to deploy
```

See `scripts/QUICKSTART.md` for detailed 5-minute walkthrough.

## What Each Script Does

### Setup-AzureGitHubOIDC.ps1

**Purpose**: Automated, interactive setup of Azure resources and GitHub configuration

**Key Features**:
- ✓ Automatically detects GitHub org/repo from git remote
- ✓ Retrieves Azure subscription and tenant information
- ✓ Creates resource group (or validates existing)
- ✓ Creates service principal with scoped permissions
- ✓ Sets up 3 types of OIDC federated credentials:
  - Main branch deployments
  - Pull request validation
  - Environment-specific deployments
- ✓ Configures GitHub repository secrets (with GitHub CLI or manual guidance)
- ✓ Creates GitHub environment
- ✓ Updates Bicep parameter files
- ✓ Validates Bicep templates
- ✓ Saves local configuration reference

**Usage**:

```powershell
# Basic setup
.\scripts\Setup-AzureGitHubOIDC.ps1

# Setup for staging environment
.\scripts\Setup-AzureGitHubOIDC.ps1 -Environment staging

# Skip GitHub configuration
.\scripts\Setup-AzureGitHubOIDC.ps1 -SkipGitHubSetup

# Skip Bicep parameter updates
.\scripts\Setup-AzureGitHubOIDC.ps1 -SkipBicepParameters
```

**Interactive Prompts**:
- Azure Region (default: eastus)
- Resource Group Name (default: rg-{appname}-{env})
- Application Name (default: myapp)
- Organization Prefix (default: acme)

**Output**:
- GitHub secrets configured
- GitHub environment created
- Bicep parameters updated
- `.env.setup.local` configuration file
- Deployment validation successful

### Validate-Setup.ps1

**Purpose**: Comprehensive validation of setup configuration and status

**Checks Performed**:
- ✓ Prerequisites (Azure CLI, Git, GitHub CLI)
- ✓ Azure authentication and subscription
- ✓ GitHub authentication and repository
- ✓ Service principal existence and permissions
- ✓ Federated credentials configuration
- ✓ GitHub repository secrets
- ✓ Azure resource group and resources
- ✓ Bicep template validity
- ✓ Local configuration file

**Usage**:

```powershell
# Validate all configuration
.\scripts\Validate-Setup.ps1

# Validate specific resource group
.\scripts\Validate-Setup.ps1 -ResourceGroupName "rg-myapp-dev"
```

**Output**: Color-coded validation report with:
- ✓ Passing checks (green)
- ✗ Failed checks (red)
- Detailed information for each check
- Actionable next steps

### Cleanup-AzureSetup.ps1

**Purpose**: Safe removal of all setup resources

**Operations**:
- ✓ Deletes service principals (sp-github-*)
- ✓ Removes federated credentials
- ✓ Optionally deletes resource group and resources
- ✓ Optionally removes GitHub secrets
- ✓ Removes local configuration file
- ✓ Interactive confirmations for destructive operations

**Usage**:

```powershell
# Interactive cleanup (prompts for confirmation)
.\scripts\Cleanup-AzureSetup.ps1

# Force cleanup without prompting
.\scripts\Cleanup-AzureSetup.ps1 `
    -ResourceGroupName "rg-myapp-dev" `
    -DeleteResourceGroup `
    -DeleteGitHubSecrets
```

**⚠️ Warning**: This performs destructive operations that cannot be easily undone!

## Smart Features

### 1. Git/GitHub Inference

Automatically detects from repository:
- **GitHub Organization** - Parsed from git remote URL
- **GitHub Repository** - Extracted from git remote
- **Branch Names** - Detects main/master branch for OIDC setup

### 2. Intelligent Prompting

- Smart defaults based on context
- Input validation with regex patterns
- Helpful descriptions for each prompt
- Option to skip prompts with command parameters

### 3. Error Handling

- Comprehensive try-catch blocks
- Meaningful error messages
- Suggestions for remediation
- Script continues gracefully when non-critical operations fail

### 4. Azure Integration

Fully integrated with Azure CLI:
- Automatic subscription/tenant detection
- Federated credential management
- Service principal creation with proper scoping
- Role assignment verification
- Resource validation and status checks

### 5. GitHub Integration

Works with or without GitHub CLI:
- Full automation with GitHub CLI present
- Graceful fallback to manual setup with guidance
- Secret verification and status
- Environment creation support
- Repository access validation

### 6. Bicep Validation

- Syntax validation via `az bicep build`
- Parameter validation via `az deployment group validate`
- Bicep parameter file creation/update
- Environment-specific parameter handling

## Configuration Files

### `.env.setup.local` (Created by Setup Script)

Local reference configuration file with all setup values:

```bash
# Azure Settings
AZURE_SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_REGION=eastus
RESOURCE_GROUP_NAME=rg-myapp-dev

# Application
APP_NAME=myapp
ORG_PREFIX=acme
ENVIRONMENT=dev

# GitHub
GITHUB_ORG=your-org
GITHUB_REPO=your-repo
```

**Important**: Add to `.gitignore` to prevent accidental commits!

## Security Highlights

### OIDC Authentication

- No passwords or credentials stored
- GitHub issues short-lived OIDC tokens (10 minute expiry)
- Tokens exchanged for Azure managed identity tokens
- Secure token exchange verified by issuer and audience

### Federated Credentials

Three types configured automatically:

1. **Main Branch** - `repo:org/repo:ref:refs/heads/main`
   - For production deployments
   - Only on pushes to main

2. **Pull Requests** - `repo:org/repo:pull_request`
   - For validation workflows
   - On all pull requests to main

3. **Environment** - `repo:org/repo:environment:dev`
   - For environment-specific deployments
   - Scoped to named environment

### Least Privilege

- Service principal scoped to specific resource group
- Contributor role assigned (minimal necessary permissions)
- No subscription-level permissions
- No tenant-level permissions

### Audit Trail

- All Azure operations logged to Activity Log
- GitHub Actions logs available in repository
- Configuration saved locally for reference
- Setup validated before completing

## Prerequisites

### Required

- **PowerShell 7.0+** - Modern version required
- **Azure CLI** - For Azure resource management
- **Git** - For repository detection
- **Azure Subscription** - With appropriate permissions
- **GitHub Repository** - Must have admin access

### Optional

- **GitHub CLI** - For automated secret management
  - Without it, manual guidance provided
  - Setup still fully functional

### Installation

```bash
# Install Azure CLI
# https://learn.microsoft.com/en-us/cli/azure/install-azure-cli

# Install GitHub CLI (recommended)
# https://cli.github.com/

# Verify installations
az --version
git --version
gh --version
```

## Common Workflows

### 1. Initial Setup

```powershell
# Run setup interactively
.\scripts\Setup-AzureGitHubOIDC.ps1

# Verify configuration
.\scripts\Validate-Setup.ps1

# Test PR workflow
git checkout -b test/deployment
# Make infrastructure changes
git push origin test/deployment
# Create PR and observe validation workflow
```

### 2. Multi-Environment Setup

```powershell
# Setup production environment
.\scripts\Setup-AzureGitHubOIDC.ps1 -Environment prod

# Update prod bicep parameters
# Create GitHub environment with approval rules
# Test PR deployment
```

### 3. Configuration Verification

```powershell
# Check all configuration
.\scripts\Validate-Setup.ps1

# Check specific resource group
.\scripts\Validate-Setup.ps1 -ResourceGroupName "rg-myapp-prod"
```

### 4. Complete Cleanup

```powershell
# Interactive cleanup
.\scripts\Cleanup-AzureSetup.ps1

# Force cleanup
.\scripts\Cleanup-AzureSetup.ps1 `
    -ResourceGroupName "rg-myapp-dev" `
    -DeleteResourceGroup `
    -DeleteGitHubSecrets
```

## Documentation

- **QUICKSTART.md** - 5-minute quick start guide
- **README.md** - Detailed script documentation
- **docs/AZURE_SETUP.md** - Manual setup reference guide
- **infra/README.md** - Infrastructure documentation

## Troubleshooting

### Script Won't Run

```powershell
# Enable script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Cannot Find Modules

```powershell
# Use full qualified names
.\scripts\Setup-AzureGitHubOIDC.ps1  # Use .\ prefix
```

### Azure Authentication Failed

```powershell
# Login to Azure
az login

# For specific tenant
az login --tenant <tenant-id>
```

### GitHub CLI Not Found

The scripts work fine without GitHub CLI—they'll guide you through manual setup!

### Validation Fails

```powershell
# Debug validation
.\scripts\Validate-Setup.ps1

# Check Bicep syntax
az bicep build --file infra/main.bicep

# Validate deployment
az deployment group validate `
    --resource-group rg-myapp-dev `
    --template-file infra/main.bicep `
    --parameters infra/main.bicepparam
```

## Best Practices

1. **Run from repository root** - Scripts detect Git remote for GitHub info
2. **Use meaningful names** - Clear app names help identify resources
3. **Save the config file** - Keep `.env.setup.local` for reference
4. **Test the workflows** - Create test PRs before production use
5. **Use validation regularly** - Run `Validate-Setup.ps1` to check status
6. **Clean up properly** - Use the cleanup script to avoid orphaned resources

## Advanced Usage

### Scripting Integration

```powershell
# Setup in automation
.\scripts\Setup-AzureGitHubOIDC.ps1 -Environment prod -SkipBicepParameters

# Validate in CI/CD
$validationResult = & .\scripts\Validate-Setup.ps1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Setup is valid"
}
```

### Error Handling

Scripts use `$ErrorActionPreference = 'Stop'` for fail-fast behavior. Wrap in try-catch:

```powershell
try {
    .\scripts\Setup-AzureGitHubOIDC.ps1
}
catch {
    Write-Host "Setup failed: $_"
    exit 1
}
```

### Parallel Environment Setup

```powershell
# Setup multiple environments sequentially
'dev', 'staging', 'prod' | ForEach-Object {
    .\scripts\Setup-AzureGitHubOIDC.ps1 -Environment $_
}
```

## Support

- **Setup Issues** - See `docs/AZURE_SETUP.md` troubleshooting
- **Script Help** - `Get-Help .\scripts\Setup-AzureGitHubOIDC.ps1 -Full`
- **Azure CLI Help** - `az --help`
- **GitHub Actions** - https://docs.github.com/en/actions

## Files Included

```
scripts/
├── Setup-AzureGitHubOIDC.ps1    # Main setup automation (~25 KB)
├── Validate-Setup.ps1             # Validation and diagnostics (~15 KB)
├── Cleanup-AzureSetup.ps1         # Resource cleanup (~10 KB)
├── README.md                       # Detailed documentation
├── QUICKSTART.md                   # 5-minute quick start
└── (this file)                     # Overview and examples
```

## What's Automated

✓ GitHub repository detection
✓ Azure subscription detection
✓ Resource group creation
✓ Service principal creation
✓ Federated credential setup (3 types)
✓ GitHub secrets configuration
✓ GitHub environment creation
✓ Bicep parameter updates
✓ Template validation
✓ Deployment validation
✓ Configuration saved to file
✓ Error handling and recovery

## What Requires Manual Steps

- GitHub CLI authentication (if desired)
- GitHub environment approval rules (optional)
- Azure Portal verification (recommended)
- Production deployment approval

## Next Steps

1. Read `scripts/QUICKSTART.md` for 5-minute setup
2. Run `.\scripts\Setup-AzureGitHubOIDC.ps1`
3. Verify with `.\scripts\Validate-Setup.ps1`
4. Create test PR and deploy
5. Review in GitHub Actions and Azure Portal

Happy automating! 🚀
