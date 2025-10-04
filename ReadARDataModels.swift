import Foundation

// MARK: - Health
struct HealthResponse: Codable { let ok: Bool }

// MARK: - Features
struct Feature: Codable {
    let color: String
    let title: String
    let subtitle: String
}
struct FeaturesResponse: Codable { let items: [Feature] }

// MARK: - Define / Explain
struct DefineResponse: Codable {
    let word: String
    let definition: String
}

// MARK: - Syllabify
struct SyllabifyToken: Codable { let raw: String; let syllables: [String] }
struct SyllabifyResponse: Codable { let tokens: [SyllabifyToken] }

// MARK: - Readability
struct ReadabilityResponse: Codable {
    let flesch_kincaid_grade: Double
    let flesch_reading_ease: Double
    let total_words: Int
    let total_sentences: Int
    let total_syllables: Int
}

// MARK: - Focus Suggest
struct FocusSuggestResponse: Codable { let next_index: Int }

// MARK: - Narrate
struct NarrateResponse: Codable { let ssml: String }

// MARK: - Preferences
struct Preferences: Codable {
    var font_size: Double
    var line_spacing: Double
    var theme: String
}
