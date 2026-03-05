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
INGRESS_HOST     ?= twin-app.local

# Colors
GREEN  := \033[0;32m
YELLOW := \033[0;33m
CYAN   := \033[0;36m
RESET  := \033[0m

# ─── Help ─────────────────────────────────────────────────────────────────────
.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "  $(CYAN)twin-devops-takehome — Available Commands$(RESET)"
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
deploy: tf-init ingress-enable ## Enable ingress addon, terraform apply, patch /etc/hosts, open app
	@echo "$(CYAN)Deploying to minikube...$(RESET)"
	cd $(TF_DIR) && terraform apply -auto-approve
	@echo "$(GREEN)✓ Deployment complete$(RESET)"
	@echo ""
	@$(MAKE) hosts-add
	@echo ""
	@echo "$(GREEN)✓ App available at http://$(INGRESS_HOST)$(RESET)"
	@$(MAKE) open-ingress

.PHONY: destroy
destroy: ## Destroy all Kubernetes resources and remove /etc/hosts entry
	@echo "$(YELLOW)WARNING: This will destroy all deployed resources$(RESET)"
	@read -p "Are you sure? [y/N] " confirm && [ $${confirm} = y ]
	@$(MAKE) hosts-remove
	cd $(TF_DIR) && terraform destroy -auto-approve
	@echo "$(GREEN)✓ All resources destroyed$(RESET)"

# ─── Kubernetes Operations ────────────────────────────────────────────────────
.PHONY: open
open: ## Open the app in the browser via minikube service (NodePort)
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
	@echo "$(CYAN)Ingress:$(RESET)"
	@kubectl get ingress -n $(NAMESPACE) 2>/dev/null || echo "  No ingress resources found."
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

# ─── Ingress ──────────────────────────────────────────────────────────────────
.PHONY: ingress-enable
ingress-enable: ## Enable the NGINX ingress addon on minikube and wait for it to be ready
	@echo "$(CYAN)Enabling minikube ingress addon...$(RESET)"
	@minikube addons enable ingress -p $(MINIKUBE_PROFILE)
	@echo "$(CYAN)Waiting for ingress-nginx controller to be ready...$(RESET)"
	@kubectl wait --namespace ingress-nginx \
	  --for=condition=ready pod \
	  --selector=app.kubernetes.io/component=controller \
	  --timeout=120s
	@echo "$(GREEN)✓ Ingress controller ready$(RESET)"

.PHONY: ingress-disable
ingress-disable: ## Disable the NGINX ingress addon on minikube
	@echo "$(YELLOW)Disabling minikube ingress addon...$(RESET)"
	@minikube addons disable ingress -p $(MINIKUBE_PROFILE)
	@echo "$(GREEN)✓ Ingress addon disabled$(RESET)"

.PHONY: hosts-add
hosts-add: ## Add twin-app.local → 127.0.0.1 in /etc/hosts (port-forward/tunnel bind to localhost)
	@if grep -q '$(INGRESS_HOST)' /etc/hosts; then \
	  echo "$(YELLOW)↳ /etc/hosts already contains $(INGRESS_HOST) — skipping$(RESET)"; \
	else \
	  echo "$(CYAN)Adding 127.0.0.1  $(INGRESS_HOST) to /etc/hosts (sudo required)...$(RESET)"; \
	  echo "127.0.0.1  $(INGRESS_HOST)" | sudo tee -a /etc/hosts > /dev/null; \
	  echo "$(GREEN)✓ Added: 127.0.0.1  $(INGRESS_HOST)$(RESET)"; \
	fi

.PHONY: hosts-remove
hosts-remove: ## Remove twin-app.local from /etc/hosts (requires sudo)
	@if grep -q '$(INGRESS_HOST)' /etc/hosts; then \
	  echo "$(CYAN)Removing $(INGRESS_HOST) from /etc/hosts (sudo required)...$(RESET)"; \
	  sudo sed -i '' '/$(INGRESS_HOST)/d' /etc/hosts; \
	  echo "$(GREEN)✓ Removed $(INGRESS_HOST) from /etc/hosts$(RESET)"; \
	else \
	  echo "$(YELLOW)↳ $(INGRESS_HOST) not found in /etc/hosts — nothing to remove$(RESET)"; \
	fi

.PHONY: open-ingress
open-ingress: ## Open the app via the ingress URL in the default browser
	@echo "$(CYAN)Opening http://$(INGRESS_HOST) ...$(RESET)"
	@open http://$(INGRESS_HOST) 2>/dev/null || xdg-open http://$(INGRESS_HOST)

.PHONY: tunnel
tunnel: ## Run minikube tunnel (macOS/Docker driver) — routes minikube network to host; keep running in a separate terminal
	@echo "$(CYAN)Starting minikube tunnel (sudo required, keep this terminal open)...$(RESET)"
	@echo "$(YELLOW)Access the app at http://$(INGRESS_HOST) once the tunnel is established$(RESET)"
	sudo minikube tunnel -p $(MINIKUBE_PROFILE)

.PHONY: ingress-forward
ingress-forward: ## Alternative to tunnel: port-forward ingress-nginx controller to localhost:80 (requires sudo)
	@echo "$(CYAN)Forwarding ingress-nginx → localhost:80 (sudo required, keep this terminal open)...$(RESET)"
	@echo "$(YELLOW)Access the app at http://$(INGRESS_HOST) while this is running$(RESET)"
	sudo kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 80:80

# ─── Utilities ────────────────────────────────────────────────────────────────
.PHONY: minikube-start
minikube-start: ## Start minikube if not running
	@minikube status -p $(MINIKUBE_PROFILE) 2>/dev/null | grep -q 'Running' \
	  || minikube start -p $(MINIKUBE_PROFILE) --driver=docker --cpus=2 --memory=4096 --addons=ingress

.PHONY: clean
clean: ## Remove local node_modules and coverage
	rm -rf $(APP_DIR)/node_modules $(APP_DIR)/coverage
