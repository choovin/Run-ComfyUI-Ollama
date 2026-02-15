#!/bin/bash
set -euo pipefail

echo "[INFO] Starting services: llama.cpp + OpenCode Manager"

LLAMACPP_HOST="${LLAMACPP_HOST:-0.0.0.0}"
LLAMACPP_PORT="${LLAMACPP_PORT:-8080}"
LLAMACPP_MODEL_PATH="${LLAMACPP_MODEL_PATH:-/models/glm-4.7-flash-q4_k_m.gguf}"
LLAMACPP_ALIAS="${LLAMACPP_ALIAS:-glm47flash}"
LLAMACPP_CTX_SIZE="${LLAMACPP_CTX_SIZE:-8192}"
LLAMACPP_N_GPU_LAYERS="${LLAMACPP_N_GPU_LAYERS:-999}"
LLAMACPP_THREADS="${LLAMACPP_THREADS:-16}"
LLAMACPP_PARALLEL="${LLAMACPP_PARALLEL:-1}"
LLAMACPP_EXTRA_ARGS="${LLAMACPP_EXTRA_ARGS:-}"

OPENCODE_MANAGER_HOST="${OPENCODE_MANAGER_HOST:-0.0.0.0}"
OPENCODE_MANAGER_PORT="${OPENCODE_MANAGER_PORT:-5003}"
NODE_ENV="${NODE_ENV:-production}"
WORKSPACE_PATH="${WORKSPACE_PATH:-/workspace}"
DATABASE_PATH="${DATABASE_PATH:-/workspace/opencode-manager/data/opencode.db}"
AUTH_TRUSTED_ORIGINS="${AUTH_TRUSTED_ORIGINS:-http://127.0.0.1:${OPENCODE_MANAGER_PORT},http://localhost:${OPENCODE_MANAGER_PORT}}"
AUTH_SECURE_COOKIES="${AUTH_SECURE_COOKIES:-false}"

if [[ ! -f "${LLAMACPP_MODEL_PATH}" ]]; then
    echo "ERROR: GGUF model not found: ${LLAMACPP_MODEL_PATH}" >&2
    echo "Set LLAMACPP_MODEL_PATH to your GLM-4.7-Flash quantized GGUF file path." >&2
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
CMD=(
  llama-server
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
