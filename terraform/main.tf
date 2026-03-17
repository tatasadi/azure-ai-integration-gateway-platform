terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Backend configuration is defined in backend.tf
  # This allows for better organization and environment-specific state management
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Data sources
data "azurerm_client_config" "current" {}

# Resource Group Module
module "resource_group" {
  source = "./modules/resource-group"

  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = local.common_tags
}

# Managed Identity Module
module "managed_identity" {
  source = "./modules/managed-identity"

  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags
}

# Monitoring Module (Application Insights, Log Analytics)
module "monitoring" {
  source = "./modules/monitoring"

  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags
}

# Key Vault Module
module "key_vault" {
  source = "./modules/key-vault"

  project_name               = var.project_name
  environment                = var.environment
  location                   = var.location
  resource_group_name        = module.resource_group.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  managed_identity_id        = module.managed_identity.principal_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = local.common_tags
}

# Azure AI Foundry Module
module "ai_foundry" {
  source = "./modules/ai-foundry"

  project_name                  = var.project_name
  environment                   = var.environment
  location                      = var.location
  resource_group_name           = module.resource_group.name
  managed_identity_id           = module.managed_identity.id
  managed_identity_principal_id = module.managed_identity.principal_id
  log_analytics_workspace_id    = module.monitoring.log_analytics_workspace_id
  tags                          = local.common_tags

  # AI model configurations
  enable_gpt4o       = var.enable_gpt4o
  enable_gpt35_turbo = var.enable_gpt35_turbo
}

# API Management Module
module "api_management" {
  source = "./modules/api-management"

  project_name                             = var.project_name
  environment                              = var.environment
  location                                 = var.location
  resource_group_name                      = module.resource_group.name
  publisher_name                           = var.apim_publisher_name
  publisher_email                          = var.apim_publisher_email
  sku_name                                 = var.apim_sku_name
  managed_identity_id                      = module.managed_identity.id
  managed_identity_client_id               = module.managed_identity.client_id
  application_insights_id                  = module.monitoring.application_insights_id
  application_insights_instrumentation_key = module.monitoring.application_insights_instrumentation_key
  ai_foundry_endpoint                      = module.ai_foundry.endpoint
  log_analytics_workspace_id               = module.monitoring.log_analytics_workspace_id
  tags                                     = local.common_tags
}

# Monitoring Alerts and Dashboards Module (requires APIM to exist)
module "monitoring_alerts" {
  source = "./modules/monitoring-alerts"

  project_name            = var.project_name
  environment             = var.environment
  location                = var.location
  resource_group_name     = module.resource_group.name
  apim_id                 = module.api_management.id
  application_insights_id = module.monitoring.application_insights_id
  action_group_id         = module.monitoring.action_group_id
  tags                    = local.common_tags

  depends_on = [module.api_management, module.monitoring]
}

# Local variables
locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
      CreatedDate = timestamp()
    }
  )
}
