# Git & GitHub — Complete Command Reference

> This file is updated progressively as the project evolves.
> Every command here was actually run and verified.

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
git push -u origin master
```

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
| Branch | `*/master` |
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

*Last updated: 2026-04-05 — SSH key setup, permission denied fix, Jenkins config*
