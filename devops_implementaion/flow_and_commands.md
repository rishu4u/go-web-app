# DevOps — Complete Flow & Commands Reference

> **Purpose:** Learning + revision cheatsheet.
> Every command here was actually run on this project (Go web app CI/CD pipeline).
> Covers: Git → Docker → Jenkins (more tools added as we go).

---

# ═══════════════════════════════════════════
#  SECTION 0 — JENKINS SERVER SETUP (Vagrant)
# ═══════════════════════════════════════════

## 0.1  WHAT GETS CREATED

```
Your Laptop (Host)
└── jenkins_vagrant_server/
    ├── Vagrantfile              ← defines the VM
    └── provision_jenkins.sh    ← auto-installs everything inside VM

After `vagrant up`:
    VM IP    : 192.168.56.12
    Jenkins  : http://192.168.56.12:8080
    Also at  : http://localhost:9090  (port-forwarded to host browser)
    RAM      : 4096 MB  |  CPUs: 2
```

---

## 0.2  WHAT THE VAGRANTFILE DOES

```ruby
# Key settings in jenkins_vagrant_server/Vagrantfile

config.vm.box                   = "generic/ubuntu2204"       # Ubuntu 22.04
config.vm.network "private_network", ip: "192.168.56.12"     # static IP
config.vm.network "forwarded_port", guest: 8080, host: 9090  # host browser access

lv.memory = 4096   # Jenkins needs more RAM
lv.cpus   = 2

# Synced folders — host directories mounted inside VM
config.vm.synced_folder "../../go-web-app",  "/home/vagrant/go-web-app"
config.vm.synced_folder "../",               "/home/vagrant/devops"

# Run provisioning script + pass DockerHub creds into VM
config.vm.provision "shell", path: "provision_jenkins.sh",
  env: { "DOCKERHUB_USERNAME" => ENV["DOCKERHUB_USERNAME"],
         "DOCKERHUB_TOKEN"    => ENV["DOCKERHUB_TOKEN"] }
```

> ⭐ The synced folders mean:
> - `/home/vagrant/go-web-app` on VM = `/home/srv/project_srv/go-web-app` on host (live sync)
> - `/home/vagrant/devops` on VM = `/home/srv/project_srv/devops_implementaion` on host (live sync)

---

## 0.3  WHAT `provision_jenkins.sh` INSTALLS AUTOMATICALLY

The script runs once when you do `vagrant up` (or `vagrant provision`).

| Step | What it does |
|---|---|
| Step 1 | Adds Jenkins apt repo + Docker apt repo (with GPG keys) |
| Step 2 | `apt-get install` — Java 17, Jenkins LTS, Docker CE, Git, curl |
| Step 3 | Adds `vagrant` and `jenkins` users to `docker` group |
| Step 4 | Installs Go 1.22.5 to `/usr/local/go` |
| Step 5 | Saves DockerHub credentials to `/var/lib/jenkins/dockerhub_creds.env` |
| Step 6 | Restarts Jenkins (so docker group takes effect) + waits for it to come up |

---

## 0.4  HOW TO SPIN UP THE JENKINS SERVER

```bash
# Step 1 — Go into the jenkins_vagrant_server directory (on host laptop)
cd /home/srv/project_srv/devops_implementaion/jenkins_vagrant_server

# Step 2 — Export DockerHub credentials (so provisioner can save them)
export DOCKERHUB_USERNAME=rishu4u
export DOCKERHUB_TOKEN=your_dockerhub_access_token

# Step 3 — Spin up the VM (downloads box + runs provision script — takes ~5-10 min first time)
vagrant up

# Step 4 — At the end of output you will see:
#   Jenkins URL : http://192.168.56.12:8080
#   Initial Admin Password: <some long string>
#   Copy that password!
```

---

## 0.5  FIRST-TIME JENKINS UI SETUP (browser)

```
1. Open: http://192.168.56.12:8080  (or http://localhost:9090)
2. Paste the Initial Admin Password shown in vagrant up output
   (also available on VM at: /var/lib/jenkins/secrets/initialAdminPassword)
3. Click "Install suggested plugins" → wait ~2 min
4. Create your admin user
5. Jenkins is ready
```

---

## 0.6  AFTER SETUP — ADD SSH KEY TO JENKINS GUI

(Full detail in Section 3.2 — but quick reminder here)

```bash
# On the Jenkins VM — generate key for jenkins user
vagrant ssh  (or: vagrant ssh jenkins_vagrant_server)

sudo -u jenkins ssh-keygen -t ed25519 -C "jenkins-vm" \
  -f /var/lib/jenkins/.ssh/id_ed25519 -N ""

# PUBLIC key → add to GitHub (Settings → SSH Keys)
sudo cat /var/lib/jenkins/.ssh/id_ed25519.pub

# PRIVATE key → add to Jenkins GUI Credentials
sudo cat /var/lib/jenkins/.ssh/id_ed25519
# Jenkins UI: Manage Jenkins → Credentials → Add → SSH Username with private key
# ID: github-ssh | Username: git | Paste private key content
```

---

## 0.7  DAY-TO-DAY VAGRANT COMMANDS

```bash
# From the jenkins_vagrant_server/ folder on host:

vagrant up                         # start the VM
vagrant halt                       # gracefully stop the VM
vagrant ssh                        # SSH into the VM (as vagrant user)
vagrant reload                     # restart VM (apply Vagrantfile changes)
vagrant provision                  # re-run provision_jenkins.sh (re-install/fix)
vagrant destroy                    # ⚠️ delete VM completely
vagrant status                     # check if VM is running/stopped
```

---

## 0.8  KEY PATHS INSIDE THE JENKINS VM

| Path | What it is |
|---|---|
| `/home/vagrant/go-web-app/` | Go app source code (synced from host) |
| `/home/vagrant/devops/` | Jenkinsfile, Dockerfile, Helm, K8s (synced from host) |
| `/var/lib/jenkins/` | Jenkins home directory |
| `/var/lib/jenkins/.ssh/id_ed25519` | Jenkins user private SSH key |
| `/var/lib/jenkins/dockerhub_creds.env` | DockerHub username + token |
| `/var/lib/jenkins/secrets/initialAdminPassword` | First-time Jenkins admin password |
| `/usr/local/go/bin/go` | Go binary |

---

## 0.9  CHECKLIST — IS JENKINS READY TO RUN PIPELINE?

```bash
# SSH into VM first
vagrant ssh

# 1. Jenkins running?
sudo systemctl status jenkins

# 2. Go installed?
/usr/local/go/bin/go version

# 3. Docker installed?
docker --version

# 4. jenkins user can run Docker? (critical)
sudo -u jenkins docker ps
# If "permission denied": sudo usermod -aG docker jenkins && sudo systemctl restart jenkins

# 5. DockerHub creds file exists?
sudo cat /var/lib/jenkins/dockerhub_creds.env

# 6. Jenkins can authenticate to GitHub?
sudo -u jenkins ssh -T git@github.com
# Expected: Hi rishu4u!
```

---

# ═══════════════════════════════════════════
#  SECTION 1 — GIT
# ═══════════════════════════════════════════

## 1.1  CORE MENTAL MODEL — 3 Things You Need to Push

| Thing | What it does | Command to check |
|---|---|---|
| **Identity** | Labels your commits (name + email) | `git config user.email` |
| **Remote URL** | Tells git WHERE to push | `git remote -v` |
| **SSH Key** | Proves you have push rights | `ssh -T git@github.com` |

> ⚠️ Identity ≠ Authentication. A remote URL with your username ≠ logged in.
> **Only the SSH key controls whether a push is allowed.**

---

## 1.2  GIT SETUP — Do Once Per Machine

```bash
# Set your identity (labels on commits)
git config --global user.name  "rishu4u"
git config --global user.email "your@email.com"

# Verify
git config --global user.name
git config --global user.email
```

---

## 1.3  SSH KEY SETUP — Do Once Per Machine (laptop, vagrant VM, jenkins VM)

```bash
# Step 1 — Check if a key already exists
ls ~/.ssh/
# Look for: id_ed25519  and  id_ed25519.pub
# If missing → generate (Step 2)

# Step 2 — Generate a new key
ssh-keygen -t ed25519 -C "machine-label" -f ~/.ssh/id_ed25519 -N ""
# -C   just a label (e.g. "rishu4u-laptop", "jenkins-vm")
# -N   no passphrase (so Jenkins can use it non-interactively)

# Step 3 — Print the PUBLIC key (copy this to GitHub)
cat ~/.ssh/id_ed25519.pub
# Starts with: ssh-ed25519 AAAAC3...

# Step 4 — Add to GitHub
# → https://github.com/settings/ssh/new
# → Title: name of the machine
# → Paste the output from Step 3

# Step 5 — Test the connection
ssh -T git@github.com
# Expected: Hi rishu4u! You've successfully authenticated...
```

---

## 1.4  DAILY GIT WORKFLOW — 3-Command Loop

```bash
git add .                          # stage all changes
git commit -m "describe what changed"
git push                           # push staged commits to GitHub
```

---

## 1.5  SCENARIO FLOWS

### SCENARIO A — Take someone else's repo and make it yours

> Example: clone teacher's `iam-veeramalla/go-web-app` → push to `rishu4u/go-web-app`

```bash
# 1. Enter the cloned folder
cd /home/srv/project_srv/go-web-app

# 2. Check where it currently points (shows teacher's URL)
git remote -v

# 3. Create a NEW empty repo on GitHub
#    → https://github.com/new  (no README, no .gitignore)

# 4. Redirect remote to YOUR repo
git remote set-url origin git@github.com:rishu4u/go-web-app.git

# 5. Verify
git remote -v

# 6. Push all history to your account
git push -u origin main
```

---

### SCENARIO B — Push a brand new folder as a new repo

> Example: devops_implementaion/ folder had no git history

```bash
# 1. Enter the folder
cd /home/srv/project_srv/devops_implementaion

# 2. Initialize git
git init

# 3. Create a NEW empty repo on GitHub
#    → https://github.com/new

# 4. Add the remote
git remote add origin git@github.com:rishu4u/go-web-app.git

# 5. Stage everything
git add .

# 6. First commit
git commit -m "Initial commit"

# 7. Push (use master or main — match your branch name)
git push -u origin master
```

---

### SCENARIO C — Future day-to-day pushes

```bash
git add .
git commit -m "what you changed"
git push
```

---

## 1.6  HOW `git push` WORKS INTERNALLY

```
Your Machine                         GitHub
─────────────────                    ──────
  commit A  ←── already there ────►  commit A
  commit B  ←── already there ────►  commit B
  commit C  ◄── NEW, not on GitHub
  commit D  ◄── NEW, not on GitHub

  git push  ──── sends C, D ───────► commit C
                                     commit D
```

Git **only sends commits GitHub doesn't have yet**.

```bash
git push                   # push using saved default (set by -u)
git push -u origin main    # -u saves the default so future bare git push works
```

Under the hood:
1. SSH key checked → GitHub allows / denies
2. Git compares local commits vs GitHub commits
3. Only NEW commits are transferred
4. GitHub moves the branch pointer to your latest commit

---

## 1.7  ROLLBACK COMMANDS

### Not pushed yet — 3 options

```bash
# SOFT — undo commit, keep files staged (safest)
git reset --soft HEAD~1
# Use when: wrong commit message, not ready

# MIXED (default) — undo commit, unstage files, keep disk changes
git reset --mixed HEAD~1    # same as: git reset HEAD~1
# Use when: want to re-select what to stage

# HARD — undo commit AND delete file changes (⚠️ destructive)
git reset --hard HEAD~1
# Use when: want to completely go back in time
```

### Already pushed to GitHub — use revert (safe)

```bash
git revert HEAD    # creates a NEW "undo" commit
git push           # push the revert commit
# Does NOT rewrite history — GitHub won't complain
```

### Visual Rollback Summary

```
BEFORE:   A → B → C      (C is latest)

--soft    A → B           (C removed, files still staged)
--mixed   A → B           (C removed, files unstaged)
--hard    A → B           (C removed, disk changes deleted)
revert    A → B → C → D  (D undoes C, history preserved)
```

| Situation | Command |
|---|---|
| Not pushed, fix commit message | `git reset --soft HEAD~1` |
| Not pushed, discard completely | `git reset --hard HEAD~1` |
| Already pushed to GitHub | `git revert HEAD` then `git push` |

---

## 1.8  DIAGNOSTIC COMMANDS — Run These When Stuck

```bash
# Am I authenticated with GitHub?
ssh -T git@github.com

# Where will this repo push/pull from?
git remote -v

# Who am I (what goes on commit labels)?
git config user.name
git config user.email

# What branch am I on?
git branch

# What files are staged / unstaged / untracked?
git status

# See recent commit history (short)
git log --oneline -5

# See ALL branches (local + remote)
git branch -a

# See what changed in last commit
git show HEAD
```

---

## 1.9  GIT GOTCHAS WE HIT

### ❌ "does not appear to be a git repository"
```
fatal: '/home/vagrant/devops' does not appear to be a git repository
```
**Cause:** Jenkins pointed at a Vagrant synced folder — synced folders don't carry `.git`
**Fix:** Point Jenkins at the GitHub repo URL directly.

---

### ❌ "Permission denied (publickey)"
```
git@github.com: Permission denied (publickey).
```
**Cause:** That machine has no SSH key registered in GitHub.
**Fix:** Generate key, add `.pub` to GitHub settings.

---

### ❌ "Push blocked — secret detected"
```
remote: - Push cannot contain secrets
```
**Cause:** A real token/password was hardcoded in a file (e.g. export.sh).
**Fix:** Replace with a placeholder, then amend and push:
```bash
# After fixing the file
git add <the-file>
git commit --amend --no-edit   # replace last commit (no new commit created)
git push -u origin master
```

---

### ❌ "src refspec master does not match any"
**Cause:** You ran `git push origin master` but git initialized with `main` branch.
**Fix:**
```bash
git branch        # check what branch you're actually on
git push -u origin main     # or whatever branch name is shown
```

---

### ❌ git remote -v still shows old URL after you changed it
```
origin  https://github.com/iam-veeramalla/go-web-app.git (fetch)
```
**Cause:** The folder is a Vagrant **synced folder**. The `.git/config` file syncs from the host.
If the HOST still has the old URL, every `vagrant up` / sync overwrites your change on the VM.
**Fix:** Change the remote URL on the **HOST first**, then on the VM:
```bash
# On HOST laptop
cd /home/srv/project_srv/go-web-app
git remote set-url origin git@github.com:rishu4u/go-web-app.git

# Then on Vagrant VM (if needed)
git remote set-url origin git@github.com:rishu4u/go-web-app.git
```
> ⭐ Rule: With synced folders, always make config changes on the HOST first.

---

### ❌ Jenkins pipeline fails — `go test ./...` can't find go.mod
```
pattern ./...: directory prefix . does not contain main module or its selected dependencies
```
**Cause:** Go source code (`main.go`, `go.mod`) and DevOps files (Jenkinsfile) were on
**different branches** of the same repo. Jenkins checked out the DevOps branch which has no `go.mod`.
**Fix:** Consolidate everything into one branch (`main`) as a unified folder structure:
```
go-web-app/ (main branch)
├── main.go
├── go.mod
└── devops_implementaion/
    ├── Jenkinsfile
    └── Dockerfile
```
```bash
# Copy devops files into go-web-app/ as a subfolder
cp -r /home/srv/project_srv/devops_implementaion \
      /home/srv/project_srv/go-web-app/devops_implementaion
cd /home/srv/project_srv/go-web-app
git add devops_implementaion/
git commit -m "feat: unify repo — add devops files as subfolder"
git pull --rebase origin main   # sync remote changes first
git push origin main
```
Then update Jenkins job → Branch: `*/main` | Script Path: `devops_implementaion/Jenkinsfile`

---

### ❌ Push rejected — remote contains work you don't have
```
error: failed to push some refs
hint: Updates were rejected because the remote contains work that you do not have locally
```
**Cause:** Someone (or another local folder) pushed to the same branch on GitHub before you did.
**Fix:** Pull first, then push:
```bash
git pull --rebase origin main   # rebase your commits on top of remote
git push origin main
```

---

### ❌ Push blocked — Docker Personal Access Token detected in commit
```
remote: - GITHUB PUSH PROTECTION
remote:   - Push cannot contain secrets
remote:   — Docker Personal Access Token
```
**Cause:** A real DockerHub PAT token was hardcoded in a file (e.g. `login.txt`) that got committed.
**Fix:** Replace token with a placeholder, amend the commit, force push:
```bash
# Edit the file — replace real token with placeholder text
vim devops_implementaion/jenkins_vagrant_server/login.txt
# Change: dckr_pat_xxxxx  →  <your-dockerhub-pat-token-here>

git add devops_implementaion/jenkins_vagrant_server/login.txt
git add devops_implementaion/docker_build_vagrant_server/login.txt
git commit --amend --no-edit        # rewrites last commit
git push --force-with-lease origin main   # force needed since history was rewritten
```
> ⚠️ After this, regenerate your DockerHub token — the old one is compromised.
> Update it on the Jenkins VM: `sudo nano /var/lib/jenkins/dockerhub_creds.env`

> 💡 The actual pipeline credentials stay safe in `/var/lib/jenkins/dockerhub_creds.env`
> which is NOT tracked by git — only `login.txt` (a notes file) had the issue.

---

## 1.10  IDENTITY vs REMOTE vs SSH SUMMARY TABLE

| | Command | What it controls | Affects push access? |
|---|---|---|---|
| Identity | `git config user.email` | Label shown on commit | ❌ No |
| Remote | `git remote -v` | Where to push (URL) | ❌ No |
| Access | `ssh -T git@github.com` | Permission to push | ✅ Yes |

---

## 1.11  REPO CLEANUP — Merging Two Branches Into One (What We Did)

**Problem:** Two local folders were pushing to the same GitHub repo on different branches:
```
go-web-app/           → main branch   (Go source only)
devops_implementaion/ → master branch (DevOps files only)

Result: 2 locations to edit, easy to push to wrong branch, Jenkins confused
```

**Solution:** Merge into one unified structure under `main` branch.

### Step 1 — Change GitHub default branch from `master` → `main`
```
GitHub → repo Settings → Branches → Default branch → switch to main → Update
```
> ⭐ GitHub won't let you delete the default branch via CLI. Must change it in UI first.

### Step 2 — Delete the old `master` branch from GitHub
```bash
git push origin --delete master
# ❌ Will fail if master is still the default branch (do Step 1 first)
```

### Step 3 — Rename old local folder to avoid confusion
```bash
mv /home/srv/project_srv/devops_implementaion \
   /home/srv/project_srv/devops_implementaion_OLD
```

### Step 4 — Fix Vagrantfile synced_folder paths
The Vagrantfile moved from:
```
devops_implementaion/jenkins_vagrant_server/Vagrantfile   (old)
go-web-app/devops_implementaion/jenkins_vagrant_server/Vagrantfile  (new)
```
Relative paths changed:
```ruby
# OLD (from devops_implementaion/jenkins_vagrant_server/):
config.vm.synced_folder "../../go-web-app",  "/home/vagrant/go-web-app"  ← was correct
config.vm.synced_folder "../",               "/home/vagrant/devops"      ← correct

# NEW (from go-web-app/devops_implementaion/jenkins_vagrant_server/):
config.vm.synced_folder "../../",  "/home/vagrant/go-web-app"  ← go up 2 = go-web-app/ root
config.vm.synced_folder "../",     "/home/vagrant/devops"      ← unchanged ✅
```

### Step 5 — Push and verify
```bash
cd /home/srv/project_srv/go-web-app
git add devops_implementaion/jenkins_vagrant_server/Vagrantfile
git commit -m "fix: update synced_folder paths for new repo structure"
git push origin main
```

### Where to run vagrant going forward
```bash
# NEW location (use this for all future vagrant operations)
cd /home/srv/project_srv/go-web-app/devops_implementaion/jenkins_vagrant_server
vagrant up / halt / ssh / destroy

# NOTE: The EXISTING running VM's .vagrant state is still in:
# devops_implementaion_OLD/jenkins_vagrant_server/.vagrant/
# For the already-running VM, run vagrant commands from OLD location
# When you recreate the VM, use the NEW location
```

### Final clean structure
```
/home/srv/project_srv/
├── go-web-app/                    → main branch (ONE source of truth ✅)
│   ├── main.go
│   ├── go.mod
│   ├── main_test.go
│   ├── static/
│   └── devops_implementaion/      ← ALL DevOps files here
│       ├── Jenkinsfile
│       ├── Dockerfile
│       ├── jenkins_vagrant_server/
│       ├── helm/
│       ├── k8s/
│       ├── flow_and_commands.md
│       ├── pipeline_plan.md
│       └── NOTES.md
├── devops_implementaion_OLD/      ← archived, don't edit
└── go-web-app-devops/             ← teacher's repo, reference only
```

---

---

# ═══════════════════════════════════════════
#  SECTION 2 — DOCKER
# ═══════════════════════════════════════════

## 2.1  CORE MENTAL MODEL

```
Source Code
    │
    ▼  docker build
Docker Image (blueprint — immutable snapshot)
    │
    ▼  docker run
Container (running live instance of the image)
    │
    ▼  docker push
DockerHub / Registry (remote storage of images)
```

---

## 2.2  DOCKERFILE — OUR PROJECT

```dockerfile
# Stage 1: Build binary
FROM golang:1.22 AS builder
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# Stage 2: Minimal runtime (distroless = no shell, small attack surface)
FROM gcr.io/distroless/base
WORKDIR /
COPY --from=builder /app/main   .
COPY --from=builder /app/static ./static
EXPOSE 8080
CMD ["./main"]
```

**Key pattern:** Multi-stage build
- Stage 1 (`builder`) compiles the code → has all Go tooling (~800MB)
- Stage 2 copies only the final binary → final image is ~20MB

---

## 2.3  DOCKER BUILD COMMANDS

```bash
# Basic build (tag with repo/name:version)
docker build -t rishu4u/go-web-app:v1.0 .

# Build using a specific Dockerfile path and a different context
docker build \
  -f /home/vagrant/devops/Dockerfile \
  -t rishu4u/go-web-app:v1.0 \
  /home/vagrant/go-web-app

# List all local images
docker images

# Remove an image
docker rmi rishu4u/go-web-app:v1.0
```

---

## 2.4  DOCKER RUN COMMANDS

```bash
# Run a container (interactive, remove on exit)
docker run --rm -p 8080:8080 rishu4u/go-web-app:v1.0

# Run in detached (background) mode
docker run -d --name my-app -p 8080:8080 rishu4u/go-web-app:v1.0

# See running containers
docker ps

# See all containers (including stopped)
docker ps -a

# Stop a container
docker stop my-app

# Remove a container
docker rm my-app

# View container logs
docker logs my-app
docker logs -f my-app    # follow live logs
```

---

## 2.5  DOCKER PUSH / PULL — DOCKERHUB

```bash
# Login to DockerHub (interactive)
docker login
# OR login non-interactively (used in Jenkins)
echo "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin

# Push image
docker push rishu4u/go-web-app:v1.0

# Pull image from DockerHub
docker pull rishu4u/go-web-app:v1.0

# Logout
docker logout
```

---

## 2.6  DOCKERHUB CREDENTIALS FILE (for Jenkins)

We store credentials in a file the jenkins user can read:

```
/var/lib/jenkins/dockerhub_creds.env
```

Contents:
```
DOCKERHUB_USERNAME=rishu4u
DOCKERHUB_TOKEN=your_dockerhub_access_token_here
```

Jenkins pipeline loads it like this:
```bash
export $(grep -v '^#' /var/lib/jenkins/dockerhub_creds.env | xargs)
echo "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin
```

> ⚠️ NEVER commit this file to Git. It's on the Jenkins VM filesystem only.

---

## 2.7  VERSION TRACKING FILE

We track the last pushed Docker image version in:
```
/var/lib/jenkins/.docker_version
```

Contains just the version string, e.g.: `v1.4`

Jenkins auto-increments minor version each run:
```
v1.3 → v1.4 → v1.5...
```

> ⚠️ This file is stored OUTSIDE the Jenkins workspace (`/var/lib/jenkins/`) so that
> `git checkout` during pipeline runs does NOT reset/wipe it between builds.

---

## 2.8  DOCKER DIAGNOSTIC COMMANDS

```bash
# See disk usage by images/containers/volumes
docker system df

# Remove all stopped containers
docker container prune

# Remove all unused images
docker image prune -a

# Remove everything unused (containers, images, networks, volumes)
docker system prune -a

# Inspect image layers
docker history rishu4u/go-web-app:v1.0

# Inspect image metadata (full JSON)
docker inspect rishu4u/go-web-app:v1.0
```

---

---

# ═══════════════════════════════════════════
#  SECTION 3 — JENKINS
# ═══════════════════════════════════════════

## 3.1  CORE MENTAL MODEL

```
GitHub (source code)
    │
    │  Jenkins polls / webhook triggers
    ▼
Jenkins Pipeline (Jenkinsfile)
    │
    ├── Stage 1: Checkout    → pull code from GitHub
    ├── Stage 2: Test        → go test ./...
    ├── Stage 3: Version Tag → auto-increment + user confirms
    ├── Stage 4: Docker Build → docker build
    ├── Stage 5: Approval    → human clicks Proceed / Abort
    ├── Stage 6: Docker Push  → docker push to DockerHub
    └── Stage 7: Helm Update  → update image tag in values.yaml
```

---

## 3.2  JENKINS SSH KEY SETUP — CRITICAL ⭐

Jenkins needs two keys set up to function. DO NOT SKIP these.

---

### KEY 1 — Jenkins user's SSH key → add PUBLIC key to GitHub

Jenkins pulls code from GitHub using the `jenkins` OS user.
That user needs its own SSH key registered in GitHub.

```bash
# Run ON the Jenkins Vagrant VM (vagrant ssh jenkins_vagrant_server)

# Step 1 — Generate key for the jenkins OS user
sudo -u jenkins ssh-keygen -t ed25519 -C "jenkins-vm" \
  -f /var/lib/jenkins/.ssh/id_ed25519 -N ""

# Step 2 — Print the PUBLIC key
sudo cat /var/lib/jenkins/.ssh/id_ed25519.pub
# Copy the entire output (starts with ssh-ed25519 AAAA...)

# Step 3 — Add to GitHub
# → https://github.com/settings/ssh/new
# → Title: Jenkins VM
# → Paste the public key

# Step 4 — Test authentication
sudo -u jenkins ssh -T git@github.com
# Expected: Hi rishu4u! You've successfully authenticated...
```

---

### KEY 2 — Private key → add to Jenkins GUI Credentials

Jenkins needs the **PRIVATE** key stored inside Jenkins to authenticate with GitHub
when running pipeline jobs.

```bash
# Print the PRIVATE key (keep this secret — never push to Git)
sudo cat /var/lib/jenkins/.ssh/id_ed25519
```

**In Jenkins UI:**
1. Go to: **Manage Jenkins → Credentials → (global) → Add Credentials**
2. Kind: **SSH Username with private key**
3. Fill in:
   | Field | Value |
   |---|---|
   | ID | `github-ssh` |
   | Description | `GitHub SSH Key for Jenkins` |
   | Username | `git` |
   | Private Key | ✅ Enter directly → paste `/var/lib/jenkins/.ssh/id_ed25519` contents |
4. Click **Create**

> ⭐ **Rule of thumb:**
> - **Public key** (`.pub`) → goes to **GitHub** (Settings → SSH Keys)
> - **Private key** (no `.pub`) → goes to **Jenkins GUI** (Credentials)

---

## 3.3  ALSO NEEDED — Vagrant User SSH Key → GitHub

If the Vagrant VM itself (not just Jenkins user) also needs to push or access GitHub
(e.g. for git operations in the pipeline run as vagrant user):

```bash
# On the Vagrant VM (either VM)

# Generate key for vagrant user
ssh-keygen -t ed25519 -C "vagrant-vm" -f ~/.ssh/id_ed25519 -N ""

# Print public key
cat ~/.ssh/id_ed25519.pub

# Add to GitHub Settings → SSH Keys
# Title: Vagrant VM
# Test:
ssh -T git@github.com
```

---

## 3.4  JENKINS JOB CONFIGURATION (Pipeline from SCM)

In Jenkins UI, configure the pipeline job:

**Dashboard → New Item → Pipeline → OK**

Under **Pipeline** section:
| Field | Value |
|---|---|
| Definition | Pipeline script from SCM |
| SCM | Git |
| Repository URL | `git@github.com:rishu4u/go-web-app.git` |
| Credentials | `github-ssh` (the one you added in step 3.2) |
| Branch | `*/main` |
| Script Path | `devops_implementaion/Jenkinsfile` |

> ⭐ Repository URL MUST be the **SSH URL** (`git@github.com:...`)
> NOT the HTTPS URL (`https://github.com/...`)
> because we're using SSH key authentication.

---

## 3.5  JENKINS URL & ACCESS

| Thing | Value |
|---|---|
| Jenkins Web UI | `http://192.168.56.12:8080` |
| Also accessible at | `http://localhost:9090` (port-forwarded to host) |
| Jenkins home dir | `/var/lib/jenkins/` |
| Jenkins SSH dir | `/var/lib/jenkins/.ssh/` |
| DockerHub creds file | `/var/lib/jenkins/dockerhub_creds.env` |
| Version tracker file | `/var/lib/jenkins/.docker_version` |
| Pipeline workspace | `/var/lib/jenkins/workspace/go-web-app/` |

---

## 3.6  OUR JENKINSFILE — PIPELINE STAGES EXPLAINED

```groovy
pipeline {
  agent any    // run on any available Jenkins agent

  environment {
    // WORKSPACE = /var/lib/jenkins/workspace/go-web-app  (Jenkins' own git checkout)
    // Jenkins runs as 'jenkins' OS user — NOT vagrant. WORKSPACE is fully accessible.
    APP_DIR      = "${WORKSPACE}"                              // Go source at repo root
    DEVOPS_DIR   = "${WORKSPACE}/devops_implementaion"         // DevOps files subfolder
    VERSION_FILE = "/var/lib/jenkins/.docker_version"          // OUTSIDE workspace (persists between builds)
    HELM_VALUES  = "${WORKSPACE}/devops_implementaion/helm/go-web-app-chart/values.yaml"
    CREDS_FILE   = "/var/lib/jenkins/dockerhub_creds.env"     // DockerHub login (never in git)
    GO_BIN       = "/usr/local/go/bin"
  }

  stages {

    stage('Checkout') { ... }
    // Jenkins clones git@github.com:rishu4u/go-web-app.git into WORKSPACE
    // The synced folder /home/vagrant/devops is COMPLETELY IGNORED by Jenkins

    stage('Test') {
      sh "cd ${APP_DIR} && go test ./..."
      // APP_DIR = WORKSPACE = repo root = has main.go + go.mod ✅
    }

    stage('Version Tag') {
      // 1. Reads VERSION_FILE → e.g. v1.0 (or defaults to v1.0 if file missing)
      // 2. Suggests v1.1 (auto-increments minor)
      // 3. Pipeline PAUSES — shows input dialog in Jenkins UI
      // 4. User accepts suggested tag or types custom one → clicks Proceed
    }

    stage('Docker Build') {
      sh "docker build -f ${DEVOPS_DIR}/Dockerfile -t ${IMAGE_TAG} ${APP_DIR}"
      // Dockerfile is in devops_implementaion/ subfolder
      // Build context is repo root (has main.go, go.mod, static/)
    }

    stage('Push to DockerHub?') {
      input(message: "Push saurabhhub1/go-web-app:v1.1 to DockerHub?", ok: "Yes, Push It!")
      // Pipeline PAUSES — human approval gate
    }

    stage('Docker Push') {
      // Loads DOCKERHUB_USERNAME + DOCKERHUB_TOKEN from /var/lib/jenkins/dockerhub_creds.env
      // Non-interactive login: echo "$TOKEN" | docker login --password-stdin
      // Then: docker push saurabhhub1/go-web-app:v1.1
      // Saves new version to VERSION_FILE after successful push
    }

    stage('Update Helm Tag') {
      sh "sed -i 's/tag: .*/tag: \"${IMAGE_VERSION}\"/' ${HELM_VALUES}"
      // Updates helm/go-web-app-chart/values.yaml with new image tag
      // This enables GitOps / Argo CD to detect and deploy the new version
    }
  }
}
```

---

## 3.7  KEY CONCEPT — Jenkins WORKSPACE vs Synced Folder

This is the most important thing to understand to avoid confusion:

```
What you might think Jenkins reads:
  /home/vagrant/devops/Jenkinsfile      ← Vagrant synced folder
           ❌ WRONG — Jenkins never touches this

What Jenkins ACTUALLY does:
  git clone git@github.com:rishu4u/go-web-app.git
         ↓
  /var/lib/jenkins/workspace/go-web-app/    ← Jenkins' OWN checkout
         ↓
  Reads Jenkinsfile from HERE
```

| Location | Who uses it | Purpose |
|---|---|---|
| `/home/vagrant/devops/` | You (editing) | Synced from host, convenient for editing |
| `/var/lib/jenkins/workspace/go-web-app/` | Jenkins | Fresh git clone every build, uses this |

**Consequence:** To update what Jenkins runs, you must:
1. Edit file on HOST → `git push` to GitHub → Jenkins picks it up on next Build Now
2. You do NOT need to do anything on the Vagrant VM for Jenkins to get the new file

**Why Jenkins runs as `jenkins` user (not `vagrant`):**
- `jenkins` OS user owns `/var/lib/jenkins/workspace/` — full access ✅
- `jenkins` user has NO access to `/home/vagrant/` — permission denied ❌
- This is why hardcoded `/home/vagrant/` paths in Jenkinsfile fail
- Solution: use `${WORKSPACE}` which always points to Jenkins' own checkout

---

## 3.8  HOW TO INTERACT WITH PIPELINE INPUT PROMPTS

The pipeline pauses at two stages waiting for human input:

### Stage 3 — Version Tag input

```
Jenkins UI shows:
┌─────────────────────────────────────────────────────┐
│  Last build: v1.0  |  Suggested next tag: v1.1      │
│  VERSION: [ v1.1                              ]     │
│           [ Proceed ]    [ Abort ]                  │
└─────────────────────────────────────────────────────┘
```

- **Accept suggestion** → just click **Proceed** (keeps v1.1)
- **Override** → clear the box, type your own (e.g. v2.0) → click **Proceed**
- **Cancel** → click **Abort** (pipeline stops cleanly)

### Stage 5 — DockerHub push approval

```
Push saurabhhub1/go-web-app:v1.1 to DockerHub?
[ Yes, Push It! ]    [ Abort ]
```

### How to find the input prompt in Jenkins UI

```
Jenkins → go-web-app job → Build #N (currently running)
  → Look for "Paused for Input" link in left sidebar
  OR
  → In Stage View, hover over the paused stage → click the prompt icon
```

> ⚠️ Jenkins waits indefinitely — pipeline won't timeout unless you configured a timeout.

---

## 3.9  DOCKERHUB CREDENTIALS — FULL FLOW

```
Where credentials come from:

  host: export DOCKERHUB_USERNAME=saurabhhub1
        export DOCKERHUB_TOKEN=dckr_pat_xxxxx
              │
              │  vagrant up (Vagrantfile passes env vars to provision script)
              ▼
  VM:   /var/lib/jenkins/dockerhub_creds.env
        DOCKERHUB_USERNAME=saurabhhub1
        DOCKERHUB_TOKEN=dckr_pat_xxxxx
        (chmod 600, owned by jenkins user)
              │
              │  Jenkins pipeline reads this file at Docker Push stage
              ▼
  Pipeline:   export $(grep -v '^#' /var/lib/jenkins/dockerhub_creds.env | xargs)
              echo "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin
              docker push saurabhhub1/go-web-app:v1.1
```

**Why non-interactive login (`--password-stdin`)?**
Jenkins pipeline runs non-interactively — there's no terminal to type a password.
Piping the token via stdin is the secure, automated way.

**If creds file is missing or wrong:**
```bash
# On Jenkins VM — recreate the file
sudo bash -c 'cat > /var/lib/jenkins/dockerhub_creds.env << EOF
DOCKERHUB_USERNAME=saurabhhub1
DOCKERHUB_TOKEN=your_new_token_here
EOF'
sudo chmod 600 /var/lib/jenkins/dockerhub_creds.env
sudo chown jenkins:jenkins /var/lib/jenkins/dockerhub_creds.env

# Verify
sudo cat /var/lib/jenkins/dockerhub_creds.env
```

---

## 3.10  UNIFIED REPO STRUCTURE — WHY WE DID IT

Originally, Go source and DevOps files were in **separate local folders on different branches**:
```
❌ BEFORE (broken):
  go-web-app/          → main branch   (Go source only)
  devops_implementaion/ → master branch (DevOps files only)

  Jenkins checked out master → no go.mod → go test FAILED
```

Fix — merged everything into ONE branch:
```
✅ AFTER (working):
  go-web-app/                    → main branch
  ├── main.go
  ├── go.mod
  ├── main_test.go
  ├── static/
  └── devops_implementaion/       ← DevOps files AS SUBFOLDER
      ├── Jenkinsfile
      ├── Dockerfile
      └── helm/

  Jenkins checks out main → has both go.mod AND Jenkinsfile ✅
```

How it was done:
```bash
cp -r /home/srv/project_srv/devops_implementaion \
      /home/srv/project_srv/go-web-app/devops_implementaion
cd /home/srv/project_srv/go-web-app
git add devops_implementaion/
git commit -m "feat: unify repo structure"
git pull --rebase origin main
git push origin main
```
Then Jenkins job was updated: Branch `*/main`, Script Path `devops_implementaion/Jenkinsfile`

---

## 3.11  JENKINS GOTCHAS WE HIT

### ❌ Jenkins pulling from synced folder path instead of GitHub

```
fatal: '/home/vagrant/devops' does not appear to be a git repository
```

**Cause:** Job was configured with a Vagrant synced folder path as Repository URL.  
Synced folders don't include the `.git` directory.  
**Fix:** Use the actual GitHub SSH URL: `git@github.com:rishu4u/go-web-app.git`

---

### ❌ Jenkins can't authenticate to GitHub

```
Host key verification failed.
```
or
```
Permission denied (publickey)
```

**Cause:** Jenkins user's SSH key not added to GitHub OR private key not stored in Jenkins credentials.  
**Fix:** Follow Section 3.2 — both steps (GitHub + Jenkins GUI).

---

### ❌ Docker command not found / permission denied

```
docker: command not found
# or
Got permission denied while trying to connect to the Docker daemon socket
```

**Cause:** Jenkins user not in the `docker` group.  
**Fix:**
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

---

### ❌ Go not found during test stage

```
go: command not found
```

**Cause:** Go is installed but not in Jenkins' default PATH.  
**Fix:** In Jenkinsfile, prepend Go bin to PATH:
```bash
export PATH=$PATH:/usr/local/go/bin
```

---

## 3.8  JENKINS SERVICE COMMANDS (on Jenkins Vagrant VM)

```bash
# Start / stop / restart Jenkins
sudo systemctl start jenkins
sudo systemctl stop jenkins
sudo systemctl restart jenkins

# Check Jenkins status
sudo systemctl status jenkins

# View Jenkins logs
sudo journalctl -u jenkins -f

# Jenkins version
jenkins --version
```

---

---

# ═══════════════════════════════════════════
#  SECTION 4 — VAGRANT (Quick ref)
# ═══════════════════════════════════════════

## 4.1  VAGRANT COMMANDS

```bash
# From host machine (where Vagrantfile is)

# Start all VMs defined in Vagrantfile
vagrant up

# Start a specific VM
vagrant up jenkins_vagrant_server

# SSH into a VM
vagrant ssh jenkins_vagrant_server

# Stop a VM (graceful)
vagrant halt jenkins_vagrant_server

# Destroy a VM (deletes it)
vagrant destroy jenkins_vagrant_server

# Check VM status
vagrant status

# Reload VM (apply Vagrantfile changes)
vagrant reload jenkins_vagrant_server

# Re-run provisioning scripts
vagrant provision jenkins_vagrant_server
```

---

## 4.2  VAGRANT VM NETWORK (OUR SETUP)

| VM | IP | Port |
|---|---|---|
| jenkins_vagrant_server | 192.168.56.12 | Jenkins UI: 8080 |
| build_test_vagrant_server | (future) | — |
| docker_build_vagrant_server | (future) | — |

---

---

# ═══════════════════════════════════════════
#  KEY POINTS SUMMARY — DON'T FORGET
# ═══════════════════════════════════════════

## Pipeline Status — First Successful Run ✅

```
✅ Checkout      — cloned rishu4u/go-web-app (main) into WORKSPACE
✅ Test          — go test ./...  PASSED
✅ Version Tag   — user entered v1.1 → pipeline continued
✅ Docker Build  — saurabhhub1/go-web-app:v1.1 built on Jenkins VM
✅ Approval      — user clicked "Yes, Push It!"
✅ Docker Push   — image pushed to DockerHub
✅ Helm Update   — values.yaml updated with tag v1.1

docker pull saurabhhub1/go-web-app:v1.1  ← this image is now live!
```

---

## SSH Key Distribution — Who Gets What

| Key Type | Source | Goes To |
|---|---|---|
| Jenkins user **PUBLIC** key | `/var/lib/jenkins/.ssh/id_ed25519.pub` | GitHub Settings → SSH Keys |
| Jenkins user **PRIVATE** key | `/var/lib/jenkins/.ssh/id_ed25519` | Jenkins GUI → Credentials (ID: `github-ssh`) |
| Vagrant user **PUBLIC** key | `~/.ssh/id_ed25519.pub` (on vagrant VM) | GitHub Settings → SSH Keys |
| Laptop user **PUBLIC** key | `~/.ssh/id_ed25519.pub` (on laptop) | GitHub Settings → SSH Keys |

---

## Quick "Is It Working?" Checklist

```bash
# On any machine before pushing:
ssh -T git@github.com          # ✅ should say Hi rishu4u!
git remote -v                  # ✅ should show YOUR repo SSH URL
git config user.name           # ✅ should show your name

# On Jenkins VM, as jenkins user:
sudo -u jenkins ssh -T git@github.com     # ✅ should say Hi rishu4u!
sudo -u jenkins docker ps                 # ✅ no permission denied
sudo cat /var/lib/jenkins/dockerhub_creds.env   # ✅ creds present
```

---

## Before Every Build — Mental Checklist

| Check | Command |
|---|---|
| Did you push latest Jenkinsfile changes? | `git push origin main` (from host) |
| Is Jenkins job on right branch? | Job config → `*/main` |
| Is Script Path correct? | `devops_implementaion/Jenkinsfile` |
| DockerHub creds on Jenkins VM? | `sudo cat /var/lib/jenkins/dockerhub_creds.env` |
| Jenkins SSH → GitHub working? | `sudo -u jenkins ssh -T git@github.com` |

---

*Last updated: 2026-04-07 — First pipeline run succeeded! saurabhhub1/go-web-app:v1.1 ✅*
