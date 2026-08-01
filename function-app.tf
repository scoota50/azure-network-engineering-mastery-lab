#building the backend platform that Front Door and API Management will eventually protect and expose.
# Funtion App 
resource "azurerm_function_app_flex_consumption" "gatekeeper" {
  name                = "func-gatekeeper-cv-20260731"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.gatekeeper.id

  storage_container_type = "blobContainer"

  storage_container_endpoint = join("", [
    azurerm_storage_account.gatekeeper.primary_blob_endpoint,
    azurerm_storage_container.gatekeeper_deployments.name
  ])

  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.gatekeeper.primary_access_key

  runtime_name    = "python"
  runtime_version = "3.12"

  instance_memory_in_mb  = 2048
  maximum_instance_count = 10

  public_network_access_enabled = true
  https_only                    = true

  site_config {
    application_insights_connection_string = azurerm_application_insights.gatekeeper.connection_string
    minimum_tls_version                    = "1.2"
  }
}

output "gatekeeper_function_hostname" {
  value = azurerm_function_app_flex_consumption.gatekeeper.default_hostname
}