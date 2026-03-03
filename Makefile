# ─── Makefile ─────────────────────────────────────────────────────────────────
# Common developer and operational commands.
# Run `make help` to see all available targets.
# ──────────────────────────────────────────────────────────────────────────────

SHELL := /bin/bash
.DEFAULT_GOAL := help

# ─── Configuration ────────────────────────────────────────────────────────────
DOCKER_USERNAME  ?= vincentchrisbone99
IMAGE_NAME       := $(DOCKER_USERNAME)/twin-app
IMAGE_TAG        ?= latest
FULL_IMAGE       := $(IMAGE_NAME):$(IMAGE_TAG)
NAMESPACE        := twin-app-ns
APP              := twin-app
TF_DIR           := terraform
APP_DIR          := app
MINIKUBE_PROFILE ?= minikube

# Colors
GREEN  := \033[0;32m
YELLOW := \033[0;33m
CYAN   := \033[0;36m
RESET  := \033[0m

# ─── Help ─────────────────────────────────────────────────────────────────────
.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "  $(CYAN)devops-takehome — Available Commands$(RESET)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

# ─── Application ──────────────────────────────────────────────────────────────
.PHONY: install
install: ## Install Node.js dependencies
	cd $(APP_DIR) && npm ci

.PHONY: dev
dev: ## Run the app locally in watch mode
	cd $(APP_DIR) && APP_ENV=local APP_VERSION=1.0.0 APP_PORT=3000 npm run dev

.PHONY: lint
lint: ## Run ESLint
	cd $(APP_DIR) && npm run lint

.PHONY: lint-fix
lint-fix: ## Run ESLint with auto-fix
	cd $(APP_DIR) && npm run lint:fix

.PHONY: test
test: ## Run Jest tests with coverage
	cd $(APP_DIR) && npm test

.PHONY: test-watch
test-watch: ## Run tests in watch mode
	cd $(APP_DIR) && npm run test:watch

# ─── Docker ───────────────────────────────────────────────────────────────────
.PHONY: build
build: ## Build Docker image locally
	@echo "$(CYAN)Building $(FULL_IMAGE)...$(RESET)"
	docker build -t $(FULL_IMAGE) $(APP_DIR)/
	@echo "$(GREEN)✓ Built $(FULL_IMAGE)$(RESET)"

.PHONY: push
push: build ## Build and push Docker image to Docker Hub
	@echo "$(CYAN)Pushing $(FULL_IMAGE)...$(RESET)"
	docker push $(FULL_IMAGE)
	@echo "$(GREEN)✓ Pushed $(FULL_IMAGE)$(RESET)"

.PHONY: run
run: ## Run the Docker container locally
	docker run --rm -p 3000:3000 \
		-e APP_ENV=local \
		-e APP_VERSION=1.0.0 \
		$(FULL_IMAGE)

# ─── Terraform ────────────────────────────────────────────────────────────────
.PHONY: tf-init
tf-init: ## Initialize Terraform providers
	cd $(TF_DIR) && terraform init

.PHONY: tf-fmt
tf-fmt: ## Format Terraform files
	cd $(TF_DIR) && terraform fmt -recursive

.PHONY: tf-validate
tf-validate: tf-init ## Validate Terraform configuration
	cd $(TF_DIR) && terraform validate

.PHONY: tf-plan
tf-plan: tf-init ## Show Terraform execution plan
	cd $(TF_DIR) && terraform plan

.PHONY: deploy
deploy: tf-init ## Deploy to minikube (terraform apply)
	@echo "$(CYAN)Deploying to minikube...$(RESET)"
	cd $(TF_DIR) && terraform apply -auto-approve
	@echo "$(GREEN)✓ Deployment complete$(RESET)"
	@echo ""
	@$(MAKE) open

.PHONY: destroy
destroy: ## Destroy all Kubernetes resources (terraform destroy)
	@echo "$(YELLOW)WARNING: This will destroy all deployed resources$(RESET)"
	@read -p "Are you sure? [y/N] " confirm && [ $${confirm} = y ]
	cd $(TF_DIR) && terraform destroy -auto-approve
	@echo "$(GREEN)✓ All resources destroyed$(RESET)"

# ─── Kubernetes Operations ────────────────────────────────────────────────────
.PHONY: open
open: ## Open the app in the browser via minikube
	minikube service $(APP) -n $(NAMESPACE) -p $(MINIKUBE_PROFILE)

.PHONY: status
status: ## Show all Kubernetes resources in the namespace
	@echo ""
	@echo "$(CYAN)Pods:$(RESET)"
	@kubectl get pods -n $(NAMESPACE) -o wide
	@echo ""
	@echo "$(CYAN)Services:$(RESET)"
	@kubectl get svc -n $(NAMESPACE)
	@echo ""
	@echo "$(CYAN)Deployments:$(RESET)"
	@kubectl get deployments -n $(NAMESPACE)
	@echo ""

.PHONY: logs
logs: ## Stream pod logs
	kubectl logs -l app.kubernetes.io/name=$(APP) -n $(NAMESPACE) --follow

.PHONY: restart
restart: ## Rolling restart of the deployment
	kubectl rollout restart deployment/$(APP) -n $(NAMESPACE)
	kubectl rollout status deployment/$(APP) -n $(NAMESPACE)

.PHONY: scale
scale: ## Scale replicas (usage: make scale REPLICAS=3)
	REPLICAS ?= 2
	kubectl scale deployment/$(APP) -n $(NAMESPACE) --replicas=$(REPLICAS)

.PHONY: port-forward
port-forward: ## Port-forward service to localhost:8080
	@echo "$(CYAN)Forwarding http://localhost:8080 → $(APP):80 in $(NAMESPACE)$(RESET)"
	kubectl port-forward svc/$(APP) 8080:80 -n $(NAMESPACE)

.PHONY: health
health: ## Check all health endpoints
	@echo "$(CYAN)Checking health endpoints (requires active port-forward or NodePort)...$(RESET)"
	@NODE_PORT=$$(kubectl get svc $(APP) -n $(NAMESPACE) -o jsonpath='{.spec.ports[0].nodePort}'); \
	 MINIKUBE_IP=$$(minikube ip); \
	 BASE="http://$$MINIKUBE_IP:$$NODE_PORT"; \
	 echo "Base URL: $$BASE"; \
	 echo ""; \
	 echo "/health:       $$(curl -sf $$BASE/health)"; \
	 echo "/health/ready: $$(curl -sf $$BASE/health/ready | head -c 100)"; \
	 echo "/api/info:     $$(curl -sf $$BASE/api/info | head -c 100)"

# ─── Utilities ────────────────────────────────────────────────────────────────
.PHONY: minikube-start
minikube-start: ## Start minikube if not running
	@minikube status -p $(MINIKUBE_PROFILE) 2>/dev/null | grep -q 'Running' \
	  || minikube start -p $(MINIKUBE_PROFILE) --driver=docker --cpus=2 --memory=4096 --addons=ingress

.PHONY: clean
clean: ## Remove local node_modules and coverage
	rm -rf $(APP_DIR)/node_modules $(APP_DIR)/coverage
