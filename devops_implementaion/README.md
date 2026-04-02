# go-web-app — My DevOps Implementation

A hands-on DevOps implementation for the [go-web-app](../go-web-app/) project.  
Reference: [teacher's implementation](../go-web-app-devops/)

---

## Host Prerequisites (one-time setup)

Run these once on your Linux machine before using any Vagrant server:

```bash
# 1 — Install libvirt/KVM (needed because VirtualBox conflicts with KVM on Linux)
sudo apt-get update
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager

# 2 — Start and enable the libvirt daemon
sudo systemctl start libvirtd
sudo systemctl enable libvirtd

# 3 — Add your user to the libvirt group (log out & back in after this)
sudo usermod -aG libvirt $USER

# 4 — Install Vagrant (if not already installed)
# https://developer.hashicorp.com/vagrant/downloads

# 5 — Install the vagrant-libvirt plugin
vagrant plugin install vagrant-libvirt
```

> **Why libvirt instead of VirtualBox?**  
> VirtualBox cannot run when the KVM kernel module is loaded (`VERR_VMX_IN_VMX_ROOT_MODE`).  
> Since Linux typically ships with KVM active, we use libvirt (which *uses* KVM) instead.  
> **Box note:** `ubuntu/jammy64` is VirtualBox-only. The Vagrantfiles use `generic/ubuntu2204` which has native libvirt support.

### Alternative: Disable KVM and use VirtualBox

If you prefer VirtualBox, unload the KVM kernel modules first:

```bash
# For Intel CPUs
sudo modprobe -r kvm_intel
sudo modprobe -r kvm

# For AMD CPUs
sudo modprobe -r kvm_amd
sudo modprobe -r kvm

# Verify KVM is unloaded (should return nothing)
lsmod | grep kvm
```

Then in both Vagrantfiles, replace the `libvirt` provider block with:

```ruby
config.vm.provider "virtualbox" do |vb|
  vb.memory = 2048
  vb.cpus   = 2
end
```

> **Note:** The KVM modules will reload automatically on next reboot.  
> To make the change permanent, blacklist them:  
> `echo "blacklist kvm_intel" | sudo tee /etc/modprobe.d/blacklist-kvm.conf`  
> (use `kvm_amd` for AMD CPUs)

---

## When to use which Vagrant server?

| | Server 1 — Build & Test | Server 2 — Docker Build & Push | Server 3 — Jenkins CI/CD |
|---|---|---|---|
| **Purpose** | Verify the Go app compiles and tests pass | Manually build & push a Docker image | Automated pipeline on every code change |
| **Trigger** | `vagrant up` (manual) | `vagrant up` (manual) | Git push / webhook / manual |
| **UI** | Terminal | Terminal (with y/n push prompt) | Full Jenkins web UI |
| **Lifespan** | Spin up → test → destroy | Spin up → build → destroy | Stays running permanently |
| **RAM** | 2 GB | 2 GB | 4 GB (Jenkins overhead) |
| **Use when…** | You want a clean Go env to run tests | You want to quickly build & push without setting up Jenkins | You want continuous automated builds with history & approvals |

> **Tip:** Servers 1 and 2 are ephemeral — spin up, do the job, destroy.  
> Server 3 (Jenkins) is persistent and replaces the need to run Servers 1 & 2 manually once set up.

---

## Vagrant Server 1 — Build & Test (Go)

**Role:** Clean-room Go environment. Useful to verify the app builds and all tests pass  
on a fresh machine before you commit — no Docker or Jenkins overhead involved.

```bash
cd build_test_vagrant_server
vagrant up

# SSH in and run the app manually
vagrant ssh
cd /home/vagrant/go-web-app
go run main.go
# On host: curl http://localhost:8080/home

# Tear down
vagrant destroy -f
```

---

## Vagrant Server 2 — Docker Build & Push

**Role:** Dedicated Docker build machine. Useful when you want to **manually** build and  
push a versioned image on demand — without spinning up the full Jenkins server.  
Think of it as a lightweight, throwaway alternative to Jenkins for one-off builds.

The provision script:
- auto-increments the version tag (`v1.0 → v1.1 → …`) tracked in `.docker_version`
- asks `Push to DockerHub? [y/N]` before pushing
- is **stateless** — destroy and recreate any time, version file persists via synced folder

```bash
export DOCKERHUB_USERNAME=saurabhhub1
export DOCKERHUB_TOKEN=<your-access-token>

cd docker_build_vagrant_server
vagrant up

# Tear down
vagrant destroy -f
```

---

## Vagrant Server 3 — Jenkins CI/CD Pipeline

Boots Ubuntu 22.04, installs **Java 17 + Jenkins LTS + Docker CE + Go 1.22**, and runs the
full CI/CD pipeline via a `Jenkinsfile`.

```bash
export DOCKERHUB_USERNAME=saurabhhub1
export DOCKERHUB_TOKEN=<your-access-token>

cd jenkins_vagrant_server
vagrant up
```

After provisioning, the **initial admin password** is printed in the terminal output.  
Open Jenkins at **http://localhost:9090** (forwarded from VM port 8080).

### First-time Jenkins Setup
1. Paste the initial admin password from the terminal
2. Click **Install suggested plugins**
3. Create your admin user
4. Create a **Pipeline** job:
   - Source: `Pipeline script from SCM` → Git → your repo URL
   - Script Path: `devops_implementaion/Jenkinsfile`
5. Click **Build Now** — the pipeline will pause at interactive stages

```bash
# Tear down
vagrant destroy -f
```

---

## Dockerfile

Multi-stage build — builder stage compiles the binary, distroless stage runs it.

```bash
# Build locally (requires Docker on host)
docker build -f Dockerfile -t <your-username>/go-web-app:latest ../go-web-app

# Run locally
docker run -p 8080:8080 <your-username>/go-web-app:latest
```

---

## CI/CD Option A — GitHub Actions (cloud, teacher's approach)

Pipeline triggers on every push to `main` (except changes to `helm/`, `k8s/`, `README`).

| Job | What it does |
|-----|-------------|
| `build` | `go build` + `go test ./...` |
| `code-quality` | `golangci-lint` |
| `push` | Docker build & push → `<username>/go-web-app:<run_id>` |
| `update-helm-tag` | Auto-bumps image tag in `helm/values.yaml` |

**GitHub Secrets required** (Settings → Secrets → Actions):

| Secret | Value |
|--------|-------|
| `DOCKERHUB_USERNAME` | `saurabhhub1` |
| `DOCKERHUB_TOKEN` | DockerHub access token |
| `TOKEN` | GitHub PAT with `repo` write scope |

---

## CI/CD Option B — Jenkins on Vagrant (self-hosted)

The `Jenkinsfile` runs a declarative pipeline inside the Jenkins Vagrant VM.
Unlike GitHub Actions (which uses a raw `run_id` as the tag), this pipeline uses
semantic version tags (`v1.0`, `v1.1`, …) and pauses for human approval.

| Stage | What it does |
|---|---|
| **Checkout** | Confirms latest source is available in the VM |
| **Test** | `go test ./...` via Go 1.22 |
| **Version Tag** | Reads `.docker_version`, suggests next minor tag, waits for input |
| **Docker Build** | `docker build -t saurabhhub1/go-web-app:<tag>` |
| **Push?** | ⏸ Human approval gate — **Proceed / Abort** button in Jenkins UI |
| **Docker Push** | `docker push` + saves new version to `.docker_version` |
| **Update Helm** | `sed` bumps `helm/values.yaml` tag for Argo CD sync |

**Credentials** — the provision script stores them at `/var/lib/jenkins/dockerhub_creds.env`  
(only readable by the `jenkins` user). No secrets hardcoded in the `Jenkinsfile`.

---

## Kubernetes — Deploy with Helm

```bash
# Install / upgrade
helm upgrade --install go-web-app helm/go-web-app-chart

# Check status
kubectl get pods,svc,ingress

# Uninstall
helm uninstall go-web-app
```

## Kubernetes — Deploy with raw manifests

```bash
# Edit k8s/manifests/deployment.yaml — replace <your-dockerhub-username>
kubectl apply -f k8s/manifests/
kubectl get pods
```

---

## Project Structure

```
devops_implementaion/
├── build_test_vagrant_server/         ← VM 1: Go build & test
│   ├── Vagrantfile
│   └── provision_build.sh
├── docker_build_vagrant_server/       ← VM 2: Docker build & push
│   ├── Vagrantfile
│   ├── provision_docker.sh            ← auto version tag + push prompt
│   └── .docker_version                ← last pushed tag (e.g. v1.2)
├── jenkins_vagrant_server/            ← VM 3: Jenkins CI/CD (self-hosted)
│   ├── Vagrantfile                    ← Ubuntu 22.04, 4 GB, port 9090→8080
│   └── provision_jenkins.sh          ← installs Java, Jenkins, Docker, Go
├── Jenkinsfile                        ← Declarative pipeline (7 stages)
├── Dockerfile                         ← Multi-stage (golang:1.22 → distroless)
├── .github/workflows/cicd.yaml        ← GitHub Actions CI/CD (Option A)
├── helm/go-web-app-chart/             ← Helm chart
└── k8s/manifests/                     ← Raw k8s manifests
```
