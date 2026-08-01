#building the backend platform that Front Door and API Management will eventually protect and expose.
# Gatekeeper Storage Account
resource "azurerm_storage_account" "gatekeeper" {
  name                     = "stgatekeepercv20260731"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.azure_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

# Gatekeeper Storage Container
resource "azurerm_storage_container" "gatekeeper_deployments" {
  name                  = "function-deployments"
  storage_account_id    = azurerm_storage_account.gatekeeper.id
  container_access_type = "private"
}

# Gatekeeper Service Plan
resource "azurerm_service_plan" "gatekeeper" {
  name                = "asp-gatekeeper-fc"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.azure_location
  os_type             = "Linux"
  sku_name            = "FC1"
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "gatekeeper" {
  name                = "law-gatekeeper"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Application Insights
resource "azurerm_application_insights" "gatekeeper" {
  name                = "appi-gatekeeper"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.gatekeeper.id
}