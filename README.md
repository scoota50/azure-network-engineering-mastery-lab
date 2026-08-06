# Azure Network Engineering Mastery Lab

A Terraform-built Azure environment for learning advanced Azure networking through deployment, packet-path analysis, deliberate failures, troubleshooting, and recovery.

## Current Architecture

- Hub VNet: `vnet-mgmt` — `10.100.0.0/16`
- Development spoke: `vnet-dev-spoke` — `10.102.0.0/16`
- Production spoke: `vnet-prod-spoke` — `10.101.0.0/16`
- Linux NVA: `nva-vm-01` — `10.100.2.4`
- Application Gateway WAF v2
- Azure Function App backend
- RHEL 389 Directory Server
- Terraform-managed infrastructure

## Current Traffic Paths

### Spoke-to-Spoke

```text
dev-vm-01
    ↓
Dev route table
    ↓
nva-vm-01
    ↓
Production spoke
    ↓
prod-vm-01

## Public Application Traffic

Client
    ↓
Application Gateway public IP
    ↓
HTTP listener
    ↓
Routing rule
    ↓
Azure Function App

## Verified Functionality
- Hub-and-spoke peering
- Spoke traffic routed through the NVA
- Linux IP forwarding
- User-defined routes
- LDAP and LDAPS connectivity
- LDAP user login through SSSD and PAM
- Application Gateway backend health
- End-to-end HTTP 200 OK through Application Gateway
- WAF policy in Detection mode
## Verified Funcationality
##6Aug26
- Azure Firewall deployed in the hub
- Dev subnet default route sends internet traffic through Azure Firewall
- Selective outbound access using FQDN application rules
- Azure Firewall default-deny behavior verified
- Firewall allow and deny logs sent to Log Analytics
- KQL used to confirm matched rules and default-deny decisions

Tools
- Terraform
- Azure CLI
- Bash
- PowerShell
- Git and GitHub
- Linux networking tools
- Azure Monitor and KQL

# COMPLETED FAILURE SCENARIOS
### Azure Firewall Default Deny
#6Aug26

- `www.microsoft.com` matched the allow rule and returned HTTP `200`
- `www.github.com` matched no rule and was denied
- Log Analytics confirmed the source IP, destination FQDN, rule, and action