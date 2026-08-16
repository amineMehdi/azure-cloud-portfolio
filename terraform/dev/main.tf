terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
  backend "azurerm" {
    resource_group_name  = "CommonRG"
    storage_account_name = "commonsaportfolio"
    container_name       = "common"
    key                  = "terraform/dev.tfstate"
  }
}
provider "azurerm" {
  features {}
}

variable "resource_group_name" {
  description = "Resource Group Name for DEV"
  type = string
  default = "RG-Dev"
}

variable "vnet_name" {
  description = "Virtual Network Name"
  type = string
  default = "main-vnet"
}

resource "azurerm_resource_group" "RGDev" {
 name = var.resource_group_name
 location = "westeurope"
}

resource "azurerm_virtual_network" "MainVNet" {
  name = var.vnet_name
  resource_group_name = azurerm_resource_group.RGDev.name
  location = azurerm_resource_group.RGDev.location
  address_space = [ "10.0.0.0/16" ]
  tags = {
    project = "Portfolio"
    environment = "Dev"
  }

}

resource "azurerm_subnet" "appSubnet" {
  name = "app-subnet"
  resource_group_name = azurerm_resource_group.RGDev.name
  virtual_network_name = azurerm_virtual_network.MainVNet.name
  address_prefixes = ["10.0.1.0/24"]

}