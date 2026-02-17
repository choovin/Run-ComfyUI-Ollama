# opencode-manager 健康检查与升级超时修复

## 现象
- `opencode` 实际可用（外部 `op` 域名可访问，容器内健康端点均为 `200`）。
- 但 `opencode-manager` 日志持续报：
  - `OpenCode server failed to become healthy`（30s）
  - `Version install command timed out after 90 seconds`

## 根因
- 容器中 `opencode-manager` 代码仍是旧硬编码：
  - `waitForHealth(30000)`
  - `execWithTimeout(..., 90000)`（升级相关两处）
- 导致“服务已可用但 manager 误判失败”。

## 修复方案
1. 构建期自动补丁 `opencode-manager` 源码（不改上游仓库）：
- 文件：`scripts/patch_opencode_manager.py`
- 注入能力：
  - 健康检查超时改为环境变量 `OPENCODE_HEALTH_TIMEOUT_MS`（默认 `120000`）
  - 升级超时改为环境变量 `OPENCODE_UPGRADE_TIMEOUT_MS`（默认 `300000`，最小 `60000`）
  - 健康探测端点改为回退链：`/global/health -> /doc -> /health -> /`

2. Docker 构建接入补丁脚本：
- 文件：`Dockerfile`
- 在 clone `opencode-manager` 后执行 `python3 /workspace/scripts/patch_opencode_manager.py`。

3. Jenkins Pipeline 增加环境变量透传：
- `OPENCODE_HEALTH_TIMEOUT_MS=120000`
- `OPENCODE_UPGRADE_TIMEOUT_MS=600000`
- 覆盖文件：
  - `jenkins-deploy/pipeline-llamacpp-opencode-h200-mig35g.groovy`
  - `jenkins-deploy/pipeline-llamacpp-opencode-h200-mig71g.groovy`

## 验证方式
- 容器内确认补丁已生效：
```bash
grep -n "OPENCODE_HEALTH_TIMEOUT_MS\|healthPaths" /opt/opencode-manager/backend/src/services/opencode-single-server.ts
grep -n "OPENCODE_UPGRADE_TIMEOUT_MS\|getOpenCodeUpgradeTimeoutMs" /opt/opencode-manager/backend/src/routes/settings.ts
```
- 不应再出现 `waitForHealth(30000)` 与 `90000`。

## 本次镜像版本
- Tag：`v20260217-llamacpp-opencode-r25-llamacpp-opencode-1.2.4-manager-main`
