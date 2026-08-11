# Azure Network Engineering Mastery Lab
## Pictures included

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

2026-08-07
Azure Firewall
- Added default route
- Proved default deny
- Added FQDN allow rule
- Verified allow/deny in Log Analytics

## Hybrid Connectivity — Site-to-Site IPsec VPN
**Date: 2026-08-07**

Built a simulated hybrid network between Azure and an on-premises environment using:

- Azure VPN Gateway
- Local Network Gateway
- Site-to-Site IPsec/IKEv2 connection
- Linux strongSwan VPN router
- Pre-shared key authentication

Traffic path:

```text
Simulated on-prem network
10.200.0.0/16
    ↓
strongSwan VPN router
    ↓ IPsec/IKEv2
Azure VPN Gateway
    ↓
vnet-mgmt
10.100.0.0/16

## Hybrid VPN Gateway Transit to Azure Spokes
**Date: 2026-08-08**

Extended the Site-to-Site IPsec VPN so the simulated on-premises network can reach both Azure spokes through the hub VPN Gateway.

### Configuration

- Added `10.101.0.0/16` and `10.102.0.0/16` to the strongSwan IPsec traffic selectors.
- Enabled `allow_gateway_transit = true` on hub-to-spoke peerings.
- Enabled `use_remote_gateways = true` on spoke-to-hub peerings.

### Verified Traffic Paths

```text
Simulated On-Prem
10.200.0.0/16
    ↓
strongSwan
    ↓
IPsec/IKEv2
    ↓
Azure VPN Gateway
    ↓
Hub VNet
    ├── Prod Spoke → 10.101.10.4
    └── Dev Spoke  → 10.102.10.4

    Verified:

On-prem → Prod: 0% packet loss
On-prem → Dev: 0% packet loss
Dev → On-prem: 0% packet loss
Troubleshooting Lesson

A working VPN tunnel does not automatically mean every Azure network is reachable.

For each network path, verify:

The VPN knows the destination CIDR.
Every intermediate resource allows and forwards the traffic.
The destination has a valid return path.

This exercise demonstrated VPN traffic selectors, hub gateway transit, spoke routing, and return-path troubleshooting.





## BGP Dynamic Routing and Hybrid DNS
**Date: 2026-08-09**

### BGP over Site-to-Site VPN

Extended the existing Site-to-Site IPsec VPN to support dynamic routing with BGP.

Configuration:

- Azure VPN Gateway ASN: `65010`
- Azure BGP peer IP: `10.100.0.94`
- Simulated on-prem ASN: `65020`
- On-prem BGP router: `10.200.1.4`
- FRRouting (FRR) used as the on-prem BGP daemon
- strongSwan continues to provide the IPsec tunnel

Verified Azure advertised the following networks to the on-prem router:

- `10.100.0.0/16` - Hub
- `10.101.0.0/16` - Prod spoke
- `10.102.0.0/16` - Dev spoke

Configured outbound BGP filtering so the on-prem router advertises only:

- `10.200.1.0/24`

Verified:

- BGP neighbor Established
- 3 Azure prefixes received
- 1 on-prem prefix advertised
- Azure learned `10.200.1.0/24` with origin `EBgp`
- On-prem-to-Prod connectivity successful
- On-prem-to-Dev connectivity successful

Troubleshooting included FRR daemon configuration, BGP route policy, next-hop resolution, and outbound route filtering.

### Hybrid DNS with Azure DNS Private Resolver

Deployed Azure DNS Private Resolver in the hub VNet.

Configuration:

- Resolver: `dnspr-mgmt`
- Inbound endpoint: `inbound-mgmt`
- Resolver subnet: `10.100.4.0/28`
- Resolver inbound IP: `10.100.4.4`
- Private DNS zone: `privatelink.azurewebsites.net`
- Function private endpoint: `10.101.20.4`

Verified DNS resolution from the simulated on-prem network across the Site-to-Site VPN:

`func-gatekeeper-cv-20260731.azurewebsites.net`
→ CNAME to the Private Link hostname
→ `10.101.20.4`

Verified HTTPS connectivity from simulated on-prem through the hybrid network path to the Function private endpoint with `HTTP 200 OK`.

This validated the complete path:

On-prem → BGP/IPsec → Azure DNS Private Resolver → Private DNS → Private Endpoint → Function App