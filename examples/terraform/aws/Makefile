# Variables
ECR_REPOSITORY_UI = $(shell terraform output -json | jq -r '.ui_repository_url.value')
ECR_REPOSITORY_API = $(shell terraform output -json | jq -r '.platform_api_repository_url.value')
ECR_REPOSITORY_GATEWAY = $(shell terraform output -json | jq -r '.gateway_repository_url.value')
IMAGE_TAG ?= latest

.PHONY: build-ui build-api build push-ui push-api push login update-ui update-api update
.DEFAULT_GOAL := update

echo:
	@echo $(ECR_REPOSITORY_UI)
	@echo $(ECR_REPOSITORY_API)

login:
	AWS_PROFILE=tenzir-playground aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 612642570909.dkr.ecr.eu-west-1.amazonaws.com

build-ui:
	docker build -t $(ECR_REPOSITORY_UI):$(IMAGE_TAG) lambda-ui-container/

build-api:
	docker build -t $(ECR_REPOSITORY_API):$(IMAGE_TAG) lambda-api-container/

build: build-ui build-api

push-ui: login build-ui
	docker push $(ECR_REPOSITORY_UI):$(IMAGE_TAG)

push-api: login build-api
	docker push $(ECR_REPOSITORY_API):$(IMAGE_TAG)

push: push-ui push-api

update-ui: push-ui
	AWS_PROFILE=tenzir-playground aws lambda update-function-code --function-name tenzir-ui-function --image-uri $(ECR_REPOSITORY_UI):$(IMAGE_TAG) --region eu-west-1

update-api: push-api
	AWS_PROFILE=tenzir-playground aws lambda update-function-code --function-name tenzir-api-function --image-uri $(ECR_REPOSITORY_API):$(IMAGE_TAG) --region eu-west-1

update: update-ui update-api
