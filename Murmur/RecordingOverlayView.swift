import SwiftUI

/// The floating dictation pill — small and nimble. Outer frame is a fixed size
/// (matching the panel); the frosted capsule inside sizes to its content and
/// animates between phases without ever resizing the window.
struct RecordingOverlayView: View {
    @EnvironmentObject var app: AppState
    @State private var copied = false

    /// Fixed panel size; transparent margin around the pill leaves room for the shadow.
    static let panelSize = CGSize(width: 320, height: 92)

    var body: some View {
        pill
            .frame(width: Self.panelSize.width, height: Self.panelSize.height)
    }

    private var pill: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, app.partialText.isEmpty ? 10 : 9)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(recordingStroke, lineWidth: 0.5)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.11), lineWidth: 0.5)
                    .blur(radius: 0.4)
                    .mask(
                        LinearGradient(colors: [.white, .clear],
                                       startPoint: .top,
                                       endPoint: .center)
                    )
            }
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            .shadow(color: recordingGlow,
                    radius: app.phase == .recording ? 8 : 0,
                    y: app.phase == .recording ? 3 : 0)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: app.phase)
            .animation(.easeOut(duration: 0.18), value: app.partialText.isEmpty)
    }

    private var recordingStroke: Color {
        app.phase == .recording
            ? Color.accentColor.opacity(0.13 + min(0.11, app.audioLevel * 0.14))
            : Color.white.opacity(0.12)
    }

    private var recordingGlow: Color {
        Color.accentColor.opacity(0.025 + min(0.05, app.audioLevel * 0.06))
    }

    @ViewBuilder private var content: some View {
        switch app.phase {
        case .recording: recording
        default:         compact
        }
    }

    // MARK: - Recording

    private var recording: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                VoiceLensView(level: app.audioLevel)
                    .frame(width: 18, height: 18)
                SpectralWaveView(levels: app.levels, level: app.audioLevel)
                    .frame(width: 156, height: 24)
                Text(timeString(app.recordingSeconds))
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if !app.partialText.isEmpty {
                Text(app.partialText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(width: 254, alignment: .leading)
            }
        }
    }

    // MARK: - Compact (processing / result)

    private var compact: some View {
        HStack(spacing: 9) {
            leadingGlyph
            detail
            if app.phase == .success {
                copyButton
            }
        }
    }

    @ViewBuilder private var leadingGlyph: some View {
        switch app.phase {
        case .transcribing, .correcting, .inserting:
            ProgressView().controlSize(.small).frame(width: 13, height: 13)
        case .success:
            Image(systemName: app.lastResultPasted ? "checkmark.circle.fill" : "doc.on.clipboard.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }

    @ViewBuilder private var detail: some View {
        switch app.phase {
        case .transcribing: label("转写中…")
        case .correcting:   label("整理中…")
        case .inserting:    label("插入中…")
        case .success:      label(app.lastResultPasted ? "已插入" : "已复制")
        case .failed:
            Text(app.errorMessage ?? "出错了")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 220, alignment: .leading)
        default:
            EmptyView()
        }
    }

    private var copyButton: some View {
        Button {
            app.copyLastResult()
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                Text(copied ? "已复制" : "复制")
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(.tint)
        }
        .buttonStyle(.borderless)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.primary)
            .fixedSize()
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%01d:%02d", seconds / 60, seconds % 60)
    }
}

/// A small glassy listening indicator. It reacts to audio without becoming a logo.
struct VoiceLensView: View {
    let level: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let safeLevel = max(0.03, min(1, level))
            let breath = CGFloat(0.5 + 0.5 * sin(t * 2.2))
            let ringScale = 0.88 + safeLevel * 0.16 + breath * 0.04
            let coreScale = 0.44 + safeLevel * 0.18 + breath * 0.04

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.055 + safeLevel * 0.035))
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.6)
                Circle()
                    .stroke(Color.accentColor.opacity(0.28 + safeLevel * 0.16), lineWidth: 1)
                    .scaleEffect(ringScale)
                Circle()
                    .fill(Color.accentColor.opacity(0.76))
                    .scaleEffect(coreScale)
                    .shadow(color: Color.accentColor.opacity(0.24 + safeLevel * 0.18),
                            radius: 2 + safeLevel * 2)
            }
            .animation(.easeOut(duration: 0.12), value: level)
        }
        .accessibilityLabel("正在录音")
    }
}
