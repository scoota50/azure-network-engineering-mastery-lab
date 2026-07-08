# ------------------------------------------------------------
# Resource Group
# ------------------------------------------------------------

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "location" {
  description = "Azure region used for the lab"
  value       = azurerm_resource_group.rg.location
}

# ------------------------------------------------------------
# Virtual Networks
# ------------------------------------------------------------

output "mgmt_vnet_name" {
  description = "Name of the Management VNet"
  value       = azurerm_virtual_network.mgmt_vnet.name
}

output "prod_vnet_name" {
  description = "Name of the Prod Spoke VNet"
  value       = azurerm_virtual_network.prod_vnet.name
}

output "dev_vnet_name" {
  description = "Name of the Dev Spoke VNet"
  value       = azurerm_virtual_network.dev_vnet.name
}

# ------------------------------------------------------------
# VM Private IPs
# ------------------------------------------------------------

output "prod_vm_private_ip" {
  description = "Private IP address of prod-vm-01"
  value       = azurerm_network_interface.prod_nic.private_ip_address
}

output "dev_vm_private_ip" {
  description = "Private IP address of dev-vm-01"
  value       = azurerm_network_interface.dev_nic.private_ip_address
}

# ------------------------------------------------------------
# Bastion
# ------------------------------------------------------------

output "bastion_name" {
  description = "Name of the Azure Bastion host"
  value       = azurerm_bastion_host.bastion.name
}

output "bastion_public_ip" {
  description = "Public IP address used by Azure Bastion"
  value       = azurerm_public_ip.bastion_pip.ip_address
}

# ------------------------------------------------------------
# Peering IDs
# ------------------------------------------------------------

output "mgmt_to_prod_peering_id" {
  description = "Management to Prod VNet peering ID"
  value       = azurerm_virtual_network_peering.mgmt_to_prod.id
}

output "prod_to_mgmt_peering_id" {
  description = "Prod to Management VNet peering ID"
  value       = azurerm_virtual_network_peering.prod_to_mgmt.id
}

output "mgmt_to_dev_peering_id" {
  description = "Management to Dev VNet peering ID"
  value       = azurerm_virtual_network_peering.mgmt_to_dev.id
}

output "dev_to_mgmt_peering_id" {
  description = "Dev to Management VNet peering ID"
  value       = azurerm_virtual_network_peering.dev_to_mgmt.id
}