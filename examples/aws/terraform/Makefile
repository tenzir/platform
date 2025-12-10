IMAGE_TAG ?= latest

TENZIR_UI_UPSTREAM_CONTAINER = ghcr.io/tenzir/app:$(IMAGE_TAG)
TENZIR_PLATFORM_API_UPSTREAM_CONTAINER = ghcr.io/tenzir/platform-lambda:$(IMAGE_TAG)
TENZIR_PLATFORM_GATEWAY_UPSTREAM_CONTAINER = ghcr.io/tenzir/platform:$(IMAGE_TAG)

ECR_REPOSITORY_UI = $(shell terraform output -json | jq -r '.ui_repository_url.value')
ECR_REPOSITORY_API = $(shell terraform output -json | jq -r '.platform_api_repository_url.value')
ECR_REPOSITORY_GATEWAY = $(shell terraform output -json | jq -r '.gateway_repository_url.value')

.PHONY: build-ui build-api build-gateway build push-ui push-api push-gateway push login pull echo update

echo:
	@echo "Available targets:"
	@echo "  login         - Login to ECR registry"
	@echo "  build-api     - Build API Docker image"
	@echo "  build-ui      - Build UI Docker image"
	@echo "  build-gateway - Build Gateway Docker image"
	@echo "  pull          - Pull upstream container images"
	@echo "  push-ui       - Tag and push UI image to ECR"
	@echo "  push-api      - Tag and push API image to ECR"
	@echo "  push-gateway  - Tag and push gateway image to ECR"
	@echo "  push          - Push all images (ui, api, gateway)"
	@echo ""
	@echo "ECR Repositories:"
	@echo "  UI:      $(ECR_REPOSITORY_UI)"
	@echo "  API:     $(ECR_REPOSITORY_API)"
	@echo "  Gateway: $(ECR_REPOSITORY_GATEWAY)"

login:
	aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 709825985650.dkr.ecr.us-east-1.amazonaws.com

build-api:
	cd ../../../../backend/platform/tenant_manager && docker build -t $(TENZIR_PLATFORM_API_UPSTREAM_CONTAINER) -f Dockerfile.lambda .

build-gateway:
	cd ../../../components/tenant-manager/platform/tenant_manager && docker build -t $(TENZIR_PLATFORM_GATEWAY_UPSTREAM_CONTAINER) .

build-ui:
	cd ../../../components/app && docker build -t $(TENZIR_UI_UPSTREAM_CONTAINER) .

build: build-api build-gateway build-ui

pull:
	docker pull $(TENZIR_UI_UPSTREAM_CONTAINER)
	docker pull $(TENZIR_PLATFORM_API_UPSTREAM_CONTAINER)
	docker pull $(TENZIR_PLATFORM_GATEWAY_UPSTREAM_CONTAINER)

push-ui: login
	docker tag $(TENZIR_UI_UPSTREAM_CONTAINER) $(ECR_REPOSITORY_UI):$(IMAGE_TAG)
	docker push $(ECR_REPOSITORY_UI):$(IMAGE_TAG)

push-api: login
	docker tag $(TENZIR_PLATFORM_API_UPSTREAM_CONTAINER) $(ECR_REPOSITORY_API):$(IMAGE_TAG)
	docker push $(ECR_REPOSITORY_API):$(IMAGE_TAG)

push-gateway: login
	docker tag $(TENZIR_PLATFORM_GATEWAY_UPSTREAM_CONTAINER) $(ECR_REPOSITORY_GATEWAY):$(IMAGE_TAG)
	docker push $(ECR_REPOSITORY_GATEWAY):$(IMAGE_TAG)

push: push-ui push-api push-gateway

