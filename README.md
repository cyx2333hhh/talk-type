<div align="center">

<img src="docs/icon.png" width="128" alt="Talk-type app icon" />

# Talk-type

**让说话直接成为输入。**

Local-first voice typing for macOS. Talk naturally, then let the text appear at your cursor.

![macOS](https://img.shields.io/badge/macOS-14%2B-111111)
![Swift](https://img.shields.io/badge/Swift-5-F05138)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0A84FF)
![License](https://img.shields.io/badge/license-MIT-3EB489)

[中文](#中文) · [English](#english)

</div>

---

## 中文

### Talk + Type

Talk-type 是一款面向 macOS 的本地优先语音输入工具。把光标放在任意输入框，按一下快捷键开始说话，再按一下结束，文字就会被转写、整理并插入当前光标位置。

它不是聊天助手。无论你说的是问题、命令、提示词还是代码，Talk-type 都只负责忠实地整理并输入你说过的内容，不回答问题、不执行指令，也不为了“更通顺”而随意删减信息。

### 核心体验

- **说完即输入**：默认使用 `fn / 🌐` 键开始和停止录音，结果自动插入当前输入框。
- **中英混合优化**：本地 Whisper Small 负责最终转写，Apple Speech 提供实时预览与自动回退；自定义词库可提示产品名、技术词和英文专名。
- **理解输入框上下文**：可读取光标附近最多 800 个字符，用于匹配列表、段落、标点、大小写、语气和明确术语。
- **保守的 AI 整理**：DeepSeek 只做标点、断句、分段、排版和小幅纠错；问题仍然输出为问题，原有信息优先保留。
- **本地优先**：安装 Whisper Small 后，最终语音转写在 Mac 本地完成；DeepSeek 完全可选。
- **系统级交互**：支持全局快捷键、菜单栏入口、Dock 主窗口、录音浮层、最近记录和复制兜底。

### 识别链路

| 环节 | 作用 | 是否必需 |
| --- | --- | --- |
| Whisper Small | 本地最终转写，优先处理中英混合内容 | 推荐 |
| Apple Speech | 实时预览；Whisper 不可用时作为最终回退 | 自动使用 |
| DeepSeek | 结合词库和输入框上下文，保守整理格式与表达 | 可选 |

```text
快捷键 / 录音按钮
        ↓
录制临时 WAV + Apple Speech 实时预览
        ↓
Whisper Small 本地最终转写
        ↓ 不可用时
Apple Speech 最终回退
        ↓
DeepSeek 保守整理（可选）
        ↓
插入当前光标位置，并还原原剪贴板
```

### 隐私边界

- 录音只用于本次转写，临时音频文件会在处理结束后删除。
- Whisper Small 转写完全在本机进行。
- Apple Speech 是否使用网络取决于 macOS、语言和设备支持情况。
- 只有启用 DeepSeek 时，本次转写文本、可选英文辅助结果和光标上下文才会发送给 DeepSeek；音频不会发送给 DeepSeek。
- DeepSeek API Key 只保存在 macOS 钥匙串中。
- 光标上下文只用于当前一次输入，可在设置中关闭。

### 使用方法

1. 把光标放进任意可编辑文本框。
2. 按 `fn / 🌐`，或点击 Talk-type 的录音按钮。
3. 自然说话；浮层会显示音量、状态和实时预览。
4. 再按一次快捷键停止。
5. Talk-type 完成转写与可选整理后，将文字插入光标位置。

如果目标 App 不允许自动粘贴，结果仍会保留在剪贴板，可手动按 `⌘V`。

### 环境要求

- macOS 14 Sonoma 或更高版本
- Xcode 16 或更高版本（仅构建时需要）
- 麦克风权限
- 语音识别权限（Apple Speech 实时预览与回退）
- 辅助功能权限（全局 `fn` 监听、读取输入框上下文和自动插入）

### 构建

当前开发版本位于 `GPT` 分支，`main` 保留为原始稳定线。

```bash
git clone --branch GPT https://github.com/cyx2333hhh/murmur-mac.git
cd murmur-mac
open Murmur.xcodeproj
```

在 Xcode 中选择 `Murmur` target，在 Signing & Capabilities 中设置自己的 Team，然后运行。自动插入其它 App 需要关闭 App Sandbox。

无签名命令行构建：

```bash
xcodebuild -project Murmur.xcodeproj -target Murmur CODE_SIGNING_ALLOWED=NO build
```

构建产物为 `build/Release/Talk-type.app`。

### 配置 Whisper Small

Talk-type 会在以下位置查找 `whisper-cli`：

```text
/opt/homebrew/bin/whisper-cli
/usr/local/bin/whisper-cli
```

模型文件名应为 `ggml-small.bin`，推荐放在：

```text
~/Library/Application Support/Talk-type/Models/ggml-small.bin
```

为兼容旧版本，原路径仍然可用：

```text
~/Library/Application Support/Murmur/Models/ggml-small.bin
```

未安装 Whisper 时，Talk-type 会自动使用 Apple Speech 完成最终识别。

### 配置 DeepSeek

DeepSeek 不是语音识别引擎，也不是必需依赖。它只在转写完成后执行一次可选文本整理。

在设置页填入 API Key 并打开智能整理后，可获得：

- 标点、断句和分段
- 与当前输入框一致的列表与排版
- 英文专名、大小写和明确错字的小幅纠正
- 对问题、命令和原始信息的保守保留

留空 API Key 或关闭智能整理，即可只使用本地识别链路。

### 技术结构

- `SwiftUI + AppKit`：菜单栏、主窗口、设置窗口和录音浮层
- `AVAudioEngine`：单次录音、音量采样和 WAV 写入
- `Speech`：实时预览与最终回退
- `whisper.cpp`：Whisper Small 本地最终转写
- `Accessibility API`：读取当前输入框上下文并插入文字
- `Keychain Services`：保存 DeepSeek API Key
- `CoreGraphics`：程序化生成 App 与菜单栏图标

---

## English

### Talk + Type

Talk-type is a local-first voice typing utility for macOS. Put the cursor in any editable field, press the hotkey, speak, and press it again. Your speech is transcribed, conservatively cleaned up, and inserted where you were typing.

It is an input tool, not a chatbot. Questions remain questions, commands remain text, and meaningful content is preserved instead of being answered, executed, summarized, or rewritten away.

### Highlights

- **Type by talking** with a global `fn / 🌐` shortcut or the record button.
- **Mixed Chinese and English** transcription with local Whisper Small, Apple Speech fallback, and a customizable vocabulary.
- **Cursor-aware formatting** using up to 800 nearby characters to match paragraphs, lists, punctuation, casing, tone, and known terms.
- **Conservative DeepSeek cleanup** for punctuation, sentence boundaries, layout, and small unambiguous corrections.
- **Native macOS workflow** with a menu-bar entry, centered main window, Dock presence, recording overlay, recent history, and clipboard fallback.
- **Privacy-first controls** with local transcription, optional context capture, optional AI cleanup, and Keychain-only API key storage.

### Processing pipeline

| Stage | Purpose | Required |
| --- | --- | --- |
| Whisper Small | Local final transcription, preferred for mixed-language speech | Recommended |
| Apple Speech | Live preview and final fallback | Automatic |
| DeepSeek | Conservative formatting with vocabulary and cursor context | Optional |

Audio is recorded to a temporary WAV file and deleted after processing. Whisper runs locally. Apple Speech behavior depends on macOS and language support. DeepSeek receives text and optional cursor context only when cleanup is enabled; it never receives the audio.

### Build

Active development is on the `GPT` branch. The `main` branch remains the original stable line.

```bash
git clone --branch GPT https://github.com/cyx2333hhh/murmur-mac.git
cd murmur-mac
open Murmur.xcodeproj
```

Select the `Murmur` target, choose your own development team, and run. App Sandbox must remain disabled for cross-application insertion.

Command-line build without signing:

```bash
xcodebuild -project Murmur.xcodeproj -target Murmur CODE_SIGNING_ALLOWED=NO build
```

The built application is `build/Release/Talk-type.app`.

### Local Whisper setup

Talk-type looks for `whisper-cli` in `/opt/homebrew/bin` or `/usr/local/bin`. Place `ggml-small.bin` at:

```text
~/Library/Application Support/Talk-type/Models/ggml-small.bin
```

The legacy `~/Library/Application Support/Murmur/Models/ggml-small.bin` path remains supported so existing downloads continue to work.

### DeepSeek setup

DeepSeek is optional and runs only after transcription. Add an API key in Settings to enable conservative punctuation, paragraphing, formatting, casing, and small unambiguous corrections. Leave the key empty, or disable cleanup, to use the recognition pipeline without DeepSeek.

---

## License

Talk-type is released under the [MIT License](LICENSE).
