# Senior DevOps Engineer — What to Add Next

> This file lists what a senior DevOps engineer would add on top of what we've already built.
> Organized by phase. Items marked ⭐ are high-value and commonly expected in interviews/real jobs.
> Items marked 🔲 are not implemented yet.

---

## PHASE 1 — Jenkins CI/CD Enhancements

### Notifications
| What | Why | How |
|---|---|---|
| ⭐ Slack build alerts | Know immediately when a build fails without watching Jenkins UI | Jenkins → Manage Plugins → Slack Notification Plugin → configure webhook |
| Email notifications | Stakeholders who don't use Slack | Jenkins → Post-build → Email Extension Plugin |
| MS Teams alerts | If org uses Teams instead of Slack | Teams Webhook + `office-365-connector` plugin |

**Slack notification in Jenkinsfile (what to add to post{} block):**
```groovy
post {
  failure {
    slackSend(
      channel: '#devops-alerts',
      color: 'danger',
      message: "❌ Build FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}\n${env.BUILD_URL}"
    )
  }
  success {
    slackSend(
      channel: '#devops-alerts',
      color: 'good',
      message: "✅ Deployed: ${env.IMAGE_TAG}\n${env.BUILD_URL}"
    )
  }
}
```

---

### Pipeline Hardening
| What | Why | How |
|---|---|---|
| ⭐ Build timeout | Prevent hung builds consuming resources forever | `options { timeout(time: 30, unit: 'MINUTES') }` |
| Build discarder | Disk fills up fast if you keep all build logs | `options { buildDiscarder(logRotator(numToKeepStr: '10')) }` |
| Retry on failure | Transient network failures (DockerHub timeout) shouldn't kill the build | `retry(3) { sh "docker push ..." }` |
| Parallel stages | Run tests + lint simultaneously — saves time | `parallel { stage('Test') {...} stage('Lint') {...} }` |

---

### Code Quality + Security Scanning in Pipeline
| What | Why | Tool |
|---|---|---|
| ⭐ Container image scanning | Catch CVEs before deploying to production | Trivy — `trivy image saurabhhub1/go-web-app:v1.x` |
| Static code analysis | Find bugs and security issues in Go code | gosec — `gosec ./...` |
| Code quality gate | Block deploy if code quality drops below threshold | SonarQube |
| Dependency scanning | Auto-PR when a Go dependency has a known CVE | Dependabot (GitHub setting) |

**Add Trivy scan stage to Jenkinsfile (after Docker Build, before Push):**
```groovy
stage('Image Scan') {
  steps {
    sh """
      trivy image --exit-code 1 --severity HIGH,CRITICAL ${env.IMAGE_TAG}
      # --exit-code 1 = fail the build if HIGH or CRITICAL CVEs found
    """
  }
}
```

---

### Jenkins Architecture
| What | Why |
|---|---|
| ⭐ Jenkins agents (separate build nodes) | Master should orchestrate only — not run builds. Single VM doing everything = single point of failure |
| ⭐ Separate Docker build agent | Docker builds are heavy — run them on a dedicated build node, Jenkins master just triggers it |
| Multibranch Pipeline | One Jenkins job for ALL branches — auto-builds PRs before merge |
| Shared Library | Move reusable pipeline code (Slack notify, Docker push) into a shared repo — DRY principle |
| Jenkins Credentials Store | Store DockerHub token in Jenkins Credentials store (not in a .env file on disk) |

**How Jenkins agents work (what we should move to):**
```
Current setup (everything on one VM):
  Jenkins Master VM
    ├── runs Jenkins UI
    ├── runs go test
    ├── runs docker build
    └── runs docker push

Senior setup (master orchestrates, agents do the work):
  Jenkins Master VM        Jenkins Build Agent (separate VM or container)
    ├── runs Jenkins UI  →  agent receives job from master
    ├── stores pipelines     ├── runs go test
    └── triggers agents      ├── runs docker build
                             └── runs docker push → DockerHub

Benefits:
- Master never goes down due to heavy builds
- Scale build capacity by adding more agents
- Different agents for different jobs (Go builds on one, Python builds on another)
- Agents can be Docker containers (spin up for a job, destroy after)
```

**In Jenkinsfile — how to assign a stage to a specific agent:**
```groovy
pipeline {
  agent none   // no global agent — each stage defines its own

  stages {
    stage('Test') {
      agent { label 'go-build-agent' }   // run on node tagged 'go-build-agent'
      steps { sh "go test ./..." }
    }
    stage('Docker Build') {
      agent { label 'docker-agent' }     // run on dedicated Docker build node
      steps { sh "docker build ..." }
    }
  }
}

---

## PHASE 2 — Terraform Enhancements

### State Management
| What | Why | How |
|---|---|---|
| ⭐ Remote backend (S3 + DynamoDB) | Local state file = lost if VM dies. Teams can't share. | Store state in S3, use DynamoDB for locking |
| State locking | Prevent two people running `terraform apply` simultaneously | Automatic with DynamoDB backend |

**Remote backend config to add to main.tf:**
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "go-web-app/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

---

### Security Improvements
| What | Why |
|---|---|
| ⭐ IAM roles for EC2 (not IAM user keys) | Keys can leak. EC2 with IAM role = no keys needed at all |
| Private subnets for EC2 | EC2 should not be directly internet-accessible — put ALB in public subnet, EC2 in private |
| Bastion host or SSM Session Manager | Don't open port 22 to the internet — use SSM for SSH-less access |
| Least-privilege IAM policy | `AdministratorAccess` is too broad — scope to only what Terraform actually needs |

---

### Infrastructure Quality
| What | Why | Tool |
|---|---|---|
| `terraform fmt` in CI | Enforce consistent formatting | Run in pipeline before plan |
| `terraform validate` in CI | Catch syntax errors before apply | Run in pipeline before plan |
| ⭐ Infracost | See cost estimate before `terraform apply` | infracost diff |
| tfsec / Checkov | Scan .tf files for security issues | `tfsec .` or `checkov -d .` |
| Terraform modules | Reuse VPC/EC2 patterns across projects | Create module in `terraform/modules/` |
| Terraform workspaces | Separate dev/staging/prod state | `terraform workspace new staging` |

---

## PHASE 3 — Ansible Enhancements

| What | Why |
|---|---|
| ⭐ Ansible Vault | Encrypt secrets in playbooks — never store plain-text passwords in YAML |
| Dynamic inventory | Auto-discover EC2 instances from AWS tags — no manual IP updates |
| Ansible roles | Reusable, testable units (role: install_docker, role: install_k3s) instead of flat playbooks |
| Molecule | Test Ansible roles in Docker containers before running on real servers |
| Idempotency check | Always run playbook twice — second run should report 0 changes |

---

## PHASE 4 — Kubernetes + Helm Enhancements

### Resource Management (critical for production)
```yaml
# Every container should have these — missing = pod can starve the node
resources:
  requests:
    cpu: "100m"       # minimum guaranteed
    memory: "128Mi"
  limits:
    cpu: "500m"       # maximum allowed
    memory: "256Mi"
```

### Reliability
| What | Why |
|---|---|
| ⭐ Liveness probe | K8s restarts pod if app hangs (process running but not responding) |
| ⭐ Readiness probe | K8s removes pod from load balancer if it's not ready to serve traffic |
| HPA (Horizontal Pod Autoscaler) | Scale pods up under load, down when idle |
| PodDisruptionBudget | Ensure at least 1 replica stays up during node maintenance |
| Rolling update strategy | Zero-downtime deploys — already default in K8s |

**Probes to add to deployment.yaml:**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

### Security
| What | Why |
|---|---|
| ⭐ K8s Secrets (not ConfigMaps) for sensitive values | ConfigMaps are plain-text in etcd — Secrets are base64-encoded (still not encrypted by default, but better) |
| External Secrets Operator | Pull secrets from AWS Secrets Manager into K8s — never store real secrets in Git |
| NetworkPolicies | Restrict which pods can talk to each other — default is allow-all |
| RBAC | Least-privilege access to K8s API — don't give every service account cluster-admin |
| Pod Security Standards | Prevent containers running as root, mounting host paths, etc. |

### Helm
| What | Why |
|---|---|
| `helm lint` in CI | Catch chart syntax errors before deploy |
| `helm test` | Run test pods after deploy to verify app works |
| Helm chart versioning | Bump `Chart.yaml` version on every release |
| Helm diff plugin | Preview what `helm upgrade` will change before running it |

---

## PHASE 5 — ArgoCD Enhancements

| What | Why |
|---|---|
| ⭐ ArgoCD notifications | Slack alert when sync fails or app goes out of sync |
| App of Apps pattern | One ArgoCD app manages all other apps — single source of truth |
| ApplicationSets | Deploy same app to multiple clusters/namespaces from one definition |
| Sync waves | Control order of resource creation (create namespace before app) |
| RBAC for ArgoCD | Different teams get different access levels |

---

## PHASE 6 — Monitoring Enhancements

| What | Why |
|---|---|
| ⭐ Alertmanager → Slack | Route Prometheus alerts to Slack channel — on-call knows immediately |
| ⭐ Centralized logging (Loki) | Logs + metrics in one Grafana dashboard — no SSH-ing into pods to read logs |
| Liveness/readiness dashboards | Visual confirmation deploy succeeded — no manually curling endpoints |
| SLO dashboards | Error budget tracking — "we have 0.1% error budget left this month" |
| DORA metrics | Deployment frequency, lead time, MTTR, change failure rate — the 4 metrics orgs track |
| Distributed tracing (Tempo/Jaeger) | Trace a slow request across microservices — essential for debugging |

---

## CROSS-CUTTING — Security (applies to all phases)

| What | Phase | Why |
|---|---|---|
| ⭐ Trivy image scanning | 1 | CVEs in base image caught before production |
| ⭐ AWS GuardDuty | 2 | Threat detection — alerts on unusual AWS API calls |
| AWS CloudTrail | 2 | Audit log of every AWS API call — who did what, when |
| GitHub secret scanning | 1 | Already active — blocks committed secrets (you've seen this) |
| Dependabot | 1 | Auto-PR when Go/Docker dependencies have CVEs |
| mTLS (Istio/Linkerd) | 4/5 | Encrypt traffic between pods — prevent lateral movement |
| SAST (gosec) | 1 | Static security scan on Go code in pipeline |

---

## INTERVIEW / PORTFOLIO IMPACT

Things that immediately signal senior-level thinking when asked about your pipeline:

| Topic | What to say |
|---|---|
| "How do you handle secrets?" | "No secrets in git. Jenkins reads from `.env` file outside workspace. Moving to AWS Secrets Manager + External Secrets Operator for K8s." |
| "How do you prevent bad code from deploying?" | "Pipeline fails on test failure, Trivy scan failure on HIGH/CRITICAL CVEs, and SonarQube quality gate." |
| "What happens if the Terraform state is lost?" | "We use S3 remote backend with versioning + DynamoDB locking. State is never local." |
| "How does a new version get deployed?" | "Jenkins builds image, pushes to DockerHub, updates Helm values.yaml. ArgoCD detects the change and runs helm upgrade automatically." |
| "How do you know if a deploy succeeded?" | "Prometheus readiness probe metric goes green. ArgoCD shows Healthy + Synced. Slack notification fires on success." |

---

*Created: 2026-06-07 — to be worked through phase by phase as project progresses*
