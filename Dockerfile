FROM ghcr.io/ggml-org/llama.cpp:server-cuda

ARG OPENCODE_VERSION=latest
ARG OPENCODE_MANAGER_REF=main
ARG NODE_VERSION=22.14.0

WORKDIR /workspace

ENV LD_LIBRARY_PATH="/app:/opt/llama/bin:/usr/local/lib:${LD_LIBRARY_PATH}"

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
    cd /opt/opencode-manager; \
    # Patch opencode-manager health check to tolerate slow opencode startup:
    # - increase per-request timeout (was 3s)
    # - use env HEALTH_CHECK_TIMEOUT_MS for overall wait (was hardcoded 30s)
    # - sleep interval uses env HEALTH_CHECK_INTERVAL_MS
    sed -i \
      -e 's/AbortSignal\\.timeout(3000)/AbortSignal.timeout(10000)/g' \
      -e 's/const healthy = await this\\.checkHealth()/const healthy = await this.waitForHealth(ENV.TIMEOUTS.HEALTH_CHECK_TIMEOUT_MS)/' \
      -e 's/await this\\.waitForHealth(30000)/await this.waitForHealth(ENV.TIMEOUTS.HEALTH_CHECK_TIMEOUT_MS)/' \
      -e 's/setTimeout\\(r, 500\\)/setTimeout(r, ENV.TIMEOUTS.HEALTH_CHECK_INTERVAL_MS)/' \
      backend/src/services/opencode-single-server.ts; \
    pnpm install --frozen-lockfile; \
    pnpm build; \
    mkdir -p /opt/opencode-manager/backend/node_modules/@opencode-manager /workspace/opencode-manager/data; \
    ln -sf /opt/opencode-manager/shared /opt/opencode-manager/backend/node_modules/@opencode-manager/shared; \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=755 start.sh /start.sh

# llama.cpp + OpenCode Manager
EXPOSE 8080 5003

ENTRYPOINT ["/start.sh"]
