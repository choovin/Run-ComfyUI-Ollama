# 修复 llama-server 缺少 libmtmd.so.0 动态库路径

## 现象
- Pod 日志：`/app/llama-server: error while loading shared libraries: libmtmd.so.0: cannot open shared object file`
- 表现：容器反复重启（CrashLoopBackOff）

## 根因
- llama.cpp 二进制依赖的动态库在镜像目录（常见为 `/app`），但运行时 `LD_LIBRARY_PATH` 未覆盖该路径。

## 修复
1. `start.sh`
- 启动前注入：`LD_LIBRARY_PATH=/app:/opt/llama/bin:/usr/local/lib:$LD_LIBRARY_PATH`

2. `Dockerfile`
- 增加镜像级 ENV：`LD_LIBRARY_PATH=/app:/opt/llama/bin:/usr/local/lib:${LD_LIBRARY_PATH}`

## 结果预期
- `llama-server` 可正确加载 `libmtmd.so.0`，容器不再因该错误重启。
