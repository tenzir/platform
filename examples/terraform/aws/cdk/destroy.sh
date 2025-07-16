#!/bin/bash

# Tenzir Platform CDK Destruction Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DOMAIN_NAME=""
RANDOM_SUBDOMAIN="false"
TRUSTING_ROLE_ARN=""
PROFILE=""
REGION="eu-west-1"
FORCE="false"

# Function to print colored output
print_status() {
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
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --domain-name DOMAIN        Domain name (e.g., example.org) [REQUIRED]"
    echo "  -r, --random-subdomain          Enable random subdomain generation (default: false)"
    echo "  -t, --trusting-role-arn ARN     ARN of the trusting role [REQUIRED]"
    echo "  -p, --profile PROFILE           AWS profile to use"
    echo "  --region REGION                 AWS region (default: eu-west-1)"
    echo "  -f, --force                     Skip confirmation prompt"
    echo "  -h, --help                      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -d example.org -t arn:aws:iam::123456789012:role/TrustingRole"
    echo "  $0 -d example.org -r -t arn:aws:iam::123456789012:role/TrustingRole -f"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain-name)
            DOMAIN_NAME="$2"
            shift 2
            ;;
        -r|--random-subdomain)
            RANDOM_SUBDOMAIN="true"
            shift
            ;;
        -t|--trusting-role-arn)
            TRUSTING_ROLE_ARN="$2"
            shift 2
            ;;
        -p|--profile)
            PROFILE="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        -f|--force)
            FORCE="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$DOMAIN_NAME" ]]; then
    print_error "Domain name is required. Use -d or --domain-name"
    usage
    exit 1
fi

if [[ -z "$TRUSTING_ROLE_ARN" ]]; then
    print_error "Trusting role ARN is required. Use -t or --trusting-role-arn"
    usage
    exit 1
fi

# Set AWS profile if provided
if [[ -n "$PROFILE" ]]; then
    export AWS_PROFILE="$PROFILE"
    print_status "Using AWS profile: $PROFILE"
fi

# Set AWS region
export AWS_DEFAULT_REGION="$REGION"
export CDK_DEFAULT_REGION="$REGION"

print_warning "This will destroy the entire Tenzir Platform infrastructure!"
print_status "Domain: $DOMAIN_NAME"
print_status "Random subdomain: $RANDOM_SUBDOMAIN"
print_status "Trusting role: $TRUSTING_ROLE_ARN"
print_status "Region: $REGION"

# Confirmation prompt unless forced
if [[ "$FORCE" != "true" ]]; then
    echo ""
    print_warning "This action cannot be undone!"
    print_warning "All data will be permanently lost!"
    echo ""
    read -p "Are you sure you want to destroy the stack? Type 'yes' to confirm: " CONFIRM
    
    if [[ "$CONFIRM" != "yes" ]]; then
        print_status "Destruction cancelled."
        exit 0
    fi
fi

print_status "Starting destruction of Tenzir Platform stack..."

# Destroy the stack
cdk destroy \
    -c domainName="$DOMAIN_NAME" \
    -c randomSubdomain="$RANDOM_SUBDOMAIN" \
    -c trustingRoleArn="$TRUSTING_ROLE_ARN" \
    --force

if [[ $? -eq 0 ]]; then
    print_success "Stack destroyed successfully!"
    print_warning "Note: Some resources like S3 buckets and ECR repositories may need manual cleanup if they contained data."
else
    print_error "Destruction failed. Check the output above for details."
    print_warning "You may need to manually clean up some resources."
    exit 1
fi