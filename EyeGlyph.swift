import SwiftUI

// Static Eye Glyph without any tracking
struct EyeGlyph: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Outer eye shape
                Capsule()
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.indigo.opacity(0.25), Color.purple.opacity(0.25)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                    )

                // Iris
                Circle()
                    .fill(LinearGradient(gradient: Gradient(colors: [.indigo, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: geo.size.minSide * 0.55, height: geo.size.minSide * 0.55)
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2))

                // Pupil
                Circle()
                    .fill(Color.black.opacity(0.9))
                    .frame(width: geo.size.minSide * 0.28, height: geo.size.minSide * 0.28)
                    .shadow(radius: 2)

                // Shine
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: geo.size.minSide * 0.12, height: geo.size.minSide * 0.12)
                    .offset(x: -geo.size.minSide * 0.18, y: -geo.size.minSide * 0.18)
                    .blur(radius: 0.5)
            }
        }
        .aspectRatio(1, contentMode: SwiftUI.ContentMode.fit)
    }
}

private extension CGSize {
    var minSide: CGFloat { min(width, height) }
}

#Preview {
    EyeGlyph()
        .frame(width: 120, height: 120)
        .padding()
}

