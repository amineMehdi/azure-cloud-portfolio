terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = "~> 3.0.2"
    }
  }
  backend "azurerm" {
    resource_group_name = "CommonRG"
    storage_account_name = "commonsaportfolio"
    container_name = "common"
    key = "terraform/bootstrap.tfstate"
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name = var.resource_group_name
  location = "westeurope"
}

variable "resource_group_name" {
  type = string
  description = "Resource Group Name"
  default = "CommonRG"
}

variable "storage_account_container" {
  type = string
  description = "Storage Account Container"
  default = "common"
}

resource "azurerm_storage_account" "common_sa" {
  name = "commonsaportfolio"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  account_tier = "Standard"
  account_replication_type = "LRS"
  allow_nested_items_to_be_public = false

  tags = {
    project = "portfolio"
  }
}

resource "azurerm_storage_container" "terraformContainer" {
  name = var.storage_account_container
  storage_account_name = azurerm_storage_account.common_sa.name
  container_access_type = "private"
}