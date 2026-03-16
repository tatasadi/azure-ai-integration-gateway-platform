# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project_name}-${var.environment}-${var.location}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags["CreatedDate"]]
  }
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "appi-${var.project_name}-${var.environment}-${var.location}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  retention_in_days   = 90
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags["CreatedDate"]]
  }
}

# Azure Monitor Action Group (for alerts)
resource "azurerm_monitor_action_group" "main" {
  name                = "ag-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  short_name          = "aigateway"
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags["CreatedDate"]]
  }

  email_receiver {
    name                    = "platform-team"
    email_address           = var.alert_email_address
    use_common_alert_schema = true
  }
}
