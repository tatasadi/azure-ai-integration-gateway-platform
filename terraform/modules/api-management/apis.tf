# AI Services Gateway API
resource "azurerm_api_management_api" "ai_gateway" {
  name                  = "ai-services-gateway"
  resource_group_name   = var.resource_group_name
  api_management_name   = azurerm_api_management.main.name
  revision              = "1"
  display_name          = "AI Services Gateway"
  path                  = "ai"
  protocols             = ["https"]
  subscription_required = true

  description = "Enterprise AI Gateway providing text summarization, information extraction, and other AI services"
}

# Operation: Summarize
resource "azurerm_api_management_api_operation" "summarize" {
  operation_id        = "summarize"
  api_name            = azurerm_api_management_api.ai_gateway.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "Summarize Text"
  method              = "POST"
  url_template        = "/summarize"
  description         = "Summarizes long text into concise summaries using advanced AI models"

  request {
    description = "Text to summarize"

    representation {
      content_type = "application/json"
      example {
        name = "default"
        value = jsonencode({
          text       = "Long article text here..."
          max_length = 500
          style      = "concise"
        })
      }
    }
  }

  response {
    status_code = 200
    description = "Success"

    representation {
      content_type = "application/json"
      example {
        name = "default"
        value = jsonencode({
          summary     = "This is the summarized text..."
          tokens_used = 1234
          request_id  = "550e8400-e29b-41d4-a716-446655440000"
          model       = "gpt-4o"
        })
      }
    }
  }

  depends_on = [
    azurerm_api_management_api_policy.ai_gateway,
    azurerm_api_management_named_value.managed_identity_client_id,
    azurerm_api_management_backend.azure_openai
  ]
}

# Operation: Extract
resource "azurerm_api_management_api_operation" "extract" {
  operation_id        = "extract"
  api_name            = azurerm_api_management_api.ai_gateway.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "Extract Information"
  method              = "POST"
  url_template        = "/extract"
  description         = "Extracts structured information from unstructured text"

  request {
    description = "Text and schema for extraction"

    representation {
      content_type = "application/json"
      example {
        name = "default"
        value = jsonencode({
          text = "Invoice details here..."
          schema = {
            type = "object"
            properties = {
              invoice_number = { type = "string" }
              amount         = { type = "number" }
            }
          }
        })
      }
    }
  }

  response {
    status_code = 200
    description = "Success"

    representation {
      content_type = "application/json"
      example {
        name = "default"
        value = jsonencode({
          extracted_data = {
            invoice_number = "12345"
            amount         = 1500.50
          }
          confidence  = 0.95
          tokens_used = 890
          request_id  = "550e8400-e29b-41d4-a716-446655440000"
          model       = "gpt-4o"
        })
      }
    }
  }

  depends_on = [
    azurerm_api_management_api_policy.ai_gateway,
    azurerm_api_management_named_value.managed_identity_client_id,
    azurerm_api_management_backend.azure_openai
  ]
}

# Operation: Health Check
resource "azurerm_api_management_api_operation" "health" {
  operation_id        = "health"
  api_name            = azurerm_api_management_api.ai_gateway.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "Health Check"
  method              = "GET"
  url_template        = "/health"
  description         = "Verifies the API gateway and backend services are operational"

  response {
    status_code = 200
    description = "Healthy"

    representation {
      content_type = "application/json"
      example {
        name = "default"
        value = jsonencode({
          status    = "healthy"
          timestamp = "2026-03-11T10:30:00Z"
          services = {
            api_gateway = "healthy"
            ai_foundry  = "healthy"
            key_vault   = "healthy"
          }
          version = "1.0.0"
        })
      }
    }
  }

  depends_on = [
    azurerm_api_management_api_policy.ai_gateway
  ]
}

# API Diagnostic Settings
resource "azurerm_api_management_api_diagnostic" "ai_gateway" {
  identifier               = "applicationinsights"
  resource_group_name      = var.resource_group_name
  api_management_name      = azurerm_api_management.main.name
  api_name                 = azurerm_api_management_api.ai_gateway.name
  api_management_logger_id = azurerm_api_management_logger.appinsights.id

  sampling_percentage       = 100.0
  always_log_errors         = true
  log_client_ip             = true
  verbosity                 = "information"
  http_correlation_protocol = "W3C"

  frontend_request {
    body_bytes     = 8192
    headers_to_log = ["Ocp-Apim-Subscription-Key"]
  }

  frontend_response {
    body_bytes     = 8192
    headers_to_log = ["X-Request-Id", "X-Token-Usage"]
  }

  backend_request {
    body_bytes     = 8192
    headers_to_log = ["Authorization"]
  }

  backend_response {
    body_bytes     = 8192
    headers_to_log = ["Content-Type"]
  }
}

# API-level Policy (Global/Base Policy)
resource "azurerm_api_management_api_policy" "ai_gateway" {
  api_name            = azurerm_api_management_api.ai_gateway.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name

  xml_content = file("${path.module}/../../../apim-policies/global/base-policy.xml")
}

# Operation Policy: Summarize
resource "azurerm_api_management_api_operation_policy" "summarize" {
  api_name            = azurerm_api_management_api.ai_gateway.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  operation_id        = azurerm_api_management_api_operation.summarize.operation_id

  xml_content = file("${path.module}/../../../apim-policies/operations/summarize-policy.xml")

  depends_on = [
    azurerm_api_management_logger.appinsights,
    azurerm_api_management_backend.azure_openai,
    azurerm_api_management_api_policy.ai_gateway
  ]
}

# Operation Policy: Extract
resource "azurerm_api_management_api_operation_policy" "extract" {
  api_name            = azurerm_api_management_api.ai_gateway.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  operation_id        = azurerm_api_management_api_operation.extract.operation_id

  xml_content = file("${path.module}/../../../apim-policies/operations/extract-policy.xml")

  depends_on = [
    azurerm_api_management_logger.appinsights,
    azurerm_api_management_backend.azure_openai,
    azurerm_api_management_api_policy.ai_gateway
  ]
}

# Operation Policy: Health Check
resource "azurerm_api_management_api_operation_policy" "health" {
  api_name            = azurerm_api_management_api.ai_gateway.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  operation_id        = azurerm_api_management_api_operation.health.operation_id

  xml_content = file("${path.module}/../../../apim-policies/operations/health-policy.xml")

  depends_on = [
    azurerm_api_management_api_policy.ai_gateway
  ]
}
