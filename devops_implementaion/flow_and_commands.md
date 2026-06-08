# DevOps — Complete Flow & Commands Reference

> **Purpose:** Command cheatsheet for this project.
> One section per tool. Each section has: mental model → daily commands → gotchas.
> Jump to the section you need using the Table of Contents below.

---

## TABLE OF CONTENTS

| Section | Tool | Phase | What's in it |
|---|---|---|---|
| [Section 0](#section-0--jenkins-server-setup-vagrant) | Vagrant / Jenkins VM | Phase 1 | `vagrant up`, provision, key paths, daily VM commands |
| [Section 1](#section-1--git) | Git | All phases | SSH setup, daily workflow, undo everything, stash, fetch vs pull, conflicts, gotchas |
| [Section 2](#section-2--docker) | Docker | Phase 1 | Build, run, push, DockerHub login, version tracking |
| [Section 3](#section-3--jenkins) | Jenkins | Phase 1 | Pipeline stages, SSH keys, credentials, Jenkinsfile explained, build triggers |
| [Section 4](#section-4--vagrant-quick-ref) | Vagrant | Phase 1 | Quick command reference |
| [Section 5](#section-5--phase-2-terraform--aws) | Terraform + AWS | Phase 2 | Install, AWS CLI setup, block types, `terraform apply` workflow |
| Section 6 *(coming)* | Ansible | Phase 3 | EC2 config, k3s install playbooks |
| Section 7 *(coming)* | Kubernetes + Helm | Phase 4 | kubectl, helm install/upgrade/rollback |
| Section 8 *(coming)* | ArgoCD | Phase 5 | GitOps sync, app setup |
| Section 9 *(coming)* | Prometheus + Grafana | Phase 6 | Monitoring stack, dashboards, alerts |
| Section 10 *(coming)* | Python Automation | Phase 7 | Pipeline scripts, health checks |

### Git quick-jump

| What you want | Subsection |
|---|---|
| SSH key setup | [1.3](#13--ssh-key-setup) |
| Daily add/commit/push | [1.4](#14--daily-git-workflow) |
| The 4 git areas (mental model) | [1.4b](#14b--the-4-git-areas) |
| Reading `git status` output | [1.4c](#14c--reading-git-status-output) |
| `git diff` / `git diff --staged` | [1.4d](#14d--seeing-what-changed) |
| Undo anything (restore, reset, revert) | [1.4e](#14e--undoing-things--every-scenario) |
| git stash / stash pop | [1.4f](#14f--stash--save-work-temporarily) |
| git fetch vs git pull | [1.4g](#14g--syncing-with-remote--pull-vs-fetch) |
| Merge conflicts — read markers, resolve, rebase --continue | [1.4h](#14h--merge-conflicts--how-to-read-and-resolve-them) |
| Scenario flows (clone, new repo, daily push) | [1.5](#15--scenario-flows) |
| Rollback visual + decision table | [1.4e](#14e--undoing-things--every-scenario) |
| Multiple git identities (personal + work) | [1.10](#110--managing-multiple-git-identities-personal--work-on-same-machine) |
| All git gotchas | [1.8](#18--git-gotchas-we-hit) |

---

# ═══════════════════════════════════════════
#  SECTION 0 — JENKINS SERVER SETUP (Vagrant)          [Phase 1 — CI/CD]
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
export DOCKERHUB_USERNAME=saurabhhub1
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
#  SECTION 1 — GIT                                      [All Phases]
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
git config --global user.email "rishusaurabh4u@gmail.com"

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

## 1.4b  THE 4 GIT AREAS — Mental Model Behind Every Command

```
Working Directory  →  Staging Area  →  Local Repo  →  GitHub (Remote)
(files on disk)       (git add)        (git commit)    (git push)

git restore <file>     ←──────────────────────────────────────────────
discard disk changes

                       git restore --staged <file>  ←─────────────────
                       unstage (move back to working dir)
```

Every git command moves things between these 4 areas:

| Command | What it does | Areas involved |
|---|---|---|
| `git add <file>` | Stage a file | working dir → staging |
| `git commit` | Commit staged snapshot | staging → local repo |
| `git push` | Upload commits | local repo → GitHub |
| `git pull` | Download + merge | GitHub → local repo |
| `git fetch` | Download only (no merge) | GitHub → local repo |
| `git restore <file>` | Discard unstaged changes | (erases working dir edits) |
| `git restore --staged <file>` | Unstage a file | staging → working dir |
| `git stash` | Shelve current work | working dir → stash shelf |
| `git stash pop` | Restore shelved work | stash shelf → working dir |

---

## 1.4c  READING `git status` OUTPUT — Line by Line

```bash
git status
```

Example output with every section explained:

```
On branch main
Your branch is up to date with 'origin/main'.    ← local matches GitHub, nothing to push
                                                   (if it says "1 commit ahead" → need to push)

Changes to be committed:                          ← STAGED — will go into next git commit
  (use "git restore --staged <file>..." to unstage)
        modified:   main.go                       ← edited + git add was run
        new file:   config.txt                    ← new file that was git add'd
        deleted:    old.txt                       ← deleted file that was git add'd

Changes not staged for commit:                    ← MODIFIED but NOT staged yet
  (use "git add <file>..." to stage)
  (use "git restore <file>..." to discard changes)
        modified:   go.mod                        ← edited but git add not run

Untracked files:                                  ← NEW files git has never seen
  (use "git add <file>..." to include)
        scratch.txt                               ← exists on disk, git ignores it
```

> ⭐ Only "Changes to be committed" goes into `git commit`. The other two sections are ignored.

---

## 1.4d  SEEING WHAT CHANGED — diff commands

```bash
# See changes NOT yet staged (working dir vs last commit)
git diff

# See changes that ARE staged (what will go into next commit)
git diff --staged

# See ALL changes (staged + unstaged) vs last commit
git diff HEAD

# See changes in one specific file
git diff main.go

# See what changed between two commits (use short SHAs from git log)
git diff e482c75 49a5ecf

# See what changed in the last commit
git show HEAD
git show HEAD --stat        # summary: filenames + lines added/removed
```

> ⭐ Rule of thumb:
> - Before `git add` → use `git diff` (shows what's NOT staged yet)
> - After `git add` → use `git diff --staged` (shows what WILL be committed)

---

## 1.4e  UNDOING THINGS — Every Scenario

### Scenario 1 — Discard changes to a file (not staged yet)
> "I edited a file but it's a mess — get back to the last committed version"
```bash
git restore main.go           # discard changes to one file
git restore .                 # discard ALL unstaged changes (⚠️ no undo)
```

### Scenario 2 — Unstage a file (you did git add, but don't want it in the commit)
> "I ran git add . but one file shouldn't go in this commit"
```bash
git restore --staged main.go  # unstage one file (changes stay on disk, just not staged)
git restore --staged .        # unstage everything
```

### Scenario 3 — Fix the last commit message
> "I committed but the message has a typo"
```bash
git commit --amend -m "correct message here"
# ⚠️ Only if NOT yet pushed — rewrites history
# If already pushed: git push --force-with-lease origin main
```

### Scenario 4 — Add a missed file to the last commit
> "I committed but forgot to include one file"
```bash
git add forgotten_file.txt
git commit --amend --no-edit    # adds file to last commit, same message
# ⚠️ Only if NOT yet pushed
```

### Scenario 5 — Undo last commit, keep changes on disk
> "I committed too early — want to re-do"
```bash
git reset --soft HEAD~1     # undo commit, keep changes staged
git reset HEAD~1            # undo commit, keep changes but unstage them
```

### Scenario 6 — Undo last commit AND delete all changes
> "I committed something wrong — erase it completely"
```bash
git reset --hard HEAD~1     # ⚠️ DESTRUCTIVE — changes are permanently gone
```

### Scenario 7 — Undo a commit already pushed to GitHub
> "I pushed something wrong — can't rewrite history"
```bash
git revert HEAD             # creates a NEW commit that undoes the last one
git push                    # push the revert commit — safe, no force needed
```

### Scenario 8 — Delete untracked files (scratch files git never tracked)
```bash
git clean -n        # dry run — shows what WOULD be deleted (safe to run)
git clean -f        # actually deletes untracked files (⚠️ no undo)
git clean -fd       # also deletes untracked directories
```

### Visual — what each reset/revert does to history

```
BEFORE:   A → B → C      (C is latest commit)

--soft    A → B           (C removed, files still staged ✅)
--mixed   A → B           (C removed, files unstaged)
--hard    A → B           (C removed, disk changes deleted ⚠️)
revert    A → B → C → D  (D undoes C, full history preserved ✅)
```

### Quick decision table

| Situation | Command |
|---|---|
| Discard file changes (not staged) | `git restore <file>` |
| Unstage a file | `git restore --staged <file>` |
| Fix last commit message | `git commit --amend -m "new msg"` |
| Undo last commit, keep staged | `git reset --soft HEAD~1` |
| Undo last commit, keep unstaged | `git reset HEAD~1` |
| Undo last commit, delete changes | `git reset --hard HEAD~1` ⚠️ |
| Undo a pushed commit | `git revert HEAD` then `git push` |

---

## 1.4f  STASH — Save Work Temporarily

> "I'm mid-edit but need to pull latest or switch tasks"

```bash
# Save current changes (both staged + unstaged) to a temporary shelf
git stash

# See what's on the stash shelf
git stash list
# Output: stash@{0}: WIP on main: e482c75 feat: sync all missing dirs

# Restore stashed work (removes it from stash shelf)
git stash pop

# Restore without removing from shelf
git stash apply

# Restore a specific stash entry
git stash apply stash@{1}

# Delete stash without applying it
git stash drop

# Save with a label (useful when you stash often)
git stash push -m "half-done terraform vars"
```

Common flow — teammate asks you to pull latest while you're mid-edit:
```bash
git stash                    # save your work
git pull origin main         # get latest from GitHub
git stash pop                # restore your work on top of latest
```

---

## 1.4g  SYNCING WITH REMOTE — pull vs fetch

```bash
# Download changes from GitHub AND merge into current branch (most common)
git pull

# Download + rebase your local commits on top (cleaner history than merge)
git pull --rebase origin main

# Download changes from GitHub but DON'T merge yet (safe — lets you inspect first)
git fetch origin

# After fetch — see WHICH commits are on GitHub that you don't have yet
git log HEAD..origin/main --oneline
# Empty output = you're already up to date
# Example output:
#   abc1234 fix: update Helm tag
#   def5678 docs: add terraform notes

# After fetch — see the actual line-by-line file changes
git diff HEAD origin/main

# See a visual picture of where local vs remote branches are
git log --oneline --graph --all
# Example output:
#   * abc1234 (origin/main) fix you made directly on GitHub
#   * ec8a5da (HEAD -> main) All folders synced   ← your local is HERE
# One line tells you: remote is 1 commit ahead, you need to pull

# After fetch — merge manually when ready
git merge origin/main

# Clone a repo for the first time
git clone git@github.com:rishu4u/go-web-app.git
git clone git@github.com:rishu4u/go-web-app.git my-folder-name
```

`pull` vs `fetch` — when to use which:

| | `git pull` | `git fetch` |
|---|---|---|
| Downloads remote changes | ✅ | ✅ |
| Merges into your branch | ✅ automatic | ❌ you choose when |
| Risk if you have local changes | ⚠️ can cause conflicts | ✅ zero risk |
| When to use | Daily sync when clean | When you want to inspect before merging |

Full safe flow when you have local edits AND remote has new commits:
```bash
git fetch origin                      # check what's on GitHub
git log HEAD..origin/main --oneline   # see the remote commits
git diff HEAD origin/main             # see the file changes
git stash                             # shelf your local edits
git pull                              # bring in remote changes cleanly
git stash pop                         # restore your local edits on top
```

---

## 1.4h  MERGE CONFLICTS — How to Read and Resolve Them

A merge conflict happens when two commits change the **same lines** of the same file
and git can't automatically decide which version to keep.

### What a conflict looks like in the file

```
<<<<<<< HEAD
export DOCKERHUB_TOKEN=<docker_token>
=======
export DOCKERHUB_TOKEN=<your-dockerhub-pat-token-here>

export AWS_ACCESS_KEY_ID=<your-aws-access-key-id>
>>>>>>> 02c3cca (Updated Material June7)
```

| Marker | Meaning |
|---|---|
| `<<<<<<< HEAD` | Start of conflict — what the REMOTE (or current branch) has |
| `=======` | Divider between the two versions |
| `>>>>>>> commit-sha` | End of conflict — what YOUR commit has |

### How to resolve

Open the file, delete the markers and keep what you want:

```bash
# Option A — keep remote version only
export DOCKERHUB_TOKEN=<docker_token>

# Option B — keep your version only
export DOCKERHUB_TOKEN=<your-dockerhub-pat-token-here>
export AWS_ACCESS_KEY_ID=<your-aws-access-key-id>

# Option C — combine both (what we did for login.txt)
export DOCKERHUB_TOKEN=<your-dockerhub-pat-token-here>
export AWS_ACCESS_KEY_ID=<your-aws-access-key-id>
```

The file must have NO `<<<<<<<`, `=======`, or `>>>>>>>` lines left when you're done.

### Full conflict resolution flow (during rebase)

```bash
# Situation: git pull --rebase hits a conflict
# Terminal shows:
#   CONFLICT (content): Merge conflict in login.txt
#   error: could not apply abc1234... Your commit message

# Step 1 — find all conflicted files
git status
# Shows: "both modified: login.txt"

# Step 2 — open each conflicted file, edit out the markers, keep correct content
nano devops_implementaion/jenkins_vagrant_server/login.txt

# Step 3 — stage the resolved file
git add devops_implementaion/jenkins_vagrant_server/login.txt

# Step 4 — continue the rebase (applies your remaining commits)
git rebase --continue
# May open editor for commit message — just save and close

# Step 5 — push
git push
```

### Escape hatches — if you want to cancel

```bash
git rebase --abort      # cancel rebase entirely — goes back to state before you ran git pull --rebase
git merge --abort       # cancel a merge (if using git pull without --rebase)
```

### The "unstaged changes block rebase" error

```
error: cannot pull with rebase: You have unstaged changes.
error: Please commit or stash them.
```

**Cause:** You have modified files not yet committed. Rebase won't run on a dirty working tree.
**Fix:** Stash first, then rebase, then pop:

```bash
git stash                        # shelf unstaged changes
git pull --rebase origin main    # rebase cleanly
git stash pop                    # restore your changes on top
# resolve any conflicts from stash pop if they appear
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

## 1.7  DIAGNOSTIC COMMANDS — Run These When Stuck

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

## 1.8  GIT GOTCHAS WE HIT

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

### ❌ Divergent branches — "Need to specify how to reconcile"
```
fatal: Need to specify how to reconcile divergent branches.
hint:   git config pull.rebase false  # merge
hint:   git config pull.rebase true   # rebase
hint:   git config pull.ff only       # fast-forward only
```
**Cause:** You committed locally AND someone (or you) pushed a different commit to GitHub
from the same base. Both branches diverged — git doesn't know which order to put them in.

```
GitHub:  A → B → C   ← commit made directly on GitHub web
Local:   A → B → D   ← commit made locally, not pushed yet
Both branched from B — git doesn't know: should result be C→D or D→C?
```

**Fix — use rebase (cleanest):**
```bash
git pull --rebase origin main
# Takes your local commit D and replays it ON TOP of GitHub's commit C
# Result: A → B → C → D  (clean linear history)
git push
```

**Permanent fix — set rebase as default so this error never appears again:**
```bash
git config --global pull.rebase true
# Now bare 'git pull' always rebases automatically
```

| Option | What it does | Use when |
|---|---|---|
| `--rebase` | Replays your commits on top of remote | ✅ Solo projects — keeps history clean |
| `--no-rebase` | Creates a merge commit | Teams — preserves exact history |
| `--ff-only` | Refuses if diverged | Strict pipelines only |

---

## 1.9  IDENTITY vs REMOTE vs SSH SUMMARY TABLE

| | Command | What it controls | Affects push access? |
|---|---|---|---|
| Identity | `git config user.email` | Label shown on commit | ❌ No |
| Remote | `git remote -v` | Where to push (URL) | ❌ No |
| Access | `ssh -T git@github.com` | Permission to push | ✅ Yes |

---

## 1.10  MANAGING MULTIPLE GIT IDENTITIES (Personal + Work on same machine)

### The 3 config levels — lower always wins

```
System   /etc/gitconfig          ← lowest priority (rarely touched)
Global   ~/.gitconfig            ← your default for ALL repos
Local    repo/.git/config        ← per-repo override — ALWAYS wins
```

**Quick check — which email will this commit use?**
```bash
git config user.email
# Shows the effective email for the current repo (local if set, global otherwise)
```

---

### Setup: Global = Work, personal repos auto-switch

**This machine setup (office machine):**
- Global = `stiwary@sparkcognition.com` → all new repos default to work identity
- Personal repos in `/home/srv/project_srv/` → auto-switch via `includeIf`

**One-time setup (run once):**
```bash
# Step 1 — Add directory rule to global config
cat >> ~/.gitconfig << 'EOF'

[includeIf "gitdir:/home/srv/project_srv/"]
    path = ~/.gitconfig-personal
EOF

# Step 2 — Create the personal identity file
cat > ~/.gitconfig-personal << 'EOF'
[user]
    name = rishu4u
    email = rishusaurabh4u@gmail.com
EOF
```

After this — any repo inside `/home/srv/project_srv/` automatically uses personal identity. No manual steps ever again.

---

### Cloning a new personal repo — what to do

**Option A — Clone into project_srv/ (auto-switches via includeIf)**
```bash
cd /home/srv/project_srv/
git clone git@github.com:rishu4u/new-personal-repo.git
cd new-personal-repo
git config user.email     # confirms: rishusaurabh4u@gmail.com ✅
```

**Option B — Clone anywhere, set identity manually**
```bash
git clone git@github.com:rishu4u/new-personal-repo.git
cd new-personal-repo
git config user.name "rishu4u"
git config user.email "rishusaurabh4u@gmail.com"
```

---

### This machine's identity map

| Location | Identity used | How |
|---|---|---|
| `/home/srv/repo/iris2/` | `stiwary@sparkcognition.com` | global (no local override) |
| `/home/srv/repo/VAIA_3/` | `stiwary@sparkcognition.com` | global |
| `/home/srv/project_srv/go-web-app/` | `rishusaurabh4u@gmail.com` | includeIf |
| `/home/srv/project_srv/<any new repo>/` | `rishusaurabh4u@gmail.com` | includeIf |

### SSH key routing (~/.ssh/config)

```
github.com    → ~/.ssh/id_ed25519_personal   (personal key)
bitbucket.org → ~/.ssh/id_rsa               (work key)
```

Test anytime:
```bash
ssh -T git@github.com       # Hi rishu4u!
ssh -T git@bitbucket.org    # authenticated via ssh key
```

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
#  SECTION 2 — DOCKER                                   [Phase 1 — CI/CD]
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

---

## 2.2b  DOCKERFILE KEYWORDS EXPLAINED

### `CGO_ENABLED=0` — what and why

CGO = C bindings in Go. By default Go can call C libraries. `CGO_ENABLED=0` disables this.

```
CGO_ENABLED=0  →  pure Go binary (no C library dependency)
CGO_ENABLED=1  →  binary links against libc on the host machine
```

**What happens if NOT set to 0:**
The binary expects `libc.so` to exist at runtime. The `distroless` image has NO libc → container crashes immediately on start.

---

### `GOOS=linux` — what and why

GOOS = Go Operating System target. Tells the Go compiler which OS to build for.

```
GOOS=linux    →  builds a Linux ELF binary (runs in containers)
GOOS=darwin   →  macOS binary
GOOS=windows  →  Windows .exe
```

**What happens if NOT set:**
If you build on macOS without `GOOS=linux`, you get a macOS binary. It will NOT run inside a Linux Docker container. Build fails silently — container exits immediately.

---

### `distroless` base image — what and why

`gcr.io/distroless/base` is a minimal Docker image with:
- The Linux kernel interface (syscalls)
- Basic C runtime
- **NO shell** (`/bin/sh` doesn't exist)
- **NO package manager** (no apt, yum)
- **NO extra tools** (no curl, ls, cat)

| | Standard (ubuntu:22.04) | Distroless |
|---|---|---|
| Image size | ~80MB | ~20MB |
| Has shell | ✅ (`/bin/bash`) | ❌ |
| Attack surface | High | Minimal |
| If compromised | Attacker has shell access | Nothing to run |

**What happens if NOT used:**
Using `ubuntu:22.04` or `golang:1.22` as the final stage adds 100-800MB and includes hundreds of exploitable tools.

**Debugging tradeoff:**
You CANNOT `docker exec -it <container> /bin/sh` into a distroless container — no shell exists.
To debug: use a debug-variant image: `gcr.io/distroless/base:debug` (adds a shell for dev use only).

---

### Multi-stage build — why it matters

```dockerfile
# Stage 1: builder (has full Go toolchain ~800MB)
FROM golang:1.22 AS builder
RUN go mod download   ← separate layer (cached — only re-runs if go.mod changes)
COPY . .              ← invalidates cache when source changes
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# Stage 2: final image (only gets what you COPY from builder)
FROM gcr.io/distroless/base
COPY --from=builder /app/main .     ← --from=builder means: copy FROM stage 1
COPY --from=builder /app/static ./static
# All 800MB of Go tooling is DISCARDED — never goes into final image
```

**`COPY --from=builder`** — `--from=builder` means "copy from the stage named `builder`", not from your local disk.

**Why `go mod download` is a separate RUN (Docker layer caching):**
```
go.mod rarely changes → docker caches that layer
source code changes every build → cache busted from COPY . . onward
Without the split: every build re-downloads all dependencies (slow)
With the split: only re-downloads if go.mod actually changed (fast)
```

**If single-stage (no multi-stage):**
```
Final image = golang:1.22 base + your code = ~850MB
vs
Final image = distroless + binary = ~20MB
```
40x size difference. Larger = slower to pull, more CVEs, bigger attack surface.

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

## 2.9  RUNNING THE GO APP MANUALLY

### On your HOST laptop (simplest)

Go is NOT installed on the host — but Docker is (v29.5.2).
Run the built image directly:

```bash
docker run --rm -p 8080:8080 saurabhhub1/go-web-app:v1.1

# Access at:
curl http://localhost:8080/home
# or open browser: http://localhost:8080/home
```

No port conflict — Jenkins runs inside the Vagrant VM, not on the host. Port 8080 on your laptop is free.

---

### On the Jenkins VM

The app listens on **port 8080** — same port Jenkins uses. Two options:

### Option A — Docker (recommended, no Jenkins conflict)

```bash
# On Jenkins VM
# Map container port 8080 → host port 9091 (avoids clashing with Jenkins on 8080)
docker run --rm -p 9091:8080 saurabhhub1/go-web-app:v1.1

# Access from your laptop:
curl http://192.168.56.12:9091/home
# or open in browser: http://192.168.56.12:9091/home
```

> ⭐ This is the best way — Jenkins keeps running, no interference.

### Option B — `go run` directly (stop Jenkins first)

```bash
# On Jenkins VM — free up port 8080 by stopping Jenkins
sudo systemctl stop jenkins

# Run from synced folder (Go source is here)
cd /home/vagrant/go-web-app
export PATH=$PATH:/usr/local/go/bin
go run main.go
# Output: server started on :8080

# Access from laptop (port 8080 on VM = port 9090 on host via Vagrantfile forward):
curl http://localhost:9090/home
# or: curl http://192.168.56.12:8080/home

# When done — restart Jenkins
sudo systemctl start jenkins
```

### App endpoints

| Endpoint | What it returns |
|---|---|
| `/home` | Home page |
| `/courses` | Courses listing |
| `/about` | About page |
| `/contact` | Contact page |

---

---

# ═══════════════════════════════════════════
#  SECTION 3 — JENKINS                                  [Phase 1 — CI/CD]
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

## 3.2b  IDENTITY vs AUTHENTICATION — Two Separate Concepts

### git identity ≠ push permission

```
git config user.email  →  LABEL on the commit (author metadata only)
SSH key                →  CONTROLS whether git push is allowed
```

These are completely independent. You could set:
```bash
git config user.email "president@whitehouse.gov"
```
But if your SSH key is not registered on GitHub → push is still rejected.
The identity label has zero effect on access.

---

### Why Stage 7 sets `jenkins-bot@go-web-app.local`

Pure labeling convention. In `git log`, this makes automated commits clearly
distinguishable from human commits:

```
e482c75 Jenkins CI  ci: update Helm image tag to v1.2 [skip ci]  ← automated
49a5ecf rishu4u     docs: update flow_and_commands                ← human
```

It does NOT affect whether the push succeeds — the SSH key does that.

---

### Why the workspace shows `rishu4u` before Stage 7 runs

The workspace `.git/config` (local git config) has no user identity until
Stage 7 explicitly sets it. Before that, git falls back up the config hierarchy:

```
Local  (workspace/.git/config)   → not set yet
Global (~/.gitconfig on VM)      → jenkins user's global = rishu4u ← shows this
System (/etc/gitconfig)          → fallback
```

Stage 7 sets the LOCAL config (`git config user.email` without `--global`)
which overrides the global — but only for this workspace, and only after Stage 7 runs.

---

### Why the private key is in TWO places

Both use the **same** private key file — but two different consumers need it:

| Consumer | Where they get the key | Used when |
|---|---|---|
| `jenkins` OS user | `/var/lib/jenkins/.ssh/id_ed25519` (file on disk) | Manual: `sudo -u jenkins ssh -T git@github.com` |
| Jenkins application (pipeline jobs) | Jenkins GUI → Credentials → `github-ssh` | Pipeline: `git clone` (Checkout) + `git push` (Stage 7) |

Jenkins the **application** cannot read arbitrary files from disk for security reasons.
It reads credentials only from its own Credentials store.
So the private key is pasted into the GUI even though the same file already exists on disk.

The public key goes to GitHub **once** — GitHub verifies the private key matches
regardless of which of the two above is making the connection.

```
Flow when pipeline runs git push:
  Stage 7 → Jenkins reads private key from GUI Credentials (github-ssh)
          → Opens SSH connection to github.com
          → GitHub verifies: does this key match any registered public key?
          → Yes (we added it in KEY 1) → push allowed ✅
          → Commit is labeled "Jenkins CI <jenkins-bot@go-web-app.local>"
```

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

## 3.5b  JENKINS BUILD TRIGGERS — HOW PIPELINE STARTS

There are 3 ways Jenkins can start a build. Set in: **Job → Configure → Build Triggers**

### Trigger 1 — Manual (Build Now)
You click "Build Now" in the Jenkins UI. What we use for testing.

### Trigger 2 — Poll SCM
Jenkins checks GitHub on a schedule. If new commits are found → trigger build.

```
Jenkins Job → Configure → Build Triggers → Poll SCM
Schedule: H/5 * * * *    ← check every 5 minutes

Cron format: MIN HOUR DAY MONTH WEEKDAY
H/5 * * * * = every 5 minutes (H = hash, spreads load across Jenkins jobs)
```

How it works:
```
Every 5 min: Jenkins asks GitHub "any new commits since I last checked?"
    → No  → do nothing
    → Yes → trigger build immediately
```

### Trigger 3 — GitHub Hook Trigger for GITScm Polling
Jenkins listens for a webhook signal FROM GitHub. When GitHub pushes a notification → build triggers instantly.

```
GitHub push happens
    → GitHub sends POST to: http://<jenkins-ip>:8080/github-webhook/
    → Jenkins receives it → triggers build immediately
```

### Why webhook doesn't work on local Vagrant VM

```
Jenkins URL: http://192.168.56.12:8080   ← private IP, only exists on your laptop
GitHub:      cannot reach 192.168.56.x   ← internet cannot reach private IPs
Result:      webhook signal never arrives, trigger never fires
```

**Current setup:** "GitHub hook trigger" is ENABLED but does nothing (private IP).
Poll SCM every 5 min is what actually triggers builds.

**When you move to Phase 2 (Jenkins on EC2 with public IP):**
- Configure GitHub webhook: repo Settings → Webhooks → Add webhook → `http://<ec2-ip>:8080/github-webhook/`
- Turn off Poll SCM (wastes resources — webhook is instant)
- Build triggers on every push, within seconds

| Trigger | Works locally (Vagrant)? | Works on EC2 (AWS)? |
|---|---|---|
| Manual (Build Now) | ✅ | ✅ |
| Poll SCM | ✅ (checks every 5 min) | ✅ (but wasteful) |
| GitHub Webhook | ❌ (private IP) | ✅ (public IP) |

---

## 3.5c  JENKINSFILE BUILT-IN STEPS — `fileExists()`, `readFile()`, `writeFile()`

These are Jenkins pipeline steps (NOT bash commands). They run in Groovy inside `script{}` blocks.

```groovy
// fileExists() — returns true/false, never throws
if (fileExists("/var/lib/jenkins/.docker_version")) {
    // file exists — safe to read
}

// readFile() — returns file contents as a String
// ⚠️ ALWAYS call .trim() — readFile adds a trailing newline
def version = readFile("/var/lib/jenkins/.docker_version").trim()

// Why check fileExists first:
// readFile() THROWS an exception if the file doesn't exist — pipeline fails
// Pattern: always guard readFile() with fileExists()
def version = fileExists(env.VERSION_FILE)
    ? readFile(env.VERSION_FILE).trim()
    : "v1.0"   // default if file missing

// writeFile() — write a string to a file
writeFile(file: "/var/lib/jenkins/.docker_version", text: "v1.5")
```

---

## 3.5d  JENKINSFILE `when{}` — CONDITIONAL STAGE EXECUTION

`when{}` lets a stage run only under certain conditions. Common patterns:

```groovy
stage('Deploy to Production') {
    when {
        branch 'main'          // only run on main branch
    }
    steps { ... }
}

stage('Integration Test') {
    when {
        not { branch 'main' }  // run on all branches EXCEPT main
    }
    steps { ... }
}

stage('Notify') {
    when {
        expression { env.IMAGE_VERSION == "v2.0" }   // custom condition
    }
    steps { ... }
}
```

**What happens if not used:** Stage always runs regardless of branch or condition. In our pipeline we don't use `when{}` yet — every stage always runs. Phase 5 (multi-environment deploys) is where `when{}` becomes important.

---

## 3.6  OUR JENKINSFILE — PIPELINE STAGES EXPLAINED

### What is `sh`?

`sh` is a Jenkins pipeline step that runs a shell command on the agent machine (our Jenkins VM).
It is NOT a Linux command — it is a Jenkins keyword that tells Jenkins: "run this in bash."

```groovy
sh "go test ./..."           // runs: bash -c "go test ./..."
sh "docker build ..."        // runs: bash -c "docker build ..."

// Multi-line version (triple-quote) — same thing, just cleaner for long commands
sh """
  export PATH=\$PATH:/usr/local/go/bin
  cd /var/lib/jenkins/workspace/go-web-app
  go test ./...
"""
```

> Note: inside `sh """..."""`, the `$` for environment variables must be escaped as `\$`
> to stop Jenkins from expanding them before bash sees them. Use `${VARIABLE}` (no backslash)
> for Jenkins env vars you DO want expanded.

---

### What is `script`?

`script` is a Jenkins step that lets you write Groovy code (logic, variables, conditionals)
inside a declarative pipeline. Without it, you can only call steps — no `if`, no variables.

```groovy
// Without script — only simple steps allowed
steps {
  sh "go test ./..."
  echo "done"
}

// With script — full Groovy logic
steps {
  script {
    def version = readFile("/var/lib/jenkins/.docker_version").trim()
    if (version == "") {
      version = "v1.0"
    }
    env.IMAGE_VERSION = version
  }
}
```

---

### What is `agent any` — and what are the alternatives?

`agent` tells Jenkins WHERE to run the pipeline (which machine / container).

| Value | Meaning | When to use |
|---|---|---|
| `agent any` | Run on any available Jenkins node | ✅ Our setup — single Jenkins VM |
| `agent none` | No global agent — each stage defines its own | When different stages need different environments |
| `agent { label 'linux' }` | Run only on nodes tagged 'linux' | Multi-node Jenkins cluster |
| `agent { docker 'golang:1.22' }` | Run inside a Docker container | Clean isolated builds without installing Go on Jenkins |
| `agent { kubernetes { ... } }` | Run inside a K8s pod | Large-scale Jenkins on Kubernetes |

In our project `agent any` works because we have one Jenkins VM and it has everything installed (Go, Docker, Git).

If we used `agent { docker 'golang:1.22' }` instead — Jenkins would spin up a fresh Go container for each build, run the tests inside it, then destroy it. No need to install Go on the VM.

---

### What is the `:` in `export PATH=\$PATH:${GO_BIN}`?

The colon is the **separator** in the Linux PATH variable. PATH is a colon-separated list of
directories where Linux looks for commands.

```bash
echo $PATH
# /usr/bin:/usr/sbin:/usr/local/bin   ← colon separates each directory

# When you type 'go', Linux checks each directory in order:
#   /usr/bin/go        → not found
#   /usr/sbin/go       → not found
#   /usr/local/bin/go  → not found
#   → "command not found" ❌

export PATH=$PATH:/usr/local/go/bin
# PATH is now: /usr/bin:/usr/sbin:/usr/local/bin:/usr/local/go/bin

# Type 'go' again → Linux checks /usr/local/go/bin/go → FOUND ✅
```

The `:` just means "and also look in this directory." Nothing Groovy — pure bash.

---

### What is the `? :` ternary operator?

A one-line if/else. Every language has it (Groovy, Java, JavaScript).

```groovy
// Normal if/else (long form)
def lastVersion
if (fileExists(env.VERSION_FILE)) {
    lastVersion = readFile(env.VERSION_FILE).trim()
} else {
    lastVersion = "v1.0"
}

// Ternary (short form) — exact same thing
def lastVersion = fileExists(env.VERSION_FILE)
    ? readFile(env.VERSION_FILE).trim()   // condition TRUE  → use this
    : "v1.0"                              // condition FALSE → use this
```

Pattern: `condition ? value_if_true : value_if_false`
Read it as: "if fileExists → read the file, else → use v1.0"

---

### What is the `.` in `"v${parts[0]}.${parts[1]}"`?

That dot is just a **literal dot character** — the dot you see between major and minor in version numbers.

```groovy
parts = ["1", "4"]    // after splitting "1.4" on "."

"v${parts[0]}.${parts[1]}"
//      ↑        ↑   ↑
//    major   dot  minor
// Result: "v1.4"

// The full line in our Jenkinsfile:
def suggestion = "v${parts[0]}.${(parts[1].toInteger() + 1)}"
//                          ↑
//                  literal dot (just the dot in "v1.5")
// parts[1] = "4" → .toInteger() converts "4" → 4 → +1 → 5
// Result: "v1.5"
```

`.toInteger()` is a Groovy method (converts a string to a number).
The `.` between `parts[0]}` and `${...}` is just the dot in `v1.5` — not a Groovy operator.

---

### Full annotated Jenkinsfile

```groovy
pipeline {
  // ─────────────────────────────────────────────────────
  // agent — WHERE the pipeline runs
  // 'any' = use this Jenkins VM (the only one we have)
  // ─────────────────────────────────────────────────────
  agent any

  // ─────────────────────────────────────────────────────
  // environment — define variables usable in ALL stages
  // ${WORKSPACE} is a Jenkins built-in = the git checkout folder
  //   → /var/lib/jenkins/workspace/go-web-app
  // ─────────────────────────────────────────────────────
  environment {
    APP_DIR      = "${WORKSPACE}"
    DEVOPS_DIR   = "${WORKSPACE}/devops_implementaion"
    VERSION_FILE = "/var/lib/jenkins/.docker_version"    // OUTSIDE workspace so git checkout doesn't wipe it
    HELM_VALUES  = "${WORKSPACE}/devops_implementaion/helm/go-web-app-chart/values.yaml"
    CREDS_FILE   = "/var/lib/jenkins/dockerhub_creds.env"
    GO_BIN       = "/usr/local/go/bin"
  }

  stages {

    // ─────────────────────────────────────────────────────
    // Stage 1: Checkout
    // Jenkins automatically clones the repo into WORKSPACE.
    // This stage just confirms the checkout happened.
    // ─────────────────────────────────────────────────────
    stage('Checkout') {
      steps {
        sh "echo 'Workspace: ${WORKSPACE}'"  // sh = run this in bash on the Jenkins VM
        sh "ls ${DEVOPS_DIR} || true"        // || true = don't fail if folder is empty
      }
    }

    // ─────────────────────────────────────────────────────
    // Stage 2: Test
    // sh runs go test in bash
    // export PATH adds Go binary location so 'go' command is found
    // ─────────────────────────────────────────────────────
    stage('Test') {
      steps {
        sh """
          export PATH=\$PATH:${GO_BIN}   // \$ = literal dollar (bash variable, not Jenkins)
          cd ${APP_DIR}                  // ${APP_DIR} = Jenkins variable, expanded before bash runs
          go test ./...                  // ./... = test all packages recursively
        """
      }
    }

    // ─────────────────────────────────────────────────────
    // Stage 3: Version Tag
    // script{} block is needed here because we have Groovy logic
    // (reading files, string manipulation, conditional, input prompt)
    // ─────────────────────────────────────────────────────
    stage('Version Tag') {
      steps {
        script {
          // readFile() = Jenkins step to read a file into a string
          def lastVersion = fileExists(env.VERSION_FILE)
            ? readFile(env.VERSION_FILE).trim()
            : "v1.0"

          // String manipulation in Groovy to increment minor version
          def parts = lastVersion.replaceAll('^v','').tokenize('.')
          def suggestion = "v${parts[0]}.${(parts[1].toInteger() + 1)}"

          // input() = PAUSES the pipeline and shows a dialog in Jenkins UI
          // User types a version or accepts the suggestion → clicks Proceed
          def userInput = input(
            message: "Last: ${lastVersion}  |  Suggested: ${suggestion}",
            parameters: [string(name: 'VERSION', defaultValue: suggestion)]
          )

          // env.X = set a Jenkins env variable for use in later stages
          env.IMAGE_VERSION = userInput ?: suggestion
          env.IMAGE_TAG     = "${env.DOCKERHUB_USERNAME}/go-web-app:${env.IMAGE_VERSION}"
        }
      }
    }

    // ─────────────────────────────────────────────────────
    // Stage 4: Docker Build
    // sh runs docker build in bash
    // -f = path to Dockerfile (not in repo root, in subfolder)
    // -t = tag the image as saurabhhub1/go-web-app:v1.1
    // last argument = build context (folder Docker reads files from)
    // ─────────────────────────────────────────────────────
    stage('Docker Build') {
      steps {
        sh """
          docker build \
            -f ${DEVOPS_DIR}/Dockerfile \
            -t ${env.IMAGE_TAG} \
            ${APP_DIR}
        """
      }
    }

    // ─────────────────────────────────────────────────────
    // Stage 5: Approval Gate
    // input() pauses and shows Proceed / Abort buttons in Jenkins UI
    // If user clicks Abort → pipeline stops, image is NOT pushed
    // ─────────────────────────────────────────────────────
    stage('Push to DockerHub?') {
      steps {
        script {
          input(
            message: "Push ${env.IMAGE_TAG} to DockerHub?",
            ok: 'Yes, Push It!'
          )
        }
      }
    }

    // ─────────────────────────────────────────────────────
    // Stage 6: Docker Push
    // Reads credentials from a file outside git (never committed)
    // export $(...) = load all KEY=VALUE lines from file as env vars
    // echo "$TOKEN" | docker login --password-stdin = non-interactive login
    //   (avoids password appearing in logs)
    // ─────────────────────────────────────────────────────
    stage('Docker Push') {
      steps {
        sh """
          export \$(grep -v '^#' ${CREDS_FILE} | xargs)   // load DOCKERHUB_USERNAME + DOCKERHUB_TOKEN
          echo "\$DOCKERHUB_TOKEN" | docker login \
            --username "\$DOCKERHUB_USERNAME" \
            --password-stdin                               // reads password from stdin, not from CLI arg
          docker push ${env.IMAGE_TAG}
        """
        sh "echo '${env.IMAGE_VERSION}' > ${env.VERSION_FILE}"  // save version for next build
      }
    }

    // ─────────────────────────────────────────────────────
    // Stage 7: Update Helm Tag
    // sed -i = edit file in-place (no temp file)
    // 's/tag: .*/tag: "v1.1"/' = replace the tag line with new version
    // Then git add/commit/push so GitHub has the updated values.yaml
    // [skip ci] in commit message = tells GitHub Actions NOT to trigger a new pipeline run
    // ─────────────────────────────────────────────────────
    stage('Update Helm Tag') {
      steps {
        sh """
          sed -i 's/tag: .*/tag: \"${env.IMAGE_VERSION}\"/' ${HELM_VALUES}
          cd ${APP_DIR}
          git config user.email "jenkins-bot@go-web-app.local"
          git config user.name  "Jenkins CI"
          git fetch origin
          git checkout main
          git pull --rebase origin main
          git add ${HELM_VALUES}
          git diff --cached --quiet || \
            git commit -m "ci: update Helm image tag to ${env.IMAGE_VERSION} [skip ci]"
          git push origin main
        """
      }
    }

  }  // end stages

  // ─────────────────────────────────────────────────────
  // post — runs AFTER all stages complete
  // success / failure / aborted = conditional blocks
  // ─────────────────────────────────────────────────────
  post {
    success  { echo "Pipeline succeeded: ${env.IMAGE_TAG}" }
    failure  { echo "Pipeline FAILED — check stage logs above" }
    aborted  { echo "Pipeline aborted — push was declined" }
  }

}
```

---

## 3.6b  `post{}` BLOCK — RUNS AFTER ALL STAGES

`post{}` runs AFTER all stages finish, regardless of outcome. It's how you send notifications, clean up, or report status.

```groovy
post {
    success  { echo "Pipeline passed" }     // all stages passed
    failure  { echo "Pipeline failed" }     // any stage failed
    aborted  { echo "User cancelled" }      // user clicked Abort
    always   { echo "Always runs" }         // runs no matter what
    unstable { echo "Tests had warnings" }  // tests ran but had failures
    changed  { echo "Status changed" }      // different result from last build
}
```

**What happens if NOT used:** Pipeline finishes silently — no final status report, no Slack alert, no cleanup. In production, `post { failure { slackSend(...) } }` is how on-call gets paged.

**Our pipeline's post block:**
```groovy
post {
    success { echo "Pushed: ${env.IMAGE_TAG}" }  // confirm which image was pushed
    failure { echo "FAILED — check stage logs" }
    aborted { echo "Push declined or build cancelled" }
}
```

---

## 3.6c  `environment{}` BLOCK — PIPELINE VARIABLES

The `environment{}` block defines variables available to ALL stages. Set once, use everywhere.

```groovy
pipeline {
    environment {
        APP_DIR    = "${WORKSPACE}"               // Jenkins built-in — git checkout path
        CREDS_FILE = "/var/lib/jenkins/creds.env" // outside WORKSPACE — persists across builds
    }
    stages {
        stage('Test') {
            steps {
                sh "cd ${APP_DIR} && go test ./..."   // uses environment variable
            }
        }
    }
}
```

**`${WORKSPACE}` vs hardcoded path:**
```
${WORKSPACE}  = /var/lib/jenkins/workspace/go-web-app/  ← always correct
/home/vagrant/devops/  ← hardcoded path → fails (jenkins user has no access)
```

**Setting variables dynamically inside stages:**
```groovy
stage('Version Tag') {
    steps {
        script {
            env.IMAGE_VERSION = "v1.5"       // env.X = set for remaining stages
            env.IMAGE_TAG = "saurabhhub1/go-web-app:v1.5"
        }
    }
}
stage('Docker Build') {
    steps {
        sh "docker build -t ${env.IMAGE_TAG} ."   // uses value set in previous stage
    }
}
```

**Why VERSION_FILE is OUTSIDE workspace:**
```
${WORKSPACE}/file  →  git checkout WIPES this every build (git clean)
/var/lib/jenkins/.docker_version  →  OUTSIDE workspace, survives every build ✅
```

---

## 3.6d  `sh` STEP — FAILURE HANDLING AND ESCAPING

**`sh` fails the pipeline if the command exits non-zero:**
```groovy
sh "go test ./..."        // if tests fail → exit code 1 → pipeline STOPS here
sh "ls nonexistent-dir"   // exit code 1 → pipeline fails

// To run a command but NOT fail the pipeline:
sh "command || true"      // || true forces exit code 0 even if command fails
sh "ls ${DEVOPS_DIR} || true"   // used in Stage 1 — won't fail if dir is empty
```

**Variable escaping inside `sh "..."`:**
```groovy
// Jenkins variable (expand BEFORE bash runs it):
sh "cd ${APP_DIR}"                 // ${APP_DIR} is replaced by Jenkins → bash sees actual path

// Bash variable (must escape $ so bash expands it, not Jenkins):
sh "echo \$HOME"                   // \$ → bash gets: echo $HOME → prints /home/jenkins
sh "export PATH=\$PATH:/usr/local/go/bin"   // same pattern

// Inside triple-quoted block (sh """...""") — same rules apply:
sh """
    export PATH=\$PATH:${GO_BIN}   // \$PATH = bash var,  ${GO_BIN} = Jenkins var
    go test ./...
"""
```

---

## 3.7  THE CORE MENTAL MODEL — Who Does What

This is the most important thing to understand about the entire pipeline.

```
┌─────────────────────────────────────────────────────────────────────┐
│  YOU (on HOST laptop)                                               │
│    Edit code → git push → GitHub                                    │
│                                                                     │
│  Rule: ALL code changes come from the host.                         │
│        Never edit files directly on the Jenkins VM.                 │
└──────────────────────────────┬──────────────────────────────────────┘
                               │  Jenkins polls GitHub every 5 min
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  JENKINS VM (automated)                                             │
│    1. Clones fresh copy from GitHub into /var/lib/jenkins/workspace/│
│    2. Runs go test ./...                                            │
│    3. Builds Docker image                                           │
│    4. Pushes image → DockerHub                                      │
│    5. Updates helm/values.yaml with new image tag                   │
│    6. Pushes THAT ONE FILE back to GitHub  ← only push Jenkins makes│
│                                                                     │
│  Rule: Jenkins makes exactly ONE git push per pipeline run.         │
│        Only the Helm values.yaml tag line. Nothing else.            │
└──────────────────────────────┬──────────────────────────────────────┘
                               │  [skip ci] in commit message
                               │  prevents Jenkins triggering itself again
                               ▼
                          GitHub updated
                          values.yaml: tag: "v1.5"
                          (ArgoCD will detect this in Phase 5)
```

### Why `[skip ci]` matters

Stage 7 pushes a commit to GitHub. Without `[skip ci]`, Jenkins would detect that new commit and trigger another build — which would push another commit — infinite loop.

The `[skip ci]` tag in the commit message tells GitHub Actions / poll SCM to ignore that commit:
```groovy
git commit -m "ci: update Helm image tag to ${env.IMAGE_VERSION} [skip ci]"
```

### The Jenkins VM should always be "clean"

Jenkins clones a **fresh copy** from GitHub every build. It never reads from the synced Vagrant folder.

This means:
- If you edit a file on the Jenkins VM → it gets **overwritten** on next build (lost)
- If you need to change the Jenkinsfile → edit on HOST → git push → Jenkins uses it next run
- If the Jenkins workspace looks wrong → delete it, Jenkins will re-clone on next build

```bash
# If workspace is in a bad state — delete it, Jenkins recreates automatically
sudo rm -rf /var/lib/jenkins/workspace/go-web-app/
# Click Build Now — Jenkins will re-clone
```

---

## 3.8  KEY CONCEPT — Jenkins WORKSPACE vs Synced Folder

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

### ❌ Stage 7 fails — "cannot pull with rebase: You have unstaged changes"

```
error: cannot pull with rebase: You have unstaged changes.
error: please commit or stash them.
```

**Cause:** `sed` modifies `values.yaml` BEFORE `git pull --rebase` runs. Rebase requires a clean working tree.

**Fix:** Always `git pull --rebase` FIRST (while tree is clean), THEN run `sed`.

```groovy
// WRONG — sed before pull
sh """
  sed -i 's/tag: .*/tag: "v1.2"/' values.yaml   // ← dirty tree
  git pull --rebase origin main                   // ← FAILS
"""

// CORRECT — pull before sed
sh """
  git pull --rebase origin main   // ← clean tree ✅
  sed -i 's/tag: .*/tag: "v1.2"/' values.yaml
  git add values.yaml && git commit -m "..." && git push
"""
```

---

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
#  SECTION 4 — VAGRANT (Quick ref)                      [Phase 1 — CI/CD]
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

---

---

# ═══════════════════════════════════════════
#  SECTION 5 — PHASE 2: TERRAFORM + AWS
# ═══════════════════════════════════════════

## 5.1  WHERE TERRAFORM RUNS

Terraform is installed on the **Jenkins Vagrant VM** (not host laptop).
This means eventually Jenkins can trigger Terraform as part of the pipeline.

```
Jenkins Vagrant VM (192.168.56.12)
├── Jenkins         ✅ CI — build, test, push Docker image
├── AWS CLI         ✅ authenticate to AWS
├── Terraform       ✅ provision EC2, VPC, Security Groups
└── kubectl         🔲 manage K8s cluster (Phase 4)
```

---

## 5.2  AWS IAM SETUP (one-time, in browser)

```
1. AWS Console → IAM → Users → Create User
   Name: terraform-devops

2. Permissions → Attach policy: AdministratorAccess
   (scope down to least privilege once project is stable)

3. After creation → Security Credentials tab
   → Create Access Key → CLI use case
   → Copy Access Key ID + Secret Access Key (treat like passwords!)

⚠️ NEVER paste credentials into chat, Git commits, or Slack.
   Store them only in: ~/.aws/credentials  (on the machine that needs them)
```

---

## 5.3  INSTALL AWS CLI (on Jenkins Vagrant VM)

```bash
# Download and install
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install 

# Verify
aws --version
# Expected: aws-cli/2.x.x Python/3.x.x Linux/...
```

---

## 5.4  INSTALL TERRAFORM (on Jenkins Vagrant VM)

```bash
# Add HashiCorp GPG key and repo
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install -y terraform

# Verify
terraform --version
# Expected: Terraform v1.14.8
```

---

## 5.5  CONFIGURE AWS CLI

```bash
aws configure
# AWS Access Key ID:     <your-key-id>
# AWS Secret Access Key: <your-secret-key>
# Default region name:   us-east-1
# Default output format: json

# Credentials are saved to:
# ~/.aws/credentials   ← actual keys
# ~/.aws/config        ← region + output format

# Verify — shows your IAM user identity
aws sts get-caller-identity
# Expected output:
# {
#     "UserId": "AIDAXXXXXX",
#     "Account": "505609702814",
#     "Arn": "arn:aws:iam::505609702814:user/terraform-devops"
# }
```

> ⚠️ `~/.aws/credentials` contains real keys. Never commit this file to Git.
> It is user-specific and should stay on the machine only.

---

## 5.6  TERRAFORM COMMANDS — CORE WORKFLOW

```bash
terraform init        # download providers (AWS plugin) — run once per new directory
terraform plan        # preview: what will be CREATED / CHANGED / DESTROYED (no cost)
terraform apply       # actually create the infrastructure (prompts "yes" to confirm)
terraform output      # show output values after apply (EC2 IPs, etc.)
terraform destroy     # tear down ALL resources Terraform created
terraform show        # show full current state in human-readable form
terraform state list  # list all resource names Terraform is tracking
```

---

## 5.6b  TERRAFORM STATE FILE — What It Is and Why It Matters

When you run `terraform apply`, Terraform creates a file called `terraform.tfstate`
in the same directory. This is the **state file** — Terraform's memory.

```
devops_implementaion/terraform/
└── terraform.tfstate     ← created after first apply (NOT in git — gitignored)
```

**What it stores:** The real AWS resource IDs that Terraform created.
```json
{
  "resources": [
    {
      "type": "aws_instance",
      "name": "k8s_master",
      "instances": [{ "attributes": { "id": "i-0abc123", "public_ip": "3.91.x.x" } }]
    }
  ]
}
```

**Why it matters:**
- `terraform plan` compares your `.tf` files against the state file to know what changed
- `terraform destroy` reads the state file to know WHICH resources to delete
- If you lose the state file → Terraform doesn't know what it created → can't manage or destroy

**Never:**
- Commit `terraform.tfstate` to Git (contains real resource IDs and may have secrets)
- Delete it manually unless you know exactly what you're doing

**Team scenario (not ours yet):** Multiple people sharing Terraform → use S3 remote backend to store the state file centrally instead of locally.

---

## 5.6c  TERRAFORM DESTROY — WHEN AND HOW

`terraform destroy` tears down everything Terraform created — EC2, VPC, SG, key pairs.
It reads the state file to know exactly what to delete.

```bash
# Always run output BEFORE destroy — save the IPs you'll need for Phase 3
terraform output

# Then destroy
terraform destroy
# Terraform shows a plan of what will be deleted → type 'yes' to confirm
```

**When to destroy:**

| Situation | Action |
|---|---|
| Done for the day, not continuing Phase 3 yet | ✅ Destroy — avoid AWS charges |
| About to start Phase 3 right now | ❌ Keep running — you need the IPs |
| Something went wrong with apply | ✅ Destroy and re-apply cleanly |

**Free tier math — why destroy matters:**

```
AWS Free Tier: 750 hours/month for t2.micro
Our setup: 2 x t2.micro running simultaneously = 2 × 24h = 48h/day consumed
750 ÷ 48 = ~15 days before free tier exhausted → charges start
```

So leaving 2 instances running idle will exceed free tier in about 2 weeks.

**After destroy — what happens:**
- EC2 instances terminated ✅
- VPC, subnets, SGs deleted ✅
- State file updated (resources removed) ✅
- `.tf` files untouched — ready to `terraform apply` again anytime

**Re-applying gives NEW IPs.** Save the old IPs from `terraform output` before destroying
if you need them for reference. Phase 3 will use the new IPs from the next apply.

---

## 5.7  TERRAFORM FILE STRUCTURE (our project)

```
devops_implementaion/terraform/
├── main.tf              ← terraform{} block + provider{} block + EC2 resources
├── vpc.tf               ← VPC, subnets, internet gateway, route table resources
├── security_groups.tf   ← firewall rule resources
├── variables.tf         ← variable{} declarations (names + types, no values)
├── outputs.tf           ← output{} declarations (what to print after apply)
└── terraform.tfvars     ← actual variable values (gitignored — has secrets)
```

> ⭐ Terraform reads ALL .tf files in the directory — filename doesn't matter.
> Split into multiple files for readability only. One big file works identically.
> Exception: `terraform.tfvars` is special — auto-loaded for variable values.

---

## 5.7b  TERRAFORM BLOCK TYPES — THE FULL STRUCTURE

Every `.tf` file is made up of these 5 block types. That's it — the whole language.

```hcl
# ── 1. terraform {} ────────────────────────────────────────────────
# Settings block. Tells Terraform which plugin to download.
# Written ONCE per project (top of main.tf).
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"   # download from registry.terraform.io
      version = "~> 5.0"          # any version >= 5.0 and < 6.0
    }
  }
  required_version = ">= 1.0"    # minimum Terraform version required
}

# ── 2. provider {} ─────────────────────────────────────────────────
# Configures the cloud connection: which region, how to authenticate.
# Written ONCE per provider.
provider "aws" {
  region = var.aws_region   # credentials come from ~/.aws/credentials
}

# ── 3. variable {} ─────────────────────────────────────────────────
# Declares an input. Like a function parameter.
# Only the DECLARATION goes here — values come from terraform.tfvars.
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"   # used if no value provided in tfvars
}

# ── 4. resource {} ─────────────────────────────────────────────────
# Creates infrastructure. One block = one thing on AWS.
# Syntax: resource "<provider_type>" "<your_local_name>" { }
resource "aws_instance" "k8s_master" {
  ami           = var.ami_id         # var.x = read from variables
  instance_type = var.instance_type
}

# ── 5. output {} ───────────────────────────────────────────────────
# Prints a value after terraform apply.
# Reference resources as: <type>.<local_name>.<attribute>
output "master_public_ip" {
  value = aws_instance.k8s_master.public_ip
}
```

### How the blocks connect — reading order

```
terraform.tfvars          variables.tf              main.tf / vpc.tf
─────────────────         ─────────────────         ─────────────────────────
aws_region = "us-east-1"  variable "aws_region" {}  provider "aws" {
instance_type = "t2.micro" variable "instance_type"   region = var.aws_region
                                                    }
      ↓ values flow into ↓                          resource "aws_instance" "k8s_master" {
                                                      instance_type = var.instance_type
                                                    }
                                                          ↓ after apply ↓
                                                    outputs.tf
                                                    output "master_ip" {
                                                      value = aws_instance.k8s_master.public_ip
                                                    }
```

### Processing order (what Terraform does internally)

```
1. terraform {}   → download AWS plugin (terraform init)
2. provider {}    → connect to AWS us-east-1 with ~/.aws/credentials
3. variable {}    → load values from terraform.tfvars
4. resource {}    → plan what to create (using var.x)
5. output {}      → after apply, print these values
```

---

## 5.7c  TERRAFORM RESOURCE REFERENCE SYNTAX

Resources in different `.tf` files talk to each other using references — no imports needed.

**Syntax:** `<resource_type>.<local_name>.<attribute>`

```hcl
# vpc.tf defines the VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# security_groups.tf REFERENCES the VPC by its local name
resource "aws_security_group" "k8s_master_sg" {
  vpc_id = aws_vpc.main.id        # ← type=aws_vpc, name=main, attribute=id
  #        ─────────────────
  #        Terraform resolves this to the actual AWS VPC ID after the VPC is created
}

# outputs.tf REFERENCES the EC2 instance
output "master_public_ip" {
  value = aws_instance.k8s_master.public_ip   # ← type=aws_instance, name=k8s_master
}
```

**What happens if NOT used:**
You'd have to hardcode actual AWS IDs (e.g., `vpc-0abc123`) — which change every `terraform apply`. References let Terraform resolve IDs automatically and determine the creation order.

**Terraform automatically figures out order:**
```
aws_security_group references aws_vpc.main.id
→ Terraform knows: create VPC first, then SG
→ No manual ordering needed
```

---

## 5.7d  `tls_private_key` RESOURCE — AUTO-GENERATE SSH KEY FOR EC2

Instead of manually running `ssh-keygen`, Terraform generates the key pair as part of `terraform apply`.

```hcl
# Generates the key pair in memory
resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Uploads the PUBLIC key to AWS (so EC2 allows SSH with this key)
resource "aws_key_pair" "k8s_key_pair" {
  key_name   = "terraform-key"
  public_key = tls_private_key.k8s_key.public_key_openssh  # ← reference
}

# Saves the PRIVATE key to a .pem file on the Jenkins VM
resource "local_file" "private_key" {
  content         = tls_private_key.k8s_key.private_key_pem
  filename        = "~/terraform-key.pem"
  file_permission = "0400"   # owner read-only — SSH refuses keys with looser permissions
}
```

**After `terraform apply`:** The file `~/terraform-key.pem` exists on the Jenkins VM.

**SSH into EC2:**
```bash
ssh -i ~/terraform-key.pem ubuntu@<ec2-public-ip>
# -i = identity file (which key to use)
```

**`file_permission = "0400"` — why:**
SSH refuses to use private keys if the file is readable by others. `0400` = owner read-only.
If wrong permissions: `WARNING: UNPROTECTED PRIVATE KEY FILE` → SSH refuses to connect.

---

## 5.7e  `depends_on` — EXPLICIT RESOURCE ORDERING

Normally Terraform figures out order automatically via references. `depends_on` is for cases where the dependency is implicit (not a direct reference).

```hcl
resource "aws_instance" "k8s_worker" {
  # ...
  depends_on = [aws_internet_gateway.main]
  # Terraform might not see this dependency from references alone
  # Without it: EC2 might try to launch before IGW exists → networking fails
}
```

**When you need it:**
- Resource A uses Resource B, but doesn't directly reference B's attributes
- A depends on a side effect of B (e.g., an IAM role policy being attached before an EC2 launches)

**In our project:** Not explicitly used — Terraform detects dependencies via the `aws_vpc.main.id` references automatically.

---

## 5.8  AWS INFRASTRUCTURE WE'LL BUILD

```
AWS us-east-1
└── VPC (10.0.0.0/16)
    ├── Public Subnet (10.0.1.0/24) — us-east-1a
    │   └── Internet Gateway → Route Table
    ├── EC2 — K8s Master Node (t3.medium: 2 vCPU, 4GB)
    │   └── Security Group: allow 22, 6443, 8080
    └── EC2 — K8s Worker Node (t3.medium: 2 vCPU, 4GB)
        └── Security Group: allow 22, 80, 8080

Key Pair: terraform-key (SSH access to EC2 instances)
```

---

## 5.9  KEY GOTCHA — AWS CREDENTIALS SECURITY

| ✅ Safe | ❌ Never do |
|---|---|
| `~/.aws/credentials` on the machine | Hardcode in `.tf` files |
| Environment variables (`AWS_ACCESS_KEY_ID`) | Paste in chat or email |
| AWS IAM roles (best for production) | Commit to Git |
| Terraform `tfvars` in `.gitignore` | Share access key + secret together |

---

*Last updated: 2026-04-10 — Phase 2 started: AWS CLI + Terraform installed on Jenkins VM ✅*

