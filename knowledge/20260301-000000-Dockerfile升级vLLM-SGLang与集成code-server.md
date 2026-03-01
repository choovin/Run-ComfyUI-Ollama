# Dockerfile 更新：vLLM 升级、SGLang 最新版、code-server 集成

## 日期
2026-03-01

## 变更内容

### 1. vLLM 升级到 nightly (0.16.1.dev)
- **原因**: 原 vLLM 0.8.3 不支持 Step3p5ForCausalLM 架构
- **新版本**: 0.16.1.dev (nightly build)
- **安装方式**:
  ```dockerfile
  ARG VLLM_VERSION=0.16.1.dev
  pip3 install vllm==${VLLM_VERSION} \
    --extra-index-url https://wheels.vllm.ai/nightly \
    --extra-index-url https://download.pytorch.org/whl/cu129
  ```

### 2. SGLang 安装最新版本
- **官方推荐安装方式**: 使用 uv 从 git 安装
- **安装命令**:
  ```dockerfile
  uv pip install --system 'git+https://github.com/sgl-project/sglang.git#subdirectory=python&egg=sglang[all]'
  ```

### 3. code-server 集成
- **安装位置**: 与 OpenCode 相同的早期 Dockerfile 层（不常变更，加速构建）
- **安装命令**:
  ```dockerfile
  # Install code-server
  curl -fsSL https://code-server.dev/install.sh | sh
  # Install opencode plugin for code-server via VSCode Marketplace
  code-server --install-extension sst-dev.opencode --force
  ```
- **默认端口**: 9000
- **环境变量**:
  - `CODE_SERVER_HOST`: 默认 "0.0.0.0"
  - `CODE_SERVER_PORT`: 默认 "9000"
  - `CODE_SERVER_PASSWORD`: 可选，用于认证
  - `CODE_SERVER_WORKSPACE`: 默认 "/workspace"

### 4. start.sh 更新
- 新增 code-server 启动逻辑
- 新增 PID_CODE_SERVER 进程端口管理
- 添加 9000 到 EXPOSE
- 新增启动诊断信息输出

### 5. 启动诊断信息 (start.sh)
启动时输出以下信息，方便调试和确认构建版本：

```bash
# 构建版本
📦 Git Commit: abc12345

# 系统信息
🖥️  OS: Ubuntu 22.04.3 LTS
🐳 Container ID: abc123def456

# GPU 信息
🎮 GPU Count: 1
🎮    GPU: NVIDIA H200 SXM2-141GB, 141GB, 535.154.03, 12.2

# AI 组件
🐍 Python: 3.11.x
🔥 vLLM: 0.16.1.dev
🌐 SGLang: 0.x.x
🦙 llama.cpp: 1.x

# 工具链
🤖 OpenCode: 1.2.15
📝 code-server: 4.x.x
📦 Node.js: 22.14.0
🧊 Bun: 1.x.x
📐 pnpm: 10.28.1
```

### 6. Dockerfile Git Commit 记录
在 Dockerfile 中添加 .git_commit 文件生成，确保运行时可获取构建版本：

```dockerfile
RUN if command -v git >/dev/null 2>&1 && [[ -d /workspace/.git ]]; then \
      git -C /workspace rev-parse HEAD > /workspace/.git_commit; \
    else \
      echo "unknown" > /workspace/.git_commit; \
    fi
```

## 验证结果

当前容器诊断输出示例（重建后将显示完整信息）：

```
[INFO] ==========================================
[INFO] 🚀 Container Startup Diagnostics
[INFO] ==========================================
[INFO] --- Build Info ---
[INFO] 📦 Git Commit: abc12345          # 重建后显示
[INFO] --- System Info ---
[INFO] 🖥️  OS: Ubuntu 22.04.4 LTS
[INFO] 🕐 Start Time: 2026-03-01 14:40:56 UTC
[INFO] 🐳 Container ID: nn-h200-136-141g-1-xxx
[INFO] --- GPU Info ---
[INFO] 🎮 GPU Count: 2
[INFO]    GPU: NVIDIA H200, 141GB, 575.57.08
[INFO]    CUDA: 12.9
[INFO] --- AI Components ---
[INFO] 🐍 Python: Python 3.10.12
[INFO] 🔥 vLLM: 0.16.1.dev              # 重建后显示
[INFO] 🌐 SGLang: 0.6.0+                # 重建后显示
[INFO] --- Inference Engine ---
[INFO] 🦙 llama.cpp: v8182 (05728db18)
[INFO] --- Additional Tools ---
[INFO] 🤖 OpenCode: 1.2.15
[INFO] 📝 code-server: 4.97.2            # 重建后显示
[INFO] 📦 Node.js: v22.14.0
[INFO] 🧊 Bun: 1.3.10
[INFO] 📐 pnpm: 10.28.1
[INFO] ==========================================
[INFO] ✅ Diagnostics Complete
[INFO] ==========================================
```

## 已知问题

### Step-3.5-Flash-FP8 GPU 需求
- 官方文档要求 **4xH200 GPUs** 才能运行
- 当前硬件: 单个 H200 MIG 7g.141gb (~141GB)
- **结论**: 硬件不足，无法运行 Step-3.5-Flash-FP8

### 替代方案
- 尝试 Qwen3.5-27B-FP8 (需要 tensor parallel size 2)

## 相关文件
- `/workspace/repos/Run-ComfyUI-Ollama/Dockerfile`
- `/workspace/repos/Run-ComfyUI-Ollama/start.sh`
