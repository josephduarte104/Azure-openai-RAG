terraform {
	
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>4.14.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 1.0"
    }
  }
}
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}