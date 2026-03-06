# ─── ingress.tf ───────────────────────────────────────────────────────────────
# Kubernetes Ingress resource — routes external traffic to the app service
# via the NGINX ingress controller installed by the minikube ingress addon.
#
# Controlled by var.enable_ingress. Set to false to skip creation entirely.
#
# Local access:  http://twin-app.local  (after /etc/hosts is patched)
# ──────────────────────────────────────────────────────────────────────────────

resource "kubernetes_ingress_v1" "app" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.app.metadata[0].name
    labels    = local.common_labels

    annotations = {
      # Use the NGINX ingress class provided by the minikube addon
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
      # Disables SSL redirect so plain http works locally
      "nginx.ingress.kubernetes.io/ssl-redirect" = "false"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = var.ingress_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.app]
}
