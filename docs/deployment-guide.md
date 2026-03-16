# Azure AI Gateway - Deployment Guide

## Overview
This guide provides comprehensive instructions for deploying and managing the Azure AI Integration Gateway across multiple environments (dev, staging, production).

### Quick Start

**For Local Development**:
```bash
# 1. Create your local configuration from the example
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars

# 2. Customize your environment configuration (especially apim_publisher_email)
nano terraform/environments/dev/terraform.tfvars

# 3. Deploy
./scripts/deploy.sh dev

# 4. Test
./scripts/smoke-test.sh <apim-url> <subscription-key>
```

**For CI/CD Pipeline**:
1. Create Azure DevOps variable groups (`ai-gateway-dev`, `ai-gateway-staging`, `ai-gateway-prod`)
2. Configure pipeline to use `pipelines/azure-devops-pipeline.yml`
3. Push code and run pipeline

---

## Table of Contents
- [Terraform State Management](#terraform-state-management)
- [CI/CD Pipeline](#cicd-pipeline)
- [Environment Configuration](#environment-configuration)
- [Deployment Scripts](#deployment-scripts)
- [Testing](#testing)
- [Azure DevOps Setup](#azure-devops-setup)
- [Getting Started](#getting-started)

---

## Terraform State Management

### Backend Configuration
- **File**: [terraform/backend.tf](../terraform/backend.tf)
- **Features**:
  - Azure Storage Account backend for remote state
  - State locking with blob lease
  - Separate state files per environment
  - Dynamic backend configuration support

**Backend Structure**:
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform"
    storage_account_name = "sttfstateta"
    container_name       = "tfstate"
    key                  = "azure-ai-integration-dev.tfstate"  # Default to dev, override via -backend-config
  }
}
```

### State Files per Environment
- `azure-ai-integration-dev.tfstate` - Development environment state
- `azure-ai-integration-staging.tfstate` - Staging environment state
- `azure-ai-integration-prod.tfstate` - Production environment state

**Initialize with specific environment**:
```bash
# Dev environment
terraform init -backend-config="key=azure-ai-integration-dev.tfstate"

# Staging environment
terraform init -backend-config="key=azure-ai-integration-staging.tfstate"

# Production environment
terraform init -backend-config="key=azure-ai-integration-prod.tfstate"
```

---

## CI/CD Pipeline

### Pipeline Overview
- **File**: [pipelines/azure-devops-pipeline.yml](../pipelines/azure-devops-pipeline.yml)
- **Architecture**: 7-stage pipeline covering validation, planning, and deployment
- **Environments**: dev, staging, production

### Pipeline Stages

#### Stage 1: Validate
**Purpose**: Validate configuration and security before any deployments

**Jobs**:
1. **ValidateTerraform** - Terraform fmt, validate
2. **ValidatePolicies** - XML policy validation using xmllint
3. **SecurityScan** - Security scanning with Checkov

**Features**:
- Terraform format check
- Terraform configuration validation
- APIM policy XML validation
- Security vulnerability scanning

#### Stage 2: Plan (Dev)
**Purpose**: Create execution plan for development environment

**Features**:
- Terraform plan using variables from `ai-gateway-dev` variable group
- Cost estimation with Infracost
- Plan artifact publishing for deployment stage

#### Stage 3: Deploy (Dev)
**Purpose**: Deploy infrastructure to development environment

**Features**:
- Terraform apply with saved plan artifact
- Automated deployment (no manual approval)
- Comprehensive smoke tests
- Environment: Azure DevOps `dev` environment

#### Stage 4: Plan (Staging)
**Purpose**: Create execution plan for staging environment

**Features**:
- Terraform plan using variables from `ai-gateway-staging` variable group
- Cost estimation with Infracost
- Separate backend state file (staging.terraform.tfstate)

#### Stage 5: Deploy (Staging)
**Purpose**: Deploy infrastructure to staging environment

**Features**:
- Manual approval gate (via Azure DevOps environment)
- Terraform apply with saved plan artifact
- Smoke tests for basic functionality
- Python integration tests (extensible)
- Environment: Azure DevOps `staging` environment (requires approval)

#### Stage 6: Plan (Production)
**Purpose**: Create execution plan for production environment

**Features**:
- Terraform plan using variables from `ai-gateway-prod` variable group
- Cost estimation with Infracost
- Separate backend state file (prod.terraform.tfstate)

#### Stage 7: Deploy (Production)
**Purpose**: Deploy infrastructure to production environment

**Features**:
- Manual approval gate (via Azure DevOps environment)
- Terraform apply with saved plan artifact
- Critical health checks (deployment fails if checks fail)
- Production validation tests
- Environment: Azure DevOps `production` environment (requires approval)

---

## Environment Configuration

### Configuration Methods

There are **two ways** to configure the infrastructure depending on your deployment method:

#### 1. Local Deployments (Manual)
Uses **`.tfvars` files** stored in `terraform/environments/<env>/terraform.tfvars`

#### 2. CI/CD Pipeline (Automated)
Uses **Azure DevOps Variable Groups** that inject variables at runtime via `-var` command-line arguments

### Directory Structure
```
terraform/environments/
├── dev/
│   ├── terraform.tfvars.example  # Template file (committed to repo)
│   └── terraform.tfvars          # Your local config (NOT in repo, gitignored)
├── staging/
│   ├── terraform.tfvars.example  # Template file (committed to repo)
│   └── terraform.tfvars          # Your local config (NOT in repo, gitignored)
└── prod/
    ├── terraform.tfvars.example  # Template file (committed to repo)
    └── terraform.tfvars          # Your local config (NOT in repo, gitignored)
```

**Important Notes**:
- `.tfvars.example` files are templates committed to the repository
- `.tfvars` files are **NOT committed** (they're in `.gitignore`) because they contain sensitive data
- You must create your own `.tfvars` files locally by copying the `.example` files
- The CI/CD pipeline uses Azure DevOps variable groups instead of `.tfvars` files

### Environment-Specific Settings

#### Development Environment
**Template File**: [terraform/environments/dev/terraform.tfvars.example](../terraform/environments/dev/terraform.tfvars.example)

**Configuration**:
- APIM SKU: `Developer_1` (cost-effective for development)
- AI Models: GPT-4o only
- Environment tag: `dev`

**Use Case**: Development and testing, cost optimization

#### Staging Environment
**Template File**: [terraform/environments/staging/terraform.tfvars.example](../terraform/environments/staging/terraform.tfvars.example)

**Configuration**:
- APIM SKU: `Standard_1` (production-like tier)
- AI Models: GPT-4o + GPT-35-Turbo (full testing)
- Environment tag: `staging`

**Use Case**: Pre-production testing, integration testing

#### Production Environment
**Template File**: [terraform/environments/prod/terraform.tfvars.example](../terraform/environments/prod/terraform.tfvars.example)

**Configuration**:
- APIM SKU: `Standard_1` (production tier, upgradeable to Premium)
- AI Models: GPT-4o + GPT-35-Turbo
- Environment tag: `prod`

**Use Case**: Live production workloads

---

## Deployment Methods

### Method 1: Local Deployment (Manual)

**Best for**: Testing, development, quick iterations

Local deployments use the `deploy.sh` script which automatically loads environment-specific `.tfvars` files.

#### Prerequisites
- Azure CLI installed and logged in (`az login`)
- Terraform >= 1.5.0 installed
- Environment-specific `.tfvars` file exists

#### Deploy Script
**File**: [scripts/deploy.sh](../scripts/deploy.sh)

**Features**:
- Environment validation (dev/staging/prod)
- Azure CLI and Terraform prerequisite checks
- Environment-specific tfvars loading from `terraform/environments/<env>/terraform.tfvars`
- Dynamic backend configuration per environment
- Terraform format check
- Plan creation and review
- Optional auto-approve flag
- Output display after deployment

**Usage**:
```bash
# Deploy to dev
./scripts/deploy.sh dev

# Deploy to staging
./scripts/deploy.sh staging

# Deploy to production
./scripts/deploy.sh prod

# Auto-approve (use with caution)
./scripts/deploy.sh dev --auto-approve
```

**How it works**:
1. Script validates environment (dev/staging/prod)
2. Checks for Azure CLI and Terraform
3. Loads variables from `terraform/environments/<env>/terraform.tfvars`
4. Initializes Terraform with environment-specific backend state
5. Creates and shows execution plan
6. Prompts for confirmation (unless --auto-approve)
7. Applies changes to Azure

### Method 2: CI/CD Pipeline (Automated)

**Best for**: Production deployments, team collaboration, automated workflows

Pipeline deployments use Azure DevOps variable groups to inject configuration at runtime.

**Features**:
- Automated multi-environment deployments
- Manual approval gates for staging and production
- Cost estimation with Infracost
- Comprehensive testing at each stage
- Artifact-based plan/apply workflow

**See [CI/CD Pipeline](#cicd-pipeline) section for full details**

### Comparison: Local vs Pipeline Deployment

| Aspect | Local Deployment | CI/CD Pipeline |
|--------|------------------|----------------|
| **Configuration** | `.tfvars` files | Azure DevOps Variable Groups |
| **Location** | `terraform/environments/<env>/terraform.tfvars` (local only) | Variable Groups: `ai-gateway-<env>` |
| **Variables** | Local file (NOT in repo, gitignored) | Stored in Azure DevOps |
| **Best For** | Development, testing, quick changes | Production, team deployments |
| **Approval** | Manual confirmation prompt | Azure DevOps approval gates |
| **Testing** | Manual | Automated (validation, smoke tests) |
| **Cost Estimation** | Manual (run infracost separately) | Automatic (Infracost integrated) |
| **State Management** | Local backend config | Automatic per environment |
| **Secrets** | In local `.tfvars` (gitignored) | Secure Azure DevOps variables |

**Important**: Both methods use the same backend configuration and state files, so you can deploy locally and then switch to the pipeline (or vice versa) without issues.

---

## Deployment Scripts

### Validation Script
**File**: [scripts/validate.sh](../scripts/validate.sh)

**Features**:
- Terraform installation check
- Azure CLI installation check
- Terraform configuration validation
- Terraform formatting check
- APIM policy XML validation
- Required files check
- Required modules check

**Usage**:
```bash
./scripts/validate.sh
```

---

## Testing

### Smoke Test Suite
**File**: [scripts/smoke-test.sh](../scripts/smoke-test.sh)

**Features**:
- Automated testing of deployed AI Gateway
- 5 comprehensive test cases
- Exit codes for CI/CD integration
- Detailed test reporting

**Usage**:
```bash
./scripts/smoke-test.sh <apim-gateway-url> <subscription-key>

# Example
./scripts/smoke-test.sh https://apim-aigateway-dev.azure-api.net "your-subscription-key"
```

**Test Coverage**:
1. Health Check Endpoint (GET /ai/health)
2. Summarize Endpoint (POST /ai/summarize)
3. Extract Endpoint (POST /ai/extract)
4. Authentication - Invalid Subscription Key
5. Authentication - Missing Subscription Key

### Pipeline Integration
- **Dev**: Smoke tests after deployment (non-blocking)
- **Staging**: Smoke tests + integration tests (non-blocking)
- **Production**: Health checks (blocking - fails deployment if tests fail)

---

## Azure DevOps Setup

### Variable Groups

The pipeline uses Azure DevOps variable groups to manage environment-specific configuration. Each environment has its own variable group with consistent variable names but different values.

#### Common Variables (`ai-gateway-common`)
```yaml
terraformVersion: 1.5.0
INFRACOST_API_KEY: <your-infracost-api-key>
```

**Note**: Backend configuration (storage account, resource group, container) is hardcoded in the pipeline YAML file. If you need to use a different backend, update the values in [pipelines/azure-devops-pipeline.yml](../pipelines/azure-devops-pipeline.yml):
- `backendAzureRmResourceGroupName`: Default is `rg-terraform`
- `backendAzureRmStorageAccountName`: Default is `sttfstateta`
- `backendAzureRmContainerName`: Default is `tfstate`

#### Dev Variables (`ai-gateway-dev`)
```yaml
PROJECT_NAME: aigateway
ENVIRONMENT: dev
LOCATION: eastus
APIM_PUBLISHER_NAME: <your-publisher-name>
APIM_PUBLISHER_EMAIL: <your-publisher-email>
APIM_SKU_NAME: Developer_1
ENABLE_GPT4O: true
ENABLE_GPT35_TURBO: false
```

**Note**: `APIM_GATEWAY_URL` is automatically extracted from Terraform outputs after deployment. It does not need to be pre-configured.

#### Staging Variables (`ai-gateway-staging`)
```yaml
PROJECT_NAME: aigateway
ENVIRONMENT: staging
LOCATION: eastus
APIM_PUBLISHER_NAME: <your-publisher-name>
APIM_PUBLISHER_EMAIL: <your-publisher-email>
APIM_SKU_NAME: Standard_1
ENABLE_GPT4O: true
ENABLE_GPT35_TURBO: true
```

**Note**: `APIM_GATEWAY_URL` is automatically extracted from Terraform outputs after deployment. It does not need to be pre-configured.

#### Production Variables (`ai-gateway-prod`)
```yaml
PROJECT_NAME: aigateway
ENVIRONMENT: prod
LOCATION: eastus
APIM_PUBLISHER_NAME: <your-publisher-name>
APIM_PUBLISHER_EMAIL: <your-publisher-email>
APIM_SKU_NAME: Standard_1
ENABLE_GPT4O: true
ENABLE_GPT35_TURBO: true
```

**Note**: `APIM_GATEWAY_URL` is automatically extracted from Terraform outputs after deployment. It does not need to be pre-configured.

**Important Notes**:
- All variable groups use the **same variable names** with different values per environment
- Variables are passed to Terraform via `-var` command-line arguments in the pipeline
- Do not create environment-specific variable names (e.g., `APIM_GATEWAY_URL_STAGING`) - use consistent names
- The pipeline automatically selects the correct variable group based on the stage being executed

### Environments

Create the following environments in Azure DevOps:

1. **dev** - No approvals required
2. **staging** - Manual approval before deployment
3. **production** - Manual approval before deployment

**Setup Instructions**:
1. Navigate to Pipelines → Environments
2. Create new environment for each (dev, staging, production)
3. For staging and production:
   - Click on environment
   - Select "Approvals and checks"
   - Add "Approvals" check
   - Configure required approvers
   - Set timeout policies

### Service Connection

**Name**: `Azure-ServiceConnection`
- **Type**: Azure Resource Manager
- **Authentication**: Service Principal or Managed Identity
- **Scope**: Subscription level
- **Permissions**: Contributor or Owner role

**Setup Instructions**:
1. Navigate to Project Settings → Service connections
2. Create new service connection (Azure Resource Manager)
3. Choose authentication method (Service Principal recommended)
4. Set subscription and resource group scope
5. Name it `Azure-ServiceConnection`

---

## Getting Started

### Prerequisites
- Azure subscription with Contributor or Owner permissions
- Azure CLI installed
- Terraform >= 1.5.0 installed
- Azure DevOps project (for CI/CD)
- Infracost account (optional, for cost estimation)

### Step 1: Initialize Remote State Storage

Create the Azure Storage Account for Terraform state:

```bash
# Login to Azure
az login

# Create resource group for Terraform state
az group create --name rg-terraform --location eastus

# Create storage account (must match the name in pipeline: sttfstateta)
az storage account create \
  --name sttfstateta \
  --resource-group rg-terraform \
  --location eastus \
  --sku Standard_LRS \
  --encryption-services blob

# Create container
az storage container create \
  --name tfstate \
  --account-name sttfstateta
```

**Important**: The storage account name `sttfstateta`, resource group `rg-terraform`, and container name `tfstate` are referenced in the pipeline configuration. If you use different names, you must update all occurrences in [pipelines/azure-devops-pipeline.yml](../pipelines/azure-devops-pipeline.yml).

### Step 2: Configure Azure DevOps

1. **Create Variable Groups**:
   - `ai-gateway-common` - Common variables
   - `ai-gateway-dev` - Dev environment variables
   - `ai-gateway-staging` - Staging environment variables
   - `ai-gateway-prod` - Production environment variables

2. **Configure Infracost** (optional):
   - Sign up at https://www.infracost.io/
   - Get API key from dashboard
   - Add `INFRACOST_API_KEY` to `ai-gateway-common` variable group

3. **Create Environments**:
   - Create `dev`, `staging`, `production` environments
   - Add approval gates for staging and production

4. **Create Service Connection**:
   - Set up `Azure-ServiceConnection` with appropriate permissions

### Step 3: Validate Configuration

Run the validation script to ensure everything is configured correctly:

```bash
./scripts/validate.sh
```

Expected output:
```
✓ Terraform installation check
✓ Azure CLI installation check
✓ Terraform configuration valid
✓ All APIM policy XML files valid
✓ All required files present
✓ All required modules present
```

### Step 4: Configure Environment Variables

Create your local configuration file from the template:

```bash
# Copy the example file to create your local configuration
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars

# Customize your configuration (especially apim_publisher_email)
nano terraform/environments/dev/terraform.tfvars
```

**Important fields to customize**:
- `apim_publisher_email`: Use your actual email address
- `location`: Change if you prefer a different Azure region
- `apim_sku_name`: Adjust based on your needs and budget

### Step 5: Deploy to Development

Deploy to the dev environment for initial testing:

```bash
# Deploy using the local deployment method
./scripts/deploy.sh dev
```

The script will:
1. Load variables from `terraform/environments/dev/terraform.tfvars`
2. Create a Terraform plan
3. Show you what will be created
4. Ask for confirmation before applying

### Step 6: Test Deployment

After deployment, run smoke tests:

```bash
# Get APIM gateway URL and subscription key from Azure portal or Terraform outputs
./scripts/smoke-test.sh <apim-gateway-url> <subscription-key>
```

### Step 7: Set Up CI/CD Pipeline (Optional)

Once local deployment is working, you can set up automated deployments:

1. **Create Variable Groups** in Azure DevOps (see [Variable Groups](#variable-groups) section)
2. **Create Environments** (`dev`, `staging`, `production`) with approval gates
3. **Set up Service Connection** for Azure authentication
4. **Configure Pipeline** to use `pipelines/azure-devops-pipeline.yml`
5. **Push code** to your repository
6. **Run the pipeline** and verify all stages execute successfully

**Note**: The pipeline uses variable groups instead of `.tfvars` files, so make sure to configure all variables in Azure DevOps as documented in the [Variable Groups](#variable-groups) section.

---

## Features

### Infracost Integration
**Cost estimation** integrated into all Plan stages.

**Configuration**:
- Set `INFRACOST_API_KEY` in `ai-gateway-common` variable group
- Sign up at https://www.infracost.io/

**Benefits**:
- Automatic cost breakdown during plan stage
- JSON cost reports saved as artifacts
- Table format output in pipeline logs
- Helps prevent unexpected cloud costs

### Multi-Environment Support
**Separate configurations** for each environment with appropriate tier selections:
- Dev: Developer tier APIM (cost-effective)
- Staging: Standard tier APIM (production-like)
- Production: Standard tier APIM (upgradeable to Premium)

### State Management
**Separate state files** per environment with automatic selection:
- Prevents accidental modifications across environments
- State locking prevents concurrent modifications
- Centralized state storage in Azure Storage

---

## Troubleshooting

### Common Issues

#### Issue: Terraform state lock
```
Error: Error acquiring the state lock
```

**Solution**:
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

#### Issue: Backend not initialized
```
Error: Backend initialization required
```

**Solution**:
```bash
# Reinitialize backend
terraform init -reconfigure -backend-config="key=<environment>.terraform.tfstate"
```

#### Issue: Invalid subscription key in smoke tests
```
Error: Health check failed (HTTP 401)
```

**Solution**:
- Verify subscription key in Azure DevOps variable groups
- Check APIM subscription in Azure portal
- Ensure subscription is active and not expired

#### Issue: Infracost failing
```
Error: INFRACOST_API_KEY not set
```

**Solution**:
- Add `INFRACOST_API_KEY` to variable group
- Or disable Infracost by removing from pipeline (optional feature)

---

## Best Practices

### Deployment Strategy
1. Always deploy to **dev** first
2. Run smoke tests and validate functionality
3. Deploy to **staging** for integration testing
4. Obtain approvals from stakeholders
5. Deploy to **production** during maintenance window
6. Monitor health checks and alerts

### State Management
- Never manually edit state files
- Use `terraform import` for existing resources
- Regular state backups (Azure Storage handles this)
- Use state locking to prevent concurrent modifications

### Security
- Store sensitive values in Azure Key Vault
- Use Azure DevOps variable groups for secrets
- Mark sensitive variables as secret
- Rotate API keys and subscription keys regularly
- Use managed identities where possible

### Cost Optimization
- Review Infracost reports before applying changes
- Use Developer tier for dev environment
- Consider auto-shutdown for non-production resources
- Set up budget alerts in Azure

---

## Additional Resources

### Documentation
- [Architecture Documentation](architecture.md)
- [API Design Documentation](api-design.md)
- [Main README](../README.md)

### External Links
- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure API Management Documentation](https://learn.microsoft.com/en-us/azure/api-management/)
- [Azure DevOps Pipeline Documentation](https://learn.microsoft.com/en-us/azure/devops/pipelines/)
- [Infracost Documentation](https://www.infracost.io/docs/)

---

## Support

For issues or questions:
1. Check the [troubleshooting section](#troubleshooting)
2. Review Azure DevOps pipeline logs
3. Check Terraform error messages
4. Consult the architecture documentation

---

**Document Version**: 1.0
**Last Updated**: 2026-03-16
