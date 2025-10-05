import SwiftUI
import UIKit
import AVFoundation

// A panel that displays the provided paragraph text and animates a left→right highlight per line.
struct FocusReaderPanel: View {
    let text: String
    var wpm: Double = 120
    var width: CGFloat = 700
    var lineSpacing: CGFloat = 6
    var font: UIFont = .systemFont(ofSize: 22, weight: .medium)
    var onFinished: (() -> Void)? = nil

    @State private var lineRects: [CGRect] = []
    @State private var currentLine: Int = 0
    @State private var lineProgress: CGFloat = 0
    @State private var isRunning: Bool = false
    @State private var lastTick: Date = .init()

    @State private var isSpeaking: Bool = false
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var audioDelegate = AudioDelegate()

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Text content (non-selectable SwiftUI Text, using same width as measurer)
            ScrollView { // in case of long paragraphs
                VStack(alignment: .leading, spacing: lineSpacing) {
                    Text(text)
                        .font(.system(size: font.pointSize, weight: font.swiftUIWeight))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: width, alignment: .leading)
                .background(
                    LineMeasurer(text: text, width: width, font: font, lineSpacing: lineSpacing) { rects in
                        lineRects = rects
                        start()
                    }
                    .frame(width: 0, height: 0)
                    .hidden()
                )
            }
            .frame(width: width)

            // Tracks
            ForEach(lineRects.indices, id: \.self) { i in
                let r = lineRects[i]
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.yellow.opacity(0.08))
                    .frame(width: r.width, height: max(6, min(12, r.height * 0.25)))
                    .position(x: r.midX, y: r.maxY + 6)
            }
            // Active fill
            if currentLine < lineRects.count {
                let r = lineRects[currentLine]
                let fillWidth = r.width * max(0, min(1, lineProgress))
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.yellow.opacity(0.6))
                    .frame(width: fillWidth, height: max(6, min(12, r.height * 0.25)))
                    .position(x: r.minX + fillWidth / 2, y: r.maxY + 6)
                    .shadow(color: .yellow.opacity(0.6), radius: 6)
            }

            // Driver
            TimelineView(.animation) { ctx in
                Color.clear
                    .onChange(of: ctx.date) { _ in tick(now: ctx.date) }
            }

            // TTS control button on the right
            VStack {
                HStack {
                    Spacer()
                    Button(action: toggleSpeak) {
                        Image(systemName: isSpeaking ? "pause.circle.fill" : "speaker.wave.2.circle.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white, .black.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .padding(2)
                }
                Spacer()
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onAppear {
            lastTick = Date()
            audioDelegate.onFinish = {
                isSpeaking = false
            }
        }
        .onDisappear {
            audioPlayer?.stop()
            isSpeaking = false
        }
    }

    private func start() {
        currentLine = 0
        lineProgress = 0
        isRunning = !lineRects.isEmpty
        lastTick = Date()
    }

    private func tick(now: Date) {
        guard isRunning, currentLine < lineRects.count else { return }
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        let wps = max(1.0, wpm) / 60.0
        // Estimate words per line by splitting the original text proportionally by line width.
        // Simpler: use a constant speed over visual width (proxy for words). Scale by width.
        let r = lineRects[currentLine]
        // Calibrate: assume ~12 chars per visual cm; approximate duration by text proportion.
        // Use a baseline of 8 words per 300pt at 120 WPM.
        let baseWidth: CGFloat = 300
        let words = max(1.0, Double(r.width / baseWidth) * 8.0)
        var dur = words / max(wps, 0.01)
        dur = min(max(dur, 0.75), 4.0)

        if dur > 0 {
            lineProgress = min(1.0, lineProgress + CGFloat(dt / dur))
            if lineProgress >= 1.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if currentLine + 1 < lineRects.count {
                        currentLine += 1
                        lineProgress = 0
                        lastTick = Date()
                    } else {
                        isRunning = false
                        onFinished?()
                    }
                }
            }
        }
    }

    private func toggleSpeak() {
        if isSpeaking {
            audioPlayer?.pause()
            isSpeaking = false
        } else {
            Task {
                await speakCurrentText()
            }
        }
    }

    @MainActor
    private func speakCurrentText() async {
        do {
            let data = try await ElevenLabsTTS.shared.synthesizeAudioData(for: text)
            let player = try ElevenLabsTTS.shared.player(for: data)
            audioPlayer = player
            player.delegate = audioDelegate
            audioDelegate.onFinish = {
                isSpeaking = false
            }
            player.play()
            isSpeaking = true
        } catch {
            print("[TTS] Failed to speak: \(error)")
        }
    }

    final class AudioDelegate: NSObject, AVAudioPlayerDelegate {
        var onFinish: (() -> Void)?
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            onFinish?()
        }
    }
}

// MARK: - TextKit line measurer
private struct LineMeasurer: UIViewRepresentable {
    let text: String
    let width: CGFloat
    let font: UIFont
    let lineSpacing: CGFloat
    let onMeasured: ([CGRect]) -> Void

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.text = text
        label.font = font
        label.preferredMaxLayoutWidth = width
        label.lineBreakMode = .byWordWrapping
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.text = text
        uiView.font = font
        uiView.preferredMaxLayoutWidth = width
        uiView.setNeedsLayout()
        uiView.layoutIfNeeded()

        // Use TextKit to measure line fragments
        let storage = NSTextStorage(string: text)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.lineBreakMode = .byWordWrapping
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        storage.addAttribute(.font, value: font, range: NSRange(location: 0, length: storage.length))

        var rects: [CGRect] = []
        var glyphIndex = 0
        while glyphIndex < layout.numberOfGlyphs {
            var range = NSRange(location: 0, length: 0)
            let lineRect = layout.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: &range)
            if !lineRect.isEmpty {
                rects.append(lineRect)
            }
            glyphIndex = NSMaxRange(range)
        }
        onMeasured(rects)
    }
}

private extension UIFont {
    var swiftUIWeight: Font.Weight {
        if let traits = fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any],
           let raw = traits[.weight] as? NSNumber {
            let w = CGFloat(truncating: raw)
            switch w {
            case ..<(-0.6): return .ultraLight
            case ..<(-0.4): return .thin
            case ..<(-0.2): return .light
            case ..<(0.0): return .regular
            case ..<(0.23): return .medium
            case ..<(0.4): return .semibold
            case ..<(0.6): return .bold
            case ..<(0.8): return .heavy
            default: return .black
            }
        }
        return .regular
    }
}
