[![Docker Image Version](https://img.shields.io/docker/v/ls250824/run-comfyui-ollama)](https://hub.docker.com/r/ls250824/run-comfyui-ollama)

# Run ComfyUI Ollama with Custom nodes on [RunPod.io](https://runpod.io?ref=se4tkc5o)

## Synopsis

A streamlined setup for running **ComfyUI** with **Ollama**.  
This pod downloads models as specified in the **environment variables** set in the [RunPod.io template](https://runpod.io/console/deploy?template=hx0q4csn2c&ref=se4tkc5o).  

- Models are automatically downloaded based on the specified paths in the environment configuration.  
- Authentication credentials can be set via secrets for:  
  - **Code server** authentication (not possible to switch off) 
  - **Hugging Face** tokens for model access.  

Ensure that the required environment variables and secrets are correctly set before running the pod.
See below for options.

## Hardware Requirements  
 
- **Recommended GPUs**: Nvidia RTX A4500, A40
- **Storage**:  
  - **Volume**: 20GB (`/workspace`)  
  - **Pod Volume**: 70Gb  

## Template [RunPod.io](https://runpod.io?ref=se4tkc5o)

- [template](https://runpod.io/console/deploy?template=hx0q4csn2c&ref=se4tkc5o)

## Available Images

### Base Images 

#### ls250824/pytorch-cuda-ubuntu-runtime
	
[![Docker Image Version](https://img.shields.io/docker/v/ls250824/pytorch-cuda-ubuntu-runtime)](https://hub.docker.com/r/ls250824/pytorch-cuda-ubuntu-runtime)

#### ls250824/comfyui-runtime

[![Docker Image Version](https://img.shields.io/docker/v/ls250824/comfyui-runtime)](https://hub.docker.com/r/ls250824/comfyui-runtime)

### Custom Build: 

```bash
docker pull registry.cn-shenzhen.aliyuncs.com/sailfish/runnode-run-comfyui-ollama:<version>
```

## Environment Variables  

### **ComfyUI Arguments**  

| Token        | Environment Variable     |
|--------------|--------------------------|
| Arguments    | `COMFYUI_EXTRA_ARGUMENTS`|

### **Authentication Tokens**  

| Token        | Environment Variable |
|--------------|----------------------|
| Huggingface  | `HF_TOKEN`           |
| Code Server  | `PASSWORD`           |

### **Diffusion Lora Setup Huggingface**  

| Model Type        | URL (Huggingface or Ollama) |
|-------------------|-----------------------------|
| Ollama model      | `OLLAMA_MODEL[1-6]`         |
| GLM-5 preset      | `DEPLOY_GLM5_UD_IQ2_XXS`    |

When `DEPLOY_GLM5_UD_IQ2_XXS=true` and `OLLAMA_MODEL1` is not set, startup automatically sets:

```bash
OLLAMA_MODEL1=hf.co/unsloth/GLM-5-GGUF:UD-IQ2_XXS
```

## Connection options 

### Services

| Service         | Port          |
|-----------------|---------------| 
| **ComfyUI**     | `8188` (HTTP) |
| **Code Server** | `9000` (HTTP) |
| **SSH/SCP**     | `22`   (TCP)  |
| **Gradio**      | `7860` (HTTP) |

## Website models

- [Huggingface](https://huggingface.co/)

## Websites software Github

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI)
- [Code server](https://github.com/coder/code-server)
- [Ollama](https://github.com/ollama/ollama)

## Tutorial

- [blog](https://geshan.com.np/blog/categories/ollama/)

### Custom Nodes ComfyUI 

#### Full list

- [awesome-comfyui](https://awesome-comfyui.rozenlaan.site)

#### Installed

- [rgthree](https://github.com/rgthree/rgthree-comfy)
- [login](https://github.com/liusida/ComfyUI-Login)
- [manager](https://github.com/ltdrdata/ComfyUI-Manager)
- [KJNodes](https://github.com/kijai/ComfyUI-KJNodes)
- [Ollama](https://github.com/stavsap/comfyui-ollama)
- [Comfyui-LoopLoader](https://github.com/alessandrozonta/Comfyui-LoopLoader)
- [JoyCaption](https://github.com/judian17/ComfyUI-JoyCaption-beta-one-hf-llava-Prompt_node)
- [StringEssentials](https://github.com/bradsec/ComfyUI_StringEssentials.git)
- [LLM_party](https://github.com/heshengtao/comfyui_LLM_party)
- [VibeVoice](https://github.com/Enemyx-net/VibeVoice-ComfyUI)

## Manual provisioning

[provisioning](provisioning/provisioning.md)

## Templates available in ComfyUI (left folder icon)

![t2t simple](images/ollama-simple.JPG)

![i2t advanced](images/ollama-vision-advanced.JPG)

## Gradio

[Gradio chat in python source](gradio/chat.py)

```bash
ollama pull hf.co/saukko/Abliterated-Dolphin3.0-R1-Mistral-24B-GGUF:Q8_0
python gradio/chat.py
```

Interface available on exposed http port 7860

## Deploy GLM-5 UD-IQ2_XXS

Set this environment variable in RunPod template:

```bash
DEPLOY_GLM5_UD_IQ2_XXS=true
```

Optional override:

```bash
OLLAMA_MODEL1=hf.co/unsloth/GLM-5-GGUF:UD-IQ2_XXS
```

Reference:
- https://unsloth.ai/docs/models/glm-5

## Building the Docker Image 

This is not possible on [runpod.io](https://runpod.io?ref=se4tkc5o) use local hardware.
You can build and push the image to Docker Hub using the `build-docker.py` script.

## GitHub Actions: Build and Push to Alibaba Cloud ACR

The workflow file is: `.github/workflows/docker-acr.yml`

Image repository:

```bash
registry.cn-shenzhen.aliyuncs.com/sailfish/runnode-run-comfyui-ollama
```

Set these repository secrets in GitHub:

- `ALICLOUD_REGISTRY_USERNAME`
- `ALICLOUD_REGISTRY_PASSWORD`

### Trigger methods

- Push Git tag like `v1.0.0` to build and push:
  - `registry.cn-shenzhen.aliyuncs.com/sailfish/runnode-run-comfyui-ollama:v1.0.0-comfyui-11022026-ollama-0.16.1`
- Run manually in GitHub Actions (`workflow_dispatch`) with:
  - `image_version` (required)
  - `comfyui_version` (optional, default reads from `Dockerfile`)
  - `ollama_version` (optional, default reads from `Dockerfile`)
- Optional: set `push_latest=true` in manual run to also push `:latest`.

Tag format:

```bash
<image_version>-comfyui-<comfyui_version>-ollama-<ollama_version>
```

### `build-docker.py` script options

| Option         | Description                                         | Default                |
|----------------|-----------------------------------------------------|------------------------|
| `--username`   | Docker Hub username                                 | Current user           |
| `--tag`        | Tag to use for the image                            | Today's date           |
| `--latest`     | If specified, also tags and pushes as `latest`      | Not enabled by default |

### Build & push Command

Run the following command to clone the repository and build the image:

```bash
git clone https://github.com/jalberty2018/run-comfyui-ollama.git
cp run-comfyui-ollama/build-docker.py ..

python3 build-docker.py \
--username=<your_dockerhub_username> \
--tag=<custom_tag> \ 
run-comfyui-ollama
```

Note: If you want to push the image with the latest tag, add the --latest flag at the end.
