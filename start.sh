#!/bin/bash

echo "[INFO] Pod run-comfyui-ollama started"

# ssh scp ftp on (TCP port 22)

if [[ $PUBLIC_KEY ]]
then
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    cd ~/.ssh
    echo $PUBLIC_KEY >> authorized_keys
    chmod 700 -R ~/.ssh
    cd /
    service ssh start
fi

# Move necessary files to workspace
for script in comfyui-on-workspace.sh provisioning-on-workspace.sh gradio-on-workspace.sh readme-on-workspace.sh; do
    if [ -f "/$script" ]; then
        echo "Executing $script..."
        "/$script"
    else
        echo "⚠️ WARNING: Skipping $script (not found)"
    fi
done

# GPU detection
HAS_GPU=0
if [[ -n "${RUNPOD_GPU_COUNT:-}" && "${RUNPOD_GPU_COUNT:-0}" -gt 0 ]]; then
  HAS_GPU=1
elif command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi >/dev/null 2>&1 && HAS_GPU=1 || true
elif [[ -n "${CUDA_VISIBLE_DEVICES:-}" && "${CUDA_VISIBLE_DEVICES}" != "-1" ]]; then
  HAS_GPU=1
fi

# Run services
if [[ "$HAS_GPU" -eq 1 ]]; then
    # Start code-server (HTTP port 9000)
    if [[ -n "$PASSWORD" ]]; then
        code-server /workspace --auth password --disable-telemetry --host 0.0.0.0 --bind-addr 0.0.0.0:9000 &
    else
        echo "⚠️ WARNING: PASSWORD is not set as an environment variable"
        code-server /workspace --disable-telemetry --host 0.0.0.0 --bind-addr 0.0.0.0:9000 &
    fi
	
	sleep 5

	# Start Ollama server
    ollama serve &
    
	# Wait until Ollama is ready
    until curl -s http://127.0.0.1:11434 > /dev/null; do
        echo "[INFO] Waiting for Ollama to start..."    
		sleep 5
    done
    echo "[INFO] Ollama server is ready (http://127.0.0.1:11434)."
	
	# Start ComfyUI (HTTP port 8188)
    python3 /workspace/ComfyUI/main.py ${COMFYUI_EXTRA_ARGUMENTS:---listen} &
	
	# Wait until ComfyUI is ready
    until curl -s http://127.0.0.1:8188 > /dev/null; do
        echo "[INFO] Waiting for ComfyUI to start..."    
		sleep 5
    done
    echo "[INFO] ComfyUI server is ready (http://127.0.0.1:8188)."
	
	# Confirmation	
	echo "[INFO] Code Server & ComfyUI & Ollama started"
	
else
    echo "⚠️ WARNING: No GPU available, ComfyUI, Code Server, Ollama not started to limit memory use"
fi

# Start OpenCode server (optional)
OPENCODE_STANDALONE_ENABLED="${OPENCODE_STANDALONE_ENABLED:-false}"
case "${OPENCODE_STANDALONE_ENABLED}" in
    1|true|TRUE|yes|YES)
        if command -v opencode >/dev/null 2>&1; then
            OPENCODE_HOSTNAME="${OPENCODE_HOSTNAME:-0.0.0.0}"
            OPENCODE_PORT="${OPENCODE_PORT:-4096}"
            opencode serve --hostname "$OPENCODE_HOSTNAME" --port "$OPENCODE_PORT" &
            until curl -s "http://127.0.0.1:${OPENCODE_PORT}" > /dev/null; do
                echo "[INFO] Waiting for OpenCode server to start..."
                sleep 3
            done
            echo "[INFO] OpenCode server is ready (http://127.0.0.1:${OPENCODE_PORT})."
        else
            echo "⚠️ WARNING: OpenCode binary not found, skipping OpenCode server startup"
        fi
        ;;
    *)
        echo "[INFO] OPENCODE_STANDALONE_ENABLED=false, skipping standalone OpenCode on port 4096."
        ;;
esac

# Start OpenCode Manager backend
if command -v bun >/dev/null 2>&1 && [[ -d /opt/opencode-manager ]]; then
    export HOST="${OPENCODE_MANAGER_HOST:-${HOST:-0.0.0.0}}"
    export PORT="${OPENCODE_MANAGER_PORT:-${PORT:-5003}}"
    export NODE_ENV="${NODE_ENV:-production}"
    export WORKSPACE_PATH="${WORKSPACE_PATH:-/workspace}"
    export DATABASE_PATH="${DATABASE_PATH:-/workspace/opencode-manager/data/opencode.db}"
    export AUTH_TRUSTED_ORIGINS="${AUTH_TRUSTED_ORIGINS:-http://127.0.0.1:${PORT},http://localhost:${PORT}}"
    export AUTH_SECURE_COOKIES="${AUTH_SECURE_COOKIES:-false}"
    if [[ -z "${AUTH_SECRET:-}" ]]; then
        AUTH_SECRET="$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
        export AUTH_SECRET
        echo "[INFO] AUTH_SECRET not set, generated an ephemeral secret for OpenCode Manager runtime."
    fi
    mkdir -p "$(dirname "$DATABASE_PATH")"
    cd /opt/opencode-manager
    if [[ -d /opt/opencode-manager/frontend/dist ]]; then
        echo "[INFO] OpenCode Manager frontend build found: /opt/opencode-manager/frontend/dist"
    else
        echo "⚠️ WARNING: OpenCode Manager frontend build not found, trying to build frontend..."
        if command -v pnpm >/dev/null 2>&1; then
            if pnpm --filter frontend build; then
                echo "[INFO] OpenCode Manager frontend build completed."
            else
                echo "⚠️ WARNING: Frontend build failed, / may return API JSON only."
            fi
        else
            echo "⚠️ WARNING: pnpm not found, cannot build frontend at runtime."
        fi
    fi
    bun backend/src/index.ts &
    until curl -fsS "http://127.0.0.1:${PORT}/api/health" > /dev/null; do
        echo "[INFO] Waiting for OpenCode Manager API to start..."
        sleep 3
    done
    CONTENT_TYPE="$(curl -sI "http://127.0.0.1:${PORT}/" | tr -d '\r' | awk -F': ' 'tolower($1)=="content-type"{print tolower($2)}' | head -n1)"
    if [[ "$CONTENT_TYPE" == *"text/html"* ]]; then
        echo "[INFO] OpenCode Manager full service is ready (UI+API on http://127.0.0.1:${PORT})."
    else
        echo "⚠️ WARNING: OpenCode Manager API is ready, but / is not HTML (content-type: ${CONTENT_TYPE:-unknown})."
    fi
else
    echo "⚠️ WARNING: OpenCode Manager dependencies not found, skipping OpenCode Manager startup"
fi
	
# Download Ollama models
# Ollama currently cannot pull sharded GGUF tags (e.g. UD-IQ2_XXS).
# Use a single-file GGUF tag that Ollama can load.
GLM5_OLLAMA_COMPAT_MODEL="hf.co/unsloth/GLM-5-GGUF:UD-TQ1_0"
GLM47_FLASH_OLLAMA_MODEL="hf.co/unsloth/GLM-4.7-Flash-GGUF:Q4_K_M"
case "${DEPLOY_GLM5_UD_IQ2_XXS:-}" in
    1|true|TRUE|yes|YES)
        if [[ -z "${OLLAMA_MODEL1:-}" ]]; then
            OLLAMA_MODEL1="$GLM5_OLLAMA_COMPAT_MODEL"
            echo "[INFO] DEPLOY_GLM5_UD_IQ2_XXS enabled, defaulting OLLAMA_MODEL1 to Ollama-compatible tag: $OLLAMA_MODEL1"
        else
            echo "[INFO] DEPLOY_GLM5_UD_IQ2_XXS enabled, keeping user provided OLLAMA_MODEL1: $OLLAMA_MODEL1"
        fi
        ;;
esac

case "${DEPLOY_GLM47_FLASH_GGUF:-}" in
    1|true|TRUE|yes|YES)
        if [[ -z "${OLLAMA_MODEL2:-}" ]]; then
            OLLAMA_MODEL2="$GLM47_FLASH_OLLAMA_MODEL"
            echo "[INFO] DEPLOY_GLM47_FLASH_GGUF enabled, defaulting OLLAMA_MODEL2 to: $OLLAMA_MODEL2"
        else
            echo "[INFO] DEPLOY_GLM47_FLASH_GGUF enabled, keeping user provided OLLAMA_MODEL2: $OLLAMA_MODEL2"
        fi
        ;;
esac

for i in 1 2 3 4 5 6; do
    var="OLLAMA_MODEL$i"
    model="${!var}"
    if [[ -n "$model" ]]; then
        echo "[INFO] Pulling Ollama model: $model"
        if ollama pull "$model"; then
            echo "[OK] Successfully pulled model: $model"
        else
            echo "⚠️ WARNING Failed to pull model: $model" >&2
        fi
    fi
done

echo "✅ Provisioning completed."

# Keep the container running
exec sleep infinity
