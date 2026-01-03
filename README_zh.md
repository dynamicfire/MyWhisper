# MyWhisper

在 macOS 上实现全局语音听写：按快捷键说话，自动转成文字并粘贴到当前光标位置。

中英混说 / 本地离线 / 准确优先 / 全局听写输入

| 特点 | 说明 |
|------|------|
| **本地离线** | 使用 whisper.cpp 本地运行，音频不上传云端 |
| **中英混说** | 自动识别中英文混合内容，无需切换 |
| **后台静默** | sox 后台录音，不弹窗、不抢焦点 |
| **一键操作** | 按一次开始录音，再按一次停止并粘贴 |
| **提示音反馈** | 开始/停止时播放系统音效确认状态 |
| **自动粘贴** | 转写结果自动复制到剪贴板并粘贴 |

**工作流程**

```
快捷键 → 听到提示音 → 说话 → 再按一次快捷键 → 结束提示音 → 转写 → 自动粘贴
```

**依赖**：`whisper-cpp`（语音转文字）、`ffmpeg`（音频转换）、`sox`（后台录音）

---

## 目标效果

* 本地离线运行 Whisper（不上传音频）
* 中英混说自动识别
* 说完自动得到文本：**复制到剪贴板** + **自动粘贴到当前光标**
* 用 **macOS Shortcuts** 绑定热键，接近"输入法体验"
* 后台录音，不弹窗，不丢失输入焦点

---

## 1) 安装依赖

```bash
brew install whisper-cpp ffmpeg sox
```

验证安装：

```bash
which whisper-cli ffmpeg sox
```

---

## 2) 下载模型（准确优先）

推荐：**ggml-large-v3.bin**（更准但更大、更吃内存）

```bash
mkdir -p ~/models/whisper
curl -L -o ~/models/whisper/ggml-large-v3.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin?download=true"
```

> 备选：`ggml-large-v3-q5_0.bin`（量化版，更省资源，准确率通常略低）。

---

## 3) 准备 prompt 词库（增强中英混说和专有名词）

```bash
mkdir -p ~/.config/whisper
cat > ~/.config/whisper/prompt.txt <<'EOF'
日常口述输入。请按原语言输出：中文用中文标点；英文术语保持原样（大小写不变）；不要翻译产品名/缩写。

编程语言：Python, JavaScript, TypeScript, Go, Rust, Swift, Kotlin, Java, C++, Ruby, PHP, Scala
前端框架：React, Vue, Angular, Next.js, Nuxt, Svelte, Flutter, SwiftUI, Tailwind, Bootstrap
后端框架：Django, FastAPI, Flask, Express, NestJS, Spring Boot, Rails, Laravel, Gin
数据库：MySQL, PostgreSQL, MongoDB, Redis, SQLite, Elasticsearch, DynamoDB, Cassandra
云服务：AWS, GCP, Azure, Vercel, Netlify, Cloudflare, DigitalOcean, Heroku
DevOps：Docker, Kubernetes, Terraform, Ansible, Jenkins, GitHub Actions, GitLab CI, ArgoCD
AI/ML：OpenAI, GPT, Claude, LLM, RAG, Embedding, PyTorch, TensorFlow, Hugging Face, LangChain
工具：Git, npm, yarn, pnpm, pip, Homebrew, VS Code, Vim, Neovim, Xcode, IntelliJ
格式：JSON, YAML, XML, Markdown, CSV, Parquet, Protobuf, GraphQL, REST API
缩写：API, SDK, CLI, UI, UX, CI/CD, ORM, JWT, OAuth, SSO, CRUD, MVC, SaaS, PaaS
EOF
```

---

## 4) 转写脚本

创建脚本：`~/bin/whisper_dictate.sh`

```bash
mkdir -p ~/bin
cat > ~/bin/whisper_dictate.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

FFMPEG="/opt/homebrew/bin/ffmpeg"
WHISPER="/opt/homebrew/bin/whisper-cli"

IN="${1:?need an input audio file path}"

MODEL="${WHISPER_MODEL:-$HOME/models/whisper/ggml-large-v3.bin}"
PROMPT_FILE="${WHISPER_PROMPT_FILE:-$HOME/.config/whisper/prompt.txt}"
PASTE="${PASTE:-1}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

WAV="$WORK/in.wav"
OUT="$WORK/out"

"$FFMPEG" -hide_banner -loglevel error -y \
  -i "$IN" -ar 16000 -ac 1 -c:a pcm_s16le "$WAV"

PROMPT=""
if [[ -f "$PROMPT_FILE" ]]; then
  PROMPT="$(tr '\n' ' ' < "$PROMPT_FILE" | sed 's/[[:space:]][[:space:]]*/ /g' | sed 's/^ *//; s/ *$//')"
fi

THREADS="$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"

"$WHISPER" \
  -m "$MODEL" \
  -f "$WAV" \
  -t "$THREADS" \
  -l auto \
  --prompt "$PROMPT" \
  -nt \
  -otxt -of "$OUT" \
  -np >/dev/null 2>&1

TXT="${OUT}.txt"
tr -d '\r' < "$TXT" | LC_ALL="en_US.UTF-8" pbcopy

if [[ "$PASTE" == "1" ]]; then
  osascript -e 'tell application "System Events" to keystroke "v" using {command down}'
fi

cat "$TXT"
BASH

chmod +x ~/bin/whisper_dictate.sh
```

---

## 5) Toggle 脚本（后台录音控制）

创建脚本：`~/bin/whisper_toggle.sh`

```bash
cat > ~/bin/whisper_toggle.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

CACHE_DIR="$HOME/.cache/whisper"
PID_FILE="$CACHE_DIR/recording.pid"
WAV_FILE="$CACHE_DIR/recording.wav"
DICTATE_SCRIPT="$HOME/bin/whisper_dictate.sh"

mkdir -p "$CACHE_DIR"

is_recording() {
    [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

start_recording() {
    rm -f "$WAV_FILE"
    afplay /System/Library/Sounds/Blow.aiff &
    /opt/homebrew/bin/sox -q -d -c 1 -r 16000 -b 16 "$WAV_FILE" >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
}

stop_recording() {
    local pid
    pid="$(cat "$PID_FILE")"
    kill -INT "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"

    afplay /System/Library/Sounds/Pop.aiff &

    if [[ -f "$WAV_FILE" ]]; then
        "$DICTATE_SCRIPT" "$WAV_FILE"
        rm -f "$WAV_FILE"
    fi
}

if is_recording; then
    stop_recording
else
    start_recording
fi
BASH

chmod +x ~/bin/whisper_toggle.sh
```

---

## 6) Shortcuts 配置

新建快捷指令 **Dictate (Local Whisper)**：

1. **Run Shell Script（运行 Shell 脚本）**
   * Shell：`/bin/zsh`
   * 传递输入：无
   * 脚本内容：

```bash
/Users/你的用户名/bin/whisper_toggle.sh
```

2. 给这个快捷指令绑定键盘快捷键（例如 `⌥Space`）

---

## 7) 权限设置

需要允许以下权限：

* **麦克风**：系统设置 → 隐私与安全 → 麦克风 → 勾选 **Terminal** 和 **Shortcuts**
* **辅助功能**（自动粘贴需要）：系统设置 → 隐私与安全 → 辅助功能 → 勾选 **Shortcuts**

---

## 8) 使用方式

| 操作 | 效果 |
|------|------|
| 按一次快捷键 | 播放提示音，开始录音（后台静默） |
| 再按一次快捷键 | 播放提示音，停止录音 → 转写 → 自动粘贴 |

---

## 9) 终端测试

```bash
# 开始录音
~/bin/whisper_toggle.sh

# 说几句话...

# 停止并转写
~/bin/whisper_toggle.sh

# 查看剪贴板内容
pbpaste
```

---

## 10) 常见问题

| 问题 | 解决方案 |
|------|----------|
| 自动粘贴无效 | 检查辅助功能权限 |
| 首次运行无反应 | 等待麦克风权限弹窗并允许 |

---

## 推荐默认值

* 模型：`ggml-large-v3.bin`
* 语言：`-l auto`（中英混说）
* prompt：简短规则 + 专有名词词表
