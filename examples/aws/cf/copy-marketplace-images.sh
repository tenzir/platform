#!/bin/bash
set -e

# Script to copy AWS Marketplace container images to local ECR
# Must be run after subscribing to the Tenzir Platform marketplace product

VERSION="${VERSION:-v0.1.0}"
AWS_REGION="${AWS_REGION:-$(aws configure get region)}"
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

MARKETPLACE_REGISTRY="709825985650.dkr.ecr.us-east-1.amazonaws.com"
LOCAL_REGISTRY="$AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com"

IMAGES=(
  "tenzir/tenzir-platform-ui"
  "tenzir/tenzir-platform-api"
  "tenzir/tenzir-platform-gateway"
)

echo "Copying Tenzir Platform images version $VERSION to $LOCAL_REGISTRY"
echo "Account: $AWS_ACCOUNT"
echo "Region: $AWS_REGION"
echo ""

# Login to marketplace ECR
echo "Logging in to marketplace ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $MARKETPLACE_REGISTRY

# Login to local ECR
echo "Logging in to local ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $LOCAL_REGISTRY

# Copy each image
for IMAGE in "${IMAGES[@]}"; do
  echo ""
  echo "Copying $IMAGE:$VERSION..."

  SOURCE_IMAGE="$MARKETPLACE_REGISTRY/$IMAGE:$VERSION"
  TARGET_IMAGE="$LOCAL_REGISTRY/$IMAGE:$VERSION"

  docker pull "$SOURCE_IMAGE"
  docker tag "$SOURCE_IMAGE" "$TARGET_IMAGE"
  docker push "$TARGET_IMAGE"

  echo "✓ Copied $IMAGE:$VERSION"
done

echo ""
echo "All images copied successfully!"
echo "You can now deploy the CloudFormation stack."
