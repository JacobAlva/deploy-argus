#!/bin/bash
# Quick validation script for Argus Agent deployment
# Usage: ./scripts/quick-validate.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

echo "🚀 Argus Agent Deployment - Quick Validation"
echo "=============================================="

# Check AWS CLI
if command -v aws &> /dev/null; then
    print_success "AWS CLI is installed"
    
    if aws sts get-caller-identity &> /dev/null; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        print_success "AWS credentials configured (Account: $ACCOUNT_ID)"
    else
        print_error "AWS credentials not configured. Run: aws configure"
        exit 1
    fi
else
    print_error "AWS CLI not found. Install from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check Terraform
if command -v terraform &> /dev/null; then
    TF_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
    print_success "Terraform is installed (Version: $TF_VERSION)"
    
    # Check version >= 1.5.0
    if printf '%s\n1.5.0\n' "$TF_VERSION" | sort -V | head -n1 | grep -q "^1.5.0$"; then
        print_success "Terraform version is compatible"
    else
        print_warning "Terraform version $TF_VERSION may be incompatible (required: >= 1.5.0)"
    fi
else
    print_error "Terraform not found. Install from: https://www.terraform.io/downloads"
    exit 1
fi

# Check configuration file
if [ -f "terraform.tfvars" ]; then
    print_success "terraform.tfvars configuration file found"
    
    # Check required variables
    if grep -q "customer_name.*=" terraform.tfvars && \
       grep -q "agent_api_key.*=" terraform.tfvars; then
        print_success "Required configuration variables present"
    else
        print_warning "Missing required variables in terraform.tfvars"
        print_info "Required: customer_name, agent_api_key"
    fi
else
    print_warning "terraform.tfvars not found"
    print_info "Copy terraform.tfvars.example to terraform.tfvars and configure"
fi

# Check AWS permissions (basic)
print_info "Checking AWS permissions..."
REGION=$(aws configure get region || echo "us-east-1")

if aws ec2 describe-regions --region "$REGION" &> /dev/null; then
    print_success "EC2 permissions OK"
else
    print_error "Missing EC2 permissions"
    exit 1
fi

if aws iam list-roles --max-items 1 &> /dev/null; then
    print_success "IAM permissions OK"
else
    print_warning "Limited IAM permissions - deployment may require additional privileges"
fi

echo ""
print_success "✨ Environment validation completed successfully!"
echo ""
print_info "Next steps:"
echo "1. Configure terraform.tfvars with your values"
echo "2. Run: terraform init"  
echo "3. Run: terraform plan"
echo "4. Run: terraform apply"