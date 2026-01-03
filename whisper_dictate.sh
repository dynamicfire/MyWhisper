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
