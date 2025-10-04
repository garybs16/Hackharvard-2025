// ReaderView.swift
import SwiftUI
import PDFKit
import AVFoundation
import Speech

struct ReaderView: View {
    let document: PDFDocument
    @StateObject private var voice = VoiceAssistant.shared
    @State private var selectedText: String = ""
    @State private var isListening = false

    var body: some View {
        VStack(spacing: 0) {
            PDFSelectableView(document: document, onParagraphPicked: { text in
                selectedText = text
                voice.read(text)
            })
            .ignoresSafeArea()

            // Compact control bar
            if !selectedText.isEmpty || voice.isSpeaking {
                ControlBar(
                    selectedText: selectedText,
                    isSpeaking: voice.isSpeaking,
                    onPlayPause: { voice.toggle() },
                    onStop: { voice.stop() },
                    onPrev: { voice.readPreviousParagraph() },
                    onNext: { voice.readNextParagraph() },
                    onMic: {
                        isListening.toggle()
                        isListening ? voice.startListening() : voice.stopListening()
                    },
                    isListening: isListening
                )
            }
        }
    }
}

// Simple controls
private struct ControlBar: View {
    let selectedText: String
    let isSpeaking: Bool
    let onPlayPause: () -> Void
    let onStop: () -> Void
    let onPrev: () -> Void
    let onNext: () -> Void
    let onMic: () -> Void
    let isListening: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(selectedText)
                .font(.callout)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 18) {
                Button(action: onPrev) { Image(systemName: "backward.end.alt") }
                Button(action: onPlayPause) { Image(systemName: isSpeaking ? "pause.fill" : "play.fill") }
                Button(action: onStop) { Image(systemName: "stop.fill") }
                Button(action: onNext) { Image(systemName: "forward.end.alt") }
                Spacer()
                Button(action: onMic) { Image(systemName: isListening ? "mic.fill" : "mic") }
            }
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }
}
