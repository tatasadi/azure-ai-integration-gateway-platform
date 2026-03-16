#!/bin/bash

################################################################################
# Azure AI Integration Gateway - Validation Script
################################################################################
# This script validates the Terraform configuration and APIM policies
#
# Usage: ./validate.sh
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

# Track validation results
VALIDATION_PASSED=true

log_info "Starting validation..."

# Navigate to script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."

# Check Terraform installation
log_info "Checking Terraform installation..."
if ! command -v terraform &> /dev/null; then
    log_error "Terraform is not installed"
    VALIDATION_PASSED=false
else
    TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
    log_success "Terraform installed: v$TERRAFORM_VERSION"
fi

# Check Azure CLI installation
log_info "Checking Azure CLI installation..."
if ! command -v az &> /dev/null; then
    log_error "Azure CLI is not installed"
    VALIDATION_PASSED=false
else
    AZ_VERSION=$(az version -o json 2>/dev/null | grep -o '"azure-cli": "[^"]*' | cut -d'"' -f4 || echo "unknown")
    log_success "Azure CLI installed: v$AZ_VERSION"
fi

# Validate Terraform Configuration
log_info "Validating Terraform configuration..."
cd "$PROJECT_ROOT/terraform"

terraform init -backend=false > /dev/null 2>&1

if terraform validate; then
    log_success "Terraform configuration is valid"
else
    log_error "Terraform validation failed"
    VALIDATION_PASSED=false
fi

# Check Terraform formatting
log_info "Checking Terraform formatting..."
if terraform fmt -check -recursive > /dev/null 2>&1; then
    log_success "Terraform files are properly formatted"
else
    log_warning "Terraform files are not properly formatted. Run 'terraform fmt -recursive' to fix."
fi

# Validate APIM Policy XML files
log_info "Validating APIM policy XML files..."

XML_FILES_VALID=true

for xml_file in "$PROJECT_ROOT/apim-policies"/**/*.xml; do
    if [ -f "$xml_file" ]; then
        # Basic XML validation using xmllint if available
        if command -v xmllint &> /dev/null; then
            if xmllint --noout "$xml_file" 2>/dev/null; then
                log_success "Valid XML: $(basename $xml_file)"
            else
                log_error "Invalid XML: $xml_file"
                XML_FILES_VALID=false
                VALIDATION_PASSED=false
            fi
        else
            log_warning "xmllint not found. Skipping XML validation for $(basename $xml_file)"
        fi
    fi
done

if [ "$XML_FILES_VALID" = true ] && command -v xmllint &> /dev/null; then
    log_success "All APIM policy XML files are valid"
fi

# Check required files
log_info "Checking required files..."

REQUIRED_FILES=(
    "terraform/main.tf"
    "terraform/variables.tf"
    "terraform/outputs.tf"
    "apim-policies/global/base-policy.xml"
    "apim-policies/operations/summarize-policy.xml"
    "apim-policies/operations/extract-policy.xml"
    "docs/architecture.md"
    "docs/api-design.md"
    "README.md"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        log_success "Found: $file"
    else
        log_error "Missing: $file"
        VALIDATION_PASSED=false
    fi
done

# Check Terraform modules
log_info "Checking Terraform modules..."

REQUIRED_MODULES=(
    "terraform/modules/resource-group"
    "terraform/modules/managed-identity"
    "terraform/modules/key-vault"
    "terraform/modules/monitoring"
    "terraform/modules/ai-foundry"
    "terraform/modules/api-management"
)

for module in "${REQUIRED_MODULES[@]}"; do
    if [ -d "$PROJECT_ROOT/$module" ]; then
        if [ -f "$PROJECT_ROOT/$module/main.tf" ]; then
            log_success "Found module: $(basename $module)"
        else
            log_error "Module missing main.tf: $module"
            VALIDATION_PASSED=false
        fi
    else
        log_error "Missing module: $module"
        VALIDATION_PASSED=false
    fi
done

# Summary
echo ""
echo "=========================================="
if [ "$VALIDATION_PASSED" = true ]; then
    log_success "All validations passed!"
    echo "=========================================="
    exit 0
else
    log_error "Validation failed. Please fix the errors above."
    echo "=========================================="
    exit 1
fi
