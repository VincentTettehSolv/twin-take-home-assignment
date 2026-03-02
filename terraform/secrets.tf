# ─── secrets.tf ───────────────────────────────────────────────────────────────
# Kubernetes Secret for sensitive values.
# In production, use an external secret manager (e.g. HashiCorp Vault,
# AWS Secrets Manager, or External Secrets Operator) instead of Terraform state.
# ──────────────────────────────────────────────────────────────────────────────

locals {
  # Internal cluster DNS names produced by the Bitnami Helm charts.
  # These are deterministic based on release name + namespace.
  redis_host    = "redis-master.${var.namespace}.svc.cluster.local"
  postgres_host = "postgres-postgresql.${var.namespace}.svc.cluster.local"
}

resource "kubernetes_secret" "app" {
  metadata {
    name      = "${var.app_name}-secret"
    namespace = kubernetes_namespace.app.metadata[0].name

    labels = local.common_labels

    annotations = {
      "description" = "Sensitive configuration for ${var.app_name}"
    }
  }

  data = {
    # ── Database connections ─────────────────────────────────────────────────
    # Connection strings reference the stable in-cluster DNS names of the
    # Bitnami Helm releases. Override per environment via terraform.tfvars.
    REDIS_URL    = "redis://:${var.redis_password}@${local.redis_host}:6379"
    DATABASE_URL = "postgresql://${var.postgres_user}:${var.postgres_password}@${local.postgres_host}:5432/${var.postgres_db}"
  }

  type = "Opaque"

  depends_on = [
    helm_release.redis,
    helm_release.postgres,
  ]
}
