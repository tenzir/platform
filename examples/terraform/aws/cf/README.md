# Tenzir Platform CloudFormation Template

This CloudFormation template provides the equivalent AWS infrastructure setup for the Tenzir Platform as defined in the Terraform configuration.

## Prerequisites

1. An AWS account with appropriate permissions
2. A registered domain name with Route53 hosted zone
3. Docker images pushed to the ECR repositories created by this stack

## Parameters

- **DomainName**: Your base domain name (e.g., example.org)
- **RandomSubdomain**: Whether to add a random subdomain prefix (true/false)
- **TrustingRoleArn**: ARN of the trusting role for AWS operations
- **UseExternalOIDC**: Use external OIDC provider instead of Cognito (true/false)
- **ExternalOIDCIssuerURL**: OIDC issuer URL (required if UseExternalOIDC=true)
- **ExternalOIDCClientID**: OIDC client ID (required if UseExternalOIDC=true)
- **ExternalOIDCClientSecret**: OIDC client secret (required if UseExternalOIDC=true)

## Deployment

### Using AWS CLI

```bash
aws cloudformation create-stack \
  --stack-name tenzir-platform \
  --template-body file://tenzir-platform.yml \
  --parameters \
    ParameterKey=DomainName,ParameterValue=example.org \
    ParameterKey=RandomSubdomain,ParameterValue=false \
    ParameterKey=TrustingRoleArn,ParameterValue=arn:aws:iam::123456789012:role/TrustingRole \
    ParameterKey=UseExternalOIDC,ParameterValue=false \
  --capabilities CAPABILITY_NAMED_IAM
```

### Using AWS Console

1. Navigate to CloudFormation in the AWS Console
2. Click "Create Stack" > "With new resources"
3. Upload the template file or specify S3 URL
4. Fill in the parameters
5. Review and acknowledge IAM resource creation
6. Create the stack

## Stack Resources

The template creates the following main resources:

### Networking
- VPC with public and private subnets
- Internet Gateway and NAT Gateway
- Security Groups for services
- VPC Endpoints for AWS services

### Compute
- ECS Cluster for container services
- Lambda function for API
- App Runner service for UI
- Application Load Balancer

### Storage
- RDS PostgreSQL database
- S3 buckets for blobs and sidepath data
- ECR repositories for container images

### Security & Auth
- Cognito User Pool (optional)
- Secrets Manager secrets
- IAM roles and policies

### Domain & Certificates
- ACM certificates for subdomains
- Route53 DNS records
- API Gateway with custom domain

## Post-Deployment Steps

1. **Push Docker Images**: Build and push your Docker images to the ECR repositories created by the stack
2. **DNS Validation**: Ensure ACM certificates are validated via DNS
3. **Update App Runner**: The App Runner service may need to be updated with the latest image
4. **Configure Cognito**: If using Cognito, configure the user pool settings as needed

## Outputs

The stack provides the following outputs:

- Repository URLs for ECR
- Service URLs for UI and API
- OAuth/OIDC configuration details
- Domain names for services
- Admin credentials (when using Cognito)

## Differences from Terraform

While this CloudFormation template aims to replicate the Terraform configuration, there are some differences:

1. **Random ID Generation**: Uses a Lambda function for random ID generation
2. **Certificate Validation**: ACM certificate validation may require manual DNS record creation
3. **Module Structure**: Bootstrap module is integrated directly into the main template
4. **Route53 Zone**: Assumes the hosted zone exists and uses SSM parameter for zone ID

## Troubleshooting

- **Certificate Validation**: Check Route53 for proper DNS validation records
- **Service Health**: Monitor ECS, Lambda, and App Runner service logs
- **Database Connection**: Verify security group rules and VPC endpoints
- **Image Deployment**: Ensure Docker images are properly tagged and pushed to ECR

## Cleanup

To delete the stack and all resources:

```bash
aws cloudformation delete-stack --stack-name tenzir-platform
```

Note: Some resources like S3 buckets may need to be emptied before deletion.