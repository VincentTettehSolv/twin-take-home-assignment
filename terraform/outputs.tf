

output "namespace" {
  description = "Kubernetes namespace where the app is deployed."
  value       = kubernetes_namespace.app.metadata[0].name
}

output "deployment_name" {
  description = "Name of the Kubernetes Deployment."
  value       = kubernetes_deployment.app.metadata[0].name
}

output "service_name" {
  description = "Name of the Kubernetes Service."
  value       = kubernetes_service.app.metadata[0].name
}

output "service_type" {
  description = "Type of the Kubernetes Service."
  value       = kubernetes_service.app.spec[0].type
}

output "node_port" {
  description = "NodePort assigned to the service (if NodePort type)."
  value       = var.service_type == "NodePort" ? var.node_port : "N/A (not NodePort)"
}

output "minikube_access_command" {
  description = "Run this command to open the app in your browser via minikube."
  value       = "minikube service ${kubernetes_service.app.metadata[0].name} -n ${kubernetes_namespace.app.metadata[0].name}"
}

output "ingress_url" {
  description = "Ingress URL for the app (requires /etc/hosts entry and ingress addon enabled)."
  value       = var.enable_ingress ? "http://${var.ingress_host}" : "Ingress disabled"
}

output "ingress_hosts_entry" {
  description = "Copy-paste this line into /etc/hosts to enable local ingress access (fill in minikube ip)."
  value       = var.enable_ingress ? "$(minikube ip)  ${var.ingress_host}" : "Ingress disabled"
}

output "kubectl_port_forward" {
  description = "Alternative: use kubectl port-forward to access the app locally."
  value       = "kubectl port-forward svc/${kubernetes_service.app.metadata[0].name} 8080:80 -n ${kubernetes_namespace.app.metadata[0].name}"
}

output "health_check_urls" {
  description = "Health check endpoints (after running minikube service or port-forward)."
  value = {
    liveness  = "http://localhost:8080/health"
    readiness = "http://localhost:8080/health/ready"
    info      = "http://localhost:8080/api/info"
    metrics   = "http://localhost:8080/metrics"
  }
}

output "docker_image" {
  description = "Docker image used in this deployment."
  value       = var.image_name
}

output "environment" {
  description = "Deployment environment."
  value       = var.app_env
}

output "replicas" {
  description = "Number of running replicas."
  value       = var.replicas
}

output "kubectl_logs" {
  description = "Command to stream application logs."
  value       = "kubectl logs -l app.kubernetes.io/name=${var.app_name} -n ${kubernetes_namespace.app.metadata[0].name} --follow"
}

output "redis_service" {
  description = "Redis in-cluster DNS name (accessible from pods in the same namespace)."
  value       = "redis-master.${var.namespace}.svc.cluster.local:6379"
}

output "postgres_service" {
  description = "PostgreSQL in-cluster DNS name (accessible from pods in the same namespace)."
  value       = "postgres-postgresql.${var.namespace}.svc.cluster.local:5432"
}

output "postgres_connect_command" {
  description = "kubectl exec command to open a psql shell in the Postgres pod."
  value       = "kubectl exec -it -n ${var.namespace} $(kubectl get pod -n ${var.namespace} -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}') -- psql -U ${var.postgres_user} -d ${var.postgres_db}"
}
