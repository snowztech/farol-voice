import Foundation

/// What a spoken reply means for the question an agent asked. It would rather ask again than pick the wrong thing, since one of the answers may run a command.
public enum AgentAnswer: Equatable, Sendable {
    /// The agent's own number for the option.
    case choice(Int)
    case unclear

    private static let yes: Set<String> = ["yes", "yeah", "yep", "yup", "sure", "ok", "okay", "allow", "approve", "approved", "proceed", "oui", "sim", "si", "ja"]
    private static let no: Set<String> = ["no", "nope", "dont", "stop", "deny", "denied", "cancel", "reject", "non", "nao", "nein"]
    /// Words around a yes or no that don't change it. Anything else, and it isn't a plain yes or no.
    private static let filler: Set<String> = ["go", "ahead", "do", "it", "that", "please", "thanks", "thank", "you", "run", "not", "dont"]
    /// Never picked by a plain yes, because saying yes once shouldn't allow something for good.
    private static let lasting = ["don't ask", "dont ask", "always", "for this session", "allow all", "from now on"]
    private static let numbers = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9]

    public static func parse(_ spoken: String, choices: [String]) -> AgentAnswer {
        let words = normalized(spoken)
        guard !words.isEmpty else { return .unclear }
        // Saying an option's own words is the clearest answer of all, including a lasting one.
        if let index = choices.firstIndex(where: { normalized($0) == words }) { return .choice(index + 1) }
        if let number = number(in: words), choices.indices.contains(number - 1) { return .choice(number) }

        let heard = Set(words)
        let saidYes = !heard.isDisjoint(with: yes) || words == ["go", "ahead"] || words == ["do", "it"]
        let saidNo = !heard.isDisjoint(with: no)
        // "No, go ahead" could mean either, and a wrong guess here may run something.
        guard saidYes != saidNo, !(saidNo && heard.contains("ahead")), heard.isSubset(of: yes.union(no).union(filler)) else { return .unclear }
        let start = saidYes ? "yes" : "no"
        let match = choices.firstIndex { choice in
            let lower = choice.lowercased()
            return normalized(choice).first == start && !lasting.contains { lower.contains($0) }
        }
        return match.map { .choice($0 + 1) } ?? .unclear
    }

    private static func number(in words: [String]) -> Int? {
        let rest = words.first == "option" || words.first == "number" ? Array(words.dropFirst()) : words
        guard rest.count == 1 else { return nil }
        return Int(rest[0]) ?? numbers[rest[0]]
    }

    private static func normalized(_ text: String) -> [String] {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }
}
