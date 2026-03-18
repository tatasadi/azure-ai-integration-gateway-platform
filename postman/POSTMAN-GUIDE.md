# Postman Collection Guide

This guide explains how to use the Postman collection to test the Azure AI Integration Gateway API.

## Files Included

- **[postman-collection.json](postman-collection.json)** - Main Postman collection with all API endpoints
- **[postman-environment-dev.json](postman-environment-dev.json)** - Development environment configuration
- **[postman-environment-staging.json](postman-environment-staging.json)** - Staging environment configuration
- **[postman-environment-prod.json](postman-environment-prod.json)** - Production environment configuration

## Quick Start

### 1. Import the Collection

1. Open Postman
2. Click **Import** button (top left)
3. Drag and drop `postman-collection.json` or click to browse
4. The collection "Azure AI Integration Gateway API" will appear in your Collections sidebar

### 2. Import Environment Files

1. Click the **Environments** icon (left sidebar)
2. Click **Import** button
3. Import all three environment files:
   - `postman-environment-dev.json`
   - `postman-environment-staging.json`
   - `postman-environment-prod.json`

### 3. Configure Your Environment

1. Select an environment from the dropdown (top right) - start with **Development**
2. Click the eye icon next to the environment dropdown
3. Click **Edit** to modify the environment variables
4. Update the following variables:

   | Variable | Description | Example |
   |----------|-------------|---------|
   | `baseUrl` | Your APIM gateway URL | `https://apim-aigateway-dev-eastus-01.azure-api.net` |
   | `subscriptionKey` | Your subscription key | Get from APIM Developer Portal |

5. Click **Save**

### 4. Get Your Subscription Key

To obtain your subscription key:

1. Navigate to your APIM Developer Portal (get URL from Terraform output: `apim_portal_url`)
2. Sign in or create an account
3. Go to **Profile** → **Subscriptions**
4. Copy your subscription key
5. Paste it into the `subscriptionKey` variable in your Postman environment

**Security Note:** Mark the `subscriptionKey` as a "secret" type in Postman to hide it from view.

### 5. Run Your First Request

1. Expand the "Azure AI Integration Gateway API" collection
2. Navigate to **AI Operations** → **Summarize Text - Basic**
3. Ensure your environment is selected (top right dropdown)
4. Click **Send**
5. View the response with the summarized text

## Collection Structure

The collection is organized into the following folders:

### 1. AI Operations

Contains all AI-powered operations:

- **Summarize Text - Basic**: Simple text summarization with concise style
- **Summarize Text - Detailed**: Detailed summary with custom length
- **Summarize Text - Bullet Points**: Summary formatted as bullet points
- **Extract Information - Invoice**: Extract structured data from invoice text
- **Extract Information - Contact Details**: Extract contact information

### 2. Health & Monitoring

Health check endpoints:

- **Health Check**: Verify API gateway and backend service status

### 3. Error Scenarios

Test cases for error handling:

- **Invalid Request - Missing Text**: Test missing required field (400)
- **Invalid Request - Text Too Short**: Test validation error (400)
- **Unauthorized - Missing Key**: Test missing authentication (401)
- **Unauthorized - Invalid Key**: Test invalid credentials (401)

## API Endpoints

### POST /ai/summarize

Summarizes long text into concise summaries.

**Request Body:**
```json
{
  "text": "Long text to summarize...",
  "max_length": 500,
  "style": "concise"
}
```

**Parameters:**
- `text` (required): Text to summarize (10-400,000 characters)
- `max_length` (optional): Maximum summary length in tokens (50-5000, default: 500)
- `style` (optional): Summary style - `concise`, `detailed`, or `bullet_points` (default: `concise`)

**Response:**
```json
{
  "summary": "The summarized text...",
  "tokens_used": 156,
  "request_id": "a1b2c3d4-e5f6-4789-0123-456789abcdef",
  "model": "gpt-4o"
}
```

### POST /ai/extract

Extracts structured information from unstructured text.

**Request Body:**
```json
{
  "text": "INVOICE #12345\nDate: March 11, 2026...",
  "schema": {
    "type": "object",
    "properties": {
      "invoice_number": { "type": "string" },
      "invoice_date": { "type": "string", "format": "date" },
      "total": { "type": "number" }
    }
  }
}
```

**Parameters:**
- `text` (required): Text to extract information from (10-400,000 characters)
- `schema` (required): JSON Schema defining expected structure

**Response:**
```json
{
  "extracted_data": {
    "invoice_number": "12345",
    "invoice_date": "2026-03-11",
    "total": 2450.00
  },
  "confidence": 0.98,
  "tokens_used": 234,
  "request_id": "b2c3d4e5-f6a7-4890-1234-567890bcdefg",
  "model": "gpt-4o"
}
```

### GET /ai/health

Checks the health of the API gateway and backend services.

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

**Response (503 Service Unavailable):**
```json
{
  "status": "degraded",
  "timestamp": "2026-03-18T10:30:00Z",
  "services": {
    "api_gateway": "healthy",
    "ai_foundry": "unhealthy",
    "key_vault": "healthy"
  },
  "version": "1.0.0"
}
```

## Authentication

All API requests require authentication using a subscription key.

**Header:**
```
Ocp-Apim-Subscription-Key: YOUR_SUBSCRIPTION_KEY_HERE
```

This header is automatically added to all requests in the collection using the `{{subscriptionKey}}` variable.

## Rate Limits

The API enforces the following rate limits:

- **Rate Limit**: 100 requests per minute per subscription
- **Daily Quota**: 10,000 requests per day per subscription

**Rate Limit Headers:**

The API returns rate limit information in response headers:

```
X-RateLimit-Remaining: 99
X-RateLimit-Reset: 1678531200
```

**What Happens When Rate Limit is Exceeded:**

If you exceed the rate limit, you'll receive a `429 Too Many Requests` response:

```json
{
  "error": {
    "code": "RateLimitExceeded",
    "message": "Rate limit exceeded. Please retry after 60 seconds.",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

The response includes a `Retry-After` header indicating when you can retry.

## Test Scripts

The collection includes automated test scripts that run after each request:

### Request Tests

Example tests included:
- Status code validation
- Response schema validation
- Required field checks
- Header validation
- Rate limit monitoring

### Console Logging

Test scripts log useful information to the Postman console:
- Request details (URL, timestamp)
- Response time
- Token usage
- Request IDs
- Rate limit remaining
- Extracted data

**To view console output:**
1. Open Postman Console: View → Show Postman Console (or Cmd+Alt+C / Ctrl+Alt+C)
2. Run a request
3. View detailed logs in the console

### Variables Set by Tests

The test scripts automatically set these environment variables:
- `last_request_id`: The request ID from the last successful request
- `timestamp`: Timestamp of the current request

## Error Handling

The API uses standard HTTP status codes:

| Status Code | Meaning | Description |
|-------------|---------|-------------|
| 200 | OK | Request successful |
| 400 | Bad Request | Invalid request parameters |
| 401 | Unauthorized | Missing or invalid subscription key |
| 429 | Too Many Requests | Rate limit or quota exceeded |
| 500 | Internal Server Error | Server error |
| 503 | Service Unavailable | Backend service unavailable |

**Error Response Format:**
```json
{
  "error": {
    "code": "ErrorCode",
    "message": "Human-readable error message",
    "request_id": "550e8400-e29b-41d4-a716-446655440000",
    "details": {}
  }
}
```

## Tips & Best Practices

### 1. Environment Management

- Use **Dev** environment for testing and development
- Use **Staging** environment for pre-production validation
- Use **Production** environment only for verified workflows
- Keep separate subscription keys for each environment

### 2. Testing Workflow

1. Start with the **Health Check** to verify connectivity
2. Test **Summarize Text - Basic** with simple input
3. Progress to more complex requests
4. Test error scenarios to understand error handling

### 3. Monitoring Token Usage

Each response includes `tokens_used` field. Monitor this to:
- Estimate API costs
- Optimize prompt length
- Track usage patterns

### 4. Request IDs

Every response includes a `request_id`. Use this for:
- Troubleshooting with support team
- Correlating requests in Application Insights
- Debugging issues

### 5. Rate Limit Management

- Monitor `X-RateLimit-Remaining` header
- Implement exponential backoff on 429 errors
- Use the `Retry-After` header value
- Distribute requests evenly over time

### 6. Security Best Practices

- Never commit subscription keys to source control
- Mark subscription keys as "secret" type in Postman
- Rotate keys regularly (every 90 days)
- Use separate keys for each environment
- Store production keys in Azure Key Vault

## Running Collection with Newman

Newman is Postman's command-line collection runner. Use it for CI/CD integration.

### Install Newman

```bash
npm install -g newman
```

### Run Collection

```bash
# Run with dev environment
newman run postman-collection.json \
  -e postman-environment-dev.json \
  --reporters cli,json \
  --reporter-json-export results.json

# Run with custom variables
newman run postman-collection.json \
  --env-var "baseUrl=https://your-apim-url.azure-api.net" \
  --env-var "subscriptionKey=your-key-here"
```

### Run Specific Folder

```bash
# Run only health checks
newman run postman-collection.json \
  -e postman-environment-dev.json \
  --folder "Health & Monitoring"
```

## Troubleshooting

### Issue: 401 Unauthorized

**Possible Causes:**
- Missing subscription key
- Invalid subscription key
- Expired subscription
- Wrong environment selected

**Solutions:**
1. Verify subscription key is correct
2. Check subscription is active in APIM Developer Portal
3. Ensure environment is selected (top right dropdown)
4. Verify `Ocp-Apim-Subscription-Key` header is present

### Issue: 429 Too Many Requests

**Possible Causes:**
- Exceeded rate limit (100 requests/minute)
- Exceeded daily quota (10,000 requests/day)

**Solutions:**
1. Wait for rate limit window to reset (check `Retry-After` header)
2. Implement request throttling
3. Contact support to request quota increase
4. Distribute requests over time

### Issue: 503 Service Unavailable

**Possible Causes:**
- Backend AI service is down
- APIM gateway is down
- Network connectivity issues

**Solutions:**
1. Check health endpoint: `GET /ai/health`
2. Verify Azure service status
3. Check Application Insights for errors
4. Contact support with request ID

### Issue: Timeout Errors

**Possible Causes:**
- Request text is too long
- AI model processing time is high
- Network latency

**Solutions:**
1. Reduce text length
2. Increase Postman timeout: Settings → General → Request timeout
3. Break large requests into smaller chunks
4. Check network connectivity

## Additional Resources

- **API Documentation**: [docs/api-design.md](docs/api-design.md)
- **Architecture**: [docs/architecture.md](docs/architecture.md)
- **Security Guide**: [docs/security.md](docs/security.md)
- **OpenAPI Spec**: [docs/openapi.yaml](docs/openapi.yaml)
- **Integration Tests**: [tests/integration/test_ai_gateway.py](tests/integration/test_ai_gateway.py)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Application Insights logs
3. Check [README.md](README.md) for general setup
4. Open an issue in the repository

## Version History

- **v1.0.0** (2026-03-18): Initial release
  - AI Operations: Summarize, Extract
  - Health monitoring
  - Error scenarios
  - Multi-environment support
