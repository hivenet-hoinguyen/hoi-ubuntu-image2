FROM ubuntu:latest

ENV VERSION=staging-1.30
ENV MODE=staging
ENV DEBIAN_FRONTEND=noninteractive

# Use bash for RUN steps so we can source NVM
SHELL ["/bin/bash", "-lc"]

# -----------------------------
# Install base tools + Java + Python + network tools + nano
# -----------------------------
RUN echo "=== [1/6] Installing base tools, Java, Python, and network utilities ===" && \
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
    echo "Installed: openjdk-17-jdk, python3, ping, netcat, nano, curl/wget"

# -----------------------------
# Install Go
# -----------------------------
ENV GO_VERSION=1.23.11
RUN echo "=== [2/6] Installing Go ${GO_VERSION} ===" && \
    wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
    rm -rf /usr/local/go && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm go${GO_VERSION}.linux-amd64.tar.gz && \
    /usr/local/go/bin/go version

# -----------------------------
# Install Node.js (LTS) from NodeSource (system-wide)
# -----------------------------
RUN echo "=== [3/6] Installing Node.js (LTS) from NodeSource (system node) ===" && \
    apt-get update && \
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    echo "System Node: $(node -v)" && \
    echo "System npm:  $(npm -v)"

# -----------------------------
# Install NVM + Node via NVM
# -----------------------------
ENV NVM_DIR=/root/.nvm
ENV NVM_VERSION=v0.39.7
# Choose a specific Node version for NVM (change if you want)
ENV NVM_NODE_VERSION=22

RUN echo "=== [4/6] Installing NVM ${NVM_VERSION} and Node ${NVM_NODE_VERSION} via NVM ===" && \
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash && \
    source "${NVM_DIR}/nvm.sh" && \
    nvm --version && \
    nvm install "${NVM_NODE_VERSION}" && \
    nvm use "${NVM_NODE_VERSION}" && \
    nvm alias default "${NVM_NODE_VERSION}" && \
    echo "NVM Node: $(node -v)" && \
    echo "NVM npm:  $(npm -v)" && \
    # Make NVM load automatically in login shells
    printf '%s\n' \
      "export NVM_DIR=\"${NVM_DIR}\"" \
      "[ -s \"${NVM_DIR}/nvm.sh\" ] && \\. \"${NVM_DIR}/nvm.sh\"" \
      > /etc/profile.d/nvm.sh

# Put NVM Node on PATH for non-interactive commands too
ENV PATH="${NVM_DIR}/versions/node/v${NVM_NODE_VERSION}/bin:${PATH}"

# -----------------------------
# Go env
# -----------------------------
ENV GOROOT=/usr/local/go
ENV GOPATH=/root/go
ENV PATH=/usr/local/go/bin:/root/go/bin:${PATH}

# Make env available in login shells
RUN echo "=== [5/6] Writing /etc/profile.d/custom_env.sh ===" && \
    printf '%s\n' \
      "export VERSION=${VERSION}" \
      "export MODE=${MODE}" \
      "export GOROOT=${GOROOT}" \
      "export GOPATH=${GOPATH}" \
      "export PATH=${PATH}" \
      > /etc/profile.d/custom_env.sh

# -----------------------------
# Final summary logs
# -----------------------------
RUN echo "=== [6/6] Installed tool versions summary ===" && \
    echo "VERSION=${VERSION}" && \
    echo "MODE=${MODE}" && \
    echo "OS:        $(. /etc/os-release && echo $PRETTY_NAME)" && \
    echo "Java:      $(java -version 2>&1 | head -n 1)" && \
    echo "Python:    $(python3 --version)" && \
    echo "Go:        $(go version)" && \
    echo "Node(sys): $(/usr/bin/node -v 2>/dev/null || true)" && \
    echo "npm(sys):  $(/usr/bin/npm -v 2>/dev/null || true)" && \
    echo "NVM:       $(source ${NVM_DIR}/nvm.sh && nvm --version)" && \
    echo "Node(nvm): $(node -v)" && \
    echo "npm(nvm):  $(npm -v)" && \
    echo "nano:      $(nano --version | head -n 1)" && \
    echo "ping:      $(ping -V 2>/dev/null | head -n 1 || true)" && \
    echo "nc:        $(nc -h 2>&1 | head -n 1 || true)"

# Keep container alive for Kubernetes exec/debug
CMD ["sleep", "infinity"]
