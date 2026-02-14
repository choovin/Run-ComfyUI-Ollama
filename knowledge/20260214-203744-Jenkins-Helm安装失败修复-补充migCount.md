# 2026-02-14 20:37:44 Jenkins Helm安装失败修复（补充migCount）

## 问题现象

Jenkins 部署阶段 `helm install` 失败：

```text
template: base-app/templates/deployment.yaml:81:43: executing ... at <gt .Values.migCount 0>: error calling gt: incompatible types for comparison
```

## 根因

`base-app` Chart 模板在做 `gt .Values.migCount 0` 比较时，要求 `migCount` 为数值型。
当前 pipeline 仅设置了 `mig=1`，未显式设置 `migCount`，导致模板比较时类型不兼容。

## 修复

在 `jenkins-deploy/pipeline-deploy.md` 的 Helm 参数中新增：

```bash
--set migCount=1
```

并保留原有：

```bash
--set mig=1
```

以兼容旧键。

## 结果

Helm 模板渲染阶段不再因 `migCount` 缺失/类型不匹配而失败，可继续验证 Sidecar 双容器是否按预期创建。
