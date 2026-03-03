# ─── secrets_registry.tf ──────────────────────────────────────────────────────
# Kubernetes docker-registry secret for pulling private Docker Hub images.
# Kubernetes uses this secret as an imagePullSecret on the deployment pod spec.
#
# In production, prefer a workload identity / IRSA approach over a long-lived
# token. For local minikube this is the simplest reliable approach.
# ──────────────────────────────────────────────────────────────────────────────

resource "kubernetes_secret" "docker_registry" {
  # Only create this secret when a token is provided.
  # If docker_hub_token is empty the deployment falls back to anonymous pulls
  # (works for public repos; set the token for private repos).
  count = var.docker_hub_token != "" ? 1 : 0

  metadata {
    name      = "${var.app_name}-registry-secret"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels    = local.common_labels

    annotations = {
      "description" = "Docker Hub image pull credentials for ${var.app_name}"
    }
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    # Kubernetes expects a base64-encoded dockerconfigjson value.
    # Terraform handles the encoding automatically via the jsonencode call.
    ".dockerconfigjson" = jsonencode({
      auths = {
        "https://index.docker.io/v1/" = {
          username = var.docker_hub_username
          password = var.docker_hub_token
          auth     = base64encode("${var.docker_hub_username}:${var.docker_hub_token}")
        }
      }
    })
  }
}
