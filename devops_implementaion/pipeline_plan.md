# DevOps Pipeline — Full Project Plan

> **Goal:** Build a production-grade DevOps pipeline from scratch, covering every
> layer of modern DevOps: CI/CD, IaC, Config Management, Containers, GitOps, Monitoring.
>
> **App:** Go Web App (`saurabhhub1/go-web-app`)
> **Style:** Each phase is independent and builds on the previous one.

---

## OVERALL ARCHITECTURE

```
Developer pushes code
        │
        ▼
┌──────────────────────────────────────────────────────────────────┐
│  PHASE 1 — CI/CD (LOCAL)                              ✅ DONE    │
│                                                                  │
│  GitHub ──► Jenkins (Vagrant VM)                                 │
│               ├── go test ./...                                  │
│               ├── docker build                                   │
│               ├── docker push → DockerHub                        │
│               └── update Helm values.yaml (image tag)           │
└──────────────────────────────────────────────────────────────────┘
        │  values.yaml updated in GitHub
        ▼
┌──────────────────────────────────────────────────────────────────┐
│  PHASE 2 — INFRASTRUCTURE (AWS)                       🔲 NEXT   │
│                                                                  │
│  Terraform provisions:                                           │
│    EC2 instances (for K8s nodes)                                 │
│    Security Groups (firewall rules)                              │
│    Key Pairs (SSH access)                                        │
│    Application Load Balancer (ALB)                               │
│    Route 53 DNS (domain → ALB)                                   │
│    VPC + Subnets + Internet Gateway                              │
└──────────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────────────┐
│  PHASE 3 — CONFIGURATION MANAGEMENT                   🔲        │
│                                                                  │
│  Ansible configures EC2 instances:                               │
│    Install Docker                                                │
│    Install Kubernetes (kubeadm / k3s)                            │
│    Configure users + SSH                                         │
│    Set up K8s cluster (master + worker nodes)                    │
└──────────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────────────┐
│  PHASE 4 — KUBERNETES + HELM DEPLOYMENT               🔲        │
│                                                                  │
│  Helm chart deploys app to K8s cluster:                          │
│    Deployment (replicas, rolling update)                         │
│    Service (ClusterIP / NodePort)                                │
│    Ingress (routes traffic from ALB)                             │
│    ConfigMap / Secrets                                           │
└──────────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────────────┐
│  PHASE 5 — GITOPS with ARGO CD                        🔲        │
│                                                                  │
│  Argo CD watches GitHub repo                                     │
│    Jenkins updates values.yaml → Argo CD detects change         │
│    Argo CD auto-deploys new image tag to K8s                     │
│    Live sync: GitHub = source of truth for cluster state         │
└──────────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────────────┐
│  PHASE 6 — MONITORING (Prometheus + Grafana)          🔲        │
│                                                                  │
│  Prometheus scrapes metrics from:                                │
│    Go app (custom /metrics endpoint)                             │
│    K8s nodes (node-exporter)                                     │
│    K8s cluster (kube-state-metrics)                              │
│  Grafana dashboards:                                             │
│    App health, request rate, error rate                          │
│    Node CPU/memory/disk                                          │
│    Alert rules (PagerDuty / Slack)                               │
└──────────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────────────┐
│  PHASE 7 — AUTOMATION SCRIPTS (Python + Bash)         🔲        │
│                                                                  │
│  Python scripts:                                                 │
│    Trigger Jenkins builds via API                                │
│    Health check script (hits /health endpoint)                   │
│    Deployment verification (checks K8s pods)                     │
│    Rollback trigger (if health check fails)                      │
│  Bash scripts: (already started with Vagrant provisioning)       │
└──────────────────────────────────────────────────────────────────┘
```

---

## PHASE 1 — CI/CD Pipeline ✅ COMPLETED

### Tools Used
| Tool | Purpose |
|---|---|
| Git | Version control, source of truth |
| GitHub | Remote repo hosting + push protection |
| Jenkins | CI/CD automation (runs on Vagrant VM) |
| Docker | Containerize the Go app |
| DockerHub | Remote container image registry |
| Vagrant | Local VM provisioning for Jenkins |
| Bash | `provision_jenkins.sh` — auto-install Jenkins, Docker, Go |

### What Was Built
- Jenkins VM spun up via `vagrant up` (auto-installs Java, Jenkins, Docker, Go)
- Jenkins pipeline: 7 stages (checkout → test → version → build → approve → push → helm update)
- SSH key authentication (laptop → GitHub, Jenkins VM → GitHub, Jenkins GUI credentials)
- DockerHub credentials stored securely in `/var/lib/jenkins/dockerhub_creds.env`
- Helm `values.yaml` updated with new image tag after each successful push
- Unified repo structure: Go source + DevOps files on same `main` branch

### Result
```
docker pull saurabhhub1/go-web-app:v1.1  ✅ live on DockerHub
```

### Files Created
```
devops_implementaion/
├── Jenkinsfile                          ← 7-stage declarative pipeline
├── Dockerfile                           ← multi-stage build (golang → distroless)
├── jenkins_vagrant_server/
│   ├── Vagrantfile                      ← Jenkins VM definition
│   └── provision_jenkins.sh             ← auto-provisioning script (Bash)
├── flow_and_commands.md                 ← complete command reference
└── NOTES.md                             ← troubleshooting + architecture notes
```

---

## PHASE 2 — Infrastructure as Code (Terraform + AWS) 🔲

### What is Terraform?
Terraform is an IaC tool. Instead of clicking in the AWS console to create EC2 instances,
Security Groups, Load Balancers — you write `.tf` files and run `terraform apply`.
Everything is declarative, version-controlled, and reproducible.

### Tools Used
| Tool | Purpose |
|---|---|
| Terraform | Provision AWS infrastructure |
| AWS EC2 | Virtual machines for K8s nodes |
| AWS Security Groups | Firewall rules (which ports are open) |
| AWS Key Pairs | SSH key for EC2 access |
| AWS ALB | Application Load Balancer (distributes traffic) |
| AWS Route 53 | DNS (map domain → ALB) |
| AWS VPC | Virtual Private Cloud (network isolation) |

### What We'll Build
```
AWS Account
└── VPC (10.0.0.0/16)
    ├── Public Subnet (10.0.1.0/24)
    │   └── ALB  ← internet-facing entry point
    ├── Private Subnet (10.0.2.0/24)
    │   ├── EC2 — K8s Master Node
    │   └── EC2 — K8s Worker Node(s)
    └── Security Groups
        ├── ALB SG  (allow 80, 443 from internet)
        ├── K8s SG  (allow 6443 from ALB SG, 22 from your IP)
        └── App SG  (allow 8080 from ALB SG)
```

### Terraform File Structure (planned)
```
devops_implementaion/terraform/
├── main.tf           ← core resources (EC2, SG, ALB)
├── variables.tf      ← input variables (region, instance type, etc.)
├── outputs.tf        ← outputs (EC2 IPs, ALB DNS)
├── vpc.tf            ← VPC + subnets + IGW
├── dns.tf            ← Route 53 record
└── terraform.tfvars  ← variable values (gitignored — has secrets)
```

### Key Terraform Commands
```bash
terraform init        # download providers
terraform plan        # preview what will be created
terraform apply       # create the infrastructure
terraform destroy     # tear it all down
terraform output      # show outputs (EC2 IPs, ALB DNS)
```

---

## PHASE 3 — Configuration Management (Ansible) 🔲

### What is Ansible?
Ansible is a configuration management tool. After Terraform creates the EC2 instances,
Ansible SSHes into them and configures them (installs software, sets up users, joins K8s cluster).
No agent needed — Ansible only requires SSH access.

### Tools Used
| Tool | Purpose |
|---|---|
| Ansible | Configure EC2 instances after Terraform creates them |
| Ansible Playbooks | YAML files that describe what to configure |
| Ansible Inventory | List of servers to configure (dynamic from Terraform output) |

### Ansible vs Terraform
| Terraform | Ansible |
|---|---|
| Creates infrastructure (EC2, VPC, SG) | Configures infrastructure (install Docker, K8s) |
| Declarative (what state to reach) | Procedural (what steps to run) |
| Idempotent (safe to re-apply) | Mostly idempotent |
| "Build the house" | "Furnish the house" |

### What Ansible Will Do
```
Ansible Playbooks:
├── install_docker.yml     → install Docker CE on EC2
├── install_k8s.yml        → install kubeadm, kubelet, kubectl
├── setup_master.yml       → kubeadm init on master node
├── join_workers.yml       → kubeadm join on worker nodes
└── deploy_app.yml         → deploy go-web-app via Helm
```

---

## PHASE 4 — Kubernetes + Helm Deployment 🔲

### What is Kubernetes (K8s)?
Kubernetes orchestrates containers at scale.
Instead of running `docker run` manually, K8s manages containers across multiple machines,
handles restarts, scaling, rolling updates, and self-healing.

### What is Helm?
Helm is the package manager for Kubernetes.
A Helm chart is a reusable template for deploying an app to K8s.
Our project already has `helm/go-web-app-chart/` with a `values.yaml` — Helm-ready!

### K8s Objects Our App Uses
| Object | Purpose |
|---|---|
| Deployment | Runs N replicas of go-web-app, handles rolling updates |
| Service | Internal load balancing between pods |
| Ingress | Routes external traffic (from ALB) to the Service |
| ConfigMap | Non-secret configuration (env vars) |
| Secret | Sensitive config (DockerHub token, DB password) |
| HPA | Horizontal Pod Autoscaler (scale up under load) |

### Helm Commands
```bash
helm install go-web-app ./helm/go-web-app-chart    # first deploy
helm upgrade go-web-app ./helm/go-web-app-chart    # update (e.g. new image tag)
helm rollback go-web-app 1                         # rollback to revision 1
helm list                                          # list all releases
helm history go-web-app                            # show deploy history
```

---

## PHASE 5 — GitOps with Argo CD 🔲

### What is Argo CD?
Argo CD is a GitOps continuous delivery tool for Kubernetes.
It watches a Git repo (specifically your Helm chart `values.yaml`) and automatically
syncs the K8s cluster to match what's in Git.

### The GitOps Flow
```
Jenkins pushes new image tag to values.yaml (on GitHub)
        │
        │  Argo CD polls GitHub every 3 min (or webhook)
        ▼
Argo CD detects: values.yaml changed (tag: v1.1 → v1.2)
        │
        ▼
Argo CD runs: helm upgrade go-web-app ./helm/go-web-app-chart
        │
        ▼
K8s cluster updated: new pods with v1.2 image rolling out
        │
        ▼
Old pods terminated after new pods are healthy
```

### Why GitOps?
- **Git = single source of truth** for what's deployed
- **Audit trail** — every deployment is a git commit
- **Easy rollback** — `git revert` = rollback deployment
- **No kubectl in CI/CD** — Argo CD handles K8s, Jenkins just pushes to Git

---

## PHASE 6 — Monitoring (Prometheus + Grafana) 🔲

### What is Prometheus?
Prometheus is a metrics database. It scrapes `/metrics` endpoints from apps
and stores time-series data (CPU usage, request count, error rate, etc.)

### What is Grafana?
Grafana is a visualization tool. It connects to Prometheus and displays
beautiful dashboards with graphs, alerts, and panels.

### What We'll Monitor
```
Prometheus scrapes:
├── Go app             → /metrics (request count, latency, errors)
├── K8s nodes          → node-exporter (CPU, memory, disk, network)
├── K8s cluster        → kube-state-metrics (pod states, deployments)
└── Jenkins            → jenkins metrics plugin

Grafana Dashboards:
├── App Dashboard      → request rate, error rate, p99 latency
├── Node Dashboard     → CPU, memory, disk per EC2 node
├── K8s Dashboard      → pod health, deployment status
└── Jenkins Dashboard  → build success/failure rate

Alert Rules:
├── App down (no healthy pods)
├── High error rate (>5%)
├── High CPU (>80% for 5 min)
└── Build failure streak
```

### Install via Helm (Prometheus + Grafana stack)
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

---

## PHASE 7 — Automation Scripts (Python + Bash) 🔲

### Bash Scripts (already started)
```
Already done:
└── jenkins_vagrant_server/provision_jenkins.sh   ✅

Planned:
├── scripts/health_check.sh      → curl /health, exit 1 if down
├── scripts/rollback.sh          → helm rollback if health check fails
└── scripts/cleanup.sh           → remove old Docker images from Jenkins VM
```

### Python Scripts (planned)
```python
# trigger_build.py   — trigger Jenkins build via API
import requests
requests.post("http://192.168.56.12:8080/job/go-web-app/build",
              auth=("admin", "token"))

# health_check.py    — check app health after deploy
# verify_deploy.py   — check K8s pods are running
# rollback.py        — trigger helm rollback via subprocess
```

---

## TOOLS SUMMARY — Full Stack

| Phase | Tool | Category | Status |
|---|---|---|---|
| 1 | Git + GitHub | Version Control | ✅ Done |
| 1 | Jenkins | CI — Build, Test, Push | ✅ Done |
| 1 | Docker | Containerization | ✅ Done |
| 1 | DockerHub | Image Registry | ✅ Done |
| 1 | Vagrant | Local VM Provisioning | ✅ Done |
| 1 | Bash | Scripting (provisioning) | ✅ Done |
| 2 | Terraform | IaC — AWS Infrastructure | 🔲 Phase 2 |
| 2 | AWS EC2 | Compute | 🔲 Phase 2 |
| 2 | AWS ALB | Load Balancing | 🔲 Phase 2 |
| 2 | AWS Route 53 | DNS | 🔲 Phase 2 |
| 3 | Ansible | Configuration Management | 🔲 Phase 3 |
| 4 | Kubernetes | Container Orchestration | 🔲 Phase 4 |
| 4 | Helm | K8s Package Manager | 🔲 Phase 4 |
| 5 | Argo CD | GitOps / CD | 🔲 Phase 5 |
| 6 | Prometheus | Metrics Collection | 🔲 Phase 6 |
| 6 | Grafana | Monitoring Dashboards | 🔲 Phase 6 |
| 7 | Python | Automation Scripts | 🔲 Phase 7 |

---

## IS THIS SENIOR DEVOPS LEVEL? YES ✅

A Senior DevOps Engineer is expected to know and have worked with:

| Skill | Covered in This Project |
|---|---|
| CI/CD Pipeline | ✅ Jenkins (Phase 1) |
| Containerization | ✅ Docker multi-stage build (Phase 1) |
| Infrastructure as Code | ✅ Terraform (Phase 2) |
| Cloud (AWS) | ✅ EC2, ALB, Route53, VPC (Phase 2) |
| Configuration Management | ✅ Ansible (Phase 3) |
| Container Orchestration | ✅ Kubernetes (Phase 4) |
| Package Management (K8s) | ✅ Helm (Phase 4) |
| GitOps | ✅ Argo CD (Phase 5) |
| Monitoring + Alerting | ✅ Prometheus + Grafana (Phase 6) |
| Scripting | ✅ Bash + Python (Phases 1 + 7) |
| Version Control | ✅ Git + GitHub (Phase 1) |
| Security | ✅ SSH keys, secrets management, push protection |

> This is not just a tutorial project — this is a REAL pipeline that mirrors
> what companies like Zepto, Razorpay, Flipkart, or any cloud-native startup runs.
> Each phase adds a deployable, explainable piece to your portfolio.

---

## RECOMMENDED ORDER

```
Phase 1  ✅  CI/CD          (Done — Jenkins + Docker)
Phase 2  🔲  Terraform      (Start here — set up AWS infra)
Phase 3  🔲  Ansible        (Configure EC2 from Terraform output)
Phase 4  🔲  K8s + Helm     (Deploy app to cluster)
Phase 5  🔲  Argo CD        (Connect Jenkins → GitHub → K8s auto-deploy)
Phase 6  🔲  Prometheus     (Monitor everything)
Phase 7  🔲  Python scripts (Glue and automation)
```

> Each phase has its own folder in `devops_implementaion/`:
> `terraform/`, `ansible/`, `k8s/`, `helm/`, `scripts/`

---

*Created: 2026-04-07*
*Phase 1 completed: saurabhhub1/go-web-app:v1.1 ✅*
