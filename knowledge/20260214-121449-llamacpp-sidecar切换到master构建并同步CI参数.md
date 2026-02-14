# 20260214-121449 llama.cpp sidecar切换到master构建并同步CI参数

## 目标
将 sidecar/llamacpp-glm5/Dockerfile 从固定 PR 19460 构建改为默认跟踪 llama.cpp master，并同步 Compose/Action/README 参数。

## 变更文件
- sidecar/llamacpp-glm5/Dockerfile
- docker-compose.yml
- .env.example
- .github/workflows/docker-acr.yml
- README.md

## 核心改动
### Dockerfile
- 参数从 LLAMACPP_PR 改为 LLAMACPP_REF
- 默认值：master
- 构建时执行 git checkout \"\"

### Compose
- build arg 改为 LLAMACPP_REF
- 默认 LLAMACPP_REF=master
- 本地镜像标签改为 unnode/llamacpp-glm5:master-latest

### GitHub Actions
- workflow_dispatch 输入从 llamacpp_pr 改为 llamacpp_ref
- sidecar 标签格式从：
  - <image_version>-llamacpp-pr-<llamacpp_pr>
  改为：
  - <image_version>-llamacpp-<llamacpp_ref>
- sidecar build-arg 同步为 LLAMACPP_REF

### README
- sidecar 说明改为“latest master”
- 所有示例变量改为 LLAMACPP_REF

## 结果
sidecar 默认跟随 llama.cpp master 最新能力，且本地/CI 参数命名保持一致，避免继续使用过期 PR 参数。
