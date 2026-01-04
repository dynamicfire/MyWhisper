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

## Install

```bash
git clone https://github.com/user/MyWhisper.git
cd MyWhisper
./install.sh
```

The script will:
1. Install dependencies via Homebrew
2. Download the Whisper model (~1.5GB)
3. Create config files and deploy scripts

---

## Configuration

### 1) Permissions

Grant the following permissions in **System Settings → Privacy & Security**:

* **Microphone** → Enable **Terminal** and **Shortcuts**
* **Accessibility** (for auto-paste) → Enable **Shortcuts**

### 2) Shortcuts Setup

Create a new Shortcut named **Dictate (Local Whisper)**:

1. Open **Shortcuts** app
2. Create new shortcut → Add **Run Shell Script** action
3. Configure:
   * Shell: `/bin/zsh`
   * Pass Input: None
   * Script: `~/bin/whisper_toggle.sh`
4. Assign a keyboard shortcut (e.g., `⌥Space`)

---

## Usage

| Action | Result |
|--------|--------|
| Press hotkey once | Sound plays, recording starts (silent background) |
| Press hotkey again | Sound plays, recording stops → transcribe → auto paste |

---

## Testing

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

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WHISPER_MODEL` | `~/models/whisper/ggml-large-v3.bin` | Path to Whisper model |
| `WHISPER_PROMPT_FILE` | `~/.config/whisper/prompt.txt` | Path to prompt file |
| `PASTE` | `1` | Auto-paste after transcription (0 to disable) |
| `PRESERVE_CLIPBOARD` | `1` | Restore original clipboard after paste |
| `MAX_RECORDING_SECONDS` | `300` | Auto-stop recording after N seconds |
| `WHISPER_TMP_DIR` | `/tmp/mywhisper` | Temp directory for recordings |

---

## Uninstall

```bash
./install.sh --uninstall
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Auto-paste not working | Check Accessibility permissions |
| No response on first run | Wait for microphone permission prompt and allow |
| Recording stops after 5 min | This is intentional (MAX_RECORDING_SECONDS) |
