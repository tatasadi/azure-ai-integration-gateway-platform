# API Management Instance
resource "azurerm_api_management" "main" {
  name                = "apim-${var.project_name}-${var.environment}-${var.location}"
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.sku_name

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  # Security: Enforce TLS 1.2 minimum
  min_api_version = "2021-08-01"

  security {
    enable_backend_ssl30  = false
    enable_backend_tls10  = false
    enable_backend_tls11  = false
    enable_frontend_ssl30 = false
    enable_frontend_tls10 = false
    enable_frontend_tls11 = false
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags["CreatedDate"]]
  }
}

# Application Insights Logger
resource "azurerm_api_management_logger" "appinsights" {
  name                = "appinsights-logger"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  resource_id         = var.application_insights_id

  application_insights {
    instrumentation_key = var.application_insights_instrumentation_key
  }
}

# Named Values (for configuration)
resource "azurerm_api_management_named_value" "ai_endpoint" {
  name                = "ai-foundry-endpoint"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  display_name        = "ai-foundry-endpoint"
  value               = var.ai_foundry_endpoint
}

# Backend for Azure OpenAI
resource "azurerm_api_management_backend" "azure_openai" {
  name                = "azure-openai-backend"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = var.ai_foundry_endpoint # HTTPS enforced via URL scheme (https://)

  # Security: Validate backend SSL certificate
  tls {
    validate_certificate_chain = true
    validate_certificate_name  = true
  }
}

# Diagnostic Settings for APIM
resource "azurerm_monitor_diagnostic_setting" "apim_diagnostics" {
  name                       = "apim-diagnostics"
  target_resource_id         = azurerm_api_management.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "GatewayLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
