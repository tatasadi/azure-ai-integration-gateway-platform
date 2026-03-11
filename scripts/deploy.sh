#!/bin/bash

################################################################################
# Azure AI Integration Gateway - Deployment Script
################################################################################
# This script deploys the AI Gateway infrastructure using Terraform
#
# Usage: ./deploy.sh <environment> [--auto-approve]
#   environment: dev, staging, or prod
#   --auto-approve: Skip approval prompts (use with caution)
#
# Example: ./deploy.sh dev
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

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

# Check if environment argument is provided
if [ $# -lt 1 ]; then
    log_error "Environment argument is required"
    echo "Usage: $0 <environment> [--auto-approve]"
    echo "  environment: dev, staging, or prod"
    exit 1
fi

ENVIRONMENT=$1
AUTO_APPROVE=""

if [ $# -eq 2 ] && [ "$2" == "--auto-approve" ]; then
    AUTO_APPROVE="-auto-approve"
    log_warning "Auto-approve enabled. Deployment will proceed without confirmation."
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT"
    echo "Valid environments: dev, staging, prod"
    exit 1
fi

log_info "Starting deployment for environment: $ENVIRONMENT"

# Check prerequisites
log_info "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    log_error "Terraform is not installed. Please install Terraform first."
    exit 1
fi

if ! command -v az &> /dev/null; then
    log_error "Azure CLI is not installed. Please install Azure CLI first."
    exit 1
fi

log_success "Prerequisites check passed"

# Check Azure login
log_info "Checking Azure login status..."
if ! az account show &> /dev/null; then
    log_error "Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
log_success "Logged in to Azure subscription: $SUBSCRIPTION"

# Navigate to terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

cd "$TERRAFORM_DIR"
log_info "Working directory: $(pwd)"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    log_warning "terraform.tfvars not found. Copying from terraform.tfvars.example"
    if [ -f "terraform.tfvars.example" ]; then
        cp terraform.tfvars.example terraform.tfvars
        log_warning "Please edit terraform.tfvars with your configuration before continuing"
        exit 1
    else
        log_error "terraform.tfvars.example not found"
        exit 1
    fi
fi

# Terraform Init
log_info "Initializing Terraform..."
terraform init -upgrade

# Terraform Validate
log_info "Validating Terraform configuration..."
terraform validate

if [ $? -ne 0 ]; then
    log_error "Terraform validation failed"
    exit 1
fi

log_success "Terraform validation passed"

# Terraform Format Check
log_info "Checking Terraform formatting..."
if ! terraform fmt -check -recursive; then
    log_warning "Terraform files are not properly formatted. Run 'terraform fmt -recursive' to fix."
fi

# Terraform Plan
log_info "Creating Terraform plan..."
terraform plan -var="environment=$ENVIRONMENT" -out="tfplan-$ENVIRONMENT"

if [ $? -ne 0 ]; then
    log_error "Terraform plan failed"
    exit 1
fi

log_success "Terraform plan created successfully"

# Terraform Apply
if [ -z "$AUTO_APPROVE" ]; then
    echo ""
    log_warning "Ready to apply changes to $ENVIRONMENT environment"
    read -p "Do you want to proceed? (yes/no): " CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
        log_info "Deployment cancelled by user"
        rm -f "tfplan-$ENVIRONMENT"
        exit 0
    fi
fi

log_info "Applying Terraform changes..."
terraform apply $AUTO_APPROVE "tfplan-$ENVIRONMENT"

if [ $? -ne 0 ]; then
    log_error "Terraform apply failed"
    exit 1
fi

# Clean up plan file
rm -f "tfplan-$ENVIRONMENT"

log_success "Deployment completed successfully!"

# Display outputs
echo ""
log_info "Deployment outputs:"
terraform output

echo ""
log_success "==========================================="
log_success "  AI Gateway deployed to $ENVIRONMENT"
log_success "==========================================="
echo ""
log_info "Next steps:"
echo "  1. Access the Developer Portal to obtain your subscription key"
echo "  2. Test the health endpoint"
echo "  3. Review the API documentation at docs/api-design.md"
echo ""
