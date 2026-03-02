# Terraform — devops-takehome

Deploys the `devops-takehome` Node.js application to a local minikube cluster using the Kubernetes Terraform provider.

---

## Prerequisites

| Tool      | Min Version | Notes                            |
|-----------|-------------|----------------------------------|
| Terraform | 1.6+        | `brew install terraform`         |
| minikube  | 1.32+       | Must be running before `apply`   |
| kubectl   | 1.28+       | Configured to the minikube ctx   |

---

## Quick Start

```bash
# 1. Copy example tfvars (image_name is already set to the correct Docker Hub image)
cp terraform.tfvars.example terraform.tfvars

# 2. (Optional) Edit terraform.tfvars to override any defaults

# 3. Initialise providers
terraform init

# 4. Preview changes
terraform plan

# 5. Deploy
terraform apply

# 6. Open the app in your browser
minikube service devops-takehome -n devops-takehome
```

---

## File Structure

| File | Purpose |
|------|---------|
| `main.tf` | Provider configuration (kubernetes + helm) |
| `variables.tf` | All input variables with types, descriptions, and defaults |
| `locals.tf` | Shared labels (`common_labels`, `selector_labels`) |
| `namespace.tf` | Kubernetes Namespace |
| `configmap.tf` | Non-sensitive runtime config (`APP_ENV`, `APP_VERSION`, `APP_PORT`) |
| `secrets.tf` | Opaque Secret for sensitive values |
| `deployment.tf` | Kubernetes Deployment (probes, resource limits, security context) |
| `service.tf` | Kubernetes Service (NodePort `:30080` by default) |
| `outputs.tf` | Useful post-deploy information |
| `terraform.tfvars.example` | Copy to `terraform.tfvars` and customise |

---

## Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `image_name` | `vincentchrisbone/devops-takehome:latest` | Docker Hub image to deploy |
| `image_pull_policy` | `Always` | `Always`, `IfNotPresent`, or `Never` |
| `app_env` | `local` | Runtime environment name |
| `app_version` | `1.0.0` | Version string surfaced in `/api/info` |
| `replicas` | `1` | Number of pod replicas (1–10) |
| `service_type` | `NodePort` | `NodePort`, `ClusterIP`, or `LoadBalancer` |
| `node_port` | `30080` | NodePort number (30000–32767) |

Override any variable at apply time:

```bash
terraform apply -var="replicas=2" -var="app_env=staging"
```

---

## Resources Created

| Kind | Name | Namespace |
|------|------|-----------|
| Namespace | `devops-takehome` | — |
| ConfigMap | `devops-takehome-config` | `devops-takehome` |
| Secret | `devops-takehome-secret` | `devops-takehome` |
| Deployment | `devops-takehome` | `devops-takehome` |
| Service | `devops-takehome` | `devops-takehome` |

---

## Outputs

After `terraform apply`, run `terraform output` to see:

```
minikube_access_command   # Open app in browser
kubectl_port_forward      # Alternative port-forward access
health_check_urls         # Liveness / readiness / info / metrics URLs
docker_image              # Image in use
node_port                 # NodePort number
kubectl_logs              # Command to stream logs
```

---

## Tear Down

```bash
terraform destroy
```

This removes all resources in the `devops-takehome` namespace.

---

## Troubleshooting

**`connection refused` on apply**
```bash
minikube status   # ensure minikube is running
minikube start
```

**Pod in `ImagePullBackOff`**
- Confirm the Docker Hub repository is **public**
- Verify `image_name` in `terraform.tfvars` matches your pushed image exactly

**Readiness probe failing**
```bash
kubectl describe pod -l app.kubernetes.io/name=devops-takehome -n devops-takehome
kubectl logs -l app.kubernetes.io/name=devops-takehome -n devops-takehome
```

See [../docs/runbook.md](../docs/runbook.md) for full operational procedures.
