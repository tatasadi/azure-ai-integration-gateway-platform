# Azure AI Gateway - API Quick Reference

## Base URLs

| Environment | URL |
|-------------|-----|
| **Development** | `https://apim-aigateway-dev-eastus-01.azure-api.net` |
| **Staging** | `https://apim-aigateway-staging-eastus-01.azure-api.net` |
| **Production** | `https://apim-aigateway-prod-eastus-01.azure-api.net` |

## Authentication

All requests require a subscription key header:

```http
Ocp-Apim-Subscription-Key: YOUR_SUBSCRIPTION_KEY
```

## Rate Limits

- **Per Minute**: 100 requests
- **Per Day**: 10,000 requests

## Endpoints

### 1. Summarize Text

**Endpoint:** `POST /ai/summarize`

**Request:**
```json
{
  "text": "Text to summarize...",
  "max_length": 500,
  "style": "concise"
}
```

**Parameters:**
- `text` (required): 10-400,000 chars
- `max_length` (optional): 50-5,000 tokens (default: 500)
- `style` (optional): `concise`, `detailed`, `bullet_points` (default: `concise`)

**Response:**
```json
{
  "summary": "Summarized text...",
  "tokens_used": 156,
  "request_id": "uuid",
  "model": "gpt-4o"
}
```

**cURL Example:**
```bash
curl -X POST https://apim-aigateway-dev-eastus-01.azure-api.net/ai/summarize \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  -d '{"text": "Long text here...", "style": "concise"}'
```

---

### 2. Extract Information

**Endpoint:** `POST /ai/extract`

**Request:**
```json
{
  "text": "INVOICE #12345\nDate: 2026-03-11\nTotal: $500",
  "schema": {
    "type": "object",
    "properties": {
      "invoice_number": {"type": "string"},
      "date": {"type": "string", "format": "date"},
      "amount": {"type": "number"}
    }
  }
}
```

**Parameters:**
- `text` (required): 10-400,000 chars
- `schema` (required): JSON Schema for extraction

**Response:**
```json
{
  "extracted_data": {
    "invoice_number": "12345",
    "date": "2026-03-11",
    "amount": 500.00
  },
  "confidence": 0.98,
  "tokens_used": 234,
  "request_id": "uuid",
  "model": "gpt-4o"
}
```

**cURL Example:**
```bash
curl -X POST https://apim-aigateway-dev-eastus-01.azure-api.net/ai/extract \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  -d '{
    "text": "INVOICE #12345...",
    "schema": {
      "type": "object",
      "properties": {
        "invoice_number": {"type": "string"}
      }
    }
  }'
```

---

### 3. Health Check

**Endpoint:** `GET /ai/health`

**Response (200 OK):**
```json
{
  "status": "healthy",
  "timestamp": "2026-03-18T10:30:00Z",
  "services": {
    "api_gateway": "healthy",
    "ai_foundry": "healthy",
    "key_vault": "healthy"
  },
  "version": "1.0.0"
}
```

**Response (503 Degraded):**
```json
{
  "status": "degraded",
  "services": {
    "api_gateway": "healthy",
    "ai_foundry": "unhealthy"
  }
}
```

**cURL Example:**
```bash
curl -X GET https://apim-aigateway-dev-eastus-01.azure-api.net/ai/health \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY"
```

---

## Response Headers

All successful responses include:

| Header | Description | Example |
|--------|-------------|---------|
| `X-Request-Id` | Unique request identifier | `a1b2c3d4-e5f6-4789-0123-456789abcdef` |
| `X-Token-Usage` | Tokens consumed | `156` |
| `X-RateLimit-Remaining` | Requests remaining in period | `99` |
| `X-RateLimit-Reset` | Unix timestamp when limit resets | `1678531200` |

---

## HTTP Status Codes

| Code | Status | Description |
|------|--------|-------------|
| **200** | OK | Success |
| **400** | Bad Request | Invalid parameters |
| **401** | Unauthorized | Missing/invalid key |
| **429** | Too Many Requests | Rate limit exceeded |
| **500** | Internal Error | Server error |
| **503** | Service Unavailable | Backend unavailable |

---

## Error Response Format

```json
{
  "error": {
    "code": "ErrorCode",
    "message": "Human-readable message",
    "request_id": "uuid",
    "details": {}
  }
}
```

### Common Error Codes

| Code | Meaning |
|------|---------|
| `InvalidRequest` | Bad input parameters |
| `Unauthorized` | Authentication failed |
| `RateLimitExceeded` | Too many requests |
| `QuotaExceeded` | Daily quota exhausted |
| `InternalError` | Server error |
| `ServiceUnavailable` | Backend down |

---

## Quick Testing

### Using cURL

```bash
# Set variables
export API_URL="https://apim-aigateway-dev-eastus-01.azure-api.net"
export API_KEY="your-subscription-key"

# Health check
curl -X GET $API_URL/ai/health \
  -H "Ocp-Apim-Subscription-Key: $API_KEY"

# Summarize
curl -X POST $API_URL/ai/summarize \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: $API_KEY" \
  -d '{"text": "Your long text here...", "style": "concise"}'

# Extract
curl -X POST $API_URL/ai/extract \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: $API_KEY" \
  -d '{
    "text": "INVOICE #12345\nTotal: $500",
    "schema": {
      "type": "object",
      "properties": {
        "invoice_number": {"type": "string"},
        "total": {"type": "number"}
      }
    }
  }'
```

### Using PowerShell

```powershell
# Set variables
$apiUrl = "https://apim-aigateway-dev-eastus-01.azure-api.net"
$apiKey = "your-subscription-key"
$headers = @{
    "Ocp-Apim-Subscription-Key" = $apiKey
    "Content-Type" = "application/json"
}

# Health check
Invoke-RestMethod -Uri "$apiUrl/ai/health" -Headers $headers

# Summarize
$body = @{
    text = "Your long text here..."
    style = "concise"
} | ConvertTo-Json

Invoke-RestMethod -Uri "$apiUrl/ai/summarize" -Method Post -Headers $headers -Body $body

# Extract
$body = @{
    text = "INVOICE #12345`nTotal: `$500"
    schema = @{
        type = "object"
        properties = @{
            invoice_number = @{ type = "string" }
            total = @{ type = "number" }
        }
    }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Uri "$apiUrl/ai/extract" -Method Post -Headers $headers -Body $body
```

### Using Python

```python
import requests
import json

# Configuration
API_URL = "https://apim-aigateway-dev-eastus-01.azure-api.net"
API_KEY = "your-subscription-key"
headers = {
    "Ocp-Apim-Subscription-Key": API_KEY,
    "Content-Type": "application/json"
}

# Health check
response = requests.get(f"{API_URL}/ai/health", headers=headers)
print(response.json())

# Summarize
payload = {
    "text": "Your long text here...",
    "style": "concise"
}
response = requests.post(f"{API_URL}/ai/summarize", headers=headers, json=payload)
print(response.json())

# Extract
payload = {
    "text": "INVOICE #12345\nTotal: $500",
    "schema": {
        "type": "object",
        "properties": {
            "invoice_number": {"type": "string"},
            "total": {"type": "number"}
        }
    }
}
response = requests.post(f"{API_URL}/ai/extract", headers=headers, json=payload)
print(response.json())
```

---

## Troubleshooting

### 401 Unauthorized
- ✓ Check subscription key is correct
- ✓ Verify header name: `Ocp-Apim-Subscription-Key`
- ✓ Ensure subscription is active

### 429 Too Many Requests
- ✓ Wait 60 seconds before retry
- ✓ Check `Retry-After` header
- ✓ Monitor `X-RateLimit-Remaining`

### 503 Service Unavailable
- ✓ Check `/ai/health` endpoint
- ✓ Verify Azure service status
- ✓ Contact support with request ID

---

## Additional Resources

- **Full Documentation**: [README.md](README.md)
- **Postman Guide**: [POSTMAN-GUIDE.md](POSTMAN-GUIDE.md)
- **OpenAPI Spec**: [docs/openapi.yaml](docs/openapi.yaml)
- **Security Guide**: [docs/security.md](docs/security.md)
- **Architecture**: [docs/architecture.md](docs/architecture.md)

---

**Version:** 1.0.0
**Last Updated:** 2026-03-18
