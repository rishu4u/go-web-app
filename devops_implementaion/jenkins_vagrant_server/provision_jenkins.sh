#!/usr/bin/env bash
# ============================================================
# provision_jenkins.sh
# Provision script for the Jenkins CI/CD Vagrant server.
# Installs: Java 17, Jenkins LTS, Docker CE, Go 1.22
# ============================================================

set -euo pipefail

echo "================================================================"
echo " Step 1: Register all apt repos BEFORE first apt-get update"
echo "         (avoids stale jenkins.list causing update to fail)"
echo "================================================================"

# ── Ensure keyrings directory exists ─────────────────────────
install -m 0755 -d /etc/apt/keyrings

# ── Jenkins repo (2026 key — current official key) ───────────
echo "Adding Jenkins repo..."
wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" \
  | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# ── Docker repo ───────────────────────────────────────────────
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
  echo "Adding Docker repo..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
fi

echo "================================================================"
echo " Step 2: Update package lists & install all packages at once"
echo "================================================================"
apt-get update -y

apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  wget \
  git \
  openjdk-17-jdk \
  jenkins \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin

java -version
echo "Docker version: $(docker --version)"

echo "================================================================"
echo " Step 3: Configure users & start services"
echo "================================================================"

# Add both vagrant and jenkins users to the docker group
usermod -aG docker vagrant
usermod -aG docker jenkins

# Start and enable Jenkins
systemctl enable jenkins
systemctl start jenkins

echo "================================================================"
echo " Step 4: Install Go 1.22"
echo "================================================================"
GO_VERSION="1.22.5"
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"

if [ -d "/usr/local/go" ]; then
  echo "Go already installed — skipping"
else
  wget -q "https://go.dev/dl/${GO_TARBALL}" -O "/tmp/${GO_TARBALL}"
  tar -C /usr/local -xzf "/tmp/${GO_TARBALL}"
  rm "/tmp/${GO_TARBALL}"
fi

# Make Go available system-wide
if ! grep -q "/usr/local/go/bin" /etc/profile; then
  echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
fi
export PATH=$PATH:/usr/local/go/bin

echo "Go version: $(go version)"

echo "================================================================"
echo " Step 5: Validate DockerHub credentials env vars"
echo "================================================================"
if [ -z "${DOCKERHUB_USERNAME}" ] || [ -z "${DOCKERHUB_TOKEN}" ]; then
  echo "WARNING: DOCKERHUB_USERNAME or DOCKERHUB_TOKEN is not set."
  echo "The Jenkins pipeline will fail at the push stage unless you set:"
  echo "   export DOCKERHUB_USERNAME=<your-username>"
  echo "   export DOCKERHUB_TOKEN=<your-token>"
  echo "Then re-provision with: vagrant provision"
else
  echo "Credentials found: DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME}"
  # Store creds in a file that Jenkins can read at pipeline runtime
  mkdir -p /var/lib/jenkins
  cat > /var/lib/jenkins/dockerhub_creds.env <<EOF
DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME}
DOCKERHUB_TOKEN=${DOCKERHUB_TOKEN}
EOF
  chmod 600 /var/lib/jenkins/dockerhub_creds.env
  chown jenkins:jenkins /var/lib/jenkins/dockerhub_creds.env
  echo "Credentials saved to /var/lib/jenkins/dockerhub_creds.env"
fi

echo "================================================================"
echo " Step 6: Restart Jenkins (docker group membership takes effect)"
echo "================================================================"
systemctl restart jenkins

# Wait for Jenkins to come up
echo "Waiting for Jenkins to start..."
timeout 60 bash -c 'until curl -s http://localhost:8080 > /dev/null; do sleep 3; done'
echo "Jenkins is up!"

echo ""
echo "================================================================"
echo " PROVISIONING COMPLETE"
echo "================================================================"
echo ""
echo " Jenkins URL : http://192.168.56.12:8080"
echo "             OR http://localhost:9090  (port-forwarded to host)"
echo ""
echo " Initial Admin Password:"
cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null \
  || echo "  (already set up — password file removed)"
echo ""
echo " Next steps:"
echo "  1. Open the Jenkins URL in your browser"
echo "  2. Paste the initial admin password above"
echo "  3. Install suggested plugins"
echo "  4. Create a Pipeline job → point it to:"
echo "       /home/vagrant/devops/Jenkinsfile"
echo "     (or configure SCM polling against your GitHub repo)"
echo "================================================================"
