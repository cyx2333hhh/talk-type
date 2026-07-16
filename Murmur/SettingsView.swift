import SwiftUI
import AVFoundation
import Speech
import ApplicationServices
import Carbon.HIToolbox

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case vocabulary
    case shortcut
    case permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "识别与整理"
        case .vocabulary: return "中英词库"
        case .shortcut: return "快捷键"
        case .permissions: return "权限"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "选择本地识别方式与文本整理策略"
        case .vocabulary: return "让技术词、产品名和专有名词更准确"
        case .shortcut: return "设置开始与停止语音输入的触发方式"
        case .permissions: return "检查录音、预览与自动插入所需权限"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .vocabulary: return "textformat.abc"
        case .shortcut: return "command"
        case .permissions: return "checkmark.shield"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(Keys.chatModel) private var chatModel = "deepseek-chat"
    @AppStorage(Keys.language) private var language = "zh"
    @AppStorage(Keys.recognitionEngine) private var recognitionEngine = "whisper"
    @AppStorage(Keys.recognitionContext) private var recognitionContext = Keys.defaultRecognitionContext
    @AppStorage(Keys.enableBilingualRecognition) private var enableBilingualRecognition = false
    @AppStorage(Keys.enableCorrection) private var enableCorrection = true
    @AppStorage(Keys.enableLivePreview) private var enableLivePreview = true
    @AppStorage(Keys.useInputContext) private var useInputContext = true
    @AppStorage(Keys.hotKeyDisplay) private var hotKeyDisplay = "fn"

    @State private var selectedPane = SettingsPane.general
    @State private var apiKey = ""
    @State private var recordingHotKey = false
    @State private var hotKeyMonitor: Any?
    @State private var micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var speechStatus = SFSpeechRecognizer.authorizationStatus()
    @State private var axTrusted = AXIsProcessTrusted()
    @FocusState private var apiKeyFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().opacity(0.65)
            content
        }
        .frame(minWidth: 680, idealWidth: 720, minHeight: 540, idealHeight: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(MurmurPalette.accent)
        .onAppear {
            apiKey = KeychainHelper.load() ?? ""
            refreshPermissions()
            apiKeyFocused = false
        }
        .onChange(of: selectedPane) { _, _ in
            apiKeyFocused = false
            if selectedPane != .shortcut { stopRecordingHotKey() }
        }
        .onDisappear { stopRecordingHotKey() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                VoiceCursorSymbol()
                    .frame(width: 27, height: 27)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Talk-type")
                        .font(.system(size: 14.5, weight: .semibold))
                    Text("设置")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 20)

            VStack(spacing: 4) {
                ForEach(SettingsPane.allCases) { pane in
                    SidebarButton(pane: pane,
                                  selected: selectedPane == pane) {
                        withAnimation(reduceMotion ? nil : MurmurMotion.quick) {
                            selectedPane = pane
                        }
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            Text("Talk-type · 本地优先")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(16)
        }
        .frame(width: 164)
        .background(MurmurPalette.quietFill)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(selectedPane.title)
                        .font(.system(size: 20, weight: .semibold))
                    Text(selectedPane.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                paneContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.vertical, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var paneContent: some View {
        switch selectedPane {
        case .general: generalPane
        case .vocabulary: vocabularyPane
        case .shortcut: shortcutPane
        case .permissions: permissionsPane
        }
    }

    // MARK: - General

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 26) {
            settingsSection("语音识别") {
                settingsRow(title: "识别引擎",
                            detail: "Whisper 更适合中英混合；Apple Speech 更轻量。") {
                    Picker("", selection: $recognitionEngine) {
                        Text("Whisper Small").tag("whisper")
                        Text("Apple Speech").tag("apple")
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
                rowDivider
                settingsRow(title: "主要语言",
                            detail: "中文为主的中英混合建议使用 zh。") {
                    TextField("zh", text: $language)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5, design: .monospaced))
                        .padding(.horizontal, 9)
                        .frame(width: 120, height: 30)
                        .background(MurmurPalette.surface,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(MurmurPalette.hairline, lineWidth: 0.5)
                        }
                }
                rowDivider
                settingsRow(title: "实时预览",
                            detail: "录音时显示 Apple Speech 的即时转写，不影响最终结果。") {
                    Toggle("", isOn: $enableLivePreview)
                        .labelsHidden()
                }
                if recognitionEngine == "apple" {
                    rowDivider
                    settingsRow(title: "英文辅助识别",
                                detail: "实验功能。仅在 Apple 中文主识别明显漏掉英文时开启。") {
                        Toggle("", isOn: $enableBilingualRecognition)
                            .labelsHidden()
                    }
                }
            }

            statusNote(systemName: LocalWhisperTranscriber.isAvailable
                       ? "checkmark.circle.fill"
                       : "exclamationmark.circle.fill",
                       tint: LocalWhisperTranscriber.isAvailable
                       ? MurmurPalette.accent
                       : MurmurPalette.warning,
                       text: whisperStatusText)

            settingsSection("上下文与整理") {
                settingsRow(title: "参考输入框上下文",
                            detail: "读取光标附近最多 240 字，用于匹配格式、语气与明确术语。") {
                    Toggle("", isOn: $useInputContext)
                        .labelsHidden()
                }
                rowDivider
                settingsRow(title: "DeepSeek 整理",
                            detail: "仅做保守排版、断句和明确纠错；关闭后直接插入本地转写。") {
                    Toggle("", isOn: $enableCorrection)
                        .labelsHidden()
                }

                if enableCorrection {
                    rowDivider
                    settingsRow(title: "API Key",
                                detail: apiKey.isEmpty
                                ? "未填写，当前仍只使用本地识别。"
                                : "仅保存在 macOS 钥匙串。") {
                        SecureField("sk-…", text: $apiKey)
                            .textFieldStyle(.plain)
                            .focused($apiKeyFocused)
                            .font(.system(size: 12.5))
                            .padding(.horizontal, 10)
                            .frame(width: 230, height: 32)
                            .background(MurmurPalette.surface,
                                        in: RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(apiKeyFocused
                                            ? MurmurPalette.accent.opacity(0.7)
                                            : MurmurPalette.hairline,
                                            lineWidth: apiKeyFocused ? 1 : 0.5)
                            }
                            .onChange(of: apiKey) { _, newValue in
                                KeychainHelper.save(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
                            }
                    }
                    rowDivider
                    settingsRow(title: "整理模型",
                                detail: "默认使用 deepseek-chat。") {
                        TextField("deepseek-chat", text: $chatModel)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.horizontal, 9)
                            .frame(width: 190, height: 30)
                            .background(MurmurPalette.surface,
                                        in: RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(MurmurPalette.hairline, lineWidth: 0.5)
                            }
                    }
                }
            }

            Text("启用 DeepSeek 时，本次转写和可选的光标上下文会随整理请求发送；音频始终留在本机。")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
        }
        .animation(reduceMotion ? nil : MurmurMotion.gentle,
                   value: recognitionEngine)
        .animation(reduceMotion ? nil : MurmurMotion.gentle,
                   value: enableCorrection)
    }

    // MARK: - Vocabulary

    private var vocabularyPane: some View {
        settingsSection("专有词与英文词") {
            HStack {
                Text("已收录 \(AppState.parseRecognitionContext(recognitionContext).count) 个词")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("恢复默认") {
                    recognitionContext = Keys.defaultRecognitionContext
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)

            TextEditor(text: $recognitionContext)
                .font(.system(size: 12.5, design: .monospaced))
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 300)
                .background(MurmurPalette.surface,
                            in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(MurmurPalette.hairline, lineWidth: 0.5)
                }

            Text("每行或用逗号分隔一个词。Whisper 使用前 24 个作为弱提示，DeepSeek 使用前 80 个进行明确纠错；不会强行插入没有说过的词。")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
    }

    // MARK: - Shortcut

    private var shortcutPane: some View {
        VStack(alignment: .leading, spacing: 26) {
            settingsSection("开始与停止") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("全局语音输入快捷键")
                                .font(.system(size: 12.5, weight: .medium))
                            Text(recordingHotKey ? "现在按下新的组合键" : "同一个快捷键用于开始和结束录音")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            recordingHotKey ? stopRecordingHotKey() : startRecordingHotKey()
                        } label: {
                            HStack(spacing: 7) {
                                if recordingHotKey {
                                    Circle()
                                        .fill(MurmurPalette.recording)
                                        .frame(width: 6, height: 6)
                                }
                                Text(recordingHotKey ? "等待按键" : hotKeyDisplay)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            }
                            .frame(minWidth: 126, minHeight: 34)
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider().opacity(0.55)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("使用 fn 键")
                                .font(.system(size: 12.5, weight: .medium))
                            Text("适合单手快速触发，不占用常见组合键。")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("设为 fn") {
                            app.setFnShortcut()
                            hotKeyDisplay = "fn"
                            stopRecordingHotKey()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 8)
            }

            statusNote(systemName: "globe",
                       tint: MurmurPalette.accent,
                       text: "如果按 fn 会打开表情面板，请在系统设置 → 键盘中把“按 🌐 键时”设为“无操作”。")
        }
    }

    // MARK: - Permissions

    private var permissionsPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("系统权限") {
                permissionRow(title: "麦克风",
                              detail: "录制本次语音。",
                              granted: micStatus == .authorized) {
                    if micStatus == .notDetermined {
                        Task {
                            _ = await AudioCapture.ensureMicPermission()
                            refreshPermissions()
                        }
                    } else {
                        openSettings("Privacy_Microphone")
                    }
                }
                rowDivider
                permissionRow(title: "语音识别",
                              detail: "用于录音时的实时预览和 Apple Speech 回退。",
                              granted: speechStatus == .authorized) {
                    if speechStatus == .notDetermined {
                        Task {
                            _ = await AudioCapture.ensureSpeechPermission()
                            refreshPermissions()
                        }
                    } else {
                        openSettings("Privacy_SpeechRecognition")
                    }
                }
                rowDivider
                permissionRow(title: "辅助功能",
                              detail: "读取光标附近文本并把结果自动插入当前输入框。",
                              granted: axTrusted) {
                    TextInserter.requestAccessibility()
                    openSettings("Privacy_Accessibility")
                }
            }

            HStack {
                Text("修改系统权限后返回此处刷新状态。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("刷新状态") { refreshPermissions() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Components

    private func settingsSection<Content: View>(_ title: String,
                                                @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func settingsRow<Control: View>(title: String,
                                            detail: String,
                                            @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            control()
        }
        .padding(.vertical, 9)
    }

    private var rowDivider: some View {
        Divider().opacity(0.55)
    }

    private func statusNote(systemName: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(tint.opacity(0.075), in: RoundedRectangle(cornerRadius: 7))
    }

    private func permissionRow(title: String,
                               detail: String,
                               granted: Bool,
                               action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark" : "minus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(granted ? MurmurPalette.success : Color.secondary)
                .frame(width: 24, height: 24)
                .background((granted ? MurmurPalette.success : Color.secondary).opacity(0.11),
                            in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Text("已开启")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(MurmurPalette.success)
            } else {
                Button("开启", action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 10)
    }

    private var whisperStatusText: String {
        if LocalWhisperTranscriber.isAvailable {
            return "Whisper Small 已就绪。最终转写优先在本机完成，Apple Speech 继续提供实时预览和自动回退。"
        }
        return "未检测到 Whisper Small 或 whisper.cpp，当前会自动使用 Apple Speech。"
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
                return event
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

    // MARK: - Permission helpers

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

private struct SidebarButton: View {
    let pane: SettingsPane
    let selected: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: pane.systemImage)
                    .font(.system(size: 12.5, weight: .medium))
                    .frame(width: 17)
                Text(pane.title)
                    .font(.system(size: 12.5, weight: selected ? .semibold : .medium))
                Spacer()
            }
            .foregroundStyle(selected ? .primary : .secondary)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(selected
                        ? MurmurPalette.accent.opacity(0.13)
                        : (hovered ? MurmurPalette.quietFill : .clear),
                        in: RoundedRectangle(cornerRadius: 7))
            .overlay(alignment: .leading) {
                if selected {
                    Capsule()
                        .fill(MurmurPalette.accent)
                        .frame(width: 2.5, height: 16)
                        .padding(.leading, 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovered = $0 }
        .animation(MurmurMotion.quick, value: hovered)
        .accessibilityLabel(pane.title)
    }
}

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
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        case kVK_Delete: return "Delete"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_DownArrow: return "↓"
        case kVK_UpArrow: return "↑"
        default:
            if let chars = event.charactersIgnoringModifiers,
               !chars.isEmpty, chars != " " {
                return chars.uppercased()
            }
            return "Key\(event.keyCode)"
        }
    }
}
