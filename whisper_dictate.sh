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
# 是否保留原剪贴板内容（默认开启）
PRESERVE_CLIPBOARD="${PRESERVE_CLIPBOARD:-1}"

# 临时文件目录（使用 /tmp，系统重启会自动清理）
TMP_BASE="${WHISPER_TMP_DIR:-/tmp/mywhisper}"
CLEANUP_AGE="${WHISPER_CLEANUP_AGE:-60}"  # 清理超过 N 分钟的旧目录
mkdir -p "$TMP_BASE"

# 启动时清理过期的临时目录（防止 kill -9 导致的泄漏）
find "$TMP_BASE" -mindepth 1 -maxdepth 1 -type d -mmin +"$CLEANUP_AGE" -exec rm -rf {} \; 2>/dev/null || true

# 创建本次运行的工作目录
WORK="$TMP_BASE/run_$$_$(date +%s)"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

WAV="$WORK/in.wav"
OUT="$WORK/out"

# 保存剪贴板内容（支持文本和图片）
save_clipboard() {
    local backup_dir="$1"

    # 检测剪贴板类型
    local clip_type
    clip_type=$(osascript -e 'try
        the clipboard as «class PNGf»
        return "image"
    on error
        try
            the clipboard as text
            return "text"
        on error
            return "empty"
        end try
    end try' 2>/dev/null || echo "empty")

    echo "$clip_type" > "$backup_dir/clip_type"

    case "$clip_type" in
        image)
            # 保存图片到 PNG 文件
            osascript -e 'set pngData to the clipboard as «class PNGf»' \
                      -e "set filePath to POSIX file \"$backup_dir/clip_image.png\"" \
                      -e 'set fileRef to open for access filePath with write permission' \
                      -e 'write pngData to fileRef' \
                      -e 'close access fileRef' 2>/dev/null || true
            ;;
        text)
            # 保存文本
            pbpaste > "$backup_dir/clip_text.txt" 2>/dev/null || true
            ;;
    esac
}

# 恢复剪贴板内容
restore_clipboard() {
    local backup_dir="$1"
    local clip_type

    [[ -f "$backup_dir/clip_type" ]] || return 0
    clip_type=$(cat "$backup_dir/clip_type")

    case "$clip_type" in
        image)
            if [[ -f "$backup_dir/clip_image.png" ]]; then
                osascript -e "set filePath to POSIX file \"$backup_dir/clip_image.png\"" \
                          -e 'set imageData to read filePath as «class PNGf»' \
                          -e 'set the clipboard to imageData' 2>/dev/null || true
            fi
            ;;
        text)
            if [[ -f "$backup_dir/clip_text.txt" ]]; then
                pbcopy < "$backup_dir/clip_text.txt"
            fi
            ;;
    esac
}

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

# 保存原剪贴板（仅在需要粘贴且启用保留功能时）
if [[ "$PRESERVE_CLIPBOARD" == "1" && "$PASTE" == "1" ]]; then
    CLIP_BACKUP="$WORK/clipboard_backup"
    mkdir -p "$CLIP_BACKUP"
    save_clipboard "$CLIP_BACKUP"
fi

# 复制转录文本到剪贴板
tr -d '\r' < "$TXT" | LC_ALL="en_US.UTF-8" pbcopy

# 粘贴并恢复剪贴板
if [[ "$PASTE" == "1" ]]; then
    osascript -e 'tell application "System Events" to keystroke "v" using {command down}'

    # 等待粘贴完成后恢复原剪贴板
    if [[ "$PRESERVE_CLIPBOARD" == "1" && -d "${CLIP_BACKUP:-}" ]]; then
        sleep 0.3
        restore_clipboard "$CLIP_BACKUP"
    fi
fi

cat "$TXT"
