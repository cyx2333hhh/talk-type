import SwiftUI

/// A fixed-size, non-activating dictation surface. The content changes inside
/// the panel without resizing the window or shifting the current text field.
struct RecordingOverlayView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var copied = false

    static let panelSize = CGSize(width: 380, height: 112)

    var body: some View {
        ZStack {
            phaseContent
                .id(phaseIdentity)
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
        .frame(width: 344, height: contentHeight)
        .padding(.horizontal, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark
                      ? MurmurPalette.graphite.opacity(0.36)
                      : Color.white.opacity(0.24))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 0.65)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.30 : 0.16),
                radius: 18,
                y: 8)
        .frame(width: Self.panelSize.width, height: Self.panelSize.height)
        .animation(reduceMotion ? nil : MurmurMotion.state, value: app.phase)
        .tint(MurmurPalette.accent)
    }

    private var contentHeight: CGFloat {
        app.phase == .recording ? 72 : 54
    }

    private var phaseIdentity: String {
        switch app.phase {
        case .recording: return "recording"
        case .success: return "success"
        case .failed: return "failed"
        default: return "processing"
        }
    }

    private var borderColor: Color {
        if app.phase == .recording {
            return MurmurPalette.accent.opacity(0.28 + app.audioLevel * 0.12)
        }
        return Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.10)
    }

    @ViewBuilder private var phaseContent: some View {
        if app.phase == .recording {
            recordingContent
        } else {
            statusContent
        }
    }

    private var recordingContent: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VoiceCursorSymbol(level: app.audioLevel, active: true)
                    .frame(width: 26, height: 26)
                    .accessibilityLabel("正在录音")

                VoiceTraceView(levels: app.levels, level: app.audioLevel)
                    .frame(height: 28)

                Text(timeString(app.recordingSeconds))
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .frame(width: 34, alignment: .trailing)
            }

            HStack(spacing: 10) {
                Text(app.partialText.isEmpty ? "正在聆听" : app.partialText)
                    .font(.system(size: 11.5, weight: app.partialText.isEmpty ? .medium : .regular))
                    .foregroundStyle(app.partialText.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)

                ShortcutKeyCap(text: app.hotKeyDisplay, compact: true)
            }
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }

    private var statusContent: some View {
        HStack(spacing: 12) {
            statusGlyph
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(statusDetail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            if app.phase == .success { copyButton }
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var statusGlyph: some View {
        switch app.phase {
        case .transcribing, .correcting, .inserting:
            ProgressView()
                .controlSize(.small)
                .tint(MurmurPalette.accent)
        case .success:
            Image(systemName: app.lastResultPasted ? "checkmark" : "doc.on.clipboard")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MurmurPalette.success)
                .frame(width: 24, height: 24)
                .background(MurmurPalette.success.opacity(0.12), in: Circle())
        case .failed:
            Image(systemName: "exclamationmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MurmurPalette.warning)
                .frame(width: 24, height: 24)
                .background(MurmurPalette.warning.opacity(0.12), in: Circle())
        default:
            VoiceCursorSymbol()
                .frame(width: 22, height: 22)
        }
    }

    private var statusTitle: String {
        switch app.phase {
        case .transcribing: return "正在转写"
        case .correcting: return "正在整理"
        case .inserting: return "正在插入"
        case .success: return app.lastResultPasted ? "文字已插入" : "文字已复制"
        case .failed: return "本次输入未完成"
        default: return "Talk-type"
        }
    }

    private var statusDetail: String {
        switch app.phase {
        case .transcribing:
            return app.partialText.isEmpty ? "正在确认最终文本" : app.partialText
        case .correcting:
            return app.partialText.isEmpty ? "正在匹配上下文与排版" : app.partialText
        case .inserting:
            return app.partialText.isEmpty ? "即将写入当前光标位置" : app.partialText
        case .success:
            return app.lastResultText.isEmpty
                ? (app.lastResultPasted ? "已写入当前光标位置" : "可使用 ⌘V 手动粘贴")
                : app.lastResultText
        case .failed: return app.errorMessage ?? "请重新尝试"
        default: return ""
        }
    }

    private var copyButton: some View {
        Button {
            app.copyLastResult()
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(copied ? MurmurPalette.success : .secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(copied ? "已复制" : "复制本次结果")
        .accessibilityLabel(copied ? "已复制" : "复制本次结果")
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%01d:%02d", seconds / 60, seconds % 60)
    }
}
