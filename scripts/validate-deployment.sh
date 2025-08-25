#!/bin/bash
# Argus Agent Deployment Validation Script
# Comprehensive validation of AWS account readiness and deployment requirements
# Usage: ./validate-deployment.sh [options]

set -e

# Script configuration
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="Argus Deployment Validator"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Validation results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Configuration
AWS_REGION="us-east-1"
VERBOSE="false"
OUTPUT_FILE=""
CHECK_PERMISSIONS="true"
CHECK_RESOURCES="true"
CHECK_NETWORK="true"

# Functions for output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_CHECKS++))
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNING_CHECKS++))
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_CHECKS++))
}

run_check() {
    local check_name="$1"
    local description="$2"
    shift 2
    
    ((TOTAL_CHECKS++))
    
    print_info "Checking: $description"
    
    if [ "$VERBOSE" = "true" ]; then
        print_info "Running: $check_name"
    fi
    
    if "$@"; then
        print_success "$description"
        return 0
    else
        print_error "$description"
        return 1
    fi
}

# Check if required tools are installed
check_prerequisites() {
    local tools=("aws" "terraform" "jq" "curl" "openssl")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -eq 0 ]; then
        return 0
    else
        print_error "Missing tools: ${missing_tools[*]}"
        return 1
    fi
}

# Validate AWS CLI configuration
check_aws_cli() {
    if ! aws sts get-caller-identity &> /dev/null; then
        return 1
    fi
    
    # Check if region is configured
    local configured_region=$(aws configure get region 2>/dev/null || echo "")
    if [ -z "$configured_region" ] && [ -z "$AWS_DEFAULT_REGION" ]; then
        print_warning "No default region configured"
    fi
    
    return 0
}

# Check AWS account information
check_aws_account() {
    local account_id
    local user_arn
    
    account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || return 1
    user_arn=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null) || return 1
    
    if [ "$VERBOSE" = "true" ]; then
        print_info "Account ID: $account_id"
        print_info "User/Role ARN: $user_arn"
    fi
    
    # Check if using root account (not recommended)
    if [[ "$user_arn" == *":root" ]]; then
        print_warning "Using root account - not recommended for deployment"
    fi
    
    return 0
}

# Check Terraform version
check_terraform_version() {
    local version
    version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null) || return 1
    
    # Check if version is >= 1.5
    if printf '%s\n1.5.0\n' "$version" | sort -V | head -n1 | grep -q "^1.5.0$"; then
        if [ "$VERBOSE" = "true" ]; then
            print_info "Terraform version: $version"
        fi
        return 0
    else
        print_error "Terraform version $version < 1.5.0 (required)"
        return 1
    fi
}

# Check EC2 permissions
check_ec2_permissions() {
    local required_actions=(
        "describe-regions"
        "describe-availability-zones"
        "describe-vpcs"
        "describe-subnets"
        "describe-security-groups"
        "describe-instances"
    )
    
    for action in "${required_actions[@]}"; do
        if ! aws ec2 "$action" --region "$AWS_REGION" &> /dev/null; then
            return 1
        fi
    done
    
    return 0
}

# Check IAM permissions
check_iam_permissions() {
    local iam_checks=(
        "get-user"
        "list-roles"
        "list-policies"
    )
    
    local iam_failures=0
    
    for check in "${iam_checks[@]}"; do
        if ! aws iam "$check" --max-items 1 &> /dev/null; then
            ((iam_failures++))
        fi
    done
    
    # Allow some IAM failures (user might have limited permissions)
    if [ $iam_failures -ge ${#iam_checks[@]} ]; then
        print_warning "Limited IAM permissions - deployment may require additional privileges"
        return 0  # Don't fail completely
    fi
    
    return 0
}

# Check Secrets Manager permissions
check_secrets_permissions() {
    if ! aws secretsmanager list-secrets --max-results 1 --region "$AWS_REGION" &> /dev/null; then
        return 1
    fi
    return 0
}

# Check CloudWatch permissions
check_cloudwatch_permissions() {
    if ! aws logs describe-log-groups --limit 1 --region "$AWS_REGION" &> /dev/null; then
        return 1
    fi
    return 0
}

# Check VPC resources and limits
check_vpc_resources() {
    local vpc_count
    local subnet_count
    
    # Check VPC limit
    vpc_count=$(aws ec2 describe-vpcs --region "$AWS_REGION" --query 'length(Vpcs)' --output text) || return 1
    
    if [ "$vpc_count" -ge 5 ]; then
        print_warning "High VPC count ($vpc_count) - approaching default limit"
    fi
    
    # Check if default VPC exists
    local default_vpc
    default_vpc=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)
    
    if [ "$default_vpc" = "None" ] || [ -z "$default_vpc" ]; then
        print_warning "No default VPC found - will create new VPC"
    else
        if [ "$VERBOSE" = "true" ]; then
            print_info "Default VPC: $default_vpc"
        fi
    fi
    
    return 0
}

# Check EC2 instance limits
check_ec2_limits() {
    local running_instances
    
    running_instances=$(aws ec2 describe-instances --region "$AWS_REGION" \
        --filters "Name=instance-state-name,Values=running" \
        --query 'length(Reservations[].Instances[])' --output text) || return 1
    
    if [ "$running_instances" -gt 15 ]; then
        print_warning "High number of running instances ($running_instances) - check service limits"
    fi
    
    return 0
}

# Check network connectivity to Argus backend
check_backend_connectivity() {
    local backend_url="https://api.argus-dspm.com"
    
    if ! curl -s --connect-timeout 10 "$backend_url/health" &> /dev/null; then
        # Try alternative check
        if ! curl -s --connect-timeout 10 -I "$backend_url" &> /dev/null; then
            print_warning "Cannot reach Argus backend - network connectivity issue"
            return 0  # Don't fail deployment for this
        fi
    fi
    
    return 0
}

# Check Docker Hub connectivity (for container pulls)
check_docker_connectivity() {
    if ! curl -s --connect-timeout 10 -I "https://registry-1.docker.io" &> /dev/null; then
        print_warning "Cannot reach Docker Hub - container image pulls may fail"
        return 0  # Don't fail deployment
    fi
    
    return 0
}

# Check AWS service endpoints
check_aws_endpoints() {
    local services=("ec2" "iam" "secretsmanager" "logs")
    
    for service in "${services[@]}"; do
        local endpoint="https://${service}.${AWS_REGION}.amazonaws.com"
        if ! curl -s --connect-timeout 5 -I "$endpoint" &> /dev/null; then
            print_warning "Cannot reach $service endpoint in $AWS_REGION"
        fi
    done
    
    return 0
}

# Check for existing Argus resources
check_existing_resources() {
    local existing_roles
    local existing_policies
    
    # Check for existing Argus IAM roles
    existing_roles=$(aws iam list-roles --query 'Roles[?contains(RoleName, `Argus`) || contains(RoleName, `argus`)].RoleName' --output text 2>/dev/null || echo "")
    
    if [ -n "$existing_roles" ]; then
        print_warning "Existing Argus-related IAM roles found: $existing_roles"
    fi
    
    # Check for existing security groups
    local existing_sgs
    existing_sgs=$(aws ec2 describe-security-groups --region "$AWS_REGION" \
        --filters "Name=group-name,Values=*argus*" \
        --query 'SecurityGroups[].GroupName' --output text 2>/dev/null || echo "")
    
    if [ -n "$existing_sgs" ]; then
        print_warning "Existing Argus-related security groups found: $existing_sgs"
    fi
    
    return 0
}

# Generate validation report
generate_report() {
    local report_content
    
    report_content=$(cat << EOF
Argus Agent Deployment Validation Report
========================================

Generated: $(date)
AWS Region: $AWS_REGION
Script Version: $SCRIPT_VERSION

Summary:
- Total Checks: $TOTAL_CHECKS
- Passed: $PASSED_CHECKS
- Warnings: $WARNING_CHECKS
- Failed: $FAILED_CHECKS

Status: $( [ $FAILED_CHECKS -eq 0 ] && echo "READY FOR DEPLOYMENT" || echo "ISSUES FOUND - REVIEW REQUIRED" )

EOF
)

    if [ -n "$OUTPUT_FILE" ]; then
        echo "$report_content" > "$OUTPUT_FILE"
        print_info "Validation report saved to: $OUTPUT_FILE"
    else
        echo
        echo "$report_content"
    fi
}

# Show usage
show_usage() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Usage: $0 [options]

Options:
    --region <region>           AWS region to validate (default: us-east-1)
    --output <file>            Save validation report to file
    --verbose                  Enable verbose output
    --skip-permissions         Skip IAM permission checks
    --skip-resources           Skip resource limit checks
    --skip-network            Skip network connectivity checks
    --help                     Show this help message

Examples:
    # Basic validation
    $0 --region us-west-2

    # Verbose validation with report
    $0 --region us-east-1 --verbose --output validation-report.txt

    # Quick validation (skip network checks)
    $0 --skip-network --skip-resources

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE="true"
            shift
            ;;
        --skip-permissions)
            CHECK_PERMISSIONS="false"
            shift
            ;;
        --skip-resources)
            CHECK_RESOURCES="false"
            shift
            ;;
        --skip-network)
            CHECK_NETWORK="false"
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

# Main execution
print_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
print_info "Validating AWS region: $AWS_REGION"
echo

# Run validation checks
run_check "check_prerequisites" "Required tools installation" check_prerequisites
run_check "check_aws_cli" "AWS CLI configuration" check_aws_cli
run_check "check_aws_account" "AWS account access" check_aws_account
run_check "check_terraform_version" "Terraform version compatibility" check_terraform_version

if [ "$CHECK_PERMISSIONS" = "true" ]; then
    run_check "check_ec2_permissions" "EC2 service permissions" check_ec2_permissions
    run_check "check_iam_permissions" "IAM service permissions" check_iam_permissions
    run_check "check_secrets_permissions" "Secrets Manager permissions" check_secrets_permissions
    run_check "check_cloudwatch_permissions" "CloudWatch Logs permissions" check_cloudwatch_permissions
fi

if [ "$CHECK_RESOURCES" = "true" ]; then
    run_check "check_vpc_resources" "VPC resources and limits" check_vpc_resources
    run_check "check_ec2_limits" "EC2 instance limits" check_ec2_limits
    run_check "check_existing_resources" "Existing Argus resources" check_existing_resources
fi

if [ "$CHECK_NETWORK" = "true" ]; then
    run_check "check_backend_connectivity" "Argus backend connectivity" check_backend_connectivity
    run_check "check_docker_connectivity" "Container registry connectivity" check_docker_connectivity
    run_check "check_aws_endpoints" "AWS service endpoints" check_aws_endpoints
fi

echo
generate_report

# Exit with appropriate code
if [ $FAILED_CHECKS -eq 0 ]; then
    print_success "Validation completed successfully - ready for deployment"
    exit 0
else
    print_error "Validation failed with $FAILED_CHECKS issues - review and resolve before deployment"
    exit 1
fi