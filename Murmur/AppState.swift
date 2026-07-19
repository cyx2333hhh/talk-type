import SwiftUI
import AppKit
import Combine
import NaturalLanguage

/// User-defaults keys + their default values.
enum Keys {
    static let chatModel = "chatModel"
    static let language = "language"
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
    Talk-type
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
    private var liveRawTranscript = ""
    private var liveCorrectedSource = ""
    private var liveCorrectedText = ""
    private var liveCorrectionTask: Task<Void, Never>?

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
            MainActor.assumeIsolated { self?.receiveLiveTranscript(text) }
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
        liveRawTranscript = ""
        liveCorrectedSource = ""
        liveCorrectedText = ""
        liveCorrectionTask?.cancel()
        liveCorrectionTask = nil
        hideTask?.cancel()
        capturedInputContext = inputContextEnabled
            ? TextInserter.focusedTextContext()
            : .empty
        panel.show()

        guard await AudioCapture.ensureMicPermission() else {
            fail("未获得麦克风权限，请在「设置 → 权限」中开启。")
            return
        }

        let whisperReady = LocalWhisperTranscriber.isAvailable
        let speechIsRequired = !whisperReady
        let speechGranted: Bool
        if livePreviewEnabled || speechIsRequired {
            speechGranted = await AudioCapture.ensureSpeechPermission()
        } else {
            speechGranted = AudioCapture.speechAuthorized()
        }
        guard !speechIsRequired || speechGranted else {
            fail("Apple Speech 不可用，且本地 Whisper 尚未就绪。请在设置中检查语音识别权限。")
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
        liveCorrectionTask?.cancel()
        liveCorrectionTask = nil
        // Apple Speech drives the text the user can already see in the overlay.
        // Keep that result as a real candidate instead of throwing it away when
        // the slower file-based pass starts.
        let liveTranscript = liveRawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let reusableCorrection = liveCorrectedSource == liveTranscript
            ? liveCorrectedText.trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        guard let capturedAudio = capture.stop() else {
            fail("没有录到音频。")
            return
        }
        let url = capturedAudio.url
        defer { try? FileManager.default.removeItem(at: url) }

        guard capturedAudio.hasMeaningfulSpeech else {
            fail("未检测到语音，本次输入已取消。")
            return
        }

        let inputContext = capturedInputContext
        capturedInputContext = .empty

        // 1) Apple Speech is authoritative whenever it produced visible text.
        // Only retry Apple on the recorded file when the live result is empty;
        // Whisper is a last-resort fallback, never an automatic replacement.
        phase = .transcribing
        let contextualStrings = recognitionContextTerms
        var usedWhisper = false
        var raw = liveTranscript

        if raw.isEmpty {
            var speechGranted = AudioCapture.speechAuthorized()
            if !speechGranted {
                speechGranted = await AudioCapture.ensureSpeechPermission()
            }
            if speechGranted {
                raw = await AudioCapture.recognizeFile(url,
                                                       localeIdentifier: recognitionLocale,
                                                       contextualStrings: contextualStrings)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }
        }

        if raw.isEmpty, LocalWhisperTranscriber.isAvailable {
            raw = await LocalWhisperTranscriber.transcribe(url,
                                                           language: language,
                                                           vocabulary: contextualStrings,
                                                           inputContext: inputContext)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            usedWhisper = !raw.isEmpty
        }

        guard !raw.isEmpty else {
            fail("没有识别到内容。请靠近麦克风后重试，或在设置中检查语音识别权限。")
            return
        }
        partialText = raw

        // 2) Optionally tidy up / correct with DeepSeek (falls back to raw on failure).
        var text = raw
        let key = KeychainHelper.load() ?? ""
        let shouldUseAI = AppState.shouldUseAI(for: raw,
                                               inputContext: inputContext,
                                               vocabulary: contextualStrings)
        if correctionEnabled, shouldUseAI, !key.isEmpty {
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
            if !reusableCorrection.isEmpty,
               raw == liveTranscript,
               AppState.shouldAcceptCorrectedText(raw: raw,
                                                  cleaned: reusableCorrection,
                                                  inputContext: inputContext) {
                text = reusableCorrection
            } else if let cleaned = try? await DeepSeekClient(apiKey: key).correct(raw,
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
            partialText = text
        }

        // 3) Insert (and keep the text around for the copy button).
        phase = .inserting
        text = TextInserter.textForInsertion(text, context: inputContext)
        // The overlay and the target input receive this exact same string.
        partialText = text
        lastResultText = text
        lastResultPasted = TextInserter.insert(text)
        addHistory(text)
        succeed()
    }

    // MARK: - Live updates

    private func receiveLiveTranscript(_ text: String) {
        guard phase == .recording else { return }
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw != liveRawTranscript else { return }

        liveRawTranscript = raw
        partialText = raw
        scheduleLiveCorrection(for: raw)
    }

    /// Debounces partial Speech updates so AI cleanup begins during recording
    /// without issuing a request for every interim token.
    private func scheduleLiveCorrection(for raw: String) {
        liveCorrectionTask?.cancel()
        liveCorrectionTask = nil
        let contextualStrings = recognitionContextTerms
        let inputContext = capturedInputContext
        guard correctionEnabled,
              AppState.shouldUseAI(for: raw,
                                   inputContext: inputContext,
                                   vocabulary: contextualStrings) else { return }

        let model = chatModel
        liveCorrectionTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 700_000_000)
                try Task.checkCancellation()
                guard let self,
                      self.phase == .recording,
                      self.liveRawTranscript == raw else { return }

                let key = KeychainHelper.load() ?? ""
                guard !key.isEmpty else { return }
                let cleaned = try await DeepSeekClient(apiKey: key).correct(
                    raw,
                    model: model,
                    contextualStrings: contextualStrings,
                    inputContext: inputContext
                )
                try Task.checkCancellation()
                guard self.phase == .recording,
                      self.liveRawTranscript == raw,
                      !cleaned.isEmpty,
                      AppState.shouldAcceptCorrectedText(raw: raw,
                                                         cleaned: cleaned,
                                                         inputContext: inputContext) else { return }

                self.liveCorrectedSource = raw
                self.liveCorrectedText = cleaned
                self.partialText = cleaned
            } catch {
                // Live cleanup is best-effort. Raw Speech text remains visible,
                // and the final pass can still retry after recording stops.
            }
        }
    }

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

    /// Standalone terms are inserted exactly as Apple Speech recognized them.
    /// Sentences and terms inserted before existing text may use AI for
    /// punctuation or context-aware correction.
    static func shouldUseAI(for text: String,
                            inputContext: FocusedTextContext,
                            vocabulary: [String]) -> Bool {
        if inputContext.hasFollowingTextOnCurrentLine { return true }
        return !isStandaloneTerm(text, vocabulary: vocabulary)
    }

    static func isStandaloneTerm(_ text: String, vocabulary: [String]) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains(where: { $0.isNewline }) else { return false }

        let normalized = signalText(trimmed)
        if vocabulary.contains(where: { signalText($0) == normalized }) {
            return true
        }

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = trimmed
        var tokenCount = 0
        tokenizer.enumerateTokens(in: trimmed.startIndex..<trimmed.endIndex) { _, _ in
            tokenCount += 1
            return tokenCount < 2
        }
        return tokenCount == 1
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

        if !hasConservativeContentChange(raw: raw,
                                         cleaned: cleaned,
                                         inputContext: inputContext) {
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

    /// Punctuation, whitespace and casing are free to change. Word/character
    /// changes are tightly bounded so a cleanup model cannot replace a correct
    /// transcript with a different sentence of similar length.
    private static func hasConservativeContentChange(raw: String,
                                                     cleaned: String,
                                                     inputContext: FocusedTextContext) -> Bool {
        let rawContent = Array(signalText(raw))
        let cleanedContent = Array(signalText(cleaned))
        if rawContent == cleanedContent { return true }

        let longest = max(rawContent.count, cleanedContent.count)
        if longest <= 8 {
            guard inputContext.hasFollowingTextOnCurrentLine else { return false }
            let allowedInlineChanges = min(2, longest)
            return editDistance(rawContent,
                                cleanedContent,
                                stoppingAfter: allowedInlineChanges) <= allowedInlineChanges
        }
        // Sentence cleanup may need two adjacent substitutions to recover a
        // split homophone (for example “确实别” -> “却识别”). Standalone terms
        // never reach AI, so this wider allowance only applies with context.
        let allowedChanges = max(2, min(8, (longest + 5) / 6))
        guard abs(rawContent.count - cleanedContent.count) <= allowedChanges else { return false }
        return editDistance(rawContent, cleanedContent, stoppingAfter: allowedChanges) <= allowedChanges
    }

    private static func editDistance(_ lhs: [Character],
                                     _ rhs: [Character],
                                     stoppingAfter limit: Int) -> Int {
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }

        var previous = Array(0...rhs.count)
        for (leftIndex, left) in lhs.enumerated() {
            var current = Array(repeating: 0, count: rhs.count + 1)
            current[0] = leftIndex + 1
            var rowMinimum = current[0]

            for (rightIndex, right) in rhs.enumerated() {
                let substitutionCost = left == right ? 0 : 1
                current[rightIndex + 1] = min(
                    previous[rightIndex + 1] + 1,
                    current[rightIndex] + 1,
                    previous[rightIndex] + substitutionCost
                )
                rowMinimum = min(rowMinimum, current[rightIndex + 1])
            }

            if rowMinimum > limit { return limit + 1 }
            previous = current
        }
        return previous[rhs.count]
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
        liveCorrectionTask?.cancel()
        liveCorrectionTask = nil
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
