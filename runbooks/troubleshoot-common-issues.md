# Runbook: How to Troubleshoot Common Issues

## Overview

This runbook provides step-by-step troubleshooting procedures for common issues encountered with the Azure AI Integration Gateway platform.

**Owner**: Platform Team
**Support Contacts**:
- Email: platform-team@example.com
- Emergency: See [Operations Guide](../docs/operations.md#support--escalation)

---

## Table of Contents

1. [Authentication & Authorization Issues](#authentication--authorization-issues)
2. [Rate Limiting & Quota Issues](#rate-limiting--quota-issues)
3. [Performance & Latency Issues](#performance--latency-issues)
4. [Backend Service Errors](#backend-service-errors)
5. [Policy Execution Errors](#policy-execution-errors)
6. [Deployment Issues](#deployment-issues)
7. [Monitoring & Logging Issues](#monitoring--logging-issues)

---

## Quick Diagnostic Commands

### Health Check

```bash
# Set variables
APIM_NAME="apim-aigateway-prod-eastus-01"
RG_NAME="rg-aigateway-prod-eastus-01"
APIM_URL="https://${APIM_NAME}.azure-api.net"
SUBSCRIPTION_KEY="your-subscription-key"

# Test health endpoint
curl -X GET "${APIM_URL}/ai/health" \
  -H "Ocp-Apim-Subscription-Key: ${SUBSCRIPTION_KEY}" \
  -w "\nHTTP Status: %{http_code}\n"

# Check APIM status
az apim show \
  --name $APIM_NAME \
  --resource-group $RG_NAME \
  --query "{Name:name, State:provisioningState, Tier:sku.name}"
```

### Recent Errors

```kql
// Application Insights - Last 1 hour errors
exceptions
| where timestamp > ago(1h)
| summarize Count = count() by type, outerMessage
| order by Count desc

// APIM Gateway Logs
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| where ResponseCode >= 400
| summarize Count = count() by ResponseCode, OperationId
| order by Count desc
```

---

## Authentication & Authorization Issues

### Issue 1: 401 Unauthorized - Invalid Subscription Key

**Symptoms**:
- API returns 401 Unauthorized
- Error message: "Access denied due to invalid subscription key"

**Error Response**:
```json
{
  "statusCode": 401,
  "message": "Access denied due to invalid subscription key. Make sure to provide a valid key for an active subscription."
}
```

#### Diagnosis

**Step 1: Verify Subscription Key**
```bash
# Check if subscription exists and is active
az apim subscription show \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id "consumer-subscription-name" \
  --query "{State:state, PrimaryKey:primaryKey}"
```

**Step 2: Check Request Headers**
```bash
# Test with curl (verbose mode)
curl -v -X GET "${APIM_URL}/ai/health" \
  -H "Ocp-Apim-Subscription-Key: ${SUBSCRIPTION_KEY}"

# Look for the header in output:
# > Ocp-Apim-Subscription-Key: xxxxxxxx
```

**Step 3: Application Insights Query**
```kql
requests
| where timestamp > ago(1h)
| where resultCode == 401
| extend SubscriptionKey = tostring(customDimensions.["Subscription-Key"])
| project timestamp, url, resultCode, SubscriptionKey
| take 10
```

#### Resolution

**Option 1: Key is Incorrect**
```bash
# Retrieve correct subscription key
az apim subscription show \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id "consumer-subscription-name" \
  --query "{Primary:primaryKey, Secondary:secondaryKey}"

# Provide correct key to consumer
```

**Option 2: Subscription is Suspended**
```bash
# Reactivate subscription
az apim subscription update \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id "consumer-subscription-name" \
  --state active
```

**Option 3: Wrong Header Name**
```bash
# Verify consumer is using correct header name
# Correct: Ocp-Apim-Subscription-Key
# Incorrect: Authorization, X-API-Key, etc.

# Test with correct header
curl -X GET "${APIM_URL}/ai/health" \
  -H "Ocp-Apim-Subscription-Key: ${SUBSCRIPTION_KEY}"
```

---

### Issue 2: 403 Forbidden - Insufficient Permissions

**Symptoms**:
- API returns 403 Forbidden
- Subscription key is valid but access denied

**Error Response**:
```json
{
  "statusCode": 403,
  "message": "Forbidden. The subscription does not have access to this API."
}
```

#### Diagnosis

```bash
# Check subscription scope
az apim subscription show \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id "consumer-subscription-name" \
  --query "scope"

# Should be: /apis/ai-services-gateway
```

#### Resolution

```bash
# Update subscription scope to include the API
az apim subscription update \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id "consumer-subscription-name" \
  --scope "/apis/ai-services-gateway"
```

---

### Issue 3: Managed Identity Authentication Fails

**Symptoms**:
- 5xx errors when APIM calls Azure OpenAI
- Error: "Failed to acquire token"

#### Diagnosis

**Step 1: Check Managed Identity Assignment**
```bash
# Get APIM Managed Identity
MI_PRINCIPAL_ID=$(az apim show \
  --name $APIM_NAME \
  --resource-group $RG_NAME \
  --query "identity.principalId" \
  --output tsv)

echo "Managed Identity Principal ID: $MI_PRINCIPAL_ID"

# Check if identity exists
az identity show --ids "/subscriptions/<sub-id>/resourceGroups/$RG_NAME/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-aigateway-prod-eastus-01"
```

**Step 2: Verify RBAC Assignments**
```bash
# Check role assignments
az role assignment list \
  --assignee $MI_PRINCIPAL_ID \
  --all \
  --query "[].{Role:roleDefinitionName, Scope:scope}" \
  --output table

# Should include:
# - Cognitive Services User (on Azure OpenAI account)
# - Key Vault Secrets User (on Key Vault)
```

#### Resolution

**Grant Missing Role**:
```bash
# Get Azure OpenAI resource ID
OPENAI_ID=$(az cognitiveservices account show \
  --name "ai-aigateway-prod-eastus-01" \
  --resource-group $RG_NAME \
  --query "id" \
  --output tsv)

# Grant Cognitive Services User role
az role assignment create \
  --assignee $MI_PRINCIPAL_ID \
  --role "Cognitive Services User" \
  --scope $OPENAI_ID

# Wait 5 minutes for propagation
sleep 300

# Test again
curl -X POST "${APIM_URL}/ai/summarize" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: ${SUBSCRIPTION_KEY}" \
  -d '{"text": "Test text", "style": "concise"}'
```

---

## Rate Limiting & Quota Issues

### Issue 4: 429 Too Many Requests - Rate Limit Exceeded

**Symptoms**:
- API returns 429 Too Many Requests
- Error occurs after ~100 requests in short time

**Error Response**:
```json
{
  "statusCode": 429,
  "message": "Rate limit is exceeded. Try again in 43 seconds."
}
```

#### Diagnosis

**Check Rate Limit Configuration**:
```bash
# View base policy
cat apim-policies/global/base-policy.xml | grep -A 2 "rate-limit-by-key"

# Should show:
# <rate-limit-by-key calls="100" renewal-period="60" ...
```

**Application Insights Query**:
```kql
requests
| where timestamp > ago(1h)
| where resultCode == 429
| extend SubscriptionId = tostring(customDimensions.SubscriptionId)
| summarize Count = count() by SubscriptionId, bin(timestamp, 5m)
| render timechart
```

#### Resolution

**Option 1: Wait for Rate Limit Reset**
```bash
# Rate limit resets every 60 seconds
# Advise consumer to implement exponential backoff

# Example Python retry logic:
# import time
# for attempt in range(3):
#     response = requests.post(...)
#     if response.status_code == 429:
#         retry_after = int(response.headers.get('Retry-After', 60))
#         time.sleep(retry_after)
#     else:
#         break
```

**Option 2: Increase Rate Limit** (if justified):

Edit `apim-policies/global/base-policy.xml`:
```xml
<!-- Increase from 100 to 500 for specific subscription -->
<choose>
    <when condition="@(context.Subscription.Id == "high-volume-consumer")">
        <rate-limit-by-key calls="500" renewal-period="60"
            counter-key="@(context.Subscription.Id)" />
    </when>
</choose>
```

Deploy updated policy:
```bash
./scripts/update-apim-policies.sh prod
```

**Option 3: Request APIM Tier Upgrade**

See [Scale APIM Runbook](scale-apim.md) for higher throughput tiers.

---

### Issue 5: 429 Quota Exceeded

**Symptoms**:
- API returns 429 after working fine initially
- Error occurs after ~10,000 requests in a day

**Error Response**:
```json
{
  "statusCode": 429,
  "message": "Quota exceeded. Quota will be replenished in 08:32:15."
}
```

#### Diagnosis

**Check Quota Usage**:
```kql
requests
| where timestamp > ago(24h)
| extend SubscriptionId = tostring(customDimensions.SubscriptionId)
| summarize TotalRequests = count() by SubscriptionId
| order by TotalRequests desc
```

#### Resolution

**Option 1: Wait for Quota Reset**
- Daily quota resets at midnight UTC
- Advise consumer to wait or spread requests over time

**Option 2: Increase Quota**:

Edit `apim-policies/global/base-policy.xml`:
```xml
<!-- Increase daily quota from 10,000 to 50,000 -->
<quota-by-key calls="50000" renewal-period="86400"
    counter-key="@(context.Subscription.Id)" />
```

**Option 3: Create Additional Subscription**
```bash
# Create additional subscription for same consumer
az apim subscription create \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id "consumer-name-additional" \
  --display-name "Consumer Name - Additional" \
  --scope "/apis/ai-services-gateway" \
  --state active
```

---

## Performance & Latency Issues

### Issue 6: High Latency (P95 > 5 seconds)

**Symptoms**:
- Requests taking longer than expected
- Timeouts occurring

#### Diagnosis

**Step 1: Measure Latency Components**
```kql
requests
| where timestamp > ago(1h)
| extend ApiDuration = duration
| extend BackendDuration = toint(customDimensions.BackendDuration)
| extend PolicyDuration = ApiDuration - BackendDuration
| summarize
    AvgApiDuration = avg(ApiDuration),
    AvgBackendDuration = avg(BackendDuration),
    AvgPolicyDuration = avg(PolicyDuration),
    P95ApiDuration = percentile(ApiDuration, 95)
    by bin(timestamp, 5m)
| render timechart
```

**Step 2: Identify Bottleneck**
```kql
dependencies
| where timestamp > ago(1h)
| where type == "HTTP"
| summarize
    AvgDuration = avg(duration),
    P95Duration = percentile(duration, 95)
    by target
| order by P95Duration desc
```

#### Resolution

**Scenario A: Backend Service Slow**

If `BackendDuration` is high (> 3 seconds):

```bash
# Check Azure OpenAI status
az cognitiveservices account show \
  --name "ai-aigateway-prod-eastus-01" \
  --resource-group $RG_NAME \
  --query "properties.provisioningState"

# Check Azure service health
az rest --method get \
  --uri "https://management.azure.com/subscriptions/<sub-id>/providers/Microsoft.ResourceHealth/availabilityStatuses?api-version=2020-05-01"

# Consider:
# - Using faster model (GPT-3.5-Turbo instead of GPT-4o)
# - Reducing max_tokens in requests
# - Scaling Azure OpenAI quota
```

**Scenario B: Policy Processing Slow**

If `PolicyDuration` is high (> 1 second):

```bash
# Review policies for:
# - Complex transformations
# - Multiple logging statements
# - External service calls in policies

# Optimize policies:
# - Cache external lookups
# - Reduce transformation complexity
# - Minimize logging in hot path
```

**Scenario C: APIM Capacity Issues**

```bash
# Check APIM capacity
az monitor metrics list \
  --resource "/subscriptions/<sub-id>/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME" \
  --metric "Capacity" \
  --aggregation Average

# If capacity > 70%, consider scaling
# See: runbooks/scale-apim.md
```

---

### Issue 7: Timeouts (504 Gateway Timeout)

**Symptoms**:
- 504 Gateway Timeout errors
- Requests exceeding 30 seconds

**Error Response**:
```json
{
  "statusCode": 504,
  "message": "The gateway did not receive a response from the backend service within the expected time."
}
```

#### Diagnosis

```kql
requests
| where timestamp > ago(1h)
| where resultCode == 504
| extend BackendDuration = toint(customDimensions.BackendDuration)
| project timestamp, name, duration, BackendDuration
| order by duration desc
```

#### Resolution

**Option 1: Increase Timeout in Policy**

Edit operation policy (e.g., `summarize-policy.xml`):
```xml
<policies>
    <inbound>
        <base />
        <!-- Increase timeout to 60 seconds -->
        <send-request timeout="60">
            <!-- ... -->
        </send-request>
    </inbound>
</policies>
```

**Option 2: Optimize Request**
- Reduce `max_tokens` parameter
- Break large requests into smaller chunks
- Use streaming if supported

**Option 3: Check Backend Health**
```bash
# Check Azure OpenAI quota
az cognitiveservices account show \
  --name "ai-aigateway-prod-eastus-01" \
  --resource-group $RG_NAME \
  --query "properties.quotaUsage"
```

---

## Backend Service Errors

### Issue 8: 500 Internal Server Error

**Symptoms**:
- Sporadic 500 errors
- No clear pattern

**Error Response**:
```json
{
  "statusCode": 500,
  "message": "An error occurred while processing your request."
}
```

#### Diagnosis

**Step 1: Check Exception Logs**
```kql
exceptions
| where timestamp > ago(1h)
| project
    timestamp,
    type,
    outerMessage,
    operation_Name,
    customDimensions
| order by timestamp desc
```

**Step 2: Check APIM Gateway Logs**
```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| where ResponseCode == 500
| project
    TimeGenerated,
    OperationId,
    LastErrorMessage,
    LastErrorReason,
    BackendResponseCode
| order by TimeGenerated desc
```

**Step 3: Check Azure OpenAI Errors**
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.COGNITIVESERVICES"
| where TimeGenerated > ago(1h)
| where Category == "RequestResponse"
| where httpStatusCode_d >= 500
| project TimeGenerated, OperationName, httpStatusCode_d, message_s
```

#### Resolution

**Scenario A: Policy Error**
```bash
# Validate policy XML
xmllint --noout apim-policies/operations/summarize-policy.xml

# Check for:
# - Syntax errors
# - Invalid C# expressions
# - Null reference exceptions
```

**Scenario B: Backend Service Error**
```bash
# Check Azure service health
az rest --method get \
  --uri "https://management.azure.com/subscriptions/<sub-id>/providers/Microsoft.ResourceHealth/availabilityStatuses?api-version=2020-05-01" \
  | jq '.value[] | select(.properties.availabilityState != "Available")'

# If Azure OpenAI is degraded:
# - Wait for service recovery
# - Implement retry logic with exponential backoff
# - Consider failover to alternate region (if multi-region)
```

**Scenario C: Transformation Error**
```xml
<!-- Add error handling in policy -->
<set-body>@{
    try {
        var response = context.Response.Body.As<JObject>(preserveContent: true);
        // ... transformation logic
        return transformedResponse;
    } catch (Exception ex) {
        return new JObject(
            new JProperty("error", "Transformation failed"),
            new JProperty("details", ex.Message)
        ).ToString();
    }
}</set-body>
```

---

### Issue 9: 503 Service Unavailable

**Symptoms**:
- APIM returning 503
- All requests failing

#### Diagnosis

```bash
# Check APIM provisioning state
az apim show \
  --name $APIM_NAME \
  --resource-group $RG_NAME \
  --query "{State:provisioningState, Tier:sku.name}"

# Check recent deployments
az deployment group list \
  --resource-group $RG_NAME \
  --query "[0].{Name:name, State:properties.provisioningState, Timestamp:properties.timestamp}"
```

#### Resolution

**Scenario A: APIM is Updating**
- Wait for update to complete (usually 15-45 minutes)
- Check deployment logs for issues

**Scenario B: APIM Capacity Exhausted**
```bash
# Check capacity
az monitor metrics list \
  --resource "/subscriptions/<sub-id>/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME" \
  --metric "Capacity" \
  --aggregation Maximum

# If > 90%, scale immediately
# See: runbooks/scale-apim.md
```

**Scenario C: Backend Unreachable**
```bash
# Test backend connectivity
az apim backend list \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME

# Verify Azure OpenAI endpoint is accessible
curl -I "https://ai-aigateway-prod-eastus-01.openai.azure.com/"
```

---

## Policy Execution Errors

### Issue 10: Policy Validation Failed

**Symptoms**:
- Policy deployment fails
- Error: "Policy XML is invalid"

#### Diagnosis

```bash
# Validate XML syntax
xmllint --noout apim-policies/operations/summarize-policy.xml

# Look for:
# - Unclosed tags
# - Invalid characters
# - Malformed XML
```

#### Resolution

```bash
# Fix XML syntax errors
# Common issues:

# 1. Unclosed tags
# Bad:  <set-header name="X-Custom">
# Good: <set-header name="X-Custom" exists-action="override">

# 2. Unescaped special characters
# Bad:  <value>Price < $100</value>
# Good: <value>Price &lt; $100</value>

# 3. Invalid C# in expressions
# Bad:  @(context.Request.Body.text)
# Good: @(context.Request.Body.As<JObject>()["text"])

# Test policy locally before deployment
```

---

### Issue 11: Policy Expression Error

**Symptoms**:
- 500 errors with policy expression errors in logs

#### Diagnosis

```kql
traces
| where message contains "PolicyExpressionError"
| where timestamp > ago(1h)
| project timestamp, message, customDimensions
```

#### Resolution

```xml
<!-- Add null checks and try-catch -->
<set-body>@{
    var body = context.Request.Body?.As<JObject>(preserveContent: true);
    if (body == null) {
        return new JObject(new JProperty("error", "Invalid request body")).ToString();
    }

    var text = body["text"]?.ToString();
    if (string.IsNullOrEmpty(text)) {
        return new JObject(new JProperty("error", "Text field is required")).ToString();
    }

    // ... rest of transformation
}</set-body>
```

---

## Deployment Issues

### Issue 12: Terraform Apply Fails

**Symptoms**:
- `terraform apply` returns error
- Infrastructure not deployed

#### Common Errors

**Error 1: Resource Name Conflict**
```
Error: A resource with the ID already exists
```

**Resolution**:
```bash
# Import existing resource into state
terraform import azurerm_api_management.apim \
  "/subscriptions/<sub-id>/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME"

# Or use different resource name
```

**Error 2: Insufficient Permissions**
```
Error: Authorization failed
```

**Resolution**:
```bash
# Check service principal permissions
az role assignment list \
  --assignee "<service-principal-id>" \
  --scope "/subscriptions/<sub-id>/resourceGroups/$RG_NAME"

# Grant Contributor role if missing
az role assignment create \
  --assignee "<service-principal-id>" \
  --role "Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/$RG_NAME"
```

**Error 3: State Lock**
```
Error: Error acquiring the state lock
```

**Resolution**:
```bash
# Force unlock (use carefully)
terraform force-unlock "<lock-id>"

# Or wait for lock to release automatically
```

---

## Monitoring & Logging Issues

### Issue 13: No Logs in Application Insights

**Symptoms**:
- Requests occurring but no logs
- Application Insights shows no data

#### Diagnosis

```bash
# Check APIM diagnostic settings
az monitor diagnostic-settings list \
  --resource "/subscriptions/<sub-id>/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME" \
  --query "[].{Name:name, WorkspaceId:workspaceId}"
```

#### Resolution

**Enable Diagnostic Settings**:
```bash
# Get Application Insights instrumentation key
AI_KEY=$(az monitor app-insights component show \
  --app "appi-aigateway-prod-eastus-01" \
  --resource-group $RG_NAME \
  --query "instrumentationKey" \
  --output tsv)

# Configure APIM logger
az apim logger create \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --logger-id "appinsights-logger" \
  --logger-type "applicationInsights" \
  --credentials "instrumentationKey=$AI_KEY"
```

---

## Escalation

If issue cannot be resolved using this runbook:

1. **Collect Diagnostics**:
   ```bash
   # Save recent logs
   az monitor app-insights query \
     --app "appi-aigateway-prod-eastus-01" \
     --resource-group $RG_NAME \
     --analytics-query "requests | where timestamp > ago(1h)" \
     --output table > diagnostics-$(date +%Y%m%d-%H%M%S).txt
   ```

2. **Create Support Ticket**:
   - Email: platform-team@example.com
   - Include: Request ID, timestamps, error messages
   - Attach: diagnostics file

3. **Escalate to Azure Support** (if Azure service issue):
   ```bash
   # Create Azure support ticket via portal
   # Or call Azure support hotline
   ```

---

## References

- [Operations Guide](../docs/operations.md)
- [API Design Documentation](../docs/api-design.md)
- [APIM Troubleshooting](https://learn.microsoft.com/azure/api-management/api-management-troubleshoot)

---

**Runbook Version**: 1.0
**Last Updated**: 2026-03-17
**Owner**: Platform Team
