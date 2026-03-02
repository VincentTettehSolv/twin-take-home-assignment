# ─── deployment.tf ────────────────────────────────────────────────────────────
# Kubernetes Deployment with:
#   - Configurable replicas
#   - Resource requests & limits
#   - Liveness and readiness probes
#   - Security context (non-root)
#   - Environment injection from ConfigMap + Secret
#   - Rolling update strategy
# ──────────────────────────────────────────────────────────────────────────────

resource "kubernetes_deployment" "app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.app.metadata[0].name
    labels    = local.common_labels

    annotations = {
      "description" = "Deployment for ${var.app_name} v${var.app_version}"
    }
  }

  spec {
    replicas = var.replicas

    # ── Selector ────────────────────────────────────────────────────────────
    # Must remain immutable after creation.
    selector {
      match_labels = local.selector_labels
    }

    # ── Rolling Update Strategy ─────────────────────────────────────────────
    # Zero-downtime deployments: bring up 1 new pod before taking down 1 old.
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "1"
        max_unavailable = "0"
      }
    }

    # ── Pod Template ────────────────────────────────────────────────────────
    template {
      metadata {
        labels = merge(local.common_labels, local.selector_labels)

        annotations = {
          # Forces pod replacement when ConfigMap or Secret changes
          "checksum/config" = sha256(jsonencode(kubernetes_config_map.app.data))
          "checksum/secret" = sha256(jsonencode(kubernetes_secret.app.data))

          # Prometheus scrape annotations
          "prometheus.io/scrape" = "true"
          "prometheus.io/path"   = "/metrics"
          "prometheus.io/port"   = tostring(var.app_port)
        }
      }

      spec {
        # ── Security Context (Pod) ─────────────────────────────────────────
        security_context {
          run_as_non_root = true
          run_as_user     = 1001
          run_as_group    = 1001
          fs_group        = 1001

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        # ── Termination Grace Period ──────────────────────────────────────
        # Gives the app time to finish in-flight requests during shutdown.
        termination_grace_period_seconds = 30

        container {
          name              = var.app_name
          image             = var.image_name
          image_pull_policy = var.image_pull_policy

          # ── Ports ───────────────────────────────────────────────────────
          port {
            name           = "http"
            container_port = var.app_port
            protocol       = "TCP"
          }

          # ── Environment — ConfigMap ──────────────────────────────────────
          env_from {
            config_map_ref {
              name = kubernetes_config_map.app.metadata[0].name
            }
          }

          # ── Environment — Secrets ────────────────────────────────────────
          env_from {
            secret_ref {
              name = kubernetes_secret.app.metadata[0].name
            }
          }

          # ── Downward API — pod metadata as env vars ─────────────────────
          env {
            name = "POD_NAME"
            value_from {
              field_ref { field_path = "metadata.name" }
            }
          }
          env {
            name = "POD_NAMESPACE"
            value_from {
              field_ref { field_path = "metadata.namespace" }
            }
          }
          env {
            name = "POD_IP"
            value_from {
              field_ref { field_path = "status.podIP" }
            }
          }

          # ── Resource Requests & Limits ───────────────────────────────────
          resources {
            requests = {
              cpu    = var.resources.requests.cpu
              memory = var.resources.requests.memory
            }
            limits = {
              cpu    = var.resources.limits.cpu
              memory = var.resources.limits.memory
            }
          }

          # ── Liveness Probe ───────────────────────────────────────────────
          # Restarts the container if the app becomes unresponsive.
          liveness_probe {
            http_get {
              path   = "/health/live"
              port   = var.app_port
              scheme = "HTTP"
            }
            initial_delay_seconds = 15
            period_seconds        = 20
            timeout_seconds       = 5
            failure_threshold     = 3
            success_threshold     = 1
          }

          # ── Readiness Probe ──────────────────────────────────────────────
          # Removes the pod from Service endpoints if not ready to serve traffic.
          readiness_probe {
            http_get {
              path   = "/health/ready"
              port   = var.app_port
              scheme = "HTTP"
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 3
            failure_threshold     = 3
            success_threshold     = 1
          }

          # ── Startup Probe ────────────────────────────────────────────────
          # Gives slow-starting apps extra time before liveness kicks in.
          startup_probe {
            http_get {
              path   = "/health"
              port   = var.app_port
              scheme = "HTTP"
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 10 # 50 seconds total window
          }

          # ── Security Context (Container) ─────────────────────────────────
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            run_as_user                = 1001

            capabilities {
              drop = ["ALL"]
            }
          }

          # ── Volume Mounts ────────────────────────────────────────────────
          # Required when read_only_root_filesystem = true
          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        # ── Volumes ─────────────────────────────────────────────────────────
        volume {
          name = "tmp"
          empty_dir {}
        }
      }
    }
  }

  # Ignore changes to replica count if HPA is managing it
  lifecycle {
    ignore_changes = [
      spec[0].replicas
    ]
  }

  depends_on = [
    kubernetes_config_map.app,
    kubernetes_secret.app,
  ]
}
