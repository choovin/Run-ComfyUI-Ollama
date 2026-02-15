# 20260215-120718 CI修复：移除 NodeSource setup 脚本

## 背景
- Actions 构建在 Build and push main image 阶段快速失败（约 1 分钟内）。
- 判断为 Dockerfile 前置依赖安装链路不稳定（curl ... setup_22.x | bash）。

## 修复
- Dockerfile 改为直接安装系统仓库 
odejs + 
pm。
- 保留 corepack + pnpm，用于构建 opencode-manager。

## 目的
- 降低外部脚本依赖导致的构建早期失败风险。
