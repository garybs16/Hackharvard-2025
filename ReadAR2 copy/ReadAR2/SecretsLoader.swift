import Foundation

enum SecretsLoader {
    enum SecretsError: Error { case missingFile }

    /// Reads the contents of a text file at the given relative path, trimming whitespace and newlines.
    private static func readTextFile(atRelativePath relPath: String) throws -> String {
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath
        let url = URL(fileURLWithPath: cwd).appendingPathComponent(relPath)
        let data = try Data(contentsOf: url)
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return text
    }

    /// Loads the Gemini API key from ENV `GEMINI_API_KEY` or from `secrets/gemini_key.txt`.
    static func geminiAPIKey() -> String? {
        if let env = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !env.isEmpty {
            return env
        }
        do { return try readTextFile(atRelativePath: "secrets/gemini_key.txt") } catch { return nil }
    }

    /// Loads the ElevenLabs API key from ENV `ELEVENLABS_API_KEY` or from `secrets/elevenlabs_key`.
    static func elevenLabsAPIKey() -> String? {
        if let env = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"], !env.isEmpty {
            return env
        }
        // Prefer txt file, then fall back to legacy filename
        if let txt = try? readTextFile(atRelativePath: "secrets/elevenlabs_key.txt"), !txt.isEmpty {
            return txt
        }
        if let legacy = try? readTextFile(atRelativePath: "secrets/elevenlabs_key"), !legacy.isEmpty {
            return legacy
        }
        return nil
    }
}
