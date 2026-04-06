#!/usr/bin/env bash
# ============================================================
# provision_test.sh
# Provision script for the Go test Vagrant server
# Installs Go 1.22 and runs the go-web-app test suite
# ============================================================

set -euo pipefail

GO_VERSION="1.22.5"
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"
GO_DOWNLOAD_URL="https://go.dev/dl/${GO_TARBALL}"
INSTALL_DIR="/usr/local"
APP_DIR="/home/vagrant/go-web-app"

echo "================================================================"
echo " Step 1: Update package lists"
echo "================================================================"
apt-get update -y
apt-get install -y wget curl git

echo "================================================================"
echo " Step 2: Install Go ${GO_VERSION}"
echo "================================================================"

if [ -d "${INSTALL_DIR}/go" ]; then
  echo "Go already installed — skipping download"
else
  echo "Downloading ${GO_TARBALL} ..."
  wget -q "${GO_DOWNLOAD_URL}" -O "/tmp/${GO_TARBALL}"
  tar -C "${INSTALL_DIR}" -xzf "/tmp/${GO_TARBALL}"
  rm -f "/tmp/${GO_TARBALL}"
  echo "Go installed to ${INSTALL_DIR}/go"
fi

# Make Go available system-wide
cat > /etc/profile.d/go.sh << 'EOF'
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
EOF

# Also export for current shell session
export PATH=$PATH:/usr/local/go/bin
export GOPATH=/root/go

echo "Go version: $(/usr/local/go/bin/go version)"

echo "================================================================"
echo " Step 3: Run go tests inside ${APP_DIR}"
echo "================================================================"

if [ ! -d "${APP_DIR}" ]; then
  echo "ERROR: ${APP_DIR} not found. Check synced_folder in Vagrantfile."
  exit 1
fi

cd "${APP_DIR}"

# Run tests as the vagrant user
sudo -u vagrant bash -c "
  export PATH=\$PATH:/usr/local/go/bin
  export GOPATH=/home/vagrant/go
  cd ${APP_DIR}
  echo 'Running: go test ./...'
  /usr/local/go/bin/go test ./...
"

echo "================================================================"
echo " ALL TESTS PASSED"
echo " The app source is at: ${APP_DIR}"
echo " To manually run the app:"
echo "   vagrant ssh"
echo "   cd /home/vagrant/go-web-app"
echo "   go run main.go"
echo " Then visit: http://localhost:8080/home"
echo "================================================================"
