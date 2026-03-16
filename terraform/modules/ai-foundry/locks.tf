# Resource lock for production Azure OpenAI instance
# Prevents accidental deletion of Azure OpenAI with deployed models
resource "azurerm_management_lock" "openai_lock" {
  count      = var.environment == "prod" ? 1 : 0
  name       = "openai-lock"
  scope      = azurerm_cognitive_account.openai.id
  lock_level = "CanNotDelete"
  notes      = "Prevents accidental deletion of production Azure OpenAI instance"
}
