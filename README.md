# devops-takehome

> TWIN — Senior Platform Engineer Take-Home Assignment  
> A production-grade Node.js application deployed to Kubernetes via Terraform

---

## Quick Start (for reviewers)

```bash
# Prerequisites: minikube, kubectl, terraform, docker

# 1. Start minikube (if not running)
minikube start

# 2. Copy tfvars and set your image name
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars if you need to override any defaults

# 3. Deploy
cd terraform
terraform init
terraform apply

# 4. Open in browser
minikube service devops-takehome -n devops-takehome

# 5. Or use port-forward
kubectl port-forward svc/devops-takehome 8080:80 -n devops-takehome
open http://localhost:8080
```

---

## Docker Image

```
vincentchrisbone/devops-takehome:latest
```

> **Docker Hub image:** `vincentchrisbone/devops-takehome:latest`

Build and push:

```bash
cd app
docker build -t vincentchrisbone/devops-takehome:latest .
docker push vincentchrisbone/devops-takehome:latest
```

---

## Prerequisites

| Tool        | Min Version | Install                                  |
|-------------|-------------|------------------------------------------|
| minikube    | 1.32+       | https://minikube.sigs.k8s.io/docs/start  |
| kubectl     | 1.28+       | https://kubernetes.io/docs/tasks/tools   |
| Terraform   | 1.6+        | https://developer.hashicorp.com/terraform/install |
| Docker      | 24+         | https://docs.docker.com/get-docker       |
| Node.js     | 20+         | https://nodejs.org (for local dev only)  |

---

## Repository Structure

```
devops-takehome/
├── app/                        # Node.js application
│   ├── src/
│   │   ├── server.js           # Entry point with graceful shutdown
│   │   ├── app.js              # Express app, middleware chain
│   │   ├── logger.js           # Winston structured logger
│   │   ├── middleware/
│   │   │   ├── requestId.js    # X-Request-ID header injection
│   │   │   └── errorHandler.js # Centralized error handling
│   │   ├── routes/
│   │   │   ├── health.js       # /health, /health/ready, /health/live
│   │   │   ├── api.js          # /api/info
│   │   │   └── metrics.js      # /metrics (Prometheus)
│   │   └── public/
│   │       └── index.html      # Status dashboard UI
│   ├── tests/
│   │   └── app.test.js         # Jest unit tests
│   ├── Dockerfile              # Multi-stage production image
│   ├── .dockerignore
│   ├── .eslintrc.json
│   └── package.json
├── terraform/
│   ├── main.tf                 # Provider configuration
│   ├── variables.tf            # All input variables
│   ├── locals.tf               # Shared labels and locals
│   ├── outputs.tf              # Deployment outputs
│   ├── namespace.tf            # Kubernetes namespace
│   ├── configmap.tf            # Non-sensitive config
│   ├── secrets.tf              # Sensitive config (Opaque secret)
│   ├── deployment.tf           # Kubernetes Deployment
│   ├── service.tf              # Kubernetes Service (NodePort)
│   └── terraform.tfvars.example
├── .github/workflows/
│   ├── build.yaml              # Lint → Test → Docker Build & Push
│   └── terraform.yaml          # fmt → validate → tfsec
├── docs/
│   └── runbook.md              # Operational procedures
├── Makefile                    # Common developer commands
└── README.md
```

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Developer Workstation                                   │
│                                                          │
│  ┌──────────┐    docker push     ┌─────────────────────┐ │
│  │  Docker  │ ─────────────────► │    Docker Hub       │ │
│  │  Build   │                    │ vincentchrisbone/app│ │
│  └──────────┘                    └─────────────────────┘ │
│                                           │               │
│  ┌──────────┐  terraform apply            │               │
│  │Terraform │ ──────────────────────────► │               │
│  └──────────┘         │                  │               │
│                        │                  │               │
│              ┌─────────▼────────────────────────────────┐│
│              │  minikube (local Kubernetes cluster)     ││
│              │                                          ││
│              │  Namespace: devops-takehome              ││
│              │  ┌───────────────────────────────────┐   ││
│              │  │  Deployment (1 replica)           │   ││
│              │  │  ┌─────────────────────────────┐  │   ││
│              │  │  │  Pod                        │  │   ││
│              │  │  │  ┌─────────────────────────┐│  │   ││
│              │  │  │  │ Container               ││  │   ││
│              │  │  │  │ image: vincentchrisbone/app ││  │   ││
│              │  │  │  │ port: 3000              ││  │   ││
│              │  │  │  │ user: 1001 (non-root)   ││  │   ││
│              │  │  │  └─────────────────────────┘│  │   ││
│              │  │  └─────────────────────────────┘  │   ││
│              │  └────────────────┬──────────────────┘   ││
│              │                   │                       ││
│              │  ┌────────────────▼──────────────────┐   ││
│              │  │  Service (NodePort :30080)         │   ││
│              │  └───────────────────────────────────┘   ││
│              │                                          ││
│              │  ConfigMap  ──► env vars (APP_ENV, etc.) ││
│              │  Secret     ──► sensitive values         ││
│              └──────────────────────────────────────────┘│
│                        │                                 │
│              ┌─────────▼──────────┐                      │
│              │  Browser           │                      │
│              │  localhost:30080   │                      │
│              └────────────────────┘                      │
└──────────────────────────────────────────────────────────┘
```

---

## API Endpoints

| Method | Path           | Description                              |
|--------|---------------|------------------------------------------|
| GET    | `/`           | Status dashboard (HTML)                  |
| GET    | `/health`     | Liveness: `{"status":"ok"}`              |
| GET    | `/health/live` | Liveness alias                          |
| GET    | `/health/ready` | Readiness with uptime + checks         |
| GET    | `/api/info`   | Version, environment, timestamp, memory  |
| GET    | `/metrics`    | Prometheus metrics                       |

---

## Design Decisions

### Why Express over Fastify/Koa?

Express has the most mature ecosystem for middleware (helmet, morgan, rate-limit), making it the safest choice for production readiness in a take-home assignment where breadth of security configuration matters.

### Why multi-stage Docker build?

Stage 1 (`deps`) installs only production deps. Stage 2 (`builder`) runs linting and tests. Stage 3 (`production`) copies only the final artifacts. This means: lint/test failures block the image build, the final image is minimal (~150MB vs ~1GB), and there are no dev tools in production.

### Why read-only root filesystem?

Combined with a non-root user and `capabilities.drop = ["ALL"]`, this enforces the principle of least privilege. The only writable path is `/tmp` (an EmptyDir volume). This significantly limits the blast radius of a container escape.

### Why separate liveness/readiness/startup probes?

- **Startup probe**: gives the app up to 50s to start before liveness begins — prevents premature restarts of slow-starting apps.
- **Liveness probe**: restarts the container if the app deadlocks or hangs.
- **Readiness probe**: removes the pod from load balancing during transient errors without restarting it.

### Why NodePort instead of LoadBalancer?

minikube doesn't provision real load balancers. NodePort works reliably with `minikube service`. In production, swap to `ClusterIP` + Ingress.

### Trade-offs

| Decision | Alternative | Why this was chosen |
|----------|-------------|----------------------|
| Terraform Kubernetes provider | Helm chart | Direct resource management is more explicit and educational |
| ConfigMap for env vars | Direct deployment env | Separation of config from code; reusable across deployments |
| Prometheus via prom-client | External sidecar | Self-contained; no extra pods required for local dev |

---

## Improvements (with more time)

- **Horizontal Pod Autoscaler (HPA)** — autoscale based on CPU/memory metrics
- **PodDisruptionBudget** — ensure minimum availability during node maintenance
- **Ingress + cert-manager** — TLS termination and hostname-based routing
- **External Secrets Operator** — replace Kubernetes Secrets with Vault/AWS Secrets Manager
- **OpenTelemetry** — distributed tracing with Jaeger or Tempo
- **Grafana + Prometheus stack** — via kube-prometheus-stack Helm chart
- **Renovate Bot** — automated dependency updates
- **Remote Terraform state** — S3 + DynamoDB locking for team use

---

## Local Development

```bash
cd app
npm install
APP_ENV=local APP_VERSION=1.0.0 APP_PORT=3000 npm run dev
# App running at http://localhost:3000
```

Run tests:

```bash
npm test
npm run test:watch
```

---

## Makefile Commands

```bash
make help        # Show all available commands
make build       # Build Docker image
make push        # Push to Docker Hub
make deploy      # terraform init + apply
make destroy     # terraform destroy
make dev         # Run app locally
make test        # Run tests
make logs        # Stream pod logs
make status      # Show k8s resources
```

---

## Documentation

- [Runbook](docs/runbook.md) — Operational procedures (logs, restart, scale, clean up)
