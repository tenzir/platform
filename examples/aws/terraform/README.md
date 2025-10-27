# Tenzir Cloud-Native Edition

# Setup

Provisional workflow for the Terraform cloud setup.

## Requirements

In order to deploy the Tenzir Cloud-Native Edition, you need the following
prerequisites:

- A domain name managed by route53
- An IAM role with permissions to deploy the infrastructure, ie. setting up
  ECS and App Runner services.

## 1. Create ECR repos for lambdas

Apply the bootstrap module containing base infrastructure.

```sh
terraform apply -m module.bootstrap
```

## 2. Upload container images

Upload the tenzir container images to the ECR repositories created in
the previous step.

```sh
make push
```

## 3. Create the rest of the deployment

```sh
terraform apply
```

# Customization

There are several ways to adjust the default setup of the cloud-native
edition.

## Authentication

By default, this terraform setup will create an instance of AWS Cognito
including 