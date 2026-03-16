#!/bin/bash

################################################################################
# Azure AI Integration Gateway - Smoke Test Script
################################################################################
# This script performs basic smoke tests on the deployed AI Gateway
#
# Usage: ./smoke-test.sh <apim-gateway-url> <subscription-key>
#   apim-gateway-url: The URL of the APIM gateway (e.g., https://apim-aigateway-dev.azure-api.net)
#   subscription-key: The APIM subscription key for authentication
#
# Example: ./smoke-test.sh https://apim-aigateway-dev.azure-api.net "your-subscription-key"
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check arguments
if [ $# -lt 2 ]; then
    log_error "Missing required arguments"
    echo "Usage: $0 <apim-gateway-url> <subscription-key>"
    echo ""
    echo "Example:"
    echo "  $0 https://apim-aigateway-dev.azure-api.net \"your-subscription-key\""
    exit 1
fi

GATEWAY_URL=$1
SUBSCRIPTION_KEY=$2

# Remove trailing slash from URL if present
GATEWAY_URL=${GATEWAY_URL%/}

log_info "Starting smoke tests for AI Gateway"
log_info "Gateway URL: $GATEWAY_URL"
echo ""

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Health Check Endpoint
log_info "Test 1: Health Check Endpoint"
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$GATEWAY_URL/ai/health" || echo "000")

HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$HEALTH_RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "Health check passed (HTTP 200)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_error "Health check failed (HTTP $HTTP_CODE)"
    log_error "Response: $RESPONSE_BODY"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 2: Summarize Endpoint - Basic Test
log_info "Test 2: Summarize Endpoint - Basic Test"
SUMMARIZE_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    -d '{"text":"This is a test document for summarization. The AI Gateway should process this request and return a summary."}' \
    "$GATEWAY_URL/ai/summarize" 2>/dev/null || echo "000")

HTTP_CODE=$(echo "$SUMMARIZE_RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$SUMMARIZE_RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "Summarize endpoint test passed (HTTP 200)"
    log_info "Response: $RESPONSE_BODY"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_error "Summarize endpoint test failed (HTTP $HTTP_CODE)"
    log_error "Response: $RESPONSE_BODY"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 3: Extract Endpoint - Basic Test
log_info "Test 3: Extract Endpoint - Basic Test"
EXTRACT_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    -d '{"text":"John Doe works at Microsoft in Seattle. His email is john.doe@example.com.","schema":{"type":"object","properties":{"name":{"type":"string"},"company":{"type":"string"},"location":{"type":"string"},"email":{"type":"string"}}}}' \
    "$GATEWAY_URL/ai/extract" 2>/dev/null || echo "000")

HTTP_CODE=$(echo "$EXTRACT_RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$EXTRACT_RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "Extract endpoint test passed (HTTP 200)"
    log_info "Response: $RESPONSE_BODY"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_error "Extract endpoint test failed (HTTP $HTTP_CODE)"
    log_error "Response: $RESPONSE_BODY"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 4: Authentication - Invalid Subscription Key
log_info "Test 4: Authentication - Invalid Subscription Key Test"
AUTH_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Ocp-Apim-Subscription-Key: invalid-key-12345" \
    "$GATEWAY_URL/ai/health" 2>/dev/null || echo "000")

HTTP_CODE=$(echo "$AUTH_RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
    log_success "Authentication test passed - Invalid key rejected (HTTP $HTTP_CODE)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_error "Authentication test failed - Expected 401/403, got HTTP $HTTP_CODE"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 5: Missing Subscription Key
log_info "Test 5: Missing Subscription Key Test"
MISSING_KEY_RESPONSE=$(curl -s -w "\n%{http_code}" \
    "$GATEWAY_URL/ai/health" 2>/dev/null || echo "000")

HTTP_CODE=$(echo "$MISSING_KEY_RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
    log_success "Missing key test passed - Request rejected (HTTP $HTTP_CODE)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_error "Missing key test failed - Expected 401/403, got HTTP $HTTP_CODE"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Summary
echo "=========================================="
echo "Smoke Test Summary"
echo "=========================================="
log_success "Tests Passed: $TESTS_PASSED"
if [ $TESTS_FAILED -gt 0 ]; then
    log_error "Tests Failed: $TESTS_FAILED"
else
    echo -e "${GREEN}Tests Failed: $TESTS_FAILED${NC}"
fi
echo "=========================================="
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    log_success "All smoke tests passed!"
    exit 0
else
    log_error "Some smoke tests failed. Please investigate."
    exit 1
fi
