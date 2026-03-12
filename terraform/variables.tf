# Core Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "aigateway"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

# API Management Variables
variable "apim_publisher_name" {
  description = "Publisher name for API Management"
  type        = string
  default     = "AI Gateway Platform Team"
}

variable "apim_publisher_email" {
  description = "Publisher email for API Management"
  type        = string
}

variable "apim_sku_name" {
  description = "SKU name for API Management (Developer, Standard, Premium)"
  type        = string
  default     = "Developer_1"
  validation {
    condition     = contains(["Developer_1", "Standard_1", "Premium_1"], var.apim_sku_name)
    error_message = "APIM SKU must be one of: Developer_1, Standard_1, Premium_1."
  }
}

# AI Foundry Model Configuration
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

# Tags
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    Owner      = "platform-team"
    CostCenter = "engineering"
  }
}
