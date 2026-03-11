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

output "gpt5_mini_deployment_name" {
  description = "Name of the GPT-5-mini deployment"
  value       = var.enable_gpt5_mini ? azurerm_cognitive_deployment.gpt5_mini[0].name : null
}

output "gpt5_nano_deployment_name" {
  description = "Name of the GPT-5-nano deployment"
  value       = var.enable_gpt5_nano ? azurerm_cognitive_deployment.gpt5_nano[0].name : null
}
