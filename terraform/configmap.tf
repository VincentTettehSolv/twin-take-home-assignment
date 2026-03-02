# ─── configmap.tf ─────────────────────────────────────────────────────────────
# ConfigMap holds non-sensitive runtime configuration.
# Environment-specific values are injected from Terraform variables.
# ──────────────────────────────────────────────────────────────────────────────

resource "kubernetes_config_map" "app" {
  metadata {
    name      = "${var.app_name}-config"
    namespace = kubernetes_namespace.app.metadata[0].name

    labels = local.common_labels

    annotations = {
      "description" = "Non-sensitive configuration for ${var.app_name}"
    }
  }

  data = {
    APP_ENV     = var.app_env
    APP_VERSION = var.app_version
    APP_PORT    = tostring(var.app_port)
    LOG_LEVEL   = var.log_level
    NODE_ENV    = var.app_env == "production" ? "production" : "development"
  }
}
