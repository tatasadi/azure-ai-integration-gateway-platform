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

variable "apim_id" {
  description = "ID of the API Management instance for monitoring"
  type        = string
}

variable "application_insights_id" {
  description = "ID of Application Insights"
  type        = string
}

variable "action_group_id" {
  description = "ID of the monitor action group"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
