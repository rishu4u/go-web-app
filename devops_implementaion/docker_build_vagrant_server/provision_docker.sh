#!/usr/bin/env bash
# ============================================================
# provision_docker.sh
# Provision script for the Docker build & push Vagrant server
# Installs Docker CE, builds the image, manages version tags,
# and optionally pushes to DockerHub.
# ============================================================

set -euo pipefail

APP_DIR="/home/vagrant/go-web-app"
DEVOPS_DIR="/home/vagrant/devops"
DOCKERFILE="${DEVOPS_DIR}/Dockerfile"
VERSION_FILE="${DEVOPS_DIR}/docker_build_vagrant_server/.docker_version"

echo "================================================================"
echo " Step 1: Update package lists & install prerequisites"
echo "================================================================"
apt-get update -y
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

echo "================================================================"
echo " Step 2: Install Docker CE"
echo "================================================================"

if command -v docker &>/dev/null; then
  echo "Docker already installed — skipping"
else
  # Add Docker's official GPG key
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # Add the Docker apt repository
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
fi

# Add vagrant user to docker group so it can run docker without sudo
usermod -aG docker vagrant

echo "Docker version: $(docker --version)"

echo "================================================================"
echo " Step 3: Validate credentials"
echo "================================================================"

if [ -z "${DOCKERHUB_USERNAME}" ] || [ -z "${DOCKERHUB_TOKEN}" ]; then
  echo "ERROR: DOCKERHUB_USERNAME or DOCKERHUB_TOKEN is not set."
  echo "On your HOST machine run:"
  echo "   export DOCKERHUB_USERNAME=<your-username>"
  echo "   export DOCKERHUB_TOKEN=<your-token>"
  echo "Then re-run: vagrant up --provision"
  exit 1
fi

echo "================================================================"
echo " Step 4: Version tag management"
echo "================================================================"

# ── Read the last version from the version file ──────────────
if [ -f "${VERSION_FILE}" ]; then
  LAST_VERSION=$(cat "${VERSION_FILE}")
  echo "Last build tag : ${DOCKERHUB_USERNAME}/go-web-app:${LAST_VERSION}"

  # Auto-increment minor version  (v1.0 → v1.1, v2.9 → v2.10)
  MAJOR=$(echo "${LAST_VERSION}" | sed 's/^v//' | cut -d. -f1)
  MINOR=$(echo "${LAST_VERSION}" | sed 's/^v//' | cut -d. -f2)
  MINOR=$((MINOR + 1))
  SUGGESTED_VERSION="v${MAJOR}.${MINOR}"
else
  echo "No previous version found — starting fresh."
  SUGGESTED_VERSION="v1.0"
fi

echo "Suggested next tag: ${SUGGESTED_VERSION}"
echo ""

# ── Allow the user to accept or override the tag ─────────────
# (In Vagrant non-interactive mode, fall back to the suggestion automatically)
if [ -t 0 ]; then
  read -rp "Enter version tag [${SUGGESTED_VERSION}]: " USER_VERSION
  VERSION="${USER_VERSION:-${SUGGESTED_VERSION}}"
else
  echo "(Non-interactive shell detected — using suggested tag automatically)"
  VERSION="${SUGGESTED_VERSION}"
fi

IMAGE_TAG="${DOCKERHUB_USERNAME}/go-web-app:${VERSION}"
echo ""
echo "Building image as: ${IMAGE_TAG}"

echo "================================================================"
echo " Step 5: Docker login"
echo "================================================================"
echo "${DOCKERHUB_TOKEN}" | docker login --username "${DOCKERHUB_USERNAME}" --password-stdin

echo "================================================================"
echo " Step 6: Build Docker image"
echo "================================================================"

if [ ! -f "${DOCKERFILE}" ]; then
  echo "ERROR: Dockerfile not found at ${DOCKERFILE}"
  echo "Make sure devops_implementaion/Dockerfile exists."
  exit 1
fi

docker build \
  -f "${DOCKERFILE}" \
  -t "${IMAGE_TAG}" \
  "${APP_DIR}"

echo "Image built: ${IMAGE_TAG}"

# ── Save the new version immediately after a successful build ─
echo "${VERSION}" > "${VERSION_FILE}"
echo "Version saved to: ${VERSION_FILE}"

echo "================================================================"
echo " Step 7: Push to DockerHub?"
echo "================================================================"

# ── Interactive push prompt ───────────────────────────────────
PUSH_ANSWER="n"
if [ -t 0 ]; then
  read -rp "Push ${IMAGE_TAG} to DockerHub? [y/N]: " PUSH_ANSWER
else
  echo "(Non-interactive shell — skipping push. Run manually: docker push ${IMAGE_TAG})"
fi

case "${PUSH_ANSWER}" in
  [yY][eE][sS]|[yY])
    echo "Pushing image..."
    docker push "${IMAGE_TAG}"
    echo "================================================================"
    echo " SUCCESS — image pushed: ${IMAGE_TAG}"
    echo " Pull it anywhere with:"
    echo "   docker pull ${IMAGE_TAG}"
    echo "================================================================"
    ;;
  *)
    echo "Skipped push."
    echo "To push later, run:"
    echo "   docker push ${IMAGE_TAG}"
    echo "================================================================"
    ;;
esac
