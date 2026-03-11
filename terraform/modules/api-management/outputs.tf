output "id" {
  description = "ID of the API Management instance"
  value       = azurerm_api_management.main.id
}

output "name" {
  description = "Name of the API Management instance"
  value       = azurerm_api_management.main.name
}

output "gateway_url" {
  description = "Gateway URL of the API Management instance"
  value       = azurerm_api_management.main.gateway_url
}

output "developer_portal_url" {
  description = "Developer portal URL"
  value       = azurerm_api_management.main.developer_portal_url
}

output "management_api_url" {
  description = "Management API URL"
  value       = azurerm_api_management.main.management_api_url
}

output "gateway_regional_url" {
  description = "Regional gateway URL"
  value       = azurerm_api_management.main.gateway_regional_url
}
