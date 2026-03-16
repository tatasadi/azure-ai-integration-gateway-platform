# Alert: High Error Rate (>5% 5xx errors)
resource "azurerm_monitor_metric_alert" "high_error_rate" {
  name                = "alert-${var.project_name}-${var.environment}-high-error-rate"
  resource_group_name = var.resource_group_name
  scopes              = [var.apim_id]
  description         = "Alert when 5xx error rate exceeds 5%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ApiManagement/service"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5

    dimension {
      name     = "BackendResponseCode"
      operator = "Include"
      values   = ["5*"]
    }
  }

  action {
    action_group_id = var.action_group_id
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags["CreatedDate"]]
  }
}

# Alert: APIM Capacity (health indicator)
resource "azurerm_monitor_metric_alert" "apim_availability" {
  name                = "alert-${var.project_name}-${var.environment}-apim-availability"
  resource_group_name = var.resource_group_name
  scopes              = [var.apim_id]
  description         = "Alert when APIM capacity exceeds 80%"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ApiManagement/service"
    metric_name      = "Capacity"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = var.action_group_id
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags["CreatedDate"]]
  }
}

# Alert: High Latency (>5s P95)
resource "azurerm_monitor_metric_alert" "high_latency" {
  name                = "alert-${var.project_name}-${var.environment}-high-latency"
  resource_group_name = var.resource_group_name
  scopes              = [var.apim_id]
  description         = "Alert when P95 latency exceeds 5 seconds"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ApiManagement/service"
    metric_name      = "Duration"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 5000 # milliseconds
  }

  action {
    action_group_id = var.action_group_id
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags["CreatedDate"]]
  }
}

# Alert: Rate Limit Exhaustion
resource "azurerm_monitor_metric_alert" "rate_limit_exhaustion" {
  name                = "alert-${var.project_name}-${var.environment}-rate-limit"
  resource_group_name = var.resource_group_name
  scopes              = [var.apim_id]
  description         = "Alert when rate limit is frequently hit"
  severity            = 3
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ApiManagement/service"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10

    dimension {
      name     = "BackendResponseCode"
      operator = "Include"
      values   = ["429"]
    }
  }

  action {
    action_group_id = var.action_group_id
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags["CreatedDate"]]
  }
}

# Alert: Unauthorized Access Attempts
resource "azurerm_monitor_metric_alert" "unauthorized_access" {
  name                = "alert-${var.project_name}-${var.environment}-unauthorized"
  resource_group_name = var.resource_group_name
  scopes              = [var.apim_id]
  description         = "Alert when unauthorized access attempts spike"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ApiManagement/service"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 20

    dimension {
      name     = "BackendResponseCode"
      operator = "Include"
      values   = ["401", "403"]
    }
  }

  action {
    action_group_id = var.action_group_id
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags["CreatedDate"]]
  }
}

# Scheduled Query Alert: High Token Usage
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "high_token_usage" {
  name                 = "alert-${var.project_name}-${var.environment}-high-token-usage"
  resource_group_name  = var.resource_group_name
  location             = var.location
  scopes               = [var.application_insights_id]
  description          = "Alert when token usage is unusually high"
  severity             = 3
  enabled              = true
  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"

  criteria {
    query = <<-QUERY
      customMetrics
      | where name == "TokenUsage"
      | summarize TotalTokens = sum(value) by bin(timestamp, 5m)
      | where TotalTokens > 100000
    QUERY

    time_aggregation_method = "Total"
    threshold               = 1
    operator                = "GreaterThan"
    metric_measure_column   = "TotalTokens"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [var.action_group_id]
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags["CreatedDate"]]
  }
}

# Scheduled Query Alert: Cost Tracking Per Subscription
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "cost_threshold" {
  name                 = "alert-${var.project_name}-${var.environment}-cost-threshold"
  resource_group_name  = var.resource_group_name
  location             = var.location
  scopes               = [var.application_insights_id]
  description          = "Alert when daily cost per subscription exceeds threshold"
  severity             = 3
  enabled              = true
  evaluation_frequency = "PT1H"
  window_duration      = "P1D"

  criteria {
    query = <<-QUERY
      customMetrics
      | where name == "EstimatedCost"
      | summarize DailyCost = sum(value) by SubscriptionId = tostring(customDimensions.SubscriptionId)
      | where DailyCost > 100
    QUERY

    time_aggregation_method = "Total"
    threshold               = 1
    operator                = "GreaterThan"
    metric_measure_column   = "DailyCost"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [var.action_group_id]
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags["CreatedDate"]]
  }
}
