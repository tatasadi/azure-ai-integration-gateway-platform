#!/bin/bash

################################################################################
# Azure AI Integration Gateway - Smoke Test
################################################################################
# This script performs basic smoke tests to verify the gateway is operational
#
# Usage: ./smoke_test.sh <apim_url> <subscription_key>
#   apim_url: Base URL of the API Management instance
#   subscription_key: Valid subscription key
#
# Example: ./smoke_test.sh https://apim-aigateway-dev-eastus-01.azure-api.net your-key-here
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check arguments
if [ $# -ne 2 ]; then
    log_error "Usage: $0 <apim_url> <subscription_key>"
    exit 1
fi

APIM_URL=$1
SUBSCRIPTION_KEY=$2

log_info "Starting smoke tests for: $APIM_URL"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Health Check
log_info "Test 1: Health Check"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET \
    "$APIM_URL/ai/health" \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    log_success "Health check passed (HTTP $HTTP_CODE)"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
    ((TESTS_PASSED++))
else
    log_error "Health check failed (HTTP $HTTP_CODE)"
    echo "$BODY"
    ((TESTS_FAILED++))
fi

echo ""

# Test 2: Summarize Endpoint
log_info "Test 2: Summarize Endpoint"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "$APIM_URL/ai/summarize" \
    -H "Content-Type: application/json" \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    -d '{
        "text": "Azure AI Integration Gateway provides centralized governance, security, rate limiting, and observability for AI services using Azure API Management.",
        "max_length": 50,
        "style": "concise"
    }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    log_success "Summarize endpoint passed (HTTP $HTTP_CODE)"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
    ((TESTS_PASSED++))
else
    log_error "Summarize endpoint failed (HTTP $HTTP_CODE)"
    echo "$BODY"
    ((TESTS_FAILED++))
fi

echo ""

# Test 3: Extract Endpoint
log_info "Test 3: Extract Endpoint"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "$APIM_URL/ai/extract" \
    -H "Content-Type: application/json" \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    -d '{
        "text": "Invoice #12345, Date: 2026-03-11, Amount: $500.00",
        "schema": {
            "type": "object",
            "properties": {
                "invoice_number": {"type": "string"},
                "date": {"type": "string"},
                "amount": {"type": "number"}
            }
        }
    }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    log_success "Extract endpoint passed (HTTP $HTTP_CODE)"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
    ((TESTS_PASSED++))
else
    log_error "Extract endpoint failed (HTTP $HTTP_CODE)"
    echo "$BODY"
    ((TESTS_FAILED++))
fi

echo ""

# Test 4: Authentication (Invalid Key)
log_info "Test 4: Authentication Test (Invalid Key)"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET \
    "$APIM_URL/ai/health" \
    -H "Ocp-Apim-Subscription-Key: invalid-key-12345")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "401" ]; then
    log_success "Authentication test passed (HTTP $HTTP_CODE) - Invalid key rejected"
    ((TESTS_PASSED++))
else
    log_error "Authentication test failed (HTTP $HTTP_CODE) - Expected 401"
    ((TESTS_FAILED++))
fi

echo ""

# Test 5: Missing Subscription Key
log_info "Test 5: Missing Subscription Key Test"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$APIM_URL/ai/health")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "401" ]; then
    log_success "Missing key test passed (HTTP $HTTP_CODE) - Request rejected"
    ((TESTS_PASSED++))
else
    log_error "Missing key test failed (HTTP $HTTP_CODE) - Expected 401"
    ((TESTS_FAILED++))
fi

echo ""

# Summary
echo "=========================================="
echo "Smoke Test Results"
echo "=========================================="
log_success "Tests Passed: $TESTS_PASSED"
if [ $TESTS_FAILED -gt 0 ]; then
    log_error "Tests Failed: $TESTS_FAILED"
else
    echo -e "${GREEN}Tests Failed: $TESTS_FAILED${NC}"
fi
echo "=========================================="

if [ $TESTS_FAILED -eq 0 ]; then
    log_success "All smoke tests passed!"
    exit 0
else
    log_error "Some smoke tests failed"
    exit 1
fi
