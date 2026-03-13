# Azure AI Integration Gateway - API Design

## Overview

This document defines the API specifications for the Azure AI Integration Gateway. The API provides a secure, rate-limited interface to AI services through Azure API Management.

## Base URL

```
https://{apim-instance-name}.azure-api.net
```

**Environments**:
- Development: `https://apim-aigateway-dev-eastus-01.azure-api.net`
- Staging: `https://apim-aigateway-staging-eastus-01.azure-api.net`
- Production: `https://apim-aigateway-prod-eastus-01.azure-api.net`

## Authentication

### Subscription Key

All requests must include a valid subscription key in the request header.

**Header Name**: `Ocp-Apim-Subscription-Key`

**Example**:
```http
GET /ai/health HTTP/1.1
Host: apim-aigateway-dev-eastus-01.azure-api.net
Ocp-Apim-Subscription-Key: your-subscription-key-here
```

**Obtaining a Subscription Key**:
1. Contact the platform team to request access
2. Receive subscription key via secure channel
3. Store key in Azure Key Vault or secure environment variables
4. Never commit keys to source control

## Rate Limits & Quotas

### Per-Subscription Limits

| Limit Type | Threshold | Period | Response Code |
|------------|-----------|--------|---------------|
| Rate Limit | 100 requests | 60 seconds | 429 Too Many Requests |
| Daily Quota | 10,000 requests | 24 hours | 429 Too Many Requests |

### Rate Limit Response

When rate limit is exceeded, the API returns:

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 60

{
  "error": {
    "code": "RateLimitExceeded",
    "message": "Rate limit exceeded. Please retry after 60 seconds.",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

## API Operations

### 1. Text Summarization

Summarizes long text into concise summaries using advanced AI models.

**Endpoint**: `POST /ai/summarize`

**Request Headers**:
```http
Content-Type: application/json
Ocp-Apim-Subscription-Key: {your-key}
```

**Request Body**:
```json
{
  "text": "Long text to summarize...",
  "max_length": 500,
  "style": "concise"
}
```

**Request Schema**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["text"],
  "properties": {
    "text": {
      "type": "string",
      "minLength": 10,
      "maxLength": 400000,
      "description": "The text to summarize"
    },
    "max_length": {
      "type": "integer",
      "minimum": 50,
      "maximum": 5000,
      "default": 500,
      "description": "Maximum length of summary in tokens"
    },
    "style": {
      "type": "string",
      "enum": ["concise", "detailed", "bullet_points"],
      "default": "concise",
      "description": "Summary style preference"
    }
  }
}
```

**Response (Success)**:
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "summary": "This is the summarized text...",
  "tokens_used": 1234,
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "model": "gpt-4o"
}
```

**Response Schema**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "summary": {
      "type": "string",
      "description": "The summarized text"
    },
    "tokens_used": {
      "type": "integer",
      "description": "Total tokens consumed (input + output)"
    },
    "request_id": {
      "type": "string",
      "format": "uuid",
      "description": "Unique request identifier for tracking"
    },
    "model": {
      "type": "string",
      "description": "AI model used for summarization"
    }
  }
}
```

**Error Responses**:

```http
# Invalid Request
HTTP/1.1 400 Bad Request
{
  "error": {
    "code": "InvalidRequest",
    "message": "Text field is required and must be between 10 and 400,000 characters.",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}

# Unauthorized
HTTP/1.1 401 Unauthorized
{
  "error": {
    "code": "Unauthorized",
    "message": "Missing or invalid subscription key.",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}

# Rate Limit Exceeded
HTTP/1.1 429 Too Many Requests
Retry-After: 60
{
  "error": {
    "code": "RateLimitExceeded",
    "message": "Rate limit exceeded. Please retry after 60 seconds.",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}

# Internal Server Error
HTTP/1.1 500 Internal Server Error
{
  "error": {
    "code": "InternalError",
    "message": "An internal error occurred. Please contact support with request ID.",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

### 2. Information Extraction

Extracts structured information from unstructured text.

**Endpoint**: `POST /ai/extract`

**Request Headers**:
```http
Content-Type: application/json
Ocp-Apim-Subscription-Key: {your-key}
```

**Request Body**:
```json
{
  "text": "Text containing information to extract...",
  "schema": {
    "type": "object",
    "properties": {
      "name": { "type": "string" },
      "date": { "type": "string", "format": "date" },
      "amount": { "type": "number" }
    }
  }
}
```

**Request Schema**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["text", "schema"],
  "properties": {
    "text": {
      "type": "string",
      "minLength": 10,
      "maxLength": 400000,
      "description": "The text to extract information from"
    },
    "schema": {
      "type": "object",
      "description": "JSON Schema describing the expected structure of extracted data"
    }
  }
}
```

**Response (Success)**:
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "extracted_data": {
    "name": "John Doe",
    "date": "2026-03-11",
    "amount": 1500.50
  },
  "confidence": 0.95,
  "tokens_used": 890,
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "model": "gpt-4o"
}
```

**Response Schema**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "extracted_data": {
      "type": "object",
      "description": "Extracted structured data matching the provided schema"
    },
    "confidence": {
      "type": "number",
      "minimum": 0,
      "maximum": 1,
      "description": "Confidence score for the extraction (0-1)"
    },
    "tokens_used": {
      "type": "integer",
      "description": "Total tokens consumed (input + output)"
    },
    "request_id": {
      "type": "string",
      "format": "uuid",
      "description": "Unique request identifier for tracking"
    },
    "model": {
      "type": "string",
      "description": "AI model used for extraction"
    }
  }
}
```

**Error Responses**: Same as summarization endpoint

### 3. Health Check

Verifies the API gateway and backend services are operational.

**Endpoint**: `GET /ai/health`

**Request Headers**:
```http
Ocp-Apim-Subscription-Key: {your-key}
```

**Response (Success)**:
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "status": "healthy",
  "timestamp": "2026-03-11T10:30:00Z",
  "services": {
    "api_gateway": "healthy",
    "ai_foundry": "healthy",
    "key_vault": "healthy"
  },
  "version": "1.0.0"
}
```

**Response (Degraded)**:
```http
HTTP/1.1 503 Service Unavailable
Content-Type: application/json

{
  "status": "degraded",
  "timestamp": "2026-03-11T10:30:00Z",
  "services": {
    "api_gateway": "healthy",
    "ai_foundry": "unhealthy",
    "key_vault": "healthy"
  },
  "version": "1.0.0"
}
```

## Error Codes

| Code | HTTP Status | Description | Retry Strategy |
|------|-------------|-------------|----------------|
| `InvalidRequest` | 400 | Request validation failed | Fix request, do not retry |
| `Unauthorized` | 401 | Missing or invalid subscription key | Provide valid key |
| `Forbidden` | 403 | Subscription lacks permissions | Contact admin |
| `NotFound` | 404 | Endpoint not found | Check endpoint path |
| `RateLimitExceeded` | 429 | Too many requests | Wait and retry after Retry-After seconds |
| `InternalError` | 500 | Server error | Retry with exponential backoff |
| `ServiceUnavailable` | 503 | Backend service unavailable | Retry with exponential backoff |
| `GatewayTimeout` | 504 | Request timeout | Retry with exponential backoff |

## Common Response Headers

All responses include these headers:

| Header | Description | Example |
|--------|-------------|---------|
| `X-Request-Id` | Unique request identifier | `550e8400-e29b-41d4-a716-446655440000` |
| `X-RateLimit-Remaining` | Remaining requests in current period | `95` |
| `X-RateLimit-Reset` | Unix timestamp when limit resets | `1678531200` |
| `X-Token-Usage` | Tokens consumed by this request | `1234` |

## CORS Policy

The API supports Cross-Origin Resource Sharing (CORS) with the following configuration:

**Allowed Origins**: `*` (all origins, can be restricted per environment)
**Allowed Methods**: `GET`, `POST`, `OPTIONS`
**Allowed Headers**: `Content-Type`, `Ocp-Apim-Subscription-Key`
**Max Age**: `3600` seconds

**Preflight Request**:
```http
OPTIONS /ai/summarize HTTP/1.1
Host: apim-aigateway-dev-eastus-01.azure-api.net
Origin: https://example.com
Access-Control-Request-Method: POST
Access-Control-Request-Headers: Content-Type, Ocp-Apim-Subscription-Key
```

**Preflight Response**:
```http
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: https://example.com
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type, Ocp-Apim-Subscription-Key
Access-Control-Max-Age: 3600
```

## Request/Response Examples

### Example 1: Summarize News Article

**Request**:
```bash
curl -X POST https://apim-aigateway-dev-eastus-01.azure-api.net/ai/summarize \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: your-key-here" \
  -d '{
    "text": "The global economy showed signs of recovery in 2026 as technology sectors led growth across major markets. Artificial intelligence continued to drive innovation in healthcare, finance, and manufacturing. Central banks maintained cautious monetary policies while inflation rates stabilized around target levels. Emerging markets demonstrated resilience despite ongoing geopolitical tensions. Experts predict sustained growth through the remainder of the year.",
    "max_length": 100,
    "style": "concise"
  }'
```

**Response**:
```json
{
  "summary": "Global economy recovers in 2026, driven by AI innovation in key sectors. Inflation stabilizes as central banks maintain cautious policies.",
  "tokens_used": 156,
  "request_id": "a1b2c3d4-e5f6-4789-0123-456789abcdef",
  "model": "gpt-4o"
}
```

### Example 2: Extract Invoice Information

**Request**:
```bash
curl -X POST https://apim-aigateway-dev-eastus-01.azure-api.net/ai/extract \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: your-key-here" \
  -d '{
    "text": "INVOICE #12345\nDate: March 11, 2026\nBill To: Acme Corp\nTotal Amount: $2,450.00\nDue Date: April 10, 2026",
    "schema": {
      "type": "object",
      "properties": {
        "invoice_number": { "type": "string" },
        "invoice_date": { "type": "string", "format": "date" },
        "customer": { "type": "string" },
        "total": { "type": "number" },
        "due_date": { "type": "string", "format": "date" }
      }
    }
  }'
```

**Response**:
```json
{
  "extracted_data": {
    "invoice_number": "12345",
    "invoice_date": "2026-03-11",
    "customer": "Acme Corp",
    "total": 2450.00,
    "due_date": "2026-04-10"
  },
  "confidence": 0.98,
  "tokens_used": 234,
  "request_id": "b2c3d4e5-f6a7-4890-1234-567890bcdefg",
  "model": "gpt-4o"
}
```

### Example 3: Health Check

**Request**:
```bash
curl -X GET https://apim-aigateway-dev-eastus-01.azure-api.net/ai/health \
  -H "Ocp-Apim-Subscription-Key: your-key-here"
```

**Response**:
```json
{
  "status": "healthy",
  "timestamp": "2026-03-11T15:45:30Z",
  "services": {
    "api_gateway": "healthy",
    "ai_foundry": "healthy",
    "key_vault": "healthy"
  },
  "version": "1.0.0"
}
```

## Client SDKs

### Python SDK Example

```python
import requests
from typing import Dict, Any

class AIGatewayClient:
    def __init__(self, base_url: str, subscription_key: str):
        self.base_url = base_url
        self.headers = {
            "Content-Type": "application/json",
            "Ocp-Apim-Subscription-Key": subscription_key
        }

    def summarize(self, text: str, max_length: int = 500, style: str = "concise") -> Dict[str, Any]:
        """Summarize text using the AI gateway."""
        response = requests.post(
            f"{self.base_url}/ai/summarize",
            headers=self.headers,
            json={
                "text": text,
                "max_length": max_length,
                "style": style
            }
        )
        response.raise_for_status()
        return response.json()

    def extract(self, text: str, schema: Dict[str, Any]) -> Dict[str, Any]:
        """Extract structured information from text."""
        response = requests.post(
            f"{self.base_url}/ai/extract",
            headers=self.headers,
            json={
                "text": text,
                "schema": schema
            }
        )
        response.raise_for_status()
        return response.json()

    def health_check(self) -> Dict[str, Any]:
        """Check API health status."""
        response = requests.get(
            f"{self.base_url}/ai/health",
            headers=self.headers
        )
        response.raise_for_status()
        return response.json()

# Usage
client = AIGatewayClient(
    base_url="https://apim-aigateway-dev-eastus-01.azure-api.net",
    subscription_key="your-subscription-key"
)

result = client.summarize("Long text to summarize...")
print(result["summary"])
```

### JavaScript/TypeScript SDK Example

```typescript
interface SummarizeRequest {
  text: string;
  max_length?: number;
  style?: 'concise' | 'detailed' | 'bullet_points';
}

interface SummarizeResponse {
  summary: string;
  tokens_used: number;
  request_id: string;
  model: string;
}

class AIGatewayClient {
  private baseUrl: string;
  private subscriptionKey: string;

  constructor(baseUrl: string, subscriptionKey: string) {
    this.baseUrl = baseUrl;
    this.subscriptionKey = subscriptionKey;
  }

  async summarize(request: SummarizeRequest): Promise<SummarizeResponse> {
    const response = await fetch(`${this.baseUrl}/ai/summarize`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Ocp-Apim-Subscription-Key': this.subscriptionKey,
      },
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      throw new Error(`API error: ${response.status} ${response.statusText}`);
    }

    return response.json();
  }

  async healthCheck(): Promise<any> {
    const response = await fetch(`${this.baseUrl}/ai/health`, {
      headers: {
        'Ocp-Apim-Subscription-Key': this.subscriptionKey,
      },
    });

    if (!response.ok) {
      throw new Error(`Health check failed: ${response.status}`);
    }

    return response.json();
  }
}

// Usage
const client = new AIGatewayClient(
  'https://apim-aigateway-dev-eastus-01.azure-api.net',
  'your-subscription-key'
);

const result = await client.summarize({
  text: 'Long text to summarize...',
  max_length: 500,
  style: 'concise',
});

console.log(result.summary);
```

## Best Practices

### 1. Error Handling

Always implement proper error handling with exponential backoff for retryable errors:

```python
import time
from typing import Any, Dict

def retry_with_backoff(func, max_retries=3):
    for attempt in range(max_retries):
        try:
            return func()
        except requests.HTTPError as e:
            if e.response.status_code in [429, 500, 502, 503, 504]:
                if attempt < max_retries - 1:
                    wait_time = 2 ** attempt  # Exponential backoff
                    time.sleep(wait_time)
                    continue
            raise
    raise Exception("Max retries exceeded")
```

### 2. Subscription Key Management

- Store subscription keys in Azure Key Vault
- Rotate keys regularly (every 90 days)
- Use different keys for different environments
- Never log or commit keys to source control

### 3. Request Optimization

- Batch multiple operations when possible
- Keep requests under 100K characters for best performance
- Use appropriate `max_length` values to control token usage
- Cache responses when data doesn't change frequently

### 4. Monitoring

- Log all request IDs for troubleshooting
- Track token usage to manage costs
- Monitor rate limit headers to avoid throttling
- Set up alerts for error rates

## Versioning Strategy

The API uses URI versioning for major changes:

- **Current**: `/ai/summarize` (v1, implicit)
- **Future**: `/v2/ai/summarize` (v2, explicit)

**Backward Compatibility**:
- Minor changes (new optional fields) are backward compatible
- Major changes (breaking changes) require new version
- Deprecated versions supported for 12 months minimum

## Support & Contact

- **Documentation**: https://docs.ai-gateway.example.com
- **Support Email**: ai-gateway-support@example.com
- **Status Page**: https://status.ai-gateway.example.com
- **API Issues**: Include request ID when reporting issues

---

**Document Version**: 1.0
**Last Updated**: 2026-03-11
**API Version**: v1
