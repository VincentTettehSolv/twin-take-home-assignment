# Runbook — devops-takehome

Operational procedures for day-to-day management of the `devops-takehome` application running on Kubernetes (minikube).

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Viewing Logs](#viewing-logs)
3. [Restarting the Application](#restarting-the-application)
4. [Scaling Replicas](#scaling-replicas)
5. [Checking Health](#checking-health)
6. [Inspecting Resources](#inspecting-resources)
7. [Updating the Image](#updating-the-image)
8. [Cleaning Up](#cleaning-up)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

```bash
# Set a shell alias for the namespace to avoid repetition
export NS=devops-takehome
export APP=devops-takehome
```

---

## Viewing Logs

### Stream live logs from all pods

```bash
kubectl logs -l app.kubernetes.io/name=$APP -n $NS --follow
```

### View logs from a specific pod

```bash
# List pods first
kubectl get pods -n $NS

# Then tail a specific pod
kubectl logs <pod-name> -n $NS --follow --tail=100
```

### View logs from a previous (crashed) container

```bash
kubectl logs <pod-name> -n $NS --previous
```

### Filter logs by severity (requires jq)

```bash
kubectl logs -l app.kubernetes.io/name=$APP -n $NS | jq 'select(.level == "error")'
```

---

## Restarting the Application

### Rolling restart (zero-downtime)

```bash
# Triggers a rolling restart without changing the deployment spec
kubectl rollout restart deployment/$APP -n $NS
```

### Monitor rollout progress

```bash
kubectl rollout status deployment/$APP -n $NS
```

### Rollback to previous version

```bash
# Roll back to the previous ReplicaSet
kubectl rollout undo deployment/$APP -n $NS

# Roll back to a specific revision
kubectl rollout undo deployment/$APP -n $NS --to-revision=2

# View rollout history
kubectl rollout history deployment/$APP -n $NS
```

---

## Scaling Replicas

### Scale via kubectl (temporary — will be overwritten by next terraform apply)

```bash
kubectl scale deployment/$APP -n $NS --replicas=3
```

### Scale via Terraform (permanent — recommended)

```bash
cd terraform

# Edit terraform.tfvars
# replicas = 3

terraform apply -var="replicas=3"
```

### Check current replica count

```bash
kubectl get deployment/$APP -n $NS
```

---

## Checking Health

### Pod status

```bash
kubectl get pods -n $NS -o wide
```

### Describe a pod (events, probe status)

```bash
kubectl describe pod -l app.kubernetes.io/name=$APP -n $NS
```

### Hit health endpoints via port-forward

```bash
# Forward the service port to localhost
kubectl port-forward svc/$APP 8080:80 -n $NS &

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/health/ready
curl http://localhost:8080/api/info | jq .
curl http://localhost:8080/metrics | head -40
```

### via minikube service URL

```bash
minikube service $APP -n $NS --url
```

---

## Inspecting Resources

### All resources in namespace

```bash
kubectl get all -n $NS
```

### ConfigMap contents

```bash
kubectl get configmap ${APP}-config -n $NS -o yaml
```

### Secret names (values are base64-encoded — do not print in production)

```bash
kubectl get secret ${APP}-secret -n $NS -o yaml
```

### Resource usage (requires metrics-server)

```bash
kubectl top pods -n $NS
```

---

## Updating the Image

### 1. Build and push new image

```bash
cd app
docker build -t vincentchrisbone99/devops-takehome:v1.1.0 .
docker push vincentchrisbone99/devops-takehome:v1.1.0
```

### 2. Update Terraform and apply

```bash
cd ../terraform
terraform apply -var="image_name=vincentchrisbone99/devops-takehome:v1.1.0"
```

### 3. Monitor rollout

```bash
kubectl rollout status deployment/$APP -n $NS
```

---

## Cleaning Up

### Destroy all Terraform-managed resources

```bash
cd terraform
terraform destroy
```

This removes the namespace, deployment, service, configmap, and secret.

### Delete the namespace manually (alternative)

```bash
kubectl delete namespace $NS
```

---

## Troubleshooting

### Pod stuck in `Pending`

```bash
kubectl describe pod -l app.kubernetes.io/name=$APP -n $NS
# Look for: Insufficient cpu/memory, ImagePullBackOff, or scheduling issues
```

**Common causes:**
- Insufficient cluster resources → reduce `resources.requests` in `terraform.tfvars`
- Image not found → verify Docker Hub image name and that the repo is public

### Pod in `CrashLoopBackOff`

```bash
kubectl logs -l app.kubernetes.io/name=$APP -n $NS --previous
```

**Common causes:**
- Application startup error → check logs for uncaught exceptions
- Wrong environment variable → check ConfigMap with `kubectl get configmap`
- Port mismatch → ensure `APP_PORT` matches container port in deployment

### `ImagePullBackOff`

```bash
kubectl describe pod <pod-name> -n $NS
# Check Events section for pull error details
```

**Common causes:**
- Private image without pull secret
- Typo in `image_name` variable
- Docker Hub rate limiting → authenticate with a pull secret

### Service not accessible

```bash
# Confirm service has endpoints
kubectl get endpoints $APP -n $NS

# Confirm pods are Running and Ready
kubectl get pods -n $NS
```

### Terraform apply fails with "connection refused"

```bash
# Ensure minikube is running
minikube status
minikube start

# Verify kubeconfig points to minikube
kubectl config current-context
kubectl config use-context minikube
```
