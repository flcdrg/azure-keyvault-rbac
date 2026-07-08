terraform {
  required_version = ">= 1.10.4"

  cloud {
    organization = "flcdrg"

    workspaces {
      name = "azure-keyvault-rbac"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0, < 5.0.0"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0, < 4.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}