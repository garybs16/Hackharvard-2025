import SwiftUI

@main
struct ReadARLandingApp: App {
    init() {
        // Configure ElevenLabs TTS at launch
        ElevenLabsTTS.shared.configure(
            apiKey: "sk_9d74e0927226556f0161f233b785ee02c61dd46f5bea510b",
            voiceID: "21m00Tcm4TlvDq8ikWAM" // Rachel
        )
        GeminiSummarizer.shared.configure(apiKey: "AIzaSyDBh7zqrggnBcCOc9A0ojUZ0C7K8MXTkEc")
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            LandingScreen()
        }
        #if os(visionOS)
        // Window to browse all pages via thumbnails
        WindowGroup(id: "pdf-browser") {
            PDFBrowserWindow()
        }
        // Window to view a specific page's extracted text
        WindowGroup(for: PageOpenRequest.self) { $request in
            PDFPageViewerWindow(initialPageIndex: $request.wrappedValue?.pageIndex)
        }
        .defaultSize(width: 500, height: 844)
        .windowResizability(.contentSize)
        // Window to show Gemini summary for a paragraph
        WindowGroup(for: SummaryOpenRequest.self) { $request in
            if let paragraph = $request.wrappedValue?.paragraph {
                SummaryWindow(paragraph: paragraph)
            } else {
                SummaryWindow(paragraph: "")
            }
        }
        .defaultSize(width: 420, height: 320)
        .windowResizability(.contentSize)
        #endif
    }
}

