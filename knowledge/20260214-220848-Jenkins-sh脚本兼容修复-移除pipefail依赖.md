# 2026-02-14 22:08:48 Jenkins sh脚本兼容修复（移除pipefail依赖）

## 问题

Jenkins Job 在 sidecar 校验步骤失败：

`	ext
set: Illegal option -o pipefail
`

原因是 Pipeline sh 默认使用 /bin/sh（dash），不支持 set -o pipefail。

## 修复

文件：jenkins-deploy/pipeline-deploy.md

- 将：

`ash
set -euo pipefail
`

改为：

`ash
set -eu
`

- 将 cho ... | grep -qw ... 判断改为 case，避免依赖管道行为。

## 结果

脚本改为纯 sh 兼容写法，可在 Jenkins 默认 shell 下执行，不再因 pipefail 报错中断。
