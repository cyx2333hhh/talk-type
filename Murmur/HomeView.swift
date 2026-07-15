import SwiftUI

enum HomePresentation {
    case mainWindow
    case menuBar
}

struct HomeView: View {
    @EnvironmentObject var app: AppState

    let presentation: HomePresentation

    init(presentation: HomePresentation = .mainWindow) {
        self.presentation = presentation
    }

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(compact: presentation == .menuBar)
            DictationStage(compact: presentation == .menuBar)
            RecentSection(compact: presentation == .menuBar)
        }
        .frame(minWidth: presentation == .mainWindow ? 560 : nil,
               idealWidth: presentation == .mainWindow ? 620 : 360,
               maxWidth: presentation == .mainWindow ? .infinity : 360,
               minHeight: presentation == .mainWindow ? 540 : nil,
               maxHeight: presentation == .mainWindow ? .infinity : nil)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(MurmurPalette.accent)
    }
}

private struct AppHeader: View {
    @EnvironmentObject var app: AppState
    let compact: Bool

    var body: some View {
        HStack(spacing: 11) {
            VoiceCursorSymbol(level: app.audioLevel,
                              active: app.phase == .recording)
                .frame(width: compact ? 25 : 28, height: compact ? 25 : 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Talk-type")
                    .font(.system(size: compact ? 14.5 : 16,
                                  weight: .semibold))
                if compact {
                    Text("本地语音输入")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                } else {
                    EngineStatusLabel()
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                HeaderIconButton(systemName: "gearshape", help: "设置") {
                    SettingsWindowController.shared.show()
                }

                Menu {
                    Button("设置…") { SettingsWindowController.shared.show() }
                    Divider()
                    Button("退出 Talk-type") { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 32, height: 32)
                .focusable(false)
                .help("更多")
                .accessibilityLabel("更多")
            }
            .fixedSize()
        }
        .padding(.horizontal, compact ? 16 : 22)
        .padding(.vertical, compact ? 12 : 15)
    }
}

private struct EngineStatusLabel: View {
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(LocalWhisperTranscriber.isAvailable
                      ? MurmurPalette.accent
                      : MurmurPalette.warning)
                .frame(width: 5, height: 5)
            Text(LocalWhisperTranscriber.isAvailable
                 ? "WHISPER SMALL · 本地"
                 : "APPLE SPEECH · 回退")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HeaderIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(hovered ? .primary : .secondary)
                .frame(width: 32, height: 32)
                .background(hovered ? MurmurPalette.quietFill : .clear,
                            in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovered = $0 }
        .animation(MurmurMotion.quick, value: hovered)
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct DictationStage: View {
    @EnvironmentObject var app: AppState
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 12 : 15) {
            RecordControl(phase: app.phase,
                          level: app.audioLevel,
                          compact: compact) {
                app.toggle()
            }

            VStack(spacing: 3) {
                Text(statusTitle)
                    .font(.system(size: compact ? 13.5 : 16, weight: .semibold))
                    .contentTransition(.opacity)
                Text(statusDetail)
                    .font(.system(size: compact ? 11 : 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }

            stageFooter
                .frame(height: compact ? 26 : 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 20 : 25)
        .background(MurmurPalette.quietFill)
        .overlay(alignment: .top) { Divider().opacity(0.55) }
        .overlay(alignment: .bottom) { Divider().opacity(0.55) }
        .animation(MurmurMotion.state, value: app.phase)
    }

    @ViewBuilder private var stageFooter: some View {
        if app.phase == .recording {
            HStack(spacing: 11) {
                VoiceTraceView(levels: app.levels, level: app.audioLevel)
                    .frame(width: compact ? 150 : 210, height: 28)
                Text(timeString(app.recordingSeconds))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        } else {
            HStack(spacing: 8) {
                ShortcutKeyCap(text: app.hotKeyDisplay, compact: compact)
                Text(app.phase == .success ? "再次输入" : "开始 / 停止")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var statusTitle: String {
        switch app.phase {
        case .idle: return "准备输入"
        case .recording: return "正在聆听"
        case .transcribing: return "正在本地转写"
        case .correcting: return "正在匹配上下文"
        case .inserting: return "正在插入"
        case .success: return app.lastResultPasted ? "输入完成" : "已复制到剪贴板"
        case .failed: return "本次输入未完成"
        }
    }

    private var statusDetail: String {
        switch app.phase {
        case .idle: return "说完后再次按下快捷键"
        case .recording: return "自然说话，中英文可以混合"
        case .transcribing: return "Whisper Small 正在处理本地音频"
        case .correcting: return "保留原意，仅优化格式与明确错误"
        case .inserting: return "写入当前光标位置"
        case .success: return app.lastResultPasted ? "文字已写入当前光标位置" : "可使用 ⌘V 手动粘贴"
        case .failed: return app.errorMessage ?? "请重新尝试"
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%01d:%02d", seconds / 60, seconds % 60)
    }
}

private struct RecordControl: View {
    let phase: Phase
    let level: CGFloat
    let compact: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                Circle()
                    .strokeBorder(stroke, lineWidth: 0.8)
                controlGlyph
            }
            .frame(width: compact ? 66 : 76, height: compact ? 66 : 76)
            .scaleEffect(hovered && !isBusy && !reduceMotion ? 1.025 : 1)
            .shadow(color: shadowColor, radius: hovered ? 10 : 6, y: 3)
            .contentShape(Circle())
        }
        .buttonStyle(RecordPressStyle())
        .disabled(isBusy)
        .onHover { hovered = $0 }
        .animation(reduceMotion ? nil : MurmurMotion.quick, value: hovered)
        .help(phase == .recording ? "停止录音" : "开始语音输入")
        .accessibilityLabel(phase == .recording ? "停止录音" : "开始语音输入")
    }

    private var isBusy: Bool {
        phase == .transcribing || phase == .correcting || phase == .inserting
    }

    private var fill: Color {
        switch phase {
        case .recording: return MurmurPalette.recording
        case .success: return MurmurPalette.success.opacity(0.13)
        case .failed: return MurmurPalette.warning.opacity(0.13)
        default: return MurmurPalette.accent.opacity(0.12)
        }
    }

    private var stroke: Color {
        switch phase {
        case .recording: return Color.white.opacity(0.22)
        case .success: return MurmurPalette.success.opacity(0.32)
        case .failed: return MurmurPalette.warning.opacity(0.32)
        default: return MurmurPalette.accent.opacity(hovered ? 0.46 : 0.28)
        }
    }

    private var shadowColor: Color {
        phase == .recording
            ? MurmurPalette.recording.opacity(0.16)
            : MurmurPalette.accent.opacity(hovered ? 0.12 : 0.06)
    }

    @ViewBuilder private var controlGlyph: some View {
        switch phase {
        case .recording:
            RoundedRectangle(cornerRadius: 3)
                .fill(.white)
                .frame(width: compact ? 17 : 19, height: compact ? 17 : 19)
        case .transcribing, .correcting, .inserting:
            ProgressView()
                .controlSize(compact ? .small : .regular)
        case .success:
            Image(systemName: "checkmark")
                .font(.system(size: compact ? 21 : 24, weight: .semibold))
                .foregroundStyle(MurmurPalette.success)
        case .failed:
            Image(systemName: "exclamationmark")
                .font(.system(size: compact ? 21 : 24, weight: .semibold))
                .foregroundStyle(MurmurPalette.warning)
        default:
            VoiceCursorSymbol(level: level)
                .frame(width: compact ? 30 : 34, height: compact ? 30 : 34)
        }
    }
}

private struct RecordPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : MurmurMotion.quick,
                       value: configuration.isPressed)
    }
}

private struct RecentSection: View {
    @EnvironmentObject var app: AppState
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("最近")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !app.history.isEmpty {
                    Button("清空") { app.clearHistory() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .help("清空最近记录")
                }
            }
            .padding(.horizontal, compact ? 16 : 22)
            .padding(.top, 14)
            .padding(.bottom, 8)

            if app.history.isEmpty {
                EmptyHistory(compact: compact)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(app.history.prefix(compact ? 6 : 50))) { record in
                            HistoryRow(record: record,
                                       compact: compact,
                                       onDelete: { app.deleteHistory(record) })
                        }
                    }
                    .padding(.horizontal, compact ? 8 : 12)
                    .padding(.bottom, 10)
                }
                .frame(maxHeight: compact ? 254 : .infinity)
            }
        }
        .frame(maxHeight: presentationHeight, alignment: .top)
    }

    private var presentationHeight: CGFloat? {
        compact ? nil : .infinity
    }
}

private struct EmptyHistory: View {
    @EnvironmentObject var app: AppState
    let compact: Bool

    var body: some View {
        VStack(spacing: 8) {
            VoiceCursorSymbol(tint: .secondary)
                .frame(width: 24, height: 24)
                .opacity(0.55)
            Text("第一次输入会出现在这里")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text("按")
                ShortcutKeyCap(text: app.hotKeyDisplay, compact: true)
                Text("开始")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 28 : 42)
    }
}

private struct HistoryRow: View {
    let record: DictationRecord
    let compact: Bool
    let onDelete: () -> Void

    @State private var copied = false
    @State private var hovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(record.text)
                    .font(.system(size: compact ? 12 : 12.5))
                    .lineSpacing(2)
                    .lineLimit(compact ? 2 : 3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(relativeTime(record.date))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Button(action: copy) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(copied ? MurmurPalette.success : Color.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(copied ? "已复制" : "复制")
            .accessibilityLabel(copied ? "已复制" : "复制")
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 9 : 10)
        .background(hovered ? MurmurPalette.quietFill : .clear,
                    in: RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .animation(MurmurMotion.quick, value: hovered)
        .contextMenu {
            Button("复制") { copy() }
            Button("删除", role: .destructive) { onDelete() }
        }
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(record.text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
