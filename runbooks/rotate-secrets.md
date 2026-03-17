# Runbook: How to Rotate Secrets

## Overview

This runbook provides step-by-step instructions for rotating secrets and keys in the Azure AI Gateway platform.

**Estimated Time**: 30-60 minutes (depending on scope)
**Frequency**: Quarterly (recommended) or as needed for security incidents
**Owner**: Platform Security Team / Platform Team

---

## Table of Contents

1. [APIM Subscription Keys](#apim-subscription-keys)
2. [Azure OpenAI Keys](#azure-openai-keys-not-recommended)
3. [Managed Identity Credentials](#managed-identity-credentials)
4. [Key Vault Secrets](#key-vault-secrets)
5. [Service Principal Credentials](#service-principal-credentials)
6. [Emergency Rotation (Security Incident)](#emergency-rotation-security-incident)

---

## Prerequisites

- [ ] Access to Azure Portal or Azure CLI
- [ ] Appropriate RBAC permissions (Contributor or Owner)
- [ ] Communication plan for affected consumers
- [ ] Backup of current configuration
- [ ] Monitoring dashboard access

---

## APIM Subscription Keys

### When to Rotate

- **Scheduled**: Every 90 days (recommended)
- **Ad-hoc**: When key is potentially compromised
- **Offboarding**: When team member leaves
- **Audit finding**: When security audit requires it

### Rotation Process

APIM subscription keys have two keys (primary and secondary) to allow zero-downtime rotation.

#### Step 1: Identify Subscriptions to Rotate

**List all subscriptions**:
```bash
# Set variables
APIM_NAME="apim-aigateway-prod-eastus-01"
RG_NAME="rg-aigateway-prod-eastus-01"

# List all subscriptions
az apim subscription list \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --query "[].{Name:displayName, ID:name, State:state}" \
  --output table
```

**Check last regeneration date** (via Azure Portal):
- Navigate to APIM → Subscriptions
- Review each subscription's created/modified date

#### Step 2: Notify API Consumer

**Timeline**: 30 days advance notice (for scheduled rotation)

**Email Template**:
```
Subject: [ACTION REQUIRED] AI Gateway Subscription Key Rotation - Due <Date>

Dear <Consumer Name>,

As part of our regular security maintenance, we will be rotating the
subscription key for your AI Gateway access.

Subscription: <subscription-name>
Current Key: Primary key ending in ...XXXX
New Key: Will be provided on <date>

Action Required:
1. Update your application configuration with the new key
2. Deploy updated configuration to all environments
3. Confirm successful migration by <deadline>

Timeline:
- <Date - 30 days>: New secondary key generated
- <Date - 14 days>: Reminder notification
- <Date - 7 days>: Final reminder
- <Date>: Old primary key will be revoked

Documentation:
- How to update key: <link to docs>
- Support contact: api-support@example.com

Please confirm receipt and planned migration date.
```

#### Step 3: Generate New Secondary Key

**Via Azure Portal**:
1. Navigate to API Management → Subscriptions
2. Select the subscription
3. Click "Regenerate secondary key"
4. Copy the new secondary key

**Via Azure CLI**:
```bash
SUBSCRIPTION_NAME="acme-corp-prod"

# Regenerate secondary key
az apim subscription regenerate-key \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id $SUBSCRIPTION_NAME \
  --key-type secondary

# Get new secondary key
az apim subscription show \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id $SUBSCRIPTION_NAME \
  --query "secondaryKey" \
  --output tsv
```

#### Step 4: Securely Provide New Key to Consumer

**Option 1: Azure Key Vault** (Recommended)
```bash
# Store new key in consumer's Key Vault
NEW_KEY=$(az apim subscription show \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id $SUBSCRIPTION_NAME \
  --query "secondaryKey" \
  --output tsv)

az keyvault secret set \
  --vault-name "consumer-keyvault" \
  --name "ai-gateway-subscription-key-new" \
  --value "$NEW_KEY"

# Notify consumer that new key is available in their Key Vault
```

**Option 2: Secure Portal**
- Upload to secure file sharing system
- Send time-limited access link
- Require MFA for access

#### Step 5: Monitor Migration Progress

**Track usage of old vs new key**:

```kql
// Application Insights query
requests
| where customDimensions.SubscriptionId == "acme-corp-prod"
| where timestamp > ago(7d)
| extend KeyUsed = iff(customDimensions.KeyId contains "primary", "Primary", "Secondary")
| summarize RequestCount = count() by KeyUsed, bin(timestamp, 1h)
| render timechart
```

**Check for errors**:
```kql
requests
| where customDimensions.SubscriptionId == "acme-corp-prod"
| where success == false
| where resultCode == 401
| where timestamp > ago(24h)
| project timestamp, resultCode, customDimensions.ErrorMessage
```

#### Step 6: Verify Consumer Migration

Wait for consumer confirmation:
- [ ] Consumer confirms application updated
- [ ] Consumer confirms testing successful
- [ ] Monitor shows traffic on secondary key
- [ ] No authentication errors reported

**Verification Command**:
```bash
# Test with new secondary key
curl -X GET "https://${APIM_NAME}.azure-api.net/ai/health" \
  -H "Ocp-Apim-Subscription-Key: ${NEW_SECONDARY_KEY}"

# Should return 200 OK
```

#### Step 7: Regenerate Primary Key

After confirming migration (typically 14 days):

```bash
# Regenerate primary key
az apim subscription regenerate-key \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id $SUBSCRIPTION_NAME \
  --key-type primary

# Get new primary key
NEW_PRIMARY_KEY=$(az apim subscription show \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id $SUBSCRIPTION_NAME \
  --query "primaryKey" \
  --output tsv)

echo "New primary key: $NEW_PRIMARY_KEY"
```

#### Step 8: Promote Secondary to Primary

Instruct consumer to switch from secondary back to primary (optional):

**This step is optional** - consumer can continue using secondary key indefinitely.

#### Step 9: Document Rotation

Update rotation log:

**File**: `docs/secret-rotation-log.md` (create if doesn't exist)

```markdown
## Subscription Key Rotations

| Date | Subscription | Consumer | Reason | Rotated By |
|------|--------------|----------|--------|------------|
| 2026-03-17 | acme-corp-prod | Acme Corp | Scheduled (90-day) | john.doe@example.com |
```

---

## Azure OpenAI Keys (Not Recommended)

**NOTE**: This platform uses Managed Identity for Azure OpenAI authentication, so API keys should **not** be used. This section is for reference only.

### If Using API Keys (Legacy/Backup)

Azure OpenAI accounts have two keys for zero-downtime rotation.

**Check current keys**:
```bash
OPENAI_ACCOUNT="ai-aigateway-prod-eastus-01"

az cognitiveservices account keys list \
  --name $OPENAI_ACCOUNT \
  --resource-group $RG_NAME
```

**Rotate Key 2** (while Key 1 is in use):
```bash
az cognitiveservices account keys regenerate \
  --name $OPENAI_ACCOUNT \
  --resource-group $RG_NAME \
  --key-name key2
```

**Update Key Vault**:
```bash
NEW_KEY=$(az cognitiveservices account keys list \
  --name $OPENAI_ACCOUNT \
  --resource-group $RG_NAME \
  --query "key2" \
  --output tsv)

az keyvault secret set \
  --vault-name "kv-aigateway-prod-eastus-01" \
  --name "azure-openai-key" \
  --value "$NEW_KEY"
```

**Important**: If using Managed Identity (recommended), this is **not necessary**.

---

## Managed Identity Credentials

### Background

Managed Identities are automatically managed by Azure. Credentials are rotated automatically by the platform every 90 days.

**No manual rotation required** for Managed Identity credentials.

### Verifying Managed Identity Health

```bash
# Check Managed Identity status
MI_NAME="mi-aigateway-prod-eastus-01"

az identity show \
  --name $MI_NAME \
  --resource-group $RG_NAME \
  --query "{Name:name, PrincipalId:principalId, ClientId:clientId}"

# Verify RBAC assignments
az role assignment list \
  --assignee <principal-id> \
  --all \
  --query "[].{Role:roleDefinitionName, Scope:scope}" \
  --output table
```

### Recreating Managed Identity (Emergency Only)

**WARNING**: This will cause service interruption. Only do this if identity is compromised.

```bash
# 1. Create new Managed Identity
az identity create \
  --name "mi-aigateway-prod-eastus-01-new" \
  --resource-group $RG_NAME

# 2. Assign RBAC roles (same as old identity)
NEW_PRINCIPAL_ID=$(az identity show \
  --name "mi-aigateway-prod-eastus-01-new" \
  --resource-group $RG_NAME \
  --query "principalId" \
  --output tsv)

# Grant Cognitive Services User role
az role assignment create \
  --assignee $NEW_PRINCIPAL_ID \
  --role "Cognitive Services User" \
  --scope "/subscriptions/<sub-id>/resourceGroups/$RG_NAME/providers/Microsoft.CognitiveServices/accounts/$OPENAI_ACCOUNT"

# Grant Key Vault Secrets User role
az role assignment create \
  --assignee $NEW_PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/<sub-id>/resourceGroups/$RG_NAME/providers/Microsoft.KeyVault/vaults/kv-aigateway-prod-eastus-01"

# 3. Update APIM to use new identity
az apim update \
  --name $APIM_NAME \
  --resource-group $RG_NAME \
  --set identity.userAssignedIdentities="/subscriptions/<sub-id>/resourceGroups/$RG_NAME/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-aigateway-prod-eastus-01-new"

# 4. Test
curl -X GET "https://${APIM_NAME}.azure-api.net/ai/health" \
  -H "Ocp-Apim-Subscription-Key: <test-key>"

# 5. Delete old identity (after verification)
az identity delete \
  --name "mi-aigateway-prod-eastus-01" \
  --resource-group $RG_NAME
```

---

## Key Vault Secrets

### Rotate Secrets Stored in Key Vault

**List all secrets**:
```bash
KV_NAME="kv-aigateway-prod-eastus-01"

az keyvault secret list \
  --vault-name $KV_NAME \
  --query "[].{Name:name, Updated:attributes.updated}" \
  --output table
```

### Example: Rotate a Database Connection String

```bash
SECRET_NAME="database-connection-string"

# 1. Generate new connection string (application-specific)
# For example, create new database user or rotate password

# 2. Store new secret version
az keyvault secret set \
  --vault-name $KV_NAME \
  --name $SECRET_NAME \
  --value "new-connection-string-here"

# 3. Verify new secret
az keyvault secret show \
  --vault-name $KV_NAME \
  --name $SECRET_NAME \
  --query "value"

# 4. Update application to use new secret
# APIM will automatically use the latest version

# 5. Test
# Verify application works with new secret

# 6. Disable old secret version (optional)
OLD_VERSION="abc123..."
az keyvault secret set-attributes \
  --vault-name $KV_NAME \
  --name $SECRET_NAME \
  --version $OLD_VERSION \
  --enabled false
```

### Best Practices for Key Vault Secrets

1. **Version Management**: Keep old version enabled for 30 days before disabling
2. **Naming**: Use descriptive names with environment suffix
3. **Monitoring**: Enable audit logging to track secret access
4. **Expiration**: Set expiration dates on secrets

```bash
# Set secret with expiration
az keyvault secret set \
  --vault-name $KV_NAME \
  --name $SECRET_NAME \
  --value "secret-value" \
  --expires "2026-06-17T00:00:00Z"
```

---

## Service Principal Credentials

### When to Rotate

- **Scheduled**: Every 90 days
- **Security Incident**: Immediately if compromised
- **Offboarding**: When team member with access leaves

### Rotation Process

**For Terraform Service Principal**:

#### Step 1: Create New Secret

```bash
SP_APP_ID="<service-principal-app-id>"

# Create new secret
az ad app credential reset \
  --id $SP_APP_ID \
  --append \
  --display-name "terraform-sp-$(date +%Y%m%d)"

# Save the output (includes new password)
```

#### Step 2: Update Pipeline/CI-CD Variables

**Azure DevOps**:
1. Navigate to Pipelines → Library → Variable Groups
2. Select "ai-gateway-prod"
3. Update `ARM_CLIENT_SECRET` with new value
4. Save

**GitHub Actions**:
1. Navigate to Settings → Secrets and variables → Actions
2. Update `AZURE_CLIENT_SECRET`
3. Save

#### Step 3: Test New Credentials

```bash
# Test authentication
az login --service-principal \
  --username $SP_APP_ID \
  --password "<new-password>" \
  --tenant "<tenant-id>"

# Test Terraform
cd terraform
terraform init
terraform plan
```

#### Step 4: Remove Old Secret

**Wait 30 days** to ensure no dependencies on old secret.

```bash
# List all credentials
az ad app credential list \
  --id $SP_APP_ID

# Delete old credential by key ID
az ad app credential delete \
  --id $SP_APP_ID \
  --key-id "<old-key-id>"
```

---

## Emergency Rotation (Security Incident)

### When Credentials Are Compromised

**Immediate Actions** (within 1 hour):

#### 1. Assess Scope

- [ ] Identify which credential was compromised
- [ ] Determine time of compromise
- [ ] Identify affected services/consumers
- [ ] Check audit logs for unauthorized access

```kql
// Key Vault access logs
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where TimeGenerated > ago(7d)
| where ResultType == "Success"
| project TimeGenerated, CallerIPAddress, OperationName, ResourceId
| order by TimeGenerated desc
```

#### 2. Immediately Revoke Compromised Credential

**For APIM Subscription Key**:
```bash
# Disable subscription immediately
az apim subscription update \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id $SUBSCRIPTION_NAME \
  --state suspended
```

**For Service Principal**:
```bash
# Delete compromised secret immediately
az ad app credential delete \
  --id $SP_APP_ID \
  --key-id "<compromised-key-id>"
```

#### 3. Generate New Credential

Follow standard rotation process (documented above) but with **expedited timeline**.

#### 4. Notify Affected Parties

**Email Template**:
```
Subject: [SECURITY ALERT] AI Gateway Credential Rotation - Immediate Action Required

Dear Team,

A security incident has been detected that requires immediate credential rotation.

Affected: <subscription/service>
Action: Credential has been revoked
New Credential: Available in <location>

Required Actions:
1. Update application configuration immediately
2. Deploy to all environments ASAP
3. Confirm successful migration within 4 hours

Support:
Emergency support line: <phone>
Email: security@example.com

This is a time-sensitive security matter.
```

#### 5. Investigate & Document

- Review audit logs for timeline
- Identify how compromise occurred
- Document lessons learned
- Update security procedures

#### 6. Post-Incident Review

Within 48 hours, create post-mortem:
- Timeline of events
- Root cause analysis
- Impact assessment
- Remediation actions taken
- Preventive measures for future

---

## Rotation Schedule

### Recommended Rotation Frequency

| Credential Type | Frequency | Priority |
|----------------|-----------|----------|
| APIM Subscription Keys | 90 days | Medium |
| Service Principal Secrets | 90 days | High |
| Key Vault Secrets | 90 days | Medium |
| Azure OpenAI Keys | N/A (use Managed Identity) | - |
| Managed Identity | Automatic (Azure managed) | - |

### Create Rotation Calendar

**File**: `docs/rotation-calendar.md`

```markdown
## 2026 Rotation Schedule

| Quarter | Credential Type | Due Date | Status |
|---------|----------------|----------|--------|
| Q1 2026 | Service Principal | 2026-03-31 | ✅ Complete |
| Q1 2026 | APIM Subscriptions | 2026-03-31 | 🔄 In Progress |
| Q2 2026 | Service Principal | 2026-06-30 | ⏳ Pending |
| Q2 2026 | APIM Subscriptions | 2026-06-30 | ⏳ Pending |
```

### Automate Rotation Reminders

**Azure Monitor Action Group** (Email reminder):

```bash
# Create reminder alert 7 days before rotation due
az monitor metrics alert create \
  --name "credential-rotation-reminder" \
  --resource-group $RG_NAME \
  --description "Reminder to rotate credentials" \
  --condition "avg 1" \
  --evaluation-frequency 1d \
  --window-size 1d
```

---

## Verification & Testing

### Post-Rotation Checklist

After any credential rotation:

- [ ] New credential stored securely
- [ ] Old credential revoked (after grace period)
- [ ] Application tested with new credential
- [ ] Monitoring shows no authentication errors
- [ ] Consumers notified and confirmed migration
- [ ] Documentation updated
- [ ] Rotation log updated
- [ ] Next rotation scheduled

### Verification Commands

```bash
# Test APIM subscription key
curl -X GET "https://${APIM_NAME}.azure-api.net/ai/health" \
  -H "Ocp-Apim-Subscription-Key: ${NEW_KEY}" \
  -w "\nHTTP Status: %{http_code}\n"

# Check for 401 errors in last 24h
az monitor metrics list \
  --resource "/subscriptions/<sub-id>/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME" \
  --metric "UnauthorizedRequests" \
  --start-time "$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

---

## Troubleshooting

### Issue 1: Consumer Unable to Use New Key

**Symptoms**: 401 Unauthorized after rotation

**Diagnosis**:
```bash
# Verify subscription is active
az apim subscription show \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id $SUBSCRIPTION_NAME \
  --query "state"

# Check subscription key
az apim subscription show \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --subscription-id $SUBSCRIPTION_NAME \
  --query "{Primary:primaryKey, Secondary:secondaryKey}"
```

**Resolution**:
- Verify correct key provided to consumer
- Check subscription state is "active"
- Verify consumer using correct header name

### Issue 2: Service Disruption After Rotation

**Symptoms**: 5xx errors after credential rotation

**Diagnosis**:
```kql
exceptions
| where timestamp > ago(1h)
| where outerMessage contains "authentication" or outerMessage contains "unauthorized"
| project timestamp, outerMessage, customDimensions
```

**Resolution**:
- Check Managed Identity assignments
- Verify RBAC roles still assigned
- Review APIM backend authentication configuration

---

## References

- [Azure APIM Subscription Keys](https://learn.microsoft.com/azure/api-management/api-management-subscriptions)
- [Azure Key Vault Secret Rotation](https://learn.microsoft.com/azure/key-vault/secrets/tutorial-rotation)
- [Service Principal Credentials](https://learn.microsoft.com/azure/active-directory/develop/howto-create-service-principal-portal)
- [Security Guide](../docs/security.md)

---

**Runbook Version**: 1.0
**Last Updated**: 2026-03-17
**Owner**: Platform Security Team
