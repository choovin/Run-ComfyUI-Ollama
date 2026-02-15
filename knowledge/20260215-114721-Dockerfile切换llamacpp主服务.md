# 20260215-114721 Dockerfile切换为llama.cpp主服务（GLM-4.7-Flash量化）

## 目标
- 不再运行 ComfyUI / Ollama / OpenCode Manager。
- 主容器改为直接运行 `llama.cpp` 的 `llama-server`。
- 使用 GLM-4.7-Flash 量化 GGUF 模型（通过环境变量指定文件路径）。

## 变更文件
- `Dockerfile`
- `start.sh`
- `.env.example`

## 关键改动
1. `Dockerfile`
- 基础镜像改为：`ghcr.io/ggml-org/llama.cpp:server-cuda`
- 删除原 ComfyUI/Ollama/OpenCode 相关安装与依赖。
- 仅保留 `/start.sh` 作为启动入口。
- 仅暴露 `8080` 端口（llama.cpp HTTP 服务）。

2. `start.sh`
- 重写为单一职责：启动 `llama-server`。
- 默认参数：
  - `LLAMACPP_HOST=0.0.0.0`
  - `LLAMACPP_PORT=8080`
  - `LLAMACPP_MODEL_PATH=/models/glm-4.7-flash-q4_k_m.gguf`
  - `LLAMACPP_ALIAS=glm47flash`
  - `LLAMACPP_CTX_SIZE=8192`
  - `LLAMACPP_N_GPU_LAYERS=999`
  - `LLAMACPP_THREADS=16`
  - `LLAMACPP_PARALLEL=1`
- 启动前校验模型文件存在，不存在则直接报错退出。

3. `.env.example`
- 移除 ComfyUI/Ollama/OpenCode 相关变量。
- 改为 llama.cpp 运行参数示例。

## 使用说明
- 启动前确保 GGUF 模型文件已挂载到容器内，并设置 `LLAMACPP_MODEL_PATH`。
- 例如：`/models/glm-4.7-flash-q4_k_m.gguf`。
