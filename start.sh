#!/bin/bash
set -euo pipefail

echo "[INFO] Starting services: llama.cpp + OpenCode Manager"

# Ensure llama.cpp runtime shared libraries can be resolved.
# Some upstream images place llama-server and its .so files under /app.
export LD_LIBRARY_PATH="/app:/opt/llama/bin:/usr/local/lib:${LD_LIBRARY_PATH:-}"
export PATH="/app:/opt/llama/bin:${PATH}"

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

OPENCODE_HOST="${OPENCODE_HOST:-127.0.0.1}"
OPENCODE_SERVER_PORT="${OPENCODE_SERVER_PORT:-5551}"

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
export OPENCODE_HOST
export OPENCODE_SERVER_PORT
mkdir -p "$(dirname "${DATABASE_PATH}")"

cleanup() {
    local code=$?
    if [[ -n "${PID_MANAGER:-}" ]]; then kill "${PID_MANAGER}" 2>/dev/null || true; fi
    if [[ -n "${PID_OPENCODE:-}" ]]; then kill "${PID_OPENCODE}" 2>/dev/null || true; fi
    if [[ -n "${PID_LLAMA:-}" ]]; then kill "${PID_LLAMA}" 2>/dev/null || true; fi
    wait || true
    exit "${code}"
}
trap cleanup EXIT INT TERM

echo "[INFO] Prestarting OpenCode server on ${OPENCODE_HOST}:${OPENCODE_SERVER_PORT} (so manager won't hit 30s health timeout)"
if ! command -v opencode >/dev/null 2>&1; then
    echo "ERROR: opencode binary not found in PATH: ${PATH}" >&2
    exit 1
fi
echo "[INFO] OpenCode version output:"
opencode --version || true

mkdir -p "${WORKSPACE_PATH}/.config/opencode" "${WORKSPACE_PATH}/.opencode/state"
export XDG_DATA_HOME="${WORKSPACE_PATH}/.opencode/state"
export XDG_CONFIG_HOME="${WORKSPACE_PATH}/.config"
export OPENCODE_CONFIG="${WORKSPACE_PATH}/.config/opencode/opencode.json"

OPENCODE_LOG="/tmp/opencode-serve.log"
cd "${WORKSPACE_PATH}"
opencode serve --port "${OPENCODE_SERVER_PORT}" --hostname "${OPENCODE_HOST}" >"${OPENCODE_LOG}" 2>&1 &
PID_OPENCODE=$!

deadline=$((SECONDS+180))
until curl -fsS "http://${OPENCODE_HOST}:${OPENCODE_SERVER_PORT}/doc" >/dev/null 2>&1; do
    if (( SECONDS > deadline )); then
        echo "ERROR: opencode did not become healthy within 180s: http://${OPENCODE_HOST}:${OPENCODE_SERVER_PORT}/doc" >&2
        echo "Last 200 lines of ${OPENCODE_LOG}:" >&2
        tail -n 200 "${OPENCODE_LOG}" >&2 || true
        exit 1
    fi
    sleep 2
done
echo "[INFO] OpenCode server is responding: http://${OPENCODE_HOST}:${OPENCODE_SERVER_PORT}/doc"

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
