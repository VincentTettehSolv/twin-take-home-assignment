# ─── locals.tf ────────────────────────────────────────────────────────────────
# Shared local values used across all resources.
# Centralizing labels ensures consistency and simplifies updates.
# ──────────────────────────────────────────────────────────────────────────────

locals {
  # Standard Kubernetes recommended labels
  # https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/
  common_labels = {
    "app.kubernetes.io/name"       = var.app_name
    "app.kubernetes.io/version"    = var.app_version
    "app.kubernetes.io/component"  = "backend"
    "app.kubernetes.io/managed-by" = "terraform"
    "environment"                  = var.app_env
  }

  # Selector labels must be stable — never change after initial deployment
  selector_labels = {
    "app.kubernetes.io/name" = var.app_name
  }
}
