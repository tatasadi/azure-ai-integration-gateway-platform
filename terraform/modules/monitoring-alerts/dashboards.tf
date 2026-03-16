# Azure Portal Dashboard for AI Gateway Monitoring
resource "azurerm_portal_dashboard" "ai_gateway" {
  name                = "dashboard-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags["CreatedDate"]]
  }

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          "0" = {
            position = {
              x       = 0
              y       = 0
              rowSpan = 4
              colSpan = 6
            }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name  = "ComponentId"
                  value = var.apim_id
                },
                {
                  name  = "TimeRange"
                  value = "P1D"
                }
              ]
              settings = {
                content = {
                  chartSettings = {
                    title         = "Request Volume (24h)"
                    visualization = "timechart"
                    metrics = [
                      {
                        resourceMetadata = {
                          id = var.apim_id
                        }
                        name            = "Requests"
                        namespace       = "Microsoft.ApiManagement/service"
                        aggregationType = "Total"
                      }
                    ]
                  }
                }
              }
            }
          }
          "1" = {
            position = {
              x       = 6
              y       = 0
              rowSpan = 4
              colSpan = 6
            }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name  = "ComponentId"
                  value = var.apim_id
                },
                {
                  name  = "TimeRange"
                  value = "P1D"
                }
              ]
              settings = {
                content = {
                  chartSettings = {
                    title         = "Error Rate by Status Code"
                    visualization = "timechart"
                    metrics = [
                      {
                        resourceMetadata = {
                          id = var.apim_id
                        }
                        name            = "Requests"
                        namespace       = "Microsoft.ApiManagement/service"
                        aggregationType = "Total"
                        dimensions = [
                          {
                            name     = "BackendResponseCode"
                            operator = "Include"
                            values   = ["4*", "5*"]
                          }
                        ]
                      }
                    ]
                  }
                }
              }
            }
          }
          "2" = {
            position = {
              x       = 0
              y       = 4
              rowSpan = 4
              colSpan = 6
            }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name  = "ComponentId"
                  value = var.apim_id
                },
                {
                  name  = "TimeRange"
                  value = "P1D"
                }
              ]
              settings = {
                content = {
                  chartSettings = {
                    title         = "Response Time (Average Duration)"
                    visualization = "timechart"
                    metrics = [
                      {
                        resourceMetadata = {
                          id = var.apim_id
                        }
                        name            = "Duration"
                        namespace       = "Microsoft.ApiManagement/service"
                        aggregationType = "Average"
                      }
                    ]
                  }
                }
              }
            }
          }
          "3" = {
            position = {
              x       = 6
              y       = 4
              rowSpan = 4
              colSpan = 6
            }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name  = "ComponentId"
                  value = var.apim_id
                },
                {
                  name  = "TimeRange"
                  value = "P1D"
                }
              ]
              settings = {
                content = {
                  chartSettings = {
                    title         = "API Gateway Availability (%)"
                    visualization = "timechart"
                    metrics = [
                      {
                        resourceMetadata = {
                          id = var.apim_id
                        }
                        name            = "Availability"
                        namespace       = "Microsoft.ApiManagement/service"
                        aggregationType = "Average"
                      }
                    ]
                  }
                }
              }
            }
          }
        }
      }
    }
  })
}

# Azure Workbook for detailed analysis
resource "azurerm_application_insights_workbook" "ai_gateway_detailed" {
  name                = "00000000-0000-0000-0000-000000000000"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "AI Gateway - Detailed Analysis"
  source_id           = lower(var.application_insights_id)
  category            = "workbook"
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags["CreatedDate"]]
  }

  data_json = jsonencode({
    version = "Notebook/1.0"
    items = [
      {
        type = 1
        content = {
          json = "## AI Gateway Analytics\n\nComprehensive analytics for AI Gateway operations, token usage, and cost tracking."
        }
      },
      {
        type = 3
        content = {
          version       = "KqlItem/1.0"
          query         = <<-QUERY
            customEvents
            | where name == "AIGatewayRequest"
            | extend Operation = tostring(customDimensions.Operation),
                     SubscriptionId = tostring(customDimensions.SubscriptionId),
                     ResponseCode = tostring(customDimensions.ResponseCode),
                     Duration = todouble(customDimensions.Duration)
            | summarize
                TotalRequests = count(),
                AvgDuration = avg(Duration),
                Errors = countif(ResponseCode startswith "5" or ResponseCode startswith "4"),
                SuccessRate = round(100.0 * countif(ResponseCode startswith "2") / count(), 2)
              by Operation, bin(timestamp, 1h)
            | order by timestamp desc
          QUERY
          size          = 0
          title         = "Request Summary by Operation"
          queryType     = 0
          resourceType  = "microsoft.insights/components"
          visualization = "table"
        }
      },
      {
        type = 3
        content = {
          version       = "KqlItem/1.0"
          query         = <<-QUERY
            customMetrics
            | where name == "TokenUsage"
            | extend Operation = tostring(customDimensions.Operation),
                     Model = tostring(customDimensions.Model)
            | summarize
                TotalTokens = sum(value),
                AvgTokensPerRequest = avg(value),
                MaxTokens = max(value)
              by Operation, Model, bin(timestamp, 1h)
            | order by timestamp desc
          QUERY
          size          = 0
          title         = "Token Usage Analysis"
          queryType     = 0
          resourceType  = "microsoft.insights/components"
          visualization = "table"
        }
      },
      {
        type = 3
        content = {
          version       = "KqlItem/1.0"
          query         = <<-QUERY
            customMetrics
            | where name == "EstimatedCost"
            | extend SubscriptionId = tostring(customDimensions.SubscriptionId),
                     Operation = tostring(customDimensions.Operation)
            | summarize
                EstimatedCost = sum(value)
              by SubscriptionId, Operation, bin(timestamp, 1d)
            | order by EstimatedCost desc
          QUERY
          size          = 0
          title         = "Cost Analysis by Subscription"
          queryType     = 0
          resourceType  = "microsoft.insights/components"
          visualization = "table"
        }
      }
    ]
  })
}
