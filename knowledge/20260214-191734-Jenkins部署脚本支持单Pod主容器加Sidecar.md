# 2026-02-14 19:17:34 Jenkins部署脚本支持单Pod主容器+Sidecar

## 目标

将 `jenkins-deploy/pipeline-deploy.md` 调整为一个 Pod 内同时运行：
- 主容器：`runnode-run-comfyui-ollama`
- Sidecar：`runnode-llamacpp-glm5`

## 主要修改

1. 镜像变量拆分
- 新增主容器与 sidecar 的独立仓库和标签变量：
  - `IMAGE_REPO_MAIN` / `IMAGE_TAG_MAIN`
  - `IMAGE_REPO_SIDECAR` / `IMAGE_TAG_SIDECAR`

2. Jenkins 镜像处理
- Pipeline 中同时对两个镜像执行 pull/tag/push：
  - 主镜像推送到 Harbor
  - Sidecar 镜像推送到 Harbor

3. Helm 部署参数
- 主容器镜像改为 `targetMainImage`。
- 新增 sidecar 端口映射参数（`ports[5]`，值 `18080`）。
- 新增 `sidecars[0]` 配置（前提：当前 Helm Chart 支持 `sidecars[]` 字段），包括：
  - sidecar 镜像
  - `llama-server` 参数（model/ctx/threads/parallel/jinja）
  - 只读挂载 `/root/.ollama`，复用主容器同一模型目录

4. 主容器环境变量
- 增加 `GLM5_SIDECAR_URL=http://127.0.0.1:8080`，便于主容器内访问同 Pod sidecar。

## 注意事项

- 当前实现依赖 Helm Chart `base-app` 支持 `sidecars[]` 字段。如果该 Chart 不支持，需要改为：
  - 扩展 Chart 模板，或
  - 使用原生 Deployment YAML 显式声明双容器。
