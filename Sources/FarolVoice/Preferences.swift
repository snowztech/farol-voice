import AppKit
import AVFoundation
import ServiceManagement
import VoiceCore

enum TalkKey: String, CaseIterable, Identifiable {
    case fn, rightOption

    var id: String { rawValue }
    var title: String { self == .fn ? "Fn" : "Right Option" }
    var keyCode: UInt16 { self == .fn ? 63 : 61 }
    var flag: NSEvent.ModifierFlags { self == .fn ? .function : .option }
}

final class Preferences: ObservableObject {
    private enum Key {
        static let talkKey = "talkKey"
        static let customWords = "customWords"
        static let setupDone = "setupDone"
    }

    @Published var talkKey: TalkKey {
        didSet { UserDefaults.standard.set(talkKey.rawValue, forKey: Key.talkKey) }
    }
    /// As typed in Settings: words separated by commas.
    @Published var customWords: String {
        didSet { UserDefaults.standard.set(customWords, forKey: Key.customWords) }
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
