# Backend Configuration for Azure Storage
# This file configures remote state storage in Azure Blob Storage
#
# The backend configuration supports multiple environments (dev, staging, prod)
# by using different state files in the same storage account.
#
# State files are named:
#   - dev.terraform.tfstate
#   - staging.terraform.tfstate
#   - prod.terraform.tfstate
#
# Usage:
#   When running locally, use -backend-config flag to specify the environment:
#
#   terraform init -backend-config="key=dev.terraform.tfstate"
#   terraform init -backend-config="key=staging.terraform.tfstate"
#   terraform init -backend-config="key=prod.terraform.tfstate"
#
# The Azure DevOps pipeline handles this automatically per environment.

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform"
    storage_account_name = "sttfstateta"
    container_name       = "tfstate"
    key                  = "azure-ai-integration-dev.tfstate" # Default to dev, override via -backend-config
  }
}
