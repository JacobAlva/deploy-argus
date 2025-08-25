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
        --help)
            echo "Usage: $0 [--region <region>] [--output <file>] [--verbose] [--help]"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
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