# Resource Group Outputs
output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.resource_group.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = module.resource_group.location
}

# Managed Identity Outputs
output "managed_identity_id" {
  description = "ID of the managed identity"
  value       = module.managed_identity.id
}

output "managed_identity_client_id" {
  description = "Client ID of the managed identity"
  value       = module.managed_identity.client_id
}

# Monitoring Outputs
output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = module.monitoring.application_insights_instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = module.monitoring.application_insights_connection_string
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = module.monitoring.log_analytics_workspace_id
}

# Key Vault Outputs
output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = module.key_vault.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = module.key_vault.vault_uri
}

# AI Foundry Outputs
output "ai_foundry_endpoint" {
  description = "Azure AI Foundry endpoint URL"
  value       = module.ai_foundry.endpoint
}

output "ai_foundry_key" {
  description = "Azure AI Foundry primary key"
  value       = module.ai_foundry.primary_key
  sensitive   = true
}

# API Management Outputs
output "apim_gateway_url" {
  description = "API Management gateway URL"
  value       = module.api_management.gateway_url
}

output "apim_portal_url" {
  description = "API Management developer portal URL"
  value       = module.api_management.developer_portal_url
}

output "apim_management_url" {
  description = "API Management management URL"
  value       = module.api_management.management_api_url
}

# Usage Instructions
output "getting_started" {
  description = "Instructions for getting started with the AI Gateway"
  value       = <<-EOT

    ========================================
    Azure AI Integration Gateway - Deployed
    ========================================

    Environment: ${var.environment}
    Region: ${var.location}

    API Gateway URL: ${module.api_management.gateway_url}
    Developer Portal: ${module.api_management.developer_portal_url}

    Next Steps:
    1. Access the Developer Portal to obtain your subscription key
    2. Test the health endpoint: GET ${module.api_management.gateway_url}/ai/health
    3. Review the API documentation at docs/api-design.md

    API Endpoints:
    - POST ${module.api_management.gateway_url}/ai/summarize
    - POST ${module.api_management.gateway_url}/ai/extract
    - GET  ${module.api_management.gateway_url}/ai/health

    Monitoring:
    - Application Insights: Azure Portal
    - Log Analytics Workspace ID: ${module.monitoring.log_analytics_workspace_id}

    ========================================
  EOT
}
