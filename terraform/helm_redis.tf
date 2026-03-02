# ─── helm_redis.tf ────────────────────────────────────────────────────────────
# Deploys Bitnami Redis in standalone (single-master) mode.
# Used by the app as a cache store via REDIS_URL env var.
#
# Service DNS inside cluster:
#   redis-master.<namespace>.svc.cluster.local:6379
# ──────────────────────────────────────────────────────────────────────────────

resource "helm_release" "redis" {
  name       = "redis"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  version    = "~18.0"
  namespace  = kubernetes_namespace.app.metadata[0].name

  # Wait until all pods are ready before Terraform marks as complete.
  wait            = true
  wait_for_jobs   = true
  timeout         = 300
  cleanup_on_fail = true

  # ── Chart Values ─────────────────────────────────────────────────────────────
  # Using the values block is the canonical way to pass complex configuration.
  # This avoids individual set blocks and is easier to diff/review.
  values = [
    yamlencode({
      # Standalone mode: one master pod, no replicas / sentinel.
      # Suitable for minikube; swap to "replication" for production HA.
      architecture = "standalone"

      auth = {
        enabled  = true
        password = var.redis_password
      }

      master = {
        # Disable PVC — Redis is used purely as a cache in this setup.
        # Enable if you need session durability across pod restarts.
        persistence = {
          enabled = false
        }

        resources = {
          requests = { cpu = "50m", memory = "64Mi" }
          limits   = { cpu = "250m", memory = "128Mi" }
        }
      }

      # Disable Prometheus exporter sidecar to keep resource footprint minimal.
      metrics = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.app]
}
