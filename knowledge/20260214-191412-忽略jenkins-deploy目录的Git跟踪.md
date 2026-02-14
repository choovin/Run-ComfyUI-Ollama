# 2026-02-14 19:14:12 忽略jenkins-deploy目录的Git跟踪

## 变更内容

- 新增仓库根目录 `.gitignore`。
- 增加忽略规则：`jenkins-deploy/`。

## 结果

- `jenkins-deploy` 目录将不再被 Git 跟踪与提交。
- 仅影响该目录，不改变其他文件的跟踪行为。
