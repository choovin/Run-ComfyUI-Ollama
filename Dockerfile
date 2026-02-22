FROM ghcr.io/ggml-org/llama.cpp:server-cuda

# Default OpenCode version. Override via build-arg OPENCODE_VERSION=...
ARG OPENCODE_VERSION=1.2.4
ARG OPENCODE_MANAGER_REF=main
ARG NODE_VERSION=22.14.0
ARG OPENCLAW_VERSION=latest
ARG OPENCLAW_MISSION_CONTROL_REF=main

WORKDIR /workspace

ENV LD_LIBRARY_PATH="/app:/opt/llama/bin:/usr/local/lib:${LD_LIBRARY_PATH}"

COPY scripts/patch_opencode_manager.py /workspace/scripts/patch_opencode_manager.py
COPY scripts/setup_openclaw.sh /workspace/scripts/setup_openclaw.sh
COPY config/openclaw.json /workspace/config/openclaw.json
COPY config/auth-profiles.json /workspace/config/auth-profiles.json
COPY config/dingtalk.env /workspace/config/dingtalk.env

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      iproute2 \
      jq \
      lsof \
      procps \
      python3 \
      python3-pip \
      ripgrep \
      xz-utils \
      net-tools \
      iproute2 \
      tcpdump \
      btop \
      wget \
      traceroute \
      dnsutils \
      netcat-openbsd \
      nmap \
      mtr \
      ethtool \
      iputils-ping \
      telnet \
      ssh \
      netplan.io \
      unzip; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -o /tmp/node.tar.xz; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1; \
    rm -f /tmp/node.tar.xz; \
    corepack enable; \
    corepack prepare pnpm@10.28.1 --activate; \
    curl -fsSL https://bun.sh/install | bash; \
    ln -sf /root/.bun/bin/bun /usr/local/bin/bun; \
    if [ "${OPENCODE_VERSION}" = "latest" ]; then \
      curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path; \
    else \
      curl -fsSL https://opencode.ai/install | bash -s -- --version "${OPENCODE_VERSION}" --no-modify-path; \
    fi; \
    mv /root/.opencode /opt/opencode; \
    chmod -R 755 /opt/opencode; \
    ln -sf /opt/opencode/bin/opencode /usr/local/bin/opencode; \
    git clone --depth 1 --branch "${OPENCODE_MANAGER_REF}" https://github.com/chriswritescode-dev/opencode-manager.git /opt/opencode-manager; \
    python3 /workspace/scripts/patch_opencode_manager.py; \
    cd /opt/opencode-manager; \
    pnpm install --frozen-lockfile; \
    pnpm build; \
    mkdir -p /opt/opencode-manager/backend/node_modules/@opencode-manager /workspace/opencode-manager/data; \
    ln -sf /opt/opencode-manager/shared /opt/opencode-manager/backend/node_modules/@opencode-manager/shared; \
    rm -rf /var/lib/apt/lists/*

# Install OpenClaw
RUN set -eux; \
    npm install -g openclaw; \
    mkdir -p /root/.openclaw/agents/main/agent; \
    chmod -R 755 /root/.openclaw

# Install OpenClaw Mission Control
RUN set -eux; \
    git clone --depth 1 --branch "${OPENCLAW_MISSION_CONTROL_REF}" https://github.com/manish-raana/openclaw-mission-control.git /opt/openclaw-mission-control; \
    cd /opt/openclaw-mission-control; \
    if [ -f "package.json" ]; then \
      pnpm install --frozen-lockfile 2>/dev/null || npm install; \
      if [ -f "package.json" ] && grep -q '"build"' package.json; then \
        pnpm build 2>/dev/null || npm run build; \
      fi; \
    fi; \
    chmod -R 755 /opt/openclaw-mission-control

# Setup OpenClaw configurations
RUN set -eux; \
    mkdir -p /root/.openclaw/agents/main/agent; \
    cp /workspace/config/openclaw.json /root/.openclaw/openclaw.json; \
    cp /workspace/config/auth-profiles.json /root/.openclaw/agents/main/agent/auth-profiles.json; \
    chmod -R 755 /root/.openclaw

# Install locale and configure UTF-8
RUN apt-get update && \
    apt-get install -y locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

# Load DingTalk environment variables
ENV DINGTALK_CLIENT_ID=${DINGTALK_CLIENT_ID:-ding4iqz6zneluw2gyts}
ENV DINGTALK_CLIENT_SECRET=${DINGTALK_CLIENT_SECRET:-key-9b1c8e5a-9c3d-4f1e-8b2a-1234567890ab}
ENV DINGTALK_ALLOWED_USERS=${DINGTALK_ALLOWED_USERS:-*}

COPY --chmod=755 start.sh /start.sh

# llama.cpp + OpenCode Manager + OpenClaw + Mission Control
EXPOSE 8080 5003 5551 3000 8081

ENTRYPOINT ["/start.sh"]
