FROM ubuntu:latest

ENV VERSION=staging-1.30
ENV MODE=staging
ENV DEBIAN_FRONTEND=noninteractive

# Base tools + Java + Python + network tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      openjdk-17-jdk wget curl python3 iputils-ping netcat-openbsd \
      nano ca-certificates gnupg && \
    rm -rf /var/lib/apt/lists/*

# Install Go
RUN wget -q https://go.dev/dl/go1.23.11.linux-amd64.tar.gz && \
    rm -rf /usr/local/go && \
    tar -C /usr/local -xzf go1.23.11.linux-amd64.tar.gz && \
    rm go1.23.11.linux-amd64.tar.gz

# Install Node.js (LTS) from NodeSource
RUN apt-get update && \
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# Go env
ENV GOROOT=/usr/local/go
ENV GOPATH=/root/go
ENV PATH=/usr/local/go/bin:/root/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Make env available in login shells
RUN printf '%s\n' \
  "export VERSION=${VERSION}" \
  "export MODE=${MODE}" \
  "export GOROOT=${GOROOT}" \
  "export GOPATH=${GOPATH}" \
  "export PATH=${PATH}" \
  > /etc/profile.d/custom_env.sh

# Copy init script (required)
COPY init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

ENTRYPOINT ["/usr/local/bin/init.sh"]
