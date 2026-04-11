# Go Web App — DevOps Notes & Command Reference

> This file is updated progressively as the project evolves.
> Every command here was actually run and verified on the Jenkins Vagrant VM.

---

## CONCEPT: The 3 Things You Need to Push to GitHub

| Thing | What it is | Command to check |
|---|---|---|
| **Identity** | Who labels your commits | `git config user.email` |
| **Remote URL** | Where your code is pushed | `git remote -v` |
| **SSH Key** | Proves you have access rights | `ssh -T git@github.com` |

> Identity ≠ Authentication. You can set any name/email — it's just a label.
> SSH key is what actually lets you push.

---

## SCENARIO A: Take someone else's repo and make it yours

> Example: Teacher has `iam-veeramalla/go-web-app`, you want it in `rishu4u/go-web-app`

```bash
# Step 1 — Go into the cloned folder
cd /home/srv/project_srv/go-web-app

# Step 2 — Check where it currently points (will show teacher's URL)
git remote -v

# Step 3 — Create a NEW empty repo on github.com (no README, no .gitignore)
#           Go to: https://github.com/new
#           Name it: go-web-app

# Step 4 — Point the remote to YOUR new repo
git remote set-url origin git@github.com:rishu4u/go-web-app.git

# Step 5 — Verify it changed
git remote -v

# Step 6 — Push all existing commits to your account
git push -u origin main
```

---

## SCENARIO B: Push a brand new folder as a new repo

> Example: Your devops_implementaion/ folder has no git history yet

```bash
# Step 1 — Go into the folder
cd /home/srv/project_srv/devops_implementaion

# Step 2 — Initialize git
git init

# Step 3 — Create a NEW empty repo on github.com
#           Go to: https://github.com/new
#           Name it: go-web-app-devops

# Step 4 — Add the remote
git remote add origin git@github.com:rishu4u/go-web-app-devops.git

# Step 5 — Stage all files
git add .

# Step 6 — First commit
git commit -m "Initial commit"

# Step 7 — Push
git push -u origin master
```

---

## SCENARIO C: Future pushes (after making changes)

```bash
git add .
git commit -m "describe what you changed"
git push
```

---

## SSH KEY SETUP — Do this on EVERY machine you push from

> Your laptop, your Vagrant VM, your Jenkins VM — each needs its own key.

### Step 1 — Check if an SSH key already exists
```bash
ls ~/.ssh/
# Look for id_ed25519 and id_ed25519.pub
# If missing, generate one (Step 2)
```

### Step 2 — Generate an SSH key
```bash
ssh-keygen -t ed25519 -C "your-label" -f ~/.ssh/id_ed25519 -N ""
# -C is just a label (use machine name e.g. "rishu4u-vagrant")
# -N "" means no passphrase
```

### Step 3 — Print the public key (copy this)
```bash
cat ~/.ssh/id_ed25519.pub
# Output starts with: ssh-ed25519 AAAAC3...
```

### Step 4 — Add the key to GitHub
- Go to: **https://github.com/settings/ssh/new**
- Title: name of the machine (e.g. `Vagrant VM`, `Laptop`)
- Key: paste the output from Step 3
- Click **Add SSH key**

### Step 5 — Test the connection
```bash
ssh -T git@github.com
# Expected: Hi rishu4u! You've successfully authenticated...
```

---

## GIT IDENTITY — Set once per machine

```bash
git config --global user.name "rishu4u"
git config --global user.email "your@email.com"

# Verify
git config --global user.name
git config --global user.email
```

> Use `--global` to apply to all repos on that machine.
> Without `--global` it only applies to the current repo.

---

## COMMON CHECKS — Run these to diagnose any git issue

```bash
# 1. Am I authenticated?
ssh -T git@github.com

# 2. Where will this repo push to?
git remote -v

# 3. Who am I (commit labels)?
git config user.name
git config user.email

# 4. What branch am I on?
git branch

# 5. What files are staged/unstaged?
git status

# 6. See commit history
git log --oneline -5
```

---

## GOTCHAS WE HIT (learn from these)

### ❌ "does not appear to be a git repository"
```
fatal: '/home/vagrant/devops' does not appear to be a git repository
```
**Cause:** Jenkins was pointing at a Vagrant synced folder — synced folders
don't include the `.git` directory from the parent folder.
**Fix:** Point Jenkins at the actual GitHub repo URL (see Jenkins section below).

### ❌ "Permission denied (publickey)"
```
git@github.com: Permission denied (publickey).
```
**Cause:** This machine has no SSH key added to GitHub.
**Fix:** Follow the SSH KEY SETUP section above for this machine.

### ❌ "Push blocked — secret detected"
```
remote: - Push cannot contain secrets
```
**Cause:** A file (e.g. `export.sh`) had a real token hardcoded.
**Fix:** Replace with placeholder, amend the commit, then push:
```bash
# After fixing the file
git add <the-file>
git commit --amend --no-edit   # replaces last commit, no new commit
git push -u origin main
```

### ❌ Docker Personal Access Token detected by GitHub Push Protection
```
remote: - GITHUB PUSH PROTECTION
remote:   — Docker Personal Access Token
```
**Cause:** A real DockerHub token (`dckr_pat_xxxxx`) was committed inside a file
(e.g. `login.txt`) and GitHub's push protection scanner caught it.  
**Fix:**
```bash
# 1. Edit the file — replace real token with placeholder
vim devops_implementaion/jenkins_vagrant_server/login.txt
# Change: dckr_pat_xxxxx  →  <your-dockerhub-pat-token-here>

# 2. Amend the commit (rewrites last commit, no new commit)
git add devops_implementaion/jenkins_vagrant_server/login.txt
git commit --amend --no-edit

# 3. Force push (needed because history was rewritten)
git push --force-with-lease origin main
```
> ⚠️ After this — REGENERATE your DockerHub token. The old one is compromised.
> Update on Jenkins VM: `sudo nano /var/lib/jenkins/dockerhub_creds.env`

### ❌ `.vagrant/` files accidentally tracked by git
**Cause:** `.vagrant/` was missing from `.gitignore` so Vagrant's internal machine
state files (VM ID, SSH keys, PIDs) got staged and committed.  
**Fix:**
```bash
# Remove from git tracking (keeps files on disk)
git rm -r --cached devops_implementaion/jenkins_vagrant_server/.vagrant/

# Add to .gitignore
echo ".vagrant/" >> .gitignore

git add .gitignore
git commit -m "fix: add .vagrant/ to .gitignore"
git push origin main
```
> ⭐ Rule: `.vagrant/` is machine-specific state. NEVER commit it.

---

## JENKINS JOB CONFIGURATION

**Root cause of Jenkins pipeline error:**
Jenkins was set to "Pipeline script from SCM" with a local Vagrant synced
folder path — but synced folders have no `.git` directory.

**Fix — use your actual GitHub repo in Jenkins:**

| Field | Value |
|---|---|
| Definition | Pipeline script from SCM |
| SCM | Git |
| Repository URL | `git@github.com:rishu4u/go-web-app.git` |
| Credentials | `github-ssh` (SSH key added to Jenkins) |
| Branch | `*/main` |
| Script Path | `devops_implementaion/Jenkinsfile` |

### Add Jenkins SSH Key to GitHub

The Jenkins user on the Jenkins VM also needs its own SSH key:

```bash
# On the Jenkins VM (vagrant ssh into jenkins_vagrant_server)

# 1. Generate key for jenkins user
sudo -u jenkins ssh-keygen -t ed25519 -C "jenkins-vm" \
  -f /var/lib/jenkins/.ssh/id_ed25519 -N ""

# 2. Print public key — add this to GitHub
sudo cat /var/lib/jenkins/.ssh/id_ed25519.pub

# 3. Test
sudo -u jenkins ssh -T git@github.com
# Expected: Hi rishu4u!
```

Then add the key to: **https://github.com/settings/ssh/new**
Title: `Jenkins VM`

Then in Jenkins UI:
**Manage Jenkins → Credentials → Add → SSH Username with private key**
- ID: `github-ssh`
- Username: `git`
- Private key: paste `/var/lib/jenkins/.ssh/id_ed25519` contents

---

## REPOSITORY STRUCTURE

```
GitHub Account: rishu4u
│
├── go-web-app                      ← App source code (Go)
│   ├── main.go
│   ├── main_test.go
│   ├── go.mod
│   └── static/
│
└── go-web-app (devops_implementaion/)  ← DevOps pipeline files
    ├── Jenkinsfile
    ├── Dockerfile
    ├── helm/go-web-app-chart/      ← Helm chart
    ├── k8s/manifests/              ← Raw K8s YAMLs
    ├── build_test_vagrant_server/
    ├── docker_build_vagrant_server/
    └── jenkins_vagrant_server/
```

---

## PROJECT LAYOUT — What Is Each Folder?

```
/home/srv/project_srv/
├── go-web-app/                   ← YOUR repo (rishu4u/go-web-app) — ONE source of truth ✅
│   ├── main.go
│   ├── go.mod
│   ├── main_test.go
│   ├── static/
│   └── devops_implementaion/     ← ALL DevOps files live here as a subfolder
│       ├── Jenkinsfile
│       ├── Dockerfile
│       ├── helm/
│       ├── k8s/
│       ├── terraform/
│       └── jenkins_vagrant_server/
│
├── devops_implementaion_OLD/     ← archived, don't edit (pre-unification backup)
└── go-web-app-devops/            ← TEACHER's reference repo (iam-veeramalla)
                                     Read-only reference. Never push here.
```

> ⭐ `go-web-app-devops/` is the teacher's original repo cloned locally for reference.
> Your actual working copy is `go-web-app/devops_implementaion/` — that's what
> Jenkins pulls from GitHub.

---

## REPO CLEANUP — How We Unified Two Branches Into One

**Problem before cleanup:**
```
go-web-app/          → main branch   (Go source only, no Jenkinsfile)
devops_implementaion/ → master branch (DevOps files only, no go.mod)

Jenkins checked out master → no go.mod → go test FAILED ❌
```

**Solution — merge everything into one repo + one branch:**

```bash
# Step 1 — Copy DevOps files into go-web-app as a subfolder
cp -r /home/srv/project_srv/devops_implementaion \
       /home/srv/project_srv/go-web-app/devops_implementaion

# Step 2 — Push the unified structure
cd /home/srv/project_srv/go-web-app
git add devops_implementaion/
git commit -m "feat: unify repo — add devops files as subfolder"
git pull --rebase origin main
git push origin main

# Step 3 — Change GitHub default branch: master → main (in GitHub UI)
# GitHub → repo Settings → Branches → Default branch → switch to main → Update

# Step 4 — Delete old master branch from GitHub
git push origin --delete master

# Step 5 — Rename old folder so you don't accidentally edit it
mv /home/srv/project_srv/devops_implementaion \
   /home/srv/project_srv/devops_implementaion_OLD
```

**Then update Jenkins job:**
- Branch: `*/main`
- Script Path: `devops_implementaion/Jenkinsfile`

---

*Last updated: 2026-04-05 — SSH key setup, permission denied fix, Jenkins config*

---

## ARCHITECTURE — What We Have Built So Far

```
┌─────────────────────────────────────────────────────────────┐
│                    YOUR LAPTOP (Host)                       │
│                                                             │
│  /home/srv/project_srv/                                     │
│  ├── go-web-app/          ← Go app source code              │
│  └── devops_implementaion/ ← Jenkins, Helm, K8s, Vagrant    │
│                                                             │
│  Vagrant manages 2 VMs:                                     │
│  ┌──────────────────────┐  ┌──────────────────────────────┐ │
│  │  Jenkins VM          │  │  (future) Build/Test VM      │ │
│  │  192.168.56.12:8080  │  │                              │ │
│  │                      │  │                              │ │
│  │  /home/vagrant/      │  └──────────────────────────────┘ │
│  │  ├── go-web-app/     │                                   │
│  │  │   (synced from    │                                   │
│  │  │    host)          │                                   │
│  │  └── devops/         │                                   │
│  │      (synced from    │                                   │
│  │       host)          │                                   │
│  └──────────────────────┘                                   │
└─────────────────────────────────────────────────────────────┘
                         │
                         │ git push (SSH)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  GitHub (rishu4u)                           │
│                                                             │
│  rishu4u/go-web-app                                         │
│  ├── go-web-app source (main.go, go.mod...)                 │
│  └── devops_implementaion/ (Jenkinsfile, Helm, K8s...)      │
└─────────────────────────────────────────────────────────────┘
                         │
                         │ Jenkins pulls from GitHub
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              NEXT STEP: Jenkins Pipeline                    │
│                                                             │
│  Stage 1: Checkout  → git pull from rishu4u/go-web-app      │
│  Stage 2: Test      → go test ./...                         │
│  Stage 3: Version   → auto-increment tag (v1.0 → v1.1)      │
│  Stage 4: Build     → docker build -t rishu4u/go-web-app    │
│  Stage 5: Approve   → human clicks Proceed/Abort            │
│  Stage 6: Push      → docker push to DockerHub              │
│  Stage 7: Helm      → update image tag in values.yaml       │
└─────────────────────────────────────────────────────────────┘
```

### Current Status
| Component | Status |
|---|---|
| go-web-app source code | ✅ On GitHub (`rishu4u/go-web-app`) |
| devops_implementaion files | ✅ On GitHub (same repo) |
| SSH key on Jenkins VM | ✅ Set up and verified |
| git identity on Jenkins VM | ✅ Set (user.name + user.email) |
| Remote URL on Jenkins VM | ✅ Points to `rishu4u/go-web-app` |
| Jenkins job config | 🔲 Next step |
| Docker build via Jenkins | 🔲 Next step |
| DockerHub push via Jenkins | 🔲 Next step |

---

## HOW `git push` WORKS

```
Your Machine (VM)                    GitHub
─────────────────                    ──────
  commit A  ←── already there ───►  commit A
  commit B  ←── already there ───►  commit B
  commit C  ◄── NEW, not on GitHub
  commit D  ◄── NEW, not on GitHub

  git push  ──────── sends C, D ──► commit C
                                    commit D
```

Git only sends commits that GitHub doesn't have yet.

```bash
git push                  # push using default (set by -u)
git push -u origin main   # -u saves default, so future git push works alone
```

**Under the hood:**
1. SSH key checked → GitHub allows/denies access
2. Git compares local commits vs GitHub commits
3. Only new commits are sent
4. GitHub moves branch pointer to your latest commit

---

## HOW TO ROLLBACK A COMMIT

### Not pushed yet — 3 options

```bash
# Option 1: Undo commit, KEEP files staged (safest)
git reset --soft HEAD~1
# Use when: wrong commit message, not ready yet

# Option 2: Undo commit, unstage files, keep files on disk
git reset --mixed HEAD~1   # same as: git reset HEAD~1
# Use when: want to re-select what to stage

# Option 3: Undo commit AND delete file changes (destructive ⚠️)
git reset --hard HEAD~1
# Use when: want to completely go back in time
```

### Already pushed to GitHub — use revert

```bash
git revert HEAD     # creates a NEW commit that undoes last commit
git push            # push the revert commit
# Safe — does NOT rewrite history, GitHub won't complain
```

### Visual

```
BEFORE:   A → B → C      (C is last commit)

--soft    A → B           (C removed, files still staged)
--mixed   A → B           (C removed, files unstaged)
--hard    A → B           (C removed, files deleted from disk)
revert    A → B → C → D  (D undoes C, history preserved)
```

### Rule of thumb
| Situation | Command |
|---|---|
| Not pushed, redo commit message | `git reset --soft HEAD~1` |
| Not pushed, discard completely | `git reset --hard HEAD~1` |
| Already pushed to GitHub | `git revert HEAD` then `git push` |

---

## IDENTITY vs REMOTE vs SSH — Key Distinction

| | Command | What it controls | Auth? |
|---|---|---|---|
| Identity | `git config user.email` | Label on your commit (sender name) | ❌ No |
| Remote | `git remote -v` | Where to push (destination URL) | ❌ No |
| Access | `ssh -T git@github.com` | Permission to push | ✅ Yes |

> `git remote -v` showing your username does NOT mean you are logged in.
> SSH key is the ONLY thing that controls push access.

---

## JENKINS — PUSH GIT CHANGES FROM JENKINS VM (Stage 7)

**Why:** After Jenkins updates `helm/values.yaml` with the new image tag,
Argo CD needs to see that change in GitHub. Instead of pushing manually from
your laptop, the Jenkins pipeline itself does the `git push`.

**How it works in Jenkinsfile Stage 7:**
```groovy
sh """
  cd ${APP_DIR}   // = /var/lib/jenkins/workspace/go-web-app

  // Set git identity for jenkins user
  git config user.email "jenkins-bot@go-web-app.local"
  git config user.name  "Jenkins CI"

  // Pull latest first to avoid conflicts
  git fetch origin
  git checkout main
  git pull --rebase origin main

  // Stage only the updated file
  git add ${HELM_VALUES}

  // Commit only if something changed
  git diff --cached --quiet || \\
    git commit -m "ci: update Helm image tag to v1.2 [skip ci]"

  // Push using jenkins user's SSH key
  git push origin main
"""
```

**Prerequisites (already done in Section 3.2):**
- Jenkins user SSH key → public key added to GitHub ✅
- Private key added to Jenkins GUI Credentials ✅

> ⭐ `[skip ci]` in commit message — this is important! It tells GitHub Actions
> to NOT trigger the CI/CD pipeline again when Jenkins pushes the Helm tag update.
> Without it, Jenkins push → GitHub Actions triggers → infinite loop.

---

## GITIGNORE — WHAT MUST ALWAYS BE IGNORED

| Pattern | What it is | Why ignore |
|---|---|---|
| `.vagrant/` | Vagrant VM state files | Machine-specific, causes conflicts |
| `*.tfstate` / `*.tfstate.backup` | Terraform state | Contains secrets + infra details |
| `.terraform/` | Terraform provider cache | Large, auto-downloaded |
| `.terraform.lock.hcl` | Provider version lock | Can conflict between OS |
| `*.env` / `dockerhub_creds.env` | Credentials files | Real tokens — NEVER in git |
| `~/.aws/credentials` | AWS access keys | Already excluded by OS, but never stage |

---

## IDENTITY vs REMOTE vs SSH — Key Distinction

| | Command | What it controls | Auth? |
|---|---|---|---|
| Identity | `git config user.email` | Label on your commit (sender name) | ❌ No |
| Remote | `git remote -v` | Where to push (destination URL) | ❌ No |
| Access | `ssh -T git@github.com` | Permission to push | ✅ Yes |

> `git remote -v` showing your username does NOT mean you are logged in.
> SSH key is the ONLY thing that controls push access.

---

# PHASE 2 — TERRAFORM + AWS

## Where Terraform Runs

Terraform is installed on the **Jenkins Vagrant VM** (not the host laptop).
This means eventually Jenkins can trigger Terraform as part of the pipeline too.

```
Jenkins Vagrant VM (192.168.56.12)
├── Jenkins         ✅ CI — build, test, push Docker image
├── AWS CLI         ✅ authenticate to AWS
├── Terraform       ✅ provision VPC, EC2, Security Groups
└── kubectl         🔲 manage K8s cluster (Phase 4)
```

---

## AWS IAM User Setup (one-time, in browser)

```
1. AWS Console → IAM → Users → Create User
   Name: terraform-devops

2. Permissions → Attach policy: AdministratorAccess
   (tighten to least privilege once stable)

3. After creation → Security Credentials tab
   → Create Access Key → CLI use case
   → Download / copy Access Key ID + Secret Access Key

⚠️ NEVER paste credentials into chat, Git commits, or Slack.
   Store ONLY in: ~/.aws/credentials  (on the machine that needs them)
```

---

## Install AWS CLI (on Jenkins Vagrant VM)

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

---

## Install Terraform (on Jenkins Vagrant VM)

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install -y terraform
terraform --version
```

---

## Configure AWS CLI

```bash
aws configure
# AWS Access Key ID:     <your-key-id>
# AWS Secret Access Key: <your-secret>
# Default region name:   us-east-1
# Default output format: json

# Verify — shows your IAM user
aws sts get-caller-identity
# Expected: { "Account": "505609702814", "Arn": "arn:aws:iam::..." }
```

> ⚠️ `~/.aws/credentials` has real keys. Never commit, never share.

---

## Terraform Core Commands

```bash
terraform init      # download AWS provider plugin (run once per directory)
terraform plan      # preview what will be CREATED / CHANGED / DESTROYED
terraform apply     # actually create the infrastructure (prompts "yes")
terraform destroy   # tear down ALL resources
terraform output    # show outputs (EC2 IPs, etc.) after apply
terraform show      # show current state
terraform state list  # list all resources in state
```

---

## Terraform File Structure (our project)

```
devops_implementaion/terraform/
├── main.tf              ← AWS provider config + EC2 instances
├── vpc.tf               ← VPC, subnets, internet gateway, route table
├── security_groups.tf   ← firewall rules (which ports open to whom)
├── variables.tf         ← input variable declarations
├── outputs.tf           ← what to print after apply (EC2 IPs, etc.)
└── terraform.tfvars     ← actual values (⚠️ gitignored! has real values)
```

---

## AWS Infrastructure We're Building

```
AWS us-east-1
└── VPC (10.0.0.0/16)
    ├── Public Subnet (10.0.1.0/24) — us-east-1a
    │   └── Internet Gateway → Route Table
    ├── EC2 — K8s Master Node (t3.medium: 2 vCPU, 4 GB)
    │   └── Security Group: allow 22, 6443, 8080
    └── EC2 — K8s Worker Node (t3.medium: 2 vCPU, 4 GB)
        └── Security Group: allow 22, 80, 8080

Key Pair: terraform-key  (SSH access to EC2 instances)
```

---

## Credentials Security — Golden Rules

| ✅ Safe | ❌ Never do |
|---|---|
| `~/.aws/credentials` on that machine only | Hardcode in `.tf` files |
| Environment variables (`AWS_ACCESS_KEY_ID`) | Paste in chat / email |
| AWS IAM roles (best for production) | Commit to git |
| `terraform.tfvars` in `.gitignore` | Share access key + secret together |

---

*Last updated: 2026-04-11 — Fixed */master → */main, added repo cleanup, new gotchas (.vagrant, Docker PAT, [skip ci]), Jenkins git push from VM, go-web-app-devops reference, Phase 2 Terraform + AWS ✅*
