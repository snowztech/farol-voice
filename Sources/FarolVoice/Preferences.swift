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
        static let customWords = "customWords"
        static let setupDone = "setupDone"
        static let waveSize = "waveSize"
    }

    @Published var talkKey: TalkKey {
        didSet { UserDefaults.standard.set(talkKey.rawValue, forKey: Key.talkKey) }
    }
    /// As typed in Settings: words separated by commas.
    @Published var customWords: String {
        didSet { UserDefaults.standard.set(customWords, forKey: Key.customWords) }
    }

    @Published var waveSize: WaveSize {
        didSet { UserDefaults.standard.set(waveSize.rawValue, forKey: Key.waveSize) }
    }

    var setupDone: Bool {
        get { UserDefaults.standard.bool(forKey: Key.setupDone) }
        set { UserDefaults.standard.set(newValue, forKey: Key.setupDone) }
    }

    var words: [String] { DictationText.words(from: customWords) }

    init() {
        let defaults = UserDefaults.standard
        talkKey = defaults.string(forKey: Key.talkKey).flatMap(TalkKey.init) ?? .fn
        customWords = defaults.string(forKey: Key.customWords) ?? "Farol"
        waveSize = defaults.string(forKey: Key.waveSize).flatMap(WaveSize.init) ?? .compact
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
