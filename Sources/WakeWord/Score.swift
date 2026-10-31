/// One spoken wake word can fire more than once, especially across spellings. It should count as one wake.
public struct WakeGate {
    public let cooldown: Double
    private var last: Double?

    public init(cooldown: Double = 2) {
        self.cooldown = cooldown
    }

    public mutating func accept(at seconds: Double) -> Bool {
        if let last, seconds - last < cooldown { return false }
        last = seconds
        return true
    }
}

/// The bar from the roadmap: catch at least 95% of real attempts, with at most one false wake a workday.
public struct Score: Equatable {
    public static let requiredRecall = 0.95
    public static let allowedFalseWakesPerWorkday = 1.0
    public static let workdaySeconds = 8.0 * 3600
    public static let minimumAttempts = 40

    public var attempts = 0
    public var caught = 0
    public var falseWakes = 0
    public var negativeSeconds = 0.0

    public init() {}

    public var recall: Double {
        attempts == 0 ? 0 : Double(caught) / Double(attempts)
    }

    public var falseWakesPerWorkday: Double {
        negativeSeconds == 0 ? 0 : Double(falseWakes) / negativeSeconds * Self.workdaySeconds
    }

    /// A clean hour says little about a whole day, so too little audio can't pass.
    public var hasEnoughAudio: Bool {
        attempts >= Self.minimumAttempts && negativeSeconds >= Self.workdaySeconds
    }

    public var passes: Bool {
        hasEnoughAudio && recall >= Self.requiredRecall && falseWakesPerWorkday <= Self.allowedFalseWakesPerWorkday
    }
}
