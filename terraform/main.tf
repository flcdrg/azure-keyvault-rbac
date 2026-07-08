data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  base_prefix      = join("-", compact([var.org_prefix, var.project_name, var.environment]))
  sanitized_prefix = join("", regexall("[a-z0-9-]", lower(local.base_prefix)))
  key_vault_name   = substr(join("-", compact([var.key_vault_name_prefix, local.sanitized_prefix, random_string.suffix.result])), 0, 24)

  full_secret_permissions = [
    "Backup",
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Restore",
    "Set",
  ]

  full_key_permissions = [
    "Backup",
    "Create",
    "Decrypt",
    "Delete",
    "Encrypt",
    "Get",
    "Import",
    "List",
    "Purge",
    "Recover",
    "Restore",
    "Sign",
    "UnwrapKey",
    "Update",
    "Verify",
    "WrapKey",
  ]

  full_certificate_permissions = [
    "Backup",
    "Create",
    "Delete",
    "DeleteIssuers",
    "Get",
    "GetIssuers",
    "Import",
    "List",
    "ListIssuers",
    "ManageContacts",
    "ManageIssuers",
    "Purge",
    "Recover",
    "Restore",
    "SetIssuers",
    "Update",
  ]

  full_storage_permissions = [
    "Backup",
    "Delete",
    "DeleteSAS",
    "Get",
    "GetSAS",
    "List",
    "ListSAS",
    "Purge",
    "Recover",
    "RegenerateKey",
    "Restore",
    "Set",
    "SetSAS",
    "Update",
  ]
}

resource "azurerm_key_vault" "this" {

  name                           = local.key_vault_name
  location                       = data.azurerm_resource_group.rg.location
  resource_group_name            = data.azurerm_resource_group.rg.name
  tenant_id                      = data.azurerm_client_config.current.tenant_id
  sku_name                       = var.key_vault_sku_name
  rbac_authorization_enabled     = false
  soft_delete_retention_days     = 7
  purge_protection_enabled       = false
  public_network_access_enabled  = true

  tags = {
    environment = var.environment
    projectName = var.project_name
    deployedBy  = "Terraform"
  }
}

resource "azurerm_key_vault_access_policy" "deployer" {
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Set"]
  key_permissions    = ["Create"]
  certificate_permissions = [
    "ManageContacts",
  ]
}

resource "azurerm_key_vault_access_policy" "additional" {
  for_each = toset(var.additional_access_policy_object_ids)

  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = each.value

  secret_permissions      = local.full_secret_permissions
  key_permissions         = local.full_key_permissions
  certificate_permissions = local.full_certificate_permissions
  storage_permissions     = local.full_storage_permissions
}