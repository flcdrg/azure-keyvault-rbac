# Azure Setup Guide

This guide provides step-by-step instructions for configuring Azure resources and GitHub federated identity for this template.

## Prerequisites

- Azure CLI installed and authenticated: `az login`
- GitHub CLI installed (optional but recommended): `gh auth login`
- Repository admin access in GitHub
- Azure subscription with appropriate permissions (Contributor or higher)

## Overview

The deployment process uses:

- **OIDC Federated Identity**: Secure, credential-free authentication from GitHub Actions to Azure
- **Resource Group**: Container for all deployed resources
- **Service Principal**: Azure identity used by GitHub Actions
- **Deployment Stack**: Azure feature that manages resource lifecycle and deletion

## Step 1: Set Environment Variables

Replace these values with your own:

**Bash:**

```bash
# Azure settings
export AZURE_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export AZURE_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export AZURE_REGION="eastus"
export AZURE_RESOURCE_GROUP="rg-myapp-dev"

# Application settings
export APP_NAME="myapp"
export ENVIRONMENT="dev"

# GitHub settings
export GITHUB_ORG="your-org-or-username"
export GITHUB_REPO="azure-gh-actions-template"
```

**PowerShell:**

```powershell
# Azure settings
$AZURE_SUBSCRIPTION_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$AZURE_TENANT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$AZURE_REGION = "eastus"
$AZURE_RESOURCE_GROUP = "rg-myapp-dev"

# Application settings
$APP_NAME = "myapp"
$ENVIRONMENT = "dev"

# GitHub settings
$GITHUB_ORG = "your-org-or-username"
$GITHUB_REPO = "azure-gh-actions-template"
```

Get your subscription ID and tenant ID:

```bash
az account show --query "{id: id, tenantId: tenantId}"
```

## Step 2: Create Resource Group

**Bash:**

```bash
az group create \
  --name "${AZURE_RESOURCE_GROUP}" \
  --location "${AZURE_REGION}"

# Verify
az group show --name "${AZURE_RESOURCE_GROUP}"

```

**PowerShell:**

```powershell
az group create `
  --name $AZURE_RESOURCE_GROUP `
  --location $AZURE_REGION

# Verify
az group show --name $AZURE_RESOURCE_GROUP

```

## Step 3: Create Service Principal

**Bash:**

```bash
# Create service principal
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "sp-github-${APP_NAME}-${ENVIRONMENT}" \
  --role Contributor \
  --scopes "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}" \
  --output json)

# Extract values for use in later steps
export AZURE_CLIENT_ID=$(echo "$SP_OUTPUT" | jq -r '.appId')

az role assignment create --assignee "${AZURE_CLIENT_ID}" --role "Role Based Access Control Administrator" --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}"

echo "Service Principal created:"
echo "  Client ID (AppId): $AZURE_CLIENT_ID"
echo ""
echo "⚠️  Important: Save these values. The password will not be shown again."

```

**PowerShell:**

```powershell
# Create service principal
$spName = "sp-github-$APP_NAME-$ENVIRONMENT"
$SP_OUTPUT = az ad sp create-for-rbac `
  --name $spName `
  --role Contributor `
  --scopes "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP" `
  --output json | ConvertFrom-Json

# Extract values for use in later steps
$AZURE_CLIENT_ID = $SP_OUTPUT.appId

az role assignment create --assignee "$AZURE_CLIENT_ID" --role "Role Based Access Control Administrator" --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP"

Write-Output "Service Principal created:"
Write-Output "  Client ID (AppId): $AZURE_CLIENT_ID"
Write-Output ""
Write-Output "⚠️  Important: Save these values. The password will not be shown again."

```

## Step 4: Create Federated Credentials

Federated credentials allow GitHub to obtain short-lived tokens without storing static secrets.

### 4a: Main branch deployments (push to main)

**Bash:**

```bash
az ad app federated-credential create \
  --id "${AZURE_CLIENT_ID}" \
  --parameters '{
    "name": "GitHub-Deployments-Main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"${GITHUB_ORG}"'/'"${GITHUB_REPO}"':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "GitHub Actions deployment from main branch"
  }'

```

**PowerShell:**

```powershell
$fedCredMain = @{
  name = "GitHub-Deployments-Main"
  issuer = "https://token.actions.githubusercontent.com"
  subject = "repo:$GITHUB_ORG/$GITHUB_REPO`:ref:refs/heads/main"
  audiences = @("api://AzureADTokenExchange")
  description = "GitHub Actions deployment from main branch"
} | ConvertTo-Json

$fedCredMain | az ad app federated-credential create `
   --id $AZURE_CLIENT_ID `
   --parameters "@-"
```

### 4b: Pull request validation (PR events)

**Bash:**

```bash
az ad app federated-credential create \
  --id "${AZURE_CLIENT_ID}" \
  --parameters '{
    "name": "GitHub-PRs",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"${GITHUB_ORG}"'/'"${GITHUB_REPO}"':pull_request",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "GitHub Actions validation for pull requests"
  }'
```

**PowerShell:**

```powershell
$fedCredPR = @{
  name = "GitHub-PRs"
  issuer = "https://token.actions.githubusercontent.com"
  subject = "repo:$GITHUB_ORG/$GITHUB_REPO`:pull_request"
  audiences = @("api://AzureADTokenExchange")
  description = "GitHub Actions validation for pull requests"
} | ConvertTo-Json

$fedCredPR | az ad app federated-credential create `
   --id $AZURE_CLIENT_ID `
   --parameters "@-"
```

Verify federated credentials were created:

**Bash:**

```bash
az ad app federated-credential list --id "${AZURE_CLIENT_ID}"
```

**PowerShell:**

```powershell
az ad app federated-credential list --id $AZURE_CLIENT_ID
```

## Step 5: Configure GitHub Secrets and Environments

### 5a: Create 'dev' environment (if not exists)

In GitHub:

1. Go to repository **Settings** → **Environments**
2. Click **New environment**
3. Name it: `dev`
4. (Optional) Add deployment protection rules if desired

### 5b: Add Repository Secrets

Add these secrets at repository level (Settings → Secrets and variables → Actions):

**Bash (using GitHub CLI):**

```bash
gh secret set AZURE_TENANT_ID --body "${AZURE_TENANT_ID}"
gh secret set AZURE_CLIENT_ID --body "${AZURE_CLIENT_ID}"
gh secret set AZURE_SUBSCRIPTION_ID --body "${AZURE_SUBSCRIPTION_ID}"
gh secret set RESOURCE_GROUP_NAME --body "${AZURE_RESOURCE_GROUP}"

```

**PowerShell (using GitHub CLI):**

```powershell
gh secret set AZURE_TENANT_ID --body $AZURE_TENANT_ID
gh secret set AZURE_CLIENT_ID --body $AZURE_CLIENT_ID
gh secret set AZURE_SUBSCRIPTION_ID --body $AZURE_SUBSCRIPTION_ID
gh secret set RESOURCE_GROUP_NAME --body $AZURE_RESOURCE_GROUP

```

Or manually in GitHub UI:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add each secret:
   - `AZURE_TENANT_ID`
   - `AZURE_CLIENT_ID`
   - `AZURE_SUBSCRIPTION_ID`
   - `RESOURCE_GROUP_NAME`

### 5c: Verify Secrets

```bash
# List secrets (names only, not values)
gh secret list
```

### 5d: Create GitHub Environment for 'dev' (with federated credentials)

To enable deployments specifically in the dev GitHub environment with federated identity:

**Via GitHub UI:**

1. Go to repository **Settings** → **Environments**
2. Click **New environment** (or select existing 'dev')
3. Name it: `dev`
4. (Optional) Add deployment protection rules for approval gate
5. Environment secrets are not needed—repository secrets are sufficient

**Note**: The federated credentials you created in Step 4 (`GitHub-Main` and `GitHub-PRs`)
work across all environments. The GitHub environment is primarily for organization and
access control.

### 5e: Create Environment-Specific Federated Credential (Optional)

If you want a separate federated credential specifically scoped to the dev environment:

**Bash:**

```bash
az ad app federated-credential create \
  --id "${AZURE_CLIENT_ID}" \
  --parameters '{
    "name": "GitHub-Dev-Environment",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"${GITHUB_ORG}"'/'"${GITHUB_REPO}"':environment:dev",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "GitHub Actions deployments to dev environment"
  }'
```

**PowerShell:**

```powershell
$fedCredDev = @{
  name = "GitHub-Dev-Environment"
  issuer = "https://token.actions.githubusercontent.com"
  subject = "repo:$GITHUB_ORG/$GITHUB_REPO`:environment:dev"
  audiences = @("api://AzureADTokenExchange")
  description = "GitHub Actions deployments to dev environment"
} | ConvertTo-Json

$fedCredDev | az ad app federated-credential create `
  --id $AZURE_CLIENT_ID `
  --parameters "@-"
```

Verify the new credential:

**Bash:**

```bash
az ad app federated-credential list --id "${AZURE_CLIENT_ID}" --query \
  "[?name=='GitHub-Dev-Environment']"
```

**PowerShell:**

```powershell
az ad app federated-credential list --id $AZURE_CLIENT_ID | `
  ConvertFrom-Json | Where-Object { $_.name -eq "GitHub-Dev-Environment" }
```

## Step 6: Update Bicep Parameters

Edit `infra/main.bicepparam`:

```bicep
using './main.bicep'

param location = 'eastus'                // Your Azure region
param environment = 'dev'
param projectName = 'myapp'              // Your application name
param orgPrefix = 'acme'                 // Your organization prefix
param storageSkuName = 'Standard_LRS'
param storageAccessTier = 'Hot'
```

## Step 7: Test the Setup

### 7a: Test OIDC Token Exchange Locally

**Bash:**

```bash
# This simulates what GitHub Actions does
# (For testing purposes only; normally done by Actions)

# 1. Create a test GitHub token (requires GitHub CLI)
GITHUB_TOKEN=$(gh auth token)

# 2. In GitHub Actions environment, the token is injected automatically
# The workflows will use this to authenticate with Azure

```

**PowerShell:**

```powershell
# This simulates what GitHub Actions does
# (For testing purposes only; normally done by Actions)

# 1. Create a test GitHub token (requires GitHub CLI)
$GITHUB_TOKEN = gh auth token

# 2. In GitHub Actions environment, the token is injected automatically
# The workflows will use this to authenticate with Azure

```

### 7b: Create Test PR

1. Create a feature branch: `git checkout -b test/deployment`
2. Make a small change to `infra/main.parameters.dev.json`
3. Push and create a PR
4. Observe the `deploy-what-if.yml` workflow run
5. Review the PR comment with the what-if results

### 7c: Deploy to Dev

Once PR is merged to main:

1. The `deploy-stack.yml` workflow triggers automatically
2. View the run in **Actions** tab
3. Verify resources in Azure portal

## Troubleshooting

### OIDC Token Not Exchanged

**Error**: `azure/login` step fails with OIDC error

**Solution**:

1. Verify federated credentials:

   **Bash:**

   ```bash
   az ad app federated-credential list --id "${AZURE_CLIENT_ID}"
   ```

   **PowerShell:**

   ```powershell
   az ad app federated-credential list --id $AZURE_CLIENT_ID
   ```

2. Ensure Subject matches exactly: `repo:ORG/REPO:ref:refs/heads/main`
3. Check issuer URL is correct: `https://token.actions.githubusercontent.com`

### Service Principal Lacks Permissions

**Error**: Deployment fails with "Insufficient privileges"

**Solution**:

1. Check role assignment:

   **Bash:**

   ```bash
   az role assignment list --assignee "${AZURE_CLIENT_ID}"
   ```

   **PowerShell:**

   ```powershell
   az role assignment list --assignee $AZURE_CLIENT_ID
   ```

2. Assign Contributor role if missing:

   **Bash:**

   ```bash
   az role assignment create \
     --assignee "${AZURE_CLIENT_ID}" \
     --role Contributor \
     --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}"
   ```

   **PowerShell:**

   ```powershell
   az role assignment create `
     --assignee $AZURE_CLIENT_ID `
     --role Contributor `
     --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP"
   ```

### Resource Group Not Found

**Error**: `Resource group 'rg-...' not found`

**Solution**:

1. Verify RG exists:

   **Bash:**

   ```bash
   az group list --query "[].name" --output table
   ```

   **PowerShell:**

   ```powershell
   az group list --query "[].name" --output table
   ```

2. Check `RESOURCE_GROUP_NAME` secret matches exactly
3. Ensure secret is in correct scope (repository, not organization)

### Bicep Validation Fails

**Error**: Bicep build error during workflow

**Solution**:

1. Test locally:

   ```bash
   az bicep build --file infra/main.bicep
   ```

2. Validate parameters:

   ```bash
   az deployment group validate --resource-group ... --template-file infra/main.bicep --parameters infra/main.bicepparam
   ```

3. Check Bicep module paths are relative to `infra/`

## Multi-Environment Setup

To add staging and prod environments:

1. Create parameter files:

   ```bash
   cp infra/main.bicepparam infra/main.bicepparam.staging
   cp infra/main.bicepparam infra/main.bicepparam.prod
   ```

2. Edit each with environment-specific values (location, SKU, tags, etc.)

3. Create GitHub environments: staging, prod

4. (Optional) Add approval rules to production environment

5. Update workflows to support environment parameter selection

## Cleanup

To remove all resources and the service principal:

**Bash:**

```bash
# Delete resource group (removes all resources)
az group delete --name "${AZURE_RESOURCE_GROUP}" --yes

# Delete service principal
az ad sp delete --id "${AZURE_CLIENT_ID}"

# Delete GitHub secrets (using GitHub CLI)
gh secret delete AZURE_TENANT_ID
gh secret delete AZURE_CLIENT_ID
gh secret delete AZURE_SUBSCRIPTION_ID
gh secret delete RESOURCE_GROUP_NAME

```

**PowerShell:**

```powershell
# Delete resource group (removes all resources)
az group delete --name $AZURE_RESOURCE_GROUP --yes

# Delete service principal
az ad sp delete --id $AZURE_CLIENT_ID

# Delete GitHub secrets (using GitHub CLI)
gh secret delete AZURE_TENANT_ID
gh secret delete AZURE_CLIENT_ID
gh secret delete AZURE_SUBSCRIPTION_ID
gh secret delete RESOURCE_GROUP_NAME

```

## Additional Resources

- [Azure Deployment Stacks Docs](https://learn.microsoft.com/en-us/azure/azure-resource-manager/deployment-stacks/overview)
- [GitHub OIDC Integration](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Azure Bicep Reference](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/file)
- [Azure CLI Installation](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
