# Runbook: How to Scale Azure API Management

## Overview

This runbook provides step-by-step instructions for scaling the Azure API Management instance in the AI Gateway platform.

**Estimated Time**: 30-90 minutes (depending on tier change)
**Frequency**: As needed based on load
**Owner**: Platform Team

---

## Table of Contents

1. [Understanding APIM Tiers](#understanding-apim-tiers)
2. [When to Scale](#when-to-scale)
3. [Vertical Scaling (Tier Upgrade)](#vertical-scaling-tier-upgrade)
4. [Horizontal Scaling (Adding Units)](#horizontal-scaling-adding-units)
5. [Downscaling Considerations](#downscaling-considerations)
6. [Monitoring After Scaling](#monitoring-after-scaling)

---

## Prerequisites

- [ ] Access to Azure Portal or Azure CLI
- [ ] Contributor/Owner role on APIM resource
- [ ] Performance metrics collected (at least 7 days)
- [ ] Capacity planning completed
- [ ] Budget approval (for tier upgrades)
- [ ] Maintenance window scheduled (for tier changes)

---

## Understanding APIM Tiers

### Tier Comparison

| Feature | Developer | Basic | Standard | Premium |
|---------|-----------|-------|----------|---------|
| **Price** | ~$50/mo | ~$150/mo | ~$700/mo | ~$2,800/mo |
| **Max Throughput** | 1,000 req/sec | 1,000 req/sec | 2,500 req/sec | Unlimited |
| **SLA** | None | 99.95% | 99.95% | 99.99% |
| **Units** | 1 (fixed) | 1-2 | 1-4 | 1+ (unlimited) |
| **Multi-region** | ❌ | ❌ | ❌ | ✅ |
| **VNet Integration** | ❌ | ❌ | ✅ | ✅ |
| **Caching** | ✅ | ❌ | ✅ | ✅ |
| **Developer Portal** | ✅ | ✅ | ✅ | ✅ |
| **All Policies** | ✅ | ✅ | ✅ | ✅ |
| **Backup/Restore** | ❌ | ❌ | ✅ | ✅ |

### Current Setup

**Default Tier**: Developer
- Suitable for dev/test environments
- Up to 1,000 requests/second
- No SLA guarantee
- Cost-effective for initial deployment

---

## When to Scale

### Metrics to Monitor

**Capacity Metric** (Most Important):

```bash
# Check current capacity
az monitor metrics list \
  --resource "/subscriptions/<sub-id>/resourceGroups/rg-aigateway-prod-eastus-01/providers/Microsoft.ApiManagement/service/apim-aigateway-prod-eastus-01" \
  --metric "Capacity" \
  --start-time "$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --aggregation Average
```

**Application Insights Query**:
```kql
requests
| where timestamp > ago(7d)
| summarize
    RequestsPerSecond = count() / 60.0,
    P95Duration = percentile(duration, 95)
    by bin(timestamp, 1m)
| summarize
    AvgRPS = avg(RequestsPerSecond),
    MaxRPS = max(RequestsPerSecond),
    AvgP95 = avg(P95Duration)
```

### Scale-Up Triggers

**Immediate Action Required**:
- Capacity consistently > 80%
- Request throughput approaching tier limit
- Frequent 503 Service Unavailable errors
- P95 latency > 5 seconds consistently

**Plan Scale-Up**:
- Capacity trending > 60% for 7+ days
- Traffic growth rate > 20% month-over-month
- Approaching SLA requirements
- Business requires production SLA

**Consideration**:
- Developer → Basic/Standard: For production workloads
- Basic → Standard: For higher throughput
- Standard → Premium: For multi-region or advanced features

---

## Vertical Scaling (Tier Upgrade)

### Developer → Standard (Most Common)

**Use Case**: Moving from development to production

**Downtime**: 15-45 minutes (plan maintenance window)

#### Step 1: Backup Current Configuration

```bash
# Backup APIM configuration
APIM_NAME="apim-aigateway-prod-eastus-01"
RG_NAME="rg-aigateway-prod-eastus-01"
STORAGE_ACCOUNT="staigatewaybackupprod"

az apim backup create \
  --name $APIM_NAME \
  --resource-group $RG_NAME \
  --storage-account-name $STORAGE_ACCOUNT \
  --storage-account-container "apim-backups" \
  --backup-name "backup-$(date +%Y%m%d-%H%M%S)"
```

**Backup Terraform State**:
```bash
cd terraform
terraform state pull > backups/tfstate-pre-scale-$(date +%Y%m%d).json
```

#### Step 2: Update Terraform Configuration

**File**: `terraform/modules/api-management/main.tf`

```hcl
resource "azurerm_api_management" "apim" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email

  # Change SKU from Developer to Standard
  sku_name = "Standard_1"  # Was: Developer_1

  # ... rest of configuration
}
```

**Or use variable**:

**File**: `terraform/environments/prod/terraform.tfvars`

```hcl
# Before
apim_sku_name = "Developer_1"

# After
apim_sku_name = "Standard_1"
```

#### Step 3: Plan the Change

```bash
cd terraform

# Plan
terraform plan -out=tfplan

# Review carefully
# Look for:
# - azurerm_api_management.apim will be updated in-place
# - Changes to sku_name
```

#### Step 4: Schedule Maintenance Window

**Notification Template**:
```
Subject: [SCHEDULED MAINTENANCE] AI Gateway Upgrade - <Date> <Time>

Dear AI Gateway Users,

We will be upgrading the AI Gateway to improve performance and reliability.

Maintenance Window:
- Start: <Date> <Time> UTC
- Duration: 45 minutes
- Expected End: <Date> <Time> UTC

Impact:
- Service will be unavailable during upgrade
- All API requests will fail with 503 errors
- No data loss expected

Actions:
- Plan for service interruption during maintenance window
- Implement retry logic in your applications
- Monitor status page: <link>

Updates will be provided via:
- Email notifications
- Status page: <link>

Contact: platform-team@example.com
```

#### Step 5: Execute Upgrade

```bash
# Apply the change
terraform apply tfplan

# This will trigger the tier upgrade
# Monitor progress in Azure Portal or CLI
```

**Monitor Progress**:
```bash
# Watch provisioning state
watch -n 30 'az apim show \
  --name $APIM_NAME \
  --resource-group $RG_NAME \
  --query "{Name:name, State:provisioningState, Tier:sku.name}" \
  --output table'
```

**Expected Output**:
```
Updating... (0-45 minutes)
Name                           State       Tier
-----------------------------  ----------  ----------
apim-aigateway-prod-eastus-01  Updating    Standard_1

...

apim-aigateway-prod-eastus-01  Succeeded   Standard_1
```

#### Step 6: Verify Upgrade

```bash
# Verify tier change
az apim show \
  --name $APIM_NAME \
  --resource-group $RG_NAME \
  --query "{Tier:sku.name, Capacity:sku.capacity, State:provisioningState}"

# Test health endpoint
curl -X GET "https://${APIM_NAME}.azure-api.net/ai/health" \
  -H "Ocp-Apim-Subscription-Key: ${TEST_KEY}"

# Run smoke tests
cd ../../
./scripts/smoke-test.sh
```

#### Step 7: Monitor Post-Upgrade

Monitor for 1-2 hours after upgrade:

```kql
// Check error rate
requests
| where timestamp > ago(2h)
| summarize
    TotalRequests = count(),
    FailedRequests = countif(success == false),
    ErrorRate = countif(success == false) * 100.0 / count()
    by bin(timestamp, 5m)
| render timechart
```

#### Step 8: Notify Completion

```
Subject: [COMPLETED] AI Gateway Upgrade

The AI Gateway upgrade has been completed successfully.

Status: ✅ Complete
Completed At: <Time>
New Tier: Standard
Downtime: <Actual duration>

The service is now fully operational with improved performance.

Improvements:
- 2.5x higher throughput (up to 2,500 req/sec)
- 99.95% SLA guarantee
- Improved reliability

Thank you for your patience.
```

---

## Horizontal Scaling (Adding Units)

**Note**: Developer tier does not support multiple units. This requires Standard or Premium tier.

### When to Add Units

- Capacity > 70% on Standard tier
- Need higher throughput without tier change
- Cost-effective scaling within same tier

### Scaling Formula

**Standard Tier**:
- 1 unit = ~2,500 req/sec
- Max 4 units = ~10,000 req/sec

**Premium Tier**:
- 1 unit = ~10,000 req/sec
- Unlimited units

### Add Units to Standard Tier

#### Step 1: Check Current Capacity

```bash
az apim show \
  --name $APIM_NAME \
  --resource-group $RG_NAME \
  --query "sku.{Name:name, Capacity:capacity}"
```

#### Step 2: Update Terraform

**File**: `terraform/modules/api-management/main.tf`

```hcl
resource "azurerm_api_management" "apim" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email

  # Add units (Standard supports 1-4 units)
  sku_name = "Standard_2"  # Was: Standard_1

  # ... rest of configuration
}
```

#### Step 3: Apply Change

```bash
cd terraform
terraform plan -out=tfplan
terraform apply tfplan
```

**Downtime**: None (units can be added without downtime)

#### Step 4: Verify Scaling

```bash
# Check new capacity
az apim show \
  --name $APIM_NAME \
  --resource-group $RG_NAME \
  --query "sku.{Name:name, Capacity:capacity}"

# Expected: Standard_2

# Monitor capacity metric
az monitor metrics list \
  --resource "/subscriptions/<sub-id>/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME" \
  --metric "Capacity" \
  --aggregation Average
```

---

## Premium Tier Features

### Multi-Region Deployment

**Use Case**: Global availability, lower latency for distributed users

```hcl
resource "azurerm_api_management" "apim" {
  name                = var.name
  location            = "eastus"  # Primary region
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = "Premium_1"

  # Add additional regions
  additional_location {
    location = "westeurope"
    capacity = 1
  }

  additional_location {
    location = "southeastasia"
    capacity = 1
  }
}
```

**Benefits**:
- Lower latency for global users
- Geographic redundancy
- 99.99% SLA

**Cost**: ~$2,800/month per region

### VNet Integration (Standard/Premium)

**Use Case**: Private connectivity, enhanced security

```hcl
resource "azurerm_api_management" "apim" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = "Premium_1"

  # Enable VNet integration
  virtual_network_type = "Internal"

  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim.id
  }
}
```

---

## Downscaling Considerations

### When to Downscale

- Consistent capacity < 30% for 30+ days
- Traffic decreased significantly
- Moving from production to dev/test
- Cost optimization required

### Risks of Downscaling

**Tier Downgrade**:
- ⚠️ May cause downtime (15-45 minutes)
- ⚠️ Features may be lost (e.g., VNet, multi-region)
- ⚠️ Performance degradation if traffic spikes

**Unit Reduction**:
- ✅ No downtime
- ⚠️ Reduced capacity (may cause throttling)

### Safe Downscaling Process

```bash
# 1. Analyze current usage
az monitor metrics list \
  --resource "/subscriptions/<sub-id>/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME" \
  --metric "Requests" \
  --start-time "$(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --aggregation Total

# 2. Calculate peak throughput
# Ensure new tier can handle peak load

# 3. Update Terraform (e.g., Standard_2 → Standard_1)
# 4. Plan and apply
terraform plan -out=tfplan
terraform apply tfplan

# 5. Monitor closely for 48 hours
```

---

## Auto-Scaling (Premium Only)

**Note**: Auto-scaling is available only in Premium tier.

### Configure Auto-Scaling

```bash
# Create auto-scale rule
az monitor autoscale create \
  --resource-group $RG_NAME \
  --resource "/subscriptions/<sub-id>/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME" \
  --min-count 2 \
  --max-count 10 \
  --count 2

# Scale out rule (capacity > 70%)
az monitor autoscale rule create \
  --resource-group $RG_NAME \
  --autoscale-name "apim-autoscale" \
  --scale out 1 \
  --condition "Capacity > 70 avg 5m"

# Scale in rule (capacity < 30%)
az monitor autoscale rule create \
  --resource-group $RG_NAME \
  --autoscale-name "apim-autoscale" \
  --scale in 1 \
  --condition "Capacity < 30 avg 15m"
```

---

## Monitoring After Scaling

### Key Metrics to Track

**Capacity**:
```kql
AzureMetrics
| where ResourceProvider == "MICROSOFT.APIMANAGEMENT"
| where MetricName == "Capacity"
| where TimeGenerated > ago(24h)
| summarize AvgCapacity = avg(Average) by bin(TimeGenerated, 5m)
| render timechart
```

**Throughput**:
```kql
requests
| where timestamp > ago(24h)
| summarize RequestsPerSecond = count() / 60.0 by bin(timestamp, 1m)
| summarize
    AvgRPS = avg(RequestsPerSecond),
    MaxRPS = max(RequestsPerSecond),
    P95RPS = percentile(RequestsPerSecond, 95)
```

**Latency**:
```kql
requests
| where timestamp > ago(24h)
| summarize
    P50 = percentile(duration, 50),
    P95 = percentile(duration, 95),
    P99 = percentile(duration, 99)
    by bin(timestamp, 5m)
| render timechart
```

### Success Criteria

After scaling, verify:
- [ ] Capacity < 60% under normal load
- [ ] P95 latency < 2 seconds
- [ ] No 503 errors
- [ ] Successful health checks
- [ ] All consumers able to access API
- [ ] No increase in error rate

---

## Cost Considerations

### Monthly Cost by Configuration

| Configuration | Monthly Cost | Use Case |
|--------------|-------------|----------|
| Developer_1 | $50 | Dev/Test only |
| Standard_1 | $700 | Production (low traffic) |
| Standard_2 | $1,400 | Production (medium traffic) |
| Standard_4 | $2,800 | Production (high traffic) |
| Premium_1 | $2,800 | Enterprise (single region) |
| Premium_1 (3 regions) | $8,400 | Global deployment |

### Cost Optimization Tips

1. **Right-Size**: Don't over-provision
2. **Monitor Usage**: Track capacity trends
3. **Scheduled Scaling**: Scale down during off-hours (Premium only)
4. **Budget Alerts**: Set alerts at 80% of budget
5. **Reserved Capacity**: Consider reserved instances for stable workloads

---

## Troubleshooting

### Issue 1: Upgrade Stuck in "Updating" State

**Symptoms**: Tier upgrade exceeds 60 minutes

**Resolution**:
```bash
# Check operation status
az apim show \
  --name $APIM_NAME \
  --resource-group $RG_NAME \
  --query "{State:provisioningState, Tier:sku.name}"

# If stuck > 90 minutes, contact Azure Support
# Do not attempt to force cancel
```

### Issue 2: 503 Errors After Adding Units

**Symptoms**: Intermittent 503 errors after scaling

**Diagnosis**:
```kql
requests
| where timestamp > ago(1h)
| where resultCode == 503
| summarize Count = count() by bin(timestamp, 1m)
| render timechart
```

**Resolution**:
- Wait 10-15 minutes for units to fully initialize
- Verify units added successfully
- Check backend service health

### Issue 3: Capacity Still High After Scaling

**Symptoms**: Capacity remains > 70% after adding units

**Possible Causes**:
- Backend service bottleneck (not APIM)
- Policy processing overhead
- Inefficient policies

**Resolution**:
- Investigate backend service performance
- Review and optimize policies
- Consider caching strategies

---

## References

- [APIM Tiers and Pricing](https://azure.microsoft.com/pricing/details/api-management/)
- [APIM Capacity Metric](https://learn.microsoft.com/azure/api-management/api-management-capacity)
- [APIM Auto-Scaling](https://learn.microsoft.com/azure/api-management/api-management-howto-autoscale)
- [Operations Guide](../docs/operations.md)

---

**Runbook Version**: 1.0
**Last Updated**: 2026-03-17
**Owner**: Platform Team
