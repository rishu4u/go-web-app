# Operations Reference — Quick Access Guide

> **Purpose:** Sit down, open this file, get to work.
> How to access, start, stop, and check status of every server and service in this project.
> Not a learning doc — a fast lookup. Learn concepts in flow_and_commands.md.

---

## TABLE OF CONTENTS

| Service | Section |
|---|---|
| Jenkins VM (Vagrant) | [Section 1](#1-jenkins-vm) |
| Jenkins UI | [Section 2](#2-jenkins-ui) |
| Go Web App | [Section 3](#3-go-web-app) |
| AWS EC2 (Terraform) | [Section 4](#4-aws-ec2--terraform) |
| Ansible *(Phase 3)* | [Section 5](#5-ansible--phase-3) |
| Kubernetes / kubectl *(Phase 4)* | [Section 6](#6-kubernetes--phase-4) |
| ArgoCD UI *(Phase 5)* | [Section 7](#7-argocd--phase-5) |
| Prometheus / Grafana *(Phase 6)* | [Section 8](#8-prometheus--grafana--phase-6) |

---

## 1. Jenkins VM

### Start / Stop / Access

```bash
# Always run from this directory on the HOST
cd /home/srv/project_srv/go-web-app/devops_implementaion/jenkins_vagrant_server

vagrant up          # start VM (first time: provisions everything ~5-10 min)
vagrant halt        # gracefully stop VM
vagrant reload      # restart VM + re-apply Vagrantfile (fixes synced folders)
vagrant destroy     # ⚠️ delete VM completely (data inside is lost)
vagrant status      # check if running or stopped
vagrant ssh         # SSH into VM as vagrant user
```

### Where is this configured?

| Setting | Defined in | Value |
|---|---|---|
| VM IP address | `Vagrantfile` line: `ip: "192.168.56.12"` | `192.168.56.12` |
| Port forward | `Vagrantfile` line: `forwarded_port, guest: 8080, host: 9090` | VM:8080 → Host:9090 |
| RAM / CPUs | `Vagrantfile`: `lv.memory = 4096`, `lv.cpus = 2` | 4GB RAM, 2 CPUs |
| OS | `Vagrantfile`: `config.vm.box = "generic/ubuntu2204"` | Ubuntu 22.04 |
| What gets installed | `provision_jenkins.sh` | Java 17, Jenkins, Docker CE, Go 1.22.5 |
| DockerHub creds passed in | `Vagrantfile`: `env: { DOCKERHUB_USERNAME, DOCKERHUB_TOKEN }` | From host env vars |

### Synced folders (host ↔ VM)

| Host path | VM path | Contents |
|---|---|---|
| `/home/srv/project_srv/go-web-app/` | `/home/vagrant/go-web-app/` | Go source + devops files |
| `/home/srv/project_srv/go-web-app/devops_implementaion/` | `/home/vagrant/devops/` | Jenkinsfile, Terraform, Helm, etc. |

> ⚠️ Synced folders use rsync (one-way: host → VM). Always edit on HOST, not on VM.

### Key paths INSIDE the VM

| Path | What it is |
|---|---|
| `/var/lib/jenkins/` | Jenkins home directory |
| `/var/lib/jenkins/workspace/go-web-app/` | Where Jenkins clones the repo |
| `/var/lib/jenkins/.ssh/id_ed25519` | Jenkins user SSH key (for GitHub push) |
| `/var/lib/jenkins/dockerhub_creds.env` | DockerHub username + token |
| `/var/lib/jenkins/.docker_version` | Tracks last pushed image version |
| `/var/lib/jenkins/secrets/initialAdminPassword` | First-time Jenkins admin password |
| `/usr/local/go/bin/go` | Go binary |
| `/home/vagrant/devops/terraform/` | Terraform files (synced from host) |

---

## 2. Jenkins UI

### Access URLs

| URL | When to use |
|---|---|
| `http://192.168.56.12:8080` | From laptop browser (direct VM IP) |
| `http://localhost:9090` | From laptop browser (port-forwarded) |

### First-time setup (only once after fresh VM)

```
1. Open http://192.168.56.12:8080
2. Get initial password:
   vagrant ssh → sudo cat /var/lib/jenkins/secrets/initialAdminPassword
3. Paste password → Install suggested plugins → Create admin user
4. Create Pipeline job:
   New Item → Pipeline → Pipeline script from SCM
   → Git → git@github.com:rishu4u/go-web-app.git
   → Credentials: github-ssh
   → Branch: */main
   → Script Path: devops_implementaion/Jenkinsfile
5. Build Triggers → Poll SCM → H/5 * * * *
```

### Jenkins service commands (run ON the VM after vagrant ssh)

```bash
sudo systemctl status jenkins       # check if running
sudo systemctl start jenkins        # start
sudo systemctl stop jenkins         # stop
sudo systemctl restart jenkins      # restart
sudo journalctl -u jenkins -f       # live logs
jenkins --version                   # Jenkins version
```

### Pre-build checklist (run ON the VM before triggering pipeline)

```bash
sudo -u jenkins ssh -T git@github.com          # Expected: Hi rishu4u!
sudo -u jenkins docker ps                      # no permission denied
sudo cat /var/lib/jenkins/dockerhub_creds.env  # creds present
aws sts get-caller-identity                    # terraform-devops account
/usr/local/go/bin/go version                   # go1.22.5
terraform --version                            # v1.14.8
```

---

## 3. Go Web App

### App details

| Item | Value |
|---|---|
| Source | `/home/srv/project_srv/go-web-app/main.go` |
| Listens on | Port `8080` |
| Docker image | `saurabhhub1/go-web-app:v1.1` (latest on DockerHub) |

### Endpoints

| URL | Page |
|---|---|
| `/home` | Home page |
| `/courses` | Courses listing |
| `/about` | About page |
| `/contact` | Contact page |

### Run on HOST laptop (Docker installed, Go not installed)

```bash
docker run --rm -p 8080:8080 saurabhhub1/go-web-app:v1.1

# Access:
curl http://localhost:8080/home
# or browser: http://localhost:8080/courses
```

### Run on Jenkins VM — Option A: Docker (Jenkins stays running)

```bash
vagrant ssh
docker run --rm -p 9091:8080 saurabhhub1/go-web-app:v1.1

# Access from laptop:
curl http://192.168.56.12:9091/home
```

### Run on Jenkins VM — Option B: go run (stop Jenkins first)

```bash
vagrant ssh
sudo systemctl stop jenkins          # free port 8080

cd /home/vagrant/go-web-app
export PATH=$PATH:/usr/local/go/bin
go run main.go

# Access from laptop (8080 on VM = 9090 on host):
curl http://localhost:9090/home

sudo systemctl start jenkins         # restart when done
```

---

## 4. AWS EC2 / Terraform

### Where Terraform runs

Terraform is installed on the **Jenkins Vagrant VM** (not the host laptop).

```bash
# Always: start Jenkins VM first, then SSH in
vagrant up && vagrant ssh

cd /home/vagrant/devops/terraform
```

### Terraform workflow

```bash
terraform init                  # first time only — downloads AWS provider
terraform plan                  # preview what will be created (no cost)
terraform apply                 # create EC2 + VPC + SGs (type 'yes')
terraform output                # show EC2 public IPs after apply
terraform destroy               # ⚠️ tear down everything (type 'yes')
terraform state list            # list all resources Terraform is tracking
```

### AWS infrastructure created

| Resource | Spec | Free tier? |
|---|---|---|
| EC2 master | t2.micro, gp2 12GB | ✅ |
| EC2 worker | t2.micro, gp2 12GB | ✅ (750h total/month) |
| VPC | 10.0.0.0/16, us-east-1 | ✅ |
| SSH key pair | `terraform-key.pem` saved to `~/` on Jenkins VM | — |

> ⚠️ FREE TIER: 2x t2.micro = 48h/day consumed → exhausts 750h in ~15 days. Destroy when not in use.

### SSH into EC2 after terraform apply

```bash
# Get IPs first
terraform output

# SSH using the generated key (saved by Terraform to Jenkins VM home)
ssh -i ~/terraform-key.pem ubuntu@<master-public-ip>
ssh -i ~/terraform-key.pem ubuntu@<worker-public-ip>
```

### AWS credentials

| Item | Location |
|---|---|
| IAM user | `terraform-devops`, Account `505609702814` |
| Credentials file | `~/.aws/credentials` on Jenkins VM |
| Verify | `aws sts get-caller-identity` |

---

## 5. Ansible *(Phase 3 — Not started)*

```
Coming: install k3s on EC2 master + worker
Access: Ansible runs from Jenkins VM, SSHes into EC2 using terraform-key.pem
```

---

## 6. Kubernetes *(Phase 4 — Not started)*

```
Coming: kubectl commands, Helm install/upgrade/rollback
Access: kubectl from Jenkins VM pointing at k3s cluster on EC2
```

---

## 7. ArgoCD *(Phase 5 — Not started)*

```
Coming: ArgoCD UI URL, sync status, app management
```

---

## 8. Prometheus / Grafana *(Phase 6 — Not started)*

```
Coming: Grafana dashboard URL, Prometheus targets, alert rules
```

---

*Last updated: 2026-06-08 — Phases 1 + 2 complete*
