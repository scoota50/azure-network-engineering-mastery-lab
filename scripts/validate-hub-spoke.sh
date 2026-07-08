#!/usr/bin/env bash

set -euo pipefail

RG="rg-daily-challenge"

MGMT_VNET="vnet-daily-challenge"
PROD_VNET="vnet-prod-spoke"
DEV_VNET="vnet-dev-spoke"

PROD_SUBNET="prod-app-subnet"
DEV_SUBNET="dev-app-subnet"

BASTION_NAME="bastion-host"

PROD_VM="prod-vm-01"
DEV_VM="dev-vm-01"

PROD_NSG="prod-app-nsg"
DEV_NSG="dev-app-nsg"

pass() {
  echo "[PASS] $1"
}

fail() {
  echo "[FAIL] $1"
  exit 1
}

check_exists() {
  local description="$1"
  local command="$2"

  if eval "$command" >/dev/null 2>&1; then
    pass "$description"
  else
    fail "$description"
  fi
}

echo "Starting hub-and-spoke validation..."
echo

check_exists "Resource group exists: $RG" \
  "az group show --name $RG"

check_exists "Mgmt hub VNet exists: $MGMT_VNET" \
  "az network vnet show --resource-group $RG --name $MGMT_VNET"

check_exists "Prod spoke VNet exists: $PROD_VNET" \
  "az network vnet show --resource-group $RG --name $PROD_VNET"

check_exists "Dev spoke VNet exists: $DEV_VNET" \
  "az network vnet show --resource-group $RG --name $DEV_VNET"

check_exists "Azure Bastion exists: $BASTION_NAME" \
  "az network bastion show --resource-group $RG --name $BASTION_NAME"

echo

prod_private_ip=$(az vm list-ip-addresses \
  --resource-group "$RG" \
  --name "$PROD_VM" \
  --query "[0].virtualMachine.network.privateIpAddresses[0]" \
  -o tsv)

dev_private_ip=$(az vm list-ip-addresses \
  --resource-group "$RG" \
  --name "$DEV_VM" \
  --query "[0].virtualMachine.network.privateIpAddresses[0]" \
  -o tsv)

prod_public_ip=$(az vm list-ip-addresses \
  --resource-group "$RG" \
  --name "$PROD_VM" \
  --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" \
  -o tsv)

dev_public_ip=$(az vm list-ip-addresses \
  --resource-group "$RG" \
  --name "$DEV_VM" \
  --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" \
  -o tsv)

[[ -n "$prod_private_ip" ]] && pass "$PROD_VM private IP: $prod_private_ip" || fail "$PROD_VM has no private IP"
[[ -n "$dev_private_ip" ]] && pass "$DEV_VM private IP: $dev_private_ip" || fail "$DEV_VM has no private IP"

[[ -z "$prod_public_ip" ]] && pass "$PROD_VM has no public IP" || fail "$PROD_VM has public IP: $prod_public_ip"
[[ -z "$dev_public_ip" ]] && pass "$DEV_VM has no public IP" || fail "$DEV_VM has public IP: $dev_public_ip"

echo

mgmt_peerings=$(az network vnet peering list \
  --resource-group "$RG" \
  --vnet-name "$MGMT_VNET" \
  --query "length(@)" \
  -o tsv)

prod_peerings=$(az network vnet peering list \
  --resource-group "$RG" \
  --vnet-name "$PROD_VNET" \
  --query "length(@)" \
  -o tsv)

dev_peerings=$(az network vnet peering list \
  --resource-group "$RG" \
  --vnet-name "$DEV_VNET" \
  --query "length(@)" \
  -o tsv)

[[ "$mgmt_peerings" == "2" ]] && pass "$MGMT_VNET has 2 peerings" || fail "$MGMT_VNET peering count is $mgmt_peerings"
[[ "$prod_peerings" == "1" ]] && pass "$PROD_VNET has 1 peering" || fail "$PROD_VNET peering count is $prod_peerings"
[[ "$dev_peerings" == "1" ]] && pass "$DEV_VNET has 1 peering" || fail "$DEV_VNET peering count is $dev_peerings"

echo

check_exists "Prod NSG exists: $PROD_NSG" \
  "az network nsg show --resource-group $RG --name $PROD_NSG"

check_exists "Dev NSG exists: $DEV_NSG" \
  "az network nsg show --resource-group $RG --name $DEV_NSG"

prod_subnet_nsg=$(az network vnet subnet show \
  --resource-group "$RG" \
  --vnet-name "$PROD_VNET" \
  --name "$PROD_SUBNET" \
  --query "networkSecurityGroup.id" \
  -o tsv)

dev_subnet_nsg=$(az network vnet subnet show \
  --resource-group "$RG" \
  --vnet-name "$DEV_VNET" \
  --name "$DEV_SUBNET" \
  --query "networkSecurityGroup.id" \
  -o tsv)

[[ "$prod_subnet_nsg" == *"$PROD_NSG"* ]] && pass "$PROD_SUBNET has $PROD_NSG attached" || fail "$PROD_SUBNET NSG attachment is wrong"
[[ "$dev_subnet_nsg" == *"$DEV_NSG"* ]] && pass "$DEV_SUBNET has $DEV_NSG attached" || fail "$DEV_SUBNET NSG attachment is wrong"

echo
echo "Validation complete."