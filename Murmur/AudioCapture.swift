import AVFoundation
import Speech
import CoreGraphics

/// Captures the microphone with a single AVAudioEngine that does three jobs at
/// once: writes a WAV file for the final OpenAI Whisper pass, feeds Apple's
/// on-device SFSpeechRecognizer for a live preview, and emits an audio level for
/// the waveform / orb animation. The live preview is best-effort — if Speech
/// isn't authorized the file + level path still works.
final class AudioCapture {
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var fileURL: URL?

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Delivered on the main queue.
    var onLevel: ((CGFloat) -> Void)?
    var onPartial: ((String) -> Void)?

    func start(livePreview: Bool, localeIdentifier: String) throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("murmur-\(UUID().uuidString).wav")
        file = try AVAudioFile(forWriting: url, settings: format.settings)
        fileURL = url

        if livePreview {
            setupRecognition(localeIdentifier: localeIdentifier)
        }

        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            try? self.file?.write(from: buffer)
            self.request?.append(buffer)
            let level = AudioCapture.level(of: buffer)
            DispatchQueue.main.async { self.onLevel?(level) }
        }

        engine.prepare()
        try engine.start()
    }

    private func setupRecognition(localeIdentifier: String) {
        let rec = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
            ?? SFSpeechRecognizer()
        guard let rec, rec.isAvailable,
              SFSpeechRecognizer.authorizationStatus() == .authorized else { return }
        recognizer = rec

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req
        task = rec.recognitionTask(with: req) { [weak self] result, _ in
            guard let self, let result else { return }
            let text = result.bestTranscription.formattedString
            DispatchQueue.main.async { self.onPartial?(text) }
        }
    }

    /// Stops capture and returns the recorded file URL.
    func stop() -> URL? {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        request?.endAudio()
        task?.finish()
        task = nil
        request = nil
        recognizer = nil
        let url = fileURL
        file = nil
        fileURL = nil
        return url
    }

    // MARK: - Permissions

    static func ensureMicPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:    return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default:             return false
        }
    }

    static func speechAuthorized() -> Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    /// One-shot on-device/server recognition of a recorded file — used as the
    /// final transcription when no OpenAI key is set. Returns nil if speech
    /// recognition isn't authorized or available.
    static func recognizeFile(_ url: URL, localeIdentifier: String) async -> String? {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { return nil }
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
            ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else { return nil }

        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            var resumed = false
            var task: SFSpeechRecognitionTask?
            task = recognizer.recognitionTask(with: request) { [recognizer] result, error in
                _ = recognizer // keep the recognizer alive until completion
                if let result, result.isFinal {
                    if !resumed { resumed = true; cont.resume(returning: result.bestTranscription.formattedString) }
                    task = nil
                } else if error != nil {
                    if !resumed { resumed = true; cont.resume(returning: nil) }
                    task = nil
                }
            }
            _ = task
        }
    }

    static func ensureSpeechPermission() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
            }
        default:
            return false
        }
    }

    // MARK: - Level metering

    private static func level(of buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0.03 }
        let count = Int(buffer.frameLength)
        let samples = channels[0]
        var sum: Float = 0
        for i in 0..<count {
            let s = samples[i]
            sum += s * s
        }
        let rms = sqrtf(sum / Float(count))
        let db = 20 * log10f(max(rms, 1e-7))
        let floor: Float = -50
        guard db > floor else { return 0.03 }
        let norm = (db - floor) / (0 - floor)
        return CGFloat(max(0.03, min(1, norm)))
    }
}
