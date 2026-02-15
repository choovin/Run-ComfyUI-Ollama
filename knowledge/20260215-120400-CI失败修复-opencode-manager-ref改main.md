# 20260215-120400 CI失败修复：opencode-manager 分支引用

## 问题
- GitHub Actions 构建在 Docker build 阶段失败。
- 失败点：git clone --branch "" ... 返回 xit code 128。

## 原因
- Dockerfile 默认 OPENCODE_MANAGER_REF=v0.8.29，该引用在目标仓库不可用。

## 修复
- 将默认值调整为：OPENCODE_MANAGER_REF=main。

## 结果
- 重新推送后可再次触发工作流构建验证。
