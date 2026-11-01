/// What's said to Farol over its socket. These mirror `ControlRequest` and `ControlReply` in Farol's FarolCore, so the names of cases and fields have to match.
public enum FarolAction: Encodable, Equatable, Sendable {
    case sessions
    case focus(session: String)
    case type(session: String, text: String, submit: Bool, asking: String?)
    case task(text: String, repo: String?, agent: String?)
}

public struct FarolRequest: Encodable, Equatable, Sendable {
    public let action: FarolAction

    public init(action: FarolAction) {
        self.action = action
    }
}

public struct FarolSession: Decodable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let folder: String
    public let branch: String?
    public let agent: String?
    public let status: String
    public let asking: String?

    public init(id: String, name: String, folder: String, branch: String? = nil, agent: String? = nil, status: String = "idle", asking: String? = nil) {
        self.id = id
        self.name = name
        self.folder = folder
        self.branch = branch
        self.agent = agent
        self.status = status
        self.asking = asking
    }

    public var isWaiting: Bool { status == "waiting" }

    /// Other things it's known by, for when names repeat in the sidebar.
    public var target: VoiceCommand.Target {
        VoiceCommand.Target(id: id, name: name, aliases: [branch, agent].compactMap { $0 })
    }
}

public struct FarolReply: Decodable, Equatable, Sendable {
    public let sessions: [FarolSession]?
    public let session: FarolSession?
    public let error: String?
}

/// Whether commands will work, so Settings can say so before you've tried one.
public enum FarolStatus: Equatable, Sendable {
    case ready, closed, notInstalled, tooOld, needsSetting, notVerified, unreachable

    /// A request that can't change anything: it's refused for its text, after the checks this wants to know about.
    public static let probe = FarolAction.type(session: "", text: "\n", submit: false, asking: nil)

    /// Farol answers the probe in words, checking the caller and the setting before anything else.
    public init(probeError error: String?) {
        if error?.contains("Only Farol Voice") == true {
            self = .notVerified
        } else if error?.contains("Turn on") == true {
            self = .needsSetting
        } else {
            self = .ready
        }
    }
}
