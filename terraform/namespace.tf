# ─── namespace.tf ─────────────────────────────────────────────────────────────
# Creates a dedicated namespace with labels for all app resources.
# Isolates the application from the default namespace.
# ──────────────────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.namespace

    labels = {
      name        = var.namespace
      app         = var.app_name
      environment = var.app_env
      managed-by  = "terraform"
    }

    annotations = {
      "description" = "Namespace for ${var.app_name} (${var.app_env})"
    }
  }
}
