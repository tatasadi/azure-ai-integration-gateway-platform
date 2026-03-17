# Azure AI Gateway Runbooks

This directory contains operational runbooks for common tasks in the Azure AI Integration Gateway platform.

## Available Runbooks

### 1. [Onboard New API Consumer](onboard-new-api-consumer.md)
**When to use**: Adding a new team or application to the AI Gateway

**Tasks covered**:
- Creating APIM subscriptions
- Configuring rate limits and quotas
- Setting up monitoring
- Securely providing credentials
- Testing and verification

**Estimated time**: 15-30 minutes

---

### 2. [Add New AI Operation](add-new-ai-operation.md)
**When to use**: Adding a new endpoint/feature to the API (e.g., translation, classification)

**Tasks covered**:
- Designing the API operation
- Creating APIM policies
- Updating Terraform configuration
- Writing integration tests
- Deploying across environments

**Estimated time**: 2-4 hours

---

### 3. [Rotate Secrets](rotate-secrets.md)
**When to use**: Regular security maintenance or after potential compromise

**Tasks covered**:
- APIM subscription key rotation
- Azure OpenAI key rotation (if applicable)
- Service principal credential rotation
- Key Vault secret rotation
- Emergency rotation procedures

**Estimated time**: 30-60 minutes

**Frequency**: Every 90 days (recommended)

---

### 4. [Scale APIM](scale-apim.md)
**When to use**: Performance issues, capacity planning, or tier upgrades

**Tasks covered**:
- Understanding APIM tiers
- Vertical scaling (tier upgrades)
- Horizontal scaling (adding units)
- Monitoring after scaling
- Cost considerations

**Estimated time**: 30-90 minutes

---

### 5. [Troubleshoot Common Issues](troubleshoot-common-issues.md)
**When to use**: Diagnosing and resolving operational issues

**Issues covered**:
- Authentication & authorization errors (401, 403)
- Rate limiting & quota issues (429)
- Performance & latency problems
- Backend service errors (500, 503)
- Policy execution errors
- Deployment issues
- Monitoring & logging issues

**Estimated time**: Variable (15 minutes - 2 hours)

---

## Runbook Structure

Each runbook follows a standard structure:

1. **Overview**: Purpose and context
2. **Prerequisites**: What you need before starting
3. **Step-by-Step Instructions**: Detailed procedures
4. **Verification**: How to confirm success
5. **Troubleshooting**: Common issues and resolutions
6. **References**: Links to related documentation

## Using These Runbooks

### Before You Start

- [ ] Ensure you have appropriate access and permissions
- [ ] Review the prerequisites section
- [ ] Gather required information (API keys, resource names, etc.)
- [ ] Consider impact and plan accordingly (maintenance windows if needed)

### During Execution

- Follow steps sequentially
- Document any deviations or issues
- Keep stakeholders informed of progress
- Use provided verification steps

### After Completion

- Document what was done
- Update tracking systems
- Communicate completion to stakeholders
- Update runbook if improvements identified

## Contributing to Runbooks

If you identify improvements or additional procedures:

1. Document your changes
2. Test the procedure
3. Submit a pull request
4. Include rationale for changes

## Support

- **Platform Team**: platform-team@example.com
- **Emergency**: See [Operations Guide](../docs/operations.md#support--escalation)
- **Documentation**: [docs/](../docs/)

## Quick Reference Commands

### Check APIM Status
```bash
az apim show --name apim-aigateway-prod-eastus-01 \
  --resource-group rg-aigateway-prod-eastus-01 \
  --query "{Name:name, State:provisioningState, Tier:sku.name}"
```

### Test Health Endpoint
```bash
curl -X GET "https://apim-aigateway-prod-eastus-01.azure-api.net/ai/health" \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY"
```

### View Recent Errors (Application Insights)
```kql
exceptions
| where timestamp > ago(1h)
| summarize Count = count() by type, outerMessage
| order by Count desc
```

### Check APIM Capacity
```bash
az monitor metrics list \
  --resource "/subscriptions/<sub-id>/resourceGroups/rg-aigateway-prod-eastus-01/providers/Microsoft.ApiManagement/service/apim-aigateway-prod-eastus-01" \
  --metric "Capacity" \
  --aggregation Average
```

---

**Last Updated**: 2026-03-17
**Maintained By**: Platform Team
