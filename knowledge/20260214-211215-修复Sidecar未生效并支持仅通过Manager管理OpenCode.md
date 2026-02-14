# 2026-02-14 21:12:15 修复Sidecar未生效并支持仅通过Manager管理OpenCode

## 现象与定位

1. 单 Pod 部署后仅有主容器，`llama.cpp` sidecar 未启动。
2. OpenCode 相关出现两个入口：
- 直接 `opencode serve`（4096）
- OpenCode Manager 进程内部管理链路（用户观测到 5551）

## 本次修改

### 1) `jenkins-deploy/pipeline-deploy.md`

- 在 `helm install` 之后增加 sidecar 校验：
  - 读取 Deployment 容器列表，检查是否包含 `llama-cpp-glm5`。
- 若 chart 未渲染 sidecar，则自动执行 `kubectl patch deployment` 注入 sidecar（同 Pod）：
  - 注入容器 `llama-cpp-glm5`
  - 注入 `hostPath` 卷 `/data/sailfish/vllm-ollama/ollama_data`（只读挂载到 `/root/.ollama`）
  - 注入运行参数（`--model`、`--ctx-size`、`--threads` 等）

> 目的：兼容 chart 不支持 `sidecars[]` 字段的情况，确保 sidecar 实际落地。

- 同时新增主容器环境变量：

```bash
OPENCODE_STANDALONE_ENABLED=false
```

用于关闭主容器内独立的 `opencode:4096` 启动。

### 2) `start.sh`

- 增加可控开关：

```bash
OPENCODE_STANDALONE_ENABLED=true|false
```

- 当为 `false` 时，不再启动独立 `opencode serve --port 4096`。

### 3) `.env.example`

- 新增：

```bash
OPENCODE_STANDALONE_ENABLED=true
```

默认兼容历史行为；在 Jenkins 部署里已按需显式置为 `false`。

## 说明

- `5003` 目前是 OpenCode Manager 后端入口；若你只需要“Manager 管理 OpenCode”，建议保持 `OPENCODE_STANDALONE_ENABLED=false`。
- 这样可避免主容器额外再起一套独立 OpenCode 服务。
