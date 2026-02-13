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
	
# Download Ollama models
# Ollama currently cannot pull sharded GGUF tags (e.g. UD-IQ2_XXS).
# Use a single-file GGUF tag that Ollama can load.
GLM5_OLLAMA_COMPAT_MODEL="hf.co/unsloth/GLM-5-GGUF:UD-TQ1_0"
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
