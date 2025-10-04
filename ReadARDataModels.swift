import Foundation

// MARK: - Health
struct HealthResponse: Codable { let ok: Bool }

// MARK: - Features
struct Feature: Codable, Identifiable {
    let id: UUID
    let color: String
    let title: String
    let subtitle: String
    
    init(id: UUID = UUID(), color: String, title: String, subtitle: String) {
        self.id = id
        self.color = color
        self.title = title
        self.subtitle = subtitle
    }
}
struct FeaturesResponse: Codable { let items: [Feature] }

// MARK: - Define / Explain
struct DefineRequest: Codable { let term: String }
struct DefineResponse: Codable { let term: String; let definition: String }

struct ExplainRequest: Codable { let text: String }
struct ExplainResponse: Codable { let explanation: String }
