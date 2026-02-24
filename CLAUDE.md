# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository is a comprehensive AI development environment combining multiple services:

- **ComfyUI**: Visual workflow editor for AI models
- **Ollama**: Local LLM serving
- **llama.cpp**: Alternative LLM serving via gguf models
- **OpenCode**: AI-powered code assistant
- **OpenCode Manager**: Web interface for OpenCode
- **OpenClaw**: AI agent platform with gateway and mission control
- **Gradio**: Web interface for chat interactions

## Architecture

The system consists of several interconnected services running in containers:

1. **Main Container** (`run-comfyui-ollama`): Contains ComfyUI, Ollama, and startup scripts
2. **llama.cpp Sidecar** (optional): Alternative LLM serving for models like GLM-5
3. **OpenCode & Manager**: AI-powered coding assistance
4. **OpenClaw**: AI agent platform with gateway and mission control

## Key Components

### Start Script (`start.sh`)
- Main entry point that starts llama.cpp, OpenCode Manager, OpenClaw Gateway, and Mission Control
- Handles model auto-download with fallback to mirrors
- Manages service startup and health checks

### Dockerfile
- Based on `ghcr.io/ggml-org/llama.cpp:server-cuda`
- Installs Node.js, Bun, OpenCode, OpenCode Manager, OpenClaw
- Exposes ports: 8080 (llama.cpp), 5003 (OpenCode Manager), 5551 (OpenCode), 3000 (Mission Control), 18789 (OpenClaw Gateway)

### Configuration
- **OpenClaw configs**: Located in `config/openclaw.json` and `config/auth-profiles.json`
- **Environment variables**: Managed via `.env` and docker-compose.yml
- **Model presets**: Support for GLM-5, GLM-4.7, Minimax 2.5, Kimi 2.5

## Common Development Tasks

### Running the Application
```bash
# Using Docker Compose
docker-compose up -d

# With GLM-5 sidecar
docker-compose --profile glm5-sidecar up -d

# With local build fallback
docker-compose --profile glm5-sidecar-localbuild up -d --build
```

### Building the Docker Image
```bash
python3 build_docker.py run-comfyui-ollama --username <your_username> --tag <custom_tag>
```

### Environment Variables
Key variables for customization:
- `MODEL_PRESET`: Select model preset (glm5, glm47flash, minimax25, kimi25)
- `LLAMACPP_MODEL_PATH`: Path to GGUF model file
- `COMFYUI_EXTRA_ARGUMENTS`: Additional ComfyUI startup arguments
- `OPENCLAW_GATEWAY_PASSWORD`: Password for OpenClaw gateway authentication

### Ports
- 8188: ComfyUI
- 9000: Code Server
- 11434: Ollama API
- 7860: Gradio
- 8080: llama.cpp server
- 5003: OpenCode Manager
- 5551: OpenCode Server
- 18789: OpenClaw Gateway
- 3000: OpenClaw Mission Control
- 22: SSH/SCP

## Development Guidelines

- The repository supports model auto-download with fallback to ModelScope or HF Mirror
- Uses GPU acceleration with CUDA support
- Configurable model presets with different quantization levels
- Supports both direct model paths and preset configurations
- Comprehensive startup validation and health checks