# Tenzir Platform - AWS CDK Implementation

This directory contains an AWS CDK (Cloud Development Kit) implementation of the Tenzir Platform, equivalent to the Terraform configuration. CDK allows you to define AWS infrastructure using TypeScript, providing better type safety, IDE support, and programming constructs.

## Prerequisites

- **Node.js 18+**: Download from [nodejs.org](https://nodejs.org/)
- **AWS CLI v2**: Configured with appropriate credentials
- **AWS CDK CLI**: Install with `npm install -g aws-cdk`
- **TypeScript**: Installed automatically as dev dependency

## Quick Start

### 1. Install Dependencies

```bash
cd cdk
npm install
```

### 2. Deploy using the convenience script

```bash
./deploy.sh -d example.org -t arn:aws:iam::123456789012:role/TrustingRole
```

### 3. Or deploy manually

```bash
# Build the TypeScript code
npm run build

# Deploy the stack
cdk deploy \
  -c domainName=example.org \
  -c randomSubdomain=false \
  -c trustingRoleArn=arn:aws:iam::123456789012:role/TrustingRole
```

## Project Structure

```
cdk/
├── bin/
│   └── tenzir-platform.ts     # CDK app entry point
├── lib/
│   └── tenzir-platform-stack.ts # Main stack definition
├── deploy.sh                  # Deployment script
├── destroy.sh                 # Destruction script
├── package.json               # Dependencies and scripts
├── tsconfig.json              # TypeScript configuration
├── cdk.json                   # CDK configuration
└── README.md                  # This file
```

## Configuration Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `domainName` | string | Base domain name (e.g., example.org) | Required |
| `randomSubdomain` | boolean | Generate random subdomain prefix | `false` |
| `trustingRoleArn` | string | ARN of the trusting role for AWS operations | Required |

## Deployment Scripts

### Deploy Script (`deploy.sh`)

```bash
./deploy.sh [OPTIONS]

Options:
  -d, --domain-name DOMAIN        Domain name (e.g., example.org) [REQUIRED]
  -r, --random-subdomain          Enable random subdomain generation
  -t, --trusting-role-arn ARN     ARN of the trusting role [REQUIRED]
  -p, --profile PROFILE           AWS profile to use
  --region REGION                 AWS region (default: eu-west-1)
  -h, --help                      Show help message
```

**Examples:**
```bash
# Basic deployment
./deploy.sh -d example.org -t arn:aws:iam::123456789012:role/TrustingRole

# With random subdomain and specific profile
./deploy.sh -d example.org -r -t arn:aws:iam::123456789012:role/TrustingRole -p myprofile
```

### Destroy Script (`destroy.sh`)

```bash
./destroy.sh [OPTIONS]

Options:
  -f, --force                     Skip confirmation prompt
  # ... same options as deploy.sh
```

## Manual CDK Commands

```bash
# Install dependencies
npm install

# Compile TypeScript
npm run build

# Synthesize CloudFormation template
cdk synth -c domainName=example.org -c trustingRoleArn=arn:aws:iam::123456789012:role/TrustingRole

# Show differences between deployed stack and current code
cdk diff -c domainName=example.org -c trustingRoleArn=arn:aws:iam::123456789012:role/TrustingRole

# Deploy stack
cdk deploy -c domainName=example.org -c trustingRoleArn=arn:aws:iam::123456789012:role/TrustingRole

# Destroy stack
cdk destroy -c domainName=example.org -c trustingRoleArn=arn:aws:iam::123456789012:role/TrustingRole
```

## CDK vs CloudFormation vs Terraform

### Advantages of CDK over Raw CloudFormation

| Feature | CDK | CloudFormation |
|---------|-----|----------------|
| **Syntax** | TypeScript/Python/etc | YAML/JSON |
| **Type Safety** | ✅ Compile-time checks | ❌ Runtime validation only |
| **IDE Support** | ✅ Full autocomplete/refactoring | ❌ Limited |
| **Reusability** | ✅ Classes, functions, libraries | ❌ Copy/paste only |
| **Complex Logic** | ✅ Loops, conditionals, functions | ❌ Limited templating |
| **Random Generation** | ✅ Native crypto library | ❌ Custom Lambda required |
| **Resource Count** | ~150 lines of TS | ~1800 lines of YAML |

### CDK vs Terraform

| Feature | CDK | Terraform |
|---------|-----|-----------|
| **Language** | TypeScript/Python/Java/C# | HCL |
| **Cloud Support** | AWS-first, some multi-cloud | Multi-cloud native |
| **State Management** | CloudFormation handles | Manual state file |
| **IDE Support** | ✅ Excellent | ✅ Good |
| **Learning Curve** | Moderate (if you know TS/Python) | Moderate (new HCL syntax) |
| **Community** | Growing AWS ecosystem | Large multi-cloud ecosystem |

## Infrastructure Created

The CDK stack creates the same resources as the Terraform configuration:

### Core Infrastructure
- **VPC** with public/private subnets, NAT Gateway, Internet Gateway
- **VPC Endpoints** for Secrets Manager, ECR, S3, STS
- **Security Groups** with proper ingress/egress rules

### Container Infrastructure  
- **ECR Repositories** for UI, API, Gateway, and Node images
- **ECS Cluster** with Fargate tasks for the gateway service
- **Application Load Balancer** for gateway service exposure

### Database & Storage
- **RDS PostgreSQL** instance with automated backups
- **S3 Buckets** for blob and sidepath storage
- **Secrets Manager** for secure credential storage

### Compute & API
- **Lambda Function** for API functionality with VPC integration
- **API Gateway v2** with custom domain mapping
- **App Runner Service** (basic implementation - CDK support is limited)

### Authentication & DNS
- **Cognito User Pool** with OAuth configuration
- **ACM Certificates** for SSL/TLS with DNS validation
- **Route53 Records** for custom domain routing

## Key CDK Implementation Details

### 1. Random Value Generation
```typescript
// CDK - Native crypto library
const subdomainHex = crypto.randomBytes(3).toString('hex');
const bucketSuffix = crypto.randomBytes(16).toString('hex');

// vs CloudFormation - Custom Lambda required
const randomIdGenerator = new AWS::Lambda::Function({ ... });
```

### 2. Conditional Logic
```typescript
// CDK - Native TypeScript conditionals
const baseDomain = props.randomSubdomain 
  ? `tenant-${subdomainHex}.${props.domainName}`
  : props.domainName;

// vs CloudFormation - Conditions and Intrinsic Functions
Conditions:
  UseRandomSubdomain: !Equals [!Ref RandomSubdomain, 'true']
```

### 3. Resource Dependencies
```typescript
// CDK - Automatic dependency resolution
gatewayService.attachToApplicationTargetGroup(targetGroup);
dbSecurityGroup.addIngressRule(lambdaSecurityGroup, ec2.Port.tcp(5432));

// vs CloudFormation - Manual DependsOn declarations
DependsOn: [GatewayTargetGroup, DatabaseSecurityGroup]
```

### 4. Type Safety
```typescript
// CDK - Compile-time validation
const database = new rds.DatabaseInstance(this, 'Database', {
  engine: rds.DatabaseInstanceEngine.postgres({
    version: rds.PostgresEngineVersion.VER_17_5, // ✅ Validated at compile time
  }),
  instanceType: ec2.InstanceType.of(
    ec2.InstanceClass.T3, 
    ec2.InstanceSize.MICRO // ✅ Enum validation
  ),
});
```

## Limitations & Considerations

### 1. App Runner Support
CDK's App Runner support is still evolving. The current implementation provides basic App Runner service creation but may not include all features available in the Terraform `aws_apprunner_service` resource.

### 2. Custom Resources
Some advanced configurations may still require custom Lambda-backed resources, though CDK reduces this need significantly compared to raw CloudFormation.

### 3. State Management
CDK uses CloudFormation as its backend, so stack updates follow CloudFormation semantics rather than Terraform's more granular state management.

## Development Workflow

### 1. Local Development
```bash
# Watch mode for continuous compilation
npm run watch

# In another terminal, run diff to see changes
cdk diff -c domainName=example.org -c trustingRoleArn=...
```

### 2. Testing
```bash
# Run unit tests (when implemented)
npm test

# Synthesize to validate template generation
cdk synth -c domainName=example.org -c trustingRoleArn=...
```

### 3. Deployment
```bash
# Deploy to development
cdk deploy --profile dev-profile -c domainName=dev.example.org -c trustingRoleArn=...

# Deploy to production
cdk deploy --profile prod-profile -c domainName=example.org -c trustingRoleArn=...
```

## Troubleshooting

### Common Issues

1. **Node.js Version**: Ensure you're using Node.js 18+
2. **AWS Credentials**: Verify AWS CLI is configured correctly
3. **CDK Bootstrap**: Run `cdk bootstrap` if this is your first CDK deployment
4. **Domain Ownership**: Ensure you own the domain specified in `domainName`
5. **Route53 Zone**: The hosted zone for your domain must exist

### Debugging

```bash
# Get detailed CloudFormation events
aws cloudformation describe-stack-events --stack-name TenzirPlatformStack

# Check CDK context and configuration
cdk context

# Generate and inspect CloudFormation template
cdk synth > template.yaml
```

## Migration from Terraform

If you're migrating from the existing Terraform configuration:

1. **Export Terraform State**: Document current resource names and configurations
2. **Import Existing Resources**: Use CDK's resource import functionality where possible
3. **Staged Migration**: Consider deploying to a separate environment first
4. **Data Migration**: Plan for database and S3 data migration if needed

## Contributing

When modifying the CDK stack:

1. Follow TypeScript best practices
2. Update this README for any new parameters or significant changes
3. Test in a development environment first
4. Consider backward compatibility for existing deployments

## Support

- **AWS CDK Documentation**: https://docs.aws.amazon.com/cdk/
- **CDK API Reference**: https://docs.aws.amazon.com/cdk/api/v2/
- **TypeScript CDK Examples**: https://github.com/aws-samples/aws-cdk-examples

For issues specific to this implementation, refer to the original Terraform configuration and compare the generated CloudFormation templates.