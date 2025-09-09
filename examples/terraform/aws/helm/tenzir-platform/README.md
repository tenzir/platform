# Tenzir Platform Helm Chart

This Helm chart deploys the Tenzir Platform - Cloud Native Edition on Kubernetes. It provides a scalable, cloud-native security and analytics platform for data processing and analysis.

## Architecture

The Tenzir Platform consists of three main components:

- **Gateway Service**: WebSocket and HTTP gateway for node communication (equivalent to ECS Fargate service in AWS)
- **UI Service**: Web interface for platform management (equivalent to App Runner service in AWS) 
- **API Service**: REST API for platform operations (equivalent to Lambda function in AWS)

The chart also includes:
- PostgreSQL database for persistent storage (equivalent to RDS in AWS)
- MinIO object storage for file storage (equivalent to S3 in AWS)
- OIDC authentication integration (equivalent to Cognito in AWS)

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- An OIDC provider for authentication
- Ingress controller (nginx recommended)
- cert-manager for TLS certificates (optional but recommended)

## Installing the Chart

### Add Repository Dependencies

First, add the Bitnami repository for PostgreSQL and MinIO dependencies:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### Install Dependencies

```bash
helm dependency build
```

### Install the Chart

To install the chart with the release name `tenzir-platform`:

```bash
helm install tenzir-platform ./tenzir-platform -f values.yaml
```

### Configuration

Copy the `values.yaml` file and customize it for your environment. Key values to update:

```yaml
global:
  domain: "your-domain.com"  # Replace with your domain
  
auth:
  oidc:
    issuerUrl: "https://your-oidc-provider/.well-known/openid_configuration"
    clientId: "your-client-id"
    clientSecret: "your-client-secret"

# Update ingress hosts to match your domain
gateway:
  ingress:
    hosts:
      - host: nodes.your-domain.com
ui:
  ingress:
    hosts:
      - host: ui.your-domain.com
api:
  ingress:
    hosts:
      - host: api.your-domain.com
```

## Configuration Parameters

### Global Parameters

| Name | Description | Value |
|------|-------------|-------|
| `global.domain` | Base domain for the platform | `"example.org"` |
| `global.randomSubdomain` | Whether to add random subdomain | `false` |
| `global.region` | AWS region (for compatibility) | `"eu-west-1"` |

### Image Parameters

| Name | Description | Value |
|------|-------------|-------|
| `images.gateway.repository` | Gateway image repository | `"tenzir-sovereign-platform/gateway"` |
| `images.gateway.tag` | Gateway image tag | `"latest"` |
| `images.ui.repository` | UI image repository | `"tenzir-sovereign-platform/ui"` |
| `images.ui.tag` | UI image tag | `"latest"` |
| `images.api.repository` | API image repository | `"tenzir-sovereign-platform/platform-api"` |
| `images.api.tag` | API image tag | `"latest"` |

### Service Configuration

Each service (gateway, ui, api) supports the following configuration:

| Name | Description | Default |
|------|-------------|---------|
| `<service>.enabled` | Enable the service | `true` |
| `<service>.replicaCount` | Number of replicas | `1` |
| `<service>.service.type` | Kubernetes service type | `ClusterIP`/`LoadBalancer` |
| `<service>.ingress.enabled` | Enable ingress | `true` |
| `<service>.resources` | Resource limits and requests | See values.yaml |

### Database Configuration

| Name | Description | Value |
|------|-------------|-------|
| `postgresql.enabled` | Enable PostgreSQL | `true` |
| `postgresql.auth.database` | Database name | `"tenzir"` |
| `postgresql.auth.username` | Database username | `"tenzir_admin"` |

### Storage Configuration

| Name | Description | Value |
|------|-------------|-------|
| `minio.enabled` | Enable MinIO object storage | `true` |
| `minio.mode` | MinIO deployment mode | `"standalone"` |

### Authentication Configuration

| Name | Description | Value |
|------|-------------|-------|
| `auth.provider` | Authentication provider | `"oidc"` |
| `auth.oidc.issuerUrl` | OIDC issuer URL | `""` |
| `auth.oidc.clientId` | OIDC client ID | `""` |
| `auth.oidc.clientSecret` | OIDC client secret | `""` |

## Upgrading

To upgrade an existing installation:

```bash
helm dependency build
helm upgrade tenzir-platform ./tenzir-platform -f values.yaml
```

## Uninstalling

To uninstall/delete the `tenzir-platform` deployment:

```bash
helm delete tenzir-platform
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n <namespace>
```

### View Logs
```bash
kubectl logs -f deployment/tenzir-platform-<component> -n <namespace>
```

### Check Services and Ingress
```bash
kubectl get svc,ingress -n <namespace>
```

### Database Connection Issues
```bash
kubectl get secret postgres-credentials -o jsonpath="{.data.password}" | base64 --decode
```

## Comparison with AWS Infrastructure

This Helm chart provides equivalent functionality to the AWS Terraform configuration:

| AWS Service | Kubernetes Equivalent | 
|-------------|----------------------|
| ECS Fargate (Gateway) | Deployment + Service + Ingress |
| App Runner (UI) | Deployment + Service + Ingress |
| Lambda (API) | Deployment + Service + Ingress |
| RDS PostgreSQL | PostgreSQL Helm chart |
| S3 | MinIO Helm chart |
| Cognito | External OIDC provider |
| ALB | Ingress controller |
| Route53 | External DNS management |
| Secrets Manager | Kubernetes Secrets |

## Security Considerations

- Secrets are stored in Kubernetes Secrets with base64 encoding
- Consider using external secret management tools like External Secrets Operator
- Enable RBAC and Pod Security Standards
- Use network policies to restrict pod communication
- Configure proper resource limits to prevent resource exhaustion

## Production Recommendations

1. **High Availability**: Increase replica counts for critical services
2. **Monitoring**: Enable monitoring with Prometheus/Grafana
3. **Logging**: Configure centralized logging with ELK/EFK stack  
4. **Backup**: Implement backup strategy for PostgreSQL data
5. **TLS**: Use cert-manager for automatic certificate management
6. **Security**: Enable Pod Security Standards and network policies
7. **Resources**: Set appropriate resource limits and requests
8. **Storage**: Use persistent volumes for database and object storage

## Contributing

Please read the contributing guidelines in the main repository.

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.