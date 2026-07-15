import SwiftUI
import AppKit
import Combine

/// User-defaults keys + their default values.
enum Keys {
    static let chatModel = "chatModel"
    static let language = "language"
    static let recognitionEngine = "recognitionEngine"
    static let recognitionContext = "recognitionContext"
    static let enableBilingualRecognition = "enableBilingualRecognition"
    static let bilingualRecognitionSafetyReset = "bilingualRecognitionSafetyReset"
    static let enableCorrection = "enableCorrection"
    static let enableLivePreview = "enableLivePreview"
    static let useInputContext = "useInputContext"
    static let useFnKey = "useFnKey"
    static let hotKeyCode = "hotKeyCode"
    static let hotKeyMods = "hotKeyMods"
    static let hotKeyDisplay = "hotKeyDisplay"
    static let historyData = "historyData"

    static let defaultRecognitionContext = """
    Murmur
    DeepSeek
    ChatGPT
    GPT
    Claude
    Codex
    OpenAI
    API
    key
    macOS
    iOS
    Swift
    SwiftUI
    Xcode
    GitHub
    Git
    branch
    commit
    pull request
    README
    JSON
    HTTP
    URL
    SQL
    JavaScript
    TypeScript
    Python
    React
    Vue
    Node.js
    npm
    Docker
    Kubernetes
    Terminal
    shell
    Safari
    Chrome
    Finder
    Notion
    Figma
    Cursor
    VS Code
    App Store
    Apple
    """

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            chatModel: "deepseek-chat",
            language: "zh",
            recognitionEngine: "whisper",
            recognitionContext: defaultRecognitionContext,
            enableBilingualRecognition: false,
            enableCorrection: true,
            enableLivePreview: true,
            useInputContext: true,
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
    private var isStarting = false
    private var capturedInputContext = FocusedTextContext.empty

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
        resetUnsafeBilingualDefaultIfNeeded()
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
    private var recognitionEngine: String {
        UserDefaults.standard.string(forKey: Keys.recognitionEngine) ?? "whisper"
    }
    private var correctionEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.enableCorrection)
    }
    private var livePreviewEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.enableLivePreview)
    }
    private var inputContextEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.useInputContext)
    }
    private var bilingualRecognitionEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.enableBilingualRecognition)
    }
    private var recognitionContextTerms: [String] {
        let raw = UserDefaults.standard.string(forKey: Keys.recognitionContext)
            ?? Keys.defaultRecognitionContext
        return AppState.parseRecognitionContext(raw)
    }
    private var recognitionLocale: String {
        let lang = language
        if lang.isEmpty { return Locale.current.identifier }
        if lang.lowercased().hasPrefix("zh") { return "zh-CN" }
        return lang
    }
    private var shouldRunEnglishAssist: Bool {
        bilingualRecognitionEnabled && recognitionLocale.lowercased().hasPrefix("zh")
    }

    private func resetUnsafeBilingualDefaultIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Keys.bilingualRecognitionSafetyReset) else { return }
        UserDefaults.standard.set(false, forKey: Keys.enableBilingualRecognition)
        UserDefaults.standard.set(true, forKey: Keys.bilingualRecognitionSafetyReset)
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
        guard !isStarting else { return }
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
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        errorMessage = nil
        partialText = ""
        hideTask?.cancel()
        capturedInputContext = inputContextEnabled
            ? TextInserter.focusedTextContext()
            : .empty
        panel.show()

        guard await AudioCapture.ensureMicPermission() else {
            fail("未获得麦克风权限，请在「设置 → 权限」中开启。")
            return
        }

        let whisperReady = recognitionEngine == "whisper" && LocalWhisperTranscriber.isAvailable
        let speechIsRequired = !whisperReady
        let speechGranted: Bool
        if livePreviewEnabled || speechIsRequired {
            speechGranted = await AudioCapture.ensureSpeechPermission()
        } else {
            speechGranted = AudioCapture.speechAuthorized()
        }
        guard !speechIsRequired || speechGranted else {
            fail("当前识别引擎不可用，且未获得「语音识别」权限。请在设置中检查识别引擎和权限。")
            return
        }

        do {
            try capture.start(livePreview: speechGranted && livePreviewEnabled,
                              localeIdentifier: recognitionLocale,
                              contextualStrings: [])
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
        defer { try? FileManager.default.removeItem(at: url) }

        let inputContext = capturedInputContext
        capturedInputContext = .empty

        // 1) Prefer local Whisper Small for mixed Chinese/English, with Apple
        // Speech as a fallback and as the live-preview engine.
        phase = .transcribing
        let contextualStrings = recognitionContextTerms
        var usedWhisper = false
        var recognized: String?

        if recognitionEngine == "whisper", LocalWhisperTranscriber.isAvailable {
            recognized = await LocalWhisperTranscriber.transcribe(url,
                                                                  language: language,
                                                                  vocabulary: contextualStrings,
                                                                  inputContext: inputContext)
            usedWhisper = !(recognized ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        }

        if !usedWhisper {
            var speechGranted = AudioCapture.speechAuthorized()
            if !speechGranted {
                speechGranted = await AudioCapture.ensureSpeechPermission()
            }
            if speechGranted {
                recognized = await AudioCapture.recognizeFile(url,
                                                              localeIdentifier: recognitionLocale,
                                                              contextualStrings: [])
            }
        }

        let raw = (recognized ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            fail("没有识别到内容。请靠近麦克风后重试，或在设置中检查识别引擎。")
            return
        }

        // 2) Optionally tidy up / correct with DeepSeek (falls back to raw on failure).
        var text = raw
        let key = KeychainHelper.load() ?? ""
        if correctionEnabled, !key.isEmpty {
            let englishAssist: String?
            if shouldRunEnglishAssist && !usedWhisper {
                englishAssist = await AudioCapture.recognizeFile(url,
                                                                 localeIdentifier: "en-US",
                                                                 contextualStrings: contextualStrings)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                englishAssist = nil
            }

            phase = .correcting
            if let cleaned = try? await DeepSeekClient(apiKey: key).correct(raw,
                                                                            model: chatModel,
                                                                            contextualStrings: contextualStrings,
                                                                            englishTranscript: englishAssist,
                                                                            inputContext: inputContext),
               !cleaned.isEmpty,
               AppState.shouldAcceptCorrectedText(raw: raw,
                                                  cleaned: cleaned,
                                                  inputContext: inputContext) {
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

    static func parseRecognitionContext(_ raw: String) -> [String] {
        raw.components(separatedBy: CharacterSet(charactersIn: "\n,，、;；"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, term in
                if !result.contains(where: { $0.caseInsensitiveCompare(term) == .orderedSame }) {
                    result.append(term)
                }
            }
    }

    private static func shouldAcceptCorrectedText(raw: String,
                                                  cleaned: String,
                                                  inputContext: FocusedTextContext = .empty) -> Bool {
        let rawSignal = signalCharacterCount(raw)
        let cleanedSignal = signalCharacterCount(cleaned)
        if rawSignal >= 8, cleanedSignal > rawSignal + max(18, rawSignal / 2) {
            return false
        }
        if rawSignal >= 18, cleanedSignal < Int(Double(rawSignal) * 0.68) {
            return false
        }
        if rawSignal >= 10, rawSignal - cleanedSignal >= 18, cleanedSignal < Int(Double(rawSignal) * 0.78) {
            return false
        }
        if !preservesDigitRuns(raw: raw, cleaned: cleaned) {
            return false
        }
        if repeatsInputContext(raw: raw, cleaned: cleaned, inputContext: inputContext) {
            return false
        }

        let rawHan = hanCharacterCount(raw)
        guard rawHan >= 2 else { return true }

        let cleanedHan = hanCharacterCount(cleaned)
        let cleanedLatin = latinLetterCount(cleaned)

        if cleanedHan == 0, cleanedLatin >= 3 {
            return false
        }
        if rawHan >= 6, cleanedHan < max(3, rawHan / 3), cleanedLatin > max(6, cleanedHan * 2) {
            return false
        }
        return true
    }

    private static func repeatsInputContext(raw: String,
                                            cleaned: String,
                                            inputContext: FocusedTextContext) -> Bool {
        guard !inputContext.isEmpty else { return false }
        let normalizedRaw = signalText(raw)
        let normalizedCleaned = signalText(cleaned)
        let contextSamples = [
            String(signalText(inputContext.beforeCursor).suffix(28)),
            String(signalText(inputContext.afterCursor).prefix(28)),
        ]

        return contextSamples.contains { sample in
            sample.count >= 10
                && normalizedCleaned.contains(sample)
                && !normalizedRaw.contains(sample)
        }
    }

    private static func signalCharacterCount(_ text: String) -> Int {
        signalText(text).count
    }

    private static func signalText(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter {
            (0x4E00...0x9FFF).contains($0.value)
                || (0x41...0x5A).contains($0.value)
                || (0x61...0x7A).contains($0.value)
                || (0x30...0x39).contains($0.value)
        })
    }

    private static func preservesDigitRuns(raw: String, cleaned: String) -> Bool {
        let runs = raw.split { !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 2 }
        guard !runs.isEmpty else { return true }
        return runs.allSatisfy { cleaned.contains($0) }
    }

    private static func hanCharacterCount(_ text: String) -> Int {
        text.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count
    }

    private static func latinLetterCount(_ text: String) -> Int {
        text.unicodeScalars.filter {
            (0x41...0x5A).contains($0.value) || (0x61...0x7A).contains($0.value)
        }.count
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
        capturedInputContext = .empty
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
