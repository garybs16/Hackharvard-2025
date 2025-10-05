#if os(visionOS)
import SwiftUI
import AVFoundation

struct PageWordsWindow: View {
  let page: PageContent
  @State private var activeParagraphID: UUID? = nil
  @State private var showMore = false

  // TTS state
  @State private var isSpeaking: Bool = false
  @State private var audioPlayer: AVAudioPlayer? = nil
  @State private var audioDelegate = AudioDelegate()
  @State private var playbackRate: Double = 1.0
  
  // Auto-advance and selection guard
  @State private var autoAdvance: Bool = true
  @State private var suppressSelectionStop: Bool = false

  var body: some View {
    ZStack {
      let paragraphs = segmentParagraphs(from: page)
      ParagraphRouletteView(
        paragraphs: paragraphs,
        activeID: $activeParagraphID,
        onActiveChange: { _ in }
      )
      .frame(maxWidth: 820)                 // constrain content width
      .frame(maxWidth: .infinity)           // center within window
      .padding(.horizontal, 8)              // small side padding only
      .ornament(
        visibility: .visible,
        attachmentAnchor: .scene(.top),
        contentAlignment: .center
      ) {
        Label("Page \(page.pageIndex + 1) · \(paragraphs.count) paragraphs", systemImage: "doc.richtext")
          .padding(8)
          .glassBackgroundEffect()
      }
      .background(.thinMaterial)
    }
    .overlay(alignment: .trailing) {
      EdgeTaskBar(
        showsLabels: false,
        onPrev: {},
        onRestart: {
          // Replay the currently selected paragraph from the beginning
          stopSpeaking()
          let paragraphs = segmentParagraphs(from: page)
          let text: String = {
            if let currentID = activeParagraphID,
               let idx = paragraphs.firstIndex(where: { $0.id == currentID }) {
              return paragraphs[idx].text
            } else {
              return paragraphs.first?.text ?? ""
            }
          }()
          guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
          startSpeaking(text, items: paragraphs)
        },
        onRewind: {
          if let player = audioPlayer {
            let newTime = player.currentTime - 5.0
            if newTime > 0 {
              player.currentTime = newTime
              if !player.isPlaying { player.play() }
              isSpeaking = true
            } else {
              // Move to previous paragraph
              let paragraphs = segmentParagraphs(from: page)
              if let currentID = activeParagraphID,
                 let idx = paragraphs.firstIndex(where: { $0.id == currentID }), idx - 1 >= 0 {
                stopSpeaking()
                let prev = paragraphs[idx - 1]
                programmaticSelectionChange { activeParagraphID = prev.id }
                let text = prev.text
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                  startSpeaking(text, items: paragraphs)
                }
              } else {
                // At first paragraph: restart current
                if let currentID = activeParagraphID,
                   let idx = paragraphs.firstIndex(where: { $0.id == currentID }) {
                  stopSpeaking()
                  let text = paragraphs[idx].text
                  if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    startSpeaking(text, items: paragraphs)
                  }
                }
              }
            }
          } else {
            // No player: behave like restart
            let paragraphs = segmentParagraphs(from: page)
            if let currentID = activeParagraphID,
               let idx = paragraphs.firstIndex(where: { $0.id == currentID }) {
              let text = paragraphs[idx].text
              if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                startSpeaking(text, items: paragraphs)
              }
            }
          }
        },
        onPlayPause: {
          if isSpeaking {
            stopSpeaking()
          } else {
            let paragraphs = segmentParagraphs(from: page)
            let text: String = {
              if let currentID = activeParagraphID,
                 let idx = paragraphs.firstIndex(where: { $0.id == currentID }) {
                return paragraphs[idx].text
              } else {
                return paragraphs.first?.text ?? ""
              }
            }()
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            startSpeaking(text, items: paragraphs)
          }
        },
        onForward: {
          if let player = audioPlayer {
            let newTime = player.currentTime + 5.0
            if newTime < player.duration {
              player.currentTime = newTime
              if !player.isPlaying { player.play() }
              isSpeaking = true
            } else {
              // Move to next paragraph
              let paragraphs = segmentParagraphs(from: page)
              if let currentID = activeParagraphID,
                 let idx = paragraphs.firstIndex(where: { $0.id == currentID }), idx + 1 < paragraphs.count {
                stopSpeaking()
                let next = paragraphs[idx + 1]
                programmaticSelectionChange { activeParagraphID = next.id }
                let text = next.text
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                  startSpeaking(text, items: paragraphs)
                }
              } else {
                // Last paragraph: stop
                stopSpeaking()
              }
            }
          } else {
            // No player: jump to next paragraph and play
            let paragraphs = segmentParagraphs(from: page)
            if let currentID = activeParagraphID,
               let idx = paragraphs.firstIndex(where: { $0.id == currentID }), idx + 1 < paragraphs.count {
              let next = paragraphs[idx + 1]
              programmaticSelectionChange { activeParagraphID = next.id }
              let text = next.text
              if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                startSpeaking(text, items: paragraphs)
              }
            }
          }
        },
        onNext: {},
        onAutoAdvanceToggle: { autoAdvance.toggle() },
        onOpenMore: { showMore = true }
      )
      .padding(.trailing, 8)
    }
    .onChange(of: activeParagraphID) { _ in
      if suppressSelectionStop {
        suppressSelectionStop = false
      } else {
        stopSpeaking()
      }
    }
    .onChange(of: playbackRate) { newRate in
      audioPlayer?.enableRate = true
      audioPlayer?.rate = Float(newRate)
    }
    .popover(isPresented: $showMore) {
      VStack(alignment: .leading, spacing: 16) {
        Text("Reading Options").font(.headline)
        Toggle("Auto-Advance", isOn: $autoAdvance)
        HStack {
          Image(systemName: "tortoise.fill")
          Slider(value: $playbackRate, in: 0.75...1.5)
          Image(systemName: "hare.fill")
        }
      }
      .padding(20)
      .frame(minWidth: 360)
      .glassBackgroundEffect()
    }
  }

  private func stopSpeaking() {
    audioPlayer?.stop()
    audioPlayer = nil
    isSpeaking = false
  }

  private func startSpeaking(_ text: String, items: [ParagraphItem]) {
    Task { @MainActor in
      do {
        let data = try await ElevenLabsTTS.shared.synthesizeAudioData(for: text)
        let player = try ElevenLabsTTS.shared.player(for: data)
        audioPlayer = player
        player.delegate = audioDelegate
        player.enableRate = true
        player.rate = Float(playbackRate)
        audioDelegate.onFinish = {
          isSpeaking = false
          if autoAdvance { advanceToNextParagraph(items: items) }
        }
        isSpeaking = true
        player.play()
      } catch {
        isSpeaking = false
        print("[TTS] Failed to speak: \(error)")
      }
    }
  }

  private func advanceToNextParagraph(items: [ParagraphItem]) {
    guard !items.isEmpty else { return }
    if let currentID = activeParagraphID,
       let idx = items.firstIndex(where: { $0.id == currentID }) {
      let nextIndex = idx + 1
      if nextIndex < items.count {
        programmaticSelectionChange { activeParagraphID = items[nextIndex].id }
        let nextText = items[nextIndex].text
        if !nextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          startSpeaking(nextText, items: items)
        }
      }
    } else if let first = items.first {
      programmaticSelectionChange { activeParagraphID = first.id }
      let firstText = first.text
      if !firstText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        startSpeaking(firstText, items: items)
      }
    }
  }

  private func programmaticSelectionChange(_ updates: () -> Void) {
    suppressSelectionStop = true
    updates()
  }

  final class AudioDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
      onFinish?()
    }
  }
}

#Preview {
  let sampleText = """
  Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum et ligula in nunc bibendum fringilla a eu lectus. Sed sit amet sem varius, faucibus erat nec, dapibus purus. Curabitur finibus, metus in facilisis lacinia, nunc ex convallis sapien, quis vehicula erat nulla in justo.
  
  Nullam porttitor magna nec elit varius, vitae laoreet massa sagittis. Quisque eget tellus a arcu fermentum efficitur. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.
  
  Phasellus ac lacus at velit fringilla lobortis. Morbi sed velit justo. Praesent ut lacus a lorem efficitur mattis.
  """
  let page = PageContent(pageIndex: 0, rawText: sampleText, words: [])
  PageWordsWindow(page: page)
}
#endif



