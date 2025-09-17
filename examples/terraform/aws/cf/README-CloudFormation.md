# Tenzir Platform - CloudFormation Template

This CloudFormation template (`tenzir-platform.yml`) is an equivalent implementation of the Terraform configuration for the Tenzir Platform AWS Cloud Native Edition.

## Overview

The CloudFormation template creates the same AWS infrastructure as the original Terraform configuration, including:

- **VPC and Networking**: Complete network setup with public/private subnets, NAT Gateway, Internet Gateway, and VPC Endpoints
- **ECS Cluster**: For running the gateway service
- **RDS PostgreSQL**: Database for the platform
- **Lambda Functions**: API functionality
- **App Runner**: UI service hosting  
- **Application Load Balancer**: For the gateway service
- **S3 Buckets**: For blob and sidepath storage
- **Cognito**: User authentication and authorization
- **Secrets Manager**: Secure storage of secrets and passwords
- **ACM Certificates**: SSL/TLS certificates for domains
- **Route53**: DNS records for custom domains
- **ECR Repositories**: Container image storage

## Parameters

The template accepts the following parameters:

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `DomainName` | String | The base domain name (e.g., example.org) | Required |
| `RandomSubdomain` | String | Whether to prepend a random subdomain | `false` |
| `TrustingRoleArn` | String | ARN of the trusting role for AWS operations | Required |

## Usage

### Deploy using AWS CLI

```bash
aws cloudformation create-stack \
  --stack-name tenzir-platform \
  --template-body file://tenzir-platform.yml \
  --parameters ParameterKey=DomainName,ParameterValue=example.org \
               ParameterKey=RandomSubdomain,ParameterValue=false \
               ParameterKey=TrustingRoleArn,ParameterValue=arn:aws:iam::123456789012:role/TrustingRole \
  --capabilities CAPABILITY_NAMED_IAM
```

### Deploy using AWS Console

1. Open the AWS CloudFormation console
2. Choose "Create stack" → "With new resources"
3. Upload the `tenzir-platform.yml` template
4. Fill in the parameters
5. Acknowledge IAM capabilities and create the stack

## Outputs

The template provides the same outputs as the Terraform configuration:

- Repository URLs for containers
- Service URLs for UI and API
- OAuth configuration details
- Domain names
- Admin credentials location

## Key Differences from Terraform

### 1. Random ID Generation
- **Terraform**: Uses `random_id` and `random_password` resources
- **CloudFormation**: Uses custom Lambda functions to generate random values since CloudFormation lacks native random resource types

### 2. Bootstrap Module
- **Terraform**: Uses a separate bootstrap module for ECR repositories and certificates
- **CloudFormation**: All resources are defined inline in a single template

### 3. Secrets Management
- **Terraform**: Explicitly creates secrets with specific values using `random_bytes`
- **CloudFormation**: Uses `GenerateSecretString` for automatic secret generation with constraints

### 4. Database Password Management
- **Terraform**: Manually creates password and stores in Secrets Manager
- **CloudFormation**: Uses RDS managed master user secret feature where possible

### 5. Cognito User Creation
- **Terraform**: Uses `aws_cognito_user` resource
- **CloudFormation**: Uses custom Lambda function since CloudFormation doesn't support user creation directly

### 6. Domain Validation
- **Terraform**: Explicit Route53 records for certificate validation
- **CloudFormation**: Uses automatic certificate validation where supported by AWS

## Limitations

1. **Container Images**: The template references ECR repositories but doesn't include image building/pushing. You'll need to ensure images are available in the repositories before services start.

2. **Custom Resources**: Some functionality requires Lambda-based custom resources due to CloudFormation limitations.

3. **Updates**: CloudFormation may have different update behavior compared to Terraform, especially for resources that require replacement.

## Security Considerations

- All secrets are stored in AWS Secrets Manager with automatic rotation capabilities
- Network traffic is properly segmented using security groups
- Database is in private subnets with no internet access
- VPC endpoints minimize external network traffic

## Monitoring and Logging

- ECS services use CloudWatch Logs for centralized logging
- RDS has automated backups configured
- CloudTrail integration available for audit logging

## Cost Optimization

The template uses cost-effective instance types:
- RDS: `db.t3.micro`
- Lambda: 512MB memory
- ECS: 256 CPU / 512MB memory
- App Runner: 0.25 vCPU / 0.5GB memory

## Troubleshooting

1. **Stack Creation Fails**: Check IAM permissions and parameter values
2. **Service Health**: Monitor ECS service health and ALB target group health
3. **Domain Issues**: Verify Route53 hosted zone exists and is correctly configured
4. **Container Issues**: Ensure ECR repositories contain the required images with `:latest` tag

## Migration from Terraform

To migrate from the existing Terraform configuration:

1. Export current Terraform state and resources
2. Carefully map resource names and configurations
3. Consider using AWS Resource Groups to tag and track resources
4. Test the CloudFormation template in a separate environment first
5. Plan for potential downtime during migration

## Support

For issues specific to this CloudFormation template, refer to the original Terraform configuration and AWS CloudFormation documentation.