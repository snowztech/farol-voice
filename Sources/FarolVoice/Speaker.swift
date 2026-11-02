import AVFoundation
import NaturalLanguage

/// Says one thing at a time in the best voice installed for the language of the words. Runs on this Mac.
@MainActor
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var finished: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func say(_ text: String, then finished: @escaping () -> Void) {
        self.finished = finished
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice(for: text)
        synthesizer.speak(utterance)
    }

    /// Stops mid-word, without calling back, since whoever stops it is taking over.
    func stop() {
        finished = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    private static func voice(for text: String) -> AVSpeechSynthesisVoice? {
        let language = NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue ?? "en"
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(language) }
            .max { $0.quality.rawValue < $1.quality.rawValue }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            let done = self?.finished
            self?.finished = nil
            done?()
        }
    }
}
