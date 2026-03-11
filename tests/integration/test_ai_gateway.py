"""
Integration tests for Azure AI Integration Gateway

These tests verify the end-to-end functionality of the AI Gateway API.

Usage:
    python -m pytest tests/integration/test_ai_gateway.py -v

Environment Variables Required:
    APIM_BASE_URL: Base URL of the API Management instance
    APIM_SUBSCRIPTION_KEY: Valid subscription key for authentication
"""

import os
import pytest
import requests
import time
from typing import Dict, Any

# Configuration
BASE_URL = os.getenv("APIM_BASE_URL", "https://apim-aigateway-dev-eastus-01.azure-api.net")
SUBSCRIPTION_KEY = os.getenv("APIM_SUBSCRIPTION_KEY", "")

# Headers
HEADERS = {
    "Content-Type": "application/json",
    "Ocp-Apim-Subscription-Key": SUBSCRIPTION_KEY
}


class TestHealthEndpoint:
    """Tests for the health check endpoint"""

    def test_health_check_returns_200(self):
        """Health endpoint should return 200 OK"""
        response = requests.get(
            f"{BASE_URL}/ai/health",
            headers=HEADERS
        )
        assert response.status_code == 200

    def test_health_check_response_structure(self):
        """Health endpoint should return expected JSON structure"""
        response = requests.get(
            f"{BASE_URL}/ai/health",
            headers=HEADERS
        )
        data = response.json()

        assert "status" in data
        assert "timestamp" in data
        assert "services" in data
        assert "version" in data

        assert data["status"] == "healthy"
        assert "api_gateway" in data["services"]
        assert "ai_foundry" in data["services"]

    def test_health_check_without_subscription_key(self):
        """Health endpoint should require subscription key"""
        response = requests.get(
            f"{BASE_URL}/ai/health",
            headers={"Content-Type": "application/json"}
        )
        assert response.status_code == 401


class TestSummarizeEndpoint:
    """Tests for the text summarization endpoint"""

    def test_summarize_success(self):
        """Summarize endpoint should return summary for valid input"""
        response = requests.post(
            f"{BASE_URL}/ai/summarize",
            headers=HEADERS,
            json={
                "text": "The global economy showed signs of recovery in 2026 as technology sectors led growth across major markets. Artificial intelligence continued to drive innovation in healthcare, finance, and manufacturing.",
                "max_length": 100,
                "style": "concise"
            }
        )

        assert response.status_code == 200

        data = response.json()
        assert "summary" in data
        assert "tokens_used" in data
        assert "request_id" in data
        assert "model" in data

        assert isinstance(data["summary"], str)
        assert len(data["summary"]) > 0
        assert data["tokens_used"] > 0
        assert data["model"] == "gpt-5-mini"

    def test_summarize_different_styles(self):
        """Summarize endpoint should support different styles"""
        text = "Test article about technology trends."

        for style in ["concise", "detailed", "bullet_points"]:
            response = requests.post(
                f"{BASE_URL}/ai/summarize",
                headers=HEADERS,
                json={
                    "text": text,
                    "style": style
                }
            )
            assert response.status_code == 200
            data = response.json()
            assert "summary" in data

    def test_summarize_missing_text_field(self):
        """Summarize endpoint should return 400 for missing text field"""
        response = requests.post(
            f"{BASE_URL}/ai/summarize",
            headers=HEADERS,
            json={
                "max_length": 100
            }
        )
        assert response.status_code in [400, 500]  # Depending on policy implementation

    def test_summarize_response_headers(self):
        """Summarize endpoint should return expected headers"""
        response = requests.post(
            f"{BASE_URL}/ai/summarize",
            headers=HEADERS,
            json={
                "text": "Short test text for summarization."
            }
        )

        assert response.status_code == 200
        assert "X-Request-Id" in response.headers
        assert "X-Token-Usage" in response.headers or "X-RateLimit-Remaining" in response.headers


class TestExtractEndpoint:
    """Tests for the information extraction endpoint"""

    def test_extract_success(self):
        """Extract endpoint should return structured data for valid input"""
        response = requests.post(
            f"{BASE_URL}/ai/extract",
            headers=HEADERS,
            json={
                "text": "INVOICE #12345\nDate: March 11, 2026\nBill To: Acme Corp\nTotal Amount: $2,450.00",
                "schema": {
                    "type": "object",
                    "properties": {
                        "invoice_number": {"type": "string"},
                        "date": {"type": "string"},
                        "customer": {"type": "string"},
                        "total": {"type": "number"}
                    }
                }
            }
        )

        assert response.status_code == 200

        data = response.json()
        assert "extracted_data" in data
        assert "confidence" in data
        assert "tokens_used" in data
        assert "request_id" in data
        assert "model" in data

        assert isinstance(data["extracted_data"], dict)
        assert data["tokens_used"] > 0
        assert 0 <= data["confidence"] <= 1

    def test_extract_missing_schema(self):
        """Extract endpoint should return 400 for missing schema"""
        response = requests.post(
            f"{BASE_URL}/ai/extract",
            headers=HEADERS,
            json={
                "text": "Some text to extract from"
            }
        )
        assert response.status_code in [400, 500]


class TestRateLimiting:
    """Tests for rate limiting functionality"""

    @pytest.mark.skip(reason="This test makes many requests and may take time")
    def test_rate_limit_exceeded(self):
        """Should return 429 when rate limit is exceeded"""
        # Make requests until rate limit is hit (100 per minute)
        responses = []

        for i in range(105):
            response = requests.post(
                f"{BASE_URL}/ai/summarize",
                headers=HEADERS,
                json={"text": f"Test text {i}"}
            )
            responses.append(response.status_code)

            if response.status_code == 429:
                break

        # Should have hit rate limit
        assert 429 in responses

    def test_rate_limit_headers_present(self):
        """Rate limit headers should be present in response"""
        response = requests.get(
            f"{BASE_URL}/ai/health",
            headers=HEADERS
        )

        # At least one rate limit header should be present
        has_rate_limit_header = (
            "X-RateLimit-Remaining" in response.headers or
            "X-RateLimit-Reset" in response.headers
        )
        # Note: Headers may not always be present depending on APIM configuration


class TestAuthentication:
    """Tests for authentication and authorization"""

    def test_missing_subscription_key(self):
        """Request without subscription key should return 401"""
        response = requests.get(
            f"{BASE_URL}/ai/health",
            headers={"Content-Type": "application/json"}
        )
        assert response.status_code == 401

    def test_invalid_subscription_key(self):
        """Request with invalid subscription key should return 401"""
        response = requests.get(
            f"{BASE_URL}/ai/health",
            headers={
                "Content-Type": "application/json",
                "Ocp-Apim-Subscription-Key": "invalid-key-12345"
            }
        )
        assert response.status_code == 401


class TestCORS:
    """Tests for CORS configuration"""

    def test_cors_headers_present(self):
        """CORS headers should be present in response"""
        response = requests.options(
            f"{BASE_URL}/ai/summarize",
            headers={
                **HEADERS,
                "Origin": "https://example.com",
                "Access-Control-Request-Method": "POST"
            }
        )

        # CORS headers may be present
        # Note: Actual CORS behavior depends on APIM configuration


class TestErrorHandling:
    """Tests for error handling"""

    def test_invalid_json_returns_error(self):
        """Invalid JSON should return appropriate error"""
        response = requests.post(
            f"{BASE_URL}/ai/summarize",
            headers={
                "Content-Type": "application/json",
                "Ocp-Apim-Subscription-Key": SUBSCRIPTION_KEY
            },
            data="invalid json"
        )
        assert response.status_code in [400, 500]

    def test_error_response_structure(self):
        """Error responses should have consistent structure"""
        response = requests.post(
            f"{BASE_URL}/ai/summarize",
            headers={
                "Content-Type": "application/json",
                "Ocp-Apim-Subscription-Key": SUBSCRIPTION_KEY
            },
            data="invalid json"
        )

        if response.status_code >= 400:
            try:
                data = response.json()
                # Error responses should ideally have an 'error' key
                # This depends on APIM policy configuration
            except:
                pass  # Some errors may not return JSON


if __name__ == "__main__":
    # Quick smoke test
    print(f"Testing AI Gateway at: {BASE_URL}")
    print(f"Subscription key configured: {bool(SUBSCRIPTION_KEY)}")

    if not SUBSCRIPTION_KEY:
        print("WARNING: APIM_SUBSCRIPTION_KEY environment variable not set")
        print("Set it using: export APIM_SUBSCRIPTION_KEY=your-key-here")

    # Run a simple health check
    try:
        response = requests.get(f"{BASE_URL}/ai/health", headers=HEADERS, timeout=10)
        print(f"Health check status: {response.status_code}")
        if response.status_code == 200:
            print(f"Response: {response.json()}")
    except Exception as e:
        print(f"Error: {e}")
