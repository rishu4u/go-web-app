# go-web-app — DevOps Pipeline

Production-grade DevOps pipeline built on a Go web app.
Full pipeline: Git → Jenkins → Docker → Helm → Terraform → Ansible → K8s → ArgoCD → Prometheus

**Repo:** git@github.com:rishu4u/go-web-app.git
**Image:** saurabhhub1/go-web-app on DockerHub
**Reference:** devops_implementaion/pipeline_plan.md for phase status

---

## Host Prerequisites — One-Time Setup (Linux)

Run these once on your Linux machine before using Vagrant:

```bash
# 1 — Install libvirt/KVM (VirtualBox conflicts with KVM on Linux)
sudo apt-get update
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager

# 2 — Start and enable the libvirt daemon
sudo systemctl start libvirtd
sudo systemctl enable libvirtd

# 3 — Add your user to the libvirt group (log out and back in after this)
sudo usermod -aG libvirt $USER

# 4 — Install Vagrant
# https://developer.hashicorp.com/vagrant/downloads

# 5 — Install the vagrant-libvirt plugin
vagrant plugin install vagrant-libvirt
```

> **Why libvirt and not VirtualBox?**
> VirtualBox cannot run when the KVM kernel module is loaded (VERR_VMX_IN_VMX_ROOT_MODE).
> Linux ships with KVM active by default. libvirt uses KVM natively — no conflict.
> Vagrantfiles use `generic/ubuntu2204` (has libvirt support). `ubuntu/jammy64` is VirtualBox-only.

---

## Start Jenkins VM

```bash
cd devops_implementaion/jenkins_vagrant_server
export DOCKERHUB_USERNAME=saurabhhub1
export DOCKERHUB_TOKEN=<your-token>
vagrant up

# Jenkins UI: http://192.168.56.12:8080  or  http://localhost:9090
```

Full setup and commands: devops_implementaion/flow_and_commands.md → Section 0

---

## Project Structure

```
go-web-app/                              ← repo root (main branch — single source of truth)
├── main.go
├── main_test.go
├── go.mod
├── static/
└── devops_implementaion/
    ├── Jenkinsfile                      ← 7-stage declarative pipeline
    ├── Dockerfile                       ← multi-stage build (golang → distroless)
    ├── jenkins_vagrant_server/          ← Jenkins CI/CD VM (persistent)
    ├── helm/go-web-app-chart/           ← Helm chart for K8s deployment
    ├── k8s/manifests/                   ← Raw K8s YAMLs
    ├── terraform/                       ← AWS infrastructure (EC2, VPC, SG)
    ├── .github/workflows/cicd.yaml      ← GitHub Actions pipeline
    ├── flow_and_commands.md             ← PRIMARY reference — all commands + concepts
    ├── NOTES.md                         ← Architecture decisions + troubleshooting
    ├── pipeline_plan.md                 ← 7-phase roadmap with status
    └── senior_suggestions.md           ← Senior DevOps additions per phase
```
