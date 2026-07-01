# Quick Start Guide - Automated Setup

Get your Azure infrastructure ready in minutes with the automated setup script!

## 5-Minute Setup

### Step 1: Prerequisites

Ensure you have:

```powershell
# Check Azure CLI
az --version

# Check Git
git --version

# Optional: Check GitHub CLI
gh --version
```

If any are missing, install them:
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Git](https://git-scm.com)
- [GitHub CLI](https://cli.github.com/) (recommended)

### Step 2: Authenticate

```powershell
# Login to Azure
az login

# Login to GitHub (if using GitHub CLI)
gh auth login
```

### Step 3: Run Setup

```powershell
# Navigate to repository
cd path/to/azure-gh-actions-template

# Run the setup script
.\scripts\Setup-AzureGitHubOIDC.ps1
```

### Step 4: Follow Prompts

The script will ask you for:

1. **Azure Region** (default: `eastus`)
   - Where your resources will be deployed
   - Examples: `eastus`, `westus2`, `northeurope`

2. **Resource Group Name** (default: `rg-myapp-dev`)
   - Container for all your Azure resources
   - Will be created if it doesn't exist

3. **Application Name** (default: `myapp`)
   - Used in resource naming conventions
   - Keep it lowercase and simple

4. **Organization Prefix** (default: `acme`)
   - 2-5 character prefix for resource naming
   - Examples: `org`, `acme`, `dev`

### Step 5: Verify Setup

After the script completes:

1. Check GitHub Secrets:
   ```
   https://github.com/YOUR_ORG/YOUR_REPO/settings/secrets/actions
   ```
   Should see:
   - `AZURE_TENANT_ID`
   - `AZURE_CLIENT_ID`
   - `AZURE_SUBSCRIPTION_ID`
   - `RESOURCE_GROUP_NAME`

2. Create a test PR:
   ```powershell
   git checkout -b test/deployment
   # Make a small change to infra/
   git push origin test/deployment
   # Create PR in GitHub
   ```

3. Watch the workflow:
   - GitHub Actions → `deploy-what-if` workflow
   - Should validate successfully

4. Merge the PR to deploy!

## What Gets Created

### Azure Resources

- **Resource Group**: Container for all resources
- **Service Principal**: Identity for GitHub Actions
- **Federated Credentials**: Secure connection between GitHub and Azure (3 types)
- **OIDC Configuration**: Enables credential-free authentication

### GitHub Configuration

- **Repository Secrets**: 4 secrets configured
- **GitHub Environment**: `dev` (or `staging`, `prod`)
- **Deployment Integration**: Ready for workflows

### Local Files

- **`.env.setup.local`**: Configuration reference (don't commit!)
- **`infra/main.bicepparam`**: Updated with your settings

## Troubleshooting

### Script Won't Run

**Error**: "cannot be loaded because running scripts is disabled"

**Solution**:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### GitHub CLI Not Available

No problem! The script will guide you to add secrets manually through the GitHub web interface.

### Bicep Validation Failed

Check your Bicep files:

```powershell
az bicep build --file infra/main.bicep
```

### Service Principal Creation Failed

Ensure you have:
- Azure subscription access
- Contributor role (at minimum) at subscription level
- Permissions to create service principals in your tenant

## Next Steps

1. **Create resources** by merging a PR to main
2. **Add more environments** with:
   ```powershell
   .\scripts\Setup-AzureGitHubOIDC.ps1 -Environment staging
   ```
3. **Review infrastructure** in `docs/AZURE_SETUP.md`
4. **Clean up** (if needed) with:
   ```powershell
   .\scripts\Cleanup-AzureSetup.ps1
   ```

## Configuration Reference

The script creates `.env.setup.local` with all your settings:

```bash
AZURE_SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_REGION=eastus
RESOURCE_GROUP_NAME=rg-myapp-dev
APP_NAME=myapp
ORG_PREFIX=acme
GITHUB_ORG=your-org
GITHUB_REPO=your-repo
```

## Security Highlights

✓ **No passwords stored**: Uses OIDC for secure authentication
✓ **Short-lived tokens**: GitHub tokens expire after 10 minutes
✓ **Least privilege**: Service principal scoped to resource group
✓ **Encrypted secrets**: All secrets encrypted at rest in GitHub
✓ **Audit trail**: All operations logged in Azure Activity Log

## Common Tasks

### Setup additional environment (staging)

```powershell
.\scripts\Setup-AzureGitHubOIDC.ps1 -Environment staging
```

### Update Bicep parameters manually

Edit `infra/main.bicepparam`:

```bicep
param location = 'eastus'
param environment = 'dev'
param projectName = 'myapp'
param orgPrefix = 'acme'
```

### Validate deployment locally

```powershell
az deployment group validate `
    --resource-group rg-myapp-dev `
    --template-file infra/main.bicep `
    --parameters infra/main.bicepparam
```

### View deployment status

```powershell
# List deployments
az deployment group list --resource-group rg-myapp-dev

# View deployment outputs
az deployment group show `
    --resource-group rg-myapp-dev `
    --name <deployment-name>
```

### Clean up (delete everything)

```powershell
.\scripts\Cleanup-AzureSetup.ps1 `
    -DeleteResourceGroup `
    -DeleteGitHubSecrets
```

## Support

- **Setup Issues**: See `docs/AZURE_SETUP.md` Troubleshooting section
- **Bicep Help**: [Azure Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- **GitHub Actions**: [GitHub Actions Documentation](https://docs.github.com/en/actions)
- **Azure CLI**: `az --help`

## What's Next?

After setup:

1. ✅ Review the deployment workflow in GitHub Actions
2. ✅ Customize Bicep templates for your needs
3. ✅ Add approval gates for production environments
4. ✅ Monitor deployments in Azure Portal
5. ✅ Extend to other environments (staging, prod)

Happy deploying! 🚀
