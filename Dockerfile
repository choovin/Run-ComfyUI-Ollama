FROM ghcr.io/ggml-org/llama.cpp:server-cuda

# Default OpenCode version. Override via build-arg OPENCODE_VERSION=...
ARG OPENCODE_VERSION=1.2.15
ARG OPENCODE_MANAGER_REF=v0.9.05
ARG NODE_VERSION=22.14.0
ARG OPENCLAW_VERSION=latest
ARG OPENCLAW_MISSION_CONTROL_REF=main
ARG CONVEX_BACKEND_VERSION=precompiled-2026-02-26-5fdc3b8

WORKDIR /workspace

ENV LD_LIBRARY_PATH="/app:/opt/llama/bin:/usr/local/lib:${LD_LIBRARY_PATH}"

# Bun 安装配置
ENV BUN_INSTALL="/root/.bun"

COPY scripts/patch_opencode_manager.py /workspace/scripts/patch_opencode_manager.py
COPY scripts/setup_openclaw.sh /workspace/scripts/setup_openclaw.sh
COPY config/openclaw.json /workspace/config/openclaw.json
COPY config/auth-profiles.json /workspace/config/auth-profiles.json
COPY config/dingtalk.env /workspace/config/dingtalk.env

# 安装依赖
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
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
      ssh \
      netplan.io \
      unzip; \
    # 下载 Node.js
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -o /tmp/node.tar.xz; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1; \
    rm -f /tmp/node.tar.xz; \
    corepack enable; \
    corepack prepare pnpm@10.28.1 --activate; \
    # 安装 Bun
    export BUN_INSTALL="/root/.bun"; \
    mkdir -p "$BUN_INSTALL/bin"; \
    curl -fsSL --connect-timeout 10 --max-time 60 https://bun.sh/install | bash; \
    ln -sf "$BUN_INSTALL/bin/bun" /usr/local/bin/bun; \
    # 安装 OpenCode
    if [ "${OPENCODE_VERSION}" = "latest" ]; then \
      curl -fsSL --connect-timeout 10 --max-time 120 https://opencode.ai/install | bash -s -- --no-modify-path; \
    else \
      curl -fsSL --connect-timeout 10 --max-time 120 https://opencode.ai/install | bash -s -- --version "${OPENCODE_VERSION}" --no-modify-path; \
    fi; \
    mv /root/.opencode /opt/opencode; \
    chmod -R 755 /opt/opencode; \
    ln -sf /opt/opencode/bin/opencode /usr/local/bin/opencode; \
    # Install code-server (placed here since it doesn't change often, enables faster rebuilds) \
    curl -fsSL https://code-server.dev/install.sh | sh; \
    # Install opencode plugin for code-server via VSCode Marketplace \
    code-server --install-extension sst-dev.opencode --force || true; \
    # 克隆 OpenCode Manager
    if [ -n "${OPENCODE_MANAGER_REF}" ]; then \
      git clone --depth 1 --branch "${OPENCODE_MANAGER_REF}" https://github.com/chriswritescode-dev/opencode-manager.git /opt/opencode-manager; \
    else \
      git clone --depth 1 https://github.com/chriswritescode-dev/opencode-manager.git /opt/opencode-manager; \
    fi; \
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
    if [ -n "${OPENCLAW_MISSION_CONTROL_REF}" ]; then \
      git clone --depth 1 --branch "${OPENCLAW_MISSION_CONTROL_REF}" https://github.com/manish-raana/openclaw-mission-control.git /opt/openclaw-mission-control; \
    else \
      git clone --depth 1 https://github.com/manish-raana/openclaw-mission-control.git /opt/openclaw-mission-control; \
    fi; \
    cd /opt/openclaw-mission-control; \
    if [ -f "package.json" ]; then \
      pnpm install --frozen-lockfile 2>/dev/null || npm install; \
      if [ -f "package.json" ] && grep -q '"build"' package.json; then \
        pnpm build 2>/dev/null || npm run build; \
      fi; \
    fi; \
    chmod -R 755 /opt/openclaw-mission-control

# Install Convex Backend (self-hosted)
RUN set -eux; \
    ARCH=$(uname -m); \
    case "$ARCH" in \
      x86_64) CONVEX_ARCH="x86_64" ;; \
      aarch64) CONVEX_ARCH="aarch64" ;; \
      *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; \
    esac; \
    CONVEX_URL="https://github.com/get-convex/convex-backend/releases/download/${CONVEX_BACKEND_VERSION}/convex-local-backend-${CONVEX_ARCH}-unknown-linux-gnu.zip"; \
    mkdir -p /opt/convex-backend; \
    curl -fsSL -o /tmp/convex-backend.zip "${CONVEX_URL}"; \
    unzip -o /tmp/convex-backend.zip -d /opt/convex-backend; \
    chmod +x /opt/convex-backend/convex-local-backend; \
    ln -sf /opt/convex-backend/convex-local-backend /usr/local/bin/convex-local-backend; \
    rm -f /tmp/convex-backend.zip

# Setup OpenClaw configurations
RUN set -eux; \
    mkdir -p /root/.openclaw/agents/main/agent; \
    cp /workspace/config/openclaw.json /root/.openclaw/openclaw.json; \
    cp /workspace/config/auth-profiles.json /root/.openclaw/agents/main/agent/auth-profiles.json; \
    chmod -R 755 /root/.openclaw

# Install vLLM (nightly for Step3.5 support) and SGLang (latest from git)
# Note: Current environment uses CUDA 12.9, using cu129 for best compatibility
ARG VLLM_VERSION=0.16.1.dev
RUN set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      python3-pip \
      python3-venv; \
    # Install uv package manager \
    pip3 install --no-cache-dir uv; \
    # Install vLLM nightly (for Step3.5 support) \
    pip3 install --no-cache-dir \
      vllm==${VLLM_VERSION} \
      --extra-index-url https://wheels.vllm.ai/nightly \
      --extra-index-url https://download.pytorch.org/whl/cu129 || true; \
    # Install SGLang latest from git (official recommended method) \
    uv pip install --system 'git+https://github.com/sgl-project/sglang.git#subdirectory=python&egg=sglang[all]' || true; \
    rm -rf /var/lib/apt/lists/*

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

# Generate git commit file for runtime diagnostics
RUN if command -v git >/dev/null 2>&1 && [[ -d /workspace/.git ]]; then \
      git -C /workspace rev-parse HEAD > /workspace/.git_commit; \
    else \
      echo "unknown" > /workspace/.git_commit; \
    fi

COPY --chmod=755 start.sh /start.sh

# llama.cpp / vLLM / SGLang + OpenCode Manager + OpenCode Server + OpenClaw + Mission Control + Convex Backend + Code-Server
EXPOSE 8000 8001 8080 5003 5551 3000 18789 3210 3211 6791 9000

ENTRYPOINT ["/start.sh"]