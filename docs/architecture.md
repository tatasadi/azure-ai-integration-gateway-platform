# Azure AI Integration Gateway - Architecture Documentation

## Overview

The Azure AI Integration Gateway is an enterprise-grade platform that provides centralized governance, security, rate limiting, and observability for AI services. It uses Azure API Management as the gateway layer and Azure AI Foundry for AI model hosting.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Client Applications                          │
│                   (Web, Mobile, Desktop, APIs)                      │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ HTTPS (Subscription Key)
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│                   Azure API Management (Gateway)                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Inbound Policies                                            │  │
│  │  • Subscription Key Validation                               │  │
│  │  • Rate Limiting (100 req/min per subscription)              │  │
│  │  • Quota Management (10,000 req/day per subscription)        │  │
│  │  • CORS Configuration                                        │  │
│  │  • Request Transformation                                    │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  API Operations                                              │  │
│  │  • POST /ai/summarize   - Text summarization                 │  │
│  │  • POST /ai/extract     - Information extraction             │  │
│  │  • GET  /ai/health      - Health check                       │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Outbound Policies                                           │  │
│  │  • Response Transformation                                   │  │
│  │  • Logging to Application Insights                           │  │
│  │  • Error Handling                                            │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ Managed Identity Authentication
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│                     Azure AI Foundry                                │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Azure AI Hub                                                │  │
│  │  • GPT-5-mini (gpt-5-mini)    - Primary model                │  │
│  │  • GPT-5-nano (gpt-5-nano)    - Cost-efficient alternative   │  │
│  │  • 400K context window                                       │  │
│  │  • Multimodal support (text + images)                        │  │
│  │  • Advanced reasoning capabilities                           │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             │ Diagnostic Logs
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│                   Observability & Security Layer                    │
│                                                                      │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │  Application     │  │   Azure Key      │  │   Managed        │  │
│  │  Insights        │  │   Vault          │  │   Identity       │  │
│  │                  │  │                  │  │                  │  │
│  │  • Request logs  │  │  • API keys      │  │  • APIM to AI    │  │
│  │  • Metrics       │  │  • Secrets       │  │  • No hardcoded  │  │
│  │  • Traces        │  │  • Certificates  │  │    credentials   │  │
│  │  • Custom events │  │                  │  │                  │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
│                                                                      │
│  ┌──────────────────┐  ┌──────────────────┐                        │
│  │  Azure Monitor   │  │   Log Analytics  │                        │
│  │                  │  │                  │                        │
│  │  • Alerts        │  │  • Query logs    │                        │
│  │  • Dashboards    │  │  • Analytics     │                        │
│  │  • Metrics       │  │  • Workbooks     │                        │
│  └──────────────────┘  └──────────────────┘                        │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Descriptions

### 1. Azure API Management (Gateway Layer)

**Purpose**: Acts as the central gateway for all AI service requests, providing security, rate limiting, and request transformation.

**Key Features**:
- **Tier**: Developer (supports up to 1,000 requests/sec, sufficient for dev/test)
- **Authentication**: Subscription key-based (simple, effective)
- **Rate Limiting**: 100 requests/minute per subscription
- **Quota Management**: 10,000 requests/day per subscription
- **Request Transformation**: Converts client requests to AI Foundry format
- **Response Transformation**: Normalizes AI responses for clients
- **Logging**: All requests logged to Application Insights

**Policies**:
- Global policies (authentication, CORS, base rate limiting)
- Operation-specific policies (transformation, routing)
- Error handling policies

### 2. Azure AI Foundry (AI Services Layer)

**Purpose**: Hosts and serves AI models with enterprise-grade infrastructure.

**Components**:
- **Azure AI Hub**: Central resource for AI project management
- **Azure AI Project**: Project-level organization
- **Cognitive Services Account**: Azure OpenAI service endpoint

**Models**:
- **GPT-5-mini** (gpt-5-mini): Primary model for complex tasks
  - 400K context window
  - Multimodal (text + images)
  - Advanced reasoning capabilities
  - Released August 2025

- **GPT-5-nano** (gpt-5-nano): Cost-efficient alternative
  - 400K context window
  - Multimodal support
  - Optimized for speed and cost

**Access Control**:
- Managed Identity authentication from APIM
- No API keys exposed to clients
- RBAC: "Cognitive Services User" role for APIM

### 3. Azure Key Vault (Secrets Management)

**Purpose**: Securely stores and manages secrets, certificates, and keys.

**Contents**:
- AI service keys (if needed for fallback)
- Certificates for TLS
- Connection strings (if needed)
- Subscription keys for APIM

**Security**:
- RBAC-enabled (no legacy access policies)
- Diagnostic logging enabled
- Managed Identity access only
- Network rules (if VNet integration added)

### 4. Managed Identity (Identity & Access)

**Purpose**: Provides secure, credential-free authentication between Azure services.

**Type**: User-Assigned Managed Identity

**Assignments**:
- APIM uses MI to authenticate to Azure AI Foundry
- APIM uses MI to access Key Vault
- No hardcoded credentials anywhere in the system

**RBAC Roles**:
- "Cognitive Services User" on Azure AI Foundry
- "Key Vault Secrets User" on Key Vault
- "Monitoring Metrics Publisher" for custom metrics

### 5. Application Insights (Observability)

**Purpose**: Centralized logging, tracing, and monitoring.

**Data Collected**:
- Request/response logs
- Custom metrics (token usage, cost tracking)
- Performance counters
- Dependency tracking
- Exception tracking
- Custom events (quota exhaustion, rate limit hits)

**Retention**: 90 days (configurable)

### 6. Azure Monitor (Alerting & Dashboards)

**Purpose**: Provides alerting and visualization capabilities.

**Alerts**:
- High error rate (>5% 5xx errors in 5 minutes)
- Quota exhaustion warnings
- Unusual token usage patterns
- APIM availability issues
- High latency (P95 >5 seconds)

**Dashboards**:
- Request volume trends
- Token consumption by operation
- Cost tracking by subscription
- Error rates and types
- Top API consumers

## Data Flow

### Request Flow: POST /ai/summarize

```
1. Client Request
   ↓
   POST https://ai-gateway.azure-api.net/ai/summarize
   Headers: Ocp-Apim-Subscription-Key: {key}
   Body: { "text": "Long article to summarize..." }

2. APIM Inbound Processing
   ↓
   • Validate subscription key (401 if invalid)
   • Check rate limit (429 if exceeded: 100/min)
   • Check daily quota (429 if exceeded: 10,000/day)
   • Apply CORS headers
   • Log request to Application Insights

3. Request Transformation
   ↓
   Transform to OpenAI format:
   {
     "messages": [
       { "role": "system", "content": "You are a summarization assistant." },
       { "role": "user", "content": "{text from request}" }
     ],
     "max_tokens": 500
   }

4. Backend Routing
   ↓
   Set backend URL: https://{ai-foundry-endpoint}/openai/deployments/gpt-5-mini/chat/completions
   Authenticate using Managed Identity

5. Azure AI Foundry Processing
   ↓
   • Validate Managed Identity
   • Process request with GPT-5-mini
   • Return response with usage metrics

6. APIM Outbound Processing
   ↓
   • Transform response to simplified format
   • Extract summary and token usage
   • Log response to Application Insights
   • Add custom headers (request ID, token count)

7. Client Response
   ↓
   200 OK
   {
     "summary": "This article discusses...",
     "tokens_used": 1234
   }
```

### Error Handling Flow

```
Error occurs at any stage
   ↓
APIM on-error policy activated
   ↓
• Log error details to Application Insights
• Return user-friendly error message
• Include request ID for tracking
   ↓
Client receives error response:
{
  "error": {
    "code": "RateLimitExceeded",
    "message": "Too many requests. Please retry after 60 seconds.",
    "request_id": "abc-123-def"
  }
}
```

## Security Model

### Defense in Depth

**Layer 1: Network Security**
- HTTPS/TLS 1.2+ enforcement
- Public endpoints (VNet integration can be added)
- DDoS protection (Azure platform-level)

**Layer 2: Authentication & Authorization**
- Subscription key requirement at APIM
- Managed Identity for service-to-service
- RBAC for Azure resource access
- No API keys in code or configuration

**Layer 3: Rate Limiting & Quotas**
- Per-subscription rate limits
- Daily quotas
- Token-based limits
- Cost controls

**Layer 4: Data Protection**
- Encryption at rest (Azure default)
- Encryption in transit (TLS)
- Request/response sanitization
- PII detection (can be added)

**Layer 5: Audit & Compliance**
- All requests logged
- Access logs in Application Insights
- Azure Activity Log for control plane
- Compliance dashboard support

## Scalability Considerations

### Current Setup (Developer Tier)
- Up to 1,000 requests/second
- No SLA guarantee
- Sufficient for development and testing

### Scale-Up Path
1. **Standard Tier**: 2,500 req/sec, 99.95% SLA
2. **Premium Tier**: Unlimited, 99.99% SLA, multi-region
3. **Auto-scaling**: Available in Premium tier

### AI Model Scaling
- Azure AI Foundry handles model scaling automatically
- Quota limits can be requested from Microsoft
- Token-based rate limiting to control costs

## High Availability

### Current Setup
- Single region deployment
- No built-in redundancy (Developer tier)

### Future Enhancements
1. **Multi-region APIM**: Premium tier with Traffic Manager
2. **Active-Active AI Foundry**: Deploy models in multiple regions
3. **Geo-redundant storage**: For state and logs
4. **Health probes**: Automated failover

## Cost Optimization

### Cost Drivers
1. **APIM**: Developer tier ~$50/month
2. **Azure AI Foundry**: Pay-per-token usage
3. **Application Insights**: Pay-per-GB ingested
4. **Key Vault**: ~$0.03 per 10K operations

### Cost Controls
- Rate limiting prevents runaway costs
- Daily quotas per subscription
- Token limits per request
- Budget alerts in Azure Monitor
- Custom metrics for cost tracking

## Disaster Recovery

### Backup Strategy
- Terraform state in Azure Storage (geo-redundant)
- APIM policies in source control
- Configuration as code (immutable infrastructure)

### Recovery Procedures
1. **APIM failure**: Redeploy from Terraform
2. **AI Foundry failure**: Automatically handled by Azure
3. **Key Vault deletion**: Soft-delete enabled (90-day recovery)
4. **Terraform state corruption**: Version history in storage

### RTO/RPO
- **Recovery Time Objective (RTO)**: 1 hour (manual redeploy)
- **Recovery Point Objective (RPO)**: Near-zero (infrastructure as code)

## Compliance & Governance

### Azure Policy
- Enforce tagging standards
- Require encryption
- Restrict resource types
- Audit non-compliant resources

### Resource Locks
- Production resources locked to prevent accidental deletion
- Terraform service principal has elevated permissions

### Audit Logging
- All control plane operations logged to Activity Log
- Data plane operations logged to Application Insights
- 90-day retention minimum

## Naming Conventions

### Resource Naming Pattern
```
{resource-type}-{project}-{environment}-{region}-{instance}
```

**Examples**:
- `apim-aigateway-dev-eastus-01`
- `kv-aigateway-prod-eastus-01`
- `ai-aigateway-dev-eastus-01`

### Tags
- `Environment`: dev/staging/prod
- `Project`: ai-gateway
- `Owner`: platform-team
- `CostCenter`: engineering
- `ManagedBy`: terraform

## Network Architecture

### Current Setup (Public Endpoints)
```
Internet → APIM (Public IP) → AI Foundry (Public Endpoint)
```

### Future: VNet Integration
```
Internet → Application Gateway (WAF) → APIM (VNet Integrated) → AI Foundry (Private Endpoint)
```

**Benefits of VNet Integration**:
- Private connectivity
- Additional WAF protection
- Network isolation
- NSG-based traffic control

## Monitoring Strategy

### Key Metrics

**API Gateway Metrics**:
- Total requests
- Requests by operation
- Response codes (2xx, 4xx, 5xx)
- Latency (P50, P95, P99)
- Rate limit hits
- Quota exhaustion events

**AI Service Metrics**:
- Token usage (total, by operation)
- Model latency
- Model errors
- Cost per request

**Infrastructure Metrics**:
- APIM CPU/memory
- Storage usage
- Network throughput

### Alerting Rules

**Critical Alerts** (immediate action):
- APIM availability <99%
- Error rate >10%
- AI Foundry quota exhausted

**Warning Alerts** (investigate):
- Error rate >5%
- P95 latency >5 seconds
- Approaching daily quota (90%)

**Informational**:
- Unusual traffic patterns
- Cost anomalies
- New subscription activity

## Operations

### Deployment Process
1. Code changes merged to main branch
2. Azure DevOps pipeline triggered
3. Terraform plan generated
4. Manual approval (staging/prod)
5. Terraform apply executed
6. APIM policies deployed
7. Smoke tests executed
8. Monitoring verified

### Rollback Process
1. Identify bad deployment
2. Revert Git commit
3. Re-run pipeline
4. Verify rollback successful

### Maintenance Windows
- None required (rolling updates)
- APIM policies can be updated without downtime
- AI model updates handled by Azure

## Future Enhancements

### Phase 2 Potential Features
1. OAuth 2.0 / Entra ID authentication
2. VNet integration and private endpoints
3. Multi-region deployment
4. Advanced prompt engineering
5. Custom AI model deployments
6. Semantic caching
7. Request/response validation schemas
8. PII detection and masking
9. Advanced cost allocation
10. Self-service portal for API consumers

## References

- [Azure API Management Documentation](https://docs.microsoft.com/azure/api-management/)
- [Azure AI Foundry Documentation](https://docs.microsoft.com/azure/ai-studio/)
- [Azure Managed Identity Documentation](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

---

**Document Version**: 1.0
**Last Updated**: 2026-03-11
**Status**: Phase 1 - Initial Architecture
