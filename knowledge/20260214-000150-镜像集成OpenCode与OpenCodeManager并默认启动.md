# 20260214-000150 镜像集成OpenCode与OpenCodeManager并默认启动

## 目标
在现有镜像中集成 `OpenCode` 与 `opencode-manager`，并在容器启动时默认拉起。

## 变更文件
- `Dockerfile`
- `start.sh`
- `docker-compose.yml`
- `.env.example`
- `README.md`

## Dockerfile改动
- 新增构建参数：
  - `OPENCODE_VERSION`（默认 `latest`）
  - `OPENCODE_MANAGER_REF`（默认 `v0.8.29`）
- 安装依赖：Node.js 22、pnpm（corepack）、bun 以及构建工具链
- 安装 OpenCode 二进制并链接到 `/usr/local/bin/opencode`
- 克隆并构建 `opencode-manager` 到 `/opt/opencode-manager`
- 新增暴露端口：
  - `11434`（Ollama API）
  - `4096`（OpenCode）
  - `5003`（OpenCode Manager）
  - `5100-5103`（预留）

## 启动脚本改动（start.sh）
- 默认启动 OpenCode：
  - `opencode serve --hostname ${OPENCODE_HOSTNAME:-0.0.0.0} --port ${OPENCODE_PORT:-4096}`
- 默认启动 OpenCode Manager（bun backend）：
  - `HOST=${HOST:-0.0.0.0}`
  - `PORT=${PORT:-5003}`
  - `WORKSPACE_PATH=${WORKSPACE_PATH:-/workspace}`
  - `DATABASE_PATH=${DATABASE_PATH:-/workspace/opencode-manager/data/opencode.db}`
- 若未设置 `AUTH_SECRET`，运行时自动生成临时值并打印提示。

## Compose与环境变量模板改动
- `docker-compose.yml`
  - 新增端口映射：`OPENCODE_PORT`、`OPENCODE_MANAGER_PORT`
  - 新增环境变量透传（OpenCode + OpenCode Manager）
- `.env.example`
  - 新增默认变量及示例

## README改动
- 在服务端口表中增加 Ollama/OpenCode/OpenCode Manager
- 增加 OpenCode/OpenCode Manager 的默认启动与环境变量说明

## 使用建议
- 生产环境请显式设置固定 `AUTH_SECRET`
- 对外访问时请按实际域名更新 `AUTH_TRUSTED_ORIGINS`
