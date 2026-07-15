<div align="center">

<img src="docs/icon.png" width="128" alt="Talk-type 图标" />

# Talk-type

**按一下，说话，再按一下。文字就落在光标那里。**

一款给 macOS 用的语音输入工具，中文为主，也认真处理夹在中文里的英文。

![macOS](https://img.shields.io/badge/macOS-14%2B-111111)
![Swift](https://img.shields.io/badge/Swift-5-F05138)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0A84FF)
![License](https://img.shields.io/badge/license-MIT-3EB489)

[中文](#中文) · [English](#english)

</div>

<p align="center">
  <img src="docs/shot-main.png" width="620" alt="Talk-type 主界面" />
</p>

## 中文

### 为什么做 Talk-type

我想要的语音输入其实很简单：光标在哪里，话就输入到哪里。它应该像键盘一样随手，而不是先打开一个聊天窗口，再复制一遍结果。

真正用起来，麻烦通常出在两个地方。

第一个是中英混合。中文句子里只要出现 `GitHub`、`SwiftUI`、`API` 或一个不常见的产品名，识别结果就很容易跑偏。第二个是文本整理。有些模型看到问句会顺手回答，看到重复会主动删掉，最后得到的文字更“漂亮”，却不是我刚才说的内容。

Talk-type 就围绕这两个问题做：识别尽量准，整理尽量克制。你说的是问句，它就输入问句；你口述的是命令、提示词或代码，它也只把这些内容放到光标处，不替你执行。

名字里的 `T` 同时来自 Talk 和 Type。图标的白色横线是声音，青绿色竖线是输入光标，两部分合在一起才是完整的 T。

### 日常怎么用

把光标放进聊天框、文档、搜索框、代码注释或任何能输入文字的地方：

1. 按一次 `fn / 🌐` 开始录音。
2. 正常说话，浮层会显示音量、时间和实时预览。
3. 再按一次停止。
4. Talk-type 完成最终识别和可选整理，把文字插入当前光标位置。

默认快捷键可以修改。菜单栏入口、主窗口里的麦克风按钮也能开始录音。最近 50 条结果保存在本机，自动粘贴失败时还可以直接复制。

### 它实际做了什么

Talk-type 把“听清楚”和“整理好”拆成了两步。

录音开始后，程序一边把音频写入临时 WAV，一边用 Apple Speech 显示实时预览。停止录音后，如果本机已经装好 Whisper Small，就由 Whisper 完成最终转写；没有安装、执行失败或没有得到结果时，再回退到 Apple Speech。

Whisper 会收到一个很短的提示，其中包含中英词库和光标前文。这样做是为了帮助它认出英文专名，但不会把大量英文词硬塞进提示里，避免普通中文被识别成英文。

如果打开 DeepSeek 整理，转写完成后才会发送文字。它负责补标点、断句、分段、匹配列表格式，以及修正很明确的错字和英文大小写。它不参与录音，也不是语音识别引擎。

整理结果不会直接照单全收。Talk-type 还会做一次本地检查：结果突然变长或变短、数字丢失、把输入框旧内容复制进来，或者把一段中文大面积改成英文，都会被拒绝，最后改用原始转写。

```text
按下快捷键
    ↓
临时录音 + Apple Speech 实时预览
    ↓
Whisper Small 本地最终转写
    ↓ 失败时自动回退
Apple Speech 最终识别
    ↓
DeepSeek 保守整理（可关闭）
    ↓
本地完整性检查
    ↓
插入光标位置，并还原原来的剪贴板
```

### 输入框上下文

开启“参考输入框上下文”后，Talk-type 会在录音开始时读取光标附近最多 800 个字符。这个上下文只用来判断：

- 当前是在写普通段落、列表还是代码式文本；
- 应该沿用什么标点、换行、大小写和语气；
- 某个同音词或英文专名在前文里是怎么写的。

它不会把旧内容拼到新结果里，也不会让 DeepSeek 回答或续写输入框里的文字。关闭这个选项后，Talk-type 不会读取光标附近内容。

<p align="center">
  <img src="docs/shot-settings.png" width="720" alt="Talk-type 识别与整理设置" />
</p>

<p align="center"><sub>识别引擎、实时预览、上下文和文本整理可以分别控制。</sub></p>

### 中英混合词库

设置页里的“中英词库”不是一套只能识别固定单词的词典。它更像一组提示词，用来告诉识别器“这段话里可能出现这些写法”。

默认包含常见技术词，例如 `DeepSeek`、`ChatGPT`、`Claude`、`OpenAI`、`Swift`、`Xcode`、`GitHub` 和 `Python`。你可以删掉不需要的词，也可以加入自己的项目名、人名、公司名或行业术语。

词库只提供参考，不会把没有说过的词强行插入结果。Whisper 最多取前 24 个词作为短提示，DeepSeek 整理最多参考前 80 个词。

### 本地识别与 DeepSeek

不填 DeepSeek API Key，Talk-type 仍然可以正常录音、识别和输入。两者的分工是：

- **Whisper Small / Apple Speech**：把声音变成文字。
- **DeepSeek**：在已有文字上做一次可选的保守整理。

本机使用的 Whisper Small 模型约 465 MB。模型装好后，最终转写优先在本地完成；Apple Speech 继续负责实时预览和自动回退。

### 隐私说明

- 临时录音会在本次处理结束后删除。
- Whisper Small 完全在本机运行。
- Apple Speech 是否联网由 macOS、语言和设备支持情况决定。
- DeepSeek 只在你主动开启整理并填写 Key 时收到本次转写、可选英文辅助结果和光标上下文；音频不会发给 DeepSeek。
- API Key 保存在 macOS 钥匙串，不写入项目文件或 UserDefaults。
- 最近记录保存在本机，可以随时清空。

### 当前限制

- Whisper Small 需要另外安装 `whisper-cli` 和模型文件，目前没有内置下载器。
- Apple Speech 的实时预览只是参考，可能和最终 Whisper 结果不同。
- 全局 `fn`、读取光标上下文和自动粘贴需要辅助功能权限。
- 某些使用自定义编辑器的 App 不接受模拟粘贴，这种情况下结果会保留在剪贴板。
- 项目目前以源码形式发布，还没有做面向普通用户的签名安装包和自动更新。

### 安装 Whisper Small

Talk-type 会在下面两个位置查找 `whisper-cli`：

```text
/opt/homebrew/bin/whisper-cli
/usr/local/bin/whisper-cli
```

模型文件名应为 `ggml-small.bin`，推荐放在：

```text
~/Library/Application Support/Talk-type/Models/ggml-small.bin
```

旧版本使用过的路径仍然兼容：

```text
~/Library/Application Support/Murmur/Models/ggml-small.bin
```

### 从源码构建

```bash
git clone https://github.com/cyx2333hhh/murmur-mac.git
cd murmur-mac
open Murmur.xcodeproj
```

在 Xcode 中选择 `Murmur` target，设置自己的 Development Team 后运行。跨 App 读取和插入文字需要保持 App Sandbox 关闭。

无签名命令行构建：

```bash
xcodebuild -project Murmur.xcodeproj -target Murmur CODE_SIGNING_ALLOWED=NO build
```

产物位于 `build/Release/Talk-type.app`。项目会同时构建 Apple Silicon 和 Intel 架构。

### 代码结构

- `AudioCapture.swift`：录音、实时预览和音量数据
- `LocalWhisperTranscriber.swift`：调用本地 whisper.cpp
- `DeepSeekClient.swift`：保守文本整理提示和请求
- `TextInserter.swift`：读取输入框上下文、插入文字并还原剪贴板
- `AppState.swift`：识别流程、回退策略、结果检查和历史记录
- `RecordingOverlayView.swift`：录音与处理状态浮层
- `Murmur-icongen.swift`：生成 App 图标和菜单栏图标

---

## English

Talk-type is a macOS voice typing tool built for one narrow job: put the words you speak at the cursor.

It does not open a chat of its own, answer spoken questions, or execute dictated commands. A question stays a question. A prompt stays a prompt. The app separates transcription from cleanup so formatting can improve without silently changing what was said.

The final transcript prefers local Whisper Small, with Apple Speech used for live preview and fallback. A custom vocabulary helps with English names inside Chinese speech. Optional cursor context can match the surrounding list, punctuation, casing, and terminology.

DeepSeek is optional and runs only after transcription. Its output is checked locally and rejected when it drops numbers, removes too much content, repeats existing cursor context, expands unexpectedly, or turns Chinese into unrelated English. When that happens, Talk-type inserts the raw transcript instead.

### Quick use

1. Put the cursor in any editable field.
2. Press `fn / 🌐` and speak.
3. Press it again to stop.
4. Talk-type transcribes, optionally tidies, and inserts the result.

The app keeps up to 50 recent results locally and leaves a copy on the clipboard when automatic insertion is unavailable.

### Privacy

Temporary audio is deleted after processing. Whisper runs locally. Apple Speech behavior depends on macOS and language support. DeepSeek receives text and optional cursor context only when cleanup is enabled, and never receives the audio. The API key is stored in the macOS Keychain.

### Build

```bash
git clone https://github.com/cyx2333hhh/murmur-mac.git
cd murmur-mac
xcodebuild -project Murmur.xcodeproj -target Murmur CODE_SIGNING_ALLOWED=NO build
```

The resulting app is `build/Release/Talk-type.app`. Select the `Murmur` target and your own Development Team when building in Xcode. App Sandbox must remain disabled for cross-application context reading and insertion.

---

## License

Talk-type is released under the [MIT License](LICENSE).
