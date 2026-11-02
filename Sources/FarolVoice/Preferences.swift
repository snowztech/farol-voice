import AppKit
import AVFoundation
import ServiceManagement
import VoiceCore

enum TalkKey: String, CaseIterable, Identifiable {
    case fn, rightOption, rightCommand, rightControl, rightShift

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fn: "Fn"
        case .rightOption: "Right Option"
        case .rightCommand: "Right Command"
        case .rightControl: "Right Control"
        case .rightShift: "Right Shift"
        }
    }

    var keyCode: UInt16 {
        switch self {
        case .fn: 63
        case .rightOption: 61
        case .rightCommand: 54
        case .rightControl: 62
        case .rightShift: 60
        }
    }

    /// The bit for this exact key, from IOKit's device masks. The usual flags can't tell left from right, so releasing the right key while holding the left one would leave the mic open.
    private var deviceMask: UInt {
        switch self {
        case .fn: NSEvent.ModifierFlags.function.rawValue
        case .rightOption: 0x40
        case .rightCommand: 0x10
        case .rightControl: 0x2000
        case .rightShift: 0x4
        }
    }

    func isDown(in event: NSEvent) -> Bool {
        event.modifierFlags.rawValue & deviceMask != 0
    }
}

final class Preferences: ObservableObject {
    private enum Key {
        static let talkKey = "talkKey"
        static let commandKey = "commandKey"
        static let customWords = "customWords"
        static let setupDone = "setupDone"
        static let waveSize = "waveSize"
        static let language = "language"
        static let speaksAgents = "speaksAgents"
        static let listensForWake = "listensForWake"
    }

    /// The two keys can't be the same, so choosing one the other has swaps them.
    @Published var talkKey: TalkKey {
        didSet {
            UserDefaults.standard.set(talkKey.rawValue, forKey: Key.talkKey)
            if commandKey == talkKey { commandKey = oldValue }
        }
    }
    @Published var commandKey: TalkKey {
        didSet {
            UserDefaults.standard.set(commandKey.rawValue, forKey: Key.commandKey)
            if talkKey == commandKey { talkKey = oldValue }
        }
    }
    /// As typed in Settings: words separated by commas.
    @Published var customWords: String {
        didSet { UserDefaults.standard.set(customWords, forKey: Key.customWords) }
    }

    /// Off until you ask for it, since it means the app talks and opens the mic by itself.
    @Published var speaksAgents: Bool {
        didSet { UserDefaults.standard.set(speaksAgents, forKey: Key.speaksAgents) }
    }

    /// Dev builds only for now. It keeps the mic open, and its model isn't ready to release.
    @Published var listensForWake: Bool {
        didSet { UserDefaults.standard.set(listensForWake, forKey: Key.listensForWake) }
    }

    @Published var waveSize: WaveSize {
        didSet { UserDefaults.standard.set(waveSize.rawValue, forKey: Key.waveSize) }
    }

    /// A language code, or `SpeechLanguage.automatic`. Starts from the Mac's own language.
    @Published var languageChoice: String {
        didSet { UserDefaults.standard.set(languageChoice, forKey: Key.language) }
    }

    var language: String? { SpeechLanguage.language(from: languageChoice) }

    var setupDone: Bool {
        get { UserDefaults.standard.bool(forKey: Key.setupDone) }
        set { UserDefaults.standard.set(newValue, forKey: Key.setupDone) }
    }

    var words: [String] { DictationText.words(from: customWords) }

    init() {
        let defaults = UserDefaults.standard
        let talk = defaults.string(forKey: Key.talkKey).flatMap(TalkKey.init) ?? .fn
        talkKey = talk
        commandKey = defaults.string(forKey: Key.commandKey).flatMap(TalkKey.init).flatMap { $0 == talk ? nil : $0 }
            ?? (talk == .rightOption ? .fn : .rightOption)
        customWords = defaults.string(forKey: Key.customWords) ?? "Farol"
        languageChoice = defaults.string(forKey: Key.language) ?? SpeechLanguage.initial(preferred: Locale.preferredLanguages)
        waveSize = defaults.string(forKey: Key.waveSize).flatMap(WaveSize.init) ?? .compact
        speaksAgents = defaults.bool(forKey: Key.speaksAgents)
        listensForWake = defaults.bool(forKey: Key.listensForWake)
    }
}

enum Permissions {
    static var microphone: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .audio) }
    static var accessibility: Bool { AXIsProcessTrusted() }

    static func askForAccessibility() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
    }

    static func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
