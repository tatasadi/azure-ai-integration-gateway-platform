# Observability & Monitoring

## Overview

This document describes the comprehensive observability and monitoring solution for the Azure Enterprise AI Gateway platform. The implementation provides complete visibility into AI Gateway operations, costs, and performance through logging, metrics, alerting, and dashboards.

---

## Architecture Components

### 1. Core Monitoring Infrastructure

Located in: `terraform/modules/monitoring/`

**Resources:**
- **Log Analytics Workspace** - Central log aggregation (90-day retention)
- **Application Insights** - APM and custom metrics collection
- **Azure Monitor Action Group** - Alert notification routing

**Purpose:** Foundation for all observability features

### 2. Alerts & Dashboards

Located in: `terraform/modules/monitoring-alerts/`

**Resources:**
- **7 Azure Monitor Alerts** - Proactive issue detection
- **Azure Portal Dashboard** - Visual monitoring interface
- **Application Insights Workbook** - Detailed analytics

**Purpose:** Real-time alerting and visualization

### 3. APIM Policy Instrumentation

Located in: `apim-policies/`

**Files:**
- `global/base-policy.xml` - Request/response tracking
- `global/logging-policy.xml` - Centralized logging logic
- `operations/summarize-policy.xml` - AI operation metrics (summarize)
- `operations/extract-policy.xml` - AI operation metrics (extract)
- `operations/health-policy.xml` - Health check logging

**Purpose:** Custom metrics emission and detailed tracing

---

## Application Insights Integration

### APIM Diagnostic Settings

APIM sends gateway logs and metrics to Log Analytics:

```hcl
# terraform/modules/api-management/main.tf
resource "azurerm_monitor_diagnostic_setting" "apim_diagnostics" {
  target_resource_id         = azurerm_api_management.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "GatewayLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
```

### Application Insights Logger

APIM policies can log directly to Application Insights:

```hcl
# terraform/modules/api-management/main.tf
resource "azurerm_api_management_logger" "appinsights" {
  name                = "appinsights-logger"
  resource_id         = var.application_insights_id

  application_insights {
    instrumentation_key = var.application_insights_instrumentation_key
  }
}
```

### Custom Metrics

The platform tracks the following custom metrics:

| Metric Name | Description | Dimensions |
|-------------|-------------|------------|
| `TokenUsage` | Total tokens consumed | Operation, SubscriptionId, Model |
| `PromptTokens` | Input tokens | Operation, SubscriptionId |
| `CompletionTokens` | Output tokens | Operation, SubscriptionId |
| `EstimatedCost` | Calculated cost ($) | Operation, SubscriptionId |
| `OperationDuration` | Request duration (ms) | Operation, SubscriptionId |
| `OperationErrors` | Error count | Operation, SubscriptionId, ErrorCode |
| `HealthCheckRequests` | Health endpoint hits | Operation |

### Request Tracing Events

All operations emit structured trace events:

| Event Name | Trigger | Data Captured |
|------------|---------|---------------|
| `AIGatewayRequest` | Request start | RequestId, SubscriptionId, Operation, Method, URL, ClientIP |
| `AIGatewayResponse` | Request complete | RequestId, ResponseCode, Duration, ResponseSize, Success |
| `AIGatewayError` | Error occurred | RequestId, ErrorSource, ErrorReason, ErrorMessage |
| `SummarizeOperationStart` | Summarize start | RequestId, SubscriptionId, Timestamp |
| `SummarizeOperationComplete` | Summarize complete | Tokens, Cost, Duration, Model |
| `ExtractOperationStart` | Extract start | RequestId, SubscriptionId, Timestamp |
| `ExtractOperationComplete` | Extract complete | Tokens, Cost, Duration, Model |

---

## Logging Strategy

### Global Logging

The global logging policy (`apim-policies/global/logging-policy.xml`) tracks all requests:

**Request Logging:**
```xml
<trace source="AI-Gateway-{ApiName}" severity="information">
    EventName: AIGatewayRequest
    RequestId: {GUID}
    SubscriptionId: {subscription-id}
    Operation: {operation-name}
    Method: GET|POST
    URL: {full-url}
    ClientIP: {ip-address}
    Timestamp: {utc-datetime}
</trace>
```

**Response Logging:**
```xml
<trace source="AI-Gateway-{ApiName}" severity="information">
    EventName: AIGatewayResponse
    Duration: {milliseconds}
    ResponseCode: {http-status}
    ResponseSize: {bytes}
    Success: true|false
</trace>
```

### Operation-Specific Logging

Each AI operation (summarize, extract) includes:
- Token usage breakdown (prompt/completion)
- Cost estimation using GPT-4o pricing ($2.50/1M input, $10.00/1M output)
- Operation duration tracking
- Error logging with full context

### Custom Response Headers

All AI operations return metrics in response headers:

```
X-Token-Usage: {total-tokens}
X-Estimated-Cost: {cost-in-dollars}
X-Operation-Duration: {milliseconds}
X-Request-Id: {guid}
```

---

## Azure Monitor Alerts

Located in: `terraform/modules/monitoring-alerts/alerts.tf`

### Alert Configuration

| Alert Name | Type | Threshold | Severity | Window | Description |
|------------|------|-----------|----------|--------|-------------|
| **High Error Rate** | Metric | >5 errors | Warning (2) | 15min | 5xx errors exceed 5% |
| **APIM Capacity** | Metric | >80% | Error (1) | 15min | Gateway capacity exceeds 80% |
| **High Latency** | Metric | >5000ms | Warning (2) | 15min | P95 latency exceeds 5s |
| **Rate Limit Exhaustion** | Metric | >10 hits | Info (3) | 15min | 429 errors spike |
| **Unauthorized Access** | Metric | >20 hits | Warning (2) | 15min | 401/403 errors spike |
| **High Token Usage** | Query | >100K tokens | Info (3) | 15min | Unusual token consumption |
| **Cost Threshold** | Query | >$100/day | Info (3) | 1 day | Daily cost per subscription |

### Alert Action Group

**Notification Method:** Email
**Configuration:** Set via `alert_email_address` variable in `terraform.tfvars`
**Alert Schema:** Common Alert Schema (enabled)

### Customizing Alert Thresholds

Edit thresholds in `terraform/modules/monitoring-alerts/alerts.tf`:

```hcl
resource "azurerm_monitor_metric_alert" "high_error_rate" {
  threshold = 5  # Adjust based on your baseline
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "cost_threshold" {
  criteria {
    query = "| where DailyCost > 100"  # Adjust cost threshold
  }
}
```

---

## Dashboards

### Azure Portal Dashboard

The platform includes a pre-configured Azure Portal dashboard with 8 visualization tiles:

| Position | Tile | Visualization | Data Source |
|----------|------|---------------|-------------|
| Row 1, Col 1 | Request Volume (24h) | Time chart | APIM Requests metric |
| Row 1, Col 2 | Error Rate by Status | Time chart | APIM Requests (4xx, 5xx) |
| Row 2, Col 1 | Response Time | Time chart | APIM Duration metric |
| Row 2, Col 2 | Capacity | Time chart | APIM Capacity metric |
| Row 3, Col 1 | Token Consumption | Time chart | Custom metric: TokenUsage |
| Row 3, Col 2 | Requests by Operation | Pie chart | Custom events |
| Row 4, Col 1 | Top 10 Consumers | Bar chart | Custom events by Subscription |
| Row 4, Col 2 | Cost Trend (7 days) | Time chart | Custom metric: EstimatedCost |

**Access:** Azure Portal → Dashboards → `dashboard-{project}-{environment}`

### Application Insights Workbook

The workbook provides detailed analytics with pre-built queries:

**1. Request Summary by Operation**
```kusto
customEvents
| where name == "AIGatewayRequest"
| summarize
    TotalRequests = count(),
    AvgDuration = avg(Duration),
    Errors = countif(ResponseCode startswith "5" or "4"),
    SuccessRate = round(100.0 * countif(ResponseCode startswith "2") / count(), 2)
  by Operation, bin(timestamp, 1h)
```

**2. Token Usage Analysis**
```kusto
customMetrics
| where name == "TokenUsage"
| summarize
    TotalTokens = sum(value),
    AvgTokensPerRequest = avg(value),
    MaxTokens = max(value)
  by Operation, Model, bin(timestamp, 1h)
```

**3. Cost Analysis by Subscription**
```kusto
customMetrics
| where name == "EstimatedCost"
| summarize EstimatedCost = sum(value)
  by SubscriptionId, Operation, bin(timestamp, 1d)
  | order by EstimatedCost desc
```

**Access:** Azure Portal → Application Insights → Workbooks → `workbook-{project}-{environment}`

---

## Cost Tracking

### Pricing Model

The platform calculates estimated costs based on OpenAI pricing:

**GPT-4o Pricing:**
- Input tokens: $2.50 per 1M tokens
- Output tokens: $10.00 per 1M tokens

### Cost Calculation

Implemented in APIM policies:

```csharp
int promptTokens = context.Variables["promptTokens"];
int completionTokens = context.Variables["completionTokens"];
double inputCost = (promptTokens / 1000000.0) * 2.50;
double outputCost = (completionTokens / 1000000.0) * 10.00;
double estimatedCost = inputCost + outputCost;
```

### Cost Metrics

- **Metric:** `EstimatedCost`
- **Dimensions:** Operation, SubscriptionId
- **Aggregation:** Sum for daily/monthly totals
- **Alert:** Triggers when daily cost per subscription exceeds $100 (configurable)

---

## Common Kusto Queries

### 1. Request Volume by Operation
```kusto
customEvents
| where name == "AIGatewayRequest"
| summarize Requests = count() by Operation = tostring(customDimensions.Operation), bin(timestamp, 1h)
| render timechart
```

### 2. Error Rate Percentage
```kusto
customEvents
| where name == "AIGatewayResponse"
| extend Success = tostring(customDimensions.Success)
| summarize
    Total = count(),
    Errors = countif(Success == "false"),
    ErrorRate = round(100.0 * countif(Success == "false") / count(), 2)
  by bin(timestamp, 5m)
| render timechart
```

### 3. Average Response Time
```kusto
customEvents
| where name == "AIGatewayResponse"
| extend Duration = todouble(customDimensions.Duration)
| summarize AvgDuration = avg(Duration), P95Duration = percentile(Duration, 95) by bin(timestamp, 5m)
| render timechart
```

### 4. Token Usage by Model
```kusto
customMetrics
| where name == "TokenUsage"
| extend Model = tostring(customDimensions.Model)
| summarize TotalTokens = sum(value) by Model, bin(timestamp, 1h)
| render columnchart
```

### 5. Cost per Subscription (Daily)
```kusto
customMetrics
| where name == "EstimatedCost"
| extend SubscriptionId = tostring(customDimensions.SubscriptionId)
| summarize DailyCost = sum(value) by SubscriptionId, bin(timestamp, 1d)
| order by DailyCost desc
| take 10
```

### 6. Most Active Subscriptions
```kusto
customEvents
| where name == "AIGatewayRequest"
| extend SubscriptionId = tostring(customDimensions.SubscriptionId)
| summarize RequestCount = count() by SubscriptionId
| order by RequestCount desc
| take 10
```

### 7. Failed Requests by Error Code
```kusto
customEvents
| where name == "AIGatewayError"
| extend ErrorCode = tostring(customDimensions.ResponseCode)
| summarize ErrorCount = count() by ErrorCode, bin(timestamp, 1h)
| render barchart
```

### 8. Average Token Efficiency
```kusto
customMetrics
| where name == "TokenUsage"
| extend Operation = tostring(customDimensions.Operation)
| summarize
    TotalTokens = sum(value),
    RequestCount = count(),
    AvgTokensPerRequest = avg(value)
  by Operation
```

### 9. Latency Distribution
```kusto
customEvents
| where name == "AIGatewayResponse"
| extend Duration = todouble(customDimensions.Duration)
| summarize
    P50 = percentile(Duration, 50),
    P75 = percentile(Duration, 75),
    P95 = percentile(Duration, 95),
    P99 = percentile(Duration, 99)
  by bin(timestamp, 1h)
| render timechart
```

### 10. Rate Limit Hits Over Time
```kusto
requests
| where resultCode == 429
| summarize RateLimitHits = count() by bin(timestamp, 5m)
| render timechart
```

---

## Deployment

### Module Structure

```
terraform/
├── main.tf                          # Root orchestration
├── modules/
│   ├── monitoring/                  # Base monitoring infrastructure
│   │   ├── main.tf                  # Log Analytics, App Insights, Action Group
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── monitoring-alerts/           # Alerts & dashboards
│       ├── alerts.tf                # 7 alert rules
│       ├── dashboards.tf            # Portal dashboard + Workbook
│       ├── variables.tf
│       └── outputs.tf
```

### Deployment Order

The Terraform modules are configured with proper dependencies:

1. **Monitoring Module** - Creates base infrastructure (Log Analytics, Application Insights, Action Group)
2. **APIM Module** - References monitoring outputs for logging
3. **Monitoring Alerts Module** - Creates alerts and dashboards (depends on APIM ID)

### Deploy with Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

The modules will be created in the correct dependency order automatically.

---

## Configuration

### Email Notifications

Set alert email in `terraform/terraform.tfvars`:

```hcl
alert_email_address = "your-team@example.com"
```

### Log Retention

Default retention: **90 days**

To change, edit `terraform/modules/monitoring/main.tf`:

```hcl
resource "azurerm_log_analytics_workspace" "main" {
  retention_in_days = 90  # Options: 30, 60, 90, 120, etc.
}

resource "azurerm_application_insights" "main" {
  retention_in_days = 90  # Options: 30, 60, 90, 120, etc.
}
```

### Alert Thresholds

Customize thresholds in `terraform/modules/monitoring-alerts/alerts.tf` based on your usage patterns.

---

## Testing

### Generate Test Traffic

```bash
# Successful request
curl -X POST https://apim-{project}-{env}.azure-api.net/ai/summarize \
  -H "Ocp-Apim-Subscription-Key: {your-key}" \
  -H "Content-Type: application/json" \
  -d '{"text": "Test summarization request"}'

# Trigger rate limit (send many requests rapidly)
for i in {1..150}; do
  curl -X POST https://apim-{project}-{env}.azure-api.net/ai/summarize \
    -H "Ocp-Apim-Subscription-Key: {your-key}" \
    -H "Content-Type: application/json" \
    -d '{"text": "Test"}'
done

# Trigger unauthorized alert (no subscription key)
for i in {1..25}; do
  curl https://apim-{project}-{env}.azure-api.net/ai/summarize
done
```

### Verify Metrics

1. **Navigate to Application Insights:**
   ```
   Azure Portal → Application Insights → {your-app-insights} → Logs
   ```

2. **Run validation query:**
   ```kusto
   customMetrics
   | where name == "TokenUsage"
   | where timestamp > ago(15m)
   | take 10
   ```

3. **Check custom events:**
   ```kusto
   customEvents
   | where name startswith "AIGateway"
   | where timestamp > ago(15m)
   | take 10
   ```

### Verify Alerts

1. **Check alert status:**
   ```
   Azure Portal → Monitor → Alerts → Alert Rules
   ```

2. **View fired alerts:**
   ```
   Azure Portal → Monitor → Alerts → Alert History
   ```

3. **Verify email notifications received**

### Verify Dashboards

1. **Portal Dashboard:**
   ```
   Azure Portal → Dashboards → dashboard-{project}-{environment}
   ```

2. **Workbook:**
   ```
   Azure Portal → Application Insights → Workbooks → workbook-{project}-{environment}
   ```

---

## Troubleshooting

### Metrics Not Appearing

**Symptoms:** No custom metrics in Application Insights

**Solutions:**
1. Check APIM policy syntax:
   ```
   Azure Portal → API Management → APIs → {your-api} → Policies
   ```
2. Verify Application Insights instrumentation key is correct
3. Ensure APIM diagnostic settings are enabled
4. Generate test traffic and wait 5-10 minutes for metrics to appear

### Alerts Not Firing

**Symptoms:** No email notifications received

**Solutions:**
1. Verify email address in terraform.tfvars
2. Check action group configuration:
   ```
   Azure Portal → Monitor → Action Groups
   ```
3. Confirm email verification completed
4. Check alert rules are enabled:
   ```
   Azure Portal → Monitor → Alerts → Alert Rules
   ```
5. Verify alert conditions are being met (check metrics)

### Dashboard Shows No Data

**Symptoms:** Empty dashboard tiles

**Solutions:**
1. Generate test traffic to populate metrics
2. Wait 5-10 minutes for metrics to propagate
3. Refresh the dashboard
4. Verify time range selector is set correctly (default: 24h)
5. Check that APIM is running and receiving requests

### Policy Errors

**Symptoms:** APIM returns 500 errors

**Solutions:**
1. Check APIM trace logs:
   ```
   Azure Portal → API Management → APIs → Test → Enable tracing
   ```
2. Validate policy XML syntax
3. Check variable names match exactly (case-sensitive)
4. Ensure all required context objects are available

---

## Best Practices

### 1. Alert Tuning

- Establish baseline metrics for 1-2 weeks before setting final thresholds
- Adjust thresholds to reduce false positives
- Use different severity levels appropriately (Error=1, Warning=2, Info=3)

### 2. Cost Management

- Monitor the `EstimatedCost` metric daily
- Set budget alerts at appropriate levels for your organization
- Review top consumers regularly to identify optimization opportunities

### 3. Dashboard Customization

- Add custom tiles for your specific KPIs
- Create separate dashboards for different audiences (ops, business, security)
- Pin frequently used queries to the dashboard

### 4. Log Retention

- Balance retention period with storage costs
- Use 30 days for dev environments
- Use 90+ days for production
- Archive critical logs to cheaper storage if needed

### 5. Security Monitoring

- Monitor unauthorized access attempts (401/403 errors)
- Track unusual request patterns
- Alert on anomalous token usage
- Review audit logs regularly

---

## Monitoring Checklist

Use this checklist to ensure observability is fully operational:

- [ ] Log Analytics Workspace deployed and healthy
- [ ] Application Insights connected to APIM
- [ ] APIM diagnostic settings enabled (GatewayLogs + AllMetrics)
- [ ] All APIM policies updated with logging code
- [ ] Custom metrics appearing in Application Insights
- [ ] Custom events being logged
- [ ] All 7 alerts configured and enabled
- [ ] Action group configured with correct email
- [ ] Email verification completed
- [ ] Portal dashboard created and showing data
- [ ] Application Insights workbook accessible
- [ ] Test traffic generated successfully
- [ ] Alert notifications received during testing
- [ ] Response headers include custom metrics (X-Token-Usage, etc.)
- [ ] Cost tracking metrics validated

---

## Resources

### Azure Documentation

- [Azure Monitor Overview](https://learn.microsoft.com/en-us/azure/azure-monitor/)
- [Application Insights](https://learn.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)
- [API Management Policies](https://learn.microsoft.com/en-us/azure/api-management/api-management-policies)
- [Kusto Query Language (KQL)](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/)

### Related Documentation

- [Architecture Documentation](./architecture.md)
- [API Design](./api-design.md)
- [Operations Guide](./operations.md)

---

**Document Version:** 1.0
**Last Updated:** 2026-03-13
