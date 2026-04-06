# DevOps Implementation Plan — go-web-app

## Overview

You have a Go web application (`go-web-app/`) and the teacher's complete reference implementation (`go-web-app-devops/`).  
Your **own** implementation goes into `devops_implementaion/`.

The plan is broken into two immediate phases that you asked about:

1. **Vagrant "test" server** — spin up a VM, install Go, run `go test` inside it.  
2. **Vagrant "build/push" server** — spin up a VM, install Docker, build the image and push to DockerHub.

Then continue with Dockerfile, CI/CD (GitHub Actions), Helm, and k8s manifests.

---

## Proposed Directory Layout

```
devops_implementaion/
├── build_test_vagrant_server/   ← YOU STARTED THIS
│   ├── Vagrantfile              ← Ubuntu 22.04, Go installed, port-forward 8080
│   └── provision_test.sh        ← installs Go, runs go test
│
├── docker_build_vagrant_server/  ← NEW
│   ├── Vagrantfile               ← Ubuntu 22.04, Docker installed
│   └── provision_docker.sh       ← installs Docker, logs in, builds & pushes
│
├── Dockerfile                   ← multi-stage distroless (same concept as teacher's)
├── .github/
│   └── workflows/
│       └── cicd.yaml            ← GitHub Actions: build → test → lint → push → update-helm
├── helm/
│   └── go-web-app-chart/        ← your own Helm chart (adapted from teacher's)
└── k8s/
    └── manifests/
        ├── deployment.yaml
        ├── service.yaml
        └── ingress.yaml
```

---

## Phase 1 — Vagrant Test Server (`build_test_vagrant_server/`)

### What it does
- Boots Ubuntu 22.04 (virtualbox)
- Installs Go 1.22
- Syncs the `go-web-app/` source into `/home/vagrant/go-web-app`
- Runs `go test ./...` on provision

### Files to create

#### [NEW] [Vagrantfile](file:///home/srv/project_srv/devops_implementaion/build_test_vagrant_server/Vagrantfile)
```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.network "forwarded_port", guest: 8080, host: 8080
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus   = 2
  end
  config.vm.synced_folder "../../go-web-app", "/home/vagrant/go-web-app"
  config.vm.provision "shell", path: "provision_test.sh"
end
```

#### [NEW] [provision_test.sh](file:///home/srv/project_srv/devops_implementaion/build_test_vagrant_server/provision_test.sh)
- Downloads Go 1.22 tarball
- Sets `GOPATH` / `PATH`
- `cd /home/vagrant/go-web-app && go test ./...`

---

## Phase 2 — Vagrant Docker Server (`docker_build_vagrant_server/`)

### What it does
- Boots Ubuntu 22.04
- Installs Docker CE + Docker Compose
- Syncs source + your [Dockerfile](file:///home/srv/project_srv/go-web-app-devops/Dockerfile)
- On provision: `docker build` → `docker login` → `docker push`

> [!IMPORTANT]
> You will need to set `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` environment variables **on your host** before running `vagrant up`. The provision script reads them from the environment.

#### [NEW] [Vagrantfile](file:///home/srv/project_srv/devops_implementaion/docker_build_vagrant_server/Vagrantfile)
```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus   = 2
  end
  config.vm.synced_folder "../../go-web-app", "/home/vagrant/go-web-app"
  config.vm.synced_folder "../",              "/home/vagrant/devops"
  config.vm.provision "shell", path: "provision_docker.sh", env: {
    "DOCKERHUB_USERNAME" => ENV["DOCKERHUB_USERNAME"],
    "DOCKERHUB_TOKEN"    => ENV["DOCKERHUB_TOKEN"]
  }
end
```

---

## Phase 3 — Dockerfile

#### [NEW] [Dockerfile](file:///home/srv/project_srv/devops_implementaion/Dockerfile)
Multi-stage build:
- Stage 1 (`golang:1.22`): `go mod download` → `go build -o main .`
- Stage 2 (`gcr.io/distroless/base`): copy binary + `static/`

---

## Phase 4 — GitHub Actions CI/CD

#### [NEW] [cicd.yaml](file:///home/srv/project_srv/devops_implementaion/.github/workflows/cicd.yaml)

Jobs (mirrors teacher's, but with **your** DockerHub username):

| Job | Depends on | What it does |
|-----|-----------|--------------|
| `build` | — | `go build`, `go test ./...` |
| `code-quality` | — | `golangci-lint` |
| `push` | `build` | Docker build & push with `github.run_id` tag |
| `update-helm-tag` | `push` | `sed` the tag in `helm/.../values.yaml` |

---

## Phase 5 — Helm & k8s Manifests

Adapted from teacher's `go-web-app-devops/helm/` and `k8s/`. Only change needed is the Docker image repository name to yours.

---

## Verification Plan

### Step 1 — Test inside Vagrant (Phase 1)
```bash
cd devops_implementaion/build_test_vagrant_server
vagrant up
# Watch provisioner output — should end with "ok  github.com/iam-veeramalla/go-web-app"
vagrant ssh
cd /home/vagrant/go-web-app && go test ./...
```

### Step 2 — Docker build & push inside Vagrant (Phase 2)
```bash
export DOCKERHUB_USERNAME=<your-username>
export DOCKERHUB_TOKEN=<your-token>
cd devops_implementaion/docker_build_vagrant_server
vagrant up
# Watch provisioner: should end with "docker push" success
```

### Step 3 — Manual smoke-test of the app locally
```bash
cd go-web-app
go test ./...   # should pass immediately on host too
go run main.go  # then open http://localhost:8080/home
```
