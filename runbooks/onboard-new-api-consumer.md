# Runbook: How to Onboard a New API Consumer

## Overview

This runbook provides step-by-step instructions for onboarding a new API consumer to the Azure AI Gateway platform.

**Estimated Time**: 15-30 minutes
**Frequency**: As needed
**Owner**: Platform Team

---

## Prerequisites

- [ ] Access to Azure Portal with APIM permissions
- [ ] Consumer's business justification approved
- [ ] Consumer's team contact information
- [ ] Environment determined (dev/staging/prod)

---

## Process Flow

```
Request → Approval → Create Subscription → Configure Limits → Provide Credentials → Onboard Complete
```

---

## Step-by-Step Instructions

### Step 1: Review Onboarding Request

**Information Required**:
- Consumer name (individual or team)
- Business justification
- Expected usage volume
- Required operations (summarize, extract, or both)
- Environment (dev/staging/prod)
- Cost center for billing

**Approval Process**:
1. Review request in ticketing system
2. Verify business justification
3. Confirm budget allocation
4. Get approval from team lead (for production)

---

### Step 2: Create APIM Subscription

**Option A: Via Azure Portal**

1. Navigate to Azure Portal
2. Go to **API Management** → Select your APIM instance
   - Dev: `apim-aigateway-dev-eastus-01`
   - Staging: `apim-aigateway-staging-eastus-01`
   - Prod: `apim-aigateway-prod-eastus-01`

3. Click **Subscriptions** in left menu

4. Click **+ Add subscription**

5. Fill in subscription details:
   ```
   Display name: <consumer-name>-<environment>
   Example: acme-corp-prod

   Scope: API
   API: AI Services Gateway

   Allow tracing: No (unless debugging)
   ```

6. Click **Create**

7. Copy the subscription key (you'll need this later)

**Option B: Via Azure CLI**

```bash
# Set variables
APIM_NAME="apim-aigateway-prod-eastus-01"
RG_NAME="rg-aigateway-prod-eastus-01"
CONSUMER_NAME="acme-corp"
SUBSCRIPTION_NAME="${CONSUMER_NAME}-prod"

# Create subscription
az apim subscription create \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id $SUBSCRIPTION_NAME \
  --display-name "$SUBSCRIPTION_NAME" \
  --scope "/apis/ai-services-gateway" \
  --state active

# Get the subscription keys
az apim subscription show \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id $SUBSCRIPTION_NAME \
  --query "{PrimaryKey:primaryKey, SecondaryKey:secondaryKey}"
```

---

### Step 3: Configure Custom Rate Limits (Optional)

If the consumer requires different rate limits than the default:

**Default Limits**:
- Rate Limit: 100 requests/minute
- Daily Quota: 10,000 requests/day

**To customize**:

1. Navigate to **API Management** → **APIs** → **AI Services Gateway**
2. Select **All operations** (or specific operation)
3. Click **Policies**
4. Add subscription-specific policy:

```xml
<policies>
    <inbound>
        <base />
        <!-- Custom rate limit for specific subscription -->
        <choose>
            <when condition="@(context.Subscription.Id == "acme-corp-prod")">
                <rate-limit-by-key calls="500" renewal-period="60"
                    counter-key="@(context.Subscription.Id)" />
                <quota-by-key calls="50000" renewal-period="86400"
                    counter-key="@(context.Subscription.Id)" />
            </when>
        </choose>
    </inbound>
</policies>
```

5. Click **Save**

**Via Terraform** (recommended for production):

Add to `terraform/modules/api-management/policies.tf`:

```hcl
resource "azurerm_api_management_api_policy" "custom_limits" {
  api_name            = azurerm_api_management_api.ai_gateway.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name

  xml_content = templatefile("${path.module}/policies/custom-limits.xml", {
    subscription_id = "acme-corp-prod"
    rate_limit      = 500
    daily_quota     = 50000
  })
}
```

---

### Step 4: Set Up Monitoring & Alerts

Create consumer-specific monitoring dashboard:

**Application Insights Query**:

```kql
// Save as function: GetConsumerMetrics
let subscriptionId = "acme-corp-prod";
requests
| where customDimensions.SubscriptionId == subscriptionId
| where timestamp > ago(24h)
| summarize
    TotalRequests = count(),
    SuccessRate = countif(success == true) * 100.0 / count(),
    AvgDuration = avg(duration),
    P95Duration = percentile(duration, 95)
    by bin(timestamp, 1h)
| render timechart
```

**Configure Consumer-Specific Alert** (optional):

```bash
# Alert when consumer exceeds 90% of quota
az monitor metrics alert create \
  --name "ai-gateway-quota-${CONSUMER_NAME}" \
  --resource-group $RG_NAME \
  --scopes "/subscriptions/<sub-id>/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME" \
  --condition "avg QuotaUsed > 9000" \
  --description "Consumer ${CONSUMER_NAME} approaching quota limit" \
  --evaluation-frequency 5m \
  --window-size 15m \
  --severity 2 \
  --action-groups "/subscriptions/<sub-id>/resourceGroups/$RG_NAME/providers/Microsoft.Insights/actionGroups/platform-team"
```

---

### Step 5: Prepare Consumer Documentation

Create a welcome package with:

1. **Subscription Key** (securely transmitted)
2. **API Endpoints**:
   - Gateway URL: `https://apim-aigateway-prod-eastus-01.azure-api.net`
   - Health: `GET /ai/health`
   - Summarize: `POST /ai/summarize`
   - Extract: `POST /ai/extract`

3. **Rate Limits & Quotas**:
   - Rate Limit: X requests/minute
   - Daily Quota: Y requests/day

4. **Documentation Links**:
   - [API Design Guide](../docs/api-design.md)
   - [Quick Test Guide](../docs/quick-test-guide.md)
   - [Testing Guide](../docs/testing-guide.md)

5. **Example Code**:

```python
import requests

# Configuration
BASE_URL = "https://apim-aigateway-prod-eastus-01.azure-api.net"
SUBSCRIPTION_KEY = "your-subscription-key"  # Store in Key Vault

# Test health endpoint
response = requests.get(
    f"{BASE_URL}/ai/health",
    headers={"Ocp-Apim-Subscription-Key": SUBSCRIPTION_KEY}
)
print(f"Health Status: {response.json()}")

# Summarize text
response = requests.post(
    f"{BASE_URL}/ai/summarize",
    headers={
        "Content-Type": "application/json",
        "Ocp-Apim-Subscription-Key": SUBSCRIPTION_KEY
    },
    json={
        "text": "Your long text here...",
        "max_length": 500,
        "style": "concise"
    }
)
print(f"Summary: {response.json()['summary']}")
```

6. **Support Contacts**:
   - Technical Support: api-support@example.com
   - Platform Team: platform-team@example.com

---

### Step 6: Securely Transmit Credentials

**IMPORTANT**: Never send subscription keys via email or chat

**Recommended Methods**:

**Option 1: Azure Key Vault (Preferred)**
```bash
# Store in consumer's Key Vault
az keyvault secret set \
  --vault-name "consumer-keyvault" \
  --name "ai-gateway-subscription-key" \
  --value "<primary-key>"

# Grant consumer access
az keyvault set-policy \
  --name "consumer-keyvault" \
  --object-id "<consumer-managed-identity-id>" \
  --secret-permissions get list
```

**Option 2: Secure Portal**
- Upload to internal secrets management system
- Share access link with time-limited access
- Require MFA for download

**Option 3: In-Person**
- For highly sensitive environments
- Present key in person or via secure video call

---

### Step 7: Initial Testing

Work with consumer to verify setup:

```bash
# Test health endpoint
curl -X GET "https://apim-aigateway-prod-eastus-01.azure-api.net/ai/health" \
  -H "Ocp-Apim-Subscription-Key: ${SUBSCRIPTION_KEY}"

# Expected response
# {
#   "status": "healthy",
#   "timestamp": "2026-03-17T10:30:00Z",
#   "services": {
#     "api_gateway": "healthy",
#     "ai_foundry": "healthy"
#   }
# }

# Test summarization
curl -X POST "https://apim-aigateway-prod-eastus-01.azure-api.net/ai/summarize" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: ${SUBSCRIPTION_KEY}" \
  -d '{
    "text": "Test text for summarization",
    "style": "concise"
  }'
```

**Verify in Application Insights**:
```kql
requests
| where customDimensions.SubscriptionId == "acme-corp-prod"
| where timestamp > ago(1h)
| project timestamp, name, resultCode, duration
| order by timestamp desc
```

---

### Step 8: Add to Cost Tracking

Update cost allocation spreadsheet or system:

| Subscription ID | Consumer | Cost Center | Environment | Rate Limit | Quota | Created Date |
|----------------|----------|-------------|-------------|------------|-------|--------------|
| acme-corp-prod | Acme Corp | CC-12345 | Production | 500/min | 50K/day | 2026-03-17 |

**Set up cost alerts**:
```bash
# Create budget for consumer
az consumption budget create \
  --budget-name "ai-gateway-${CONSUMER_NAME}" \
  --amount 500 \
  --category Cost \
  --time-grain Monthly \
  --time-period start-date=2026-03-01 \
  --notifications \
    threshold=80 \
    contact-emails="${CONSUMER_EMAIL},finance@example.com"
```

---

### Step 9: Documentation & Handoff

1. **Update Consumer Registry**:
   - Add to `docs/consumer-registry.md` (if exists)
   - Update internal wiki/documentation

2. **Notify Relevant Teams**:
   - Platform team
   - Finance team (for billing)
   - Support team

3. **Schedule Follow-up**:
   - 1 week: Check usage patterns
   - 1 month: Review cost and performance
   - Quarterly: Business review

---

## Post-Onboarding Checklist

- [ ] Subscription created in APIM
- [ ] Custom rate limits configured (if needed)
- [ ] Monitoring dashboard created
- [ ] Alerts configured
- [ ] Consumer documentation sent
- [ ] Credentials securely transmitted
- [ ] Initial testing completed successfully
- [ ] Cost tracking configured
- [ ] Consumer registry updated
- [ ] Teams notified
- [ ] Follow-up scheduled

---

## Common Issues & Troubleshooting

### Issue 1: Consumer Receives 401 Unauthorized

**Possible Causes**:
- Incorrect subscription key
- Subscription not active
- Wrong header name

**Resolution**:
```bash
# Verify subscription is active
az apim subscription show \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id $SUBSCRIPTION_NAME \
  --query "state"

# Verify key is correct
az apim subscription show \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id $SUBSCRIPTION_NAME \
  --query "primaryKey"
```

### Issue 2: Consumer Immediately Hits Rate Limit

**Possible Causes**:
- Incorrect rate limit configuration
- Multiple instances using same key
- Testing with loops

**Resolution**:
- Review consumer's code for loops
- Consider increasing rate limit if justified
- Suggest implementing backoff strategy

### Issue 3: No Metrics Appearing

**Possible Causes**:
- Subscription ID not logged correctly
- Delay in Application Insights ingestion

**Resolution**:
- Wait 5-10 minutes for ingestion
- Verify APIM diagnostic settings enabled
- Check policy includes logging

---

## Offboarding Process

When a consumer no longer needs access:

1. **Disable Subscription** (don't delete immediately):
   ```bash
   az apim subscription update \
     --resource-group $RG_NAME \
     --service-name $APIM_NAME \
     --subscription-id $SUBSCRIPTION_NAME \
     --state suspended
   ```

2. **Wait 30 days** for any billing reconciliation

3. **Delete Subscription**:
   ```bash
   az apim subscription delete \
     --resource-group $RG_NAME \
     --service-name $APIM_NAME \
     --subscription-id $SUBSCRIPTION_NAME
   ```

4. **Update Documentation**:
   - Remove from consumer registry
   - Update cost tracking
   - Notify relevant teams

---

## References

- [API Design Documentation](../docs/api-design.md)
- [Operations Guide](../docs/operations.md)
- [Azure APIM Subscription Management](https://learn.microsoft.com/azure/api-management/api-management-subscriptions)

---

**Runbook Version**: 1.0
**Last Updated**: 2026-03-17
**Owner**: Platform Team
