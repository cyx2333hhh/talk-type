import SwiftUI
import AVFoundation
import Speech
import ApplicationServices
import Carbon.HIToolbox

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    @AppStorage(Keys.chatModel) private var chatModel = "deepseek-chat"
    @AppStorage(Keys.language) private var language = "zh"
    @AppStorage(Keys.recognitionEngine) private var recognitionEngine = "whisper"
    @AppStorage(Keys.recognitionContext) private var recognitionContext = Keys.defaultRecognitionContext
    @AppStorage(Keys.enableBilingualRecognition) private var enableBilingualRecognition = false
    @AppStorage(Keys.enableCorrection) private var enableCorrection = true
    @AppStorage(Keys.enableLivePreview) private var enableLivePreview = true
    @AppStorage(Keys.useInputContext) private var useInputContext = true
    @AppStorage(Keys.hotKeyDisplay) private var hotKeyDisplay = "⌃⌥Space"

    @State private var apiKey = ""
    @State private var recordingHotKey = false
    @State private var hotKeyMonitor: Any?
    @State private var micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var speechStatus = SFSpeechRecognizer.authorizationStatus()
    @State private var axTrusted = AXIsProcessTrusted()
    @FocusState private var apiKeyFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                apiSection
                modelSection
                appearanceSection
                hotKeySection
                permissionSection
            }
            .padding(26)
        }
        .frame(width: 460)
        .onAppear {
            apiKey = KeychainHelper.load() ?? ""
            refreshPermissions()
            apiKeyFocused = false
        }
        .onDisappear { stopRecordingHotKey() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Murmur 语音输入")
                .font(.system(size: 20, weight: .bold))
            Text("按快捷键开始说话，松手即转写、整理并插入到光标处。")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - API key

    private var apiSection: some View {
        section("DeepSeek API Key（可选）") {
            SecureField("sk-…（留空则只用本地识别，不做整理）", text: $apiKey)
                .textFieldStyle(.plain)
                .focused($apiKeyFocused)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(apiKeyFocused ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.22),
                                lineWidth: apiKeyFocused ? 1.5 : 1)
                )
                .onChange(of: apiKey) { _, newValue in
                    KeychainHelper.save(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            Text(apiKey.isEmpty
                 ? "未填写：语音用 Mac 本地识别（免费、离线），直接插入原文。"
                 : "已填写：本地识别后再用 DeepSeek 智能整理 / 纠错。密钥仅保存在系统钥匙串。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("语音转文字始终由 Mac 本地完成（DeepSeek 无语音接口）；DeepSeek 只做文本整理。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Models

    private var modelSection: some View {
        section("识别与整理") {
            HStack {
                Text("识别引擎")
                    .font(.system(size: 12.5))
                Spacer()
                Picker("", selection: $recognitionEngine) {
                    Text("Whisper Small（中英混合）").tag("whisper")
                    Text("Apple Speech（轻量）").tag("apple")
                }
                .labelsHidden()
                .frame(width: 220)
            }
            Text(whisperStatusText)
                .font(.caption2)
                .foregroundStyle(LocalWhisperTranscriber.isAvailable ? Color.secondary : Color.orange)
            labeledField("整理模型", text: $chatModel,
                         hint: "DeepSeek 模型：deepseek-chat（默认）或 deepseek-reasoner")
            labeledField("语言", text: $language,
                         hint: "中文为主的中英混合建议填 zh；纯英文填 en，留空为自动判断")
            vocabularyField
            if recognitionEngine == "apple" {
                Toggle("实验：额外跑英文识别（默认关闭，避免中文被误改成英文）",
                       isOn: $enableBilingualRecognition)
                    .font(.system(size: 12.5))
                Text("仅在中文主识别里有明显英文词但识别很差时再手动开启；中文主识别始终优先。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Toggle("参考光标附近文本，匹配格式、语气和术语",
                   isOn: $useInputContext)
                .font(.system(size: 12.5))
            Text("只读取光标前后最多 800 字，本次输入结束后立即清除；启用 DeepSeek 时，该片段会随本次整理请求发送。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Toggle("用 DeepSeek 智能整理 / 纠错（自动排版、断句、去口水词、纠正表达）",
                   isOn: $enableCorrection)
                .font(.system(size: 12.5))
        }
    }

    private var vocabularyField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("中英混合词库")
                .font(.system(size: 12.5))
            TextEditor(text: $recognitionContext)
                .font(.system(size: 12.5))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .frame(height: 86)
            Text("每行或用逗号分隔一个英文词/专名；Whisper 只读取前 24 个作为弱提示，DeepSeek 可读取前 80 个用于纠错。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var whisperStatusText: String {
        if LocalWhisperTranscriber.isAvailable {
            return "Whisper Small 已安装并优先用于最终转写；Apple Speech 继续提供实时预览和自动回退。"
        }
        return "未检测到 Whisper Small 或 whisper.cpp，将自动回退到 Apple Speech。"
    }

    // MARK: - Appearance & experience

    private var appearanceSection: some View {
        section("录音体验") {
            Toggle("录音时显示实时转写预览（本地识别，边说边出字）",
                   isOn: $enableLivePreview)
                .font(.system(size: 12.5))
            Text("实时预览仅用于即时反馈；填了 Key 时最终文本仍由 DeepSeek 整理。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Hotkey

    private var hotKeySection: some View {
        section("快捷键") {
            HStack {
                Text("开始 / 停止录音")
                    .font(.system(size: 12.5))
                Spacer()
                Button(recordingHotKey ? "按下按键…" : hotKeyDisplay) {
                    recordingHotKey ? stopRecordingHotKey() : startRecordingHotKey()
                }
                .buttonStyle(.bordered)
                .frame(minWidth: 130)
            }
            HStack(spacing: 6) {
                Button("用 fn 键") { app.setFnShortcut(); hotKeyDisplay = "fn"; stopRecordingHotKey() }
                    .buttonStyle(.link)
                    .font(.caption)
                Text("·").foregroundStyle(.tertiary)
                Text("点上方按钮再按组合键也可自定义")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("fn 键为全局触发需要「辅助功能」权限；如按 fn 会弹出表情面板，可在 系统设置→键盘→「按 🌐 键时」设为「无操作」。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Permissions

    private var permissionSection: some View {
        section("权限") {
            permissionRow(
                title: "麦克风",
                granted: micStatus == .authorized,
                action: {
                    if micStatus == .notDetermined {
                        Task {
                            _ = await AudioCapture.ensureMicPermission()
                            refreshPermissions()
                        }
                    } else {
                        openSettings("Privacy_Microphone")
                    }
                }
            )
            permissionRow(
                title: "语音识别（实时预览所需）",
                granted: speechStatus == .authorized,
                action: {
                    if speechStatus == .notDetermined {
                        Task {
                            _ = await AudioCapture.ensureSpeechPermission()
                            refreshPermissions()
                        }
                    } else {
                        openSettings("Privacy_SpeechRecognition")
                    }
                }
            )
            permissionRow(
                title: "辅助功能（自动粘贴所需）",
                granted: axTrusted,
                action: {
                    TextInserter.requestAccessibility()
                    openSettings("Privacy_Accessibility")
                }
            )
            Button("刷新权限状态") { refreshPermissions() }
                .buttonStyle(.link)
                .font(.caption)
        }
    }

    // MARK: - Reusable pieces

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func labeledField(_ title: String, text: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 12.5))
                    .frame(width: 70, alignment: .leading)
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
            }
            Text(hint)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.leading, 78)
        }
    }

    private func permissionRow(title: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
            Text(title)
                .font(.system(size: 12.5))
            Spacer()
            if granted {
                Text("已授权").font(.caption).foregroundStyle(.green)
            } else {
                Button("去开启", action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Hotkey recording

    private func startRecordingHotKey() {
        recordingHotKey = true
        hotKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                if Int(event.keyCode) == kVK_Function, event.modifierFlags.contains(.function) {
                    app.setFnShortcut()
                    hotKeyDisplay = "fn"
                    stopRecordingHotKey()
                    return nil
                }
                return event   // ignore other modifier changes while recording
            }
            handleHotKey(event)
            return nil
        }
    }

    private func stopRecordingHotKey() {
        if let monitor = hotKeyMonitor {
            NSEvent.removeMonitor(monitor)
            hotKeyMonitor = nil
        }
        recordingHotKey = false
    }

    private func handleHotKey(_ event: NSEvent) {
        let flags = event.modifierFlags
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }

        let code = UInt32(event.keyCode)
        let display = HotKeyFormatter.string(event)
        app.setKeyShortcut(code: code, mods: carbon, display: display)
        hotKeyDisplay = display
        stopRecordingHotKey()
    }

    // MARK: - Permissions helpers

    private func refreshPermissions() {
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        speechStatus = SFSpeechRecognizer.authorizationStatus()
        axTrusted = AXIsProcessTrusted()
    }

    private func openSettings(_ anchor: String) {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Builds a readable label like "⌃⌥Space" from a key event.
enum HotKeyFormatter {
    static func string(_ event: NSEvent) -> String {
        var result = ""
        let flags = event.modifierFlags
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option)  { result += "⌥" }
        if flags.contains(.shift)   { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        result += keyName(event)
        return result
    }

    private static func keyName(_ event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space:        return "Space"
        case kVK_Return:       return "Return"
        case kVK_Tab:          return "Tab"
        case kVK_Escape:       return "Esc"
        case kVK_Delete:       return "Delete"
        case kVK_LeftArrow:    return "←"
        case kVK_RightArrow:   return "→"
        case kVK_DownArrow:    return "↓"
        case kVK_UpArrow:      return "↑"
        default:
            if let chars = event.charactersIgnoringModifiers,
               !chars.isEmpty, chars != " " {
                return chars.uppercased()
            }
            return "Key\(event.keyCode)"
        }
    }
}
