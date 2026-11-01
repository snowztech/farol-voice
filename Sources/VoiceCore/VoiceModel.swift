/// A speech model you can install and run on this Mac.
public enum VoiceModel: String, CaseIterable, Identifiable, Sendable {
    case parakeetV3 = "parakeet-v3"
    case whisperTurbo = "whisper-turbo"

    /// The languages Parakeet V3 understands. It is the fastest, so it's the choice when it fits.
    private static let parakeetLanguages: Set<String> = [
        "bg", "cs", "da", "de", "el", "en", "es", "et", "fi", "fr", "hr", "hu", "it",
        "lt", "lv", "mt", "nl", "pl", "pt", "ro", "ru", "sk", "sl", "sv", "uk",
    ]

    public var id: String { rawValue }

    /// What it's good for, which is what people choose by. The real name stays beside it for anyone who knows it.
    public var friendlyName: String {
        switch self {
        case .parakeetV3: "Fast"
        case .whisperTurbo: "Most languages"
        }
    }

    public var title: String {
        switch self {
        case .parakeetV3: "Parakeet V3"
        case .whisperTurbo: "Whisper Large V3 Turbo"
        }
    }

    public var strengths: String {
        switch self {
        case .parakeetV3: "English and 24 more languages, most of them European."
        case .whisperTurbo: "Slower, with about 100 languages."
        }
    }

    public var downloadSize: String {
        switch self {
        case .parakeetV3: "About 600 MB."
        case .whisperTurbo: "A larger download."
        }
    }

    public static func recommended(languages: [String]) -> VoiceModel {
        best(for: languages.first.map(SpeechLanguage.code(of:)))
    }

    /// Fast when it understands the language, and Whisper for the rest. No language means detecting it, which starts from fast.
    public static func best(for language: String?) -> VoiceModel {
        guard let language else { return .parakeetV3 }
        return parakeetLanguages.contains(language) ? .parakeetV3 : .whisperTurbo
    }

    /// The language to hold this model to, or nil to let it detect. Only Whisper really can: holding Parakeet to one changed nothing on real recordings.
    public func lockedLanguage(_ language: String?) -> String? {
        self == .whisperTurbo ? language : nil
    }

}

/// What you choose instead of a model.
public enum SpeechLanguage {
    /// Saved when you'd rather have the language detected, or speak several.
    public static let automatic = "auto"

    /// Everything Whisper understands, which includes all of Parakeet's. A long list has your language in it, and a short one might not.
    public static let codes = [
        "af", "am", "ar", "as", "az", "ba", "be", "bg", "bn", "bo", "br", "bs", "ca", "cs", "cy", "da", "de", "el", "en", "es",
        "et", "eu", "fa", "fi", "fo", "fr", "gl", "gu", "ha", "haw", "he", "hi", "hr", "ht", "hu", "hy", "id", "is", "it", "ja",
        "jw", "ka", "kk", "km", "kn", "ko", "la", "lb", "ln", "lo", "lt", "lv", "mg", "mi", "mk", "ml", "mn", "mr", "ms", "mt",
        "my", "ne", "nl", "nn", "no", "oc", "pa", "pl", "ps", "pt", "ro", "ru", "sa", "sd", "si", "sk", "sl", "sn", "so", "sq",
        "sr", "su", "sv", "sw", "ta", "te", "tg", "th", "tk", "tl", "tr", "tt", "uk", "ur", "uz", "vi", "yi", "yo", "yue", "zh",
    ]

    /// Your Mac's languages, for the top of the list, so nobody has to scroll a hundred names to find theirs.
    public static func yours(preferred: [String]) -> [String] {
        var found: [String] = []
        for code in preferred.map(code(of:)) where codes.contains(code) && !found.contains(code) { found.append(code) }
        return found
    }

    /// "pt-PT" and "fr_FR" come down to "pt" and "fr".
    public static func code(of identifier: String) -> String {
        identifier.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map { $0.lowercased() } ?? identifier.lowercased()
    }

    /// What to start from: the Mac's own language when it's one of these, or else detecting it.
    public static func initial(preferred: [String]) -> String {
        guard let first = preferred.first.map(code(of:)), codes.contains(first) else { return automatic }
        return first
    }

    /// A saved choice as a language, with detecting as nil.
    public static func language(from choice: String) -> String? {
        choice == automatic ? nil : choice
    }
}
