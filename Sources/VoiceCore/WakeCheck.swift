import Foundation

/// A second opinion on the wake word, from the speech model. It doesn't know "Farol" and hears "Okay, Pharaoh" or "Okay for all", so this asks for the shape of it rather than the word.
public enum WakeCheck {
    private static let okay: Set<String> = ["ok", "okay", "okie", "oke", "okey", "o", "k"]
    /// Other things people say after "okay" that a near miss turns into.
    private static let notFarol: Set<String> = ["fine", "google", "great", "good", "cool", "thanks", "so", "then", "now", "well", "yes", "yeah", "carol"]
    private static let farolStarts: Set<Character> = ["f", "p", "v", "h"]

    public static func confirms(_ transcript: String) -> Bool {
        let words = transcript.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard let first = words.first, okay.contains(first) else { return false }
        let rest = words.drop { okay.contains($0) }
        guard let next = rest.first, !notFarol.contains(next), let start = next.first else { return false }
        return farolStarts.contains(start)
    }
}
