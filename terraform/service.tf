# ─── service.tf ───────────────────────────────────────────────────────────────
# Kubernetes Service exposes the application.
# Uses NodePort for local minikube access.
# In production, pair with a LoadBalancer or Ingress controller.
# ──────────────────────────────────────────────────────────────────────────────

resource "kubernetes_service" "app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.app.metadata[0].name
    labels    = local.common_labels

    annotations = {
      "description" = "Service for ${var.app_name}"
    }
  }

  spec {
    type     = var.service_type
    selector = local.selector_labels

    port {
      name        = "http"
      port        = 80
      target_port = var.app_port
      protocol    = "TCP"

      # Only set node_port for NodePort/LoadBalancer types
      node_port = var.service_type == "NodePort" ? var.node_port : null
    }

    # Ensures client IPs are not obscured behind the node IP
    external_traffic_policy = var.service_type == "NodePort" ? "Local" : null
  }

  depends_on = [kubernetes_deployment.app]
}
