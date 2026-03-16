output "dashboard_id" {
  description = "ID of the Azure Portal dashboard"
  value       = azurerm_portal_dashboard.ai_gateway.id
}

output "dashboard_name" {
  description = "Name of the Azure Portal dashboard"
  value       = azurerm_portal_dashboard.ai_gateway.name
}

output "workbook_id" {
  description = "ID of the Application Insights workbook"
  value       = azurerm_application_insights_workbook.ai_gateway_detailed.id
}

output "workbook_name" {
  description = "Name of the Application Insights workbook"
  value       = azurerm_application_insights_workbook.ai_gateway_detailed.display_name
}

output "alert_ids" {
  description = "IDs of all configured alerts"
  value = {
    high_error_rate       = azurerm_monitor_metric_alert.high_error_rate.id
    apim_availability     = azurerm_monitor_metric_alert.apim_availability.id
    high_latency          = azurerm_monitor_metric_alert.high_latency.id
    rate_limit_exhaustion = azurerm_monitor_metric_alert.rate_limit_exhaustion.id
    unauthorized_access   = azurerm_monitor_metric_alert.unauthorized_access.id
    high_token_usage      = azurerm_monitor_scheduled_query_rules_alert_v2.high_token_usage.id
    cost_threshold        = azurerm_monitor_scheduled_query_rules_alert_v2.cost_threshold.id
  }
}
