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
