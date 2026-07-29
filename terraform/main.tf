terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = "~> 3.0.2"
    }
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
}