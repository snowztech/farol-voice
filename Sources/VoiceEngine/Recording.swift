import Foundation

/// One press of the key. Audio arrives on the audio thread and is read from the main one.
public final class Recording {
    private static let levelInterval: TimeInterval = 0.05

    private let lock = NSLock()
    private var samples: [Float] = []
    private var lastLevel = Date.distantPast
    private let mic = Microphone()
    private let onLevel: (Double) -> Void

    public init(onLevel: @escaping (Double) -> Void) {
        self.onLevel = onLevel
    }

    public func start() throws {
        try mic.start { [weak self] in self?.append($0) }
    }

    /// Closes the mic and returns what it heard.
    public func finish() -> [Float] {
        mic.stop()
        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    private func append(_ more: [Float]) {
        lock.lock()
        samples += more
        lock.unlock()
        let now = Date()
        guard now.timeIntervalSince(lastLevel) >= Self.levelInterval, !more.isEmpty else { return }
        lastLevel = now
        onLevel(Self.loudness(more))
    }

    /// 0 to 1, from -50 dB (a quiet room) to -10 dB (close, clear speech).
    public static func loudness(_ samples: [Float]) -> Double {
        let power = samples.reduce(Float(0)) { $0 + $1 * $1 } / Float(samples.count)
        let decibels = 10 * log10(Double(max(power, 1e-10)))
        return min(max((decibels + 50) / 40, 0), 1)
    }
}
