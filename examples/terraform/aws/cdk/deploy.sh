#!/bin/bash

# Tenzir Platform CDK Deployment Script
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
    echo "  -h, --help                      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -d example.org -t arn:aws:iam::123456789012:role/TrustingRole"
    echo "  $0 -d example.org -r -t arn:aws:iam::123456789012:role/TrustingRole -p myprofile"
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
print_status "Using AWS region: $REGION"

print_status "Starting Tenzir Platform CDK deployment..."
print_status "Domain: $DOMAIN_NAME"
print_status "Random subdomain: $RANDOM_SUBDOMAIN"
print_status "Trusting role: $TRUSTING_ROLE_ARN"

# Check if Node.js and npm are available
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install Node.js 18 or later."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    print_error "npm is not installed. Please install npm."
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [[ $NODE_VERSION -lt 18 ]]; then
    print_error "Node.js version 18 or later is required. Current version: $(node --version)"
    exit 1
fi

# Install dependencies
print_status "Installing dependencies..."
npm install

# Build the project
print_status "Building TypeScript code..."
npm run build

# Bootstrap CDK (if needed)
print_status "Checking CDK bootstrap status..."
if ! cdk bootstrap --profile "${PROFILE}" 2>/dev/null; then
    print_warning "CDK bootstrap may be required. Running bootstrap..."
    cdk bootstrap --profile "${PROFILE}"
fi

# Synthesize the stack to check for errors
print_status "Synthesizing CloudFormation template..."
cdk synth \
    -c domainName="$DOMAIN_NAME" \
    -c randomSubdomain="$RANDOM_SUBDOMAIN" \
    -c trustingRoleArn="$TRUSTING_ROLE_ARN"

# Deploy the stack
print_status "Deploying Tenzir Platform stack..."
cdk deploy \
    -c domainName="$DOMAIN_NAME" \
    -c randomSubdomain="$RANDOM_SUBDOMAIN" \
    -c trustingRoleArn="$TRUSTING_ROLE_ARN" \
    --require-approval never

if [[ $? -eq 0 ]]; then
    print_success "Deployment completed successfully!"
    print_status "Your Tenzir Platform is now being provisioned."
    print_status "It may take several minutes for all services to become healthy."
    print_warning "Remember to push container images to the ECR repositories before the services can start."
else
    print_error "Deployment failed. Check the output above for details."
    exit 1
fi