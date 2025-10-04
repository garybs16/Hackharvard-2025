// VoiceAssistant.swift
import Foundation
import AVFoundation
import Speech

final class VoiceAssistant: NSObject, ObservableObject {
    static let shared = VoiceAssistant()

    @Published var isSpeaking = false

    private let synth = AVSpeechSynthesizer()
    private var queue: [String] = []
    private var currentIndex: Int = -1

    private let recognizer = SFSpeechRecognizer()
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private override init() {
        super.init()
        synth.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }

    // MARK: - TTS
    func read(_ text: String) {
        stop()
        queue = [text]
        currentIndex = 0
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        u.rate  = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synth.speak(u)
        isSpeaking = true
    }

    func readNextParagraph() {
        guard currentIndex + 1 < queue.count else { return }
        currentIndex += 1
        read(queue[currentIndex])
    }

    func readPreviousParagraph() {
        guard currentIndex - 1 >= 0 else { return }
        currentIndex -= 1
        read(queue[currentIndex])
    }

    func toggle() {
        if synth.isSpeaking {
            synth.pauseSpeaking(at: .immediate)
            isSpeaking = false
        } else if synth.isPaused {
            synth.continueSpeaking()
            isSpeaking = true
        }
    }

    func stop() {
        if synth.isSpeaking || synth.isPaused {
            synth.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    // MARK: - Voice commands
    func startListening() {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            DispatchQueue.main.async { self.beginRecognition() }
        }
    }

    func stopListening() {
        audioEngine?.stop()
        request?.endAudio()
        task?.cancel()
        audioEngine = nil
        request = nil
        task = nil
    }

    private func beginRecognition() {
        let engine = AVAudioEngine()
        audioEngine = engine
        let req = SFSpeechAudioBufferRecognitionRequest()
        request = req
        req.shouldReportPartialResults = true

        guard let input = engine.inputNode else { return }
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.request?.append(buf)
        }

        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let t = result?.bestTranscription.formattedString.lowercased() {
                self.handleCommand(t)
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
            }
        }

        engine.prepare()
        try? engine.start()
    }

    private func handleCommand(_ t: String) {
        switch true {
        case t.contains("pause"): toggle()
        case t.contains("resume"), t.contains("continue"): toggle()
        case t.contains("stop"): stop()
        case t.contains("next"): readNextParagraph()
        case t.contains("previous"), t.contains("back"): readPreviousParagraph()
        default: break
        }
    }
}

extension VoiceAssistant: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { isSpeaking = false }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { isSpeaking = false }
}
