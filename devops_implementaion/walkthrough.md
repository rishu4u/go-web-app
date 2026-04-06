# DevOps Implementation — Walkthrough

## What Was Built

All files live inside `devops_implementaion/` (your directory), mirroring what the teacher built in `go-web-app-devops/` but with your own structure and learning comments.

```
devops_implementaion/
├── build_test_vagrant_server/     ← VM 1: Install Go & run tests
│   ├── Vagrantfile
│   └── provision_test.sh
│
├── docker_build_vagrant_server/   ← VM 2: Install Docker, build & push image
│   ├── Vagrantfile
│   └── provision_docker.sh
│
├── Dockerfile                     ← Multi-stage (golang → distroless)
├── .github/
│   └── workflows/
│       └── cicd.yaml              ← GitHub Actions: 4-job CI/CD pipeline
├── helm/
│   └── go-web-app-chart/
│       ├── Chart.yaml
│       ├── values.yaml            ← tag auto-updated by CI/CD
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml
│           ├── service.yaml
│           └── ingress.yaml
└── k8s/
    └── manifests/
        ├── deployment.yaml
        ├── service.yaml
        └── ingress.yaml
```

---

## How to Use Each Piece

### Step 1 — Run tests inside Vagrant (VM 1)

> Prerequisite: VirtualBox installed on your machine.

```bash
cd devops_implementaion/build_test_vagrant_server
vagrant up
```

The VM will:
1. Boot Ubuntu 22.04
2. Install Go 1.22
3. Run `go test ./...` against the synced `go-web-app/` source
4. Print **ALL TESTS PASSED** if everything works

To manually run the app inside the VM:
```bash
vagrant ssh
cd /home/vagrant/go-web-app
go run main.go
# Then on your HOST: curl http://localhost:8080/home
```

> **Note**: Go was not found on the host machine (`go: command not found`), confirming that the Vagrant VM is the right place to test.

---

### Step 2 — Build & push Docker image (VM 2)

> Prerequisite: DockerHub account + access token.

```bash
export DOCKERHUB_USERNAME=<your-username>
export DOCKERHUB_TOKEN=<your-access-token>

cd devops_implementaion/docker_build_vagrant_server
vagrant up
```

The VM will:
1. Boot Ubuntu 22.04
2. Install Docker CE
3. `docker login` using credentials passed from your host env
4. `docker build -f devops_implementaion/Dockerfile ...`
5. `docker push <your-username>/go-web-app:latest`

---

### Step 3 — CI/CD via GitHub Actions

Push to [main](file:///home/srv/project_srv/go-web-app/main.go#28-40) branch → GitHub Actions runs 4 jobs automatically:

| Job | What it does |
|-----|-------------|
| `build` | `go build` + `go test ./...` |
| `code-quality` | `golangci-lint` |
| `push` | Docker build & push → `<username>/go-web-app:<run_id>` |
| `update-helm-tag` | `sed` updates `helm/.../values.yaml` tag → commits back |

**Required GitHub Secrets to set:**
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `TOKEN` (GitHub PAT with repo write for the helm tag commit)

---

### Step 4 — Deploy to Kubernetes

**With Helm (recommended):**
```bash
# Edit values.yaml first — replace <your-dockerhub-username>
helm install go-web-app devops_implementaion/helm/go-web-app-chart
```

**With raw manifests (learning purpose):**
```bash
# Edit k8s/manifests/deployment.yaml — replace <your-dockerhub-username>
kubectl apply -f devops_implementaion/k8s/manifests/
```

---

## What You Learned / Implemented

| Concept | Where |
|---------|-------|
| Infrastructure as Code (Vagrant) | `build_test_vagrant_server/`, `docker_build_vagrant_server/` |
| Multi-stage Docker build | [Dockerfile](file:///home/srv/project_srv/go-web-app-devops/Dockerfile) |
| CI/CD pipeline | [.github/workflows/cicd.yaml](file:///home/srv/project_srv/go-web-app-devops/.github/workflows/cicd.yaml) |
| GitOps (auto-update helm tag) | `update-helm-tag` job in cicd.yaml |
| Helm packaging | `helm/go-web-app-chart/` |
| Raw k8s manifests | `k8s/manifests/` |
