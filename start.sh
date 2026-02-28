#!/bin/bash
set -euo pipefail

echo "[INFO] Starting services: llama.cpp + OpenCode Manager + OpenClaw + Mission Control"

# Ensure llama.cpp runtime shared libraries can be resolved.
# Some upstream images place llama-server and its .so files under /app.
export LD_LIBRARY_PATH="/app:/opt/llama/bin:/usr/local/lib:${LD_LIBRARY_PATH:-}"
export PATH="/app:/opt/llama/bin:/usr/local/bin:/root/.bun/bin:${PATH}"

# ==================== Configuration ====================
# llama.cpp settings
LLAMACPP_HOST="${LLAMACPP_HOST:-0.0.0.0}"
LLAMACPP_PORT="${LLAMACPP_PORT:-8080}"
LLAMACPP_MODEL_PATH="${LLAMACPP_MODEL_PATH:-}"
LLAMACPP_ALIAS="${LLAMACPP_ALIAS:-}"
LLAMACPP_CTX_SIZE="${LLAMACPP_CTX_SIZE:-}"
LLAMACPP_N_GPU_LAYERS="${LLAMACPP_N_GPU_LAYERS:-999}"
LLAMACPP_THREADS="${LLAMACPP_THREADS:-16}"
LLAMACPP_PARALLEL="${LLAMACPP_PARALLEL:-1}"
LLAMACPP_EXTRA_ARGS="${LLAMACPP_EXTRA_ARGS:-}"

# OpenCode Manager settings
OPENCODE_MANAGER_HOST="${OPENCODE_MANAGER_HOST:-0.0.0.0}"
OPENCODE_MANAGER_PORT="${OPENCODE_MANAGER_PORT:-5003}"
NODE_ENV="${NODE_ENV:-production}"
WORKSPACE_PATH="${WORKSPACE_PATH:-/workspace}"
DATABASE_PATH="${DATABASE_PATH:-/workspace/opencode-manager/data/opencode.db}"
AUTH_TRUSTED_ORIGINS="${AUTH_TRUSTED_ORIGINS:-http://127.0.0.1:${OPENCODE_MANAGER_PORT},http://localhost:${OPENCODE_MANAGER_PORT}}"
AUTH_SECURE_COOKIES="${AUTH_SECURE_COOKIES:-false}"

# OpenCode settings
OPENCODE_HOST="${OPENCODE_HOST:-0.0.0.0}"
OPENCODE_SERVER_PORT="${OPENCODE_SERVER_PORT:-5551}"
OPENCODE_MANAGER_STARTUP_TIMEOUT_SEC="${OPENCODE_MANAGER_STARTUP_TIMEOUT_SEC:-300}"

# OpenClaw settings
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_GATEWAY_HOST="${OPENCLAW_GATEWAY_HOST:-0.0.0.0}"
OPENCLAW_GATEWAY_MODE="${OPENCLAW_GATEWAY_MODE:-token}"
OPENCLAW_GATEWAY_PASSWORD="${OPENCLAW_GATEWAY_PASSWORD:-your-password}"
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-your-token}"
OPENCLAW_STARTUP_TIMEOUT_SEC="${OPENCLAW_STARTUP_TIMEOUT_SEC:-60}"

# OpenClaw Mission Control settings
OPENCLAW_MISSION_CONTROL_PORT="${OPENCLAW_MISSION_CONTROL_PORT:-3000}"
OPENCLAW_MISSION_CONTROL_STARTUP_TIMEOUT_SEC="${OPENCLAW_MISSION_CONTROL_STARTUP_TIMEOUT_SEC:-60}"

# Convex Backend settings
CONVEX_BACKEND_PORT="${CONVEX_BACKEND_PORT:-3210}"
CONVEX_SITE_PORT="${CONVEX_SITE_PORT:-3211}"
CONVEX_DASHBOARD_PORT="${CONVEX_DASHBOARD_PORT:-6791}"
CONVEX_DATA_DIR="${CONVEX_DATA_DIR:-/data/convex}"
CONVEX_INSTANCE_NAME="${CONVEX_INSTANCE_NAME:-mission-control}"

# DingTalk settings
DINGTALK_CLIENT_ID="${DINGTALK_CLIENT_ID:-ding4iqz6zneluw2gyts}"
DINGTALK_CLIENT_SECRET="${DINGTALK_CLIENT_SECRET:-0eUE-rEvcQC1-vyW5e4vxvQDovEH0SHByNGH0vsy1SGirfjwNWG-9VsiPV0mlBrz}"
DINGTALK_ALLOWED_USERS="${DINGTALK_ALLOWED_USERS:-*}"

# Model selection (GGUF) via preset + per-model path env vars.
MODEL_PRESET="${MODEL_PRESET:-${LLAMACPP_MODEL_PRESET:-minimax25}}"
GPU_PROFILE="${GPU_PROFILE:-${LLAMACPP_GPU_PROFILE:-71g}}"
MODEL_PATH_GLM5="${MODEL_PATH_GLM5:-}"
MODEL_PATH_GLM47FLASH="${MODEL_PATH_GLM47FLASH:-}"
MODEL_PATH_MINIMAX25="${MODEL_PATH_MINIMAX25:-}"
MODEL_PATH_KIMI25="${MODEL_PATH_KIMI25:-}"

# Generic model auto-download knobs (recommended for future presets/quantizations)
MODEL_AUTO_DOWNLOAD="${MODEL_AUTO_DOWNLOAD:-false}"
MODEL_DOWNLOAD_URL="${MODEL_DOWNLOAD_URL:-}"
MODEL_DOWNLOAD_URLS="${MODEL_DOWNLOAD_URLS:-}"
MODEL_DOWNLOAD_TOKEN="${MODEL_DOWNLOAD_TOKEN:-${HF_TOKEN:-}}"
MODEL_DOWNLOAD_FALLBACK_ENABLED="${MODEL_DOWNLOAD_FALLBACK_ENABLED:-true}"
HF_MIRROR_BASE="${HF_MIRROR_BASE:-https://hf-mirror.com}"
MODELSCOPE_BASE="${MODELSCOPE_BASE:-https://modelscope.cn}"

# Legacy per-model download knobs (kept for backward compatibility)
AUTO_DOWNLOAD_GLM47FLASH="${AUTO_DOWNLOAD_GLM47FLASH:-false}"
GLM47FLASH_DOWNLOAD_URL="${GLM47FLASH_DOWNLOAD_URL:-}"
GLM47FLASH_DOWNLOAD_TOKEN="${GLM47FLASH_DOWNLOAD_TOKEN:-${HF_TOKEN:-}}"
AUTO_DOWNLOAD_MINIMAX25="${AUTO_DOWNLOAD_MINIMAX25:-false}"
MINIMAX25_DOWNLOAD_URL="${MINIMAX25_DOWNLOAD_URL:-}"
MINIMAX25_DOWNLOAD_URLS="${MINIMAX25_DOWNLOAD_URLS:-}"
MINIMAX25_DOWNLOAD_TOKEN="${MINIMAX25_DOWNLOAD_TOKEN:-${HF_TOKEN:-}}"
# ==================== Model Configuration ====================

if [[ -z "${LLAMACPP_CTX_SIZE}" ]]; then
    case "${GPU_PROFILE}" in
        71g) LLAMACPP_CTX_SIZE="8192" ;;
        35g) LLAMACPP_CTX_SIZE="4096" ;;
        *)   LLAMACPP_CTX_SIZE="8192" ;;
    esac
fi

if [[ -z "${LLAMACPP_MODEL_PATH}" ]]; then
    case "${MODEL_PRESET}" in
        glm5|glm-5)
            LLAMACPP_MODEL_PATH="${MODEL_PATH_GLM5}"
            LLAMACPP_ALIAS="${LLAMACPP_ALIAS:-glm5}"
            ;;
        glm47flash|glm47|glm-4.7-flash|glm-4.7)
            LLAMACPP_MODEL_PATH="${MODEL_PATH_GLM47FLASH}"
            LLAMACPP_ALIAS="${LLAMACPP_ALIAS:-glm47flash}"
            ;;
        minimax25|minimax-2.5|minimax2.5)
            LLAMACPP_MODEL_PATH="${MODEL_PATH_MINIMAX25:-/models/downloads/minimax25/minimax2.5.gguf}"
            LLAMACPP_ALIAS="${LLAMACPP_ALIAS:-minimax25}"
            ;;
        kimi25|kimi-2.5|kimi2.5)
            LLAMACPP_MODEL_PATH="${MODEL_PATH_KIMI25}"
            LLAMACPP_ALIAS="${LLAMACPP_ALIAS:-kimi25}"
            ;;
        *)
            echo "ERROR: Unknown MODEL_PRESET='${MODEL_PRESET}'. Supported: glm5, glm47flash, minimax25, kimi25" >&2
            exit 1
            ;;
    esac
fi

if [[ -z "${LLAMACPP_ALIAS}" ]]; then
    LLAMACPP_ALIAS="model"
fi

build_download_candidates() {
    local url="$1"
    local -a out=()
    local stripped="${url#https://}"
    stripped="${stripped#http://}"

    # Priority for HF links: 1) ModelScope 2) HF mirror 3) HF origin
    if [[ "${MODEL_DOWNLOAD_FALLBACK_ENABLED}" == "true" && "${stripped}" == huggingface.co/* ]]; then
        local path="${stripped#huggingface.co/}"  # <repo>/resolve/<rev>/<file...>
        out+=("${MODELSCOPE_BASE}/models/${path}")
        out+=("${HF_MIRROR_BASE}/${path}")
        out+=("${url}")
    else
        out+=("${url}")
    fi

    printf '%s\n' "${out[@]}"
}

download_to_file() {
    local url="$1"
    local dst="$2"
    local token="${3:-}"
    local tmp="${dst}.part"
    local tried=0
    while IFS= read -r candidate; do
        [[ -z "${candidate}" ]] && continue
        tried=$((tried + 1))
        echo "[INFO] Download attempt ${tried}: ${candidate}"
        if [[ -n "${token}" ]]; then
            if curl -L --fail --retry 5 --retry-delay 5 -C - \
              -H "Authorization: Bearer ${token}" \
              -o "${tmp}" "${candidate}"; then
                mv -f "${tmp}" "${dst}"
                return 0
            fi
        else
            if curl -L --fail --retry 5 --retry-delay 5 -C - \
              -o "${tmp}" "${candidate}"; then
                mv -f "${tmp}" "${dst}"
                return 0
            fi
        fi
        rm -f "${tmp}" || true
    done < <(build_download_candidates "${url}")

    echo "ERROR: Failed to download model from all candidate sources for: ${url}" >&2
    return 1
}

# Backward-compatible mapping: old model-specific knobs -> generic knobs.
if [[ "${MODEL_AUTO_DOWNLOAD}" != "true" && -z "${MODEL_DOWNLOAD_URL}" && -z "${MODEL_DOWNLOAD_URLS}" ]]; then
    if [[ "${MODEL_PRESET}" == "glm47flash" || "${MODEL_PRESET}" == "glm47" || "${MODEL_PRESET}" == "glm-4.7-flash" || "${MODEL_PRESET}" == "glm-4.7" ]]; then
        if [[ "${AUTO_DOWNLOAD_GLM47FLASH}" == "true" ]]; then
            MODEL_AUTO_DOWNLOAD="true"
            MODEL_DOWNLOAD_URL="${GLM47FLASH_DOWNLOAD_URL}"
            MODEL_DOWNLOAD_TOKEN="${GLM47FLASH_DOWNLOAD_TOKEN}"
        fi
    elif [[ "${MODEL_PRESET}" == "minimax25" || "${MODEL_PRESET}" == "minimax-2.5" || "${MODEL_PRESET}" == "minimax2.5" ]]; then
        if [[ "${AUTO_DOWNLOAD_MINIMAX25}" == "true" ]]; then
            MODEL_AUTO_DOWNLOAD="true"
            MODEL_DOWNLOAD_URL="${MINIMAX25_DOWNLOAD_URL}"
            MODEL_DOWNLOAD_URLS="${MINIMAX25_DOWNLOAD_URLS}"
            MODEL_DOWNLOAD_TOKEN="${MINIMAX25_DOWNLOAD_TOKEN}"
        fi
    fi
fi

# Generic auto-download for any preset/quantization:
# - single file: MODEL_DOWNLOAD_URL -> LLAMACPP_MODEL_PATH
# - split files: MODEL_DOWNLOAD_URLS (comma-separated) -> dirname(LLAMACPP_MODEL_PATH)
if [[ "${MODEL_AUTO_DOWNLOAD}" == "true" ]]; then
    if [[ -z "${MODEL_DOWNLOAD_URL}" && -z "${MODEL_DOWNLOAD_URLS}" ]]; then
        echo "ERROR: MODEL_AUTO_DOWNLOAD=true but MODEL_DOWNLOAD_URL / MODEL_DOWNLOAD_URLS not set." >&2
        exit 1
    fi

    mkdir -p "$(dirname "${LLAMACPP_MODEL_PATH}")"
    model_dir="$(dirname "${LLAMACPP_MODEL_PATH}")"

    if [[ -n "${MODEL_DOWNLOAD_URLS}" ]]; then
        IFS=',' read -r -a url_arr <<< "${MODEL_DOWNLOAD_URLS}"
        missing="false"
        for url in "${url_arr[@]}"; do
            clean_url="$(echo "${url}" | xargs)"
            [[ -z "${clean_url}" ]] && continue
            filename="$(basename "${clean_url%%\?*}")"
            target="${model_dir}/${filename}"
            if [[ ! -f "${target}" ]]; then
                missing="true"
                break
            fi
        done
        if [[ "${missing}" != "true" ]]; then
            echo "[INFO] Model shards already present in ${model_dir}, skip download."
        fi

        for url in "${url_arr[@]}"; do
            clean_url="$(echo "${url}" | xargs)"
            [[ -z "${clean_url}" ]] && continue
            filename="$(basename "${clean_url%%\?*}")"
            target="${model_dir}/${filename}"
            if [[ -f "${target}" ]]; then
                echo "[INFO] Shard exists, skip: ${filename}"
                continue
            fi
            echo "[INFO] Downloading shard: ${filename}"
            download_to_file "${clean_url}" "${target}" "${MODEL_DOWNLOAD_TOKEN}"
        done
        echo "[INFO] Model shards prepared in ${model_dir}"
    else
        if [[ -f "${LLAMACPP_MODEL_PATH}" ]]; then
            echo "[INFO] Model already present: ${LLAMACPP_MODEL_PATH}, skip download."
        else
            echo "[INFO] Model not found, downloading: ${LLAMACPP_MODEL_PATH}"
            download_to_file "${MODEL_DOWNLOAD_URL}" "${LLAMACPP_MODEL_PATH}" "${MODEL_DOWNLOAD_TOKEN}"
            echo "[INFO] Model downloaded to ${LLAMACPP_MODEL_PATH}"
        fi
    fi
fi

# ==================== Validation ====================

if [[ -z "${LLAMACPP_MODEL_PATH}" ]]; then
    echo "ERROR: No model selected." >&2
    echo "Set either LLAMACPP_MODEL_PATH directly, or set MODEL_PRESET + corresponding MODEL_PATH_*." >&2
    echo "Examples:" >&2
    echo "  MODEL_PRESET=glm47flash MODEL_PATH_GLM47FLASH=/models/<your-glm47flash>.gguf" >&2
    echo "  MODEL_PRESET=glm5 MODEL_PATH_GLM5=/models/<your-glm5>.gguf" >&2
    exit 1
fi

if [[ ! -f "${LLAMACPP_MODEL_PATH}" ]]; then
    echo "ERROR: GGUF model not found: ${LLAMACPP_MODEL_PATH}" >&2
    echo "Check your /models mount and MODEL_PATH_* / LLAMACPP_MODEL_PATH settings." >&2
    exit 1
fi

if [[ -z "${AUTH_SECRET:-}" ]]; then
    AUTH_SECRET="$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
    export AUTH_SECRET
    echo "[INFO] AUTH_SECRET not set, generated an ephemeral secret."
fi

# ==================== Setup OpenClaw Config ====================

echo "[INFO] Setting up OpenClaw configuration..."

# Force remove existing config to avoid stale data
rm -rf /root/.openclaw/* 2>/dev/null || true

mkdir -p /root/.openclaw/agents/main/agent

# Update OpenClaw config with environment variables
cat > /root/.openclaw/openclaw.json << EOF
{
  "models": {
    "mode": "merge",
    "providers": {
      "minimax": {
        "baseUrl": "https://comfyui-nn-h200-136-71g-3.bytebroad.com",
        "api": "openai-completions",
        "models": [{
          "id": "minimax25",
          "name": "MiniMax 2.5",
          "reasoning": true,
          "input": ["text", "image"],
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
          "contextWindow": 128000,
          "maxTokens": 8192
        }]
      },
      "local": {
        "baseUrl": "http://127.0.0.1:${LLAMACPP_PORT}",
        "api": "openai-completions",
        "models": [{
          "id": "llama-local",
          "name": "Local LLaMA",
          "reasoning": false,
          "input": ["text"],
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
          "contextWindow": ${LLAMACPP_CTX_SIZE},
          "maxTokens": 8192
        }]
      }
    }
  },
  "agents": {
    "defaults": {
      "workspace": "~/.openclaw/workspace",
      "model": { "primary": "minimax/minimax25" }
    }
  },
  "gateway": {
    "port": ${OPENCLAW_GATEWAY_PORT},
    "mode": "local",
    "bind": "auto",
    "auth": {
      "mode": "${OPENCLAW_GATEWAY_MODE:-token}",
      "token": "${OPENCLAW_GATEWAY_TOKEN:-your-token}"
    },
    "controlUi": {
      "dangerouslyAllowHostHeaderOriginFallback": true
    }
  }
}
EOF

cat > /root/.openclaw/agents/main/agent/auth-profiles.json << EOF
{
  "version": 1,
  "profiles": {
    "minimax": {
      "type": "api_key",
      "provider": "minimax",
      "key": "no-key-required"
    },
    "local": {
      "type": "api_key",
      "provider": "local",
      "key": "no-key-required"
    }
  }
}
EOF

chmod -R 755 /root/.openclaw

# ==================== Cleanup Function ====================

cleanup() {
    local code=$?
    echo "[INFO] Cleaning up services..."
    if [[ -n "${PID_MC_FRONTEND:-}" ]]; then kill "${PID_MC_FRONTEND}" 2>/dev/null || true; fi
    if [[ -n "${PID_MC_BACKEND:-}" ]]; then kill "${PID_MC_BACKEND}" 2>/dev/null || true; fi
    if [[ -n "${PID_CONVEX:-}" ]]; then kill "${PID_CONVEX}" 2>/dev/null || true; fi
    if [[ -n "${PID_OPENCLAW_GATEWAY:-}" ]]; then kill "${PID_OPENCLAW_GATEWAY}" 2>/dev/null || true; fi
    if [[ -n "${PID_MANAGER:-}" ]]; then kill "${PID_MANAGER}" 2>/dev/null || true; fi
    if [[ -n "${PID_LLAMA:-}" ]]; then kill "${PID_LLAMA}" 2>/dev/null || true; fi
    wait || true
    exit "${code}"
}
trap cleanup EXIT INT TERM

# ==================== Start Services ====================

# Export environment variables for OpenCode Manager
export HOST="${OPENCODE_MANAGER_HOST}"
export PORT="${OPENCODE_MANAGER_PORT}"
export NODE_ENV
export WORKSPACE_PATH
export DATABASE_PATH
export AUTH_TRUSTED_ORIGINS
export AUTH_SECURE_COOKIES
export OPENCODE_HOST
export OPENCODE_SERVER_PORT
mkdir -p "$(dirname "${DATABASE_PATH}")"

# Start OpenCode Manager
echo "[INFO] Starting OpenCode Manager on ${OPENCODE_MANAGER_HOST}:${OPENCODE_MANAGER_PORT}"
cd /opt/opencode-manager
bun backend/src/index.ts &
PID_MANAGER=$!

# Wait for OpenCode Manager to be ready
ready=0
start_ts="$(date +%s)"
while true; do
    # Newer manager builds may protect /api/health behind auth and return 401.
    # Treat 200/401/403 as "HTTP stack is up".
    http_code="$(curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:${OPENCODE_MANAGER_PORT}/api/health" || true)"
    if [[ "${http_code}" == "200" || "${http_code}" == "401" || "${http_code}" == "403" ]]; then
        ready=1
        break
    fi

    # Fail fast if manager process already exited.
    if ! kill -0 "${PID_MANAGER}" 2>/dev/null; then
        echo "ERROR: OpenCode Manager process exited before becoming ready." >&2
        exit 1
    fi

    now_ts="$(date +%s)"
    elapsed=$((now_ts - start_ts))
    if (( elapsed >= OPENCODE_MANAGER_STARTUP_TIMEOUT_SEC )); then
        echo "ERROR: OpenCode Manager did not become ready within ${OPENCODE_MANAGER_STARTUP_TIMEOUT_SEC}s (last /api/health code: ${http_code})." >&2
        exit 1
    fi

    echo "[INFO] Waiting for OpenCode Manager API to start... (last /api/health code: ${http_code:-n/a})"
    sleep 2
done

if [[ "${ready}" != "1" ]]; then
    echo "ERROR: OpenCode Manager startup check ended unexpectedly." >&2
    exit 1
fi
echo "[INFO] OpenCode Manager ready: http://127.0.0.1:${OPENCODE_MANAGER_PORT}"

# Start OpenClaw Gateway
echo "[INFO] Starting OpenClaw Gateway on port ${OPENCLAW_GATEWAY_PORT}"
# Add control UI configuration for non-loopback binding
export OPENCLAW_CONTROL_UI_DANGEROUSLY_ALLOW_HOST_HEADER_ORIGIN_FALLBACK="true"
openclaw gateway run --port "${OPENCLAW_GATEWAY_PORT}" --bind lan --auth password --password "${OPENCLAW_GATEWAY_PASSWORD}" &
PID_OPENCLAW_GATEWAY=$!  
  
# Wait for Gateway to be ready  
openclaw_ready=0  
start_ts="$(date +%s)"  
while true; do  
    # 直接检查 TCP 端口是否可连接（绕过认证问题）
    if timeout 2 bash -c "exec 3<>/dev/tcp/127.0.0.1/${OPENCLAW_GATEWAY_PORT} && echo -e 'GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n' >&3 && timeout 1 cat <&3 | grep -q '200\|101'" 2>/dev/null; then
        openclaw_ready=1
        break
    fi
    
    # 备选：简单的端口监听检查
    if ss -tln | grep -q "LISTEN.*:${OPENCLAW_GATEWAY_PORT}"; then
        # 端口在监听，再等 2 秒让服务完全初始化
        sleep 2
        openclaw_ready=1
        break
    fi
      
    if ! kill -0 "${PID_OPENCLAW_GATEWAY}" 2>/dev/null; then
        echo "WARN: OpenClaw Gateway process exited before becoming ready. Continuing without Gateway..." >&2
        PID_OPENCLAW_GATEWAY=""
        break
    fi

    now_ts="$(date +%s)"
    elapsed=$((now_ts - start_ts))
    if (( elapsed >= OPENCLAW_STARTUP_TIMEOUT_SEC )); then
        echo "WARN: OpenClaw Gateway did not become ready within ${OPENCLAW_STARTUP_TIMEOUT_SEC}s. Continuing without Gateway..." >&2
        if [[ -n "${PID_OPENCLAW_GATEWAY}" ]]; then
            kill "${PID_OPENCLAW_GATEWAY}" 2>/dev/null || true
        fi
        PID_OPENCLAW_GATEWAY=""
        break
    fi  
      
    echo "[INFO] Waiting for OpenClaw Gateway to start..."
    sleep 2
done

if [[ -n "${PID_OPENCLAW_GATEWAY}" ]] && kill -0 "${PID_OPENCLAW_GATEWAY}" 2>/dev/null; then
    echo "[INFO] OpenClaw Gateway ready: ws://127.0.0.1:${OPENCLAW_GATEWAY_PORT}"
else
    echo "[WARN] OpenClaw Gateway not available, continuing without it..."
    PID_OPENCLAW_GATEWAY=""
fi

# Start Convex Backend (self-hosted)
echo "[INFO] Starting Convex Backend on port ${CONVEX_BACKEND_PORT}"
mkdir -p "${CONVEX_DATA_DIR}"
cd /opt/convex-backend
./convex-local-backend \
  --port "${CONVEX_BACKEND_PORT}" \
  --site-proxy-port "${CONVEX_SITE_PORT}" \
  --instance-name "${CONVEX_INSTANCE_NAME}" \
  --local-storage "${CONVEX_DATA_DIR}" &
PID_CONVEX=$!

# Wait for Convex Backend to be ready
convex_ready=0
start_ts="$(date +%s)"
while true; do
    if curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:${CONVEX_BACKEND_PORT}/version" 2>/dev/null | grep -q "200"; then
        convex_ready=1
        break
    fi

    if ! kill -0 "${PID_CONVEX}" 2>/dev/null; then
        echo "ERROR: Convex Backend process exited before becoming ready." >&2
        exit 1
    fi

    now_ts="$(date +%s)"
    elapsed=$((now_ts - start_ts))
    if (( elapsed >= 30 )); then
        echo "ERROR: Convex Backend did not become ready within 30s." >&2
        exit 1
    fi

    echo "[INFO] Waiting for Convex Backend to start..."
    sleep 2
done

if [[ "${convex_ready}" != "1" ]]; then
    echo "ERROR: Convex Backend startup check ended unexpectedly." >&2
    exit 1
fi
echo "[INFO] Convex Backend ready: http://127.0.0.1:${CONVEX_BACKEND_PORT}"
# Note: Dashboard is served at the same port as the backend for convex-local-backend

# Generate admin key for Convex
# Note: convex-local-backend generates a deterministic key based on instance name
# For development, we use a fixed admin key pattern
ADMIN_KEY="convex-self-hosted-admin-key:${CONVEX_INSTANCE_NAME}"
echo "[INFO] Convex admin key generated for instance: ${CONVEX_INSTANCE_NAME}"

# Start OpenClaw Mission Control
echo "[INFO] Starting OpenClaw Mission Control on port ${OPENCLAW_MISSION_CONTROL_PORT}"
cd /opt/openclaw-mission-control

# Set Convex self-hosted configuration
export CONVEX_SELF_HOSTED_URL="http://127.0.0.1:${CONVEX_BACKEND_PORT}"
export CONVEX_SELF_HOSTED_ADMIN_KEY="${ADMIN_KEY}"

# Initialize Convex schema if convex folder exists
if [ -d "convex" ]; then
    echo "[INFO] Initializing Convex schema..."
    npx convex dev --once --url "${CONVEX_SELF_HOSTED_URL}" --admin-key "${ADMIN_KEY}" 2>/dev/null || {
        echo "[WARN] Convex schema initialization failed, continuing anyway..."
    }
fi

# Start frontend server
# Check if built output exists
if [ -d ".next" ] || [ -d "dist" ]; then
    echo "[INFO] Starting Mission Control frontend..."
    pnpm preview --port "${OPENCLAW_MISSION_CONTROL_PORT}" --host 0.0.0.0 &
    PID_MC_FRONTEND=$!
else
    echo "[WARN] Mission Control not built, attempting to start dev server..."
    pnpm dev --port "${OPENCLAW_MISSION_CONTROL_PORT}" --host 0.0.0.0 &
    PID_MC_FRONTEND=$!
fi

# Wait for Mission Control to be ready
mc_ready=0
start_ts="$(date +%s)"
while true; do
    http_code="$(curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:${OPENCLAW_MISSION_CONTROL_PORT}" 2>/dev/null || echo "000")"
    if [[ "${http_code}" == "200" || "${http_code}" == "304" ]]; then
        mc_ready=1
        break
    fi

    if ! kill -0 "${PID_MC_FRONTEND}" 2>/dev/null; then
        echo "WARN: Mission Control frontend process exited before becoming ready." >&2
        break
    fi

    now_ts="$(date +%s)"
    elapsed=$((now_ts - start_ts))
    if (( elapsed >= OPENCLAW_MISSION_CONTROL_STARTUP_TIMEOUT_SEC )); then
        echo "WARN: Mission Control did not become ready within ${OPENCLAW_MISSION_CONTROL_STARTUP_TIMEOUT_SEC}s." >&2
        break
    fi

    echo "[INFO] Waiting for Mission Control to start... (last HTTP code: ${http_code})"
    sleep 2
done

if [[ "${mc_ready}" == "1" ]]; then
    echo "[INFO] Mission Control ready: http://127.0.0.1:${OPENCLAW_MISSION_CONTROL_PORT}"
else
    echo "[WARN] Mission Control startup incomplete, but continuing..."
fi

PID_MC_BACKEND=""

# Start llama-server
echo "[INFO] Starting llama-server on ${LLAMACPP_HOST}:${LLAMACPP_PORT}"
LLAMACPP_BIN="${LLAMACPP_BIN:-}"
if [[ -z "${LLAMACPP_BIN}" ]]; then
    if command -v llama-server >/dev/null 2>&1; then
        LLAMACPP_BIN="llama-server"
    elif [[ -x "/app/llama-server" ]]; then
        LLAMACPP_BIN="/app/llama-server"
    elif [[ -x "/opt/llama/bin/llama-server" ]]; then
        LLAMACPP_BIN="/opt/llama/bin/llama-server"
    else
        echo "ERROR: llama-server not found in PATH, /app, or /opt/llama/bin" >&2
        exit 1
    fi
fi
CMD=(
  "${LLAMACPP_BIN}"
  --host "${LLAMACPP_HOST}"
  --port "${LLAMACPP_PORT}"
  --model "${LLAMACPP_MODEL_PATH}"
  --alias "${LLAMACPP_ALIAS}"
  --ctx-size "${LLAMACPP_CTX_SIZE}"
  --n-gpu-layers "${LLAMACPP_N_GPU_LAYERS}"
  --threads "${LLAMACPP_THREADS}"
  --parallel "${LLAMACPP_PARALLEL}"
  --jinja
)
if [[ -n "${LLAMACPP_EXTRA_ARGS}" ]]; then
    # shellcheck disable=SC2206
    EXTRA=(${LLAMACPP_EXTRA_ARGS})
    CMD+=("${EXTRA[@]}")
fi
"${CMD[@]}" &
PID_LLAMA=$!

echo "[INFO] =========================================="
echo "[INFO] All services started successfully!"
echo "[INFO] =========================================="
echo "[INFO] llama.cpp Server:     http://127.0.0.1:${LLAMACPP_PORT}"
echo "[INFO] OpenCode Manager:     http://127.0.0.1:${OPENCODE_MANAGER_PORT}"
echo "[INFO] Opencode Server:      http://127.0.0.1:${OPENCODE_SERVER_PORT}"
echo "[INFO] OpenClaw Gateway:     http://127.0.0.1:${OPENCLAW_GATEWAY_PORT}"
echo "[INFO] Convex Backend:       http://127.0.0.1:${CONVEX_BACKEND_PORT}"
if [[ -n "${PID_MC_FRONTEND}" ]] && kill -0 "${PID_MC_FRONTEND}" 2>/dev/null; then
    echo "[INFO] Mission Control:      http://127.0.0.1:${OPENCLAW_MISSION_CONTROL_PORT}"
fi
echo "[INFO] =========================================="

# Wait for any process to exit
wait -n "${PID_MANAGER}" "${PID_LLAMA}" "${PID_OPENCLAW_GATEWAY}" "${PID_CONVEX}" "${PID_MC_FRONTEND}"