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
    key = "terraform/dev.tfstate"
  }
}