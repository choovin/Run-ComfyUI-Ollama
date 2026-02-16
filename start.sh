#!/bin/bash
set -euo pipefail

echo "[INFO] Starting services: llama.cpp + OpenCode Manager"

# Ensure llama.cpp runtime shared libraries can be resolved.
# Some upstream images place llama-server and its .so files under /app.
export LD_LIBRARY_PATH="/app:/opt/llama/bin:/usr/local/lib:${LD_LIBRARY_PATH:-}"
export PATH="/app:/opt/llama/bin:${PATH}"

LLAMACPP_HOST="${LLAMACPP_HOST:-0.0.0.0}"
LLAMACPP_PORT="${LLAMACPP_PORT:-8080}"
LLAMACPP_MODEL_PATH="${LLAMACPP_MODEL_PATH:-}"
LLAMACPP_ALIAS="${LLAMACPP_ALIAS:-}"
LLAMACPP_CTX_SIZE="${LLAMACPP_CTX_SIZE:-}"
LLAMACPP_N_GPU_LAYERS="${LLAMACPP_N_GPU_LAYERS:-999}"
LLAMACPP_THREADS="${LLAMACPP_THREADS:-16}"
LLAMACPP_PARALLEL="${LLAMACPP_PARALLEL:-1}"
LLAMACPP_EXTRA_ARGS="${LLAMACPP_EXTRA_ARGS:-}"

# Model selection (GGUF) via preset + per-model path env vars.
# If LLAMACPP_MODEL_PATH is set, it always wins.
MODEL_PRESET="${MODEL_PRESET:-${LLAMACPP_MODEL_PRESET:-glm47flash}}"
GPU_PROFILE="${GPU_PROFILE:-${LLAMACPP_GPU_PROFILE:-71g}}" # "71g" or "35g" (used only for defaults)
MODEL_PATH_GLM5="${MODEL_PATH_GLM5:-}"
MODEL_PATH_GLM47FLASH="${MODEL_PATH_GLM47FLASH:-}"
MODEL_PATH_MINIMAX25="${MODEL_PATH_MINIMAX25:-}"
MODEL_PATH_KIMI25="${MODEL_PATH_KIMI25:-}"
AUTO_DOWNLOAD_MINIMAX25="${AUTO_DOWNLOAD_MINIMAX25:-false}"
MINIMAX25_DOWNLOAD_URL="${MINIMAX25_DOWNLOAD_URL:-}"
MINIMAX25_DOWNLOAD_URLS="${MINIMAX25_DOWNLOAD_URLS:-}"
MINIMAX25_DOWNLOAD_TOKEN="${MINIMAX25_DOWNLOAD_TOKEN:-${HF_TOKEN:-}}"

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

# Optional: auto-download minimax2.5 GGUF on first boot.
# For split GGUF, we verify all shards and download missing ones.
if [[ "${MODEL_PRESET}" == "minimax25" || "${MODEL_PRESET}" == "minimax-2.5" || "${MODEL_PRESET}" == "minimax2.5" ]]; then
    if [[ "${AUTO_DOWNLOAD_MINIMAX25}" == "true" ]]; then
        if [[ -z "${MINIMAX25_DOWNLOAD_URL}" ]]; then
            if [[ -z "${MINIMAX25_DOWNLOAD_URLS}" ]]; then
                echo "ERROR: MINIMAX25 model missing and MINIMAX25_DOWNLOAD_URL / MINIMAX25_DOWNLOAD_URLS are not set." >&2
                exit 1
            fi
        fi

        mkdir -p "$(dirname "${LLAMACPP_MODEL_PATH}")"
        MODEL_DIR="$(dirname "${LLAMACPP_MODEL_PATH}")"

        if [[ -n "${MINIMAX25_DOWNLOAD_URLS}" ]]; then
            IFS=',' read -r -a URL_ARR <<< "${MINIMAX25_DOWNLOAD_URLS}"
            needs_download="false"
            for url in "${URL_ARR[@]}"; do
                clean_url="$(echo "${url}" | xargs)"
                [[ -z "${clean_url}" ]] && continue
                filename="$(basename "${clean_url%%\?*}")"
                target_path="${MODEL_DIR}/${filename}"
                if [[ ! -f "${target_path}" ]]; then
                    needs_download="true"
                    break
                fi
            done

            if [[ "${needs_download}" != "true" ]]; then
                echo "[INFO] MiniMax2.5 GGUF shards already present in ${MODEL_DIR}, skip download."
            fi

            for url in "${URL_ARR[@]}"; do
                clean_url="$(echo "${url}" | xargs)"
                [[ -z "${clean_url}" ]] && continue

                filename="$(basename "${clean_url%%\?*}")"
                target_path="${MODEL_DIR}/${filename}"
                tmp_path="${target_path}.part"

                if [[ -f "${target_path}" ]]; then
                    echo "[INFO] Shard exists, skip: ${filename}"
                    continue
                fi

                echo "[INFO] Downloading shard: ${filename}"
                if [[ -n "${MINIMAX25_DOWNLOAD_TOKEN}" ]]; then
                    curl -L --fail --retry 5 --retry-delay 5 -C - \
                      -H "Authorization: Bearer ${MINIMAX25_DOWNLOAD_TOKEN}" \
                      -o "${tmp_path}" "${clean_url}"
                else
                    curl -L --fail --retry 5 --retry-delay 5 -C - \
                      -o "${tmp_path}" "${clean_url}"
                fi
                mv -f "${tmp_path}" "${target_path}"
            done
            echo "[INFO] MiniMax2.5 GGUF shards downloaded to ${MODEL_DIR}"
        else
            if [[ -f "${LLAMACPP_MODEL_PATH}" ]]; then
                echo "[INFO] MiniMax2.5 GGUF already present: ${LLAMACPP_MODEL_PATH}, skip download."
            fi
            TMP_PATH="${LLAMACPP_MODEL_PATH}.part"
            if [[ ! -f "${LLAMACPP_MODEL_PATH}" ]]; then
                echo "[INFO] MiniMax2.5 GGUF not found, downloading first-time model..."
                if [[ -n "${MINIMAX25_DOWNLOAD_TOKEN}" ]]; then
                    curl -L --fail --retry 5 --retry-delay 5 -C - \
                      -H "Authorization: Bearer ${MINIMAX25_DOWNLOAD_TOKEN}" \
                      -o "${TMP_PATH}" "${MINIMAX25_DOWNLOAD_URL}"
                else
                    curl -L --fail --retry 5 --retry-delay 5 -C - \
                      -o "${TMP_PATH}" "${MINIMAX25_DOWNLOAD_URL}"
                fi
                mv -f "${TMP_PATH}" "${LLAMACPP_MODEL_PATH}"
                echo "[INFO] MiniMax2.5 GGUF downloaded to ${LLAMACPP_MODEL_PATH}"
            fi
        fi
    fi
fi

OPENCODE_MANAGER_HOST="${OPENCODE_MANAGER_HOST:-0.0.0.0}"
OPENCODE_MANAGER_PORT="${OPENCODE_MANAGER_PORT:-5003}"
NODE_ENV="${NODE_ENV:-production}"
WORKSPACE_PATH="${WORKSPACE_PATH:-/workspace}"
DATABASE_PATH="${DATABASE_PATH:-/workspace/opencode-manager/data/opencode.db}"
AUTH_TRUSTED_ORIGINS="${AUTH_TRUSTED_ORIGINS:-http://127.0.0.1:${OPENCODE_MANAGER_PORT},http://localhost:${OPENCODE_MANAGER_PORT}}"
AUTH_SECURE_COOKIES="${AUTH_SECURE_COOKIES:-false}"

OPENCODE_HOST="${OPENCODE_HOST:-0.0.0.0}"
OPENCODE_SERVER_PORT="${OPENCODE_SERVER_PORT:-5551}"

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

cleanup() {
    local code=$?
    if [[ -n "${PID_MANAGER:-}" ]]; then kill "${PID_MANAGER}" 2>/dev/null || true; fi
    if [[ -n "${PID_LLAMA:-}" ]]; then kill "${PID_LLAMA}" 2>/dev/null || true; fi
    wait || true
    exit "${code}"
}
trap cleanup EXIT INT TERM

echo "[INFO] Starting OpenCode Manager on ${OPENCODE_MANAGER_HOST}:${OPENCODE_MANAGER_PORT}"
cd /opt/opencode-manager
bun backend/src/index.ts &
PID_MANAGER=$!
until curl -fsS "http://127.0.0.1:${OPENCODE_MANAGER_PORT}/api/health" > /dev/null; do
    echo "[INFO] Waiting for OpenCode Manager API to start..."
    sleep 2
done
echo "[INFO] OpenCode Manager ready: http://127.0.0.1:${OPENCODE_MANAGER_PORT}"

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

wait -n "${PID_MANAGER}" "${PID_LLAMA}"
