import Foundation

public enum DictationText {
    /// What gets typed: one line of plain text with your own words fixed, since a newline would press Return in a terminal and a control character could drive it.
    public static func clean(_ transcript: String, customWords: [String] = []) -> String {
        let scalars = transcript.unicodeScalars.map { scalar -> Unicode.Scalar in
            CharacterSet.controlCharacters.contains(scalar) ? " " : scalar
        }
        let line = String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return "" }
        return fix(line, customWords: customWords) + " "
    }

    /// Parses the comma-separated list from Settings.
    public static func words(from list: String) -> [String] {
        list.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static func fix(_ line: String, customWords: [String]) -> String {
        guard !customWords.isEmpty else { return line }
        var tokens = line.split(separator: " ").map(String.init)
        var index = 0
        while index < tokens.count {
            // Two words first, since speech models often split a name they don't know: "fa roll".
            if index + 1 < tokens.count,
               let word = customWords.first(where: { $0.count >= 5 && isClose(core(tokens[index]) + core(tokens[index + 1]), to: $0) }) {
                tokens[index] = leading(tokens[index]) + word + trailing(tokens[index + 1])
                tokens.remove(at: index + 1)
            } else if let word = customWords.first(where: { isClose(core(tokens[index]), to: $0) }) {
                tokens[index] = leading(tokens[index]) + word + trailing(tokens[index])
            }
            index += 1
        }
        return tokens.joined(separator: " ")
    }

    /// One letter off, only in longer words, and never the first letter, so "Carol" doesn't turn into "Farol".
    private static func isClose(_ spoken: String, to word: String) -> Bool {
        let spoken = spoken.lowercased(), word = word.lowercased()
        if spoken == word { return true }
        return word.count >= 5 && spoken.first == word.first && editDistance(spoken, word) <= 1
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }

    private static func core(_ token: String) -> String {
        String(token.drop { !isWordCharacter($0) }.reversed().drop { !isWordCharacter($0) }.reversed())
    }

    private static func leading(_ token: String) -> String {
        String(token.prefix { !isWordCharacter($0) })
    }

    private static func trailing(_ token: String) -> String {
        String(String(token.reversed().prefix { !isWordCharacter($0) }).reversed())
    }

    private static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var row = Array(0...b.count)
        for i in 0..<a.count {
            var previous = row[0]
            row[0] = i + 1
            for j in 0..<b.count {
                let replaced = previous + (a[i] == b[j] ? 0 : 1)
                previous = row[j + 1]
                row[j + 1] = min(replaced, row[j] + 1, row[j + 1] + 1)
            }
        }
        return row[b.count]
    }
}
