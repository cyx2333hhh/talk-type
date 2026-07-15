import Foundation

/// Runs the locally installed whisper.cpp CLI with the downloaded Small model.
/// Apple Speech remains the fallback when either dependency is unavailable.
enum LocalWhisperTranscriber {
    static let modelName = "Whisper Small"

    static var isAvailable: Bool {
        executableURL != nil && FileManager.default.fileExists(atPath: modelURL.path)
    }

    static func transcribe(_ audioURL: URL,
                           language: String,
                           vocabulary: [String],
                           inputContext: FocusedTextContext) async -> String? {
        guard let executableURL,
              FileManager.default.fileExists(atPath: modelURL.path) else { return nil }

        let prompt = makePrompt(vocabulary: vocabulary, inputContext: inputContext)
        let whisperLanguage = normalizedLanguage(language)

        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            let output = Pipe()
            process.executableURL = executableURL

            var arguments = [
                "-ng",
                "-m", modelURL.path,
                "-f", audioURL.path,
                "-l", whisperLanguage,
                "-nt",
                "-np",
                "-sns",
            ]
            if !prompt.isEmpty {
                arguments.append(contentsOf: ["--prompt", prompt, "--carry-initial-prompt"])
            }
            process.arguments = arguments
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0,
                      let transcript = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                      !transcript.isEmpty else { return nil }
                return transcript
            } catch {
                return nil
            }
        }.value
    }

    private static var modelURL: URL {
        let applicationSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
        let current = applicationSupport
            .appendingPathComponent("Talk-type/Models/ggml-small.bin")
        if FileManager.default.fileExists(atPath: current.path) {
            return current
        }

        // Keep existing model downloads working after the product rename.
        return applicationSupport
            .appendingPathComponent("Murmur/Models/ggml-small.bin")
    }

    private static var executableURL: URL? {
        let candidates = [
            "/opt/homebrew/bin/whisper-cli",
            "/usr/local/bin/whisper-cli",
        ]
        return candidates.first(where: FileManager.default.isExecutableFile(atPath:))
            .map(URL.init(fileURLWithPath:))
    }

    private static func normalizedLanguage(_ language: String) -> String {
        let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return "auto" }
        if normalized.hasPrefix("zh") { return "zh" }
        if normalized.hasPrefix("en") { return "en" }
        return normalized.split(separator: "-").first.map(String.init) ?? "auto"
    }

    private static func makePrompt(vocabulary: [String],
                                   inputContext: FocusedTextContext) -> String {
        var parts = ["以下是以中文为主、可能夹杂英文专名的语音记录。"]

        // A short hint improves proper nouns without flooding the decoder with
        // English tokens that could make ordinary Chinese sound like English.
        let terms = vocabulary.prefix(24).joined(separator: "、")
        if !terms.isEmpty {
            parts.append("可能出现：\(terms)。")
        }

        let precedingText = inputContext.beforeCursor
            .suffix(320)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !precedingText.isEmpty {
            parts.append("前文：\(precedingText)")
        }
        return parts.joined(separator: " ")
    }
}
