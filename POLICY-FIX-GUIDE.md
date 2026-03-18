# APIM Policy Fix Guide

## Problem Description

When testing the AI Gateway API endpoints with Postman, you were receiving this error:

```json
{
    "error": {
        "message": "Missing required parameter: 'messages'.",
        "type": "invalid_request_error",
        "param": "messages",
        "code": "missing_required_parameter"
    }
}
```

## Root Cause

The APIM policies were **missing request/response body transformations**. Your API accepts a simplified format:

```json
{
  "text": "Text to summarize...",
  "style": "concise"
}
```

But Azure AI Foundry (OpenAI) expects the standard chat completions format:

```json
{
  "messages": [
    {"role": "system", "content": "You are a helpful assistant"},
    {"role": "user", "content": "Text to summarize..."}
  ],
  "max_tokens": 500,
  "temperature": 0.3
}
```

The policies were only handling routing, authentication, and logging—not the critical body transformation.

## What Was Fixed

### 1. Summarize Policy ([apim-policies/operations/summarize-policy.xml](apim-policies/operations/summarize-policy.xml))

**Added in `<inbound>` section:**
- Parse incoming request body to extract `text`, `max_length`, and `style` parameters
- Build a dynamic system prompt based on the requested style (concise/detailed/bullet_points)
- Transform the simplified request into OpenAI chat completions format with:
  - System message with summarization instructions
  - User message with the text to summarize
  - Appropriate parameters (temperature, max_tokens)

**Added in `<outbound>` section:**
- Extract the summary text from OpenAI's response (`choices[0].message.content`)
- Transform back to simplified format:
  ```json
  {
    "summary": "The summarized text...",
    "tokens_used": 156,
    "request_id": "uuid",
    "model": "gpt-4o"
  }
  ```

### 2. Extract Policy ([apim-policies/operations/extract-policy.xml](apim-policies/operations/extract-policy.xml))

**Added in `<inbound>` section:**
- Parse incoming request body to extract `text` and `schema` parameters
- Build a system prompt that includes the JSON schema for extraction
- Transform to OpenAI format with:
  - `response_format: {"type": "json_object"}` to ensure JSON output
  - Lower temperature (0.1) for more deterministic extraction
  - Clear instructions to return only valid JSON

**Added in `<outbound>` section:**
- Extract the JSON content from OpenAI's response
- Parse the JSON string into an object
- Transform back to simplified format:
  ```json
  {
    "extracted_data": {...},
    "confidence": 0.95,
    "tokens_used": 234,
    "request_id": "uuid",
    "model": "gpt-4o"
  }
  ```

## Key Changes Summary

| Aspect | Before | After |
|--------|--------|-------|
| **Request Format** | Passed through unchanged | Transformed to OpenAI format |
| **Response Format** | Raw OpenAI response | Simplified custom format |
| **Prompting** | No system prompts | Dynamic prompts based on parameters |
| **Validation** | None | Schema-based extraction guidance |

## Deployment Steps

### Option 1: Via Azure Portal

1. Navigate to your APIM instance in Azure Portal
2. Go to **APIs** → Select your AI Gateway API
3. For each operation (summarize, extract):
   - Click **Design** tab
   - Select the operation
   - Click **Policies** (code view: `</>`)
   - Replace the policy XML with the updated version
   - Click **Save**

### Option 2: Via Terraform

If you're deploying with Terraform, the updated policy files should be automatically applied on the next deployment:

```bash
cd terraform
terraform plan
terraform apply
```

Make sure your Terraform configuration references these policy files correctly.

### Option 3: Via Azure CLI

```bash
# Set variables
APIM_NAME="apim-aigateway-dev-eastus-01"
RESOURCE_GROUP="rg-aigateway-dev-eastus-01"
API_ID="ai-gateway-api"

# Update summarize operation policy
az apim api operation policy create \
  --resource-group $RESOURCE_GROUP \
  --service-name $APIM_NAME \
  --api-id $API_ID \
  --operation-id summarize \
  --xml-file apim-policies/operations/summarize-policy.xml

# Update extract operation policy
az apim api operation policy create \
  --resource-group $RESOURCE_GROUP \
  --service-name $APIM_NAME \
  --api-id $API_ID \
  --operation-id extract \
  --xml-file apim-policies/operations/extract-policy.xml
```

## Testing After Deployment

### 1. Test Summarize Endpoint

```bash
curl -X POST https://your-apim-url.azure-api.net/ai/summarize \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  -d '{
    "text": "The global economy showed signs of recovery in 2026 as technology sectors led growth across major markets.",
    "style": "concise"
  }'
```

**Expected Response:**
```json
{
  "summary": "Global economy recovers in 2026, driven by technology sector growth.",
  "tokens_used": 45,
  "request_id": "a1b2c3d4-...",
  "model": "gpt-4o"
}
```

### 2. Test Extract Endpoint

```bash
curl -X POST https://your-apim-url.azure-api.net/ai/extract \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  -d '{
    "text": "INVOICE #12345\nDate: March 11, 2026\nTotal: $500.00",
    "schema": {
      "type": "object",
      "properties": {
        "invoice_number": {"type": "string"},
        "total": {"type": "number"}
      }
    }
  }'
```

**Expected Response:**
```json
{
  "extracted_data": {
    "invoice_number": "12345",
    "total": 500.00
  },
  "confidence": 0.95,
  "tokens_used": 78,
  "request_id": "b2c3d4e5-...",
  "model": "gpt-4o"
}
```

### 3. Test with Postman

1. Open Postman
2. Import the collection: `postman-collection.json`
3. Import environment: `postman-environment-dev.json`
4. Update your subscription key in the environment
5. Run: **AI Operations** → **Summarize Text - Basic**
6. Verify you get a proper response with `summary`, `tokens_used`, etc.

## Troubleshooting

### Issue: Still getting "Missing required parameter: 'messages'"

**Possible Causes:**
1. Policies not deployed correctly
2. Wrong operation/API selected
3. Caching issues in APIM

**Solutions:**
```bash
# Verify policy is applied
az apim api operation policy show \
  --resource-group $RESOURCE_GROUP \
  --service-name $APIM_NAME \
  --api-id $API_ID \
  --operation-id summarize

# Check if policy contains the new transformation logic
# Look for: <set-body>@{ ... new JObject( ... messages ...
```

### Issue: Empty or null response

**Possible Causes:**
1. OpenAI response parsing error
2. Variable not set correctly
3. Authentication issues

**Solutions:**
- Check Application Insights for detailed traces
- Look for the custom trace events: `SummarizeOperationComplete`, `ExtractOperationComplete`
- Verify the `responseBody` variable contains expected data

### Issue: 500 Internal Server Error

**Possible Causes:**
1. Syntax error in policy XML
2. C# expression evaluation error
3. Type conversion error

**Solutions:**
```bash
# Validate XML syntax
xmllint --noout apim-policies/operations/summarize-policy.xml
xmllint --noout apim-policies/operations/extract-policy.xml

# Check APIM traces in Azure Portal
# Go to: APIM → APIs → Test → Enable tracing → Send request
# Review the trace output for errors
```

### Issue: Incorrect response format

**Possible Causes:**
1. Response transformation not applying
2. Variables not accessible in outbound section
3. JObject parsing errors

**Solutions:**
- Add trace statements to debug:
  ```xml
  <trace source="Debug" severity="information">
    @((string)context.Variables["summaryText"])
  </trace>
  ```
- Check if `requestId` variable from base policy is accessible
- Verify the OpenAI response structure matches expected format

## Policy Architecture

```
Request Flow:
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ Simplified Format: {"text": "...", "style": "..."}
       ▼
┌─────────────────────────────────────────┐
│  APIM Gateway                           │
│                                         │
│  1. Base Policy (auth, rate limit)     │
│  2. Operation Policy - Inbound:        │
│     • Parse request                     │
│     • Build system prompt               │
│     • Transform to OpenAI format        │
└──────┬──────────────────────────────────┘
       │ OpenAI Format: {"messages": [...], "max_tokens": ...}
       ▼
┌─────────────┐
│  Azure AI   │
│  Foundry    │
│  (GPT-4o)   │
└──────┬──────┘
       │ OpenAI Response: {"choices": [...], "usage": {...}}
       ▼
┌─────────────────────────────────────────┐
│  APIM Gateway                           │
│                                         │
│  3. Operation Policy - Outbound:       │
│     • Extract content & metrics         │
│     • Transform to simplified format    │
│  4. Base Policy (add headers)          │
└──────┬──────────────────────────────────┘
       │ Simplified Format: {"summary": "...", "tokens_used": ...}
       ▼
┌─────────────┐
│   Client    │
└─────────────┘
```

## Policy Customization

### Adjust Summarization Style

Edit `summarize-policy.xml`, modify the `systemPrompt` variable:

```xml
<set-variable name="systemPrompt" value="@{
    string style = (string)context.Variables[&quot;style&quot;];
    int maxLength = (int)context.Variables[&quot;maxLength&quot;];

    string styleInstruction = style switch {
        &quot;detailed&quot; => &quot;YOUR CUSTOM INSTRUCTION&quot;,
        &quot;bullet_points&quot; => &quot;YOUR CUSTOM INSTRUCTION&quot;,
        _ => &quot;YOUR CUSTOM INSTRUCTION&quot;
    };

    return $&quot;You are a text summarization assistant. {styleInstruction}&quot;;
}" />
```

### Adjust Model Parameters

Change temperature, max_tokens, etc. in the `<set-body>` section:

```xml
<set-body>@{
    // ...
    return new JObject(
        new JProperty("messages", ...),
        new JProperty("max_tokens", 1000),  // Increase max tokens
        new JProperty("temperature", 0.5),  // Adjust creativity
        // ...
    ).ToString();
}</set-body>
```

### Add Request Validation

Add validation in the `<inbound>` section before transformation:

```xml
<!-- Validate text length -->
<choose>
    <when condition="@(((string)context.Variables[&quot;inputText&quot;]).Length < 10)">
        <return-response>
            <set-status code="400" reason="Bad Request" />
            <set-body>@{
                return new JObject(
                    new JProperty("error", new JObject(
                        new JProperty("code", "InvalidRequest"),
                        new JProperty("message", "Text must be at least 10 characters")
                    ))
                ).ToString();
            }</set-body>
        </return-response>
    </when>
</choose>
```

## Monitoring & Observability

After deployment, monitor these metrics in Application Insights:

### Custom Traces

Look for these event names:
- `SummarizeOperationStart` / `SummarizeOperationComplete`
- `ExtractOperationStart` / `ExtractOperationComplete`

### Example KQL Query

```kql
traces
| where customDimensions.EventName in ("SummarizeOperationComplete", "ExtractOperationComplete")
| project
    timestamp,
    EventName = customDimensions.EventName,
    Operation = customDimensions.Operation,
    Duration = customDimensions.Duration,
    TokenUsage = customDimensions.TokenUsage,
    Cost = customDimensions.EstimatedCost,
    SubscriptionId = customDimensions.SubscriptionId
| order by timestamp desc
```

### Custom Headers

Check these response headers:
- `X-Token-Usage` - Total tokens consumed
- `X-Estimated-Cost` - Estimated cost in USD
- `X-Operation-Duration` - Processing time in milliseconds
- `X-Request-Id` - Unique request identifier

## Additional Resources

- **Postman Collection**: [postman-collection.json](postman-collection.json)
- **Postman Guide**: [POSTMAN-GUIDE.md](POSTMAN-GUIDE.md)
- **API Reference**: [API-QUICK-REFERENCE.md](API-QUICK-REFERENCE.md)
- **Main README**: [README.md](README.md)
- **OpenAPI Spec**: [docs/openapi.yaml](docs/openapi.yaml)

## Support

If you continue to experience issues:

1. Enable APIM tracing in Azure Portal (Test tab)
2. Check Application Insights traces for detailed logs
3. Verify the policy XML is correctly formatted
4. Test with simple, minimal requests first
5. Check the Azure AI Foundry endpoint is accessible

---

**Last Updated:** 2026-03-18
**Version:** 1.0.0
