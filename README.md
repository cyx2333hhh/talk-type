<div align="center">

<img src="docs/icon.png" width="128" alt="Talk-type icon" />

# Talk-type

**macOS 语音输入工具**

![macOS](https://img.shields.io/badge/macOS-14%2B-111111)
![License](https://img.shields.io/badge/license-MIT-3EB489)

[开始了解](#zh) · [English](#en)

</div>

<a id="zh"></a>

## Talk-type

Talk-type 面向 macOS 的中文、英文和中英混合语音输入。可在设置中切换中文或 English 作为主要识别语言，中英混合识别默认开启。它将实时语音识别、文本整理和跨应用输入整合在一起，适合写作、聊天、笔记和日常办公。

<p align="center">
  <img src="docs/shot-main.png" width="620" alt="Talk-type 主窗口" />
</p>

### 功能

- **实时识别与纠错**：录音时实时显示转写内容；开启 AI 整理后，文本会在录音期间同步更新，结束后可看到识别、整理和写入状态。
- **中文、英文与中英混合输入**：可在设置中切换中文或英文作为主要识别语言；中英混合识别默认开启，以另一种语言辅助复核。
- **本地 Whisper 回退**：Apple Speech 无结果时，可使用本机 Whisper Small 继续识别。
- **多 AI 整理**：支持 DeepSeek、Anthropic（Claude）、OpenAI、xAI（Grok）、Qwen（通义千问）和 Kimi（月之暗面）。
- **上下文整理**：结合光标附近文本处理标点、断句、空格和句中插入。
- **跨应用输入**：通过 macOS 辅助功能写入当前输入框；不支持时保留到剪贴板。
- **全局快捷键与历史记录**：支持 `fn` 和自定义快捷键，最近输入保存在本机。

### 配置

首次使用时，在「设置 → 权限」中开启麦克风、语音识别和辅助功能权限。在「设置 → 识别与整理」中选择中文或 English 作为输入语言；中英混合识别默认开启。AI 整理为可选功能，可在同一页面选择服务、填写 API Key 和模型 ID；不同服务的配置独立保存。

### 安装

当前暂未提供 DMG 安装包，可从源码运行：

```bash
git clone https://github.com/cyx2333hhh/talk-type.git
cd talk-type
open Murmur.xcodeproj
```

需要 macOS 14 或更高版本和 Xcode。使用本地 Whisper 回退时，请自行安装 `whisper-cli` 和 Whisper Small 模型。

### 致谢

Talk-type 使用 Apple Speech、AVFoundation 和 [whisper.cpp](https://github.com/ggerganov/whisper.cpp)。项目开发过程中使用了 **OpenAI Codex** 协作完成方案讨论、实现与验证。

### 许可证

[MIT License](LICENSE)

---

<a id="en"></a>

## About Talk-type

Talk-type is a macOS voice input tool for Chinese, English, and mixed Chinese-English input. Choose Chinese or English as the primary recognition language in Settings; mixed Chinese-English recognition is enabled by default. It brings live speech recognition, text cleanup, and cross-app input together for writing, messaging, note-taking, and everyday work.

### Features

- **Live recognition and cleanup**: Shows the live transcript while recording. With AI cleanup enabled, the text updates during recording and the app shows recognition, cleanup, and insertion status after recording ends.
- **Chinese, English, and mixed input**: Choose Chinese or English as the primary recognition language. Mixed Chinese-English recognition is on by default and uses the other language as a second pass.
- **Local Whisper fallback**: Uses local Whisper Small when Apple Speech returns no result.
- **Multiple AI providers**: Supports DeepSeek, Anthropic (Claude), OpenAI, xAI (Grok), Qwen, and Kimi (Moonshot).
- **Context-aware cleanup**: Uses nearby cursor text to handle punctuation, sentence breaks, spacing, and inline insertion.
- **Cross-app input**: Writes into the focused field through macOS Accessibility, or keeps the text on the clipboard when unavailable.
- **Global shortcuts and local history**: Supports `fn` and custom shortcuts; recent input stays on the Mac.

### Setup

On first use, grant Microphone, Speech Recognition, and Accessibility permissions in **Settings → Permissions**. In **Settings → Recognition & Cleanup**, choose Chinese or English as the input language; mixed Chinese-English recognition is enabled by default. AI cleanup is optional. On the same page, choose a provider and enter its API key and model ID; settings are stored separately for each provider.

### Installation

There is no DMG release yet. Run from source instead:

```bash
git clone https://github.com/cyx2333hhh/talk-type.git
cd talk-type
open Murmur.xcodeproj
```

macOS 14 or later and Xcode are required. For local fallback transcription, install `whisper-cli` and the Whisper Small model.

### Credits

Talk-type uses Apple Speech, AVFoundation, and [whisper.cpp](https://github.com/ggerganov/whisper.cpp). **OpenAI Codex** was used during development for planning, implementation, and verification.

### License

[MIT License](LICENSE)
