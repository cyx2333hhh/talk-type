import SwiftUI

/// The floating dictation pill — small and nimble. Outer frame is a fixed size
/// (matching the panel); the frosted capsule inside sizes to its content and
/// animates between phases without ever resizing the window.
struct RecordingOverlayView: View {
    @EnvironmentObject var app: AppState
    @State private var copied = false

    /// Fixed panel size; transparent margin around the pill leaves room for the shadow.
    static let panelSize = CGSize(width: 300, height: 96)

    var body: some View {
        pill
            .frame(width: Self.panelSize.width, height: Self.panelSize.height)
    }

    private var pill: some View {
        content
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: app.phase)
            .animation(.easeOut(duration: 0.18), value: app.partialText.isEmpty)
    }

    @ViewBuilder private var content: some View {
        switch app.phase {
        case .recording: recording
        default:         compact
        }
    }

    // MARK: - Recording

    private var recording: some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                PulsingDot()
                FlowWaveView(levels: app.levels)
                    .frame(width: 128, height: 24)
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
                    .frame(maxWidth: 250)
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

/// A small pulsing red dot used during recording.
struct PulsingDot: View {
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 7, height: 7)
            .scaleEffect(animate ? 1.0 : 0.55)
            .opacity(animate ? 1.0 : 0.45)
            .shadow(color: .red.opacity(0.6), radius: animate ? 4 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}
