# 20260215-115158 保留OpenCode Manager并与llama.cpp同容器启动

## 需求
- 在切换到 `llama.cpp` 主服务后，保留原有 `opencode-manager` 能力。
- 不恢复 ComfyUI/Ollama。

## 结果
- 现在容器同时启动两个进程：
  - `llama-server`（默认 `:8080`）
  - `opencode-manager`（默认 `:5003`）

## 文件变更
1. `Dockerfile`
- 基于 `ghcr.io/ggml-org/llama.cpp:server-cuda`
- 额外安装并准备：Node.js、pnpm、bun、opencode
- 构建 `opencode-manager` 前后端产物
- 暴露端口：`8080`、`5003`

2. `start.sh`
- 启动前校验 GGUF 模型文件存在
- 自动生成 `AUTH_SECRET`（未显式设置时）
- 后台启动 `opencode-manager` 并健康检查 `/api/health`
- 启动 `llama-server`
- 使用 `wait -n` 监控双进程，任一异常退出会触发整体退出

3. `.env.example`
- 保留 llama.cpp 参数
- 增加/保留 opencode-manager 运行参数（HOST/PORT/NODE_ENV/DATABASE/AUTH）

## 注意
- 需要在运行时挂载 GLM-4.7-Flash GGUF 文件，并正确设置 `LLAMACPP_MODEL_PATH`。
- 生产建议固定 `AUTH_SECRET`，避免容器重启后会话失效。
