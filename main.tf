terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.81.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.10"
    }
  }
}

provider "azapi" {}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

# Mgmt Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-daily-challenge"
  location = var.azure_location
}

# Mgmt VNet/Hub Virtual Network
resource "azurerm_virtual_network" "mgmt_vnet" {
  name                = "vnet-mgmt"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.100.0.0/16"]

  tags = {
    environment = "Daily Challenge"
  }
}

# Mgmt VNet/Hub NVA VM
resource "azurerm_linux_virtual_machine" "nva_vm" {
  name                = "nva-vm-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.azure_location
  size                = "Standard_B1s"
  admin_username      = "adminuser"

  network_interface_ids = [
    azurerm_network_interface.nva_nic.id
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file(pathexpand("~/.ssh/firstprojectAZkey.pub"))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
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

#------------------------------------------------------------
# NSG ASSOCATIONS
#------------------------------------------------------------

resource "azurerm_subnet_network_security_group_association" "prod_nsg_assoc" {
  subnet_id                 = azurerm_subnet.prod_subnet.id
  network_security_group_id = azurerm_network_security_group.prod_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "dev_nsg_assoc" {
  subnet_id                 = azurerm_subnet.dev_subnet.id
  network_security_group_id = azurerm_network_security_group.dev_nsg.id
}

#------------------------------------------------------------
# Bastion Host and Public IP
#------------------------------------------------------------
# Public IP for Bastion Host
resource "azurerm_public_ip" "bastion_pip" {
  count               = var.enable_bastion ? 1 : 0
  name                = "pip-bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Bastion Host
resource "azurerm_bastion_host" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  name                = "bastion-host"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  tunneling_enabled   = true

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip[0].id
  }
}


# ------------------------------------------------------------
# Network Interfaces
# ------------------------------------------------------------

resource "azurerm_network_interface" "nva_nic" {
  name                = "nva-nic"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.rg.name

  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.nva_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.100.2.4"
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
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    project = "daily-challenge"
    lab     = "hub-spoke-network"
    owner   = "chris"
  }
}

# VNet Peering between Prod and Prod Spoke
resource "azurerm_virtual_network_peering" "mgmt_to_prod" {
  name                      = "peer-mgmt-to-prod"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.mgmt_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.prod_vnet.id

  allow_gateway_transit   = true
  allow_forwarded_traffic = true
}

resource "azurerm_virtual_network_peering" "prod_to_mgmt" {
  name                      = "peer-prod-to-mgmt"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.prod_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.mgmt_vnet.id

  use_remote_gateways     = true
  allow_forwarded_traffic = true
}

# VNet Peering between Management and Dev Spoke
resource "azurerm_virtual_network_peering" "mgmt_to_dev" {
  name                      = "peer-mgmt-to-dev"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.mgmt_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.dev_vnet.id

  allow_forwarded_traffic = true
  allow_gateway_transit   = true
}

resource "azurerm_virtual_network_peering" "dev_to_mgmt" {
  name                      = "peer-dev-to-mgmt"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.dev_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.mgmt_vnet.id

  allow_forwarded_traffic = true
  use_remote_gateways     = true
}

#------------------------------------------------------------
# Subnets
#------------------------------------------------------------

# NVA Subnet
resource "azurerm_subnet" "nva_subnet" {
  name                 = "nva-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.mgmt_vnet.name
  address_prefixes     = ["10.100.2.0/24"]
}

# Mgmt VNet/Hub Bastion Subnet
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet" # MUST be exactly this name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.mgmt_vnet.name
  address_prefixes     = ["10.100.0.0/26"] # MUST be /26 or larger
}

# Mgmt VNet/Hub Gateway Subnet
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
# Firewall
#------------------------------------------------------------

resource "azurerm_public_ip" "firewall_pip" {
  name                = "pip-azfw-mgmt"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall_policy" "main" {
  name                = "fwpol-mgmt"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"

  threat_intelligence_mode = "Alert"

  dns {
    proxy_enabled = true
  }
}

resource "azurerm_firewall" "main" {
  name                = "azfw-mgmt"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku_name = "AZFW_VNet"
  sku_tier = "Standard"

  firewall_policy_id = azurerm_firewall_policy.main.id

  ip_configuration {
    name                 = "azfw-ip-config"
    subnet_id            = azurerm_subnet.firewall_subnet.id
    public_ip_address_id = azurerm_public_ip.firewall_pip.id
  }
}

#------------------------------------------------------------
# App Gateway Block
#------------------------------------------------------------
# App gateway Subnet
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.mgmt_vnet.name
  address_prefixes     = ["10.100.3.0/24"]
}

#App Gateway Public IP
resource "azurerm_public_ip" "appgw_pip" {
  name                = "pip-appgw-gatekeeper"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  allocation_method = "Static"
  sku               = "Standard"
}

# App Gateway WAFv2
resource "azurerm_web_application_firewall_policy" "gatekeeper" {
  name                = "wafpol-gatekeeper"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  policy_settings {
    enabled = true
    mode    = "Detection"
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

# App Gateway
resource "azurerm_application_gateway" "gatekeeper" {
  name                = "appgw-gatekeeper"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  http2_enabled       = true
  firewall_policy_id  = azurerm_web_application_firewall_policy.gatekeeper.id

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_ip_configuration {
    name                 = "appgw-public-frontend"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  backend_address_pool {
    name = "function-backend-pool"

    fqdns = [
      "${azurerm_function_app_flex_consumption.gatekeeper.name}.azurewebsites.net"
    ]
  }

  probe {
    name                                      = "function-health-probe"
    protocol                                  = "Https"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
  }

  backend_http_settings {
    name                                = "function-https-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 30
    probe_name                          = "function-health-probe"
    pick_host_name_from_backend_address = true
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-public-frontend"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "route-to-function"
    priority                   = 100
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "function-backend-pool"
    backend_http_settings_name = "function-https-settings"
  }
}

#------------------------------------------------------------
# fake on-prem network
#------------------------------------------------------------
resource "azurerm_virtual_network" "onprem_vnet" {
  name                = "vnet-onprem-sim"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.200.0.0/16"]
}

resource "azurerm_subnet" "onprem_subnet" {
  name                 = "onprem-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.onprem_vnet.name
  address_prefixes     = ["10.200.1.0/24"]
}

resource "azurerm_public_ip" "onprem_vpn_pip" {
  name                = "pip-onprem-vpn"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "onprem_vpn_nic" {
  name                = "nic-onprem-vpn"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.onprem_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.200.1.4"
    public_ip_address_id          = azurerm_public_ip.onprem_vpn_pip.id
  }
}

resource "azurerm_linux_virtual_machine" "onprem_vpn" {
  name                = "onprem-vpn-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.onprem_vpn_nic.id
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
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}


#------------------------------------------------------------
# Azure VPN
#------------------------------------------------------------
resource "azurerm_public_ip" "vpn_gateway_pip" {
  name                = "pip-vpngw-mgmt"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  allocation_method = "Static"
  sku               = "Standard"
  zones             = ["1", "2", "3"]
}

resource "azurerm_virtual_network_gateway" "mgmt_vpn" {
  name                = "vpngw-mgmt"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  type       = "Vpn"
  vpn_type   = "RouteBased"
  sku        = "VpnGw1AZ"
  generation = "Generation1"

  active_active = false
  bgp_enabled   = false

  ip_configuration {
    name                          = "vpngw-ip-config"
    subnet_id                     = azurerm_subnet.gateway_subnet.id
    public_ip_address_id          = azurerm_public_ip.vpn_gateway_pip.id
    private_ip_address_allocation = "Dynamic"
  }
}

#IKE/IPSec inbound
resource "azurerm_network_security_group" "onprem_vpn" {
  name                = "nsg-onprem-vpn"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-IPsec"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_ranges    = ["500", "4500"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_local_network_gateway" "onprem" {
  name                = "lng-onprem-sim"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  gateway_address = azurerm_public_ip.onprem_vpn_pip.ip_address
  address_space   = ["10.200.0.0/16"]
}

resource "azurerm_network_interface_security_group_association" "onprem_vpn" {
  network_interface_id      = azurerm_network_interface.onprem_vpn_nic.id
  network_security_group_id = azurerm_network_security_group.onprem_vpn.id
}

#Gateway-to-Gateway VPN connection
#mgmt to on-prem 
resource "azurerm_virtual_network_gateway_connection" "onprem" {
  name                = "conn-mgmt-to-onprem"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.mgmt_vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem.id

  shared_key = var.vpn_shared_key
}

#------------------------------------------------------------
# IP ROUTES
#FROM DEV SPOKE TO PROD SPOKE VIA NVA
#------------------------------------------------------------
resource "azurerm_route_table" "dev_rt" {
  name                = "rt-dev-to-prod"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.rg.name

  route {
    name                   = "to-prod"
    address_prefix         = "10.101.10.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.100.2.4"
  }

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
  }
}

# DEV UDR association to DEV Subnet
resource "azurerm_subnet_route_table_association" "dev_rt_assoc" {
  subnet_id      = azurerm_subnet.dev_subnet.id
  route_table_id = azurerm_route_table.dev_rt.id
}

#Prod UDR to DEV Spoke via NVA [Subnet]
resource "azurerm_route_table" "prod_rt" {
  name                = "rt-prod-to-dev"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.rg.name

  route {
    name                   = "to-dev"
    address_prefix         = "10.102.10.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.100.2.4"
  }
}

# Prod UDR association to PROD Subnet
resource "azurerm_subnet_route_table_association" "prod_rt_assoc" {
  subnet_id      = azurerm_subnet.prod_subnet.id
  route_table_id = azurerm_route_table.prod_rt.id
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

resource "azurerm_firewall_policy_rule_collection_group" "dev_egress" {
  name               = "rcg-dev-egress"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 500

  application_rule_collection {
    name     = "allow-approved-websites"
    priority = 500
    action   = "Allow"

    rule {
      name              = "allow-microsoft"
      source_addresses  = ["10.102.10.0/24"]
      destination_fqdns = ["www.microsoft.com"]

      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "diag-azfw-to-law"
  target_resource_id         = azurerm_firewall.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.gatekeeper.id

  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "AZFWApplicationRule"
  }
}

#------------------------------------------------------------
# Private Endpoint
#------------------------------------------------------------
resource "azurerm_subnet" "private_endpoint_subnet" {
  name                 = "private-endpoint-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.prod_vnet.name
  address_prefixes     = ["10.101.20.0/24"]

  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_private_dns_zone" "function" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "function_to_mgmt" {
  name                  = "link-function-dns-to-mgmt"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.function.name
  virtual_network_id    = azurerm_virtual_network.mgmt_vnet.id
}

resource "azurerm_private_endpoint" "function" {
  name                = "pe-gatekeeper-function"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id


  private_service_connection {
    name                           = "psc-gatekeeper-function"
    private_connection_resource_id = azurerm_function_app_flex_consumption.gatekeeper.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "function-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.function.id]
  }
}

