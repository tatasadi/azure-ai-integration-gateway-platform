# Azure AI Integration Gateway Platform

An enterprise-grade AI Gateway built on Azure API Management and Azure AI Foundry, providing centralized governance, security, rate limiting, and observability for AI services.

## Overview

This platform provides a secure, scalable gateway layer for AI services, enabling:

- **Centralized AI Governance**: Single entry point for all AI requests
- **Security**: Subscription key authentication, rate limiting, and quotas
- **Observability**: Comprehensive logging and monitoring via Application Insights
- **Cost Control**: Token tracking and usage metrics per subscription
- **Developer Experience**: Well-documented REST API with client SDKs

## Architecture

```
Client Applications
       │
       │ HTTPS (Subscription Key)
       ▼
Azure API Management (Gateway)
       │
       │ Managed Identity
       ▼
Azure AI Foundry (GPT-4o)
       │
       └──> Application Insights (Logging)
```

See [docs/architecture.md](docs/architecture.md) for detailed architecture documentation.

## Features

### API Operations

- **POST /ai/summarize** - Text summarization
- **POST /ai/extract** - Information extraction
- **GET /ai/health** - Health check

See [docs/api-design.md](docs/api-design.md) for complete API documentation.

### Security Features

- Subscription key authentication
- Rate limiting (100 requests/minute)
- Daily quotas (10,000 requests/day)
- Managed Identity for service-to-service authentication
- No hardcoded credentials
- Azure Key Vault integration

### Observability

- Request/response logging to Application Insights
- Custom metrics (token usage, cost tracking)
- Azure Monitor alerts
- Performance monitoring
- Error tracking

## Prerequisites

### Required Tools

- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) >= 2.40.0
- [Git](https://git-scm.com/downloads)
- [Python](https://www.python.org/downloads/) >= 3.8 (for testing)

### Azure Requirements

- Azure subscription with appropriate permissions
- Service Principal for Terraform (Contributor role)
- Azure DevOps project (for CI/CD)

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd azure-ai-integration-gateway-platform
```

### 2. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_name         = "aigateway"
environment          = "dev"
location             = "eastus"
apim_publisher_email = "your-email@example.com"
enable_gpt4o         = true
enable_gpt35_turbo   = false
```

### 3. Login to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 4. Deploy Infrastructure

```bash
# Validate configuration
../scripts/validate.sh

# Deploy to dev environment
../scripts/deploy.sh dev
```

### 5. Get Deployment Outputs

```bash
terraform output
```

Note the `apim_gateway_url` and `apim_portal_url` from the outputs.

### 6. Obtain Subscription Key

1. Navigate to the APIM Developer Portal URL from the outputs
2. Sign in and create a subscription
3. Copy your subscription key

### 7. Test the API

```bash
# Test health endpoint
curl -X GET \
  https://apim-aigateway-dev-eastus-01.azure-api.net/ai/health \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY_HERE"

# Test summarization
curl -X POST \
  https://apim-aigateway-dev-eastus-01.azure-api.net/ai/summarize \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY_HERE" \
  -d '{
    "text": "Long article text here...",
    "max_length": 500,
    "style": "concise"
  }'
```

## Project Structure

```
azure-ai-integration-gateway-platform/
├── docs/                           # Documentation
│   ├── architecture.md             # Architecture details
│   └── api-design.md               # API specifications
├── terraform/                      # Infrastructure as Code
│   ├── modules/                    # Terraform modules
│   │   ├── resource-group/         # Resource group module
│   │   ├── api-management/         # APIM module
│   │   ├── ai-foundry/             # AI Foundry module
│   │   ├── key-vault/              # Key Vault module
│   │   ├── managed-identity/       # Managed Identity module
│   │   └── monitoring/             # Monitoring module
│   ├── environments/               # Environment-specific configs
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   ├── main.tf                     # Main Terraform configuration
│   ├── variables.tf                # Variable definitions
│   ├── outputs.tf                  # Output definitions
│   └── terraform.tfvars.example    # Example variables file
├── apim-policies/                  # APIM Policy definitions
│   ├── global/                     # Global policies
│   │   └── base-policy.xml         # Base policy (auth, rate limiting)
│   └── operations/                 # Operation-specific policies
│       ├── summarize-policy.xml    # Summarization policy
│       ├── extract-policy.xml      # Extraction policy
│       └── health-policy.xml       # Health check policy
├── scripts/                        # Deployment scripts
│   ├── deploy.sh                   # Deployment script
│   └── validate.sh                 # Validation script
├── pipelines/                      # CI/CD pipelines
│   └── azure-devops-pipeline.yml   # Azure DevOps pipeline
├── tests/                          # Test suites
│   ├── integration/                # Integration tests
│   │   └── test_ai_gateway.py      # API integration tests
│   └── smoke/                      # Smoke tests
│       └── smoke_test.sh           # Basic smoke tests
├── .gitignore                      # Git ignore rules
└── README.md                       # This file
```

## Deployment Environments

### Development (dev)

- APIM SKU: Developer
- Auto-deployment from main branch
- Used for testing and development

### Staging (staging)

- APIM SKU: Developer/Standard
- Manual approval required
- Pre-production testing

### Production (prod)

- APIM SKU: Standard/Premium
- Manual approval required
- Production workloads

## Configuration

### Environment Variables

For testing, set these environment variables:

```bash
export APIM_BASE_URL="https://apim-aigateway-dev-eastus-01.azure-api.net"
export APIM_SUBSCRIPTION_KEY="your-subscription-key"
```

### Terraform Variables

Key variables in `terraform.tfvars`:

| Variable | Description | Default |
|----------|-------------|---------|
| `project_name` | Project name | `aigateway` |
| `environment` | Environment (dev/staging/prod) | - |
| `location` | Azure region | `eastus` |
| `apim_publisher_email` | APIM publisher email | - |
| `apim_sku_name` | APIM SKU | `Developer_1` |
| `enable_gpt4o` | Enable GPT-4o model | `true` |
| `enable_gpt35_turbo` | Enable GPT-35-Turbo model | `false` |

## Testing

### Run Integration Tests

```bash
cd tests/integration
pip install -r requirements.txt  # Install dependencies

export APIM_BASE_URL="https://your-apim-url.azure-api.net"
export APIM_SUBSCRIPTION_KEY="your-key"

python -m pytest test_ai_gateway.py -v
```

### Run Smoke Tests

```bash
cd tests/smoke
chmod +x smoke_test.sh
./smoke_test.sh https://your-apim-url.azure-api.net your-subscription-key
```

## Monitoring & Observability

### Application Insights

View logs and metrics in Azure Portal:

1. Navigate to Application Insights resource
2. View "Live Metrics" for real-time monitoring
3. Query logs using Kusto Query Language (KQL)

Example KQL query:

```kql
traces
| where customDimensions.EventName == "SummarizeRequest"
| project timestamp, customDimensions.SubscriptionId, customDimensions.TokensUsed
| order by timestamp desc
```

### Azure Monitor Alerts

Configured alerts:

- High error rate (>5% 5xx errors)
- Quota exhaustion
- Unusual token usage
- APIM availability issues
- High latency (P95 >5 seconds)

## Cost Management

### Cost Drivers

1. **API Management**: ~$50/month (Developer tier)
2. **Azure AI Foundry**: Pay-per-token usage
3. **Application Insights**: Pay-per-GB ingested
4. **Key Vault**: ~$0.03 per 10K operations

### Cost Controls

- Rate limiting (100 requests/minute)
- Daily quotas (10,000 requests/day)
- Token limits per request
- Budget alerts via Azure Monitor

## CI/CD Pipeline

### Azure DevOps

The pipeline includes:

1. **Validate**: Terraform validation, policy validation, security scanning
2. **Plan**: Generate Terraform plan for each environment
3. **Deploy**: Apply infrastructure changes with approval gates

### Pipeline Stages

- Dev: Auto-deploy on merge to main
- Staging: Manual approval required
- Production: Manual approval required

See [pipelines/azure-devops-pipeline.yml](pipelines/azure-devops-pipeline.yml)

## Security Best Practices

1. **Never commit secrets**: Use Azure Key Vault
2. **Use Managed Identity**: No hardcoded credentials
3. **Enable RBAC**: Least privilege access
4. **Monitor access**: Enable audit logging
5. **Rotate keys**: Regular key rotation policy
6. **Review policies**: Regular security reviews

## Troubleshooting

### Common Issues

#### 1. Terraform Init Fails

```bash
# Clear Terraform cache
rm -rf .terraform
terraform init
```

#### 2. Deployment Fails Due to Naming Conflicts

Azure resource names must be globally unique. Modify the `project_name` in `terraform.tfvars`.

#### 3. API Returns 401 Unauthorized

- Verify subscription key is correct
- Check subscription is active in APIM portal
- Ensure key is passed in correct header: `Ocp-Apim-Subscription-Key`

#### 4. Rate Limit Errors

Wait for the rate limit window to reset (60 seconds) or request quota increase.

### Getting Help

1. Check [docs/architecture.md](docs/architecture.md) for architecture details
2. Review [docs/api-design.md](docs/api-design.md) for API specifications
3. Check Application Insights logs for detailed error information
4. Open an issue in the repository

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards

- Run `terraform fmt` before committing
- Validate with `./scripts/validate.sh`
- Update documentation for new features
- Add tests for new functionality


## License

This project is licensed under the MIT License

---

**Version**: 1.0.0
**Last Updated**: 2026-03-11

