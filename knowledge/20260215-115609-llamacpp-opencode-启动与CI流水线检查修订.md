# 20260215-115609 llama.cpp + opencode-manager 启动与 CI/CD 流水线检查修订

## 目标
- 确保镜像中 llama.cpp 与 opencode-manager 可并行启动。
- 检查并修订 Jenkins 与 GitHub Actions 构建/部署流程，匹配新架构（无 ComfyUI/sidecar）。

## 核查结论
1. 运行入口
- start.sh 已改为并行启动：
  - un backend/src/index.ts（5003）
  - llama-server（8080）
- 增加 manager 健康检查 /api/health。
- 增加 GGUF 文件存在性校验。

2. GitHub Actions
- .github/workflows/docker-acr.yml 已从旧 ComfyUI+sidecar 方案切换为单镜像构建。
- 新镜像仓库：sailfish/runnode-llamacpp-glm47-opencode。
- 构建参数改为：OPENCODE_VERSION、OPENCODE_MANAGER_REF。
- 移除 sidecar mirror job。

3. Jenkins 部署流水线
- jenkins-deploy/pipeline-deploy.md 已切换到新镜像与新端口（8080/5003）。
- 修复端口重复问题：避免 port=8080 与 ports[0]=8080 同时出现。
- 现仅保留附加端口 5003（主端口由 port 字段提供）。

## 备注
- 当前环境无法本地实际运行 docker 容器进行端到端启动测试（本机 Docker engine 不可用），已完成静态逻辑与流水线一致性校验。
