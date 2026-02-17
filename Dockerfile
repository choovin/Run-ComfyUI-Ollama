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
    cat > /tmp/patch_opencode_manager.py <<'PY'
from pathlib import Path
import re
import sys

svc = Path("backend/src/services/opencode-single-server.ts")
svc_text = svc.read_text(encoding="utf-8")

# 1) Make startup health timeout configurable and longer by default.
if "OPENCODE_HEALTH_TIMEOUT_MS" not in svc_text:
    svc_text = svc_text.replace(
        "    const healthy = await this.waitForHealth(30000)\n"
        "    if (!healthy) {\n"
        "      this.lastStartupError = `Server failed to become healthy after 30s${stderrOutput ? `. Last error: ${stderrOutput.slice(-500)}` : ''}`\n",
        "    const rawHealthTimeoutMs = Number.parseInt(process.env.OPENCODE_HEALTH_TIMEOUT_MS || '120000', 10)\n"
        "    const healthTimeoutMs = Number.isFinite(rawHealthTimeoutMs) && rawHealthTimeoutMs >= 10000\n"
        "      ? rawHealthTimeoutMs\n"
        "      : 120000\n"
        "    const healthy = await this.waitForHealth(healthTimeoutMs)\n"
        "    if (!healthy) {\n"
        "      const timeoutSeconds = Math.floor(healthTimeoutMs / 1000)\n"
        "      this.lastStartupError = `Server failed to become healthy after ${timeoutSeconds}s${stderrOutput ? `. Last error: ${stderrOutput.slice(-500)}` : ''}`\n",
    )

# 2) Use health endpoint fallback chain instead of single endpoint.
check_health_pattern = re.compile(
    r"  async checkHealth\(\): Promise<boolean> \{\n"
    r"    try \{\n"
    r"      const response = await fetch\(`http://\$\{OPENCODE_SERVER_HOST\}:\$\{OPENCODE_SERVER_PORT\}/doc`, \{\n"
    r"        signal: AbortSignal\.timeout\(3000\)\n"
    r"      \}\)\n"
    r"      return response\.ok\n"
    r"    \} catch \{\n"
    r"      return false\n"
    r"    \}\n"
    r"  \}\n",
    re.M,
)
replacement_check_health = """  async checkHealth(): Promise<boolean> {
    const healthPaths = ['/global/health', '/doc', '/health', '/']
    for (const p of healthPaths) {
      try {
        const response = await fetch(`http://${OPENCODE_SERVER_HOST}:${OPENCODE_SERVER_PORT}${p}`, {
          signal: AbortSignal.timeout(3000)
        })
        if (response.ok) {
          return true
        }
      } catch {
        // try next path
      }
    }
    return false
  }
"""
svc_text, svc_subs = check_health_pattern.subn(replacement_check_health, svc_text, count=1)
if svc_subs == 0 and "const healthPaths = ['/global/health', '/doc', '/health', '/']" not in svc_text:
    print("Failed to patch checkHealth fallback paths", file=sys.stderr)
    sys.exit(1)

svc.write_text(svc_text, encoding="utf-8")

settings = Path("backend/src/routes/settings.ts")
settings_text = settings.read_text(encoding="utf-8")

# 3) Make install/upgrade timeout configurable and longer by default.
if "getOpenCodeUpgradeTimeoutMs()" not in settings_text:
    marker = "function execWithTimeout(command: string, timeoutMs: number, env?: Record<string, string>): { output: string; timedOut: boolean } {\n"
    helper = (
        "function getOpenCodeUpgradeTimeoutMs(): number {\n"
        "  const raw = Number.parseInt(process.env.OPENCODE_UPGRADE_TIMEOUT_MS || '300000', 10)\n"
        "  if (!Number.isFinite(raw)) return 300000\n"
        "  return Math.max(60000, raw)\n"
        "}\n\n"
    )
    if marker not in settings_text:
        print("Failed to find insertion point for getOpenCodeUpgradeTimeoutMs", file=sys.stderr)
        sys.exit(1)
    settings_text = settings_text.replace(marker, helper + marker, 1)

settings_text = settings_text.replace(
    "logger.info(`Running opencode upgrade --method ${installMethod} with 90s timeout...`)\n"
    "      const { output: upgradeOutput, timedOut } = execWithTimeout(`opencode upgrade --method ${installMethod} 2>&1`, 90000)\n"
    "      logger.info(`Upgrade output: ${upgradeOutput}`)\n\n"
    "      if (timedOut) {\n"
    "        logger.warn('OpenCode upgrade timed out after 90 seconds')\n"
    "        throw new Error('Upgrade command timed out after 90 seconds')\n"
    "      }\n",
    "logger.info(`Running opencode upgrade --method ${installMethod} ...`)\n"
    "      const timeoutMs = getOpenCodeUpgradeTimeoutMs()\n"
    "      const timeoutSeconds = Math.floor(timeoutMs / 1000)\n"
    "      const { output: upgradeOutput, timedOut } = execWithTimeout(\n"
    "        `opencode upgrade --method ${installMethod} 2>&1`,\n"
    "        timeoutMs,\n"
    "        { CI: '1', NO_COLOR: '1' }\n"
    "      )\n"
    "      logger.info(`Upgrade output: ${upgradeOutput}`)\n\n"
    "      if (timedOut) {\n"
    "        logger.warn(`OpenCode upgrade timed out after ${timeoutSeconds} seconds`)\n"
    "        throw new Error(`Upgrade command timed out after ${timeoutSeconds} seconds`)\n"
    "      }\n",
)

settings_text = settings_text.replace(
    "logger.info(`Running opencode upgrade ${versionArg} --method ${installMethod} with 90s timeout...`)\n\n"
    "      const { output: upgradeOutput, timedOut } = execWithTimeout(`opencode upgrade ${versionArg} --method ${installMethod} 2>&1`, 90000)\n"
    "      logger.info(`Upgrade output: ${upgradeOutput}`)\n\n"
    "      if (timedOut) {\n"
    "        logger.warn('OpenCode version install timed out after 90 seconds')\n"
    "        throw new Error('Version install command timed out after 90 seconds')\n"
    "      }\n",
    "logger.info(`Running opencode upgrade ${versionArg} --method ${installMethod} ...`)\n"
    "      const timeoutMs = getOpenCodeUpgradeTimeoutMs()\n"
    "      const timeoutSeconds = Math.floor(timeoutMs / 1000)\n\n"
    "      const { output: upgradeOutput, timedOut } = execWithTimeout(\n"
    "        `opencode upgrade ${versionArg} --method ${installMethod} 2>&1`,\n"
    "        timeoutMs,\n"
    "        { CI: '1', NO_COLOR: '1' }\n"
    "      )\n"
    "      logger.info(`Upgrade output: ${upgradeOutput}`)\n\n"
    "      if (timedOut) {\n"
    "        logger.warn(`OpenCode version install timed out after ${timeoutSeconds} seconds`)\n"
    "        throw new Error(`Version install command timed out after ${timeoutSeconds} seconds`)\n"
    "      }\n",
)

settings.write_text(settings_text, encoding="utf-8")
print("Patched opencode-manager health checks and upgrade timeouts")
PY
    python3 /tmp/patch_opencode_manager.py; \
    rm -f /tmp/patch_opencode_manager.py; \
    pnpm install --frozen-lockfile; \
    pnpm build; \
    mkdir -p /opt/opencode-manager/backend/node_modules/@opencode-manager /workspace/opencode-manager/data; \
    ln -sf /opt/opencode-manager/shared /opt/opencode-manager/backend/node_modules/@opencode-manager/shared; \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=755 start.sh /start.sh

# llama.cpp + OpenCode Manager
EXPOSE 8080 5003

ENTRYPOINT ["/start.sh"]
