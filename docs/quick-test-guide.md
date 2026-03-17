# Quick Testing Guide

## Your Deployed API Gateway

**Gateway URL**: `https://apim-aigateway-dev-swedencentral.azure-api.net`
**Resource Group**: `rg-aigateway-dev-swedencentral`
**APIM Service**: `apim-aigateway-dev-swedencentral`

---

## Step 1: Get Your Subscription Key

### Option A: Via Azure Portal (Easiest)

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to your API Management service: `apim-aigateway-dev-swedencentral`
3. In the left menu, click **"Subscriptions"**
4. Click on **"Built-in all-access subscription"** or create a new one
5. Click **"Show/hide keys"**
6. Copy the **Primary key** or **Secondary key**

### Option B: Via Azure CLI

```bash
# List all subscriptions
az rest --method get \
  --url "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-aigateway-dev-swedencentral/providers/Microsoft.ApiManagement/service/apim-aigateway-dev-swedencentral/subscriptions?api-version=2021-08-01" \
  --query "value[].{Name:properties.displayName, State:properties.state}" -o table

# Get the built-in subscription key
az rest --method post \
  --url "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-aigateway-dev-swedencentral/providers/Microsoft.ApiManagement/service/apim-aigateway-dev-swedencentral/subscriptions/master/listSecrets?api-version=2021-08-01" \
  --query "primaryKey" -o tsv
```

### Option C: Create a New Subscription

```bash
# Create a new subscription for testing
az rest --method put \
  --url "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-aigateway-dev-swedencentral/providers/Microsoft.ApiManagement/service/apim-aigateway-dev-swedencentral/subscriptions/test-subscription?api-version=2021-08-01" \
  --body '{
    "properties": {
      "displayName": "Test Subscription",
      "scope": "/subscriptions/'$(az account show --query id -o tsv)'/resourceGroups/rg-aigateway-dev-swedencentral/providers/Microsoft.ApiManagement/service/apim-aigateway-dev-swedencentral/apis",
      "state": "active"
    }
  }'

# Get the subscription key
az rest --method post \
  --url "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-aigateway-dev-swedencentral/providers/Microsoft.ApiManagement/service/apim-aigateway-dev-swedencentral/subscriptions/test-subscription/listSecrets?api-version=2021-08-01" \
  --query "primaryKey" -o tsv
```

---

## Step 2: Set Environment Variables

```bash
export APIM_BASE_URL="https://apim-aigateway-dev-swedencentral.azure-api.net"
export APIM_SUBSCRIPTION_KEY="your-key-here"  # Replace with your actual key
```

---

## Step 3: Test the API

### Test 1: Health Check

```bash
curl -H "Ocp-Apim-Subscription-Key: $APIM_SUBSCRIPTION_KEY" \
  "$APIM_BASE_URL/ai/health"
```

**Expected Response**:
```json
{
  "status": "healthy",
  "timestamp": "2026-03-16T...",
  "services": {
    "api_gateway": "ok",
    "ai_foundry": "ok"
  },
  "version": "1.0"
}
```

### Test 2: Summarize Text

```bash
curl -X POST "$APIM_BASE_URL/ai/summarize" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: $APIM_SUBSCRIPTION_KEY" \
  -d '{
    "text": "The Azure AI Integration Gateway provides centralized governance, security, rate limiting, and observability for AI services using Azure API Management and Azure AI Foundry.",
    "max_length": 50,
    "style": "concise"
  }'
```

**Expected Response**:
```json
{
  "summary": "Azure AI Gateway centralizes AI service management with governance and security.",
  "tokens_used": 45,
  "request_id": "...",
  "model": "gpt-5-mini"
}
```

### Test 3: Extract Information

```bash
curl -X POST "$APIM_BASE_URL/ai/extract" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: $APIM_SUBSCRIPTION_KEY" \
  -d '{
    "text": "INVOICE #12345, Date: March 11, 2026, Bill To: Acme Corp, Amount: $2,450.00",
    "schema": {
      "type": "object",
      "properties": {
        "invoice_number": {"type": "string"},
        "date": {"type": "string"},
        "customer": {"type": "string"},
        "amount": {"type": "number"}
      }
    }
  }'
```

**Expected Response**:
```json
{
  "extracted_data": {
    "invoice_number": "12345",
    "date": "March 11, 2026",
    "customer": "Acme Corp",
    "amount": 2450.00
  },
  "confidence": 0.95,
  "tokens_used": 78,
  "request_id": "...",
  "model": "gpt-5-mini"
}
```

---

## Step 4: Run Automated Tests

Once you have your subscription key, run the test suites:

### Smoke Tests

```bash
./tests/smoke/smoke_test.sh "$APIM_BASE_URL" "$APIM_SUBSCRIPTION_KEY"
```

### Integration Tests

```bash
cd tests
pip install -r requirements.txt

export APIM_BASE_URL="https://apim-aigateway-dev-swedencentral.azure-api.net"
export APIM_SUBSCRIPTION_KEY="your-key-here"

pytest integration/test_ai_gateway.py -v
```

### All Tests

```bash
pytest -v
```

---

## Troubleshooting

### Error: "Access denied due to missing subscription key"

**Cause**: No subscription key provided or invalid key

**Solution**:
1. Verify the key is set: `echo $APIM_SUBSCRIPTION_KEY`
2. Check the header is correct: `Ocp-Apim-Subscription-Key`
3. Get a new key from Azure Portal

### Error: Returns HTML instead of JSON

**Cause**: Wrong URL or hitting the Developer Portal

**Solution**:
1. Verify the URL: `https://apim-aigateway-dev-swedencentral.azure-api.net`
2. Ensure the path starts with `/ai/` (e.g., `/ai/health`)
3. Don't navigate to the URL in a browser without the subscription key

### Error: 404 Not Found

**Cause**: API might not be published or path is incorrect

**Solution**:
1. Verify API endpoints in Azure Portal
2. Check the API paths: `/ai/health`, `/ai/summarize`, `/ai/extract`
3. Ensure APIs are published to the appropriate product

### Error: 500 Internal Server Error

**Cause**: Backend service issue or policy error

**Solution**:
1. Check Application Insights for errors
2. Verify OpenAI service is accessible
3. Check APIM policy logs in Azure Portal

---

## Monitoring

View telemetry in Application Insights:

```bash
# Open Application Insights in Azure Portal
az portal show --resource-group rg-aigateway-dev-swedencentral \
  --resource-type Microsoft.Insights/components
```

Or query directly:

```bash
# Get recent requests
az monitor app-insights query \
  --app <app-insights-id> \
  --analytics-query "requests | where timestamp > ago(1h) | take 10"
```

---

## Next Steps

1. ✅ Get subscription key
2. ✅ Test health endpoint
3. ✅ Test summarize endpoint
4. ✅ Test extract endpoint
5. ✅ Run automated tests
6. ✅ Check Application Insights for telemetry
7. Review API documentation: [`docs/api-design.md`](./api-design.md)
8. Review testing guide: [`docs/testing-guide.md`](./testing-guide.md)

---

**Last Updated**: March 16, 2026
