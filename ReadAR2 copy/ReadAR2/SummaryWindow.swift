import SwiftUI

// Request type to open a summary window for a given paragraph
import UniformTypeIdentifiers
import Foundation

struct SummaryOpenRequest: Codable, Hashable, Transferable {
    static let type = UTType(exportedAs: "com.readar.summary-open-request")
    let paragraph: String
    static var transferRepresentation: some TransferRepresentation { CodableRepresentation(contentType: type) }
}

struct SummaryWindow: View {
    let paragraph: String

    @State private var isSummarizing = true
    @State private var summaryText: String = ""
    @State private var errorText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(.blue, .purple)
                Text("Gemini Summary").font(.headline)
                Spacer()
            }
            .padding(.bottom, 4)

            if isSummarizing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Summarizing…").foregroundStyle(.secondary)
                }
            } else if let err = errorText {
                Text("Error: \(err)").foregroundStyle(.red)
            } else {
                ScrollView { Text(summaryText).font(.body) }
            }

            Divider().padding(.top, 4)
            Text("Paragraph:")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView { Text(paragraph).font(.footnote).foregroundStyle(.secondary) }
        }
        .padding(16)
        .frame(minWidth: 360, idealWidth: 420, maxWidth: 520, minHeight: 220)
        .task { await summarize() }
        .glassBackgroundEffect()
    }

    @MainActor
    private func summarize() async {
        do {
            let result = try await GeminiSummarizer.shared.summarize(paragraph)
            summaryText = result
            isSummarizing = false
        } catch {
            errorText = String(describing: error)
            isSummarizing = false
        }
    }
}

#Preview("Summary Window") {
    SummaryWindow(paragraph: "This is an example paragraph about machine learning models and their applications in education.")
        .frame(width: 420, height: 300)
}
