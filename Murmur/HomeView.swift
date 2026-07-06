import SwiftUI

/// The main interface, shown as a refined panel when the menu-bar icon is
/// clicked: a large record button, live status, and recent dictations.
struct HomeView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            hero
            Divider().opacity(0.5)
            recent
        }
        .frame(width: 340)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("Murmur")
                    .font(.system(size: 15, weight: .semibold))
                Text("语音输入")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            headerActions
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            Button {
                SettingsWindowController.shared.show()
            } label: {
                headerActionIcon("gearshape")
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("设置")
            .accessibilityLabel("设置")

            Menu {
                Button("设置…") { SettingsWindowController.shared.show() }
                Divider()
                Button("退出 Murmur") { NSApp.terminate(nil) }
            } label: {
                headerActionIcon("ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28, height: 28)
            .focusable(false)
            .help("更多")
            .accessibilityLabel("更多")
        }
        .fixedSize()
    }

    private func headerActionIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.primary)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 14) {
            RecordButton(phase: app.phase) { app.toggle() }
            VStack(spacing: 3) {
                Text(statusText)
                    .font(.system(size: 13.5, weight: .medium))
                    .contentTransition(.opacity)
                Text(hintText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }

    private var statusText: String {
        switch app.phase {
        case .idle:         return "准备就绪"
        case .recording:    return "聆听中 · \(timeString(app.recordingSeconds))"
        case .transcribing: return "转写中…"
        case .correcting:   return "智能整理…"
        case .inserting:    return "正在插入…"
        case .success:      return app.lastResultPasted ? "已插入" : "已复制到剪贴板"
        case .failed:       return app.errorMessage ?? "出错了"
        }
    }

    private var hintText: String {
        switch app.phase {
        case .recording: return "再次按下 \(app.hotKeyDisplay) 或点按结束"
        default:         return "按 \(app.hotKeyDisplay) 或点按上方开始"
        }
    }

    // MARK: - Recent

    private var recent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Label("最近记录", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !app.history.isEmpty {
                    Button {
                        app.clearHistory()
                    } label: {
                        Text("清空")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("清空最近记录")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if app.history.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(app.history.prefix(8)) { record in
                            HistoryRow(record: record) { app.deleteHistory(record) }
                            if record.id != app.history.prefix(8).last?.id {
                                Divider().opacity(0.4).padding(.leading, 16)
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(.bottom, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "text.bubble")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text("还没有记录")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
            Text("按 \(app.hotKeyDisplay) 开始你的第一次语音输入")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%01d:%02d", seconds / 60, seconds % 60)
    }
}

/// The large circular record / stop button reflecting the current phase.
private struct RecordButton: View {
    let phase: Phase
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                    .frame(width: 74, height: 74)

                if phase == .recording {
                    Circle()
                        .stroke(Color.red.opacity(0.45), lineWidth: 3)
                        .frame(width: 74, height: 74)
                        .scaleEffect(pulse ? 1.28 : 1.0)
                        .opacity(pulse ? 0 : 1)
                }

                icon
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }

    private var isBusy: Bool {
        phase == .transcribing || phase == .correcting || phase == .inserting
    }

    private var fill: Color {
        switch phase {
        case .recording: return Color.red.opacity(0.92)
        case .failed:    return Color.orange.opacity(0.18)
        default:         return Color.accentColor.opacity(0.14)
        }
    }

    @ViewBuilder private var icon: some View {
        switch phase {
        case .recording:
            Image(systemName: "stop.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)
        case .transcribing, .correcting, .inserting:
            ProgressView().controlSize(.small)
        case .failed:
            Image(systemName: "exclamationmark")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.orange)
        default:
            Image(systemName: "mic.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.tint)
        }
    }
}

/// A single recent-dictation row with a copy button.
private struct HistoryRow: View {
    let record: DictationRecord
    let onDelete: () -> Void
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.text)
                    .font(.system(size: 12.5))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(relativeTime(record.date))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            Button {
                copy()
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(copied ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help("复制")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contextMenu {
            Button("复制") { copy() }
            Button("删除", role: .destructive) { onDelete() }
        }
    }

    private func copy() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(record.text, forType: .string)
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
