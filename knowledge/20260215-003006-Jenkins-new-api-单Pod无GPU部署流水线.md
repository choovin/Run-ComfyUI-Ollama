# 20260215-003006 Jenkins new-api 单 Pod 无 GPU 部署流水线

## 目标
- 部署项目：https://github.com/QuantumNous/new-api.git
- 在 **一个 Pod** 内完成应用及依赖镜像部署
- 不使用 GPU

## 产物
- 新增流水线文件：jenkins-deploy/pipeline-new-api-single-pod.groovy

## 流水线能力
1. 拉取 
ew-api 仓库（main）
2. 基于源码构建镜像并推送 Harbor
3. 在 K8s 创建单 Pod 多容器部署：
   - 
ew-api 主容器
   - edis:7-alpine
   - postgres:15
4. 创建 Service + Ingress 暴露 3000
5. 滚动重启并等待 rollout 完成

## 无 GPU 说明
- Deployment 未设置任何 
vidia.com/* 资源请求与限制
- 资源仅为 CPU/Memory

## 可改参数（环境区）
- REGISTRY_TARGET
- IMAGE_REPO_MAIN
- K8S_NAMESPACE
- K8S_DEPLOY_NAME
- NEWAPI_HOST
- HOSTPATH_BASE

## 注意
- 当前 postgres 密码使用示例值 123456，生产请替换并改为 Secret 管理。
- 单 Pod 内置数据库适合轻量/测试场景；生产建议把 DB/Redis 拆为独立服务。
