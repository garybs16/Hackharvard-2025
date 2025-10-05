import SwiftUI

@main
struct ReadARLandingApp: App {
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
        #endif
    }
}
