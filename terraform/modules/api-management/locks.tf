# Resource lock for production APIM instance
# Prevents accidental deletion of the API Management instance
resource "azurerm_management_lock" "apim_lock" {
  count      = var.environment == "prod" ? 1 : 0
  name       = "apim-lock"
  scope      = azurerm_api_management.main.id
  lock_level = "CanNotDelete"
  notes      = "Prevents accidental deletion of production API Management instance"
}
