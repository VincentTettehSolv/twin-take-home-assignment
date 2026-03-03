# ─── helm_postgres.tf ─────────────────────────────────────────────────────────
# Deploys Bitnami PostgreSQL as a StatefulSet with a PersistentVolumeClaim.
# Satisfies the assignment bonus: "StatefulSet — show proper stateful config".
#
# Service DNS inside cluster:
#   postgres-postgresql.<namespace>.svc.cluster.local:5432
# ──────────────────────────────────────────────────────────────────────────────

resource "helm_release" "postgres" {
  name = "postgres"
  # Bitnami PostgreSQL 16+ is published as an OCI artifact only.
  # The legacy HTTP repo (charts.bitnami.com) only carries older versions.
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "postgresql"
  version    = "18.5.1"
  namespace  = kubernetes_namespace.app.metadata[0].name

  wait            = true
  wait_for_jobs   = true
  timeout         = 300
  cleanup_on_fail = true

  # ── Chart Values ─────────────────────────────────────────────────────────────
  values = [
    yamlencode({
      auth = {
        username = var.postgres_user
        password = var.postgres_password
        database = var.postgres_db
      }

      primary = {
        # PostgreSQL uses a StatefulSet with a PVC for data durability.
        # The PVC is bound to minikube's default StorageClass (standard / hostPath).
        # In production, replace with a CSI driver (EBS, Persistent Disk, etc.).
        persistence = {
          enabled = true
          size    = var.postgres_pvc_size
        }

        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "500m", memory = "512Mi" }
        }
      }

      # Disable the Prometheus exporter sidecar for minimal local footprint.
      metrics = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.app]
}
