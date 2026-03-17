# Operations Guide

## Overview

This document provides operational procedures for deploying, monitoring, maintaining, and troubleshooting the Azure AI Integration Gateway platform.

## Table of Contents

1. [Deployment Procedures](#deployment-procedures)
2. [Monitoring & Alerting](#monitoring--alerting)
3. [Incident Response](#incident-response)
4. [Cost Management](#cost-management)
5. [Maintenance Procedures](#maintenance-procedures)
6. [Backup & Recovery](#backup--recovery)

---

## Deployment Procedures

### Pre-Deployment Checklist

Before deploying to any environment, ensure:

- [ ] Azure subscription is accessible
- [ ] Service Principal has required permissions (Contributor role)
- [ ] Terraform backend storage account exists
- [ ] Environment-specific variables are configured
- [ ] All secrets are stored in Key Vault (no hardcoded values)
- [ ] Code review completed and approved
- [ ] Tests passing in CI/CD pipeline

### Development Environment Deployment

**Prerequisites**:
- Azure CLI installed and authenticated
- Terraform >= 1.5.0 installed
- Git repository cloned locally

**Steps**:

```bash
# 1. Login to Azure
az login
az account set --subscription "<subscription-id>"

# 2. Navigate to Terraform directory
cd terraform

# 3. Initialize Terraform
terraform init

# 4. Review variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 5. Validate configuration
terraform validate
../scripts/validate.sh

# 6. Plan deployment
terraform plan -out=tfplan

# 7. Review plan output carefully
# Check for any unexpected changes or deletions

# 8. Apply deployment
terraform apply tfplan

# 9. Save outputs
terraform output > ../deployment-outputs.txt

# 10. Deploy APIM policies
../scripts/update-apim-policies.sh

# 11. Run smoke tests
../scripts/smoke-test.sh
```

**Estimated Time**: 20-30 minutes

### Staging Environment Deployment

**Prerequisites**:
- Development environment successfully deployed and tested
- Manual approval from team lead obtained
- Change ticket created and approved

**Steps**:

```bash
# 1. Switch to staging workspace (if using workspaces)
terraform workspace select staging

# 2. Use staging tfvars
terraform plan -var-file="environments/staging/terraform.tfvars" -out=tfplan

# 3. Review plan with team
# Share plan output for review

# 4. Apply with approval
terraform apply tfplan

# 5. Deploy policies
../scripts/update-apim-policies.sh

# 6. Run integration tests
cd ../tests/integration
pytest test_ai_gateway.py -v

# 7. Verify monitoring
pytest test_monitoring.py -v
```

**Estimated Time**: 30-45 minutes

### Production Environment Deployment

**Prerequisites**:
- Staging deployment successful and stable for 24+ hours
- Load testing completed successfully
- Change Advisory Board (CAB) approval obtained
- Rollback plan documented
- Communication sent to stakeholders

**Steps**:

```bash
# 1. Create deployment backup
terraform state pull > backup-$(date +%Y%m%d-%H%M%S).tfstate

# 2. Switch to production workspace
terraform workspace select prod

# 3. Plan production deployment
terraform plan -var-file="environments/prod/terraform.tfvars" -out=tfplan

# 4. Final review with operations team
# Review plan for any resource replacements or deletions

# 5. Schedule maintenance window (if needed)
# Communicate to all API consumers

# 6. Apply deployment
terraform apply tfplan

# 7. Verify resource locks applied
az lock list --resource-group rg-aigateway-prod-eastus-01

# 8. Deploy policies
../scripts/update-apim-policies.sh

# 9. Run production smoke tests
../scripts/smoke-test.sh

# 10. Monitor for 1 hour
# Watch Application Insights, Azure Monitor for errors

# 11. Send completion notification
```

**Estimated Time**: 1-2 hours (including monitoring)

### Rollback Procedure

If deployment fails or issues are detected:

```bash
# 1. Identify last known good state
terraform state list

# 2. Revert to previous Terraform code
git revert <commit-hash>

# 3. Re-apply previous configuration
terraform plan -out=tfplan
terraform apply tfplan

# 4. Restore APIM policies from git
git checkout <previous-commit> -- apim-policies/
../scripts/update-apim-policies.sh

# 5. Verify rollback successful
../scripts/smoke-test.sh

# 6. Document incident
# Create post-mortem document
```

### CI/CD Pipeline Deployment

**Pipeline Stages**:

1. **Validate** (automatic)
   - Terraform fmt check
   - Terraform validate
   - XML policy validation
   - Security scanning

2. **Plan** (automatic)
   - Generate Terraform plan
   - Save plan artifact
   - Comment plan on PR

3. **Deploy Dev** (automatic on main branch)
   - Apply Terraform
   - Deploy policies
   - Run smoke tests

4. **Deploy Staging** (manual approval required)
   - Apply Terraform
   - Deploy policies
   - Run integration tests

5. **Deploy Production** (manual approval + CAB)
   - Apply Terraform
   - Deploy policies
   - Run smoke tests
   - Monitor for 1 hour

**Pipeline Configuration**: See [pipelines/azure-devops-pipeline.yml](../pipelines/azure-devops-pipeline.yml)

---

## Monitoring & Alerting

### Key Metrics to Monitor

#### API Gateway Metrics

**Location**: Azure Portal → API Management → Metrics

| Metric | Threshold | Action |
|--------|-----------|--------|
| Total Requests | Baseline ±50% | Investigate unusual spikes/drops |
| Failed Requests (5xx) | >5% | Immediate investigation |
| Failed Requests (4xx) | >10% | Check for client issues |
| Request Duration (P95) | >5 seconds | Performance investigation |
| Capacity | >70% | Consider scaling up |

**Dashboard Query** (KQL):
```kql
requests
| where timestamp > ago(1h)
| summarize
    TotalRequests = count(),
    SuccessRate = countif(success == true) * 100.0 / count(),
    P95Duration = percentile(duration, 95)
    by bin(timestamp, 5m)
| render timechart
```

#### AI Service Metrics

**Location**: Application Insights → Custom Metrics

| Metric | Threshold | Action |
|--------|-----------|--------|
| Token Usage (hourly) | >50K tokens | Check for runaway requests |
| Average Tokens per Request | >5000 | Review request patterns |
| AI Model Latency | >3 seconds | Check Azure OpenAI status |
| AI Model Errors | >1% | Review error logs |

**Dashboard Query**:
```kql
customMetrics
| where name == "TokensUsed"
| summarize
    TotalTokens = sum(value),
    AvgTokens = avg(value),
    MaxTokens = max(value)
    by bin(timestamp, 1h)
| render timechart
```

#### Cost Metrics

**Location**: Application Insights → Custom Events

```kql
customEvents
| where name == "AIGatewayRequest"
| extend TokensUsed = toint(customDimensions.TokensUsed)
| extend EstimatedCost = TokensUsed * 0.00003 // Adjust based on model pricing
| summarize
    DailyCost = sum(EstimatedCost),
    RequestCount = count()
    by bin(timestamp, 1d), tostring(customDimensions.SubscriptionId)
| order by DailyCost desc
```

### Alert Configuration

#### Critical Alerts (Immediate Response Required)

**1. High Error Rate Alert**
- **Condition**: 5xx error rate > 5% over 5 minutes
- **Severity**: Critical
- **Action Group**: On-call engineer (SMS + Email)
- **Runbook**: [Troubleshooting 5xx Errors](../runbooks/troubleshoot-5xx-errors.md)

**2. APIM Availability Alert**
- **Condition**: APIM availability < 99% over 5 minutes
- **Severity**: Critical
- **Action Group**: Platform team + On-call
- **Runbook**: [APIM Availability Issues](../runbooks/troubleshoot-common-issues.md)

**3. Quota Exhaustion Alert**
- **Condition**: Azure OpenAI quota > 90% used
- **Severity**: High
- **Action Group**: Platform team
- **Runbook**: Request quota increase from Microsoft

#### Warning Alerts (Investigation Required)

**4. Elevated Error Rate Alert**
- **Condition**: 5xx error rate > 2% over 15 minutes
- **Severity**: Warning
- **Action Group**: Platform team (Email)

**5. High Latency Alert**
- **Condition**: P95 latency > 5 seconds over 10 minutes
- **Severity**: Warning
- **Action Group**: Platform team

**6. Budget Alert**
- **Condition**: Daily cost > $100
- **Severity**: Warning
- **Action Group**: Finance team + Platform team

### Monitoring Dashboards

#### Operations Dashboard

**Location**: Azure Portal → Dashboards → AI Gateway Operations

**Tiles**:
1. Request volume (last 24h)
2. Success rate trend
3. P95 latency trend
4. Top 10 API consumers
5. Error distribution by code
6. Token usage by operation
7. Estimated cost trend

#### Executive Dashboard

**Location**: Azure Portal → Dashboards → AI Gateway Executive

**Tiles**:
1. Total requests (MTD)
2. Success rate (SLA compliance)
3. Cost summary (MTD)
4. Active subscriptions
5. Top consumers
6. Growth trend

### Log Analysis

#### Find Failed Requests

```kql
requests
| where success == false
| where timestamp > ago(24h)
| project
    timestamp,
    name,
    resultCode,
    duration,
    customDimensions.RequestId,
    customDimensions.SubscriptionId
| order by timestamp desc
| take 100
```

#### Analyze Rate Limit Events

```kql
traces
| where message contains "RateLimitExceeded"
| extend SubscriptionId = tostring(customDimensions.SubscriptionId)
| summarize
    RateLimitHits = count()
    by SubscriptionId, bin(timestamp, 1h)
| order by RateLimitHits desc
```

#### Track Token Consumption

```kql
customEvents
| where name == "SummarizeRequest" or name == "ExtractRequest"
| extend TokensUsed = toint(customDimensions.TokensUsed)
| extend Operation = name
| summarize
    TotalTokens = sum(TokensUsed),
    RequestCount = count(),
    AvgTokensPerRequest = avg(TokensUsed)
    by Operation, bin(timestamp, 1h)
```

---

## Incident Response

### Incident Classification

| Severity | Description | Response Time | Examples |
|----------|-------------|---------------|----------|
| **P0 - Critical** | Complete service outage | 15 minutes | APIM down, total service unavailable |
| **P1 - High** | Significant degradation | 30 minutes | >10% error rate, quota exhausted |
| **P2 - Medium** | Partial degradation | 2 hours | Single operation failing, high latency |
| **P3 - Low** | Minor issues | 1 business day | Elevated 4xx errors, logging issues |

### Incident Response Workflow

#### 1. Detection
- Alert fires in Azure Monitor
- User reports issue
- Monitoring team identifies anomaly

#### 2. Triage (within response time SLA)
```bash
# Quick health check
curl -X GET "https://${APIM_URL}/ai/health" \
  -H "Ocp-Apim-Subscription-Key: ${SUBSCRIPTION_KEY}"

# Check APIM status
az apim show --name apim-aigateway-prod-eastus-01 \
  --resource-group rg-aigateway-prod-eastus-01 \
  --query provisioningState

# Check recent deployments
az deployment group list \
  --resource-group rg-aigateway-prod-eastus-01 \
  --query "[0].properties.timestamp"
```

#### 3. Investigation

**Check Application Insights**:
```kql
exceptions
| where timestamp > ago(1h)
| summarize Count = count() by type, outerMessage
| order by Count desc
```

**Check APIM Gateway Logs**:
```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| where ResponseCode >= 500
| project TimeGenerated, OperationId, ResponseCode, LastErrorMessage
| order by TimeGenerated desc
```

**Check Azure OpenAI Logs**:
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.COGNITIVESERVICES"
| where TimeGenerated > ago(1h)
| where httpStatusCode_d >= 500
| project TimeGenerated, OperationName, httpStatusCode_d, message_s
```

#### 4. Communication

**Initial Update** (within 30 minutes):
```
Subject: [INCIDENT] AI Gateway - <Brief Description>

Status: Investigating
Severity: <P0/P1/P2/P3>
Impact: <Describe user impact>
Started: <Timestamp>

We are investigating reports of <issue description>.
Updates will be provided every 30 minutes.

Next Update: <Time>
```

**Resolution Update**:
```
Subject: [RESOLVED] AI Gateway - <Brief Description>

Status: Resolved
Duration: <Start - End>
Root Cause: <Brief explanation>

The issue has been resolved. Service is operating normally.

Post-mortem will be published within 48 hours.
```

#### 5. Resolution

Common resolution actions:
- Restart APIM (if unresponsive)
- Rollback recent deployment
- Increase quotas
- Fix policy configuration
- Scale up resources

#### 6. Post-Incident Review

**Template**: Create post-mortem document with:
1. Timeline of events
2. Root cause analysis
3. Impact assessment (users affected, duration)
4. Resolution steps taken
5. Action items to prevent recurrence
6. Follow-up tasks

---

## Cost Management

### Cost Structure

**Monthly Cost Breakdown** (Development Environment):

| Service | Tier/SKU | Estimated Monthly Cost |
|---------|----------|------------------------|
| API Management | Developer | $50 |
| Azure OpenAI | Pay-per-token | Variable ($50-500) |
| Application Insights | Pay-per-GB | $10-50 |
| Key Vault | Standard | $1-5 |
| Log Analytics | Pay-per-GB | $5-20 |
| **Total Estimated** | | **$116-625** |

### Cost Optimization Strategies

#### 1. Token Usage Optimization

**Current Controls**:
- Rate limiting: 100 req/min per subscription
- Daily quotas: 10,000 req/day per subscription
- Max tokens per request: 5000 (configurable in policies)

**Monitoring**:
```kql
customEvents
| where name == "SummarizeRequest" or name == "ExtractRequest"
| extend TokensUsed = toint(customDimensions.TokensUsed)
| extend SubscriptionId = tostring(customDimensions.SubscriptionId)
| summarize
    TotalTokens = sum(TokensUsed),
    EstimatedCost = sum(TokensUsed) * 0.00003 // $0.03 per 1K tokens (adjust based on model)
    by SubscriptionId
| order by EstimatedCost desc
```

**Actions**:
- Identify top consumers
- Review and optimize prompts for token efficiency
- Implement caching for repeated requests
- Use GPT-3.5-Turbo for simpler tasks (lower cost)

#### 2. APIM Tier Optimization

**Developer Tier** ($50/month):
- Up to 1,000 req/sec
- No SLA
- All features enabled
- **Use for**: Dev/Test environments

**Standard Tier** ($700/month):
- Up to 2,500 req/sec
- 99.95% SLA
- **Use for**: Production with moderate traffic

**Premium Tier** ($2,800/month):
- Unlimited throughput
- 99.99% SLA
- Multi-region support
- **Use for**: High-volume production

#### 3. Application Insights Cost Control

**Current Ingestion** (monitor):
```kql
Usage
| where TimeGenerated > ago(30d)
| where IsBillable == true
| summarize DataGB = sum(Quantity) / 1000 by bin(TimeGenerated, 1d)
| render timechart
```

**Optimization**:
- Set daily cap (e.g., 5 GB/day)
- Sample telemetry (only in high-volume scenarios)
- Adjust retention period (default: 90 days)

```bash
# Set daily cap
az monitor app-insights component update \
  --app appi-aigateway-prod-eastus-01 \
  --resource-group rg-aigateway-prod-eastus-01 \
  --cap 5
```

### Budget Alerts

**Configure Azure Budgets**:

```bash
# Create budget alert
az consumption budget create \
  --budget-name ai-gateway-monthly-budget \
  --amount 1000 \
  --category Cost \
  --time-grain Monthly \
  --time-period start-date=2026-03-01 \
  --notifications \
    threshold=80 \
    contact-emails="finance@example.com,platform@example.com" \
    operator=GreaterThan
```

**Alert Thresholds**:
- 50% of budget: Warning (Email)
- 80% of budget: Alert (Email + Slack)
- 100% of budget: Critical (Email + SMS)
- 120% of budget: Emergency (Throttle low-priority requests)

### Cost Allocation

**Tag-Based Cost Tracking**:

All resources tagged with:
- `Environment`: dev/staging/prod
- `CostCenter`: engineering/research/etc
- `Project`: ai-gateway
- `Owner`: team-name

**Monthly Cost Report Query**:
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.APIMANAGEMENT" or
        ResourceProvider == "MICROSOFT.COGNITIVESERVICES"
| extend CostCenter = tostring(tags_s.CostCenter)
| extend Environment = tostring(tags_s.Environment)
| summarize RequestCount = count() by CostCenter, Environment
```

---

## Maintenance Procedures

### Regular Maintenance Tasks

#### Daily
- [ ] Review Azure Monitor alerts
- [ ] Check error rate dashboard
- [ ] Monitor cost trends
- [ ] Review high-volume consumers

#### Weekly
- [ ] Review Application Insights logs for anomalies
- [ ] Check APIM policy performance
- [ ] Analyze token usage trends
- [ ] Review and respond to support tickets

#### Monthly
- [ ] Security review (RBAC, Key Vault access logs)
- [ ] Update Terraform modules to latest versions
- [ ] Review and rotate subscription keys (if needed)
- [ ] Cost analysis and optimization review
- [ ] Review and update documentation
- [ ] Capacity planning review

#### Quarterly
- [ ] Disaster recovery test
- [ ] Load testing
- [ ] Security audit
- [ ] Review and update incident response procedures
- [ ] Update runbooks based on lessons learned

### Subscription Key Rotation

See detailed runbook: [How to Rotate Secrets](../runbooks/rotate-secrets.md)

**Summary**:
1. Generate new subscription key
2. Communicate to API consumer with 30-day notice
3. Update consumer applications with new key
4. Monitor usage to ensure migration
5. Revoke old key after confirmation

### APIM Policy Updates

```bash
# 1. Update policy XML files in git
cd apim-policies/operations/
# Edit policy files

# 2. Validate XML syntax
xmllint --noout summarize-policy.xml

# 3. Deploy to dev first
../scripts/update-apim-policies.sh dev

# 4. Test in dev environment
curl -X POST "https://apim-aigateway-dev-eastus-01.azure-api.net/ai/summarize" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: ${DEV_KEY}" \
  -d '{"text": "test", "style": "concise"}'

# 5. Deploy to staging, then production
../scripts/update-apim-policies.sh staging
../scripts/update-apim-policies.sh prod
```

### Terraform State Maintenance

**Backup State**:
```bash
# Manual backup
terraform state pull > backups/tfstate-$(date +%Y%m%d).json

# Automated backup (weekly cron job)
0 0 * * 0 cd /path/to/terraform && terraform state pull > backups/tfstate-$(date +%Y%m%d).json
```

**Verify State Integrity**:
```bash
# Refresh state
terraform refresh

# Check for drift
terraform plan -detailed-exitcode
# Exit code 2 = changes detected (drift)
```

---

## Backup & Recovery

### Backup Strategy

#### Infrastructure as Code (Primary Backup)
- All infrastructure defined in Terraform (git repository)
- Version controlled
- Immutable infrastructure approach

**Repository**: GitHub/Azure DevOps
**Branches**: Protected main branch with PR reviews
**Tags**: Tag releases for production deployments

#### Terraform State Backup

**Storage**: Azure Storage Account (geo-redundant)
- Automatic versioning enabled
- Soft-delete enabled (14 days)
- Access restricted to service principal

**Backup Schedule**:
- Automatic: On every terraform apply
- Manual: Weekly full backup
- Retention: 90 days

#### Key Vault Backup

**Soft Delete**: Enabled (90-day retention)
**Purge Protection**: Enabled (production only)

**Manual Backup**:
```bash
# Backup all secrets
az keyvault secret list --vault-name kv-aigateway-prod-eastus-01 \
  --query "[].name" -o tsv | \
  while read secret; do
    az keyvault secret backup \
      --vault-name kv-aigateway-prod-eastus-01 \
      --name "$secret" \
      --file "backups/${secret}.bak"
  done
```

#### APIM Configuration Backup

**Git Repository**: All policies stored in source control
**APIM Backup API** (optional):
```bash
az apim backup --name apim-aigateway-prod-eastus-01 \
  --resource-group rg-aigateway-prod-eastus-01 \
  --storage-account-name staigatewaybackupprod \
  --storage-account-container backups \
  --backup-name apim-backup-$(date +%Y%m%d)
```

### Recovery Procedures

#### Disaster Recovery Scenarios

**Scenario 1: Complete Resource Group Deletion**

**Recovery Steps**:
```bash
# 1. Restore from git repository
git clone <repository-url>
cd azure-ai-integration-gateway-platform/terraform

# 2. Initialize Terraform
terraform init

# 3. Apply infrastructure
terraform apply -var-file="environments/prod/terraform.tfvars"

# 4. Deploy APIM policies
../scripts/update-apim-policies.sh prod

# 5. Verify deployment
../scripts/smoke-test.sh
```

**Recovery Time**: ~30 minutes
**Recovery Point**: Last git commit (near-zero data loss)

**Scenario 2: Key Vault Accidental Deletion**

**Recovery Steps**:
```bash
# 1. List deleted Key Vaults
az keyvault list-deleted

# 2. Recover soft-deleted Key Vault
az keyvault recover \
  --name kv-aigateway-prod-eastus-01 \
  --resource-group rg-aigateway-prod-eastus-01

# 3. Verify recovery
az keyvault show --name kv-aigateway-prod-eastus-01
```

**Recovery Time**: ~5 minutes
**Recovery Point**: Instant (soft-delete recovery)

**Scenario 3: Corrupted Terraform State**

**Recovery Steps**:
```bash
# 1. Download backup from Azure Storage
az storage blob download \
  --account-name stterraformstateprod \
  --container-name tfstate \
  --name prod.terraform.tfstate \
  --file terraform.tfstate.backup \
  --version-id <previous-version>

# 2. Restore state
cp terraform.tfstate.backup terraform.tfstate

# 3. Push to remote backend
terraform state push terraform.tfstate

# 4. Verify
terraform plan
```

**Recovery Time**: ~10 minutes

#### Recovery Testing

**Schedule**: Quarterly disaster recovery test

**Test Checklist**:
- [ ] Deploy infrastructure to test subscription from scratch
- [ ] Verify all services operational
- [ ] Test API endpoints
- [ ] Verify monitoring and logging
- [ ] Document time to recover
- [ ] Update procedures based on learnings

---

## Support & Escalation

### Support Tiers

**Tier 1: API Consumers**
- Email: api-support@example.com
- Response: 1 business day
- Scope: API usage questions, subscription key issues

**Tier 2: Platform Team**
- Email: platform-team@example.com
- Response: 4 hours (business hours)
- Scope: Platform issues, monitoring, deployments

**Tier 3: On-Call Engineer**
- Phone: +1-XXX-XXX-XXXX
- Response: 15 minutes (24/7)
- Scope: P0/P1 incidents only

### Escalation Matrix

| Issue Type | Severity | Initial Contact | Escalate To | Escalate After |
|------------|----------|----------------|-------------|----------------|
| API Usage Question | P3 | API Support | - | - |
| Performance Degradation | P2 | Platform Team | On-Call | 2 hours |
| Service Outage | P0 | On-Call | Leadership | 30 minutes |
| Security Incident | P0 | Security Team | CISO | Immediate |

---

## References

- [Architecture Documentation](architecture.md)
- [API Design Documentation](api-design.md)
- [Security Guide](security.md)
- [Testing Guide](testing-guide.md)
- [Deployment Guide](deployment-guide.md)
- [All Runbooks](../runbooks/)

---

## Appendix

### Useful Commands Reference

**Check APIM Health**:
```bash
az apim show --name <apim-name> --resource-group <rg-name> \
  --query "{Name:name, State:provisioningState, Gateway:gatewayUrl}"
```

**List All Subscriptions**:
```bash
az apim subscription list --resource-group <rg-name> \
  --service-name <apim-name> \
  --query "[].{Name:displayName, State:state}"
```

**Get Subscription Usage**:
```kql
requests
| where customDimensions.SubscriptionId == "<subscription-id>"
| where timestamp > ago(24h)
| summarize RequestCount = count() by bin(timestamp, 1h)
```

**Check OpenAI Quota**:
```bash
az cognitiveservices account show \
  --name <openai-account> \
  --resource-group <rg-name> \
  --query "properties.quotaUsage"
```

---

**Document Version**: 1.0
**Last Updated**: 2026-03-17
**Owner**: Platform Operations Team
