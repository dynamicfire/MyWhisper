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

## 安装

```bash
git clone https://github.com/user/MyWhisper.git
cd MyWhisper
./install.sh
```

脚本会自动：
1. 通过 Homebrew 安装依赖
2. 下载 Whisper 模型（约 1.5GB）
3. 创建配置文件并部署脚本

---

## 配置

### 1) 权限设置

在 **系统设置 → 隐私与安全** 中授予以下权限：

* **麦克风** → 勾选 **Terminal** 和 **Shortcuts**
* **辅助功能**（自动粘贴需要） → 勾选 **Shortcuts**

### 2) 快捷指令配置

新建快捷指令 **Dictate (Local Whisper)**：

1. 打开 **快捷指令** App
2. 新建快捷指令 → 添加 **运行 Shell 脚本** 操作
3. 配置：
   * Shell：`/bin/zsh`
   * 传递输入：无
   * 脚本：`~/bin/whisper_toggle.sh`
4. 绑定键盘快捷键（例如 `⌥Space`）

---

## 使用方式

| 操作 | 效果 |
|------|------|
| 按一次快捷键 | 播放提示音，开始录音（后台静默） |
| 再按一次快捷键 | 播放提示音，停止录音 → 转写 → 自动粘贴 |

---

## 终端测试

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

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `WHISPER_MODEL` | `~/models/whisper/ggml-large-v3.bin` | 模型路径 |
| `WHISPER_PROMPT_FILE` | `~/.config/whisper/prompt.txt` | 提示词文件路径 |
| `PASTE` | `1` | 转写后自动粘贴（设为 0 禁用） |
| `PRESERVE_CLIPBOARD` | `1` | 粘贴后恢复原剪贴板内容 |
| `MAX_RECORDING_SECONDS` | `300` | 录音超时自动停止（秒） |
| `WHISPER_TMP_DIR` | `/tmp/mywhisper` | 临时文件目录 |

---

## 卸载

```bash
./install.sh --uninstall
```

---

## 常见问题

| 问题 | 解决方案 |
|------|----------|
| 自动粘贴无效 | 检查辅助功能权限 |
| 首次运行无反应 | 等待麦克风权限弹窗并允许 |
| 录音 5 分钟后自动停止 | 这是预期行为（MAX_RECORDING_SECONDS） |
