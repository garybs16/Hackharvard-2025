import SwiftUI

@main
struct ReadARLandingApp: App {
    var body: some Scene {
        WindowGroup {
            LandingScreen()
        }
    }
}

struct LandingScreen: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("ReadAR")
                .font(.largeTitle.bold())
                .foregroundColor(.indigo)

            Text("Helping every mind read clearly — one word at a time.")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Start Reading Experience") {
                print("Tapped!")
            }
            .padding()
            .background(Color.indigo)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding()
    }
}
