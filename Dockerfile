FROM ghcr.io/ggml-org/llama.cpp:server-cuda

# Default OpenCode version. Override via build-arg OPENCODE_VERSION=...
ARG OPENCODE_VERSION=1.2.4
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
    python3 -c 'import re; from pathlib import Path; p=Path("backend/src/services/opencode-single-server.ts"); t=p.read_text(encoding="utf-8"); pat=re.compile(r"async checkHealth\\(\\): Promise<boolean> \\{.*?\\n\\s*\\}\\n", re.S); repl="async checkHealth(): Promise<boolean> {\\n    const baseUrl = `http://${OPENCODE_SERVER_HOST}:${OPENCODE_SERVER_PORT}`\\n\\n    // Prefer lightweight health endpoints. /doc may hang on some OpenCode versions.\\n    const checks: Array<{ path: string, timeoutMs: number }> = [\\n      { path: \\\"/global/health\\\", timeoutMs: 1500 },\\n      { path: \\\"/health\\\", timeoutMs: 1500 },\\n      { path: \\\"/doc\\\", timeoutMs: 500 },\\n    ]\\n\\n    for (const check of checks) {\\n      try {\\n        const response = await fetch(`${baseUrl}${check.path}`, {\\n          signal: AbortSignal.timeout(check.timeoutMs)\\n        })\\n        if (response.ok) return true\\n      } catch {\\n        // Try next endpoint\\n      }\\n    }\\n\\n    return false\\n  }\\n"; nt,n=pat.subn(repl,t,1); assert n==1, "Failed to patch checkHealth() in opencode-single-server.ts"; p.write_text(nt,encoding="utf-8"); print("Patched opencode-manager checkHealth() to prefer /global/health");'; \
    pnpm install --frozen-lockfile; \
    pnpm build; \
    mkdir -p /opt/opencode-manager/backend/node_modules/@opencode-manager /workspace/opencode-manager/data; \
    ln -sf /opt/opencode-manager/shared /opt/opencode-manager/backend/node_modules/@opencode-manager/shared; \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=755 start.sh /start.sh

# llama.cpp + OpenCode Manager
EXPOSE 8080 5003

ENTRYPOINT ["/start.sh"]
