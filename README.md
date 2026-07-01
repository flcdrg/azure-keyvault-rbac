# Azure GitHub Actions Template

A production-ready template for deploying Azure infrastructure using GitHub
Actions, Bicep, and Azure Deployment Stacks with OIDC authentication.

## 🚀 Features

- **Infrastructure as Code**: Bicep templates for Azure resources
- **Deployment Stacks**: Azure feature for managing resource lifecycle and deletion
- **GitHub Actions Workflows**: Automated CI/CD for infrastructure
- **OIDC Authentication**: Secure, credential-free authentication to Azure
- **PR What-If**: Preview infrastructure changes before merging
- **Multi-Environment Ready**: Easily extend to staging and production

## 📋 Quick Start

### Prerequisites

- Azure CLI: [Install](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- Git and GitHub CLI (optional)
- Azure subscription with Contributor or higher permissions

### 1. Setup Azure Infrastructure

Follow the comprehensive setup guide:

```bash
# See docs/AZURE_SETUP.md for detailed step-by-step instructions
# This includes:
# - Creating a resource group
# - Creating a service principal
# - Setting up OIDC federated credentials
# - Configuring GitHub Secrets

```

**Quick summary**:

```bash
# Set your values
export AZURE_SUBSCRIPTION_ID="your-sub-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_RESOURCE_GROUP="rg-myapp-dev"
export GITHUB_ORG="your-org"
export GITHUB_REPO="your-repo"

# Create resource group
az group create --name "${AZURE_RESOURCE_GROUP}" --location eastus

# Create service principal
az ad sp create-for-rbac \
  --name "sp-github-myapp-dev" \
  --role Contributor \
   --scopes "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}"

# Create federated credentials (see AZURE_SETUP.md for full commands)

```

### 2. Add GitHub Secrets

Add these repository secrets (Settings → Secrets and variables → Actions):

- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `RESOURCE_GROUP_NAME`

### 3. Customize Infrastructure

Edit the Bicep parameters for your environment:

```bash
# Edit dev environment parameters
vim infra/main.bicepparam

# Update values:
# - location: Azure region for deployment
# - projectName: Your application name
# - orgPrefix: Your organization prefix

```

### 4. Deploy

Create a PR to trigger the what-if validation:

```bash
git checkout -b feature/my-changes
# Make changes to infra/
git push origin feature/my-changes
# Create PR in GitHub

```

The PR workflow (`deploy-what-if.yml`) will:

- ✅ Validate Bicep syntax
- ✅ Validate template deployment (without actual deployment)
- ✅ Comment on the PR with validation results

Merge the PR to deploy to dev:

```bash
# After PR is approved and merged to main
# The deploy-stack.yml workflow triggers automatically
# Monitor in Actions tab

```

## 📁 Repository Structure

```text
.
├── .github/
│   ├── workflows/
│   │   ├── deploy-what-if.yml    # PR validation workflow (uses bicep-deploy action)
│   │   └── deploy-stack.yml      # Main branch deployment workflow (deploymentStack)
│   └── copilot-instructions.md   # Copilot configuration
├── docs/
│   └── AZURE_SETUP.md            # Comprehensive setup guide
├── infra/
│   ├── main.bicep                # Main orchestration template
│   ├── variables.bicep           # Naming conventions and variables
│   ├── outputs.bicep             # Output definitions
│   ├── modules/
│   │   └── storage.bicep         # Storage account module
│   ├── main.bicepparam           # Dev environment parameters (bicepparam format)
│   ├── main.bicepparam.staging   # Staging environment parameters (future)
│   ├── main.bicepparam.prod      # Production environment parameters (future)
│   └── README.md                 # Infrastructure documentation
├── README.md
└── LICENSE

```

## 🔐 Security

- **OIDC Federated Credentials**: No static credentials stored in GitHub Secrets
- **Short-Lived Tokens**: GitHub Issues OIDC tokens valid for 10 minutes
- **Least Privilege**: Service principal scoped to the deployment resource group
- **Secure Communication**: All communication over HTTPS with verified tokens

[Learn more about OIDC security](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

## 🛠️ Workflows

### deploy-what-if.yml

Triggered on: Pull requests to `main` (when infra changes detected)

Purpose: Validates infrastructure changes before merge

Jobs:

1. **setup**: Generates deployment name with timestamp (output variable)
2. **validate-bicep**: Validates Bicep syntax and parameters
3. **what-if**: Runs validation using Azure/bicep-deploy action
   - Uses regular `deployment` mode (not deploymentStack)
   - Uses `azure/login@v2` for OIDC authentication
   - Comments PR with validation results

### deploy-stack.yml

Triggered on:

- Push to `main` branch (after PR merge)
- Manual workflow dispatch via GitHub UI

Purpose: Creates or updates Deployment Stack for resource lifecycle management

Jobs:

1. **setup**: Generates deployment stack name with timestamp (output variable)
2. **deploy**: Main deployment job
   - Validates resource group exists
   - Validates Bicep template
   - Uses Azure/bicep-deploy@v0.3.0 for what-if preview
   - Creates/updates Deployment Stack via `az deployment group create`
   - Retrieves and displays deployment outputs using consistent deployment name

**Key Feature**: Deployment name is calculated once in setup job and reused across
all steps to ensure consistent naming for what-if preview and actual deployment.

## 📦 Deployment Stacks

Azure Deployment Stacks manage resource lifecycle:

- **Create**: Initial deployment creates a stack
- **Update**: Subsequent deployments update the stack
- **Delete**: Stack can cleanly remove managed resources

Benefits:

- Prevents accidental deletion of managed resources
- Tracks all resources created by a stack
- Supports deny assignments for protection

## 🌍 Multi-Environment Deployment

To add staging or production environments:

1. **Create parameter file**:

   ```bash
   cp infra/main.bicepparam infra/main.bicepparam.staging
   ```

2. **Update parameters** for your environment

3. **Create GitHub environment** (Settings → Environments)

4. **Update workflows** to support environment selection:

   ```yaml
   # Modify deploy-stack.yml to use selected environment's bicepparam file
   # Add approval rules in GitHub Environments if desired
   ```

See [Multi-Environment Setup](docs/AZURE_SETUP.md#multi-environment-setup) for detailed instructions.

## 📚 Documentation

- **[docs/AZURE_SETUP.md](docs/AZURE_SETUP.md)** - Complete setup guide with CLI commands
- **[infra/README.md](infra/README.md)** - Infrastructure template documentation
- **[.github/copilot-instructions.md](.github/copilot-instructions.md)** - Copilot AI guidelines

## 🔧 Troubleshooting

### Workflow fails with OIDC error

See [OIDC Troubleshooting](docs/AZURE_SETUP.md#oidc-token-not-exchanged) in the setup guide.

### Service Principal lacks permissions

See [Permissions Troubleshooting](docs/AZURE_SETUP.md#service-principal-lacks-permissions) in the setup guide.

### Bicep validation fails

See [Bicep Troubleshooting](docs/AZURE_SETUP.md#bicep-validation-fails) in the setup guide.

## 🔗 Resources

- [Azure Deployment Stacks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/deployment-stacks/overview)
- [GitHub OIDC Integration](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Azure Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## 📝 License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.

## 🛠️ Contributing

### Code Quality Standards

All Markdown documentation must pass linting checks:

```bash
npm install -g markdownlint-cli
markdownlint "*.md" "docs/*.md" ".github/*.md" "infra/*.md"
```

**Markdown Standards** (.markdownlintrc):

- Line length: Maximum 120 characters (wrap longer lines)
- No trailing spaces at end of lines
- Maximum 1 blank line between sections
- Code blocks must have syntax highlighting

Before committing documentation changes, run the linter and fix any warnings.
