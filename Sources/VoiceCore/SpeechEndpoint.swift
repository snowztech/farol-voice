import Foundation

/// Decides when you've finished talking, from how loud the mic is, so an answer needs no key.
/// ponytail: a loudness threshold against the room's own noise, fine for a short answer. Smart Turn or Silero when longer sentences get cut off.
public struct SpeechEndpoint: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case listening
        case speaking
        /// Stopped talking.
        case finished
        /// Nobody said anything.
        case nothing
    }

    private static let settling: TimeInterval = 0.25
    private static let margin = 0.18
    private static let lowestSpeech = 0.3
    private static let quietToFinish: TimeInterval = 1.0

    public private(set) var state = State.listening
    private let patience: TimeInterval
    private let started: TimeInterval
    private var room = 0.0
    private var lastVoice: TimeInterval?

    public init(startingAt time: TimeInterval, patience: TimeInterval = 8) {
        started = time
        self.patience = patience
    }

    @discardableResult
    public mutating func hear(level: Double, at time: TimeInterval) -> State {
        guard state == .listening || state == .speaking else { return state }
        if time - started < Self.settling {
            room = max(room, level)
            return state
        }
        if level >= max(Self.lowestSpeech, room + Self.margin) {
            lastVoice = time
            state = .speaking
        } else if let lastVoice {
            if time - lastVoice >= Self.quietToFinish { state = .finished }
        } else if time - started >= patience {
            state = .nothing
        }
        return state
    }
}
