output "id" {
  description = "ID of the Cognitive Services account"
  value       = azurerm_cognitive_account.openai.id
}

output "name" {
  description = "Name of the Cognitive Services account"
  value       = azurerm_cognitive_account.openai.name
}

output "endpoint" {
  description = "Endpoint URL of the Cognitive Services account"
  value       = azurerm_cognitive_account.openai.endpoint
}

output "primary_key" {
  description = "Primary access key"
  value       = azurerm_cognitive_account.openai.primary_access_key
  sensitive   = true
}

output "gpt4o_deployment_name" {
  description = "Name of the GPT-4o deployment"
  value       = var.enable_gpt4o ? azurerm_cognitive_deployment.gpt4o[0].name : null
}

output "gpt35_turbo_deployment_name" {
  description = "Name of the GPT-35-Turbo deployment"
  value       = var.enable_gpt35_turbo ? azurerm_cognitive_deployment.gpt35_turbo[0].name : null
}
