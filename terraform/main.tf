# ─── main.tf ──────────────────────────────────────────────────────────────────
# Provider configuration for Kubernetes and Helm.
# Targets a local minikube cluster via ~/.kube/config.
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

# ─── Kubernetes Provider ──────────────────────────────────────────────────────
# Reads the active context from ~/.kube/config.
# To target a specific context: export KUBE_CONTEXT=minikube
provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

# ─── Helm Provider ────────────────────────────────────────────────────────────
# Shares the same kubeconfig as the kubernetes provider.
provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}
