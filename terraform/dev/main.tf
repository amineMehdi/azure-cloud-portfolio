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

resource "azurerm_network_security_group" "app-nsg" {
  name = "app-nsg"
  location = azurerm_resource_group.RGDev.location
  resource_group_name = azurerm_resource_group.RGDev.name
}
resource "azurerm_subnet_network_security_group_association" "app-sub-nsg-association" {
  subnet_id                 = azurerm_subnet.appSubnet.id
  network_security_group_id = azurerm_network_security_group.app-nsg.id
}


resource "azurerm_subnet" "pe-subnet" {
  name = "pe-subnet"
  resource_group_name = azurerm_resource_group.RGDev.name
  virtual_network_name = azurerm_virtual_network.MainVNet.name
  address_prefixes = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "pe-nsg" {
  name = "pe-nsg"
  location = azurerm_resource_group.RGDev.location
  resource_group_name = azurerm_resource_group.RGDev.name

  security_rule {
    name = "allowHTTPS"
    priority = 100
    direction = "Outbound"
    access = "Allow"
    protocol = "Udp"
    destination_port_range = 443
  }

  tags = {
    project = "Portfolio"
    environment = "Dev"
  }
}
resource "azurerm_subnet_network_security_group_association" "pe-sub-nsg-association" {
  subnet_id                 = azurerm_subnet.pe-subnet.id
  network_security_group_id = azurerm_network_security_group.pe-nsg.id
}

resource "azurerm_subnet" "vpn-subnet" {
  name = "vpn-subnet"
  resource_group_name = azurerm_resource_group.RGDev.name
  virtual_network_name = azurerm_virtual_network.MainVNet.name
  address_prefixes = ["10.0.3.0/24"]
}

resource "azurerm_network_security_group" "vpn-nsg" {
  name = "vpn-nsg"
  location = azurerm_resource_group.RGDev.location
  resource_group_name = azurerm_resource_group.RGDev.name

  security_rule {
    name="allowTunnelVPS"
    priority = 100
    direction = "Outbound"
    access = "Allow"
    protocol = "Tcp"
    destination_port_range = 51820
    source_address_prefix = "10.2.3.4"
    
  }
}
resource "azurerm_subnet_network_security_group_association" "vpn-subnet-nsg-association" {
  subnet_id                 = azurerm_subnet.vpn-subnet.id
  network_security_group_id = azurerm_network_security_group.vpn-nsg.id
}