# GitHub Copilot Instructions

## Project Overview

**azure-gh-actions-template** is a production-ready template for deploying Azure
infrastructure using GitHub Actions, Bicep IaC, and Azure Deployment Stacks with
OIDC authentication. It demonstrates secure CI/CD patterns for infrastructure
deployment with PR validation and multi-environment support.

## Architecture

- **Bicep Infrastructure**: Modular templates defining Azure resources (storage account module)
- **GitHub Actions Workflows**: Two workflows—PR what-if validation and main branch deployment
- **Deployment Stacks**: Azure ARM feature managing resource lifecycle
- **OIDC Authentication**: Federated credentials for credential-free Azure access
- **Environment Separation**: Parameter files per environment (dev, staging, prod)

## Key Conventions

### Bicep Structure (`infra/`)

- **main.bicep**: Orchestration template importing modules and variables
- **variables.bicep**: Shared naming conventions, tags, computed values
- **modules/*.bicep**: Reusable resource modules (e.g., storage.bicep)
- **outputs.bicep**: Output definitions for workflow consumption
- **main.bicepparam***: Environment-specific parameters using bicepparam format (dev, staging, prod)

Naming follows Azure Cloud Adoption Framework: https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations

### Workflows (.github/workflows/)

- **deploy-what-if.yml**: PR trigger; uses Azure/bicep-deploy action for validation,
  comments PR with validation results
- **deploy-stack.yml**: Main/push trigger; uses Azure/bicep-deploy action for deployment,
  creates Deployment Stack via `az deployment group create`
- Both use `azure/login@v2` with OIDC (client-id, tenant-id, subscription-id from secrets)
- Both generate deployment name with timestamp in setup job for output variable reuse
- Environment-aware via ENVIRONMENT variable resolved from parameter file naming
- Uses `Azure/bicep-deploy@v0.3.0` action for consistent deployment handling

## Documentation

- **docs/AZURE_SETUP.md**: Comprehensive setup guide with step-by-step CLI commands
  - Resource group creation
  - Service principal creation
  - OIDC federated credential setup (main, PRs, and dev environment-specific)
  - GitHub environment configuration
  - GitHub Secret configuration
  - Multi-environment scaling instructions
  - Troubleshooting guide
- **infra/README.md**: Infrastructure template documentation
- **README.md**: Quick start and feature overview

### Markdown Standards

All Markdown files must comply with `.markdownlintrc` configuration:

- **Line Length**: Maximum 120 characters per line (wrap longer lines)
- **Code Blocks**: Proper syntax highlighting (bash, powershell, json, etc.)
- **No Trailing Spaces**: Remove spaces at end of lines
- **No Multiple Blank Lines**: Maximum 1 blank line between sections

Validation commands:

```bash
# Install linter
npm install -g markdownlint-cli

# Validate all Markdown files
markdownlint "*.md" "docs/*.md" ".github/*.md" "infra/*.md"
```

Before committing, ensure all Markdown passes linting.

## Build, Test, and Validation Commands

**Bicep Validation** (used in workflows):

```bash
az bicep build --file infra/main.bicep --outdir /tmp  # Check syntax

```

**Deployment Validation** (used in PR and deployment workflows):

```bash
az deployment group validate \
  --resource-group "${RG}" \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam

```

**Parameter Validation**:

```bash
# Ensure bicepparam file is valid (Bicep CLI handles syntax)
az bicep build --file infra/main.bicep

```

**Workflow Testing Locally**:

```bash
# Install act: https://github.com/nektos/act
act pull_request -l  # List what runs on PR
act pull_request -j validate-bicep  # Test a specific job

```

## Multi-Environment Extension

To add new environments (staging, prod):

1. **Create parameter file**:

   ```bash
   cp infra/main.bicepparam infra/main.bicepparam.staging
   # Edit with environment-specific values (location, SKU, naming)
   ```

2. **Create GitHub environment**: Settings → Environments → New

3. **Update workflows** to parameterize environment selection
   (currently hardcoded to 'dev')

4. **Bicep conventions remain unchanged**: modules and structure scale to any
   environment via parameter files

## Azure Integration Notes

- **OIDC vs Static Credentials**: Uses federated credentials (no secrets stored in GitHub)
- **Token Exchange**: GitHub Actions issues OIDC token; Azure/login action exchanges for managed identity token
- **Scope**: Service principal has Contributor role at resource group level (least privilege by default)
- **Deployment Stacks**: ARM feature; manages resource lifecycle and prevents accidental deletions
- **Audit**: All deployments logged in Azure Activity Log; PR comments include what-if output for change review

## When Adding Resources

1. **Create module** in `infra/modules/resource.bicep` with @param inputs and outputs
2. **Add to variables.bicep** if naming conventions needed
3. **Import in main.bicep** via `module resourceModule 'modules/resource.bicep' = {...}`
4. **Update parameters** in all `main.bicepparam*` files
5. **Test locally**: `az bicep build` and `az deployment group validate`
6. **Document**: Update infra/README.md with new module purpose

## Testing PR Workflow

1. Create feature branch: `git checkout -b feature/test`
2. Modify `infra/` files (e.g., update parameter, add module)
3. Push and create PR
4. `deploy-what-if.yml` triggers automatically
5. Review what-if output in PR comment
6. Merge to main to trigger full deployment

## Troubleshooting

See **docs/AZURE_SETUP.md** for:

- OIDC token exchange failures
- Service principal permission issues
- Resource group not found errors
- Bicep validation failures

## Additional Resources

- [Azure Deployment Stacks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/deployment-stacks/overview)
- [GitHub OIDC Security](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Azure Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [GitHub Actions](https://docs.github.com/en/actions)
