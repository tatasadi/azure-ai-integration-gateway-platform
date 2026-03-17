# Azure AI Integration Gateway - Tests

Comprehensive test suite for the Azure AI Integration Gateway platform.

## Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure Environment

```bash
# Required for integration tests
export APIM_BASE_URL="https://apim-aigateway-dev-eastus-01.azure-api.net"
export APIM_SUBSCRIPTION_KEY="your-subscription-key"

# Required for monitoring tests
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export APPLICATION_INSIGHTS_ID="your-log-analytics-workspace-id"  # NOT App Insights App ID!

# Login to Azure
az login
```

### 3. Run Tests

```bash
# Run all tests
pytest -v

# Run specific test suite
pytest unit/ -v                           # Unit tests
pytest integration/test_ai_gateway.py -v  # Integration tests
pytest integration/test_monitoring.py -v  # Monitoring tests

# Run smoke tests
./smoke/smoke_test.sh $APIM_BASE_URL $APIM_SUBSCRIPTION_KEY
```

---

## Test Structure

```
tests/
├── requirements.txt          # Python dependencies
├── README.md                 # This file
├── unit/                     # Unit tests (no external dependencies)
│   └── test_terraform_validation.py
├── integration/              # Integration tests (requires deployed resources)
│   ├── test_ai_gateway.py   # API endpoint tests
│   └── test_monitoring.py   # Observability tests
└── smoke/                    # Quick smoke tests
    └── smoke_test.sh         # Bash smoke test script
```

---

## Test Categories

### Unit Tests
Tests that validate configuration and structure without external dependencies.

**Coverage**:
- Terraform configuration validation
- APIM policy XML validation
- Security checks (no hardcoded secrets)
- Documentation completeness

**Run**: `pytest unit/ -v`

### Integration Tests
End-to-end tests that validate the deployed API Gateway.

**Coverage**:
- API endpoint functionality (health, summarize, extract)
- Authentication and authorization
- Rate limiting and quotas
- Error handling
- CORS configuration
- Application Insights integration

**Run**: `pytest integration/ -v`

### Smoke Tests
Quick validation tests for basic functionality.

**Coverage**:
- Health check
- Basic API operations
- Authentication validation

**Run**: `./smoke/smoke_test.sh <url> <key>`

---

## Running Specific Tests

### All Tests
```bash
pytest -v
```

### Specific Test Class
```bash
pytest integration/test_ai_gateway.py::TestSummarizeEndpoint -v
```

### Specific Test Method
```bash
pytest integration/test_ai_gateway.py::TestSummarizeEndpoint::test_summarize_success -v
```

### With Coverage
```bash
pytest --cov=. --cov-report=html
open htmlcov/index.html
```

### Skip Slow Tests
```bash
pytest -m "not slow" -v
```

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `APIM_BASE_URL` | Yes (integration) | Base URL of APIM instance |
| `APIM_SUBSCRIPTION_KEY` | Yes (integration) | Valid subscription key |
| `AZURE_SUBSCRIPTION_ID` | Yes (monitoring) | Azure subscription ID |
| `APPLICATION_INSIGHTS_ID` | Yes (monitoring) | Log Analytics workspace ID (customerId, not App Insights App ID) |
| `RUN_RATE_LIMIT_TESTS` | No | Set to `1` to enable rate limit tests |
| `RUN_QUOTA_TESTS` | No | Set to `1` to enable quota tests |

---

## Test Markers

Tests use pytest markers for categorization. Markers are defined in `pytest.ini`:

| Marker | Description | Usage |
|--------|-------------|-------|
| `slow` | Slow tests (rate limiting, load tests) | Skip with `-m "not slow"` |
| `integration` | Tests requiring deployed Azure resources | Skip with `-m "not integration"` |
| `smoke` | Quick smoke tests | Run with `-m smoke` |

**Examples:**

```bash
# Run only smoke tests
pytest -m smoke -v

# Skip slow tests (rate limiting, load tests)
pytest -m "not slow" -v

# Run only tests that don't require deployment
pytest -m "not integration" -v

# List all available markers
pytest --markers
```

---

## CI/CD Integration

### Azure DevOps Example

```yaml
- script: |
    pip install -r tests/requirements.txt
    pytest tests/ -v --junitxml=test-results.xml
  displayName: 'Run Tests'
  env:
    APIM_BASE_URL: $(APIM_BASE_URL)
    APIM_SUBSCRIPTION_KEY: $(APIM_SUBSCRIPTION_KEY)
```

### GitHub Actions Example

```yaml
- name: Run tests
  run: |
    pip install -r tests/requirements.txt
    pytest tests/ -v
  env:
    APIM_BASE_URL: ${{ secrets.APIM_BASE_URL }}
    APIM_SUBSCRIPTION_KEY: ${{ secrets.APIM_SUBSCRIPTION_KEY }}
```

---

## Writing New Tests

### Test Template

```python
import pytest
import requests

class TestMyFeature:
    """Tests for my feature"""

    def test_feature_success(self):
        """Test successful behavior"""
        # Arrange
        url = f"{BASE_URL}/api/endpoint"
        data = {"key": "value"}

        # Act
        response = requests.post(url, json=data, headers=HEADERS)

        # Assert
        assert response.status_code == 200
        assert "result" in response.json()
```

### Best Practices

1. Use descriptive test names
2. Follow Arrange-Act-Assert pattern
3. One assertion per test (when practical)
4. Use fixtures for common setup
5. Add docstrings
6. Use appropriate markers

---

## Troubleshooting

### Authentication Errors (401)
```bash
# Verify environment variables
echo $APIM_BASE_URL
echo $APIM_SUBSCRIPTION_KEY

# Test manually
curl -H "Ocp-Apim-Subscription-Key: $APIM_SUBSCRIPTION_KEY" \
  $APIM_BASE_URL/ai/health
```

### Module Import Errors
```bash
# Reinstall dependencies
pip install -r requirements.txt --upgrade
```

### Monitoring Tests Fail
```bash
# Verify Azure login
az login
az account show

# Get the correct Log Analytics workspace ID
az monitor log-analytics workspace show \
  --workspace-name log-aigateway-dev-swedencentral \
  --resource-group rg-aigateway-dev-swedencentral \
  --query customerId -o tsv

# Set the correct workspace ID (NOT the App Insights App ID!)
export APPLICATION_INSIGHTS_ID="<workspace-customer-id>"

# Verify permissions
az role assignment list --assignee $(az account show --query user.name -o tsv)
```

---

## Documentation

For complete testing documentation, see:
- [Testing Guide](../docs/testing-guide.md) - Comprehensive testing documentation
- [Phase 8 Summary](../docs/phase8-completion-summary.md) - Phase 8 completion details

---

## Contributing

When adding new features:
1. Write tests first (TDD)
2. Ensure tests pass locally
3. Update documentation if needed
4. Maintain >80% code coverage

---

**Last Updated**: March 16, 2026
