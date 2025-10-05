import SwiftUI

struct ReaderPreview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var highlightIndex = 0
    private let lines = [
        "Spatial reading with dynamic line highlight.",
        "Tap a line to focus it visually.",
        "Syllable view available in full app.",
        "Adjust font and spacing for comfort."
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Reading Preview").font(.title.weight(.bold)).foregroundColor(.primary)
                    Text("Experience ReadAR's intelligent highlighting").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(lines.indices, id: \.self) { i in
                        Text(lines[i])
                            .font(.title3.weight(.medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(i == highlightIndex ? LinearGradient(gradient: Gradient(colors: [.yellow.opacity(0.15), .orange.opacity(0.1)]), startPoint: .leading, endPoint: .trailing) : LinearGradient(gradient: Gradient(colors: [.clear, .clear]), startPoint: .leading, endPoint: .trailing))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(i == highlightIndex ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: i == highlightIndex ? 2 : 1))
                            )
                            .scaleEffect(i == highlightIndex ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: highlightIndex)
                            .onTapGesture { withAnimation(.easeInOut(duration: 0.3)) { highlightIndex = i } }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial).shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 10))
                .padding(.horizontal, 20)

                Spacer()
                Text("Tap any line to highlight and focus").font(.callout).foregroundColor(.secondary).padding(.bottom, 20)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.font(.headline).foregroundColor(.indigo) } }
        }
    }
}
//
//  ReaderPreview.swift
//  ReadAR
//
//  Created by Eason Ying on 10/4/25.
//

