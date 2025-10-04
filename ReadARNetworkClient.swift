import Foundation

// MARK: - ReadAR API Client

enum ReadARAPI {
    /// For device testing, point this to your Mac's LAN IP:
    /// ReadARAPI.baseURL = URL(string: "http://192.168.1.23:5055")!
    static var baseURL: URL = URL(string: "http://127.0.0.1:5055")!

    // Shared JSON decoder (tweak if you add dates etc.)
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }()

    // Shared URLSession with a sane timeout
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    // MARK: - GETs

    static func health() async -> Bool {
        guard let url = URL(string: "/api/health", relativeTo: baseURL) else { return false }
        do {
            let (data, _) = try await session.data(from: url)
            return (try? decoder.decode(HealthResponse.self, from: data).ok) ?? false
        } catch {
            return false
        }
    }

    static func features() async -> [Feature] {
        guard let url = URL(string: "/api/features", relativeTo: baseURL) else { return [] }
        do {
            let (data, _) = try await session.data(from: url)
            return (try? decoder.decode(FeaturesResponse.self, from: data).items) ?? []
        } catch {
            return []
        }
    }

    static func define(_ word: String) async -> String {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("/api/define"),
                                        resolvingAgainstBaseURL: false) else { return "" }
        comps.queryItems = [URLQueryItem(name: "q", value: word)]
        guard let url = comps.url else { return "" }

        do {
            let (data, _) = try await session.data(from: url)
            // define endpoint returns { word, definition } but not always stable, parse minimally:
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let def = obj["definition"] as? String {
                return def
            }
            return ""
        } catch {
            return ""
        }
    }

    // MARK: - POSTs (JSON)

    static func syllabify(text: String) async -> [SyllabifyToken] {
        (try? await postJSON(path: "/api/syllabify",
                             body: ["text": text],
                             as: SyllabifyResponse.self).tokens) ?? []
    }

    static func readability(text: String) async -> ReadabilityResponse? {
        try? await postJSON(path: "/api/readability",
                            body: ["text": text],
                            as: ReadabilityResponse.self)
    }

    static func nextFocusIndex(lines: [String], current: Int) async -> Int {
        (try? await postJSON(path: "/api/focus/suggest",
                             body: ["lines": lines, "current_index": current],
                             as: FocusSuggestResponse.self).next_index) ?? 0
    }

    static func narrate(text: String) async -> NarrateResponse? {
        try? await postJSON(path: "/api/narrate",
                            body: ["text": text, "voice_hint": "en-US", "rate": 1.0],
                            as: NarrateResponse.self)
    }

    // MARK: - PDF Endpoints

    /// Extract text from a PDF file (multipart upload). Returns (numPages, text) on success.
    static func pdfExtract(fileName: String, data: Data) async throws -> (numPages: Int, text: String) {
        let resp: PDFExtractResponse = try await postMultipart(
            path: "/api/pdf/extract",
            fileField: "file",
            fileName: fileName,
            mimeType: "application/pdf",
            fileData: data,
            fields: [:],
            decodeAs: PDFExtractResponse.self
        )
        return (resp.numPages, resp.text)
    }

    /// Generate a PDF from text lines (JSON body). Returns raw PDF Data.
    static func pdfGenerate(title: String = "ReadAR Document", lines: [String]) async throws -> Data {
        try await postForBinary(path: "/api/pdf/generate",
                                jsonBody: ["title": title, "lines": lines])
    }

    /// Stamp/watermark a PDF (multipart upload). Returns stamped PDF Data.
    static func pdfStamp(fileName: String, data: Data, text: String = "ReadAR") async throws -> Data {
        try await postMultipartBinary(
            path: "/api/pdf/stamp",
            fileField: "file",
            fileName: fileName,
            mimeType: "application/pdf",
            fileData: data,
            fields: ["text": text]
        )
    }

    // MARK: - Low-level helpers

    private static func postJSON<T: Decodable>(path: String,
                                               body: [String: Any],
                                               as: T.Type) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, resp) = try await session.data(for: req)
        try ensureOK(resp)
        return try decoder.decode(T.self, from: data)
    }

    private static func postForBinary(path: String,
                                      jsonBody: [String: Any]) async throws -> Data {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: jsonBody, options: [])
        let (data, resp) = try await session.data(for: req)
        try ensureOK(resp)
        return data
    }

    /// Multipart/form-data POST that decodes JSON response.
    private static func postMultipart<T: Decodable>(path: String,
                                                    fileField: String,
                                                    fileName: String,
                                                    mimeType: String,
                                                    fileData: Data,
                                                    fields: [String: String],
                                                    decodeAs: T.Type) async throws -> T {
        let boundary = "----readar-\(UUID().uuidString)"
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = makeMultipartBody(boundary: boundary,
                                         fileField: fileField,
                                         fileName: fileName,
                                         mimeType: mimeType,
                                         fileData: fileData,
                                         fields: fields)
        let (data, resp) = try await session.data(for: req)
        try ensureOK(resp)
        return try decoder.decode(T.self, from: data)
    }

    /// Multipart/form-data POST that expects binary (PDF) response.
    private static func postMultipartBinary(path: String,
                                            fileField: String,
                                            fileName: String,
                                            mimeType: String,
                                            fileData: Data,
                                            fields: [String: String]) async throws -> Data {
        let boundary = "----readar-\(UUID().uuidString)"
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = makeMultipartBody(boundary: boundary,
                                         fileField: fileField,
                                         fileName: fileName,
                                         mimeType: mimeType,
                                         fileData: fileData,
                                         fields: fields)
        let (data, resp) = try await session.data(for: req)
        try ensureOK(resp)
        return data
    }

    private static func makeMultipartBody(boundary: String,
                                          fileField: String,
                                          fileName: String,
                                          mimeType: String,
                                          fileData: Data,
                                          fields: [String: String]) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        // Text fields
        for (k, v) in fields {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(k)\"\(lineBreak)\(lineBreak)")
            body.append("\(v)\(lineBreak)")
        }

        // File part
        body.append("--\(boundary)\(lineBreak)")
        body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\(lineBreak)")
        body.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)")
        body.append(fileData)
        body.append(lineBreak)

        // End
        body.append("--\(boundary)--\(lineBreak)")
        return body
    }

    private static func ensureOK(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

// MARK: - Private response types for PDF endpoints (avoid changing your models file)

private struct PDFExtractResponse: Decodable {
    let numPages: Int
    let text: String
}

// MARK: - Small Data append helper

private extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) {
            append(d)
        }
    }
}
