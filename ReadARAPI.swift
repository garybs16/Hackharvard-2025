import Foundation

struct Feature: Decodable { let color: String; let title: String; let subtitle: String }
struct FeaturesResponse: Decodable { let items: [Feature] }
struct SyllabifyToken: Decodable { let raw: String; let syllables: [String] }
struct SyllabifyResponse: Decodable { let tokens: [SyllabifyToken] }
struct ReadabilityResponse: Decodable {
    let flesch_kincaid_grade: Double
    let flesch_reading_ease: Double
    let total_words: Int
    let total_sentences: Int
    let total_syllables: Int
}
struct FocusSuggestResponse: Decodable { let next_index: Int }
struct NarrateResponse: Decodable { let ssml: String }

enum ReadARAPI {
    static var baseURL = URL(string: "http://127.0.0.1:5055")!

    static func health() async -> Bool {
        guard let url = URL(string: "/api/health", relativeTo: baseURL) else { return false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let js = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return (js?["ok"] as? Bool) == true
        } catch { return false }
    }

    static func features() async -> [Feature] {
        guard let url = URL(string: "/api/features", relativeTo: baseURL) else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return (try? JSONDecoder().decode(FeaturesResponse.self, from: data).items) ?? []
        } catch { return [] }
    }

    static func define(_ word: String) async -> String {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("/api/define"), resolvingAgainstBaseURL: false) else { return "" }
        comps.queryItems = [URLQueryItem(name: "q", value: word)]
        guard let url = comps.url else { return "" }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let js = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return (js?["definition"] as? String) ?? ""
        } catch { return "" }
    }

    static func syllabify(text: String) async -> [SyllabifyToken] {
        (try? await post("/api/syllabify", body: ["text": text], as: SyllabifyResponse.self).tokens) ?? []
    }

    static func readability(text: String) async -> ReadabilityResponse? {
        try? await post("/api/readability", body: ["text": text], as: ReadabilityResponse.self)
    }

    static func nextFocusIndex(lines: [String], current: Int) async -> Int {
        (try? await post("/api/focus/suggest", body: ["lines": lines, "current_index": current], as: FocusSuggestResponse.self).next_index) ?? 0
    }

    static func narrate(text: String) async -> NarrateResponse? {
        try? await post("/api/narrate", body: ["text": text, "voice_hint": "en-US", "rate": 1.0], as: NarrateResponse.self)
    }

    private static func post<T: Decodable>(_ path: String, body: [String: Any], as: T.Type) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
