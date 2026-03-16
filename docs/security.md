# Security & Compliance Guide

## Overview

This document outlines the security architecture, controls, and best practices implemented in the Azure AI Gateway platform.

## Table of Contents

1. [Network Security](#network-security)
2. [Identity & Access Management](#identity--access-management)
3. [Data Protection](#data-protection)
4. [Compliance & Governance](#compliance--governance)
5. [Security Monitoring](#security-monitoring)
6. [Incident Response](#incident-response)

---

## Network Security

### TLS/HTTPS Enforcement

**APIM Configuration** ([api-management/main.tf:15-25](../terraform/modules/api-management/main.tf#L15-L25))
- **TLS 1.2+** enforced on both frontend and backend connections
- SSL 3.0, TLS 1.0, and TLS 1.1 explicitly disabled
- Backend certificate validation enabled

```hcl
security {
  enable_backend_ssl30  = false
  enable_backend_tls10  = false
  enable_backend_tls11  = false
  enable_frontend_ssl30 = false
  enable_frontend_tls10 = false
  enable_frontend_tls11 = false
}
```

**Backend Protocol** ([api-management/main.tf:60-67](../terraform/modules/api-management/main.tf#L60-L67))
- All backend connections use HTTPS
- Certificate chain validation enabled
- Certificate name validation enabled

### Public Endpoints

- All services use public endpoints by default
- This design choice prioritizes simplicity for MVP
- **Future Enhancement**: VNet integration and private endpoints can be added for enhanced security

### Network Access Control

**Key Vault** ([key-vault/main.tf:14-17](../terraform/modules/key-vault/main.tf#L14-L17))
- Default deny network ACL
- Azure Services bypass enabled for service-to-service communication
- Can be further restricted with IP allowlists if needed

---

## Identity & Access Management

### Managed Identity Architecture

**Service-to-Service Authentication**
- All Azure service communications use Managed Identity (no API keys)
- APIM uses User-Assigned Managed Identity
- Azure OpenAI has `local_auth_enabled = false` (key-based auth disabled)

**Identity Flow**:
```
Client → [Subscription Key] → APIM → [Managed Identity] → Azure OpenAI
```

### Role-Based Access Control (RBAC)

#### Azure OpenAI Access
**Role**: Cognitive Services User
**Principal**: APIM Managed Identity
**Scope**: Azure OpenAI Cognitive Account
**File**: [ai-foundry/main.tf:61-65](../terraform/modules/ai-foundry/main.tf#L61-L65)

```hcl
resource "azurerm_role_assignment" "cognitive_services_user" {
  scope                = azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services User"
  principal_id         = var.managed_identity_principal_id
}
```

#### Key Vault Access
**Managed Identity Access**
**Role**: Key Vault Secrets User
**Principal**: APIM Managed Identity
**Scope**: Key Vault
**File**: [key-vault/main.tf:27-31](../terraform/modules/key-vault/main.tf#L27-L31)

**Administrator Access**
**Role**: Key Vault Administrator
**Principal**: Current User/Service Principal
**Scope**: Key Vault
**File**: [key-vault/main.tf:34-38](../terraform/modules/key-vault/main.tf#L34-L38)

### Authentication Model

**Client Authentication**
- Subscription Key (primary method)
- Configured in APIM base policy ([base-policy.xml:3-4](../apim-policies/global/base-policy.xml#L3-L4))
- Per-subscription rate limiting and quotas

**Future Enhancements**:
- OAuth 2.0 / Azure Entra ID integration
- JWT token validation
- IP-based access restrictions

---

## Data Protection

### Encryption at Rest
- **Azure Default Encryption**: All data encrypted at rest using Azure Storage Service Encryption
- **Key Vault**: Purge protection enabled ([key-vault/main.tf:10](../terraform/modules/key-vault/main.tf#L10))
- **Soft Delete**: 90-day retention for Key Vault ([key-vault/main.tf:9](../terraform/modules/key-vault/main.tf#L9))

### Encryption in Transit
- TLS 1.2+ enforced for all connections
- HTTPS only for backend communications
- Certificate validation enabled

### Secrets Management
- **Zero Secrets in Code**: No API keys, connection strings, or credentials in repository
- **Key Vault Storage**: All secrets stored in Azure Key Vault
- **RBAC Access**: Secrets accessed via Managed Identity with least privilege

### Request/Response Sanitization
- Subscription key validation before processing
- Error messages sanitized (no internal details exposed)
- Request ID tracking for audit purposes

---

## Compliance & Governance

### Resource Locks

**Production Environment Protection**
Resource locks are automatically applied to production resources to prevent accidental deletion.

**Protected Resources**:
1. **Resource Group** ([resource-group/locks.tf](../terraform/modules/resource-group/locks.tf))
2. **API Management** ([api-management/locks.tf](../terraform/modules/api-management/locks.tf))
3. **Key Vault** ([key-vault/locks.tf](../terraform/modules/key-vault/locks.tf))
4. **Azure OpenAI** ([ai-foundry/locks.tf](../terraform/modules/ai-foundry/locks.tf))

**Lock Level**: `CanNotDelete`
- Resources can be modified but not deleted
- Requires explicit lock removal before deletion

### Audit Logging

**Key Vault Audit Events** ([key-vault/main.tf:41-54](../terraform/modules/key-vault/main.tf#L41-L54))
- All access attempts logged
- Forwarded to Log Analytics workspace
- Includes successful and failed access

**Azure OpenAI Audit Logs** ([ai-foundry/main.tf:68-85](../terraform/modules/ai-foundry/main.tf#L68-L85))
- Audit events logged
- Request/response logging enabled (monitor for sensitive data)
- All metrics tracked

**APIM Gateway Logs** ([api-management/main.tf:70-79](../terraform/modules/api-management/main.tf#L70-L79))
- All API requests logged
- Diagnostic settings to Log Analytics
- Includes request metadata, errors, and performance metrics

### Tagging Strategy

**Standard Tags** ([main.tf:138-147](../terraform/main.tf#L138-L147))
```hcl
{
  Environment = "prod|staging|dev"
  Project     = "ai-gateway"
  ManagedBy   = "terraform"
  CreatedDate = timestamp()
}
```

### Azure Policy (Future)

**Recommended Policies**:
- Require TLS 1.2+ for all services
- Require diagnostic settings on all resources
- Require Managed Identity for all compute resources
- Deny public storage account access
- Require encryption at rest

**Implementation**: Create policy assignments in a future phase

---

## Security Monitoring

### Application Insights Integration

**Custom Metrics Tracked**:
- Total AI requests
- Token usage per request
- Error rates (4xx, 5xx)
- Response times
- Quota exhaustion events

**Log Integration** ([logging-policy.xml](../apim-policies/global/logging-policy.xml))
- Request ID tracking
- Subscription ID logging
- Client IP logging
- Timestamp and response codes

### Azure Monitor Alerts

**Configured Alerts** ([monitoring-alerts/alerts.tf](../terraform/modules/monitoring-alerts/alerts.tf))
1. High error rates (>5% 5xx errors)
2. Quota exhaustion
3. Unusual token usage
4. APIM availability issues
5. High latency (>5s P95)

### Security Alerts (Recommended)

**Future Enhancements**:
- Failed authentication attempts (multiple)
- Suspicious API usage patterns
- Unusual geographic access
- Key Vault access anomalies

---

## Incident Response

### Security Incident Playbook

#### 1. Suspected API Key Compromise
**Actions**:
1. Immediately revoke the compromised subscription key in APIM
2. Review audit logs for unauthorized access
3. Generate new subscription key for legitimate user
4. Investigate scope of breach
5. Document incident

#### 2. Unusual Usage Pattern
**Actions**:
1. Check Azure Monitor alerts for quota exhaustion
2. Review Application Insights for request patterns
3. Identify subscription and user
4. Temporarily throttle or block if necessary
5. Contact user to verify legitimate usage

#### 3. Azure Service Compromise
**Actions**:
1. Rotate Managed Identity if possible (or rotate downstream secrets)
2. Review RBAC assignments for unauthorized changes
3. Check audit logs for timeline of events
4. Engage Azure support if needed
5. Document and create post-mortem

#### 4. Key Vault Access Breach
**Actions**:
1. Review Key Vault audit logs
2. Identify accessed secrets
3. Rotate affected secrets immediately
4. Review and restrict RBAC assignments
5. Enable additional network restrictions
6. Document incident and update procedures

### Emergency Contacts

**Update the following**:
- Security Team Email: `security@example.com`
- On-Call Engineer: `oncall@example.com`
- Azure Support: Available via Azure Portal

---

## Security Checklist

### Pre-Deployment
- [ ] Review all Terraform configurations for hardcoded secrets
- [ ] Verify RBAC assignments follow least privilege
- [ ] Confirm TLS 1.2+ enforcement
- [ ] Validate network ACLs on Key Vault
- [ ] Enable audit logging on all resources

### Post-Deployment
- [ ] Verify Managed Identity authentication works
- [ ] Test subscription key authentication
- [ ] Confirm audit logs flowing to Log Analytics
- [ ] Test Azure Monitor alerts
- [ ] Review APIM diagnostic logs
- [ ] Verify resource locks applied (production only)

### Regular Reviews (Monthly)
- [ ] Review RBAC assignments
- [ ] Audit subscription key usage
- [ ] Review security alerts and anomalies
- [ ] Check for Azure security advisories
- [ ] Update dependencies and modules
- [ ] Review and rotate secrets if necessary

---

## Best Practices

### Development
1. **Never commit secrets**: Use `.gitignore` and pre-commit hooks
2. **Use Managed Identity**: Avoid API keys wherever possible
3. **Least Privilege**: Grant minimum permissions required
4. **Enable Logging**: All resources should have diagnostic settings
5. **Test Security**: Include security tests in CI/CD pipeline

### Production
1. **Enable Resource Locks**: Prevent accidental deletion
2. **Monitor Alerts**: Configure actionable alerts with proper routing
3. **Regular Audits**: Review logs and RBAC assignments monthly
4. **Incident Response**: Have documented procedures ready
5. **Backup Strategy**: Ensure Key Vault soft delete is enabled

### API Consumers
1. **Secure Storage**: Store subscription keys in secure key management systems
2. **Rotate Keys**: Regularly rotate subscription keys
3. **Monitor Usage**: Track token consumption and costs
4. **Report Issues**: Immediately report suspicious activity

---

## References

- [Azure API Management Security](https://learn.microsoft.com/azure/api-management/api-management-security-controls)
- [Azure OpenAI Security Best Practices](https://learn.microsoft.com/azure/ai-services/openai/how-to/managed-identity)
- [Azure Key Vault Security](https://learn.microsoft.com/azure/key-vault/general/security-features)
- [Managed Identity Overview](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)

---

**Document Version**: 1.0
**Last Updated**: 2026-03-16
**Owner**: Platform Security Team
