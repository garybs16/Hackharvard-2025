import SwiftUI
import AVFoundation
import Combine

// MARK: - ElevenLabs TTS Client
final class ElevenLabsTTS {
    static let shared = ElevenLabsTTS()

    struct Configuration {
        var apiKey: String?
        var voiceID: String?
        var modelID: String = "eleven_multilingual_v2"
    }

    private var config = Configuration()
    private init() {}

    /// Configure the ElevenLabs client. Call this once at app launch.
    func configure(apiKey: String, voiceID: String, modelID: String = "eleven_multilingual_v2") {
        config.apiKey = apiKey
        config.voiceID = voiceID
        config.modelID = modelID
    }

    enum TTSError: Error, LocalizedError {
        case notConfigured
        case invalidResponse(status: Int, message: String)
        case badURL

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "ElevenLabsTTS is not configured. Call configure(apiKey:voiceID:) first."
            case .invalidResponse(let status, let message):
                return "ElevenLabs API error (\(status)): \(message)"
            case .badURL:
                return "Invalid ElevenLabs URL"
            }
        }
    }

    /// Synthesizes speech audio for the given text using ElevenLabs.
    /// Returns MPEG audio data on success.
    func synthesizeAudioData(for text: String) async throws -> Data {
        guard let apiKey = config.apiKey, let voiceID = config.voiceID, !apiKey.isEmpty, !voiceID.isEmpty else {
            throw TTSError.notConfigured
        }
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)") else {
            throw TTSError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let body: [String: Any] = [
            "text": text,
            "model_id": config.modelID
            // Optionally add voice settings:
            // "voice_settings": ["stability": 0.5, "similarity_boost": 0.5]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TTSError.invalidResponse(status: http.statusCode, message: message)
        }
        return data
    }

    /// Creates an AVAudioPlayer for the provided audio data.
    func player(for data: Data) throws -> AVAudioPlayer {
        let player = try AVAudioPlayer(data: data)
        player.prepareToPlay()
        return player
    }

    /// Convenience: synthesize then play immediately, returning the prepared player.
    @MainActor
    func speak(text: String) async throws -> AVAudioPlayer {
        let data = try await synthesizeAudioData(for: text)
        let p = try player(for: data)
        p.play()
        return p
    }
}

// MARK: - Text-to-Speech Manager
class TextToSpeechManager: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isSpeaking = false
    @Published var isPaused = false
    @Published var currentWordRange: NSRange?
    @Published var progress: Double = 0.0
    @Published var selectedVoice: AVSpeechSynthesisVoice?
    @Published var speechRate: Float = 0.5
    
    private var currentText: String = ""
    private var currentUtterance: AVSpeechUtterance?
    
    override init() {
        super.init()
        synthesizer.delegate = self
        // Set default voice to a clear English voice
        selectedVoice = AVSpeechSynthesisVoice(language: "en-US")
    }
    
    func speak(text: String) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            stop()
        }
        
        currentText = text
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2
        
        currentUtterance = utterance
        synthesizer.speak(utterance)
        isSpeaking = true
        isPaused = false
    }
    
    func speakBySentence(text: String) {
        if synthesizer.isSpeaking {
            stop()
        }
        
        currentText = text
        
        // Split by sentence endings
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let utterance = AVSpeechUtterance(string: trimmed)
                utterance.voice = selectedVoice
                utterance.rate = speechRate
                utterance.postUtteranceDelay = 0.5 // Pause between sentences
                synthesizer.speak(utterance)
            }
        }
        
        isSpeaking = true
        isPaused = false
    }
    
    func pause() {
        if synthesizer.isSpeaking && !isPaused {
            synthesizer.pauseSpeaking(at: .word)
            isPaused = true
        }
    }
    
    func resume() {
        if isPaused {
            synthesizer.continueSpeaking()
            isPaused = false
        }
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
        currentWordRange = nil
        progress = 0.0
    }
    
    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices.filter { $0.language.starts(with: "en") }
    }
}

// MARK: - Speech Synthesizer Delegate
extension TextToSpeechManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                          willSpeakRangeOfSpeechString characterRange: NSRange,
                          utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.currentWordRange = characterRange
            
            // Calculate progress
            if !self.currentText.isEmpty {
                let progress = Double(characterRange.location) / Double(self.currentText.count)
                self.progress = min(progress, 1.0)
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPaused = false
            self.currentWordRange = nil
            self.progress = 1.0
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPaused = false
            self.currentWordRange = nil
        }
    }
}

// MARK: - Highlighted Text View
struct HighlightedTextView: View {
    let text: String
    let highlightRange: NSRange?
    
    var body: some View {
        let attributed: AttributedString = {
            var attr = AttributedString(text)
            if let range = highlightRange,
               range.location != NSNotFound,
               let stringRange = Range(range, in: text) {

                // Compute character offsets in the original String
                let lowerOffset = text.distance(from: text.startIndex, to: stringRange.lowerBound)
                let upperOffset = text.distance(from: text.startIndex, to: stringRange.upperBound)

                // Safely map those offsets to AttributedString indices
                let totalCount = attr.characters.count
                if lowerOffset < totalCount && upperOffset <= totalCount && lowerOffset < upperOffset {
                    let start = attr.characters.index(attr.startIndex, offsetBy: lowerOffset)
                    let end = attr.characters.index(attr.startIndex, offsetBy: upperOffset)
                    let attrRange = start..<end

                    // Apply styles to the highlighted portion
                    attr[attrRange].foregroundColor = .blue
                    attr[attrRange].backgroundColor = Color.yellow.opacity(0.3)
                    attr[attrRange].inlinePresentationIntent = .stronglyEmphasized
                }
            }
            return attr
        }()
        
        Text(attributed)
    }
}

// MARK: - Reading Controls View
struct ReadingControlsView: View {
    @ObservedObject var ttsManager: TextToSpeechManager
    let onSentenceMode: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Playback Controls
            HStack(spacing: 30) {
                Button(action: {
                    if ttsManager.isSpeaking {
                        if ttsManager.isPaused {
                            ttsManager.resume()
                        } else {
                            ttsManager.pause()
                        }
                    }
                }) {
                    Label(
                        ttsManager.isPaused ? "Resume" : "Pause",
                        systemImage: ttsManager.isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .disabled(!ttsManager.isSpeaking)
                
                Button(action: {
                    ttsManager.stop()
                }) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!ttsManager.isSpeaking)
                
                Button(action: onSentenceMode) {
                    Label("Sentence Mode", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
            }
            .buttonStyle(.bordered)
            
            // Progress Bar
            if ttsManager.isSpeaking || ttsManager.progress > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: ttsManager.progress)
                        .frame(height: 8)
                }
            }
            
            // Speed Control
            VStack(alignment: .leading, spacing: 8) {
                Text("Reading Speed: \(String(format: "%.1f", ttsManager.speechRate))x")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Slow")
                        .font(.caption2)
                    Slider(value: $ttsManager.speechRate, in: 0.3...0.8, step: 0.1)
                    Text("Fast")
                        .font(.caption2)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(20)
    }
}

// MARK: - Voice Selector View
struct VoiceSelectorView: View {
    @ObservedObject var ttsManager: TextToSpeechManager
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Selection")
                .font(.headline)
            
            Picker("Voice", selection: Binding(
                get: { ttsManager.selectedVoice },
                set: { ttsManager.selectedVoice = $0 }
            )) {
                ForEach(availableVoices, id: \.identifier) { voice in
                    Text("\(voice.name) (\(voice.language))")
                        .tag(voice as AVSpeechSynthesisVoice?)
                }
            }
            .pickerStyle(.menu)
        }
        .onAppear {
            availableVoices = ttsManager.getAvailableVoices()
        }
    }
}

// MARK: - Main App View
struct ContentView: View {
    @StateObject private var ttsManager = TextToSpeechManager()
    @State private var paperText = """
    Welcome to the accessible reading app. This app is designed to help people with dyslexia and ADHD read papers more easily.
    
    The text-to-speech feature will read the text aloud at a comfortable pace. You can adjust the reading speed using the slider below.
    
    The highlighted word feature helps you follow along with the audio. The current word being spoken will be highlighted in blue with a yellow background.
    
    Sentence mode reads one sentence at a time with pauses between sentences, which can help with comprehension and reduce overwhelm.
    
    You can pause, resume, or stop the reading at any time using the controls below.
    """
    
    @State private var showVoiceSelector = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Text Display with Highlighting
                ScrollView {
                    HighlightedTextView(
                        text: paperText,
                        highlightRange: ttsManager.currentWordRange
                    )
                    .font(.title3)
                    .lineSpacing(8)
                    .padding()
                }
                .frame(maxHeight: 400)
                .background(Color(white: 0.95))
                .cornerRadius(12)
                
                // Start Reading Button
                if !ttsManager.isSpeaking {
                    Button(action: {
                        ttsManager.speak(text: paperText)
                    }) {
                        Label("Start Reading", systemImage: "play.circle.fill")
                            .font(.title2)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // Reading Controls
                ReadingControlsView(
                    ttsManager: ttsManager,
                    onSentenceMode: {
                        ttsManager.speakBySentence(text: paperText)
                    }
                )
                
                // Voice Selector Toggle
                Button(action: {
                    showVoiceSelector.toggle()
                }) {
                    Label("Voice Settings", systemImage: "speaker.wave.2")
                }
                .buttonStyle(.bordered)
                
                if showVoiceSelector {
                    VoiceSelectorView(ttsManager: ttsManager)
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Accessible Reader")
        }
    }
}
