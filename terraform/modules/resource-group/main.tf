resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}-${var.location}"
  location = var.location
  tags     = var.tags

  lifecycle {
    ignore_changes = [tags["CreatedDate"]]
  }
}
