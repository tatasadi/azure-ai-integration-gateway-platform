# Testing Guide

This guide covers all aspects of testing the Azure AI Integration Gateway, from unit tests to load testing.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Test Types](#test-types)
- [Setup](#setup)
- [Running Tests](#running-tests)
- [Writing Tests](#writing-tests)
- [CI/CD Integration](#cicd-integration)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

- **Python** 3.8 or higher
- **pytest** testing framework
- **Azure CLI** (for monitoring tests)
- **curl** (for smoke tests)
- **jq** (optional, for JSON parsing)
- **Terraform** (for validation tests)
- **xmllint** (for XML validation)

### Azure Resources

For integration and monitoring tests, you need:
- Deployed APIM instance
- Valid subscription key
- Application Insights instance
- Appropriate Azure RBAC permissions

---

## Test Types

### 1. Unit Tests

Unit tests validate individual components without external dependencies.

**Location**: `tests/unit/`

**Coverage**:
- Terraform configuration validation
- APIM policy XML validation
- Security configuration checks
- Documentation completeness

### 2. Integration Tests

Integration tests validate end-to-end API functionality.

**Location**: `tests/integration/`

**Coverage**:
- API endpoint functionality
- Authentication and authorization
- Rate limiting
- Error handling
- Response formats

### 3. Smoke Tests

Quick validation tests to verify basic functionality.

**Location**: `tests/smoke/` and `scripts/`

**Coverage**:
- Health check endpoint
- Basic API operations
- Authentication validation

### 4. Monitoring Tests

Validate observability and telemetry.

**Location**: `tests/integration/test_monitoring.py`

**Coverage**:
- Application Insights data flow
- Custom metrics
- Logging validation

---

## Setup

### 1. Install Python Dependencies

```bash
cd tests
pip install -r requirements.txt
```

### 2. Set Environment Variables

Create a `.env` file or export variables:

```bash
# Required for integration and monitoring tests
export APIM_BASE_URL="https://apim-aigateway-dev-eastus-01.azure-api.net"
export APIM_SUBSCRIPTION_KEY="your-subscription-key-here"

# Required for monitoring tests
export AZURE_SUBSCRIPTION_ID="your-azure-subscription-id"
export AZURE_RESOURCE_GROUP="rg-aigateway-dev-eastus-01"
export APPLICATION_INSIGHTS_ID="your-app-insights-resource-id"

# Optional: Use Azure CLI authentication
az login
```

### 3. Verify Setup

```bash
# Test Azure CLI authentication
az account show

# Test APIM connectivity
curl -H "Ocp-Apim-Subscription-Key: $APIM_SUBSCRIPTION_KEY" \
  $APIM_BASE_URL/ai/health
```

---

## Running Tests

### Run All Tests

```bash
# From project root
python -m pytest tests/ -v

# With coverage report
python -m pytest tests/ -v --cov=. --cov-report=html
```

### Run Unit Tests Only

```bash
python -m pytest tests/unit/ -v
```

### Run Integration Tests Only

```bash
python -m pytest tests/integration/ -v
```

### Run Specific Test Class

```bash
python -m pytest tests/integration/test_ai_gateway.py::TestSummarizeEndpoint -v
```

### Run Specific Test Method

```bash
python -m pytest tests/integration/test_ai_gateway.py::TestSummarizeEndpoint::test_summarize_success -v
```

### Run Smoke Tests

```bash
# Using the smoke test script
./tests/smoke/smoke_test.sh $APIM_BASE_URL $APIM_SUBSCRIPTION_KEY

# Or
./scripts/smoke-test.sh $APIM_BASE_URL $APIM_SUBSCRIPTION_KEY
```

### Run Tests with Markers

```bash
# Run only smoke tests
python -m pytest -m smoke -v

# Skip slow tests
python -m pytest -m "not slow" -v

# Run only tests that don't require deployment
python -m pytest -m "not integration" -v
```

---

## Running Specific Test Suites

### Terraform Validation Tests

```bash
# Validate Terraform configuration
python -m pytest tests/unit/test_terraform_validation.py::TestTerraformValidation -v

# Validate APIM policies
python -m pytest tests/unit/test_terraform_validation.py::TestAPIMPolicyValidation -v
```

### Health Check Tests

```bash
python -m pytest tests/integration/test_ai_gateway.py::TestHealthEndpoint -v
```

### Authentication Tests

```bash
python -m pytest tests/integration/test_ai_gateway.py::TestAuthentication -v
```

### Rate Limiting Tests

```bash
# Note: These tests make many requests and may take time
python -m pytest tests/integration/test_ai_gateway.py::TestRateLimiting -v
```

### Monitoring Tests

```bash
# Requires Azure authentication
python -m pytest tests/integration/test_monitoring.py -v
```

---

## Writing Tests

### Test Structure

```python
import pytest
import requests

class TestMyFeature:
    """Tests for my feature"""

    @pytest.fixture
    def api_client(self):
        """Create an API client"""
        return {
            "base_url": os.getenv("APIM_BASE_URL"),
            "headers": {
                "Ocp-Apim-Subscription-Key": os.getenv("APIM_SUBSCRIPTION_KEY")
            }
        }

    def test_feature_success(self, api_client):
        """Test successful feature behavior"""
        response = requests.post(
            f"{api_client['base_url']}/ai/endpoint",
            headers=api_client['headers'],
            json={"data": "test"}
        )

        assert response.status_code == 200
        assert "result" in response.json()
```

### Best Practices

1. **Use descriptive test names**: `test_summarize_returns_200_with_valid_input`
2. **One assertion per test** (when practical)
3. **Use fixtures** for common setup
4. **Mock external dependencies** in unit tests
5. **Use markers** for test categorization
6. **Add docstrings** to explain test purpose
7. **Clean up resources** after tests

### Test Markers

```python
@pytest.mark.smoke  # Quick smoke test
@pytest.mark.slow   # Test that takes significant time
@pytest.mark.integration  # Requires deployed resources
@pytest.mark.skip(reason="Not yet implemented")  # Skip test
```

---

## CI/CD Integration

### Azure DevOps Pipeline

Tests are automatically run in the CI/CD pipeline:

```yaml
- stage: Test
  jobs:
    - job: UnitTests
      steps:
        - task: UsePythonVersion@0
          inputs:
            versionSpec: '3.9'
        - script: |
            pip install -r tests/requirements.txt
            pytest tests/unit/ -v --junitxml=test-results.xml
          displayName: 'Run Unit Tests'

    - job: IntegrationTests
      steps:
        - script: |
            pytest tests/integration/ -v --junitxml=test-results.xml
          displayName: 'Run Integration Tests'
          env:
            APIM_BASE_URL: $(APIM_BASE_URL)
            APIM_SUBSCRIPTION_KEY: $(APIM_SUBSCRIPTION_KEY)
```

### GitHub Actions

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      - name: Install dependencies
        run: pip install -r tests/requirements.txt
      - name: Run tests
        run: pytest tests/ -v
```

---

## Load Testing

### Using Azure Load Testing

1. **Create Load Test**:
   ```bash
   az load test create \
     --name "ai-gateway-load-test" \
     --resource-group "rg-aigateway-dev-eastus-01" \
     --test-plan-file load-test.jmx
   ```

2. **Run Load Test**:
   ```bash
   az load test run \
     --test-name "ai-gateway-load-test" \
     --parameters VirtualUsers=100 Duration=300
   ```

### Using Apache JMeter

1. Create test plan with thread groups
2. Configure HTTP requests to APIM endpoints
3. Add listeners for results
4. Run with: `jmeter -n -t load-test.jmx -l results.jtl`

### Using k6

```javascript
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '2m', target: 0 },
  ],
};

export default function () {
  let response = http.post(
    'https://apim-aigateway-dev.azure-api.net/ai/summarize',
    JSON.stringify({ text: 'Test data' }),
    {
      headers: {
        'Content-Type': 'application/json',
        'Ocp-Apim-Subscription-Key': __ENV.SUBSCRIPTION_KEY,
      },
    }
  );

  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 2000ms': (r) => r.timings.duration < 2000,
  });
}
```

Run with: `k6 run load-test.js`

---

## Test Data Management

### Using Fixtures

```python
@pytest.fixture
def sample_text():
    """Sample text for summarization tests"""
    return "Long article text here..."

@pytest.fixture
def sample_invoice():
    """Sample invoice for extraction tests"""
    return """
    INVOICE #12345
    Date: March 11, 2026
    Bill To: Acme Corp
    Total: $2,450.00
    """
```

### Using Faker for Random Data

```python
from faker import Faker

fake = Faker()

def test_with_random_data():
    text = fake.text(max_nb_chars=500)
    # Use text in test
```

---

## Monitoring Test Results

### View Test Results in Application Insights

```bash
# Query for test requests
az monitor app-insights query \
  --app $APPLICATION_INSIGHTS_ID \
  --analytics-query "requests | where name contains 'test' | take 100"
```

### Generate Coverage Report

```bash
pytest tests/ --cov=. --cov-report=html
open htmlcov/index.html
```

### Test Metrics to Track

- **Test pass rate**: % of tests passing
- **Code coverage**: % of code covered by tests
- **Test execution time**: How long tests take
- **Flaky tests**: Tests that intermittently fail

---

## Troubleshooting

### Common Issues

#### 1. Authentication Failures

**Symptom**: Tests fail with 401 errors

**Solution**:
```bash
# Verify subscription key is set
echo $APIM_SUBSCRIPTION_KEY

# Verify APIM URL is correct
echo $APIM_BASE_URL

# Test manually
curl -H "Ocp-Apim-Subscription-Key: $APIM_SUBSCRIPTION_KEY" \
  $APIM_BASE_URL/ai/health
```

#### 2. Rate Limiting Tests Fail

**Symptom**: Rate limit tests don't hit 429 errors

**Solution**:
- Verify rate limits are configured in APIM
- Check if using a different subscription with different limits
- Wait for rate limit window to reset (60 seconds)

#### 3. Terraform Validation Fails

**Symptom**: `terraform validate` fails

**Solution**:
```bash
cd terraform
terraform init -backend=false
terraform validate
# Fix any reported issues
```

#### 4. Missing Dependencies

**Symptom**: Import errors when running tests

**Solution**:
```bash
pip install -r tests/requirements.txt --upgrade
```

#### 5. Monitoring Tests Fail

**Symptom**: Can't query Application Insights

**Solution**:
```bash
# Login to Azure
az login

# Verify permissions
az role assignment list --assignee $(az account show --query user.name -o tsv)

# Verify Application Insights exists
az monitor app-insights component show --app $APPLICATION_INSIGHTS_ID
```

### Debug Mode

Run tests with debug output:

```bash
# Verbose output
pytest tests/ -v -s

# Show local variables on failure
pytest tests/ -l

# Stop on first failure
pytest tests/ -x

# Enter debugger on failure
pytest tests/ --pdb
```

---

## Test Environment Configuration

### Development Environment

```bash
export ENVIRONMENT=dev
export APIM_BASE_URL="https://apim-aigateway-dev-eastus-01.azure-api.net"
# Lower rate limits for testing
```

### Staging Environment

```bash
export ENVIRONMENT=staging
export APIM_BASE_URL="https://apim-aigateway-staging-eastus-01.azure-api.net"
# Production-like configuration
```

### Production Environment

```bash
# DO NOT run integration tests against production
# Use smoke tests only for production validation
./scripts/smoke-test.sh $PROD_URL $PROD_KEY
```

---

## Test Reporting

### Generate Test Report

```bash
# HTML report
pytest tests/ --html=report.html --self-contained-html

# JUnit XML (for CI/CD)
pytest tests/ --junitxml=test-results.xml

# Coverage report
pytest tests/ --cov=. --cov-report=term --cov-report=html
```

### View Reports

```bash
# Open HTML report
open report.html

# Open coverage report
open htmlcov/index.html
```

---

## Additional Resources

- [pytest Documentation](https://docs.pytest.org/)
- [Azure Load Testing Documentation](https://docs.microsoft.com/azure/load-testing/)
- [APIM Testing Best Practices](https://docs.microsoft.com/azure/api-management/api-management-test-apis)
- [Application Insights Testing](https://docs.microsoft.com/azure/azure-monitor/app/availability-overview)

---

## Contributing

When adding new features:

1. Write tests first (TDD approach)
2. Ensure tests pass locally
3. Update this documentation if needed
4. Verify CI/CD pipeline passes
5. Maintain >80% code coverage

---

**Last Updated**: March 16, 2026
**Version**: 1.0
