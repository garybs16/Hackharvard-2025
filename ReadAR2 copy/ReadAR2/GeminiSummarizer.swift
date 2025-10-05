// GeminiSummarizer.swift
// Provides a minimal client for Google's Gemini API to summarize text

import Foundation

final class GeminiSummarizer {
    static let shared = GeminiSummarizer()
    private init() {}

    private var apiKey: String?
    private let model: String = "gemini-2.5-pro" // higher-quality model per request

    func configure(apiKey: String) {
        self.apiKey = apiKey
    }

    enum GeminiError: Error, LocalizedError {
        case notConfigured
        case badURL
        case invalidResponse(status: Int, message: String)
        case empty

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "GeminiSummarizer is not configured with an API key."
            case .badURL: return "Invalid Gemini API URL."
            case .invalidResponse(let status, let message): return "Gemini API error (\(status)): \(message)"
            case .empty: return "Gemini returned an empty response."
            }
        }
    }

    // Summarize the provided paragraph into a brief, accessible explanation.
    func summarize(_ text: String) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else { throw GeminiError.notConfigured }
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else { throw GeminiError.badURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Gemini generateContent body
        struct Part: Codable { let text: String }
        struct Content: Codable { let parts: [Part] }
        struct RequestBody: Codable { let contents: [Content] }
        let prompt = "Summarize the following paragraph in 2-3 sentences, in clear, simple language for quick understanding.\n\nParagraph:\n\(text)"
        let body = RequestBody(contents: [Content(parts: [Part(text: prompt)])])
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.invalidResponse(status: http.statusCode, message: message)
        }

        // Parse response: { candidates: [ { content: { parts: [ { text: "..." } ] } } ] }
        struct ResponsePart: Codable { let text: String? }
        struct ResponseContent: Codable { let parts: [ResponsePart]? }
        struct Candidate: Codable { let content: ResponseContent? }
        struct ResponseBody: Codable { let candidates: [Candidate]? }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        if let text = decoded.candidates?.first?.content?.parts?.first?.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        throw GeminiError.empty
    }
}

