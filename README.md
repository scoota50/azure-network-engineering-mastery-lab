# Azure Gatekeeper Lab

Terraform-based Azure lab demonstrating hub-and-spoke networking, centralized routing through an NVA, LDAP authentication, and a serverless Gatekeeper API platform.

## Business Scenario

A company needs to expose internal applications without allowing users to connect directly to protected backend systems.

The planned request flow is:

```text
User
  ↓
Azure Front Door
  ↓
API Management
  ↓
Gatekeeper Function App
  ↓
Protected backend service

Azure Front Door controls public ingress and filters web traffic.

The Gatekeeper Function App makes application-level decisions such as:

Is the caller authenticated?
Is the caller authorized?
Is the request valid?
Should the request be allowed or denied?
Which backend should receive the request?
Current Architecture
                       Azure
                         │
              Resource Group
              rg-daily-challenge
                         │
         ┌───────────────┴───────────────┐
         │                               │
     Hub VNet                      Gatekeeper Platform
     vnet-mgmt                     Azure Function App
     10.100.0.0/16                 Flex Consumption
         │                               │
     NVA VM                        Application Insights
     10.100.2.4                    Log Analytics
         │                               │
   ┌─────┴─────┐                  Deployment Storage
   │           │
Dev Spoke   Prod Spoke
10.102/16   10.101/16
   │           │
Dev VM      RHEL 389 Directory Server
               │
          LDAP / LDAPS
          SSSD / PAM
Implemented Components
Networking
Hub-and-spoke Azure network topology
Hub VNet: vnet-mgmt
Development spoke: vnet-dev-spoke
Production spoke: vnet-prod-spoke
Linux NVA for spoke-to-spoke routing
User-defined routes
IP forwarding
Network security groups
VNet peering with forwarded traffic enabled
Identity Lab
RHEL 389 Directory Server
LDAP and LDAPS connectivity
Ubuntu LDAP client
SSSD integration
PAM authentication
Successful login using LDAP user chris
Gatekeeper Platform
Azure Function App using Flex Consumption
Python runtime
Private deployment container
Application Insights
Log Analytics workspace
HTTPS-only access
Terraform-managed infrastructure
Health Endpoint

The first API endpoint is:

GET /api/health

Expected response:

{
  "status": "ok",
  "service": "gatekeeper"
}

The health endpoint verifies that:

The Function App is reachable
HTTPS works
Azure Functions discovered the route
The Python runtime can execute the function
The application can return an HTTP response
Application telemetry can be collected
Infrastructure and Application Separation

Terraform manages the Azure infrastructure:

Terraform
  ↓
Azure resources

Application code is packaged and deployed separately:

Python source
  ↓
ZIP deployment package
  ↓
Azure Function App

This separation mirrors a real CI/CD workflow where infrastructure and application deployments have different responsibilities.

Cost Controls
Virtual machines are deallocated when not in use
Azure Bastion is destroyed after administrative work
The Function App uses Flex Consumption
Always Ready instances are not enabled
Deployment artifacts and Terraform state are excluded from Git
Repository Structure
.
├── main.tf
├── variables.tf
├── outputs.tf
├── gatekeeper.tf
├── function-app.tf
├── terraform.tfvars.example
├── function/
│   ├── function_app.py
│   ├── host.json
│   └── requirements.txt
└── scripts/
Planned Next Steps
Deploy and test /api/health
Verify telemetry in Application Insights
Add Azure Front Door
Add API Management
Add authentication and authorization
Connect the Gatekeeper to protected backend services
Add GitHub Actions CI/CD
Move Terraform state to an Azure Storage remote backend
Security Notice

This repository intentionally excludes:

Terraform state files
Terraform plan files
Real variable values
SSH keys
Credentials
Deployment ZIP files