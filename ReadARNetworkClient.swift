import Foundation

// MARK: - ReadAR API Client
enum ReadARAPI {
    /// For device testing on Wi-Fi, set this to your Mac's LAN IP:
    /// ReadARAPI.baseURL = URL(string: "http://192.168.1.23:5055")!
    static var baseURL: URL = URL(string: "http://127.0.0.1:5055")!
    
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }()
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .useDefaultKeys
        return e
    }()
    
    static func health() async throws -> HealthResponse {
        let url = baseURL.appending(path: "/api/health")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(HealthResponse.self, from: data)
    }
    
    static func features() async throws -> [Feature] {
        let url = baseURL.appending(path: "/api/features")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(FeaturesResponse.self, from: data).items
    }
    
    static func define(term: String) async throws -> DefineResponse {
        let url = baseURL.appending(path: "/api/define")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(DefineRequest(term: term))
        let (data, _) = try await URLSession.shared.data(for: req)
        return try decoder.decode(DefineResponse.self, from: data)
    }
    
    static func explain(text: String) async throws -> ExplainResponse {
        let url = baseURL.appending(path: "/api/explain")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(ExplainRequest(text: text))
        let (data, _) = try await URLSession.shared.data(for: req)
        return try decoder.decode(ExplainResponse.self, from: data)
    }
}
