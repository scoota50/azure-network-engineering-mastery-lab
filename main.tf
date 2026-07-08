terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

# Mgmt Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-daily-challenge"
  location = var.azure_location
}

# Mgmt Hub Virtual Network
resource "azurerm_virtual_network" "mgmt_vnet" {
  name                = "vnet-daily-challenge"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.100.0.0/16"]

  tags = {
    environment = "Daily Challenge"
  }
}

# Dev App NSG
resource "azurerm_network_security_group" "dev_nsg" {
  name                = "dev-app-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH-From-Bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.100.0.0/26"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-VNet-To-VNet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = {
    project = "daily-challenge"
    lab     = "hub-spoke-network"
    owner   = "chris"
  }
}

resource "azurerm_network_security_group" "prod_nsg" {
  name                = "prod-app-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH-From-Bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.100.0.0/26"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-VNet-To-VNet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = {
    project = "daily-challenge"
    lab     = "hub-spoke-network"
    owner   = "chris"
  }
}

# NSG ASSOCATIONS

resource "azurerm_subnet_network_security_group_association" "prod_nsg_assoc" {
  subnet_id                 = azurerm_subnet.prod_subnet.id
  network_security_group_id = azurerm_network_security_group.prod_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "dev_nsg_assoc" {
  subnet_id                 = azurerm_subnet.dev_subnet.id
  network_security_group_id = azurerm_network_security_group.dev_nsg.id
}

# Mgmt Hub Public IP for Bastion Host
resource "azurerm_public_ip" "bastion_pip" {
  name                = "pip-bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Mgmt Hub Bastion Host
resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-host"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }
}

# Prod App NIC for Prod VM
resource "azurerm_network_interface" "prod_nic" {
  name                = "prod-vm-nic"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.prod_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Dev App NIC for Dev VM
resource "azurerm_network_interface" "dev_nic" {
  name                = "dev-vm-nic"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dev_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# ------------------------------------------------------------
# Linux VM - Prod
# ------------------------------------------------------------

resource "azurerm_linux_virtual_machine" "prod_vm" {
  name                = "prod-vm-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.azure_location
  size                = "Standard_B2s"
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.prod_nic.id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "9-lvm-gen2"
    version   = "latest"
  }

  tags = {
    project = "daily-challenge"
    lab     = "hub-spoke-network"
    owner   = "chris"
  }
}

# ------------------------------------------------------------
# Linux VM - Dev
# ------------------------------------------------------------

resource "azurerm_linux_virtual_machine" "dev_vm" {
  name                = "dev-vm-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.azure_location
  size                = "Standard_B2s"
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.dev_nic.id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "9-lvm-gen2"
    version   = "latest"
  }

  tags = {
    project = "daily-challenge"
    lab     = "hub-spoke-network"
    owner   = "chris"
  }
}

# VNet Peering between Management and Prod Spoke
resource "azurerm_virtual_network_peering" "mgmt_to_prod" {
  name                      = "peer-mgmt-to-prod"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.mgmt_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.prod_vnet.id
}

resource "azurerm_virtual_network_peering" "prod_to_mgmt" {
  name                      = "peer-prod-to-mgmt"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.prod_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.mgmt_vnet.id
}

# VNet Peering between Management and Dev Spoke
resource "azurerm_virtual_network_peering" "mgmt_to_dev" {
  name                      = "peer-mgmt-to-dev"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.mgmt_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.dev_vnet.id
}

resource "azurerm_virtual_network_peering" "dev_to_mgmt" {
  name                      = "peer-dev-to-mgmt"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.dev_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.mgmt_vnet.id
}

# Mgmt Hub Bastion Subnet
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet" # MUST be exactly this name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.mgmt_vnet.name
  address_prefixes     = ["10.100.0.0/26"] # MUST be /26 or larger
}

# Mgmt Hub Gateway Subnet
resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.mgmt_vnet.name
  address_prefixes     = ["10.100.0.64/27"]
}

# Mgmt Firewall Subnet
resource "azurerm_subnet" "firewall_subnet" {
  name                 = "AzureFirewallSubnet" # MUST be exactly this name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.mgmt_vnet.name
  address_prefixes     = ["10.100.1.0/26"]

}

# Mgmt Subnet
resource "azurerm_subnet" "mgmt_subnet" {
  name                 = "mgmt-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.mgmt_vnet.name
  address_prefixes     = ["10.100.10.0/24"]
}


#------------------------------------------------------------
# Prod Spoke Network
#------------------------------------------------------------

# Prod App VNet
resource "azurerm_virtual_network" "prod_vnet" {
  name                = "vnet-prod-spoke"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.101.0.0/16"]
}

# Prod App Subnet
resource "azurerm_subnet" "prod_subnet" {
  name                 = "prod-app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.prod_vnet.name
  address_prefixes     = ["10.101.10.0/24"]
}


#------------------------------------------------------------
# Dev Spoke Network
#------------------------------------------------------------

# Dev App VNet
resource "azurerm_virtual_network" "dev_vnet" {
  name                = "vnet-dev-spoke"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.102.0.0/16"]
}

# Dev App Subnet
resource "azurerm_subnet" "dev_subnet" {
  name                 = "dev-app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.dev_vnet.name
  address_prefixes     = ["10.102.10.0/24"]
}



