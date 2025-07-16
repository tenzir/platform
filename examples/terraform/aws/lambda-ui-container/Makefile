# Variables
ECR_REPOSITORY = 612642570909.dkr.ecr.eu-west-1.amazonaws.com/tenzir-lambda-ui-container
IMAGE_TAG ?= latest

.PHONY: build push login update
.DEFAULT_GOAL := update

login: ## Login to ECR
	AWS_PROFILE=tenzir-playground aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 612642570909.dkr.ecr.eu-west-1.amazonaws.com

build: ## Build the Docker image
	docker build -t $(ECR_REPOSITORY):$(IMAGE_TAG) .

push: login build ## Build and push the image to ECR
	docker push $(ECR_REPOSITORY):$(IMAGE_TAG)

update: push ## Update Lambda function with new image
	AWS_PROFILE=tenzir-playground aws lambda update-function-code --function-name tenzir-ui-function --image-uri $(ECR_REPOSITORY):$(IMAGE_TAG) --region eu-west-1
