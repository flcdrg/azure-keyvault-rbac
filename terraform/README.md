# Terraform Key Vault (Access Policies)

This Terraform configuration creates an Azure Key Vault in the same existing resource group used by the Bicep deployment.

State is stored in HCP Terraform Cloud, matching the pattern used in the sibling example repository.

## What it creates

- One `azurerm_key_vault` resource
- One deployer access policy for the currently authenticated principal
- Optional additional access policies for extra object IDs

## HCP Terraform backend

Backend is configured in `versions.tf` using Terraform Cloud:

- Organization: `flcdrg`
- Workspace: `azure-keyvault-rbac`

## Required input

- `resource_group_name`: Existing resource group name

In GitHub Actions, this is sourced from the existing repository secret:

- `RESOURCE_GROUP_NAME` -> `TF_VAR_resource_group_name`

## GitHub Actions workflows

- `.github/workflows/terraform.yml`: Pull request plan
- `.github/workflows/deploy.yml`: Apply on `main`
- `.github/workflows/terraform-destroy.yml`: Manual destroy

All Terraform workflows require:

- `TF_API_TOKEN` (HCP Terraform user/team token)

## Local usage

```bash
cd terraform
terraform init
terraform plan -var="resource_group_name=rg-your-existing-group"
terraform apply -var="resource_group_name=rg-your-existing-group"
```

## Notes

- `enable_rbac_authorization = false` is intentionally set so Key Vault uses access policies initially.
- You can later migrate to RBAC by changing this flag and replacing access policy resources.
