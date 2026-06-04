# Go Web App — DevOps Notes & Command Reference:

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

> `~/.ssh/` is a hidden folder in your home directory where SSH stores all keys.

### Step 2 — Generate an SSH key

```bash
ssh-keygen -t ed25519 -C "your-label" -f ~/.ssh/id_ed25519 -N ""
```

**Every flag explained:**

| Flag | What it means | Your value |
|---|---|---|
| `-t ed25519` | **Type** of key algorithm to generate. `ed25519` is modern, fast, and secure. Old default was `rsa`. Always use `ed25519` now. | `ed25519` |
| `-C "your-label"` | **Comment** — just a human-readable label baked into the key. Helps you identify WHERE this key came from when you see it on GitHub. Use machine name e.g. `"jenkins-vm"` | e.g. `"jenkins-vm"` |
| `-f ~/.ssh/id_ed25519` | **File** — where to save the key. Creates TWO files: `id_ed25519` (private) and `id_ed25519.pub` (public). | `~/.ssh/id_ed25519` |
| `-N ""` | **New passphrase** — the `""` means NO passphrase. Without this it asks you interactively. We skip passphrase so Jenkins can use the key non-interactively (no human to type it). | `""` (empty) |

> **Why two files?**
> - `id_ed25519`     → **Private key** — stays on THIS machine ONLY. Never share. Never commit.
> - `id_ed25519.pub` → **Public key**  — you paste this to GitHub/servers to register your machine.

> **How it works (SSH handshake):**
> ```
> Key pair generated:  Private key (you keep)  +  Public key (you share with GitHub)
>
> When you push:
>   Your machine signs a message with PRIVATE key  →  sends to GitHub
>   GitHub checks it with PUBLIC key               →  "matches! identity verified"
>   Result: push allowed ✅
> ```
> You never send your private key — only use it to sign. GitHub never sees it.

### Step 3 — Print the public key (copy this)
```bash
cat ~/.ssh/id_ed25519.pub
# Output starts with: ssh-ed25519 AAAAC3...
```
> `cat` = print file contents to screen. The `.pub` file is safe to share — that's the point.

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

**Flag explained:**

| Part | Meaning |
|---|---|
| `ssh` | SSH client — makes SSH connections |
| `-T` | **No terminal** — disable pseudo-terminal allocation. GitHub doesn't give you a shell, so without `-T` SSH would show a warning. `-T` suppresses that and makes the output clean. |
| `git@github.com` | User `git` on host `github.com`. GitHub uses `git` as the username for all accounts — it distinguishes WHO you are by your SSH key, not by username. |

> **What this tests:** Does GitHub recognize this machine's SSH key?
> If it prints `Hi rishu4u!` → your key in `~/.ssh/id_ed25519` matches what's registered in GitHub. ✅

---


## GIT IDENTITY — Set once per machine

```bash
git config --global user.name  "rishu4u"
git config --global user.email "your@email.com"

# Verify
git config --global user.name
git config --global user.email
```

**Flag explained:**

| Flag/Part | Meaning |
|---|---|
| `git config` | Read or write git configuration values |
| `--global` | Apply to **ALL repos on this machine** — stored in `~/.gitconfig` |
| `--local` | Apply only to the **current repo** — stored in `.git/config` inside that folder |
| `--system` | Apply to **all users on this machine** — stored in `/etc/gitconfig` |
| `user.name` | The display name that appears on your commits (like a label — not login) |
| `user.email` | The email that appears on your commits (also just a label — not login) |

> **Scope priority (most specific wins):**
> ```
> --system  (all users on machine)     ← overridden by ↓
> --global  (all repos for your user)  ← overridden by ↓
> --local   (this repo only)           ← highest priority
> ```
> So if you set `--global` email but `--local` email in a specific repo, the `--local` one wins.

> ⭐ **Identity ≠ Authentication.** Setting `user.name`/`user.email` does NOT give push access.
> It's just a label on your commit — like a name tag. The SSH key is what controls access.


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

# 6. See commit history (short format)
git log --oneline -5
# --oneline  = one line per commit (short SHA + message)
# -5         = show last 5 commits only (limit the output)
```

> **`git log` flags reference:**
> | Flag | Meaning |
> |---|---|
> | `--oneline` | Condenses each commit to one line: short SHA + message |
> | `-5` / `-N` | Show only last N commits |
> | `--graph` | Show branch/merge history as ASCII art |
> | `--all` | Show ALL branches (not just current) |
> | Combined: `git log --oneline --graph --all -10` | Very useful overview of all branches |

> **`git pull --rebase` explained (used in our pipeline & repo cleanup):**
> | Flag | Meaning |
> |---|---|
> | `git pull` | Fetch remote changes + merge them into your local branch |
> | `--rebase` | Instead of a merge commit, **replay your local commits on top** of the fetched commits. Keeps history clean and linear. |
>
> ```
> Without --rebase (merge):         With --rebase:
> A - B - C (remote)                A - B - C (remote)
>       \                                     \
>        D - E (your commits) → merge          D'- E' (your commits replayed on top)
>              \                           (no merge commit, cleaner history)
>               M (merge commit)
> ```
> Rule: Use `--rebase` when pulling before pushing to avoid unnecessary merge commits.

---

## LINUX COMMAND — `usermod` (Adding User to a Group)

```bash
sudo usermod -aG docker jenkins
```

**Every part explained:**

| Part | Meaning |
|---|---|
| `sudo` | Run as root — required, modifying users needs root privileges |
| `usermod` | **User modify** — change properties of an existing user |
| `-a` | **Append** — add to the group WITHOUT removing from other groups |
| `-G docker` | **Groups** — which supplementary group to add the user to |
| `jenkins` | The **LOGIN** (username) to modify — **required, must be last argument** |

> ⚠️ **`-a` and `-G` MUST always be used together.**
> ```bash
> sudo usermod -aG docker jenkins    # ✅ SAFE — adds to docker, keeps all other groups
> sudo usermod -G docker jenkins     # ❌ DANGEROUS — removes jenkins from ALL other groups first!
> ```

> **After running this, always restart Jenkins:**
> ```bash
> sudo systemctl restart jenkins
> ```
> **Why restart?** Group membership is read at process start time.
> Jenkins was already running before you added it to `docker` group.
> The running process still has the OLD group list.
> Restarting Jenkins forces it to re-read its group memberships → docker now works.

### ❌ GOTCHA: Ran without username — got usage/help output

```bash
sudo usermod -aG docker      # ← missing username at the end
# Result: prints the long usage/help text — no error, just tells you it needs LOGIN
```
**Fix:** Always put the **username as the last argument:**
```bash
sudo usermod -aG docker jenkins     # jenkins user (for CI pipeline)
sudo usermod -aG docker vagrant     # vagrant user (for manual testing inside VM)
sudo usermod -aG docker $USER       # current user (on your laptop)
```

### Verify it worked:
```bash
# Check which groups jenkins belongs to
groups jenkins
# Expected output should include 'docker' in the list

# Or verify directly
sudo -u jenkins docker ps
# Expected: empty table (no permission denied = group membership is active)
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

> **`git commit --amend` flags explained:**
> | Flag | Meaning |
> |---|---|
> | `--amend` | **Rewrite** the last commit instead of creating a new one. Replaces old commit with a new one (different SHA). Use this to fix a mistake in the most recent commit. |
> | `--no-edit` | Keep the **same commit message** as the last commit — don't open the editor to retype it. Without this flag, it opens your text editor asking you to re-enter the message. |
>
> **`git push -u` flag explained:**
> | Flag | Meaning |
> |---|---|
> | `-u` | Short for `--set-upstream`. Saves `origin main` as the **default** for this branch. After doing this once, future `git push` (no args) works automatically. |
> | `origin` | The name of the remote (GitHub). `origin` is the standard default name. |
> | `main` | The branch name to push to. |

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
> **`git push --force-with-lease` explained:**
> | Flag | Meaning |
> |---|---|
> | `--force` | Overwrite the remote branch with your local version, even if remote has newer commits. ⚠️ Dangerous — can delete others' work. |
> | `--force-with-lease` | **Safer force push** — only overwrites if nobody else pushed new commits since you last fetched. If someone else pushed, it FAILS instead of overwriting their work. Always prefer this over bare `--force`. |
>
> **Why is force push needed after `--amend`?**
> `--amend` rewrites the last commit → creates a NEW commit SHA (different ID).
> GitHub still has the OLD commit SHA. A normal push would fail because the histories diverged.
> Force push says "replace GitHub's version with mine" — which is safe here since it was your own last commit.
> Rule: `--force-with-lease` after `--amend` = safe ✅
> ⚠️ After this — REGENERATE your DockerHub token. The old one is compromised.
> Update on Jenkins VM: `sudo nano /var/lib/jenkins/dockerhub_creds.env`

### ❌ `.vagrant/` files accidentally tracked by git
**Cause:** `.vagrant/` was missing from `.gitignore` so Vagrant's internal machine
state files (VM ID, SSH keys, PIDs) got staged and committed.  
**Fix:**
```bash
# Remove from git tracking (keeps files on disk)
git rm -r --cached devops_implementaion/jenkins_vagrant_server/.vagrant/
```
> **`git rm` flags explained:**
> | Flag | Meaning |
> |---|---|
> | `rm` | Remove files from git tracking |
> | `-r` | **Recursive** — remove a directory and everything inside it (not just a single file) |
> | `--cached` | Remove from git index (tracking) only — **do NOT delete from disk**. Without this flag, it would delete the actual files from your filesystem too. |
>
> **Result:** `.vagrant/` folder still exists on your disk, but git stops tracking it.
> Next commit will record "these files were removed from git" → GitHub won't have them anymore.

# Add to .gitignore
echo ".vagrant/" >> .gitignore

git add .gitignore
git commit -m "fix: add .vagrant/ to .gitignore"
git push origin main
```
> ⭐ Rule: `.vagrant/` is machine-specific state. NEVER commit it.

---

## HOW JENKINS WORKS — 3 Key Connections Explained

---

### Q1: Where is the Workspace Directory Set?

**Jenkins assigns it automatically based on the job name. You never set it manually.**

```
Job name in Jenkins UI: go-web-app
                ↓
Jenkins creates: /var/lib/jenkins/workspace/go-web-app/
```

In our Jenkinsfile we just USE the built-in `${WORKSPACE}` variable:

```groovy
environment {
    APP_DIR    = "${WORKSPACE}"                  // /var/lib/jenkins/workspace/go-web-app
    DEVOPS_DIR = "${WORKSPACE}/devops_implementaion"
    HELM_VALUES= "${WORKSPACE}/devops_implementaion/helm/go-web-app-chart/values.yaml"
}
```

When Stage 1 (Checkout) runs, Jenkins clones the GitHub repo INTO this folder.
After checkout the folder looks like:

```
/var/lib/jenkins/workspace/go-web-app/   ← ${WORKSPACE}
├── main.go
├── go.mod
├── main_test.go
└── devops_implementaion/
    ├── Jenkinsfile
    ├── Dockerfile
    └── helm/
```

> ⭐ You confirmed this with: `ls /var/lib/jenkins/workspace/` → showed `go-web-app` ✅

---

### Q2: Where is the DockerHub Token Used?

**Stored on Jenkins VM disk (NOT in git). Read and used in Stage 6 (Docker Push).**

#### Where it's stored:
```
/var/lib/jenkins/dockerhub_creds.env    ← on Jenkins VM disk only
DOCKERHUB_USERNAME=saurabhhub1
DOCKERHUB_TOKEN=dckr_pat_xxxxx
```

#### How Stage 6 in our Jenkinsfile uses it:
```groovy
// Stage 6 — Docker Push
sh """
  # Step 1: Load both variables from the file into shell environment
  export $(grep -v '^#' ${CREDS_FILE} | xargs)

  # Step 2: Login to DockerHub using the token
  echo "$DOCKERHUB_TOKEN" | docker login \
    --username "$DOCKERHUB_USERNAME" \
    --password-stdin

  # Step 3: Push the built image
  docker push ${env.IMAGE_TAG}
"""
```

> **`grep -v '^#' file | xargs` — command breakdown:**
> | Part | Meaning |
> |---|---|
> | `grep` | Search tool — filters lines |
> | `-v` | **Invert** match — return lines that do NOT match the pattern |
> | `'^#'` | Pattern: lines starting with `#` (comments). So `-v '^#'` = skip comment lines |
> | `\|` | **Pipe** — send output of grep as input to next command |
> | `xargs` | Takes lines of text and passes them as arguments to a command. Here, converts `KEY=VALUE` lines into shell arguments |
> | `export $(...)` | Loads all `KEY=VALUE` pairs as shell environment variables |
>
> **Example — what it does step by step:**
> ```
> dockerhub_creds.env contents:
> # This is a comment line
> DOCKERHUB_USERNAME=saurabhhub1
> DOCKERHUB_TOKEN=dckr_pat_xxxxx
>
> grep -v '^#'  →  skips comment line, outputs:
>   DOCKERHUB_USERNAME=saurabhhub1
>   DOCKERHUB_TOKEN=dckr_pat_xxxxx
>
> | xargs  →  becomes arguments:
>   DOCKERHUB_USERNAME=saurabhhub1 DOCKERHUB_TOKEN=dckr_pat_xxxxx
>
> export $(...)  →  sets them as env variables in this shell session
>   Now $DOCKERHUB_USERNAME and $DOCKERHUB_TOKEN are usable below
> ```

> **`docker login --password-stdin` flag explained:**
> | Flag | Meaning |
> |---|---|
> | `--username` | DockerHub account username |
> | `--password-stdin` | Read the password from stdin (piped input) instead of typing it interactively. Safer than `--password "token"` which would expose it in process list. |
>
> `echo "$DOCKERHUB_TOKEN" | docker login --password-stdin` = secure, non-interactive login ✅

#### Full token flow:
```
dockerhub_creds.env          Jenkinsfile Stage 6          DockerHub
(VM disk, never in git) ──►  export + docker login   ──►  accepts push ✅
DOCKERHUB_TOKEN=xxxx         echo $TOKEN | login          saurabhhub1/go-web-app:v1.5
```

> ⭐ Also in Stage 3 (Version Tag), the Jenkinsfile reads DOCKERHUB_USERNAME from
> the same file → builds the full image tag: `saurabhhub1/go-web-app:v1.5`

> ✅ Both are now correct and consistent:
> - Creds file: `DOCKERHUB_USERNAME=saurabhhub1`
> - Image tag built: `saurabhhub1/go-web-app:vX.Y`
> - DockerHub account: `saurabhhub1`
> - GitHub repo: `rishu4u/go-web-app` (different — that's fine, separate services)

---

### Q3: How is Jenkins Connected to GitHub?

**Three places — ALL three must be set up for it to work:**

#### Place 1 — Jenkins Job UI (tells Jenkins WHERE and WHAT)
> Jenkins UI → Your Job → Configure → Pipeline (scroll to bottom)

```
Definition:    Pipeline script from SCM
SCM:           Git
Repo URL:      git@github.com:rishu4u/go-web-app.git   ← WHERE to clone from
Credentials:   github-ssh                               ← SSH key to authenticate
Branch:        */main
Script Path:   devops_implementaion/Jenkinsfile         ← which file to run
```

#### Place 2 — Jenkins Credentials Store (the SSH private key)
> Jenkins UI → Manage Jenkins → Credentials → global → Add Credentials

```
Kind:         SSH Username with private key
ID:           github-ssh                    ← matches what you set in Place 1
Username:     git
Private Key:  (paste contents of /var/lib/jenkins/.ssh/id_ed25519)
```

#### Place 3 — GitHub Settings (trusts the Jenkins key)
> github.com → Settings → SSH and GPG keys → New SSH key

```
Title:  Jenkins VM
Key:    (paste contents of /var/lib/jenkins/.ssh/id_ed25519.pub)
```

#### Why all 3 are needed:
```
Place 1: Jenkins knows WHICH repo to pull from
Place 2: Jenkins has the private key to prove its identity
Place 3: GitHub has the public key → trusts Jenkins when it connects

Private key (Place 2) + Public key (Place 3) = SSH handshake = Jenkins can pull/push
```

#### Full connection flow:
```
Jenkins job starts
    │
    ▼
Reads job config (Place 1) → knows repo URL: git@github.com:rishu4u/go-web-app.git
    │
    ▼
Picks 'github-ssh' credential (Place 2) → loads private key
    │
    ▼  SSH connection →
GitHub checks public key (Place 3) → "I trust this key → access granted"
    │
    ▼
Jenkins clones repo into WORKSPACE
    │
    ▼
Runs devops_implementaion/Jenkinsfile
```

> ⭐ Verified: `sudo -u jenkins ssh -T git@github.com` → `Hi rishu4u!` ✅
> This confirms Places 2 + 3 are working correctly.

---

### Summary Table

| Thing | Where it's configured | Set by |
|---|---|---|
| **Workspace** | Auto: `/var/lib/jenkins/workspace/<job-name>/` | Jenkins (automatic) |
| **GitHub repo URL** | Jenkins UI → Job → Configure → SCM | You (one-time) |
| **GitHub auth (private key)** | Jenkins UI → Manage Jenkins → Credentials | You (one-time) |
| **GitHub trust (public key)** | github.com → Settings → SSH Keys | You (one-time) |
| **DockerHub token storage** | `/var/lib/jenkins/dockerhub_creds.env` on VM | You (update when token rotates) |
| **DockerHub login code** | Jenkinsfile Stage 6 (`docker login`) | Jenkinsfile (runs every build) |

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
│  Stage 4: Build     → docker build -t saurabhhub1/go-web-app│
│  Stage 5: Approve   → human clicks Proceed/Abort            │
│  Stage 6: Push      → docker push to DockerHub              │
│  Stage 7: Helm      → update image tag in values.yaml       │
└─────────────────────────────────────────────────────────────┘
```

### Phase 1 — COMPLETE ✅ (2026-04-16)
| Component | Status |
|---|---|
| go-web-app source code | ✅ On GitHub (`rishu4u/go-web-app`) |
| devops_implementaion files | ✅ On GitHub (same repo, `main` branch) |
| SSH key on Jenkins VM (git push) | ✅ Set up and verified |
| git identity on Jenkins VM | ✅ Set (user.name + user.email) |
| Remote URL on Jenkins VM | ✅ Points to `rishu4u/go-web-app` |
| Jenkins job — Git SCM URL | ✅ `git@github.com:rishu4u/go-web-app.git` |
| Jenkins job — Branch | ✅ `*/main` |
| Jenkins job — Script Path | ✅ `devops_implementaion/Jenkinsfile` |
| Jenkinsfile — all stages | ✅ Checkout, Test, Version, Build, Approve, Push, Helm update |
| Docker build via Jenkins | ✅ Building `saurabhhub1/go-web-app:vX.Y` |
| DockerHub push via Jenkins | ✅ Human approval gate before push |
| Helm values.yaml auto-update | ✅ Jenkins commits + pushes image tag via git push |
| Terraform infra files | ✅ Written (VPC, EC2, SG, vars) — *apply pending* |
| AWS CLI configured on Jenkins VM | ✅ `aws sts get-caller-identity` verified |
| Terraform installed on Jenkins VM | ✅ |

### Phase 2 — IN PROGRESS 🔄
| Component | Status |
|---|---|
| Terraform apply (create VPC + EC2) | 🔲 Pending |
| Jenkins VM → EKS / K8s cluster setup | 🔲 Pending |
| ArgoCD GitOps pull from GitHub | 🔲 Pending |

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
   Name: rishu4u_aws  (our actual IAM user)

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
```

Our actual output (verified ✅):
```json
{
    "UserId": "AIDAXLOFPZWPB7N6U4X4E",
    "Account": "505609702814",
    "Arn": "arn:aws:iam::505609702814:user/rishu4u_aws"
}
```

> ⚠️ NOTE: The above was verified on the HOST machine.
> Run the same command inside the Jenkins Vagrant VM to confirm it's configured there too.

> ⚠️ `~/.aws/credentials` has real keys. Never commit, never share.

---

## Terraform Core Commands

```bash
terraform init      # download AWS provider plugin (run once per directory)
terraform plan      # preview what will be CREATED / CHANGED / DESTROYED
terraform apply     # actually create the infrastructure (prompts "yes")
terraform destroy   # tear down ALL resources ⚠️ do this when done!
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

## UNDERSTANDING THE 3 DIRECTORIES IN `/home/srv/project_srv/`

> ⭐ This confused me — writing it down so I never forget.

### What each folder actually is:

| Folder | What it is | Branch | Push here? |
|---|---|---|---|
| `go-web-app/` | **YOUR working repo** — One Source of Truth | `main` | ✅ YES |
| `devops_implementaion_OLD/` | **ARCHIVE** — old separate devops folder before we unified | `master` | ❌ No (delete it) |
| `go-web-app-devops/` | **TEACHER's repo** — reference only (iam-veeramalla) | `main` | ❌ No |

### Why does each folder show same remote `git@github.com:rishu4u/go-web-app.git`?

When we **unified** the repo:
- `go-web-app/` already pointed to `rishu4u/go-web-app` → that's correct ✅
- `devops_implementaion_OLD/` — it was ALSO set to push to that same repo (on the old `master` branch)
  - That old `master` branch was **deleted** from GitHub after unification
  - So this folder's remote still shows the URL but there's **nothing on GitHub's master branch** anymore
  - It's safe to delete this folder entirely

### Why is `project_srv/` itself also a git repo (with `master` branch)?

The root `/home/srv/project_srv/` has its own `.git` from an **early experiment**  
when we initialized git there before deciding the structure.  
> It points to `rishu4u/go-web-app` too, but on `master` branch — it's a leftover.

**You do NOT need this.** Your single source of truth is `go-web-app/` on `main`.

### Clean mental model (final):

```
/home/srv/project_srv/
├── go-web-app/                 ← ✅ YOUR REPO  (edit, commit, push here ONLY)
│   ├── main.go
│   ├── go.mod
│   └── devops_implementaion/  ← All DevOps files live here
│
├── devops_implementaion_OLD/  ← 🗑️  SAFE TO DELETE (archived backup)
└── go-web-app-devops/         ← 📖  TEACHER's reference (never push here)
```

### Should we delete `devops_implementaion_OLD/`?

**Yes — it is safe to delete.** Here's why:
- All content was copied into `go-web-app/devops_implementaion/` and pushed to GitHub ✅
- The `master` branch it was on has been deleted from GitHub ✅
- Keeping it only causes confusion about "which folder to edit"

**Command to delete it (run yourself — review before deleting!):**
```bash
# First, double-check there's nothing unique in it
ls /home/srv/project_srv/devops_implementaion_OLD/

# If OK, delete it
rm -rf /home/srv/project_srv/devops_implementaion_OLD
```

---

## JENKINS VM GIT SETUP — VERIFY EVERYTHING IS CORRECT

> Before assuming Jenkins VM is set up, always verify. Here's what to check:

### Step 1 — SSH into Jenkins VM
```bash
# From your laptop, go to the Vagrantfile location
cd /home/srv/project_srv/go-web-app/devops_implementaion/jenkins_vagrant_server
vagrant ssh
# OR if VM is up on a different terminal:
ssh vagrant@192.168.56.12
```

### Step 2 — Full diagnostic checklist on Jenkins VM
```bash
# 1. Where does Jenkins check out the repo?
#    (Jenkins workspace — exists AFTER first pipeline run)
ls /var/lib/jenkins/workspace/

# 2. What remote does the Jenkins workspace point to?
cd /var/lib/jenkins/workspace/go-web-app
git remote -v
# Expected: origin  git@github.com:rishu4u/go-web-app.git

# 3. What branch?
git branch
# Expected: * main

# 4. Can jenkins user SSH to GitHub?
sudo -u jenkins ssh -T git@github.com
# Expected: Hi rishu4u! You've successfully authenticated, but GitHub does not provide shell access.

# 5. Jenkins git identity?
sudo -u jenkins git config --global user.name
sudo -u jenkins git config --global user.email
# Expected: Jenkins CI / jenkins-bot@go-web-app.local (or whatever was set)

# 6. DockerHub credentials file still there?
sudo cat /var/lib/jenkins/dockerhub_creds.env
# Expected: DOCKERHUB_USERNAME=saurabhhub1  +  DOCKERHUB_TOKEN=...

# 7. Jenkins can run docker?
sudo -u jenkins docker ps
# Expected: lists containers (even empty table is OK — no "permission denied")

# 8. Go installed?
/usr/local/go/bin/go version
# Expected: go version go1.22.x linux/amd64

# 9. Terraform installed? (for Phase 2)
terraform --version

# 10. AWS configured?
aws sts get-caller-identity
# Expected: shows UserId + Account + Arn
```

### What to share if something looks wrong:
Run the above commands and copy-paste the output here. We'll fix it.

---

## CREDENTIALS MASTER MAP — Where Each Credential Lives

> Single reference — so I never forget where to add/update creds.

| Credential | Where it lives | How it's used |
|---|---|---|
| **DockerHub username + token** | `/var/lib/jenkins/dockerhub_creds.env` on Jenkins VM | Pipeline Stage 4: docker login |
| **GitHub SSH key (jenkins user)** | `/var/lib/jenkins/.ssh/id_ed25519` on Jenkins VM | Jenkins pulls from / pushes to GitHub |
| **GitHub SSH public key** | GitHub → Settings → SSH Keys → "Jenkins VM" | GitHub allows Jenkins to push |
| **Jenkins SSH credential** | Jenkins UI → Manage Jenkins → Credentials → `github-ssh` | Jenkins job SCM authentication |
| **AWS Access Key + Secret** | `~/.aws/credentials` on Jenkins VM (jenkins user) | Terraform + AWS CLI |
| **Terraform values** | `devops_implementaion/terraform/terraform.tfvars` (gitignored) | Terraform apply |

> ⚠️ NEVER put real tokens/passwords in git. All of the above are either on-disk files
> that are gitignored, or in Jenkins UI credentials store — NOT in any `.tf`, `.sh`, or `.md` file.

---

*Last updated: 2026-04-19 — Phase 1 marked COMPLETE ✅, directory confusion explained, Jenkins VM verification results documented, DockerHub token gotcha added*

---

## JENKINS VM VERIFICATION RESULTS — 2026-04-19

Ran full checklist on the Jenkins Vagrant VM. Here's what we found:

| Check | Result | Status |
|---|---|---|
| Jenkins workspace | `go-web-app` folder exists | ✅ |
| GitHub SSH (jenkins user) | `Hi rishu4u!` | ✅ |
| Jenkins can run Docker | Empty table (no permission denied) | ✅ |
| Go | `go version go1.22.5 linux/amd64` | ✅ |
| Terraform | `v1.14.8` | ✅ |
| AWS auth | `terraform-devops` user, account `505609702814` | ✅ |
| DockerHub creds file | **`DOCKERHUB_USERNAME=saurabhhub1`** — MISMATCH! | ⚠️ |
| DockerHub token | Accidentally shared in chat → REGENERATED | 🔴 → ✅ |

---

## ❌ GOTCHA: DockerHub Token Leaked in Chat

**Lesson learned:** Running `sudo cat /var/lib/jenkins/dockerhub_creds.env` shows the REAL token.  
Never paste that output in chat, email, Slack, or anywhere public.

**Rule:** If a real token is ever exposed → **Delete the old token + generate a new one immediately.**

### Fix procedure (do this every time a token leaks):

```bash
# Step 1 — Go to DockerHub in browser
# hub.docker.com → Account Settings → Security → Access Tokens
# → Delete the leaked token
# → Generate New Token (name it: jenkins-vm)
# → Copy the new token (shown ONCE only!)

# Step 2 — Update token on Jenkins VM
sudo nano /var/lib/jenkins/dockerhub_creds.env
# Change DOCKERHUB_TOKEN=<old>  →  DOCKERHUB_TOKEN=<new>
# Save: Ctrl+O → Enter → Ctrl+X

# Step 3 — Verify Jenkins can still log in
sudo -u jenkins bash -c '
  source /var/lib/jenkins/dockerhub_creds.env
  echo $DOCKERHUB_TOKEN | docker login --username $DOCKERHUB_USERNAME --password-stdin
'
# Expected: Login Succeeded
```

---

## ✅ RESOLVED: DockerHub Username — `saurabhhub1`

**Confirmed:** DockerHub account = `saurabhhub1`, GitHub account = `rishu4u`. These are two different services — different usernames is perfectly fine.

| Service | Username | Used for |
|---|---|---|
| **GitHub** | `rishu4u` | Source code repo, git push/pull, SSH auth |
| **DockerHub** | `saurabhhub1` | Docker image registry — push/pull images |

**Why the Jenkinsfile is already correct:**  
The Jenkinsfile does NOT hardcode `saurabhhub1` anywhere. Instead, Stage 3 reads `DOCKERHUB_USERNAME` dynamically from `/var/lib/jenkins/dockerhub_creds.env`:
```groovy
// Stage 3 — reads from creds file
if (line.startsWith("DOCKERHUB_USERNAME=")) {
    username = line.replace("DOCKERHUB_USERNAME=", "").trim()
}
env.IMAGE_TAG = "${env.DOCKERHUB_USERNAME}/go-web-app:${env.IMAGE_VERSION}"
// Result: saurabhhub1/go-web-app:v1.5
```
So as long as the creds file has `saurabhhub1` → pipeline will tag and push correctly to DockerHub. ✅

**DockerHub repo will be:** `hub.docker.com/r/saurabhhub1/go-web-app`

---

## AWS IAM User — `terraform-devops` vs `rishu4u_aws`

Our earlier notes mentioned IAM user `rishu4u_aws` but the VM has `terraform-devops`.  
**Both are fine** — it's just a name. What matters:
- ✅ Account ID `505609702814` — matches
- ✅ `AdministratorAccess` policy — confirmed (Terraform can create resources)
- The notes will use `terraform-devops` going forward (that's the real name)
