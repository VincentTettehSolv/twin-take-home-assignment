

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
