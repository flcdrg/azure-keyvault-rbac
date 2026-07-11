# Migrating Azure Key Vaults from Access Policies to Role-based Access Control (RBAC)

This repository is a practical reference for teams migrating Azure Key Vault data-plane
authorization from legacy access policies to Azure role-based access control (RBAC).

It combines:

- Infrastructure as code examples in Bicep and Terraform
- Migration-safe role assignment patterns
- A simple C# app that reads secrets from multiple vaults to validate runtime behavior
- A Slidev deck for presenting the migration strategy and lessons learned

## Why this repo exists

Azure Key Vault is moving toward RBAC-first authorization for new vaults.
Many existing environments still use access policies, and migration can cause outages if
permission model changes happen before equivalent roles are in place.

This repo shows a safe migration sequence:

1. Inventory existing access policies.
2. Create equivalent RBAC role assignments.
3. Validate application access.
4. Switch vault permission model to RBAC.
5. Monitor and harden operations.

## What is included

- [infra](infra): Bicep templates and modules for Key Vault and RBAC migration patterns
- [terraform](terraform): Terraform implementation of the same migration concepts
- [app.cs](app.cs): file-based C# script that repeatedly reads secrets from two vaults
- [docs/talks](docs/talks): Slidev deck for the talk
	Don’t lose the keys to your Azure Key Vaults
- [docs/AZURE_SETUP.md](docs/AZURE_SETUP.md): environment and identity setup guidance

## High-level architecture

- One Key Vault managed through Bicep
- One Key Vault managed through Terraform
- Secret named shoosh in each vault with different values
- Identity access defined with both access policy and RBAC examples
- Application checks that read behavior matches current authorization state

## Typical usage

1. Deploy Bicep and/or Terraform resources.
2. Confirm secrets and role assignments exist.
3. Run [app.cs](app.cs) to read from both vaults in a loop.
4. Test migration scenarios by changing role assignments or permission models.
5. Use the Slidev deck in [docs/talks](docs/talks) to communicate migration approach.

## Who this is for

- Platform engineers managing shared Azure infrastructure
- Security and identity teams defining least-privilege access
- DevOps teams implementing migration-safe CI/CD patterns

## Notes

- Examples are designed for learning and migration rehearsal.
- Always validate role scopes and principal IDs before production rollout.
- Expect short propagation delays after RBAC role assignment changes.

