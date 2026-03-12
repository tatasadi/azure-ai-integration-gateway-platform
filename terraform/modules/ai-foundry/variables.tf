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

variable "enable_gpt4o" {
  description = "Enable GPT-4o model deployment"
  type        = bool
  default     = true
}

variable "enable_gpt35_turbo" {
  description = "Enable GPT-35-Turbo model deployment"
  type        = bool
  default     = false
}

variable "gpt4o_capacity" {
  description = "Capacity for GPT-4o deployment (in thousands of tokens per minute)"
  type        = number
  default     = 10
}

variable "gpt35_turbo_capacity" {
  description = "Capacity for GPT-35-Turbo deployment (in thousands of tokens per minute)"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
