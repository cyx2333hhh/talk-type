import SwiftUI
import AppKit
import Combine

/// User-defaults keys + their default values.
enum Keys {
    static let chatModel = "chatModel"
    static let language = "language"
    static let enableCorrection = "enableCorrection"
    static let enableLivePreview = "enableLivePreview"
    static let useFnKey = "useFnKey"
    static let hotKeyCode = "hotKeyCode"
    static let hotKeyMods = "hotKeyMods"
    static let hotKeyDisplay = "hotKeyDisplay"
    static let historyData = "historyData"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            chatModel: "deepseek-chat",
            language: "zh",
            enableCorrection: true,
            enableLivePreview: true,
            useFnKey: true,
            hotKeyCode: 49,        // Space (used when not in fn mode)
            hotKeyMods: 6144,      // control(4096) + option(2048)
            hotKeyDisplay: "fn",
        ])
    }
}

/// The lifecycle of a single dictation.
enum Phase: Equatable {
    case idle
    case recording
    case transcribing
    case correcting
    case inserting
    case success
    case failed
}

/// One completed dictation, shown in the history list.
struct DictationRecord: Identifiable, Codable {
    let id: UUID
    let text: String
    let date: Date

    init(text: String, date: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.date = date
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let barCount = 28

    @Published var phase: Phase = .idle
    @Published var levels: [CGFloat]
    @Published var audioLevel: CGFloat = 0
    @Published var partialText: String = ""
    @Published var recordingSeconds: Int = 0
    @Published var errorMessage: String?
    @Published var lastResultPasted = true
    @Published var lastResultText = ""
    @Published var history: [DictationRecord] = []

    private let capture = AudioCapture()
    private var clockTimer: Timer?
    private var hideTask: Task<Void, Never>?

    private lazy var panel = PanelController(
        content: AnyView(RecordingOverlayView().environmentObject(self)),
        size: RecordingOverlayView.panelSize
    )

    private init() {
        levels = Array(repeating: 0.03, count: 28)
        history = AppState.loadHistory()
    }

    // MARK: - Setup

    func bootstrap() {
        Keys.registerDefaults()
        capture.onLevel = { [weak self] level in
            MainActor.assumeIsolated { self?.pushLevel(level) }
        }
        capture.onPartial = { [weak self] text in
            MainActor.assumeIsolated { self?.partialText = text }
        }
        let trigger: () -> Void = { Task { @MainActor in AppState.shared.toggle() } }
        HotKeyManager.shared.onTrigger = trigger
        FnKeyMonitor.shared.onTrigger = trigger
        applyShortcut()
    }

    /// Activates the correct trigger (fn monitor or Carbon hotkey) from settings.
    func applyShortcut() {
        if UserDefaults.standard.bool(forKey: Keys.useFnKey) {
            HotKeyManager.shared.unregister()
            FnKeyMonitor.shared.start()
        } else {
            FnKeyMonitor.shared.stop()
            let code = UInt32(UserDefaults.standard.integer(forKey: Keys.hotKeyCode))
            let mods = UInt32(UserDefaults.standard.integer(forKey: Keys.hotKeyMods))
            HotKeyManager.shared.register(keyCode: code, modifiers: mods)
        }
    }

    func setFnShortcut() {
        UserDefaults.standard.set(true, forKey: Keys.useFnKey)
        UserDefaults.standard.set("fn", forKey: Keys.hotKeyDisplay)
        applyShortcut()
    }

    func setKeyShortcut(code: UInt32, mods: UInt32, display: String) {
        UserDefaults.standard.set(false, forKey: Keys.useFnKey)
        UserDefaults.standard.set(Int(code), forKey: Keys.hotKeyCode)
        UserDefaults.standard.set(Int(mods), forKey: Keys.hotKeyMods)
        UserDefaults.standard.set(display, forKey: Keys.hotKeyDisplay)
        applyShortcut()
    }

    // MARK: - Settings accessors

    private var chatModel: String {
        UserDefaults.standard.string(forKey: Keys.chatModel) ?? "deepseek-chat"
    }
    private var language: String {
        UserDefaults.standard.string(forKey: Keys.language) ?? ""
    }
    private var correctionEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.enableCorrection)
    }
    private var livePreviewEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.enableLivePreview)
    }
    private var recognitionLocale: String {
        let lang = language
        if lang.isEmpty { return Locale.current.identifier }
        if lang.lowercased().hasPrefix("zh") { return "zh-CN" }
        return lang
    }

    var hotKeyDisplay: String {
        UserDefaults.standard.string(forKey: Keys.hotKeyDisplay) ?? "fn"
    }

    var menuBarImageName: String {
        switch phase {
        case .recording, .transcribing, .correcting, .inserting: return "MenuBarIconActive"
        default: return "MenuBarIcon"
        }
    }

    // MARK: - Flow

    func toggle() {
        switch phase {
        case .idle, .success, .failed:
            Task { await start() }
        case .recording:
            Task { await stop() }
        default:
            break // busy transcribing/inserting — ignore
        }
    }

    private func start() async {
        errorMessage = nil
        partialText = ""
        hideTask?.cancel()
        panel.show()

        guard await AudioCapture.ensureMicPermission() else {
            fail("未获得麦克风权限，请在「设置 → 权限」中开启。")
            return
        }

        // Apple's on-device recognition is the transcription engine, so it's
        // always needed (DeepSeek only does the text cleanup afterwards).
        let speechGranted = await AudioCapture.ensureSpeechPermission()

        do {
            try capture.start(livePreview: speechGranted && livePreviewEnabled,
                              localeIdentifier: recognitionLocale)
        } catch {
            fail("录音启动失败：\(error.localizedDescription)")
            return
        }
        levels = Array(repeating: 0.03, count: barCount)
        audioLevel = 0
        recordingSeconds = 0
        phase = .recording
        startClock()
    }

    private func stop() async {
        stopClock()
        guard let url = capture.stop() else {
            fail("没有录到音频。")
            return
        }

        // 1) Transcribe locally with Apple's recognizer.
        phase = .transcribing
        let recognized = await AudioCapture.recognizeFile(url, localeIdentifier: recognitionLocale)
        try? FileManager.default.removeItem(at: url)

        let raw = (recognized ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            fail("没有识别到内容。请确认已开启「语音识别」权限后重试。")
            return
        }

        // 2) Optionally tidy up / correct with DeepSeek (falls back to raw on failure).
        var text = raw
        let key = KeychainHelper.load() ?? ""
        if correctionEnabled, !key.isEmpty {
            phase = .correcting
            if let cleaned = try? await DeepSeekClient(apiKey: key).correct(raw, model: chatModel),
               !cleaned.isEmpty {
                text = cleaned
            }
        }

        // 3) Insert (and keep the text around for the copy button).
        phase = .inserting
        lastResultText = text
        lastResultPasted = TextInserter.insert(text)
        addHistory(text)
        succeed()
    }

    // MARK: - Live updates

    private func pushLevel(_ level: CGFloat) {
        guard phase == .recording else { return }
        audioLevel = level
        var arr = levels
        arr.removeFirst()
        arr.append(level)
        levels = arr
    }

    // MARK: - Timer

    private func startClock() {
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated { self.recordingSeconds += 1 }
        }
    }

    private func stopClock() {
        clockTimer?.invalidate()
        clockTimer = nil
    }

    // MARK: - History

    func clearHistory() {
        history = []
        saveHistory()
    }

    func deleteHistory(_ record: DictationRecord) {
        history.removeAll { $0.id == record.id }
        saveHistory()
    }

    private func addHistory(_ text: String) {
        history.insert(DictationRecord(text: text), at: 0)
        if history.count > 50 { history.removeLast(history.count - 50) }
        saveHistory()
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: Keys.historyData)
        }
    }

    private static func loadHistory() -> [DictationRecord] {
        guard let data = UserDefaults.standard.data(forKey: Keys.historyData),
              let records = try? JSONDecoder().decode([DictationRecord].self, from: data) else {
            return []
        }
        return records
    }

    // MARK: - Result presentation

    private func succeed() {
        phase = .success
        scheduleHide(after: 3.5) // long enough to click the copy button
    }

    /// Copies the last dictation result to the clipboard (manual fallback when
    /// auto-paste lands in the wrong place) and keeps the pill up a moment.
    func copyLastResult() {
        guard !lastResultText.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(lastResultText, forType: .string)
        hideTask?.cancel()
        scheduleHide(after: 1.5)
    }

    private func fail(_ message: String) {
        stopClock()
        errorMessage = message
        phase = .failed
        scheduleHide(after: 2.4)
    }

    private func scheduleHide(after seconds: Double) {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            panel.hide()
            phase = .idle
            partialText = ""
        }
    }
}
