resource "azurerm_cdn_frontdoor_profile" "gatekeeper" {
  name                = "fd-gatekeeper-cv"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "gatekeeper" {
  name                     = "fd-gatekeeper-cv-20260731"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.gatekeeper.id
}

resource "azurerm_cdn_frontdoor_origin_group" "gatekeeper" {
  name                     = "og-gatekeeper"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.gatekeeper.id

  session_affinity_enabled = false

  health_probe {
    interval_in_seconds = 240
    path                = "/api/health"
    protocol            = "Https"
    request_type        = "GET"
  }

  load_balancing {
    additional_latency_in_milliseconds = 0
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "gatekeeper" {
  name                          = "origin-gatekeeper-function"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.gatekeeper.id

  enabled                        = true
  certificate_name_check_enabled = true

  host_name = azurerm_function_app_flex_consumption.gatekeeper.default_hostname

  origin_host_header = azurerm_function_app_flex_consumption.gatekeeper.default_hostname

  http_port  = 80
  https_port = 443
  priority   = 1
  weight     = 1000
}

resource "azurerm_cdn_frontdoor_route" "gatekeeper" {
  name                          = "route-gatekeeper"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.gatekeeper.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.gatekeeper.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.gatekeeper.id]

  enabled                = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]
  https_redirect_enabled = true
  forwarding_protocol    = "HttpsOnly"
  link_to_default_domain = true
}

output "frontdoor_hostname" {
  value = azurerm_cdn_frontdoor_endpoint.gatekeeper.host_name
}
