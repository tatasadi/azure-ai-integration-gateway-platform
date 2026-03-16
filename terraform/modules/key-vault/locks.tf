# Resource lock for production Key Vault
# Prevents accidental deletion of Key Vault with critical secrets
resource "azurerm_management_lock" "keyvault_lock" {
  count      = var.environment == "prod" ? 1 : 0
  name       = "keyvault-lock"
  scope      = azurerm_key_vault.main.id
  lock_level = "CanNotDelete"
  notes      = "Prevents accidental deletion of production Key Vault"
}
