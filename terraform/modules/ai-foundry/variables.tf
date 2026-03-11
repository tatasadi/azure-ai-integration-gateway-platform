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

variable "managed_identity_id" {
  description = "ID of the managed identity"
  type        = string
}

variable "managed_identity_principal_id" {
  description = "Principal ID of the managed identity"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for diagnostics"
  type        = string
}

variable "enable_gpt5_mini" {
  description = "Enable GPT-5-mini model deployment"
  type        = bool
  default     = true
}

variable "enable_gpt5_nano" {
  description = "Enable GPT-5-nano model deployment"
  type        = bool
  default     = false
}

variable "gpt5_mini_capacity" {
  description = "Capacity for GPT-5-mini deployment"
  type        = number
  default     = 10
}

variable "gpt5_nano_capacity" {
  description = "Capacity for GPT-5-nano deployment"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
