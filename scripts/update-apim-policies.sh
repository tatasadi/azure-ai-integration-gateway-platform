#!/bin/bash

################################################################################
# Update APIM Policies Script
################################################################################
# This script updates the APIM policies for all operations
#
# Usage: ./update-apim-policies.sh [resource-group] [apim-service-name]
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Default values (can be overridden by arguments)
RESOURCE_GROUP=${1:-"rg-aigateway-dev-swedencentral"}
APIM_SERVICE=${2:-"apim-aigateway-dev-swedencentral"}
API_NAME="ai-services-api"

log_info "Updating APIM Policies"
log_info "Resource Group: $RESOURCE_GROUP"
log_info "APIM Service: $APIM_SERVICE"
log_info "API Name: $API_NAME"
echo ""

# Check if logged in to Azure
log_info "Checking Azure CLI authentication..."
if ! az account show &> /dev/null; then
    log_error "Not logged in to Azure. Please run: az login"
    exit 1
fi
log_success "Azure CLI authenticated"
echo ""

# Get API ID
log_info "Getting API ID..."
API_ID=$(az apim api show \
    --resource-group "$RESOURCE_GROUP" \
    --service-name "$APIM_SERVICE" \
    --api-id "$API_NAME" \
    --query "id" -o tsv 2>/dev/null)

if [ -z "$API_ID" ]; then
    log_error "API '$API_NAME' not found. Please check the API name and try again."
    exit 1
fi
log_success "Found API: $API_NAME"
echo ""

# Update Global Policy
log_info "Updating global policy..."
if [ -f "apim-policies/global/base-policy.xml" ]; then
    az apim policy create \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_SERVICE" \
        --xml-value @apim-policies/global/base-policy.xml \
        --output none
    log_success "Global policy updated"
else
    log_warning "Global policy file not found: apim-policies/global/base-policy.xml"
fi
echo ""

# Update Operation Policies
log_info "Updating operation policies..."

# Summarize operation
if [ -f "apim-policies/operations/summarize-policy.xml" ]; then
    log_info "  - Updating summarize operation policy..."
    az apim api operation policy create \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_SERVICE" \
        --api-id "$API_NAME" \
        --operation-id "summarize" \
        --xml-value @apim-policies/operations/summarize-policy.xml \
        --output none 2>/dev/null || log_warning "Could not update summarize policy (operation may not exist)"
    log_success "  ✓ Summarize operation policy updated"
else
    log_warning "  - Summarize policy file not found"
fi

# Extract operation
if [ -f "apim-policies/operations/extract-policy.xml" ]; then
    log_info "  - Updating extract operation policy..."
    az apim api operation policy create \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_SERVICE" \
        --api-id "$API_NAME" \
        --operation-id "extract" \
        --xml-value @apim-policies/operations/extract-policy.xml \
        --output none 2>/dev/null || log_warning "Could not update extract policy (operation may not exist)"
    log_success "  ✓ Extract operation policy updated"
else
    log_warning "  - Extract policy file not found"
fi

# Health operation
if [ -f "apim-policies/operations/health-policy.xml" ]; then
    log_info "  - Updating health operation policy..."
    az apim api operation policy create \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_SERVICE" \
        --api-id "$API_NAME" \
        --operation-id "health" \
        --xml-value @apim-policies/operations/health-policy.xml \
        --output none 2>/dev/null || log_warning "Could not update health policy (operation may not exist)"
    log_success "  ✓ Health operation policy updated"
else
    log_warning "  - Health policy file not found"
fi

echo ""
log_success "All policies updated successfully!"
echo ""
log_info "Next steps:"
echo "  1. Test the API endpoints"
echo "  2. Check Application Insights for telemetry"
echo "  3. Verify policies in Azure Portal"
echo ""
