# MyWhisper

Global voice dictation on macOS: press a hotkey to speak, automatically transcribe and paste text at cursor.

Bilingual (Chinese/English, or whatever language you want) / Local & Offline / Accuracy First / Global Dictation

[中文文档](README_zh.md)

| Feature | Description |
|---------|-------------|
| **Local & Offline** | Runs whisper.cpp locally, audio never leaves your machine |
| **Bilingual** | Auto-detects mixed Chinese/English content |
| **Background Recording** | sox records silently, no popup windows, no focus stealing |
| **One-Key Toggle** | Press once to start, press again to stop and paste |
| **Audio Feedback** | System sounds confirm recording start/stop |
| **Auto Paste** | Transcription copied to clipboard and pasted automatically |

**Workflow**

```
Hotkey → Sound → Speak → Hotkey → Sound → Transcribe → Auto Paste
```

**Dependencies**: `whisper-cpp` (speech-to-text), `ffmpeg` (audio conversion), `sox` (background recording)

---

## Goals

* Run Whisper locally (audio never uploaded)
* Auto-detect mixed Chinese/English speech
* Auto copy to clipboard + paste at cursor
* Bind to hotkey via **macOS Shortcuts** for IME-like experience
* Background recording without popups or focus loss

---

## 1) Install Dependencies

```bash
brew install whisper-cpp ffmpeg sox
```

Verify installation:

```bash
which whisper-cli ffmpeg sox
```

---

## 2) Download Model (Accuracy Priority)

Recommended: **ggml-large-v3.bin** (more accurate, larger, more memory)

```bash
mkdir -p ~/models/whisper
curl -L -o ~/models/whisper/ggml-large-v3.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin?download=true"
```

> Alternative: `ggml-large-v3-q5_0.bin` (quantized, lighter, slightly less accurate)

---

## 3) Prepare Prompt Dictionary (Enhance Recognition)

```bash
mkdir -p ~/.config/whisper
cat > ~/.config/whisper/prompt.txt <<'EOF'
Daily dictation input. Output in original language: use proper punctuation; keep English terms as-is (preserve case); don't translate product names/abbreviations.

Languages: Python, JavaScript, TypeScript, Go, Rust, Swift, Kotlin, Java, C++, Ruby, PHP, Scala
Frontend: React, Vue, Angular, Next.js, Nuxt, Svelte, Flutter, SwiftUI, Tailwind, Bootstrap
Backend: Django, FastAPI, Flask, Express, NestJS, Spring Boot, Rails, Laravel, Gin
Databases: MySQL, PostgreSQL, MongoDB, Redis, SQLite, Elasticsearch, DynamoDB, Cassandra
Cloud: AWS, GCP, Azure, Vercel, Netlify, Cloudflare, DigitalOcean, Heroku
DevOps: Docker, Kubernetes, Terraform, Ansible, Jenkins, GitHub Actions, GitLab CI, ArgoCD
AI/ML: OpenAI, GPT, Claude, LLM, RAG, Embedding, PyTorch, TensorFlow, Hugging Face, LangChain
Tools: Git, npm, yarn, pnpm, pip, Homebrew, VS Code, Vim, Neovim, Xcode, IntelliJ
Formats: JSON, YAML, XML, Markdown, CSV, Parquet, Protobuf, GraphQL, REST API
Acronyms: API, SDK, CLI, UI, UX, CI/CD, ORM, JWT, OAuth, SSO, CRUD, MVC, SaaS, PaaS
EOF
```

---

## 4) Transcription Script

Create script: `~/bin/whisper_dictate.sh`

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

## 5) Toggle Script (Background Recording Control)

Create script: `~/bin/whisper_toggle.sh`

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

## 6) Shortcuts Configuration

Create a new Shortcut named **Dictate (Local Whisper)**:

1. **Run Shell Script**
   * Shell: `/bin/zsh`
   * Pass Input: None
   * Script content:

```bash
/Users/YOUR_USERNAME/bin/whisper_toggle.sh
```

2. Assign a keyboard shortcut (e.g., `⌥Space`)

---

## 7) Permissions

Grant the following permissions:

* **Microphone**: System Settings → Privacy & Security → Microphone → Enable **Terminal** and **Shortcuts**
* **Accessibility** (for auto-paste): System Settings → Privacy & Security → Accessibility → Enable **Shortcuts**

---

## 8) Usage

| Action | Result |
|--------|--------|
| Press hotkey once | Sound plays, recording starts (silent background) |
| Press hotkey again | Sound plays, recording stops → transcribe → auto paste |

---

## 9) Terminal Testing

```bash
# Start recording
~/bin/whisper_toggle.sh

# Speak...

# Stop and transcribe
~/bin/whisper_toggle.sh

# Check clipboard
pbpaste
```

---

## 10) Troubleshooting

| Issue | Solution |
|-------|----------|
| Auto-paste not working | Check Accessibility permissions |
| No response on first run | Wait for microphone permission prompt and allow |

---

## Recommended Defaults

* Model: `ggml-large-v3.bin`
* Language: `-l auto` (bilingual)
* Prompt: Brief rules + terminology list
