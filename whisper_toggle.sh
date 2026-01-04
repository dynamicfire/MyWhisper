#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# 缓存目录（使用 /tmp，系统重启会自动清理）
CACHE_DIR="${WHISPER_TMP_DIR:-/tmp/mywhisper}"
PID_FILE="$CACHE_DIR/recording.pid"
TIMEOUT_PID_FILE="$CACHE_DIR/timeout.pid"
WAV_FILE="$CACHE_DIR/recording.wav"
DICTATE_SCRIPT="$HOME/bin/whisper_dictate.sh"

# 最大录音时长（秒），默认 5 分钟
# 防止用户忘记停止导致无限录音
MAX_RECORDING_SECONDS="${MAX_RECORDING_SECONDS:-300}"

mkdir -p "$CACHE_DIR"

# 启动时清理孤立的 PID 文件（进程已不存在的情况）
cleanup_orphan_files() {
    if [[ -f "$PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$old_pid" ]] && ! kill -0 "$old_pid" 2>/dev/null; then
            rm -f "$PID_FILE" "$TIMEOUT_PID_FILE" "$WAV_FILE"
        fi
    fi
}
cleanup_orphan_files

# 检查是否正在录音
is_recording() {
    [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

# 清理超时进程
cleanup_timeout() {
    if [[ -f "$TIMEOUT_PID_FILE" ]]; then
        local timeout_pid
        timeout_pid="$(cat "$TIMEOUT_PID_FILE")"
        kill "$timeout_pid" 2>/dev/null || true
        rm -f "$TIMEOUT_PID_FILE"
    fi
}

start_recording() {
    rm -f "$WAV_FILE"
    # 播放系统提示音（开始录音）
    afplay /System/Library/Sounds/Blow.aiff &
    # sox 录音：-q 静默模式，输出重定向避免日志
    /opt/homebrew/bin/sox -q -d -c 1 -r 16000 -b 16 "$WAV_FILE" >/dev/null 2>&1 &
    local sox_pid=$!
    echo $sox_pid > "$PID_FILE"

    # 超时自动停止，防止无限录音
    (
        sleep "$MAX_RECORDING_SECONDS"
        if kill -0 "$sox_pid" 2>/dev/null; then
            # 超时前播放警告音
            afplay /System/Library/Sounds/Sosumi.aiff &
            kill -INT "$sox_pid" 2>/dev/null || true
            wait "$sox_pid" 2>/dev/null || true
            rm -f "$PID_FILE" "$TIMEOUT_PID_FILE"
            afplay /System/Library/Sounds/Pop.aiff &
            if [[ -f "$WAV_FILE" ]]; then
                "$DICTATE_SCRIPT" "$WAV_FILE"
                rm -f "$WAV_FILE"
            fi
        fi
    ) &
    echo $! > "$TIMEOUT_PID_FILE"
}

stop_recording() {
    cleanup_timeout

    local pid
    pid="$(cat "$PID_FILE")"
    kill -INT "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"

    # 播放系统提示音（停止录音）
    afplay /System/Library/Sounds/Pop.aiff &

    # 调用转写脚本
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
