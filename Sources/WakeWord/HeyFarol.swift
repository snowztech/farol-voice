import SpeechWakeWord

public enum HeyFarol {
    public static let phrase = "hey farol"

    // "Farol" isn't a word this model knows, so it's spelled from pieces in its vocabulary.
    // These fired most often out of 270 spellings tried on synthetic speech. This is a baseline, not the final model.
    static let spellings = [
        ["▁HE", "Y", "▁F", "AR", "RE", "LL"],
        ["▁HE", "Y", "▁F", "AR", "RE", "L"],
        ["▁HE", "Y", "▁F", "ER", "AL"],
    ]

    public static func keywords(threshold: Double, boost: Double) -> [KeywordSpec] {
        spellings.map { KeywordSpec(phrase: phrase, acThreshold: threshold, boost: boost, tokens: $0) }
    }
}
