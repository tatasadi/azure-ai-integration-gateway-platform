# RBAC Model Documentation

## Overview

This document describes the Role-Based Access Control (RBAC) model implemented for the Azure AI Gateway platform, following the principle of least privilege.

---

## RBAC Architecture

### Service Identity

**User-Assigned Managed Identity**
- **Name**: `id-{project_name}-{environment}-{location}`
- **Purpose**: Service-to-service authentication for APIM
- **Module**: [managed-identity/main.tf](../terraform/modules/managed-identity/main.tf)

---

## Role Assignments

### 1. Azure OpenAI Access

**Configuration**: [ai-foundry/main.tf:61-65](../terraform/modules/ai-foundry/main.tf#L61-L65)

```hcl
resource "azurerm_role_assignment" "cognitive_services_user" {
  scope                = azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services User"
  principal_id         = var.managed_identity_principal_id
}
```

| Property | Value |
|----------|-------|
| **Role** | Cognitive Services User |
| **Principal** | APIM Managed Identity |
| **Scope** | Azure OpenAI Cognitive Account |
| **Permissions** | Call Azure OpenAI APIs, inference only |
| **Justification** | APIM needs to forward requests to Azure OpenAI |

**Permissions Granted**:
- `Microsoft.CognitiveServices/accounts/*/read`
- `Microsoft.CognitiveServices/accounts/*/action`

**Permissions NOT Granted** (Least Privilege):
- Cannot delete or modify the OpenAI account
- Cannot manage model deployments
- Cannot change account settings
- Cannot manage keys (not needed, using Managed Identity)

---

### 2. Key Vault Access - Managed Identity

**Configuration**: [key-vault/main.tf:27-31](../terraform/modules/key-vault/main.tf#L27-L31)

```hcl
resource "azurerm_role_assignment" "mi_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.managed_identity_id
}
```

| Property | Value |
|----------|-------|
| **Role** | Key Vault Secrets User |
| **Principal** | APIM Managed Identity |
| **Scope** | Key Vault |
| **Permissions** | Read secret contents only |
| **Justification** | APIM needs to read configuration secrets |

**Permissions Granted**:
- `Microsoft.KeyVault/vaults/secrets/getSecret/action`
- Read secret contents

**Permissions NOT Granted**:
- Cannot create, update, or delete secrets
- Cannot manage Key Vault settings
- Cannot manage access policies or RBAC
- Cannot purge or recover secrets

---

### 3. Key Vault Access - Administrators

**Configuration**: [key-vault/main.tf:34-38](../terraform/modules/key-vault/main.tf#L34-L38)

```hcl
resource "azurerm_role_assignment" "current_user_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}
```

| Property | Value |
|----------|-------|
| **Role** | Key Vault Administrator |
| **Principal** | Terraform Service Principal / Current User |
| **Scope** | Key Vault |
| **Permissions** | Full management of Key Vault |
| **Justification** | Required for Terraform to manage secrets and configuration |

**Permissions Granted**:
- Full control over secrets, keys, and certificates
- Manage access policies and RBAC
- Purge and recover operations
- Configure Key Vault settings

---

## Permission Matrix

| Service / User | Azure OpenAI | Key Vault | API Management | Resource Group |
|---------------|--------------|-----------|----------------|----------------|
| **APIM Managed Identity** | Cognitive Services User (Call APIs) | Secrets User (Read Only) | System-Assigned (Self) | - |
| **Terraform SP** | Contributor (Full) | Administrator (Full) | Contributor (Full) | Contributor (Full) |
| **API Consumers** | None (via APIM only) | None | Subscription Key Auth | - |
| **Platform Admins** | Reader (View) | Administrator (Full) | Contributor (Full) | Contributor (Full) |
| **Developers** | Reader (View) | Secrets User (Read) | Reader (View) | Reader (View) |

---

## Identity Flow

### API Request Flow

```
1. Client → [Subscription Key] → APIM
2. APIM validates subscription key
3. APIM → [Managed Identity Token] → Azure AD
4. Azure AD validates identity
5. Azure AD → [Access Token] → APIM
6. APIM → [Access Token] → Azure OpenAI
7. Azure OpenAI validates token and RBAC
8. Azure OpenAI processes request
9. Response flows back to client
```

### Key Vault Access Flow

```
1. APIM needs secret → [Managed Identity Token] → Azure AD
2. Azure AD → [Access Token] → APIM
3. APIM → [Access Token] → Key Vault
4. Key Vault validates RBAC (Secrets User role)
5. Key Vault → [Secret Value] → APIM
```

---

## Security Controls

### Disabled Authentication Methods

**Azure OpenAI** ([ai-foundry/main.tf:8](../terraform/modules/ai-foundry/main.tf#L8))
```hcl
local_auth_enabled = false
```
- **Effect**: API key authentication is disabled
- **Result**: Only Managed Identity or Azure AD authentication is accepted
- **Benefit**: Eliminates risk of API key leakage

### Key Vault RBAC Mode

**Key Vault** ([key-vault/main.tf:11](../terraform/modules/key-vault/main.tf#L11))
```hcl
enable_rbac_authorization = true
```
- **Effect**: Uses Azure RBAC instead of Access Policies
- **Benefit**: Centralized, auditable, and consistent with Azure governance

---

## User Roles & Responsibilities

### Platform Administrators
**Access Required**:
- Contributor on Resource Group
- Key Vault Administrator
- Can view all resources
- Can modify infrastructure via Terraform

**Responsibilities**:
- Deploy and manage infrastructure
- Rotate secrets when necessary
- Review audit logs
- Respond to security incidents

### Developers
**Access Required**:
- Reader on Resource Group
- Reader on APIM
- Secrets User on Key Vault (if debugging)

**Responsibilities**:
- Develop and test APIM policies
- Review logs and metrics
- Report security issues

### API Consumers
**Access Required**:
- APIM Subscription Key only
- No direct Azure resource access

**Responsibilities**:
- Securely store subscription keys
- Rotate keys regularly
- Monitor their usage and costs
- Report suspicious activity

---

## Adding New Services

### Granting New Service Access to Azure OpenAI

**Scenario**: A new service needs to call Azure OpenAI

**Steps**:
1. Create User-Assigned Managed Identity for new service
2. Assign identity to the service
3. Grant "Cognitive Services User" role:

```hcl
resource "azurerm_role_assignment" "new_service_openai" {
  scope                = azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_user_assigned_identity.new_service.principal_id
}
```

### Granting User Access to Key Vault

**Scenario**: A user needs to read secrets for debugging

**Steps**:
1. Get user's Object ID from Azure AD
2. Grant "Key Vault Secrets User" role:

```bash
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee <user-object-id> \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<kv-name>
```

---

## Auditing & Monitoring

### RBAC Changes
- All role assignments are logged in Azure Activity Log
- Diagnostic settings forward logs to Log Analytics
- Review regularly for unauthorized changes

### Access Attempts
- Key Vault logs all access attempts ([key-vault/main.tf:41-54](../terraform/modules/key-vault/main.tf#L41-L54))
- Azure OpenAI logs API calls ([ai-foundry/main.tf:68-85](../terraform/modules/ai-foundry/main.tf#L68-85))
- Failed authentication attempts are logged

### Queries for Monitoring

**List all role assignments**:
```bash
az role assignment list --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group-name>
```

**Check Key Vault access logs** (Kusto/KQL):
```kql
AzureDiagnostics
| where ResourceType == "VAULTS"
| where OperationName == "SecretGet"
| project TimeGenerated, CallerIPAddress, identity_claim_appid_g, ResultSignature
| order by TimeGenerated desc
```

**Check OpenAI API calls**:
```kql
AzureDiagnostics
| where ResourceType == "COGNITIVESERVICES"
| where Category == "RequestResponse"
| project TimeGenerated, identity_claim_appid_g, OperationName, ResultType
| order by TimeGenerated desc
```

---

## Compliance

### Least Privilege Principle
✅ Each identity has only the permissions required for its function
✅ No wildcard permissions granted
✅ Regular reviews scheduled

### Separation of Duties
✅ API consumers cannot access Azure resources directly
✅ Services use Managed Identity (no shared keys)
✅ Admins separated from developers

### Audit Trail
✅ All access logged to Log Analytics
✅ Activity logs retained for compliance period
✅ RBAC changes are auditable

---

## Troubleshooting

### Error: "Forbidden" when calling Azure OpenAI

**Possible Causes**:
1. Managed Identity not assigned "Cognitive Services User" role
2. Role assignment not yet propagated (can take a few minutes)
3. Managed Identity not correctly assigned to APIM

**Resolution**:
```bash
# Verify role assignment
az role assignment list --assignee <managed-identity-object-id> --scope <openai-resource-id>

# If missing, create it
az role assignment create \
  --role "Cognitive Services User" \
  --assignee <managed-identity-object-id> \
  --scope <openai-resource-id>
```

### Error: "Access Denied" to Key Vault

**Possible Causes**:
1. RBAC not enabled on Key Vault
2. Managed Identity not assigned "Key Vault Secrets User" role
3. Network ACL blocking access

**Resolution**:
```bash
# Check RBAC mode
az keyvault show --name <keyvault-name> --query properties.enableRbacAuthorization

# Verify role assignment
az role assignment list --assignee <managed-identity-object-id> --scope <keyvault-resource-id>

# Check network rules
az keyvault network-rule list --name <keyvault-name>
```

---

## Future Enhancements

### Recommended Additions
1. **Azure AD Groups**: Group-based RBAC for easier management
2. **Privileged Identity Management (PIM)**: Just-in-time admin access
3. **Conditional Access**: Location and device-based policies
4. **Custom Roles**: Fine-tuned permissions for specific use cases

### OAuth 2.0 Integration
For API consumers, consider migrating from subscription keys to OAuth 2.0:
- Azure AD authentication
- JWT token validation in APIM
- Scope-based authorization

---

## References

- [Azure RBAC Documentation](https://learn.microsoft.com/azure/role-based-access-control/overview)
- [Managed Identity Best Practices](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/managed-identity-best-practice-recommendations)
- [Azure OpenAI RBAC](https://learn.microsoft.com/azure/ai-services/openai/how-to/managed-identity)
- [Key Vault RBAC Guide](https://learn.microsoft.com/azure/key-vault/general/rbac-guide)

---

**Document Version**: 1.0
**Last Updated**: 2026-03-16
**Owner**: Platform Security Team
