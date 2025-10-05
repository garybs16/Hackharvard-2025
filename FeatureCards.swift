import SwiftUI

struct FeatureCardVisual: View {
    let items: [(Color, String, String, String)] = [
        (.blue, "Eye tracking", "Dynamic text highlight", "eye.fill"),
        (.purple, "Focus modes", "Line • Word • Syllable", "scope"),
        (.green, "Word lookup", "Tap to define / speak", "book.fill"),
        (.orange, "Narration", "Read-aloud sync", "speaker.wave.3.fill"),
        (.teal, "Accessibility", "Dyslexia & ADHD", "accessibility")
    ]

    var body: some View {
        VStack(spacing: 24) {
            HStack { Image(systemName: "sparkles").font(.title2).foregroundColor(.indigo); Text("Key Features").font(.system(size: 32, weight: .black, design: .rounded)).foregroundColor(.indigo); Spacer() }
            .padding(.horizontal, 8)
            VStack(spacing: 20) {
                let pairCount = items.count / 2
                ForEach(0..<pairCount, id: \.self) { row in
                    HStack(spacing: 20) {
                        FeatureBullet(color: items[row * 2].0, title: items[row * 2].1, subtitle: items[row * 2].2, iconName: items[row * 2].3)
                        FeatureBullet(color: items[row * 2 + 1].0, title: items[row * 2 + 1].1, subtitle: items[row * 2 + 1].2, iconName: items[row * 2 + 1].3)
                    }
                }
                if items.count % 2 == 1 { HStack { Spacer(); FeatureBullet(color: items.last!.0, title: items.last!.1, subtitle: items.last!.2, iconName: items.last!.3).frame(maxWidth: 200); Spacer() } }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }
}

struct FeatureBullet: View {
    var color: Color
    var title: String
    var subtitle: String
    var iconName: String
    @State private var isShining = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.15), color.opacity(0.25), color.opacity(0.10)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(LinearGradient(gradient: Gradient(colors: [color.opacity(0.4), color.opacity(0.2), color.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
                    .shadow(color: color.opacity(0.25), radius: 12, x: 0, y: 6)
                    .shadow(color: color.opacity(0.1), radius: 24, x: 0, y: 12)
                Image(systemName: iconName).font(.system(size: 24, weight: .medium)).foregroundStyle(LinearGradient(gradient: Gradient(colors: [color, color.opacity(0.7), color]), startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: .white.opacity(0.3), radius: 1, x: 0, y: 1)
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(gradient: Gradient(stops: [.init(color: .clear, location: 0.0), .init(color: .white.opacity(0.3), location: 0.4), .init(color: .white.opacity(0.6), location: 0.5), .init(color: .white.opacity(0.3), location: 0.6), .init(color: .clear, location: 1.0)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                    .mask(Image(systemName: iconName).font(.system(size: 24, weight: .medium)))
                    .opacity(isShining ? 1.0 : 0.0)
                    .animation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(Double.random(in: 0...2)), value: isShining)
            }
            .onAppear { isShining = true }
            VStack(spacing: 10) { Text(title).font(.title3.weight(.bold)).foregroundColor(.primary).multilineTextAlignment(.center); Text(subtitle).font(.subheadline.weight(.medium)).foregroundColor(.secondary).multilineTextAlignment(.center).lineLimit(2).fixedSize(horizontal: false, vertical: true) }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(
            ZStack { RoundedRectangle(cornerRadius: 28).fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.04), color.opacity(0.08), color.opacity(0.03)]), startPoint: .topLeading, endPoint: .bottomTrailing)); RoundedRectangle(cornerRadius: 28).stroke(LinearGradient(gradient: Gradient(colors: [color.opacity(0.2), color.opacity(0.1), color.opacity(0.05)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2) }
                .shadow(color: color.opacity(0.12), radius: 20, x: 0, y: 8)
                .shadow(color: color.opacity(0.06), radius: 40, x: 0, y: 20)
        )
    }
}
//
//  FeatureCards.swift
//  ReadAR
//
//  Created by Eason Ying on 10/4/25.
//


