import Foundation

/// What's worth saying out loud when Farol's sessions change.
public enum AgentNews: Equatable, Sendable {
    case question(FarolSession)
    case finished([String])

    /// Only what changed, and nothing about the pane you're already looking at.
    public static func changes(from old: [FarolSession], to new: [FarolSession]) -> [AgentNews] {
        let before = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var news: [AgentNews] = []
        var finished: [String] = []
        for session in new where session.inFront != true {
            guard let previous = before[session.id] else { continue }
            if session.isWaiting, !previous.isWaiting || previous.asking != session.asking {
                news.append(.question(session))
            } else if session.status == "done", previous.status == "working" {
                finished.append(session.name)
            }
        }
        if !finished.isEmpty { news.append(.finished(finished)) }
        return news
    }

    public var sentence: String {
        switch self {
        case .question(let session):
            guard let asking = session.asking else { return "\(session.name) needs you." }
            let words = Self.spoken(asking)
            let hint = session.yesOrNo ? " Yes or no?" : session.canAnswerAloud ? "" : " It's waiting on screen."
            return "\(session.name) asks: \(words)\(hint)"
        case .finished(let names):
            return names.count == 1 ? "\(names[0]) is done." : "\(names.count) agents are done."
        }
    }

    /// Long enough to know what's being asked. Nobody wants a whole script read to them.
    private static let longestSpoken = 140

    /// Farol writes a tool's request as "Bash · npm test" and marks code up for the screen, none of which reads well aloud.
    private static func spoken(_ asking: String) -> String {
        let line = asking
            .replacingOccurrences(of: " · ", with: ": ")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard line.count > longestSpoken else { return line }
        let cut = line.prefix(longestSpoken)
        return String(cut[..<(cut.lastIndex(of: " ") ?? cut.endIndex)]) + ", and more."
    }
}

extension FarolSession {
    /// Whether a plain yes and no are on its menu, so it can say so.
    /// Only a menu Farol could read gets answered by voice. Without one, words and a Return could land on a menu it missed, and pick whatever the cursor is on.
    public var canAnswerAloud: Bool { asking != nil && choices?.isEmpty == false }

    public var yesOrNo: Bool {
        guard let choices, !choices.isEmpty else { return false }
        return AgentAnswer.parse("yes", choices: choices) != .unclear && AgentAnswer.parse("no", choices: choices) != .unclear
    }
}

/// What's left to say, with questions first since an agent is stuck until someone answers.
public struct NewsQueue: Equatable, Sendable {
    public private(set) var items: [AgentNews] = []

    public init() {}

    public var isEmpty: Bool { items.isEmpty }

    public mutating func add(_ news: [AgentNews]) {
        for item in news {
            switch item {
            case .question(let session):
                // A newer question replaces the old one of that session.
                items.removeAll { if case .question(let queued) = $0 { queued.id == session.id } else { false } }
                let firstFinished = items.firstIndex { if case .finished = $0 { true } else { false } } ?? items.endIndex
                items.insert(item, at: firstFinished)
            case .finished(let names):
                // One sentence for everything that finished while it was busy.
                if let index = items.firstIndex(where: { if case .finished = $0 { true } else { false } }),
                   case .finished(let earlier) = items[index] {
                    items[index] = .finished(earlier + names)
                } else {
                    items.append(item)
                }
            }
        }
    }

    public mutating func next() -> AgentNews? {
        items.isEmpty ? nil : items.removeFirst()
    }

    /// A question answered on the Mac or the phone isn't news any more.
    public mutating func drop(outdatedBy sessions: [FarolSession]) {
        items.removeAll { item in
            guard case .question(let queued) = item else { return false }
            let now = sessions.first { $0.id == queued.id }
            return now?.isWaiting != true || now?.asking != queued.asking || now?.inFront == true
        }
    }
}
