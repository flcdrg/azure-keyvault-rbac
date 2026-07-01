# Infrastructure as Code (Bicep)

This directory contains the infrastructure definitions using Azure Bicep for Azure Deployment Stacks.

## Structure

- `main.bicep` - Main orchestration template
- `variables.bicep` - Shared variables and naming conventions
- `outputs.bicep` - Output definitions
- `modules/storage.bicep` - Storage account module
- `main.bicepparam` - Development environment parameters
- `main.bicepparam.staging` - Staging environment parameters (future)
- `main.bicepparam.prod` - Production environment parameters (future)

## Naming Conventions

Resources follow Azure Cloud Adoption Framework naming standards:

- **Storage Account**: `{orgprefix}{projectname}{environment}{unique}`
  (lowercase, 24 chars max)
- **Other Resources**: `{orgprefix}-{projectname}-{environment}-{resourcetype}`

Reference:
[Azure Resource Abbreviations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)

## Modular Design

Each module is independently deployable but orchestrated through `main.bicep`:

- **variables.bicep**: Computes naming conventions and common tags
- **modules/storage.bicep**: Deploys storage account with container for deployment stack state
- **outputs.bicep**: Defines outputs for workflow consumption

## Parameters

All parameters are defined in environment-specific bicepparam files. To add a new parameter:

1. Add the `@param` to `main.bicep`
2. Update all `main.bicepparam*` files with the new parameter
3. Update the GitHub Actions workflow to pass the parameter if needed

### Bicepparam Format

Bicepparam files use a cleaner syntax than JSON ARM templates:

```bicep
using './main.bicep'

param location = 'eastus'
param environment = 'dev'
param projectName = 'myapp'
param orgPrefix = 'acme'
param storageSkuName = 'Standard_LRS'
param storageAccessTier = 'Hot'
```

For more information, see:
[Microsoft Learn - Bicep parameter files](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameter-files?tabs=Bicep)

## Deployment

Deployment is managed by GitHub Actions workflows in `.github/workflows/`:

- `deploy-what-if.yml` - Validates changes on PR
- `deploy-stack.yml` - Deploys on main branch

See [main README](../README.md) for setup instructions.
