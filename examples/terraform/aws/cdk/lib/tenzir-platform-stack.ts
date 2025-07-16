import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as rds from 'aws-cdk-lib/aws-rds';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigateway from 'aws-cdk-lib/aws-apigatewayv2';
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
import * as ecr from 'aws-cdk-lib/aws-ecr';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as acm from 'aws-cdk-lib/aws-certificatemanager';
import * as route53 from 'aws-cdk-lib/aws-route53';
import * as route53targets from 'aws-cdk-lib/aws-route53-targets';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as ssm from 'aws-cdk-lib/aws-ssm';
import * as apprunner from 'aws-cdk-lib/aws-apprunner';
import { Construct } from 'constructs';
import * as crypto from 'crypto';

export interface TenzirPlatformStackProps extends cdk.StackProps {
  domainName: string;
  randomSubdomain: boolean;
  trustingRoleArn: string;
}

export class TenzirPlatformStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: TenzirPlatformStackProps) {
    super(scope, id, props);

    // Generate random values
    const subdomainHex = props.randomSubdomain ? crypto.randomBytes(3).toString('hex') : '';
    const bucketSuffix = crypto.randomBytes(16).toString('hex');
    
    // Domain configuration
    const baseDomain = props.randomSubdomain 
      ? `tenant-${subdomainHex}.${props.domainName}`
      : props.domainName;
    
    const apiDomain = `api.${baseDomain}`;
    const uiDomain = `ui.${baseDomain}`;
    const nodesDomain = `nodes.${baseDomain}`;

    // Route53 Hosted Zone (create new one for this example)
    const hostedZone = new route53.HostedZone(this, 'HostedZone', {
      zoneName: props.domainName,
    });

    // ACM Certificates
    const apiCertificate = new acm.Certificate(this, 'ApiCertificate', {
      domainName: apiDomain,
      validation: acm.CertificateValidation.fromDns(hostedZone),
    });

    const uiCertificate = new acm.Certificate(this, 'UiCertificate', {
      domainName: uiDomain,
      validation: acm.CertificateValidation.fromDns(hostedZone),
    });

    const nodesCertificate = new acm.Certificate(this, 'NodesCertificate', {
      domainName: nodesDomain,
      validation: acm.CertificateValidation.fromDns(hostedZone),
    });

    // ECR Repositories
    const nodeRepository = new ecr.Repository(this, 'NodeRepository', {
      repositoryName: 'tenzir-sovereign-platform/node',
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      imageScanOnPush: true,
    });

    const platformApiRepository = new ecr.Repository(this, 'PlatformApiRepository', {
      repositoryName: 'tenzir-sovereign-platform/platform-api',
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      imageScanOnPush: true,
    });

    const gatewayRepository = new ecr.Repository(this, 'GatewayRepository', {
      repositoryName: 'tenzir-sovereign-platform/gateway',
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      imageScanOnPush: true,
    });

    const uiRepository = new ecr.Repository(this, 'UiRepository', {
      repositoryName: 'tenzir-sovereign-platform/ui',
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      imageScanOnPush: true,
    });

    // VPC and Networking
    const vpc = new ec2.Vpc(this, 'TenzirVPC', {
      cidr: '10.0.0.0/16',
      maxAzs: 3,
      enableDnsHostnames: true,
      enableDnsSupport: true,
      subnetConfiguration: [
        {
          name: 'public',
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24,
        },
        {
          name: 'private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
        {
          name: 'isolated',
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24,
        },
      ],
    });

    // Additional custom subnets to match Terraform exactly
    const nodesSubnet = new ec2.Subnet(this, 'NodesSubnet', {
      vpcId: vpc.vpcId,
      cidrBlock: '10.0.1.0/24',
      availabilityZone: vpc.availabilityZones[0],
      mapPublicIpOnLaunch: true,
    });

    const platformSubnet = new ec2.Subnet(this, 'PlatformSubnet', {
      vpcId: vpc.vpcId,
      cidrBlock: '10.0.2.0/24',
      availabilityZone: vpc.availabilityZones[1],
      mapPublicIpOnLaunch: false,
    });

    // VPC Endpoints
    vpc.addInterfaceEndpoint('SecretsManagerEndpoint', {
      service: ec2.InterfaceVpcEndpointAwsService.SECRETS_MANAGER,
      subnets: { subnets: [platformSubnet] },
    });

    vpc.addInterfaceEndpoint('ECRApiEndpoint', {
      service: ec2.InterfaceVpcEndpointAwsService.ECR,
      subnets: { subnets: [platformSubnet] },
    });

    vpc.addInterfaceEndpoint('ECRDockerEndpoint', {
      service: ec2.InterfaceVpcEndpointAwsService.ECR_DOCKER,
      subnets: { subnets: [platformSubnet] },
    });

    vpc.addGatewayEndpoint('S3Endpoint', {
      service: ec2.GatewayVpcEndpointAwsService.S3,
    });

    vpc.addInterfaceEndpoint('STSEndpoint', {
      service: ec2.InterfaceVpcEndpointAwsService.STS,
      subnets: { subnets: [platformSubnet] },
    });

    // S3 Buckets
    const blobsBucket = new s3.Bucket(this, 'TenzirBlobsBucket', {
      bucketName: `tenzir-blobs-${bucketSuffix}`,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const sidepathBucket = new s3.Bucket(this, 'TenzirSidepathBucket', {
      bucketName: `tenzir-sidepath-${bucketSuffix}`,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // Secrets Manager
    const dbPasswordSecret = new secretsmanager.Secret(this, 'DatabasePasswordSecret', {
      secretName: `tenzir-postgres-password-v2-${subdomainHex}`,
      description: 'Password for Tenzir PostgreSQL database',
      generateSecretString: {
        secretStringTemplate: JSON.stringify({ username: 'tenzir_admin' }),
        generateStringKey: 'password',
        passwordLength: 16,
        excludeCharacters: '"@/\\\'',
      },
    });

    const tenantTokenEncryptionKey = new secretsmanager.Secret(this, 'TenantTokenEncryptionKey', {
      secretName: `tenzir-tenant-token-encryption-key-${subdomainHex}`,
      description: 'Tenant token encryption key secret',
      generateSecretString: {
        passwordLength: 32,
        requireEachIncludedType: false,
        includeSpace: false,
        excludePunctuation: true,
      },
    });

    const tenantManagerAppApiKey = new secretsmanager.Secret(this, 'TenantManagerAppApiKey', {
      secretName: `tenzir-tenant-manager-app-api-key-${subdomainHex}`,
      description: 'API key secret for tenant manager app',
      generateSecretString: {
        passwordLength: 32,
        requireEachIncludedType: false,
        includeSpace: false,
        excludePunctuation: true,
      },
    });

    const workspaceSecretsMasterSeed = new secretsmanager.Secret(this, 'WorkspaceSecretsMasterSeed', {
      secretName: `tenzir-workspace-secrets-master-seed-${subdomainHex}`,
      description: 'Master seed secret for workspace secrets',
      generateSecretString: {
        passwordLength: 64,
        requireEachIncludedType: false,
        includeSpace: false,
        excludePunctuation: true,
      },
    });

    const authSecret = new secretsmanager.Secret(this, 'AuthSecret', {
      secretName: `tenzir-auth-secret-${subdomainHex}`,
      description: 'Auth secret for UI Lambda',
      generateSecretString: {
        passwordLength: 32,
        requireEachIncludedType: false,
        includeSpace: false,
        excludePunctuation: true,
      },
    });

    // RDS Database
    const dbSubnetGroup = new rds.SubnetGroup(this, 'DatabaseSubnetGroup', {
      description: 'Subnet group for Tenzir database',
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
    });

    const dbSecurityGroup = new ec2.SecurityGroup(this, 'DatabaseSecurityGroup', {
      vpc,
      description: 'Security group for Tenzir RDS instance',
    });

    const database = new rds.DatabaseInstance(this, 'TenzirDatabase', {
      instanceIdentifier: 'tenzir-postgres',
      engine: rds.DatabaseInstanceEngine.POSTGRES,
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MICRO),
      allocatedStorage: 20,
      maxAllocatedStorage: 100,
      storageType: rds.StorageType.GP2,
      storageEncrypted: true,
      databaseName: 'tenzir',
      credentials: rds.Credentials.fromSecret(dbPasswordSecret),
      vpc,
      subnetGroup: dbSubnetGroup,
      securityGroups: [dbSecurityGroup],
      backupRetention: cdk.Duration.days(7),
      preferredBackupWindow: '03:00-04:00',
      preferredMaintenanceWindow: 'sun:04:00-sun:05:00',
      deletionProtection: false,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // PostgreSQL URI Secret (will be populated after DB creation)
    const postgresUriSecret = new secretsmanager.Secret(this, 'PostgresUriSecret', {
      secretName: `tenzir-postgres-uri-${subdomainHex}`,
      description: 'PostgreSQL URI for Tenzir database connection',
      secretStringValue: cdk.SecretValue.unsafePlainText(
        `postgresql://tenzir_admin:PLACEHOLDER_PASSWORD@${database.instanceEndpoint.socketAddress}/tenzir?sslmode=require`
      ),
    });

    // Cognito User Pool
    const userPool = new cognito.UserPool(this, 'TenzirUserPool', {
      userPoolName: 'tenzir-user-pool',
      signInAliases: { email: true },
      autoVerify: { email: true },
      selfSignUpEnabled: false,
      passwordPolicy: {
        minLength: 8,
        requireLowercase: true,
        requireUppercase: true,
        requireDigits: true,
        requireSymbols: true,
      },
      userVerification: {
        emailSubject: 'Tenzir Account Verification Code',
        emailBody: 'Your verification code is {####}',
      },
      standardAttributes: {
        email: {
          required: true,
          mutable: true,
        },
      },
    });

    const userPoolClient = new cognito.UserPoolClient(this, 'TenzirUserPoolClient', {
      userPool,
      userPoolClientName: 'tenzir-app',
      generateSecret: true,
      oAuth: {
        flows: {
          authorizationCodeGrant: true,
        },
        scopes: [
          cognito.OAuthScope.EMAIL,
          cognito.OAuthScope.OPENID,
          cognito.OAuthScope.PROFILE,
        ],
        callbackUrls: [`https://${uiDomain}/login/oauth/callback`],
      },
      preventUserExistenceErrors: true,
      enableTokenRevocation: true,
      authFlows: {
        userSrp: false,
        adminUserPassword: false,
        custom: false,
        userPassword: false,
      },
      accessTokenValidity: cdk.Duration.minutes(60),
      idTokenValidity: cdk.Duration.minutes(60),
      refreshTokenValidity: cdk.Duration.days(30),
    });

    const userPoolDomain = new cognito.UserPoolDomain(this, 'TenzirUserPoolDomain', {
      userPool,
      cognitoDomain: {
        domainPrefix: `tenzir-auth-${subdomainHex || 'default'}`,
      },
    });

    // ECS Cluster
    const cluster = new ecs.Cluster(this, 'ECSCluster', {
      clusterName: 'tenzir-platform-aws-edition',
      vpc,
      containerInsights: true,
    });

    // ECS Task Role for Gateway
    const gatewayTaskRole = new iam.Role(this, 'GatewayTaskRole', {
      assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
      inlinePolicies: {
        SecretsPolicy: new iam.PolicyDocument({
          statements: [
            new iam.PolicyStatement({
              actions: ['secretsmanager:GetSecretValue'],
              resources: [
                postgresUriSecret.secretArn,
                tenantManagerAppApiKey.secretArn,
                tenantTokenEncryptionKey.secretArn,
                workspaceSecretsMasterSeed.secretArn,
              ],
            }),
          ],
        }),
      },
    });

    // CloudWatch Log Groups
    const gatewayLogGroup = new logs.LogGroup(this, 'GatewayLogGroup', {
      logGroupName: '/ecs/tenzir-gateway',
      retention: logs.RetentionDays.ONE_WEEK,
    });

    const demoNodeLogGroup = new logs.LogGroup(this, 'DemoNodeLogGroup', {
      logGroupName: '/ecs/tenzir-demo-node',
      retention: logs.RetentionDays.ONE_WEEK,
    });

    // ECS Task Definition
    const gatewayTaskDefinition = new ecs.FargateTaskDefinition(this, 'GatewayTaskDefinition', {
      family: 'tenzir-gateway',
      cpu: 256,
      memoryLimitMiB: 512,
      taskRole: gatewayTaskRole,
    });

    const gatewayContainer = gatewayTaskDefinition.addContainer('gateway', {
      image: ecs.ContainerImage.fromEcrRepository(gatewayRepository, 'latest'),
      command: ['tenant_manager/ws/server/aws.py'],
      environment: {
        BASE_PATH: '',
        TENZIR_PROXY_TIMEOUT: '60',
        TENANT_MANAGER_APP_API_KEY_SECRET_ARN: tenantManagerAppApiKey.secretArn,
        TENANT_MANAGER_TENANT_TOKEN_ENCRYPTION_KEY_SECRET_ARN: tenantTokenEncryptionKey.secretArn,
        STORE__TYPE: 'postgres',
        STORE__POSTGRES_URI_SECRET_ARN: postgresUriSecret.secretArn,
        WORKSPACE_SECRETS_MASTER_SEED_ARN: workspaceSecretsMasterSeed.secretArn,
      },
      logging: ecs.LogDrivers.awsLogs({
        streamPrefix: 'ecs',
        logGroup: gatewayLogGroup,
      }),
    });

    gatewayContainer.addPortMappings({
      containerPort: 5000,
      protocol: ecs.Protocol.TCP,
    });

    // Application Load Balancer
    const alb = new elbv2.ApplicationLoadBalancer(this, 'GatewayALB', {
      vpc,
      internetFacing: true,
      loadBalancerName: 'tenzir-gateway-alb',
    });

    const targetGroup = new elbv2.ApplicationTargetGroup(this, 'GatewayTargetGroup', {
      vpc,
      port: 80,
      protocol: elbv2.ApplicationProtocol.HTTP,
      targetType: elbv2.TargetType.IP,
      healthCheck: {
        enabled: true,
        healthyThresholdCount: 2,
        interval: cdk.Duration.seconds(30),
        path: '/health',
        port: 'traffic-port',
        protocol: elbv2.Protocol.HTTP,
        timeout: cdk.Duration.seconds(5),
        unhealthyThresholdCount: 2,
      },
    });

    const httpsListener = alb.addListener('HTTPSListener', {
      port: 443,
      protocol: elbv2.ApplicationProtocol.HTTPS,
      certificates: [nodesCertificate],
      defaultTargetGroups: [targetGroup],
    });

    alb.addListener('HTTPListener', {
      port: 80,
      protocol: elbv2.ApplicationProtocol.HTTP,
      defaultAction: elbv2.ListenerAction.redirect({
        protocol: 'HTTPS',
        port: '443',
        permanent: true,
      }),
    });

    // ECS Service
    const gatewayService = new ecs.FargateService(this, 'GatewayService', {
      cluster,
      taskDefinition: gatewayTaskDefinition,
      serviceName: 'gateway',
      desiredCount: 1,
      vpcSubnets: { subnets: [platformSubnet] },
      assignPublicIp: false,
    });

    gatewayService.attachToApplicationTargetGroup(targetGroup);

    // Allow ALB to connect to ECS service
    gatewayService.connections.allowFrom(alb, ec2.Port.tcp(5000));
    dbSecurityGroup.addIngressRule(gatewayService.connections.securityGroups[0], ec2.Port.tcp(5432));

    // SSM Parameters
    new ssm.StringParameter(this, 'DemoNodeLogsGroupNameParameter', {
      parameterName: '/tenzir/platform/demo-node-logs-group-name',
      stringValue: demoNodeLogGroup.logGroupName,
    });

    new ssm.StringParameter(this, 'ECSClusterArnParameter', {
      parameterName: '/tenzir/platform/ecs-cluster-arn',
      stringValue: cluster.clusterArn,
    });

    new ssm.StringParameter(this, 'GatewayWsEndpointParameter', {
      parameterName: '/tenzir/platform/gateway-ws-endpoint',
      stringValue: `wss://${nodesDomain}`,
    });

    new ssm.StringParameter(this, 'GatewayHttpEndpointParameter', {
      parameterName: '/tenzir/platform/gateway-http-endpoint',
      stringValue: `https://${nodesDomain}`,
    });

    // Lambda Function for API
    const apiLambdaRole = new iam.Role(this, 'ApiLambdaRole', {
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaVPCAccessExecutionRole'),
      ],
      inlinePolicies: {
        SecretsPolicy: new iam.PolicyDocument({
          statements: [
            new iam.PolicyStatement({
              actions: ['secretsmanager:GetSecretValue'],
              resources: [
                dbPasswordSecret.secretArn,
                postgresUriSecret.secretArn,
                tenantManagerAppApiKey.secretArn,
                tenantTokenEncryptionKey.secretArn,
                workspaceSecretsMasterSeed.secretArn,
                authSecret.secretArn,
              ],
            }),
          ],
        }),
        SSMPolicy: new iam.PolicyDocument({
          statements: [
            new iam.PolicyStatement({
              actions: ['ssm:GetParameter', 'ssm:GetParameters'],
              resources: [`arn:aws:ssm:*:*:parameter/tenzir/platform/*`],
            }),
          ],
        }),
        S3Policy: new iam.PolicyDocument({
          statements: [
            new iam.PolicyStatement({
              actions: ['s3:GetObject', 's3:PutObject', 's3:DeleteObject', 's3:ListBucket'],
              resources: [sidepathBucket.bucketArn, `${sidepathBucket.bucketArn}/*`],
            }),
          ],
        }),
        CloudFormationPolicy: new iam.PolicyDocument({
          statements: [
            new iam.PolicyStatement({
              actions: [
                'cloudformation:CreateStack',
                'cloudformation:UpdateStack',
                'cloudformation:DeleteStack',
                'cloudformation:DescribeStacks',
                'cloudformation:DescribeStackEvents',
                'cloudformation:DescribeStackResources',
                'cloudformation:GetStackPolicy',
                'cloudformation:GetTemplate',
                'cloudformation:ListStackResources',
                'cloudformation:ListStacks',
                'cloudformation:ValidateTemplate',
              ],
              resources: ['arn:aws:cloudformation:*:*:stack/demo-*/*'],
            }),
          ],
        }),
        ECSPolicy: new iam.PolicyDocument({
          statements: [
            new iam.PolicyStatement({
              actions: [
                'ecs:CreateService',
                'ecs:UpdateService',
                'ecs:DeleteService',
                'ecs:ListTasks',
                'ecs:DescribeTasks',
                'ecs:DescribeServices',
                'ecs:RegisterTaskDefinition',
                'ecs:DeregisterTaskDefinition',
                'ecs:ListTaskDefinitions',
              ],
              resources: ['*'],
            }),
          ],
        }),
      },
    });

    const apiLambda = new lambda.Function(this, 'ApiLambdaFunction', {
      functionName: 'tenzir-api-function',
      role: apiLambdaRole,
      runtime: lambda.Runtime.FROM_IMAGE,
      handler: lambda.Handler.FROM_IMAGE,
      code: lambda.Code.fromEcrImage(platformApiRepository, { tagOrDigest: 'latest' }),
      timeout: cdk.Duration.seconds(30),
      memorySize: 512,
      vpc,
      vpcSubnets: { subnets: [platformSubnet] },
      environment: {
        DB_SECRET_ARN: dbPasswordSecret.secretArn,
        ECS_CLUSTER_ARN: cluster.clusterArn,
        STORE__TYPE: 'postgres',
        STORE__POSTGRES_URI_SECRET_ARN: postgresUriSecret.secretArn,
        TENANT_MANAGER_APP_API_KEY_SECRET_ARN: tenantManagerAppApiKey.secretArn,
        TENANT_MANAGER_TENANT_TOKEN_ENCRYPTION_KEY_SECRET_ARN: tenantTokenEncryptionKey.secretArn,
        WORKSPACE_SECRETS_MASTER_SEED_ARN: workspaceSecretsMasterSeed.secretArn,
        TENZIR_DEMO_NODE_LOGS_GROUP_NAME: demoNodeLogGroup.logGroupName,
        TENANT_MANAGER_AUTH__TRUSTED_AUDIENCES: JSON.stringify({
          issuer: `https://cognito-idp.${this.region}.amazonaws.com/${userPool.userPoolId}`,
          audiences: [userPoolClient.userPoolClientId],
        }),
        BASE_PATH: '',
        TENANT_MANAGER_SIDEPATH_BUCKET_NAME: sidepathBucket.bucketName,
        TENZIR_DEMO_NODE_IMAGE: `${nodeRepository.repositoryUri}:latest`,
        GATEWAY_WS_ENDPOINT: `wss://${nodesDomain}`,
        GATEWAY_HTTP_ENDPOINT: `https://${nodesDomain}`,
      },
    });

    // Lambda Function URL
    const apiLambdaUrl = apiLambda.addFunctionUrl({
      authType: lambda.FunctionUrlAuthType.NONE,
      cors: {
        allowCredentials: false,
        allowedOrigins: ['*'],
        allowedMethods: [lambda.HttpMethod.ALL],
        allowedHeaders: ['*'],
        maxAge: cdk.Duration.days(1),
      },
    });

    // API Gateway using CloudFormation resources
    const apiGateway = new apigateway.CfnApi(this, 'ApiGateway', {
      name: 'tenzir-api-api',
      description: 'API Gateway for Tenzir API Lambda',
      protocolType: 'HTTP',
      corsConfiguration: {
        allowCredentials: false,
        allowOrigins: ['*'],
        allowMethods: ['*'],
        allowHeaders: ['*'],
        maxAge: 86400,
      },
    });

    const apiIntegration = new apigateway.CfnIntegration(this, 'ApiIntegration', {
      apiId: apiGateway.ref,
      integrationType: 'AWS_PROXY',
      integrationMethod: 'POST',
      integrationUri: apiLambda.functionArn,
      payloadFormatVersion: '2.0',
    });

    new apigateway.CfnRoute(this, 'ApiRoute', {
      apiId: apiGateway.ref,
      routeKey: '$default',
      target: `integrations/${apiIntegration.ref}`,
    });

    const apiStage = new apigateway.CfnStage(this, 'ApiStage', {
      apiId: apiGateway.ref,
      stageName: '$default',
      autoDeploy: true,
    });

    const apiDomainName = new apigateway.CfnDomainName(this, 'ApiDomainName', {
      domainName: apiDomain,
      domainNameConfigurations: [{
        certificateArn: apiCertificate.certificateArn,
        endpointType: 'REGIONAL',
        securityPolicy: 'TLS_1_2',
      }],
    });

    new apigateway.CfnApiMapping(this, 'ApiMapping', {
      apiId: apiGateway.ref,
      domainName: apiDomainName.ref,
      stage: apiStage.ref,
    });

    // Lambda permission for API Gateway
    new lambda.CfnPermission(this, 'ApiGatewayLambdaPermission', {
      action: 'lambda:InvokeFunction',
      functionName: apiLambda.functionName,
      principal: 'apigateway.amazonaws.com',
      sourceArn: `arn:aws:execute-api:${this.region}:${this.account}:${apiGateway.ref}/*/*`,
    });

    // Allow database access from Lambda
    dbSecurityGroup.addIngressRule(apiLambda.connections.securityGroups[0], ec2.Port.tcp(5432));

    // App Runner Service (simplified implementation)
    // Note: CDK doesn't have full App Runner support yet, so this is a basic implementation
    const appRunnerRole = new iam.Role(this, 'AppRunnerInstanceRole', {
      assumedBy: new iam.ServicePrincipal('tasks.apprunner.amazonaws.com'),
      inlinePolicies: {
        SecretsPolicy: new iam.PolicyDocument({
          statements: [
            new iam.PolicyStatement({
              actions: ['secretsmanager:GetSecretValue'],
              resources: [
                dbPasswordSecret.secretArn,
                postgresUriSecret.secretArn,
                tenantManagerAppApiKey.secretArn,
                authSecret.secretArn,
              ],
            }),
          ],
        }),
      },
    });

    // Route53 Records
    new route53.ARecord(this, 'NodesARecord', {
      zone: hostedZone,
      recordName: nodesDomain,
      target: route53.RecordTarget.fromAlias(new route53targets.LoadBalancerTarget(alb)),
    });

    new route53.ARecord(this, 'ApiARecord', {
      zone: hostedZone,
      recordName: apiDomain,
      target: route53.RecordTarget.fromAlias(
        new route53targets.ApiGatewayv2DomainProperties(
          apiDomainName.getAtt('RegionalDomainName').toString(),
          apiDomainName.getAtt('RegionalHostedZoneId').toString(),
        ),
      ),
    });

    // Outputs
    new cdk.CfnOutput(this, 'UiRepositoryUrl', {
      description: 'URL of the unified UI repository',
      value: uiRepository.repositoryUri,
    });

    new cdk.CfnOutput(this, 'PlatformApiRepositoryUrl', {
      description: 'URL of the unified platform API repository',
      value: platformApiRepository.repositoryUri,
    });

    new cdk.CfnOutput(this, 'GatewayRepositoryUrl', {
      description: 'URL of the unified gateway repository',
      value: gatewayRepository.repositoryUri,
    });

    new cdk.CfnOutput(this, 'ApiFunctionUrl', {
      description: 'URL of the API Lambda function',
      value: apiLambdaUrl.url,
    });

    new cdk.CfnOutput(this, 'OauthClientId', {
      description: 'The OAuth client ID',
      value: userPoolClient.userPoolClientId,
    });

    new cdk.CfnOutput(this, 'OidcIssuerUrl', {
      description: 'The OIDC issuer URL for the Cognito User Pool',
      value: `https://cognito-idp.${this.region}.amazonaws.com/${userPool.userPoolId}`,
    });

    new cdk.CfnOutput(this, 'GatewayAlbDnsName', {
      description: 'DNS name of the gateway Application Load Balancer',
      value: alb.loadBalancerDnsName,
    });

    new cdk.CfnOutput(this, 'BaseDomain', {
      description: 'The base domain (with random subdomain if enabled)',
      value: baseDomain,
    });

    new cdk.CfnOutput(this, 'ApiDomain', {
      description: 'The API domain name',
      value: apiDomain,
    });

    new cdk.CfnOutput(this, 'UiDomain', {
      description: 'The UI domain name',
      value: uiDomain,
    });

    new cdk.CfnOutput(this, 'AdminUsername', {
      description: 'Default admin username for Cognito',
      value: `admin@${baseDomain}`,
    });
  }
}