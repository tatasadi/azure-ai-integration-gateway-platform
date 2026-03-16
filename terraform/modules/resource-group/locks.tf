# Resource locks for production environment
# Prevents accidental deletion of critical resources
resource "azurerm_management_lock" "resource_group_lock" {
  count      = var.environment == "prod" ? 1 : 0
  name       = "resource-group-lock"
  scope      = azurerm_resource_group.main.id
  lock_level = "CanNotDelete"
  notes      = "Prevents accidental deletion of production resources"
}
