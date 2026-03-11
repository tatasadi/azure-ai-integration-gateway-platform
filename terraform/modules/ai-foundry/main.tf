# Azure Cognitive Services Account (Azure OpenAI)
resource "azurerm_cognitive_account" "openai" {
  name                = "cog-${var.project_name}-${var.environment}-${var.location}"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "OpenAI"
  sku_name            = "S0"

  identity {
    type = "SystemAssigned, UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  tags = var.tags
}

# GPT-5-mini deployment
resource "azurerm_cognitive_deployment" "gpt5_mini" {
  count                = var.enable_gpt5_mini ? 1 : 0
  name                 = "gpt-5-mini"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "gpt-5-mini"
    version = "2025-08-01"
  }

  sku {
    name     = "Standard"
    capacity = var.gpt5_mini_capacity
  }
}

# GPT-5-nano deployment
resource "azurerm_cognitive_deployment" "gpt5_nano" {
  count                = var.enable_gpt5_nano ? 1 : 0
  name                 = "gpt-5-nano"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "gpt-5-nano"
    version = "2025-08-01"
  }

  sku {
    name     = "Standard"
    capacity = var.gpt5_nano_capacity
  }
}

# Grant Cognitive Services User role to Managed Identity
resource "azurerm_role_assignment" "cognitive_services_user" {
  scope                = azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services User"
  principal_id         = var.managed_identity_principal_id
}

# Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "ai_diagnostics" {
  name                       = "ai-diagnostics"
  target_resource_id         = azurerm_cognitive_account.openai.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "Audit"
  }

  enabled_log {
    category = "RequestResponse"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
