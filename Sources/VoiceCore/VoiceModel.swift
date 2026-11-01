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

    public var title: String {
        switch self {
        case .parakeetV3: "Parakeet V3"
        case .whisperTurbo: "Whisper Large V3 Turbo"
        }
    }

    public var strengths: String {
        switch self {
        case .parakeetV3: "Fast. English and 24 more languages, most of them European."
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
        let first = languages.first?.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map { $0.lowercased() }
        guard let first else { return .parakeetV3 }
        return parakeetLanguages.contains(first) ? .parakeetV3 : .whisperTurbo
    }
}
