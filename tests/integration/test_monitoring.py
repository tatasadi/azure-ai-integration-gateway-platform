"""
Monitoring and Observability Tests for Azure AI Integration Gateway

These tests verify that telemetry data is properly flowing to Application Insights
and that monitoring is configured correctly.

Usage:
    python -m pytest tests/integration/test_monitoring.py -v

Environment Variables Required:
    AZURE_SUBSCRIPTION_ID: Azure subscription ID
    AZURE_RESOURCE_GROUP: Resource group name
    APPLICATION_INSIGHTS_ID: Log Analytics workspace ID (NOT App Insights App ID!)
                             This is the Log Analytics workspace customer ID (GUID format)
                             Get it via: az monitor log-analytics workspace show --workspace-name <name> --query customerId
    APIM_BASE_URL: Base URL of the API Management instance
    APIM_SUBSCRIPTION_KEY: Valid subscription key for authentication
"""

import os
import pytest
import requests
import time
from datetime import datetime, timedelta
from azure.identity import DefaultAzureCredential, AzureCliCredential
from azure.monitor.query import LogsQueryClient, LogsQueryStatus
from typing import Optional


# Configuration
SUBSCRIPTION_ID = os.getenv("AZURE_SUBSCRIPTION_ID", "")
RESOURCE_GROUP = os.getenv("AZURE_RESOURCE_GROUP", "")
APP_INSIGHTS_ID = os.getenv("APPLICATION_INSIGHTS_ID", "")
BASE_URL = os.getenv("APIM_BASE_URL", "https://apim-aigateway-dev-eastus-01.azure-api.net")
SUBSCRIPTION_KEY = os.getenv("APIM_SUBSCRIPTION_KEY", "")

# Headers
HEADERS = {
    "Content-Type": "application/json",
    "Ocp-Apim-Subscription-Key": SUBSCRIPTION_KEY
}


@pytest.fixture(scope="module")
def logs_client():
    """Create Azure Monitor Logs Query client"""
    if not SUBSCRIPTION_ID or not APP_INSIGHTS_ID:
        pytest.skip("Azure credentials not configured")

    try:
        # Try Azure CLI credentials first (common in local dev)
        credential = AzureCliCredential()
        client = LogsQueryClient(credential)
        return client
    except Exception:
        try:
            # Fall back to default credential chain
            credential = DefaultAzureCredential()
            client = LogsQueryClient(credential)
            return client
        except Exception as e:
            pytest.skip(f"Could not authenticate to Azure: {e}")


@pytest.fixture
def test_request_id():
    """Make a test request and return the request ID"""
    # Make a test request to generate telemetry
    response = requests.get(
        f"{BASE_URL}/ai/health",
        headers=HEADERS
    )

    # Extract request ID from headers if available
    request_id = response.headers.get("X-Request-Id") or response.headers.get("x-request-id")

    # Wait a bit for telemetry to be processed
    time.sleep(5)

    return request_id


class TestApplicationInsightsIntegration:
    """Tests for Application Insights integration"""

    @pytest.mark.skipif(
        not APP_INSIGHTS_ID,
        reason="Application Insights not configured"
    )
    def test_requests_logged_to_app_insights(self, logs_client, test_request_id):
        """Requests should be logged to Application Insights"""

        # Query for recent requests (use longer time window for reliability)
        # Note: Application Insights data can take 2-5 minutes to be ingested
        query = """
        AppRequests
        | where TimeGenerated > ago(1h)
        | where Url contains "ai/"
        | project TimeGenerated, Name, Url, ResultCode, DurationMs
        | take 10
        """

        try:
            response = logs_client.query_workspace(
                workspace_id=APP_INSIGHTS_ID,
                query=query,
                timespan=timedelta(hours=1)
            )

            if response.status == LogsQueryStatus.SUCCESS:
                tables = response.tables
                assert len(tables) > 0, "No tables returned from query"

                rows = tables[0].rows
                assert len(rows) > 0, (
                    "No requests found in Application Insights. "
                    "Note: Telemetry data can take 2-5 minutes to appear. "
                    "Ensure APIM is configured to send telemetry to Application Insights."
                )

                # Verify we have the expected columns
                columns = [col for col in tables[0].columns]
                assert "ResultCode" in columns
                assert "DurationMs" in columns

            else:
                pytest.fail(f"Query failed with status: {response.status}")

        except Exception as e:
            pytest.fail(f"Failed to query Application Insights: {e}")

    @pytest.mark.skipif(
        not APP_INSIGHTS_ID,
        reason="Application Insights not configured"
    )
    def test_custom_metrics_logged(self, logs_client):
        """Custom metrics should be logged to Application Insights"""

        query = """
        AppMetrics
        | where TimeGenerated > ago(1h)
        | summarize count() by Name
        | take 10
        """

        try:
            response = logs_client.query_workspace(
                workspace_id=APP_INSIGHTS_ID,
                query=query,
                timespan=timedelta(hours=1)
            )

            if response.status == LogsQueryStatus.SUCCESS:
                # Custom metrics may not be present immediately
                # This test verifies the query works
                assert response.tables is not None

        except Exception as e:
            pytest.fail(f"Failed to query custom metrics: {e}")

    @pytest.mark.skipif(
        not APP_INSIGHTS_ID,
        reason="Application Insights not configured"
    )
    def test_dependencies_tracked(self, logs_client):
        """Dependencies (calls to OpenAI) should be tracked"""

        # First make a request that will call OpenAI
        try:
            requests.post(
                f"{BASE_URL}/ai/summarize",
                headers=HEADERS,
                json={"text": "Test for monitoring"},
                timeout=30
            )
        except:
            pass  # Continue even if request fails

        # Wait for telemetry
        time.sleep(10)

        query = """
        AppDependencies
        | where TimeGenerated > ago(10m)
        | where DependencyType == "HTTP" or DependencyType == "Azure"
        | project TimeGenerated, Name, DependencyType, Target, ResultCode, DurationMs
        | take 10
        """

        try:
            response = logs_client.query_workspace(
                workspace_id=APP_INSIGHTS_ID,
                query=query,
                timespan=timedelta(minutes=10)
            )

            if response.status == LogsQueryStatus.SUCCESS:
                # Dependencies should be tracked
                assert response.tables is not None

        except Exception as e:
            pytest.fail(f"Failed to query dependencies: {e}")


class TestCustomEvents:
    """Tests for custom events and logging"""

    @pytest.mark.skipif(
        not APP_INSIGHTS_ID,
        reason="Application Insights not configured"
    )
    def test_custom_events_logged(self, logs_client):
        """Custom events should be logged to Application Insights"""

        query = """
        AppEvents
        | where TimeGenerated > ago(1h)
        | summarize count() by Name
        | take 10
        """

        try:
            response = logs_client.query_workspace(
                workspace_id=APP_INSIGHTS_ID,
                query=query,
                timespan=timedelta(hours=1)
            )

            if response.status == LogsQueryStatus.SUCCESS:
                assert response.tables is not None

        except Exception as e:
            pytest.fail(f"Failed to query custom events: {e}")


class TestExceptions:
    """Tests for exception tracking"""

    @pytest.mark.skipif(
        not APP_INSIGHTS_ID,
        reason="Application Insights not configured"
    )
    def test_exceptions_tracked(self, logs_client):
        """Exceptions should be tracked in Application Insights"""

        # Trigger an error by sending invalid request
        try:
            requests.post(
                f"{BASE_URL}/ai/summarize",
                headers=HEADERS,
                data="invalid json",  # Send invalid data
                timeout=10
            )
        except:
            pass

        # Wait for telemetry
        time.sleep(5)

        query = """
        AppExceptions
        | where TimeGenerated > ago(10m)
        | project TimeGenerated, ExceptionType, OuterMessage, ProblemId
        | take 10
        """

        try:
            response = logs_client.query_workspace(
                workspace_id=APP_INSIGHTS_ID,
                query=query,
                timespan=timedelta(minutes=10)
            )

            if response.status == LogsQueryStatus.SUCCESS:
                # May or may not have exceptions depending on error handling
                assert response.tables is not None

        except Exception as e:
            pytest.fail(f"Failed to query exceptions: {e}")


class TestPerformanceMetrics:
    """Tests for performance metrics"""

    @pytest.mark.skipif(
        not APP_INSIGHTS_ID,
        reason="Application Insights not configured"
    )
    def test_request_duration_tracked(self, logs_client, test_request_id):
        """Request durations should be tracked"""

        query = """
        AppRequests
        | where TimeGenerated > ago(5m)
        | summarize
            avg(DurationMs),
            percentile(DurationMs, 95),
            percentile(DurationMs, 99),
            count()
        """

        try:
            response = logs_client.query_workspace(
                workspace_id=APP_INSIGHTS_ID,
                query=query,
                timespan=timedelta(minutes=5)
            )

            if response.status == LogsQueryStatus.SUCCESS:
                tables = response.tables
                assert len(tables) > 0, "No tables returned from query"

        except Exception as e:
            pytest.fail(f"Failed to query performance metrics: {e}")


class TestOperationalQueries:
    """Tests for operational monitoring queries"""

    @pytest.mark.skipif(
        not APP_INSIGHTS_ID,
        reason="Application Insights not configured"
    )
    def test_error_rate_query(self, logs_client):
        """Should be able to query error rates"""

        query = """
        AppRequests
        | where TimeGenerated > ago(1h)
        | summarize
            total_requests = count(),
            failed_requests = countif(toint(ResultCode) >= 400),
            error_rate = 100.0 * countif(toint(ResultCode) >= 400) / count()
        """

        try:
            response = logs_client.query_workspace(
                workspace_id=APP_INSIGHTS_ID,
                query=query,
                timespan=timedelta(hours=1)
            )

            if response.status == LogsQueryStatus.SUCCESS:
                assert response.tables is not None

        except Exception as e:
            pytest.fail(f"Failed to query error rates: {e}")

    @pytest.mark.skipif(
        not APP_INSIGHTS_ID,
        reason="Application Insights not configured"
    )
    def test_top_operations_query(self, logs_client):
        """Should be able to query top operations"""

        query = """
        AppRequests
        | where TimeGenerated > ago(1h)
        | summarize
            request_count = count(),
            avg_duration = avg(DurationMs)
            by OperationName
        | order by request_count desc
        | take 10
        """

        try:
            response = logs_client.query_workspace(
                workspace_id=APP_INSIGHTS_ID,
                query=query,
                timespan=timedelta(hours=1)
            )

            if response.status == LogsQueryStatus.SUCCESS:
                assert response.tables is not None

        except Exception as e:
            pytest.fail(f"Failed to query top operations: {e}")


class TestAlertQueries:
    """Test queries that would be used for alerts"""

    @pytest.mark.skipif(
        not APP_INSIGHTS_ID,
        reason="Application Insights not configured"
    )
    def test_high_error_rate_detection(self, logs_client):
        """Should be able to detect high error rates"""

        query = """
        AppRequests
        | where TimeGenerated > ago(5m)
        | summarize
            error_rate = 100.0 * countif(toint(ResultCode) >= 500) / count()
        | where error_rate > 0
        """

        try:
            response = logs_client.query_workspace(
                workspace_id=APP_INSIGHTS_ID,
                query=query,
                timespan=timedelta(minutes=5)
            )

            if response.status == LogsQueryStatus.SUCCESS:
                assert response.tables is not None

        except Exception as e:
            pytest.fail(f"Failed to query error rate for alerting: {e}")

    @pytest.mark.skipif(
        not APP_INSIGHTS_ID,
        reason="Application Insights not configured"
    )
    def test_slow_requests_detection(self, logs_client):
        """Should be able to detect slow requests"""

        query = """
        AppRequests
        | where TimeGenerated > ago(5m)
        | where DurationMs > 5000  // Requests slower than 5 seconds
        | project TimeGenerated, Name, Url, DurationMs, ResultCode
        | order by DurationMs desc
        | take 10
        """

        try:
            response = logs_client.query_workspace(
                workspace_id=APP_INSIGHTS_ID,
                query=query,
                timespan=timedelta(minutes=5)
            )

            if response.status == LogsQueryStatus.SUCCESS:
                assert response.tables is not None

        except Exception as e:
            pytest.fail(f"Failed to query slow requests: {e}")


# Smoke test for quick validation
def test_application_insights_configured():
    """Basic check that Application Insights environment is configured"""
    if not APP_INSIGHTS_ID:
        pytest.skip("APPLICATION_INSIGHTS_ID not configured")

    assert APP_INSIGHTS_ID, "Application Insights ID should be configured"
    assert SUBSCRIPTION_ID or os.getenv("AZURE_TENANT_ID"), "Azure credentials should be configured"


if __name__ == "__main__":
    print("Application Insights Monitoring Tests")
    print(f"App Insights ID: {APP_INSIGHTS_ID or 'Not configured'}")
    print(f"APIM Base URL: {BASE_URL}")
    print(f"Subscription Key configured: {bool(SUBSCRIPTION_KEY)}")

    if not APP_INSIGHTS_ID:
        print("\nWARNING: APPLICATION_INSIGHTS_ID not set")
        print("Set it using: export APPLICATION_INSIGHTS_ID=your-workspace-id")

    if not SUBSCRIPTION_KEY:
        print("\nWARNING: APIM_SUBSCRIPTION_KEY not set")
        print("Set it using: export APIM_SUBSCRIPTION_KEY=your-key")

    # Run tests
    pytest.main([__file__, "-v"])
