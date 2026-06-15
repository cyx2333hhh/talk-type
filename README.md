# Murmur — Mac 语音输入法

按一个快捷键开始说话，再按一次后自动：**语音转文字 → 智能整理排版 + 纠正表达错误 → 插入到当前光标处**。常驻菜单栏，带简约高级的悬浮动画。

- **语音转文字**：始终用 Mac 本地 `SFSpeechRecognizer`（免费、离线、开箱即用）。DeepSeek 没有语音接口，故 STT 一律本地完成。
- **整理 / 纠错（DeepSeek Key 可选）**：
  - 不填 Key → 直接插入本地识别的原文
  - 填了 Key → 本地识别后再用 **DeepSeek**（`deepseek-chat`）做断句、标点、分段、去口水词、纠正口误与表达错误
- **实时预览**：录音时用苹果本地识别边说边显示文字
- **录音动画**：小巧灵动的毛玻璃胶囊 + 平滑**流动声纹**（单色、克制、高级）
- **交互**：全局快捷键「按一下开始 / 再按一下停止」（默认 **fn 键**，可改自定义组合键）
- **界面**：常规应用，**有 Dock 图标 + 主窗口**（启动即开、点 Dock 可重开），同时保留菜单栏弹窗（大录音按钮 + 实时状态 + 最近记录，可一键复制）
- **形态**：原生 SwiftUI App，自带黑白 App 图标 + 菜单栏模板图标

## 运行

1. 打开工程：
   ```bash
   open Murmur.xcodeproj
   ```
2. 在 Xcode 选中 `Murmur` target → Signing & Capabilities，确认 Team（已预填 `7HD58DCN44`，需要时换成你自己的），保持 **未开启 App Sandbox**（默认即未开启——粘贴到其它 App 需要这一点）。
3. `⌘R` 运行。菜单栏出现 🎙️ 图标。

命令行构建（这台机器需要 `DEVELOPER_DIR`）：
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Murmur.xcodeproj -target Murmur -configuration Debug build
```

## 首次设置（主窗口或菜单栏 →「设置…」）

1. **DeepSeek API Key（可选）**：留空即只用 Mac 本地识别插入原文；填入 `sk-…` 则在本地识别后用 DeepSeek 智能整理 / 纠错（保存在系统钥匙串）。
2. **权限**：
   - **麦克风** —— 点「去开启」授权（用于录音）。
   - **语音识别** —— 点「去开启」授权（本地识别 / 实时预览都要用；不填 Key 时是主识别引擎）。
   - **辅助功能** —— 点「去开启」，在系统设置里勾选 Murmur（用于模拟 ⌘V 自动粘贴）。
     未授权时不会自动粘贴，结果会留在剪贴板，手动按 ⌘V 即可。
3. **录音体验**：可开关「录音时实时转写预览」。
4. **快捷键**：默认 **fn 键**。可点「用 fn 键」，或点当前按钮后按下任意自定义组合键。
   - fn 全局触发需要「辅助功能」权限；若按 fn 弹出表情面板，去 系统设置→键盘→「按 🌐 键时」设为「无操作」。
5. **模型 / 语言**（可选，有默认值）：
   - 整理模型：`deepseek-chat`（默认）或 `deepseek-reasoner`
   - 语言：本地识别语言，默认 `zh`，留空为自动识别
   - 可关闭「用 DeepSeek 整理 / 纠错」，只做本地纯转写

## 使用

1. 在任意 App（备忘录、微信、浏览器输入框…）把光标放到要输入的位置。
2. 按 **fn 键**（或点菜单栏弹窗里的录音按钮）→ 悬浮面板出现，开始说话（红点 + 动画 + 计时）。
3. 再按一次 fn → 面板显示「转写中 → 智能整理 → 插入」，完成后文本自动出现在光标处。

点菜单栏图标会弹出**主界面**：大录音按钮、当前状态、最近记录（可复制 / 删除 / 清空）、设置入口。

完成后悬浮胶囊上有**「复制」按钮**：当自动粘贴落点不准时，点它即可把本次结果复制到剪贴板自行粘贴（主界面「最近」里每条也能复制）。

## 工作流程

```
fn 键 / 录音按钮 → 录音(.wav) → Mac 本地识别 → [可选] DeepSeek 整理/纠错 → 写入剪贴板 + 模拟⌘V → 还原剪贴板
```

> 隐私：音频不出本机（本地识别）；只有当填了 DeepSeek Key 且开启整理时，识别出的**文本**会发给 DeepSeek 做润色。

源码结构（`Murmur/`）：

| 文件 | 职责 |
|------|------|
| `MurmurApp.swift` | App 入口、菜单栏、accessory 策略 |
| `AppState.swift` | 状态机与整体流程编排、设置读取 |
| `AudioCapture.swift` | AVAudioEngine：写文件 + 实时电平 + 本地识别（实时预览 + 文件最终转写） |
| `DeepSeekClient.swift` | DeepSeek 对话 API（仅文本整理/纠错；OpenAI 兼容） |
| `TextInserter.swift` | 剪贴板 + 模拟 ⌘V 粘贴（含剪贴板还原） |
| `HotKeyManager.swift` | Carbon 全局快捷键（自定义组合键时用） |
| `FnKeyMonitor.swift` | fn / 🌐 键监听（flagsChanged，keyCode 63） |
| `KeychainHelper.swift` | DeepSeek Key 钥匙串读写 |
| `PanelController.swift` | 固定尺寸非激活悬浮面板（小巧灵动胶囊） |
| `RecordingOverlayView.swift` | 悬浮胶囊：流动声纹动画、实时预览、状态、完成态「复制」按钮 |
| `WaveAnimation.swift` | 流动声纹动画 `FlowWaveView`（Canvas 平滑曲线 + 渐变 + 辉光） |
| `HomeView.swift` | 主界面：录音按钮 + 状态 + 最近记录（用于主窗口和菜单栏弹窗） |
| `MainWindowController.swift` | 主窗口（AppKit 托管，启动/点 Dock 时显示） |
| `SettingsView.swift` | 设置面板 + 快捷键录制 |
| `SettingsWindowController.swift` | AppKit 托管的设置窗口 |
| `Assets.xcassets` | App 图标全套尺寸 + 菜单栏模板图标 |

图标是用 `Murmur-icongen.swift`（CoreGraphics 脚本）程序化生成的；要改配色/造型，编辑该脚本后重跑 `swift Murmur-icongen.swift` 即可重新生成整套资源。

## 说明与边界

- **未签名/沙盒**：为了能把文字粘贴进其它 App 并模拟按键，App **不开启沙盒**；自动粘贴依赖系统「辅助功能」授权。
- **隐私**：音频不出本机（本地识别）；仅在填了 DeepSeek Key 且开启整理时，识别出的文本会发给 DeepSeek 润色。
- **快捷键**：默认 fn 键（需辅助功能权限才能全局触发）；可在设置改成自定义组合键。fn 若触发系统🌐行为，把 系统设置→键盘→「按🌐键时」设为「无操作」。
- **测试**：核心链路依赖实时麦克风、网络与系统级权限（TCC），难以做有意义的自动化 UI 测试；当前以「构建通过 + 启动冒烟」为验证基线，建议手动走一遍真实链路。
