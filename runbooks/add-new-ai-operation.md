# Runbook: How to Add a New AI Operation

## Overview

This runbook provides step-by-step instructions for adding a new AI operation to the Azure AI Gateway platform.

**Estimated Time**: 2-4 hours
**Frequency**: As needed
**Owner**: Platform Team

---

## Prerequisites

- [ ] New operation requirements defined
- [ ] API design approved
- [ ] Development environment access
- [ ] Git repository access
- [ ] Azure CLI and Terraform installed

---

## Process Flow

```
Design API → Create Policy → Update Terraform → Test Locally → Deploy Dev → Test → Deploy Staging → Deploy Prod
```

---

## Example: Adding a "Translation" Operation

We'll use adding a translation endpoint as an example throughout this runbook.

**New Operation**: `POST /ai/translate`

**Request**:
```json
{
  "text": "Hello, world!",
  "source_language": "en",
  "target_language": "es"
}
```

**Response**:
```json
{
  "translated_text": "¡Hola, mundo!",
  "source_language": "en",
  "target_language": "es",
  "tokens_used": 25,
  "request_id": "abc-123",
  "model": "gpt-4o"
}
```

---

## Step-by-Step Instructions

### Step 1: Design the API Operation

**Document the following**:

1. **Endpoint**: `POST /ai/translate`
2. **Purpose**: Translate text between languages
3. **Request Schema**:
   ```json
   {
     "text": "string (required, min: 1, max: 100000)",
     "source_language": "string (required, ISO 639-1 code)",
     "target_language": "string (required, ISO 639-1 code)"
   }
   ```

4. **Response Schema**:
   ```json
   {
     "translated_text": "string",
     "source_language": "string",
     "target_language": "string",
     "tokens_used": "integer",
     "request_id": "string (uuid)",
     "model": "string"
   }
   ```

5. **Error Codes**:
   - 400: Invalid language code
   - 401: Unauthorized
   - 429: Rate limit exceeded
   - 500: Internal error

6. **Rate Limits**: Use default (100 req/min, 10K/day)

---

### Step 2: Create APIM Policy File

Create new policy file for the operation:

**File**: `apim-policies/operations/translate-policy.xml`

```xml
<policies>
    <inbound>
        <base />

        <!-- Validate request -->
        <validate-content unspecified-content-type-action="prevent"
                         max-size="102400"
                         size-exceeded-action="detect"
                         errors-variable-name="requestBodyValidation">
            <content type="application/json"
                     validate-as="json"
                     action="prevent" />
        </validate-content>

        <!-- Set backend service URL -->
        <set-backend-service
            base-url="{{ai-foundry-endpoint}}/openai/deployments/{{gpt-4o-deployment-name}}/chat/completions?api-version=2024-02-15-preview" />

        <!-- Transform request to OpenAI format -->
        <set-body>@{
            var body = context.Request.Body.As<JObject>(preserveContent: true);
            var text = body["text"]?.ToString() ?? "";
            var sourceLang = body["source_language"]?.ToString() ?? "auto";
            var targetLang = body["target_language"]?.ToString() ?? "en";

            return new JObject(
                new JProperty("messages", new JArray(
                    new JObject(
                        new JProperty("role", "system"),
                        new JProperty("content", $"You are a professional translator. Translate the following text from {sourceLang} to {targetLang}. Return only the translated text without any explanation.")
                    ),
                    new JObject(
                        new JProperty("role", "user"),
                        new JProperty("content", text)
                    )
                )),
                new JProperty("max_tokens", 5000),
                new JProperty("temperature", 0.3)
            ).ToString();
        }</set-body>

        <!-- Set request headers -->
        <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
        </set-header>

        <!-- Authenticate using Managed Identity -->
        <authentication-managed-identity resource="https://cognitiveservices.azure.com" />

        <!-- Log request -->
        <log-to-applicationinsights>@{
            return new {
                EventName = "TranslateRequest",
                Operation = context.Operation.Name,
                SubscriptionId = context.Subscription?.Id,
                RequestId = context.RequestId,
                SourceLanguage = context.Request.Body.As<JObject>(preserveContent: true)["source_language"]?.ToString(),
                TargetLanguage = context.Request.Body.As<JObject>(preserveContent: true)["target_language"]?.ToString(),
                Timestamp = DateTime.UtcNow
            };
        }</log-to-applicationinsights>
    </inbound>

    <backend>
        <base />
    </backend>

    <outbound>
        <base />

        <!-- Transform response -->
        <set-body>@{
            var response = context.Response.Body.As<JObject>(preserveContent: true);
            var originalRequest = context.Request.Body.As<JObject>(preserveContent: true);

            var translatedText = response["choices"]?[0]?["message"]?["content"]?.ToString() ?? "";
            var tokensUsed = response["usage"]?["total_tokens"]?.Value<int>() ?? 0;

            return new JObject(
                new JProperty("translated_text", translatedText),
                new JProperty("source_language", originalRequest["source_language"]?.ToString()),
                new JProperty("target_language", originalRequest["target_language"]?.ToString()),
                new JProperty("tokens_used", tokensUsed),
                new JProperty("request_id", context.RequestId),
                new JProperty("model", "gpt-4o")
            ).ToString();
        }</set-body>

        <!-- Set response headers -->
        <set-header name="X-Request-Id" exists-action="override">
            <value>@(context.RequestId)</value>
        </set-header>
        <set-header name="X-Token-Usage" exists-action="override">
            <value>@(context.Response.Body.As<JObject>()["tokens_used"]?.ToString())</value>
        </set-header>

        <!-- Log response -->
        <log-to-applicationinsights>@{
            var responseBody = context.Response.Body.As<JObject>(preserveContent: true);
            return new {
                EventName = "TranslateResponse",
                RequestId = context.RequestId,
                TokensUsed = responseBody["tokens_used"]?.Value<int>(),
                ResponseCode = context.Response.StatusCode,
                Duration = context.Elapsed.TotalMilliseconds,
                Timestamp = DateTime.UtcNow
            };
        }</log-to-applicationinsights>
    </outbound>

    <on-error>
        <base />

        <!-- Log error -->
        <log-to-applicationinsights>@{
            return new {
                EventName = "TranslateError",
                RequestId = context.RequestId,
                ErrorMessage = context.LastError?.Message,
                ErrorSource = context.LastError?.Source,
                Timestamp = DateTime.UtcNow
            };
        }</log-to-applicationinsights>

        <!-- Return user-friendly error -->
        <return-response>
            <set-status code="500" reason="Internal Server Error" />
            <set-header name="Content-Type" exists-action="override">
                <value>application/json</value>
            </set-header>
            <set-body>@{
                return new JObject(
                    new JProperty("error", new JObject(
                        new JProperty("code", "TranslationError"),
                        new JProperty("message", "An error occurred during translation. Please try again."),
                        new JProperty("request_id", context.RequestId)
                    ))
                ).ToString();
            }</set-body>
        </return-response>
    </on-error>
</policies>
```

**Validate XML**:
```bash
xmllint --noout apim-policies/operations/translate-policy.xml
```

---

### Step 3: Update Terraform Configuration

**File**: `terraform/modules/api-management/apis.tf`

Add the new operation to the API:

```hcl
# Add to existing azurerm_api_management_api resource

# Translation Operation
resource "azurerm_api_management_api_operation" "translate" {
  operation_id        = "translate"
  api_name            = azurerm_api_management_api.ai_gateway.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name
  display_name        = "Translate Text"
  method              = "POST"
  url_template        = "/ai/translate"
  description         = "Translate text between languages using AI"

  request {
    description = "Translation request"

    representation {
      content_type = "application/json"

      example {
        name  = "default"
        value = jsonencode({
          text            = "Hello, world!"
          source_language = "en"
          target_language = "es"
        })
      }

      schema_id = "translate-request"
    }
  }

  response {
    status_code = 200
    description = "Successful translation"

    representation {
      content_type = "application/json"

      example {
        name  = "default"
        value = jsonencode({
          translated_text = "¡Hola, mundo!"
          source_language = "en"
          target_language = "es"
          tokens_used     = 25
          request_id      = "550e8400-e29b-41d4-a716-446655440000"
          model           = "gpt-4o"
        })
      }
    }
  }

  response {
    status_code = 400
    description = "Bad Request - Invalid language code or text"
  }

  response {
    status_code = 401
    description = "Unauthorized - Invalid or missing subscription key"
  }

  response {
    status_code = 429
    description = "Too Many Requests - Rate limit exceeded"
  }
}

# Translation Operation Policy
resource "azurerm_api_management_api_operation_policy" "translate_policy" {
  api_name            = azurerm_api_management_api.ai_gateway.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name
  operation_id        = azurerm_api_management_api_operation.translate.operation_id

  xml_content = file("${path.root}/../apim-policies/operations/translate-policy.xml")
}
```

**Validate Terraform**:
```bash
cd terraform
terraform fmt
terraform validate
```

---

### Step 4: Update API Documentation

**File**: `docs/api-design.md`

Add new section for the translation operation:

```markdown
### 4. Text Translation

Translates text between languages using advanced AI models.

**Endpoint**: `POST /ai/translate`

**Request Headers**:
```http
Content-Type: application/json
Ocp-Apim-Subscription-Key: {your-key}
```

**Request Body**:
```json
{
  "text": "Text to translate...",
  "source_language": "en",
  "target_language": "es"
}
```

**Request Schema**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["text", "source_language", "target_language"],
  "properties": {
    "text": {
      "type": "string",
      "minLength": 1,
      "maxLength": 100000,
      "description": "The text to translate"
    },
    "source_language": {
      "type": "string",
      "pattern": "^[a-z]{2}$",
      "description": "Source language code (ISO 639-1)"
    },
    "target_language": {
      "type": "string",
      "pattern": "^[a-z]{2}$",
      "description": "Target language code (ISO 639-1)"
    }
  }
}
```

**Response (Success)**:
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "translated_text": "Texto traducido...",
  "source_language": "en",
  "target_language": "es",
  "tokens_used": 125,
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "model": "gpt-4o"
}
```
```

---

### Step 5: Update README

**File**: `README.md`

Add the new operation to the features list:

```markdown
### API Operations

- **POST /ai/summarize** - Text summarization
- **POST /ai/extract** - Information extraction
- **POST /ai/translate** - Text translation (NEW)
- **GET /ai/health** - Health check
```

Add example usage:

```markdown
# Test translation
curl -X POST \
  https://apim-aigateway-dev-eastus-01.azure-api.net/ai/translate \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY_HERE" \
  -d '{
    "text": "Hello, world!",
    "source_language": "en",
    "target_language": "es"
  }'
```

---

### Step 6: Create Integration Tests

**File**: `tests/integration/test_ai_gateway.py`

Add test class for translation:

```python
class TestTranslateEndpoint:
    """Tests for the /ai/translate endpoint"""

    def test_translate_basic(self, api_client):
        """Test basic translation functionality"""
        response = api_client.post(
            "/ai/translate",
            json={
                "text": "Hello, world!",
                "source_language": "en",
                "target_language": "es"
            }
        )

        assert response.status_code == 200
        data = response.json()
        assert "translated_text" in data
        assert data["source_language"] == "en"
        assert data["target_language"] == "es"
        assert "tokens_used" in data
        assert "request_id" in data

    def test_translate_invalid_language(self, api_client):
        """Test translation with invalid language code"""
        response = api_client.post(
            "/ai/translate",
            json={
                "text": "Hello",
                "source_language": "invalid",
                "target_language": "es"
            }
        )

        # Depending on validation, might be 400 or 200 with error message
        assert response.status_code in [200, 400]

    def test_translate_missing_field(self, api_client):
        """Test translation with missing required field"""
        response = api_client.post(
            "/ai/translate",
            json={
                "text": "Hello",
                "source_language": "en"
                # Missing target_language
            }
        )

        assert response.status_code == 400

    def test_translate_empty_text(self, api_client):
        """Test translation with empty text"""
        response = api_client.post(
            "/ai/translate",
            json={
                "text": "",
                "source_language": "en",
                "target_language": "es"
            }
        )

        assert response.status_code == 400

    def test_translate_long_text(self, api_client):
        """Test translation with long text"""
        long_text = "This is a test. " * 1000  # Long text
        response = api_client.post(
            "/ai/translate",
            json={
                "text": long_text,
                "source_language": "en",
                "target_language": "es"
            }
        )

        assert response.status_code == 200
        data = response.json()
        assert "translated_text" in data
        assert len(data["translated_text"]) > 0
```

---

### Step 7: Deploy to Development Environment

```bash
# 1. Commit changes
git add .
git commit -m "Add translation operation to AI Gateway"

# 2. Navigate to Terraform directory
cd terraform

# 3. Plan deployment
terraform plan -out=tfplan

# 4. Review plan carefully
# Look for the new operation and policy resources

# 5. Apply to dev environment
terraform apply tfplan

# 6. Update APIM policies (if using script)
cd ..
./scripts/update-apim-policies.sh dev
```

---

### Step 8: Test in Development

**Manual Test**:

```bash
# Set environment variables
export APIM_BASE_URL="https://apim-aigateway-dev-eastus-01.azure-api.net"
export APIM_SUBSCRIPTION_KEY="your-dev-key"

# Test translation
curl -X POST "${APIM_BASE_URL}/ai/translate" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: ${APIM_SUBSCRIPTION_KEY}" \
  -d '{
    "text": "The weather is beautiful today.",
    "source_language": "en",
    "target_language": "fr"
  }' | jq

# Expected response:
# {
#   "translated_text": "Le temps est magnifique aujourd'hui.",
#   "source_language": "en",
#   "target_language": "fr",
#   "tokens_used": 35,
#   "request_id": "abc-123-def",
#   "model": "gpt-4o"
# }
```

**Automated Tests**:

```bash
cd tests/integration
pytest test_ai_gateway.py::TestTranslateEndpoint -v
```

**Verify in Application Insights**:

```kql
customEvents
| where name == "TranslateRequest"
| where timestamp > ago(1h)
| project
    timestamp,
    SourceLanguage = tostring(customDimensions.SourceLanguage),
    TargetLanguage = tostring(customDimensions.TargetLanguage),
    RequestId = tostring(customDimensions.RequestId)
| order by timestamp desc
```

---

### Step 9: Deploy to Staging

```bash
# 1. Ensure dev testing is complete and successful

# 2. Plan staging deployment
terraform workspace select staging  # If using workspaces
terraform plan -var-file="environments/staging/terraform.tfvars" -out=tfplan

# 3. Apply to staging
terraform apply tfplan

# 4. Update policies
./scripts/update-apim-policies.sh staging

# 5. Run integration tests
cd tests/integration
APIM_BASE_URL="https://apim-aigateway-staging-eastus-01.azure-api.net" \
APIM_SUBSCRIPTION_KEY="staging-key" \
pytest test_ai_gateway.py::TestTranslateEndpoint -v
```

---

### Step 10: Deploy to Production

**Prerequisites**:
- [ ] Staging deployment successful
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Change approval obtained

```bash
# 1. Create backup
terraform state pull > backup-$(date +%Y%m%d-%H%M%S).tfstate

# 2. Plan production deployment
terraform workspace select prod
terraform plan -var-file="environments/prod/terraform.tfvars" -out=tfplan

# 3. Review plan with team

# 4. Schedule deployment window (communicate to users)

# 5. Apply to production
terraform apply tfplan

# 6. Update policies
./scripts/update-apim-policies.sh prod

# 7. Run smoke tests
./scripts/smoke-test.sh

# 8. Monitor for issues (1 hour)
# Watch Application Insights for errors

# 9. Communicate completion
```

---

### Step 11: Update OpenAPI Specification

If you're maintaining an OpenAPI spec file:

**File**: `docs/openapi.yaml`

Add the translation operation:

```yaml
  /ai/translate:
    post:
      summary: Translate text between languages
      operationId: translate
      tags:
        - AI Operations
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/TranslateRequest'
      responses:
        '200':
          description: Successful translation
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/TranslateResponse'
        '400':
          $ref: '#/components/responses/BadRequest'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '429':
          $ref: '#/components/responses/TooManyRequests'

components:
  schemas:
    TranslateRequest:
      type: object
      required:
        - text
        - source_language
        - target_language
      properties:
        text:
          type: string
          minLength: 1
          maxLength: 100000
        source_language:
          type: string
          pattern: '^[a-z]{2}$'
        target_language:
          type: string
          pattern: '^[a-z]{2}$'

    TranslateResponse:
      type: object
      properties:
        translated_text:
          type: string
        source_language:
          type: string
        target_language:
          type: string
        tokens_used:
          type: integer
        request_id:
          type: string
          format: uuid
        model:
          type: string
```

---

## Post-Deployment Checklist

- [ ] Policy XML validated
- [ ] Terraform configuration updated
- [ ] API documentation updated
- [ ] README updated
- [ ] Integration tests created
- [ ] Deployed to dev and tested
- [ ] Deployed to staging and tested
- [ ] Production deployment approved
- [ ] Deployed to production
- [ ] Monitoring dashboard updated
- [ ] OpenAPI spec updated (if applicable)
- [ ] Consumer notification sent
- [ ] Knowledge base updated

---

## Rollback Procedure

If issues are discovered after deployment:

```bash
# 1. Identify the commit before the change
git log --oneline

# 2. Revert the change
git revert <commit-hash>

# 3. Re-deploy
terraform plan -out=tfplan
terraform apply tfplan

# 4. Verify rollback
./scripts/smoke-test.sh
```

Or remove just the operation:

```bash
# 1. Remove operation from Terraform
# Comment out or delete the translate operation resources

# 2. Apply change
terraform plan -out=tfplan
terraform apply tfplan
```

---

## Common Issues & Troubleshooting

### Issue 1: Policy Validation Fails

**Error**: XML syntax error

**Resolution**:
```bash
# Validate XML
xmllint --noout apim-policies/operations/translate-policy.xml

# Check for common issues:
# - Unclosed tags
# - Invalid C# expressions in @{}
# - Missing CDATA sections for complex expressions
```

### Issue 2: Backend Returns 401

**Error**: Authentication failed to Azure OpenAI

**Resolution**:
- Verify Managed Identity has "Cognitive Services User" role
- Check backend URL is correct
- Verify authentication-managed-identity resource URL

### Issue 3: Response Transformation Fails

**Error**: Cannot parse response body

**Resolution**:
```xml
<!-- Add error handling in policy -->
<set-body>@{
    try {
        var response = context.Response.Body.As<JObject>(preserveContent: true);
        // ... transformation logic
    } catch (Exception ex) {
        return new JObject(
            new JProperty("error", ex.Message)
        ).ToString();
    }
}</set-body>
```

---

## References

- [APIM Policy Reference](https://learn.microsoft.com/azure/api-management/api-management-policies)
- [APIM Policy Expressions](https://learn.microsoft.com/azure/api-management/api-management-policy-expressions)
- [Azure OpenAI REST API](https://learn.microsoft.com/azure/ai-services/openai/reference)

---

**Runbook Version**: 1.0
**Last Updated**: 2026-03-17
**Owner**: Platform Team
