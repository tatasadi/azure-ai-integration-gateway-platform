variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "publisher_name" {
  description = "Publisher name for API Management"
  type        = string
}

variable "publisher_email" {
  description = "Publisher email for API Management"
  type        = string
}

variable "sku_name" {
  description = "SKU name for API Management"
  type        = string
  default     = "Developer_1"
}

variable "managed_identity_id" {
  description = "ID of the managed identity"
  type        = string
}

variable "application_insights_id" {
  description = "ID of Application Insights"
  type        = string
}

variable "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  type        = string
  sensitive   = true
}

variable "ai_foundry_endpoint" {
  description = "Endpoint URL of Azure AI Foundry"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for diagnostics"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
