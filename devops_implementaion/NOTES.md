# Git & GitHub Setup — Commands Reference

All commands used to set up and push this project to a new GitHub repository.

---

## 1. Check SSH Authentication with GitHub

```bash
ssh -T git@github.com
# Expected: Hi rishu4u! You've successfully authenticated...
```

---

## 2. Point the Remote to Your New Repo

```bash
cd /home/srv/project_srv

git remote set-url origin git@github.com:rishu4u/go-web-app.git

# Verify
git remote -v
```

---

## 3. Set Git Identity (one-time)

```bash
git config user.name "rishu4u"
git config user.email "your@email.com"
```

---

## 4. Create a .gitignore (before staging)

The `.gitignore` at the root excludes:
- `.vagrant/` directories  (Vagrant machine state — never commit)
- `go-web-app/` and `go-web-app-devops/` (embedded git repos)
- `export.sh`, `login.txt`, `dockerhub_creds.env` (secrets)

---

## 5. Stage & Commit

```bash
# Reset index (clears any previously staged files)
git rm -r --cached -f .

# Re-stage respecting .gitignore
git add .

# Commit
git commit -m "Initial commit: Go web app DevOps pipeline (Jenkins, Helm, K8s, Docker)"
```

---

## 6. Push to GitHub

```bash
git push -u origin master
```

> **Note:** GitHub's secret scanning blocked the first push because `export.sh`
> contained a real DockerHub token. The fix was to replace it with placeholders,
> then amend the commit **before** pushing:
>
> ```bash
> # After redacting export.sh
> git add devops_implementaion/docker_build_vagrant_server/export.sh
> git commit --amend --no-edit
> git push -u origin master
> ```

---

## 7. Future Pushes (after changes)

```bash
git add .
git commit -m "your message"
git push
```

---

## 8. Jenkins Job Configuration (the fix for the pipeline error)

The Jenkins error was:
```
fatal: '/home/vagrant/devops' does not appear to be a git repository
```

**Root cause:** Jenkins was set to "Pipeline script from SCM" pointing at a
Vagrant synced folder that had no `.git` directory.

**Fix — configure the Jenkins job to use your GitHub repo:**

| Field            | Value                                               |
|------------------|-----------------------------------------------------|
| Definition       | Pipeline script from SCM                            |
| SCM              | Git                                                 |
| Repository URL   | `git@github.com:rishu4u/go-web-app.git`             |
| Branch           | `*/master`                                          |
| Script Path      | `devops_implementaion/Jenkinsfile`                  |

> Add your SSH key or GitHub credentials in **Jenkins → Manage Jenkins →
> Credentials** so Jenkins can clone the repo.

---

## Repository Structure

```
go-web-app/                         ← GitHub repo root
├── .gitignore
└── devops_implementaion/
    ├── Jenkinsfile                  ← Jenkins pipeline definition
    ├── Dockerfile
    ├── build_test_vagrant_server/
    ├── docker_build_vagrant_server/
    ├── jenkins_vagrant_server/
    ├── helm/go-web-app-chart/       ← Helm chart for K8s deployment
    └── k8s/manifests/               ← Raw K8s YAML files
```
