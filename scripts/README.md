# Azure Setup Scripts

Automated PowerShell scripts for setting up and managing Azure resources with GitHub
Actions OIDC authentication.

## Prerequisites

- **PowerShell 7.0+**
- **Azure CLI** (installed and authenticated: `az login`)
- **Git** (for repository detection)
- **GitHub CLI** (optional, for automated secret management)

## Scripts

### Setup-AzureGitHubOIDC.ps1

Complete automated setup for Azure OIDC authentication with GitHub Actions.

#### What it does

1. ✓ Detects GitHub organization and repository from git remote
2. ✓ Retrieves Azure subscription and tenant information
3. ✓ Creates or validates Azure resource group
4. ✓ Creates service principal with Contributor role scoped to resource group
5. ✓ Sets up OIDC federated credentials for:
   - Main branch deployments
   - Pull request validation
   - Environment-specific deployments
6. ✓ Configures GitHub repository secrets (with or without GitHub CLI)
7. ✓ Creates GitHub environment
8. ✓ Updates Bicep parameter files with your configuration
9. ✓ Validates Bicep templates and deployment configuration
10. ✓ Saves local configuration for reference

#### Usage

**Interactive setup (prompts for all values):**

```powershell
cd path/to/repository
.\scripts\Setup-AzureGitHubOIDC.ps1
```

**Setup for specific environment:**

```powershell
.\scripts\Setup-AzureGitHubOIDC.ps1 -Environment staging
```

**Skip GitHub setup (Azure only):**

```powershell
.\scripts\Setup-AzureGitHubOIDC.ps1 -SkipGitHubSetup
```

**Skip Bicep parameter updates:**

```powershell
.\scripts\Setup-AzureGitHubOIDC.ps1 -SkipBicepParameters
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Environment` | String | `dev` | Deployment environment: `dev`, `staging`, or `prod` |
| `-SkipGitHubSetup` | Switch | `false` | Skip GitHub secret and environment configuration |
| `-SkipBicepParameters` | Switch | `false` | Skip updating Bicep parameter files |

#### What you'll be prompted for

- **Azure Region**: Azure region for resource deployment (default: `eastus`)
- **Resource Group Name**: Name for Azure resource group (default: `rg-{appname}-{environment}`)
- **Application Name**: Used in resource naming (default: `myapp`)
- **Organization Prefix**: 2-5 char prefix for resources (default: `acme`)

#### Output

After successful setup:

1. **GitHub Secrets** configured:
   - `AZURE_TENANT_ID`
   - `AZURE_CLIENT_ID`
   - `AZURE_SUBSCRIPTION_ID`
   - `RESOURCE_GROUP_NAME`

2. **GitHub Environment** created (if not exists)

3. **Bicep Parameters** updated in `infra/main.bicepparam*`

4. **Local Config** saved to `.env.setup.local` (do not commit!)

#### Next Steps

1. Review secrets in GitHub: Settings → Secrets and variables → Actions
2. Create a test PR to validate the deployment workflow
3. Merge PR to trigger production deployment

### Cleanup-AzureSetup.ps1

Remove all Azure resources and GitHub secrets created during setup.

#### What it does

1. ✓ Deletes service principals matching `sp-github-*`
2. ✓ Removes federated credentials
3. ✓ Optionally deletes resource group and all resources
4. ✓ Optionally removes GitHub repository secrets
5. ✓ Removes local configuration file

#### Usage

**Interactive cleanup (prompts before each deletion):**

```powershell
.\scripts\Cleanup-AzureSetup.ps1
```

**Clean up specific resource group:**

```powershell
.\scripts\Cleanup-AzureSetup.ps1 -ResourceGroupName "rg-myapp-dev"
```

**Force cleanup without prompting:**

```powershell
.\scripts\Cleanup-AzureSetup.ps1 `
    -ResourceGroupName "rg-myapp-dev" `
    -DeleteResourceGroup `
    -DeleteGitHubSecrets
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-ResourceGroupName` | String | interactive | Azure resource group to delete |
| `-DeleteResourceGroup` | Switch | interactive | Delete resource group without prompting |
| `-DeleteGitHubSecrets` | Switch | interactive | Delete GitHub secrets without prompting |

#### ⚠️ Warning

This script performs destructive operations:

- **Deletes Azure resources** in the specified resource group
- **Removes service principals** used by GitHub Actions
- **Deletes GitHub repository secrets**

**These operations cannot be easily undone!**

## Troubleshooting

### GitHub CLI not available

If you don't have GitHub CLI installed, the setup script will guide you to add
secrets manually through the GitHub web interface. Links will be provided.

### Authentication failures

Ensure you're authenticated with both Azure and GitHub:

```powershell
az login                    # Login to Azure
gh auth login              # Login to GitHub
```

### Service principal creation fails

Check that your Azure account has sufficient permissions (Contributor role or
higher at subscription level).

### Bicep validation fails

Verify that:
1. You're in the repository root directory
2. `infra/main.bicep` exists
3. Bicep templates are syntactically valid

Run this to debug:

```powershell
az bicep build --file infra/main.bicep
```

### Cannot find parameter file

The script expects Bicep parameter files at:
- Dev: `infra/main.bicepparam`
- Staging: `infra/main.bicepparam.staging`
- Prod: `infra/main.bicepparam.prod`

If files don't exist, the script will offer to create them from the dev template.

## Configuration File

After setup, a `.env.setup.local` file is created with all configuration values.

```bash
# Example .env.setup.local
AZURE_SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
RESOURCE_GROUP_NAME=rg-myapp-dev
APP_NAME=myapp
ORG_PREFIX=acme
GITHUB_ORG=your-org
GITHUB_REPO=azure-gh-actions-template
```

**Important**: Add this file to `.gitignore` to prevent accidental commits of
sensitive data.

## Best Practices

1. **Run from repository root**: Scripts detect Git remote to identify GitHub info
2. **Use meaningful names**: Choose clear app names and org prefixes for resources
3. **Save the config file**: Keep `.env.setup.local` for reference
4. **Test workflows**: Create a test PR after setup to validate everything works
5. **Use cleanup script**: For complete teardown, use `Cleanup-AzureSetup.ps1`

## Multi-Environment Setup

To add staging or production environments:

```powershell
# Setup staging
.\scripts\Setup-AzureGitHubOIDC.ps1 -Environment staging

# Setup production
.\scripts\Setup-AzureGitHubOIDC.ps1 -Environment prod
```

Each environment:
- Gets its own service principal
- Has separate Bicep parameters
- Can have its own GitHub environment with approval rules

## Security Notes

- **No secrets stored**: Uses OIDC for credential-free authentication
- **Federated credentials**: GitHub tokens are short-lived (10 minutes)
- **Least privilege**: Service principals are scoped to resource group level
- **Local config**: `.env.setup.local` contains sensitive data—never commit it

## Related Documentation

- [Azure Setup Guide](../docs/AZURE_SETUP.md)
- [Infrastructure Documentation](../infra/README.md)
- [GitHub OIDC Security](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Azure Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
