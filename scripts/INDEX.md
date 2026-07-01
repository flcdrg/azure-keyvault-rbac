# Scripts Package - Index and Quick Reference

This directory contains production-ready PowerShell scripts for automating Azure + GitHub Actions OIDC setup.

## 📋 Files Overview

### Core Scripts

| Script | Purpose | Size | Lines |
|--------|---------|------|-------|
| **Setup-AzureGitHubOIDC.ps1** | Complete interactive setup automation | 25 KB | 590 |
| **Validate-Setup.ps1** | Comprehensive validation & diagnostics | 15 KB | 380 |
| **Cleanup-AzureSetup.ps1** | Safe resource cleanup with confirmations | 10 KB | 260 |

### Documentation

| Document | Purpose |
|----------|---------|
| **README.md** | Detailed script documentation & reference |
| **QUICKSTART.md** | 5-minute quick start guide |
| **INDEX.md** | This file - quick reference |

## 🚀 Quick Commands

```powershell
# Setup (interactive, prompts for values)
.\Setup-AzureGitHubOIDC.ps1

# Validate everything is configured
.\Validate-Setup.ps1

# Cleanup (with confirmations)
.\Cleanup-AzureSetup.ps1
```

## 🎯 What Each Script Does

### Setup-AzureGitHubOIDC.ps1

Automates the complete Azure + GitHub setup in one command:

1. Detects GitHub org/repo from git remote
2. Gets Azure subscription & tenant info
3. Creates/validates resource group
4. Creates service principal
5. Sets up OIDC federated credentials (3 types)
6. Configures GitHub secrets
7. Creates GitHub environment
8. Updates Bicep parameters
9. Validates everything works
10. Saves configuration file

**Parameters**:
```powershell
-Environment dev|staging|prod        # Which environment (default: dev)
-SkipGitHubSetup                      # Skip GitHub configuration
-SkipBicepParameters                  # Skip Bicep parameter updates
```

**Example**:
```powershell
# Setup production environment
.\Setup-AzureGitHubOIDC.ps1 -Environment prod

# Setup dev, skip GitHub
.\Setup-AzureGitHubOIDC.ps1 -SkipGitHubSetup
```

### Validate-Setup.ps1

Validates all configuration is working:

- Prerequisites installed (Azure CLI, Git, GitHub CLI)
- Azure authentication working
- GitHub authentication working
- Service principal exists and has permissions
- Federated credentials configured
- GitHub secrets configured
- Resource group exists
- Bicep templates valid
- Local configuration file present

**Parameters**:
```powershell
-ResourceGroupName <name>     # Specific resource group to check
```

**Example**:
```powershell
# Validate everything
.\Validate-Setup.ps1

# Check specific resource group
.\Validate-Setup.ps1 -ResourceGroupName "rg-myapp-prod"
```

### Cleanup-AzureSetup.ps1

Safely removes all created resources:

1. Deletes service principals (sp-github-*)
2. Removes federated credentials
3. Optionally deletes resource group
4. Optionally removes GitHub secrets
5. Removes local configuration file
6. Prompts for confirmation on destructive operations

**Parameters**:
```powershell
-ResourceGroupName <name>     # Resource group to delete
-DeleteResourceGroup           # Delete RG without prompting
-DeleteGitHubSecrets          # Delete secrets without prompting
```

**Example**:
```powershell
# Interactive cleanup (prompts before each action)
.\Cleanup-AzureSetup.ps1

# Force cleanup without prompting
.\Cleanup-AzureSetup.ps1 -ResourceGroupName "rg-myapp-dev" `
    -DeleteResourceGroup -DeleteGitHubSecrets
```

## 📚 Documentation Files

### README.md
Comprehensive reference for all scripts:
- Detailed parameter documentation
- Usage examples
- Troubleshooting guide
- Best practices
- Multi-environment setup

### QUICKSTART.md
Get started in 5 minutes:
- Step-by-step setup walkthrough
- What to expect at each step
- Common tasks
- Configuration reference

## 🔧 Common Workflows

### Initial Setup (Complete)

```powershell
# 1. Run interactive setup
.\Setup-AzureGitHubOIDC.ps1

# 2. Verify everything
.\Validate-Setup.ps1

# 3. Create test PR
git checkout -b test/infrastructure
# Make a small change to infra/
git push origin test/infrastructure
# Create PR in GitHub - should trigger deploy-what-if workflow

# 4. Merge to deploy
# After PR approval, merge to main
# deploy-stack workflow triggers automatically
```

### Multi-Environment (Production)

```powershell
# 1. Setup dev
.\Setup-AzureGitHubOIDC.ps1 -Environment dev

# 2. Setup staging
.\Setup-AzureGitHubOIDC.ps1 -Environment staging

# 3. Setup production
.\Setup-AzureGitHubOIDC.ps1 -Environment prod

# 4. Verify all
.\Validate-Setup.ps1 -ResourceGroupName "rg-myapp-dev"
.\Validate-Setup.ps1 -ResourceGroupName "rg-myapp-staging"
.\Validate-Setup.ps1 -ResourceGroupName "rg-myapp-prod"
```

### Validation & Monitoring

```powershell
# Check if everything is still working
.\Validate-Setup.ps1

# Verify secrets are configured
.\Validate-Setup.ps1 | Select-String "GitHub"

# Check specific resource group
.\Validate-Setup.ps1 -ResourceGroupName "rg-myapp-prod"
```

### Complete Cleanup

```powershell
# Interactive cleanup (recommended)
.\Cleanup-AzureSetup.ps1

# Or force cleanup for specific resource group
.\Cleanup-AzureSetup.ps1 `
    -ResourceGroupName "rg-myapp-dev" `
    -DeleteResourceGroup `
    -DeleteGitHubSecrets
```

## 🎓 Learning Resources

### For First-Time Users
1. Read `QUICKSTART.md` (5 minutes)
2. Run `Setup-AzureGitHubOIDC.ps1` (interactive)
3. Run `Validate-Setup.ps1` (verify)
4. Review `README.md` for details

### For Advanced Users
1. Review `README.md` for all parameters and options
2. Use `Validate-Setup.ps1` in automation/scripts
3. Integrate `Setup-AzureGitHubOIDC.ps1` into CI/CD
4. Review `SETUP_AUTOMATION.md` for architecture details

## 📋 Prerequisites

### Required
- PowerShell 7.0+
- Azure CLI (installed and authenticated: `az login`)
- Git (for repository detection)
- Azure subscription (with appropriate permissions)
- GitHub repository (with admin access)

### Optional (but recommended)
- GitHub CLI (for automated secret management)

### Installation
```powershell
# Check what you have
az --version
git --version
gh --version

# If missing:
# Azure CLI: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
# GitHub CLI: https://cli.github.com/
```

## 🔐 Security

All scripts use:
- ✅ OIDC authentication (no stored credentials)
- ✅ Short-lived tokens (10-minute expiry)
- ✅ Least privilege service principals (scoped to resource group)
- ✅ Comprehensive error handling
- ✅ User confirmations for destructive operations
- ✅ Local config files never committed to git

## ⚡ Key Features

### Smart Detection
- Automatically finds GitHub org/repo from git remote
- Auto-detects Azure subscription and tenant
- Infers reasonable defaults from context

### Interactive Prompts
- Helpful descriptions for each input
- Input validation with regex patterns
- Smart defaults you can override
- Option to skip with parameters

### Validation Built-In
- Bicep syntax validation
- Deployment configuration validation
- Template compatibility checks
- Environment variable verification

### Error Handling
- Graceful failure modes
- Helpful error messages
- Suggestions for fixes
- Non-blocking error recovery

### GitHub Integration
- Works with or without GitHub CLI
- Fallback to manual guidance when needed
- Automatic secret management
- Repository access verification

## 🛠️ Troubleshooting

### Script Won't Run
```powershell
# Enable script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Command Not Found
```powershell
# Use full path from scripts directory
.\Setup-AzureGitHubOIDC.ps1

# Or navigate to scripts directory
cd scripts
.\Setup-AzureGitHubOIDC.ps1
```

### Authentication Failed
```powershell
# Azure login
az login

# GitHub login (if using CLI)
gh auth login
```

### Validation Errors
```powershell
# Run validation script for diagnostics
.\Validate-Setup.ps1

# Detailed Bicep check
az bicep build --file infra/main.bicep

# Detailed deployment validation
az deployment group validate `
    --resource-group rg-myapp-dev `
    --template-file infra/main.bicep `
    --parameters infra/main.bicepparam
```

## 📞 Support

- **Detailed Docs**: See `README.md` in this directory
- **Quick Start**: See `QUICKSTART.md` in this directory
- **Setup Guide**: See `../docs/AZURE_SETUP.md` for manual reference
- **Infrastructure**: See `../infra/README.md` for infrastructure docs
- **Help Text**: Run `Get-Help .\Setup-AzureGitHubOIDC.ps1 -Full`

## 🎯 Next Steps

1. ✅ Review this file (INDEX.md)
2. ✅ Read `QUICKSTART.md` for 5-minute walkthrough
3. ✅ Run `Setup-AzureGitHubOIDC.ps1`
4. ✅ Validate with `Validate-Setup.ps1`
5. ✅ Create test PR to verify workflows
6. ✅ Refer to `README.md` for advanced usage

---

**Version**: 1.0
**Last Updated**: 2024
**Tested With**: PowerShell 7.0+, Azure CLI 2.50+, GitHub CLI 2.30+
