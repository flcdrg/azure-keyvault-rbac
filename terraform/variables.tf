variable "resource_group_name" {
  type        = string
  description = "Name of the existing resource group used by the Bicep deployment"
  nullable    = false
}

variable "environment" {
  type        = string
  description = "Environment tag value"
  default     = "dev"
}

variable "project_name" {
  type        = string
  description = "Project tag value"
  default     = "kvdemo"
}

variable "org_prefix" {
  type        = string
  description = "Optional org prefix included in naming"
  default     = ""
}

variable "key_vault_name_prefix" {
  type        = string
  description = "Prefix for Key Vault name"
  default     = "kv"
}

variable "key_vault_sku_name" {
  type        = string
  description = "Key Vault SKU"
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku_name)
    error_message = "key_vault_sku_name must be one of: standard, premium"
  }
}

variable "additional_access_policy_object_ids" {
  type        = list(string)
  description = "Additional Entra object IDs that should have full data-plane permissions"
  default     = []
}