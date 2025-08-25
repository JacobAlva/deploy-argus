#!/bin/bash
# Argus Agent Customer Onboarding Script
# Automated deployment workflow for new customer environments
# Usage: ./customer-onboarding.sh --customer-name <name> --region <region> [options]

set -e

# Script version and metadata
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="Argus Customer Onboarding"
ARGUS_BACKEND_URL="https://api.argus-dspm.com"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CUSTOMER_NAME=""
AWS_REGION="us-east-1"
INSTANCE_TYPE="t3.medium"
ENVIRONMENT="prod"
ENABLE_MONITORING="true"
ENABLE_SSH="false"
AUTO_SCALING="false"
TERRAFORM_STATE_BUCKET=""
DRY_RUN="false"
VERBOSE="false"

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Usage: $0 --customer-name <name> [options]

Required Arguments:
    --customer-name <name>      Customer name (alphanumeric and hyphens only)

Optional Arguments:
    --region <region>           AWS region (default: us-east-1)
    --instance-type <type>      EC2 instance type (default: t3.medium)
    --environment <env>         Environment (dev/staging/prod, default: prod)
    --backend-url <url>         Argus backend URL (default: $ARGUS_BACKEND_URL)
    --state-bucket <bucket>     S3 bucket for Terraform state storage
    --enable-ssh                Enable SSH access for debugging
    --enable-autoscaling        Enable auto-scaling group
    --dry-run                   Show what would be deployed without executing
    --verbose                   Enable verbose logging
    --help                      Show this help message

Examples:
    # Basic deployment
    $0 --customer-name acme-corp --region us-west-2

    # Production deployment with monitoring
    $0 --customer-name acme-corp --region us-east-1 --instance-type t3.large --environment prod

    # Development deployment with SSH access
    $0 --customer-name acme-dev --environment dev --enable-ssh --dry-run

EOF
}

# Function to validate prerequisites
validate_prerequisites() {
    print_info "Validating prerequisites..."
    
    # Check required tools
    local missing_tools=()
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws-cli")
    fi
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Please install the missing tools and try again"
        exit 1
    fi
    
    # Validate AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or invalid"
        print_info "Please run 'aws configure' or set AWS environment variables"
        exit 1
    fi
    
    # Get AWS account information
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    
    print_success "Prerequisites validated"
    print_info "AWS Account ID: $AWS_ACCOUNT_ID"
    print_info "AWS User/Role: $AWS_USER_ARN"
}

# Function to validate AWS permissions
validate_permissions() {
    print_info "Validating AWS permissions..."
    
    local required_permissions=(
        "ec2:DescribeInstances"
        "ec2:RunInstances"
        "ec2:CreateSecurityGroup"
        "iam:CreateRole"
        "iam:CreatePolicy"
        "iam:AttachRolePolicy"
        "secretsmanager:CreateSecret"
        "logs:CreateLogGroup"
        "sns:CreateTopic"
    )
    
    # Test key permissions (simplified check)
    if ! aws ec2 describe-regions --region $AWS_REGION &> /dev/null; then
        print_error "Insufficient EC2 permissions for region $AWS_REGION"
        exit 1
    fi
    
    if ! aws iam get-user &> /dev/null && ! aws iam get-role --role-name $(basename $AWS_USER_ARN) &> /dev/null; then
        print_warning "Limited IAM permissions detected - deployment may fail"
    fi
    
    print_success "AWS permissions validated"
}

# Function to generate API key via Argus backend
generate_api_key() {
    print_info "Generating Argus agent API key..."
    
    # For now, generate a secure random key
    # TODO: Replace with actual backend API call
    API_KEY=$(openssl rand -hex 32)
    
    if [ -z "$API_KEY" ]; then
        print_error "Failed to generate API key"
        exit 1
    fi
    
    print_success "API key generated successfully"
    
    if [ "$VERBOSE" = "true" ]; then
        print_info "API Key: ${API_KEY:0:8}..."
    fi
}

# Function to prepare Terraform configuration
prepare_terraform_config() {
    print_info "Preparing Terraform configuration..."
    
    # Create deployment directory
    DEPLOY_DIR="deployments/${CUSTOMER_NAME}-${AWS_REGION}"
    mkdir -p "$DEPLOY_DIR"
    
    # Create main.tf
    cat > "$DEPLOY_DIR/main.tf" << EOF
# Argus Agent Deployment for ${CUSTOMER_NAME}
# Generated by: $SCRIPT_NAME v$SCRIPT_VERSION
# Generated on: $(date)

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
$(if [ -n "$TERRAFORM_STATE_BUCKET" ]; then
cat << EOT
  
  backend "s3" {
    bucket = "$TERRAFORM_STATE_BUCKET"
    key    = "argus-agent/${CUSTOMER_NAME}-${AWS_REGION}/terraform.tfstate"
    region = "$AWS_REGION"
  }
EOT
fi)
}

provider "aws" {
  region = var.aws_region
}

module "argus_agent_ec2" {
  source = "../../terraform/modules/argus-agent-ec2"
  
  # Required variables
  customer_name     = var.customer_name
  agent_api_key     = var.agent_api_key
  argus_backend_url = var.argus_backend_url
  
  # AWS Configuration
  aws_region = var.aws_region
  
  # Instance Configuration
  instance_type    = var.instance_type
  environment      = var.environment
  enable_ssh_access = var.enable_ssh_access
  auto_scaling_enabled = var.auto_scaling_enabled
  
  # Monitoring
  enable_detailed_monitoring = var.enable_detailed_monitoring
  
  # Tags
  additional_tags = var.additional_tags
}

# Outputs
output "agent_instance_id" {
  description = "EC2 instance ID of the deployed agent"
  value       = module.argus_agent_ec2.agent_instance_id
}

output "agent_role_arn" {
  description = "ARN of the IAM role assigned to the agent"
  value       = module.argus_agent_ec2.agent_role_arn
}

output "external_id" {
  description = "External ID for cross-account role assumption"
  value       = module.argus_agent_ec2.external_id
  sensitive   = true
}

output "agent_connection_info" {
  description = "Information needed for backend agent registration"
  value       = module.argus_agent_ec2.agent_connection_info
  sensitive   = true
}
EOF

    # Create variables.tf
    cat > "$DEPLOY_DIR/variables.tf" << EOF
# Variables for Argus Agent Deployment

variable "customer_name" {
  description = "Customer name for resource naming"
  type        = string
  default     = "$CUSTOMER_NAME"
}

variable "agent_api_key" {
  description = "Argus agent API key"
  type        = string
  sensitive   = true
}

variable "argus_backend_url" {
  description = "Argus backend URL"
  type        = string
  default     = "$ARGUS_BACKEND_URL"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "$AWS_REGION"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "$INSTANCE_TYPE"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "$ENVIRONMENT"
}

variable "enable_ssh_access" {
  description = "Enable SSH access"
  type        = bool
  default     = $([[ "$ENABLE_SSH" == "true" ]] && echo "true" || echo "false")
}

variable "auto_scaling_enabled" {
  description = "Enable auto-scaling"
  type        = bool
  default     = $([[ "$AUTO_SCALING" == "true" ]] && echo "true" || echo "false")
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = $([[ "$ENABLE_MONITORING" == "true" ]] && echo "true" || echo "false")
}

variable "additional_tags" {
  description = "Additional tags"
  type        = map(string)
  default = {
    DeployedBy    = "argus-onboarding-script"
    DeployedAt    = "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    ScriptVersion = "$SCRIPT_VERSION"
  }
}
EOF

    # Create terraform.tfvars
    cat > "$DEPLOY_DIR/terraform.tfvars" << EOF
# Terraform variables for ${CUSTOMER_NAME}
# Generated by: $SCRIPT_NAME v$SCRIPT_VERSION

agent_api_key = "$API_KEY"
EOF
    
    chmod 600 "$DEPLOY_DIR/terraform.tfvars"  # Protect API key file
    
    print_success "Terraform configuration prepared in: $DEPLOY_DIR"
}

# Function to run Terraform deployment
run_terraform_deployment() {
    print_info "Running Terraform deployment..."
    
    cd "$DEPLOY_DIR"
    
    # Initialize Terraform
    print_info "Initializing Terraform..."
    if [ "$VERBOSE" = "true" ]; then
        terraform init
    else
        terraform init > /dev/null
    fi
    
    # Plan deployment
    print_info "Planning deployment..."
    terraform plan -out=tfplan
    
    if [ "$DRY_RUN" = "true" ]; then
        print_warning "DRY RUN MODE - Deployment not executed"
        print_info "Terraform plan saved to: $(pwd)/tfplan"
        return 0
    fi
    
    # Apply deployment
    print_info "Applying deployment..."
    if terraform apply tfplan; then
        print_success "Terraform deployment completed successfully"
    else
        print_error "Terraform deployment failed"
        return 1
    fi
    
    cd - > /dev/null
}

# Function to validate deployment
validate_deployment() {
    print_info "Validating deployment..."
    
    cd "$DEPLOY_DIR"
    
    # Get deployment outputs
    INSTANCE_ID=$(terraform output -raw agent_instance_id 2>/dev/null || echo "")
    ROLE_ARN=$(terraform output -raw agent_role_arn 2>/dev/null || echo "")
    
    if [ -z "$INSTANCE_ID" ]; then
        print_error "Failed to retrieve instance ID from Terraform output"
        return 1
    fi
    
    print_info "Instance ID: $INSTANCE_ID"
    print_info "Role ARN: $ROLE_ARN"
    
    # Check instance status
    print_info "Checking instance status..."
    INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].State.Name' --output text)
    
    if [ "$INSTANCE_STATE" != "running" ]; then
        print_warning "Instance is not in running state: $INSTANCE_STATE"
        print_info "Waiting for instance to start..."
        aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION
    fi
    
    print_success "Instance is running"
    
    # Get instance IP for health check
    INSTANCE_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
    
    # Wait for agent to be healthy (this would require VPC access or bastion host in real deployment)
    print_info "Agent health check would require VPC access - skipping for now"
    print_info "Instance Private IP: $INSTANCE_IP"
    
    cd - > /dev/null
    
    print_success "Deployment validation completed"
}

# Function to generate deployment summary
generate_summary() {
    print_info "Generating deployment summary..."
    
    cd "$DEPLOY_DIR"
    
    # Create summary file
    cat > "deployment-summary.txt" << EOF
Argus Agent Deployment Summary
==============================

Customer: $CUSTOMER_NAME
Region: $AWS_REGION
Environment: $ENVIRONMENT
Deployed: $(date)
Script Version: $SCRIPT_VERSION

Instance Configuration:
- Type: $INSTANCE_TYPE
- Auto Scaling: $AUTO_SCALING
- SSH Access: $ENABLE_SSH
- Detailed Monitoring: $ENABLE_MONITORING

Terraform Outputs:
$(terraform output 2>/dev/null | grep -v "sensitive" || echo "Run 'terraform output' to see deployment outputs")

Next Steps:
1. Verify agent connectivity from Argus backend
2. Configure monitoring alerts if needed
3. Test scan job execution
4. Review security configuration

Support:
- Deployment directory: $(pwd)
- Terraform state: $(if [ -n "$TERRAFORM_STATE_BUCKET" ]; then echo "s3://$TERRAFORM_STATE_BUCKET/argus-agent/${CUSTOMER_NAME}-${AWS_REGION}/terraform.tfstate"; else echo "local"; fi)
EOF
    
    cd - > /dev/null
    
    print_success "Deployment summary saved to: $DEPLOY_DIR/deployment-summary.txt"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --customer-name)
            CUSTOMER_NAME="$2"
            shift 2
            ;;
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --instance-type)
            INSTANCE_TYPE="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --backend-url)
            ARGUS_BACKEND_URL="$2"
            shift 2
            ;;
        --state-bucket)
            TERRAFORM_STATE_BUCKET="$2"
            shift 2
            ;;
        --enable-ssh)
            ENABLE_SSH="true"
            shift
            ;;
        --enable-autoscaling)
            AUTO_SCALING="true"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --verbose)
            VERBOSE="true"
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$CUSTOMER_NAME" ]; then
    print_error "Customer name is required"
    show_usage
    exit 1
fi

# Validate customer name format
if ! [[ "$CUSTOMER_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    print_error "Customer name must contain only alphanumeric characters and hyphens"
    exit 1
fi

# Main execution
print_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
print_info "Customer: $CUSTOMER_NAME"
print_info "Region: $AWS_REGION"
print_info "Environment: $ENVIRONMENT"

if [ "$DRY_RUN" = "true" ]; then
    print_warning "DRY RUN MODE - No resources will be created"
fi

# Execute deployment steps
validate_prerequisites
validate_permissions
generate_api_key
prepare_terraform_config
run_terraform_deployment

if [ "$DRY_RUN" != "true" ]; then
    validate_deployment
    generate_summary
    
    print_success "Argus Agent deployment completed successfully!"
    print_info "Deployment directory: $DEPLOY_DIR"
    print_info "Review deployment-summary.txt for next steps"
else
    print_info "DRY RUN completed - review generated configuration in: $DEPLOY_DIR"
fi