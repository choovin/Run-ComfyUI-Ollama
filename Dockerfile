# Base image (ComfyUI runtime version is parameterized for reproducible tags/builds)
ARG COMFYUI_VERSION=11022026
FROM ls250824/comfyui-runtime:${COMFYUI_VERSION} AS base
ARG COMFYUI_VERSION
ARG OLLAMA_VERSION=0.16.1

# Set working directory
WORKDIR /

# Copy scripts and make them executable
COPY --chmod=755 start.sh onworkspace/comfyui-on-workspace.sh onworkspace/provisioning-on-workspace.sh onworkspace/readme-on-workspace.sh onworkspace/gradio-on-workspace.sh /

# Copy documentation with appropriate permissions
COPY --chmod=644 documentation/README.md /README.md

# Copy provisioning with appropriate permissions
COPY --chmod=644 provisioning/ /provisioning

# Copy gradio with appropriate permissions
COPY --chmod=644 gradio/ /gradio

# Copy workflows with appropriate permissions
COPY --chmod=644 workflows/ /ComfyUI/user/default/workflows

# Copy default configuration
COPY --chmod=644 configurations/comfy.settings.json /ComfyUI/user/default/comfy.settings.json

# Install llama_cpp_python wheel + set CUDA/CUBLAS runtime paths ----
RUN wget https://github.com/jalberty2018/run-pytorch-cuda-develop/releases/download/v1.1.0/llama_cpp_python-0.3.16-cp311-cp311-linux_x86_64.whl && \
    pip3 install --no-cache-dir llama_cpp_python-0.3.16-cp311-cp311-linux_x86_64.whl && \
    rm -f llama_cpp_python-0.3.16-cp311-cp311-linux_x86_64.whl && \
    echo "/opt/conda/lib/python3.11/site-packages/nvidia/cuda_runtime/lib" > /etc/ld.so.conf.d/cuda-runtime.conf  && \
    echo "/opt/conda/lib/python3.11/site-packages/nvidia/cublas/lib" > /etc/ld.so.conf.d/cublas.conf && \
    ldconfig

# Install Ollama from GitHub releases (.tar.zst) to avoid install.sh fallback 404s
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends zstd; \
    rm -rf /var/lib/apt/lists/*; \
    OLLAMA_TAG="v${OLLAMA_VERSION#v}"; \
    curl -fsSL "https://github.com/ollama/ollama/releases/download/${OLLAMA_TAG}/ollama-linux-amd64.tar.zst" -o /tmp/ollama-linux-amd64.tar.zst; \
    zstd -d < /tmp/ollama-linux-amd64.tar.zst | tar -xf - -C /usr/local \
      --exclude='lib/ollama/cuda_v13' \
      --exclude='lib/ollama/cuda_v13/*'; \
    rm -f /tmp/ollama-linux-amd64.tar.zst

# Install required Python packages and clone custom ComfyUI nodes
RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/liusida/ComfyUI-Login.git && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
	git clone https://github.com/alessandrozonta/Comfyui-LoopLoader.git && \
    git clone https://github.com/stavsap/comfyui-ollama.git && \
	git clone https://github.com/bradsec/ComfyUI_StringEssentials.git && \
	git clone https://github.com/heshengtao/comfyui_LLM_party.git && \
	git clone https://github.com/Enemyx-net/VibeVoice-ComfyUI.git

# Install requirements for each relevant custom node
RUN pip3 install --no-cache-dir diffusers gradio requests openai \
    -r /ComfyUI/custom_nodes/ComfyUI-Login/requirements.txt \
    -r /ComfyUI/custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt \
    -r /ComfyUI/custom_nodes/ComfyUI-KJNodes/requirements.txt \
	-r /ComfyUI/custom_nodes/comfyui-ollama/requirements.txt \
	-r /ComfyUI/custom_nodes/comfyui_LLM_party/requirements.txt

# Set workspace directory
WORKDIR /workspace

# Expose ports for ComfyUI, code-server, Gradio
EXPOSE 8188 9000 7860

# Start script
CMD [ "/start.sh" ]
