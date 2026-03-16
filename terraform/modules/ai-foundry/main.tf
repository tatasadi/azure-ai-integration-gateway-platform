# Azure Cognitive Services Account (Azure OpenAI)
resource "azurerm_cognitive_account" "openai" {
  name                          = "cog-${var.project_name}-${var.environment}-${var.location}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  kind                          = "OpenAI"
  sku_name                      = "S0"
  local_auth_enabled            = false
  public_network_access_enabled = true
  custom_subdomain_name         = "cog-${var.project_name}-${var.environment}-${var.location}"

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags["CreatedDate"]]
  }
}

# GPT-4o deployment
resource "azurerm_cognitive_deployment" "gpt4o" {
  count                = var.enable_gpt4o ? 1 : 0
  name                 = "gpt-4o"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-05-13"
  }

  scale {
    type     = "Standard"
    capacity = var.gpt4o_capacity
  }
}

# GPT-35-Turbo deployment
resource "azurerm_cognitive_deployment" "gpt35_turbo" {
  count                = var.enable_gpt35_turbo ? 1 : 0
  name                 = "gpt-35-turbo"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "gpt-35-turbo"
    version = "0613"
  }

  scale {
    type     = "Standard"
    capacity = var.gpt35_turbo_capacity
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
