# opencode-manager 连接 opencode：`OPENCODE_HOST` 必须使用 `127.0.0.1`

## 背景/现象
- 单容器内同时运行：
  - `opencode-manager`（WebUI/API，5003）
  - `opencode serve`（默认 5551）
- 启动后出现 manager 侧“连接/健康检查异常”，但从外部访问 `op` 域名是正常的。

## 根因
- `opencode-manager` 连接 `opencode` 是通过容器内 HTTP 访问完成的。
- 在容器内，`0.0.0.0` 只表示“监听所有网卡”，不是一个可用于客户端连接的目标地址。
- 因此 `OPENCODE_HOST=0.0.0.0` 会导致 manager 对 `opencode` 的访问行为不可靠/失败。

## 解决方案
- 将 `OPENCODE_HOST` 改为 loopback：
  - `OPENCODE_HOST=127.0.0.1`

## 修改点
- Jenkins Pipeline 透传 env：
  - `jenkins-deploy/pipeline-llamacpp-opencode-h200-mig35g.groovy`
  - `jenkins-deploy/pipeline-llamacpp-opencode-h200-mig71g.groovy`
- 将：
  - `[name: 'OPENCODE_HOST', value: '0.0.0.0']`
  - 改为：
  - `[name: 'OPENCODE_HOST', value: '127.0.0.1']`

## 验证
- 进入容器确认环境变量与端口监听：
```bash
echo "$OPENCODE_HOST"
ss -lntp | rg ":5551"
curl -sS -o /dev/null -w "%{http_code}\n" "http://127.0.0.1:5551/global/health"
```
