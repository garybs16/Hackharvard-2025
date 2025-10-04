// VoiceAssistant.swift
import Foundation
import AVFoundation
import Speech

final class VoiceAssistant: NSObject, ObservableObject {
    static let shared = VoiceAssistant()
    
    @Published var isSpeaking = false
    
    private let synth = AVSpeechSynthesizer()
    private var queue: [String] = []        // paragraphs queue
    private var currentIndex: Int = -1
    private let audioSession = AVAudioSession.sharedInstance()
    
    // Speech recognition (optional)
    private let recognizer = SFSpeechRecognizer()
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    
    private override init() {
        super.init()
        synth.delegate = self
        try? audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }
    
    // MARK: Playback
    func read(_ text: String) {
        // Reset and read just this paragraph
        queue = [text]
        currentIndex = 0
        speak(text)
    }
    
    func readNextParagraph() {
        guard currentIndex + 1 < queue.count else { return }
        currentIndex += 1
        speak(queue[currentIndex])
    }
    
    func readPreviousParagraph() {
        guard currentIndex - 1 >= 0 else { return }
        currentIndex -= 1
        speak(queue[currentIndex])
    }
    
    private func speak(_ text: String) {
        stop()
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier) // e.g. "en-US"
        utt.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synth.speak(utt)
        isSpeaking = true
    }
    
    func toggle() {
        if synth.isSpeaking { synth.pauseSpeaking(at: .immediate); isSpeaking = false }
        else if synth.isPaused { synth.continueSpeaking(); isSpeaking = true }
    }
    
    func stop() {
        if synth.isSpeaking || synth.isPaused { synth.stopSpeaking(at: .immediate) }
        isSpeaking = false
    }
    
    // MARK: Speech Commands
    func startListening() {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            DispatchQueue.main.async { self.beginRecognition() }
        }
    }
    func stopListening() {
        audioEngine?.stop(); request?.endAudio(); task?.cancel()
        audioEngine = nil; request = nil; task = nil
    }
    
    private func beginRecognition() {
        audioEngine = AVAudioEngine()
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let engine = audioEngine, let req = request, let node = engine.inputNode else { return }
        req.shouldReportPartialResults = true
        
        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let t = result?.bestTranscription.formattedString.lowercased() {
                self.handleCommand(t)
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
            }
        }
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.request?.append(buf)
        }
        engine.prepare(); try? engine.start()
    }
    
    private func handleCommand(_ text: String) {
        switch true {
        case text.contains("pause"): toggle()
        case text.contains("resume") || text.contains("continue"): toggle()
        case text.contains("stop"): stop()
        case text.contains("next"): readNextParagraph()
        case text.contains("previous") || text.contains("back"): readPreviousParagraph()
        default: break
        }
    }
}

extension VoiceAssistant: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utt: AVSpeechUtterance) { isSpeaking = false }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utt: AVSpeechUtterance) { isSpeaking = false }
}
