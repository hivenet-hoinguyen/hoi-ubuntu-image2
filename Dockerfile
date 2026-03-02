FROM ubuntu:latest

ENV VERSION=staging-1.30
ENV MODE=staging
ENV DEBIAN_FRONTEND=noninteractive

# Use bash so we can source scripts during RUN
SHELL ["/bin/bash", "-lc"]

# -----------------------------
# Create ubuntu user (idempotent)
# -----------------------------
RUN echo "=== [0/7] Ensuring ubuntu user exists ===" && \
    id ubuntu >/dev/null 2>&1 || useradd -m -s /bin/bash ubuntu

# -----------------------------
# Install base tools + Java + Python + network tools + nano
# -----------------------------
RUN echo "=== [1/7] Installing base tools, Java, Python, and network utilities ===" && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      openjdk-17-jdk \
      wget curl ca-certificates gnupg \
      python3 \
      iputils-ping \
      netcat-openbsd \
      nano && \
    rm -rf /var/lib/apt/lists/* && \
    echo "Java:   $(java -version 2>&1 | head -n 1)" && \
    echo "Python: $(python3 --version)" && \
    echo "nano:   $(nano --version | head -n 1)"

# -----------------------------
# Install Go
# -----------------------------
ENV GO_VERSION=1.23.11
RUN echo "=== [2/7] Installing Go ${GO_VERSION} ===" && \
    wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
    rm -rf /usr/local/go && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm go${GO_VERSION}.linux-amd64.tar.gz && \
    /usr/local/go/bin/go version

# -----------------------------
# Install Node.js (LTS) from NodeSource (system-wide)
# -----------------------------
RUN echo "=== [3/7] Installing Node.js (LTS) from NodeSource (system node) ===" && \
    apt-get update && \
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    echo "System Node: $(node -v)" && \
    echo "System npm:  $(npm -v)"

# -----------------------------
# Install NVM for ubuntu user + Node via NVM
# -----------------------------
ENV NVM_VERSION=v0.39.7
ENV NVM_DIR=/home/ubuntu/.nvm
ENV NVM_NODE_VERSION=22

RUN echo "=== [4/7] Installing NVM ${NVM_VERSION} for ubuntu at ${NVM_DIR} ===" && \
    mkdir -p "${NVM_DIR}" && \
    chown -R ubuntu:ubuntu /home/ubuntu && \
    su - ubuntu -c "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash" && \
    su - ubuntu -c "source ${NVM_DIR}/nvm.sh && nvm --version" && \
    su - ubuntu -c "source ${NVM_DIR}/nvm.sh && nvm install ${NVM_NODE_VERSION} && nvm alias default ${NVM_NODE_VERSION}" && \
    su - ubuntu -c "source ${NVM_DIR}/nvm.sh && node -v && npm -v"

# Load NVM automatically for login shells
RUN echo "=== [5/7] Installing /etc/profile.d/nvm.sh (login shells) ===" && \
    printf '%s\n' \
      "export NVM_DIR=\"${NVM_DIR}\"" \
      "[ -s \"${NVM_DIR}/nvm.sh\" ] && \\. \"${NVM_DIR}/nvm.sh\"" \
      > /etc/profile.d/nvm.sh

# Provide an nvm wrapper so it works even when profiles are not sourced
RUN echo "=== [6/7] Creating /usr/local/bin/nvm wrapper (non-login shells) ===" && \
    cat >/usr/local/bin/nvm <<'EOF' && \
    chmod +x /usr/local/bin/nvm
#!/usr/bin/env bash
set -euo pipefail
export NVM_DIR="${NVM_DIR:-/home/ubuntu/.nvm}"
# shellcheck disable=SC1090
source "${NVM_DIR}/nvm.sh"
nvm "$@"
EOF

# -----------------------------
# Go env + general env
# -----------------------------
ENV GOROOT=/usr/local/go
ENV GOPATH=/home/ubuntu/go
# Put Go and NVM Node on PATH (NVM Node first so `node` is the NVM one by default)
ENV PATH=/home/ubuntu/.nvm/versions/node/v${NVM_NODE_VERSION}/bin:/usr/local/go/bin:/home/ubuntu/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Make env available in login shells
RUN echo "=== [7/7] Writing /etc/profile.d/custom_env.sh and printing summary ===" && \
    printf '%s\n' \
      "export VERSION=${VERSION}" \
      "export MODE=${MODE}" \
      "export GOROOT=${GOROOT}" \
      "export GOPATH=${GOPATH}" \
      "export PATH=${PATH}" \
      > /etc/profile.d/custom_env.sh && \
    echo "=== Installed tool versions summary ===" && \
    echo "VERSION=${VERSION}" && \
    echo "MODE=${MODE}" && \
    echo "OS:        $(. /etc/os-release && echo $PRETTY_NAME)" && \
    echo "Java:      $(java -version 2>&1 | head -n 1)" && \
    echo "Python:    $(python3 --version)" && \
    echo "Go:        $(go version)" && \
    echo "Node(sys): $(/usr/bin/node -v 2>/dev/null || true)" && \
    echo "npm(sys):  $(/usr/bin/npm -v 2>/dev/null || true)" && \
    echo "NVM:       $(nvm --version)" && \
    echo "Node(nvm): $(node -v)" && \
    echo "npm(nvm):  $(npm -v)" && \
    echo "nano:      $(nano --version | head -n 1)" && \
    echo "ping:      $(ping -V 2>/dev/null | head -n 1 || true)" && \
    echo "nc:        $(nc -h 2>&1 | head -n 1 || true)"

# Run as ubuntu by default (matches your instance user)
USER ubuntu
ENV HOME=/home/ubuntu
WORKDIR /home/ubuntu

# Keep container alive for Kubernetes exec/debug
CMD ["sleep", "infinity"]
