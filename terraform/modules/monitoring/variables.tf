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

variable "alert_email_address" {
  description = "Email address for alert notifications"
  type        = string
  default     = "ai-gateway-alerts@example.com"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
