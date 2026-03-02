# ─── variables.tf ─────────────────────────────────────────────────────────────
# All configurable input variables.
# Override via terraform.tfvars or -var flags.
# ──────────────────────────────────────────────────────────────────────────────

# ─── Cluster Configuration ────────────────────────────────────────────────────

variable "kubeconfig_path" {
  type        = string
  description = "Path to the kubeconfig file."
  default     = "~/.kube/config"
}

variable "kube_context" {
  type        = string
  description = "Kubernetes context to use. Defaults to the active context."
  default     = "minikube"
}

# ─── Application Configuration ────────────────────────────────────────────────

variable "image_name" {
  type        = string
  description = "Full Docker Hub image reference (e.g. vincentchrisbone/twin-app:latest)."
  default     = "vincentchrisbone/twin-app:latest"
}

variable "image_pull_policy" {
  type        = string
  description = "Kubernetes imagePullPolicy. Use 'Always' for latest tags."
  default     = "Always"

  validation {
    condition     = contains(["Always", "IfNotPresent", "Never"], var.image_pull_policy)
    error_message = "image_pull_policy must be Always, IfNotPresent, or Never."
  }
}

variable "app_name" {
  type        = string
  description = "Application name used for Kubernetes resource naming and labels."
  default     = "devops-takehome"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace to deploy into."
  default     = "devops-takehome"
}

variable "app_env" {
  type        = string
  description = "Runtime environment: local, staging, or production."
  default     = "local"

  validation {
    condition     = contains(["local", "staging", "production"], var.app_env)
    error_message = "app_env must be local, staging, or production."
  }
}

variable "app_version" {
  type        = string
  description = "Application version string surfaced in /api/info."
  default     = "1.0.0"
}

variable "app_port" {
  type        = number
  description = "Port the Node.js application listens on inside the container."
  default     = 3000
}

# ─── Deployment Configuration ─────────────────────────────────────────────────

variable "replicas" {
  type        = number
  description = "Number of pod replicas. Increase for HA in staging/production."
  default     = 1

  validation {
    condition     = var.replicas >= 1 && var.replicas <= 10
    error_message = "replicas must be between 1 and 10."
  }
}

variable "resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Container resource requests and limits."
  default = {
    requests = { cpu = "50m", memory = "64Mi" }
    limits   = { cpu = "250m", memory = "256Mi" }
  }
}

# ─── Service Configuration ────────────────────────────────────────────────────

variable "service_type" {
  type        = string
  description = "Kubernetes Service type: NodePort or ClusterIP."
  default     = "NodePort"

  validation {
    condition     = contains(["NodePort", "ClusterIP", "LoadBalancer"], var.service_type)
    error_message = "service_type must be NodePort, ClusterIP, or LoadBalancer."
  }
}

variable "node_port" {
  type        = number
  description = "NodePort to bind the service to (30000–32767). 0 = auto-assign."
  default     = 30080
}

# ─── Observability ────────────────────────────────────────────────────────────

variable "log_level" {
  type        = string
  description = "Application log level: debug, info, warn, error."
  default     = "info"
}

# ─── Redis Configuration ──────────────────────────────────────────────────────

variable "redis_password" {
  type        = string
  description = "Password for the Bitnami Redis Helm release."
  default     = "redispass"
  sensitive   = true
}

# ─── PostgreSQL Configuration ─────────────────────────────────────────────────

variable "postgres_user" {
  type        = string
  description = "PostgreSQL application username."
  default     = "appuser"
}

variable "postgres_password" {
  type        = string
  description = "PostgreSQL application user password."
  default     = "pgpassword"
  sensitive   = true
}

variable "postgres_db" {
  type        = string
  description = "PostgreSQL database name."
  default     = "appdb"
}

variable "postgres_pvc_size" {
  type        = string
  description = "Size of the PersistentVolumeClaim for PostgreSQL data."
  default     = "1Gi"
}
