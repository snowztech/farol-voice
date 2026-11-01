import Foundation
import Testing
@testable import VoiceCore

private let sessions = [
    VoiceCommand.Target(id: "1", name: "fix/auth-login"),
    VoiceCommand.Target(id: "2", name: "search box"),
    VoiceCommand.Target(id: "3", name: "docs"),
]

private func spoken(_ text: String) -> VoiceCommand { VoiceCommand.parse(text, sessions: sessions) }

@Test func goesToASessionByAnyWordOfItsName() {
    #expect(spoken("Go to auth.") == .session(id: "1", text: nil, send: false, focus: true))
    #expect(spoken("switch to search box") == .session(id: "2", text: nil, send: false, focus: true))
    #expect(spoken("Open docs") == .session(id: "3", text: nil, send: false, focus: true))
}

@Test func goesThereAndTypes() {
    #expect(spoken("Go to auth and run the tests") == .session(id: "1", text: "run the tests", send: false, focus: true))
}

@Test func tellsASessionWithoutLeavingThisOne() {
    #expect(spoken("Tell auth to run the tests.") == .session(id: "1", text: "run the tests.", send: false, focus: false))
}

@Test func sendsOnlyWhenAskedTo() {
    #expect(spoken("Tell docs to fix the typo and send it.") == .session(id: "3", text: "fix the typo", send: true, focus: false))
}

@Test func tellingWithoutAMessageIsNotACommand() {
    #expect(spoken("Tell auth") == .notUnderstood)
}

@Test func forgivesASmallMishearing() {
    #expect(spoken("go to serch box") == .session(id: "2", text: nil, send: false, focus: true))
}

@Test func neverGuessesBetweenTwoSessions() {
    let two = [VoiceCommand.Target(id: "a", name: "auth login"), VoiceCommand.Target(id: "b", name: "auth signup")]
    #expect(VoiceCommand.parse("tell auth to stop", sessions: two) == .ambiguous(spoken: "auth", names: ["auth login", "auth signup"]))
    let same = [VoiceCommand.Target(id: "a", name: "docs"), VoiceCommand.Target(id: "b", name: "docs")]
    #expect(VoiceCommand.parse("go to docs and fix it", sessions: same) == .ambiguous(spoken: "docs", names: ["docs", "docs"]))
}

@Test func saysSoWhenNoSessionMatches() {
    #expect(spoken("go to kubernetes") == .noSession("kubernetes"))
}

@Test func startsATask() {
    #expect(spoken("New task, add a search box") == .newTask(agent: nil, text: "add a search box"))
    #expect(spoken("New Codex task to add a search box.") == .newTask(agent: "codex", text: "add a search box."))
    #expect(spoken("new task") == .notUnderstood)
}

@Test func ordinarySpeechIsNotACommand() {
    #expect(spoken("I think we should rewrite this") == .notUnderstood)
    #expect(spoken("") == .notUnderstood)
}

// Names as they really appear in a day's sidebar, with repeats.
private let realSidebar = [
    VoiceCommand.Target(id: "1", name: "Ask me in 3 sec", aliases: ["main", "codex"]),
    VoiceCommand.Target(id: "2", name: "pingbuddy-app", aliases: ["fix/admin-history-cleanup"]),
    VoiceCommand.Target(id: "3", name: "farol", aliases: ["main"]),
    VoiceCommand.Target(id: "4", name: "Claude Code", aliases: ["main", "claude"]),
    VoiceCommand.Target(id: "5", name: "farol", aliases: ["feat/voice"]),
    VoiceCommand.Target(id: "6", name: "Claude Code", aliases: ["read-docs", "claude"]),
    VoiceCommand.Target(id: "7", name: "dashmin", aliases: ["main"]),
]

private func said(_ text: String) -> VoiceCommand { VoiceCommand.parse(text, sessions: realSidebar) }

@Test func goingToARepeatedNameOffersEveryMatch() {
    #expect(said("Go to Farol.") == .choices(ids: ["3", "5"]))
    #expect(said("Go to the Claude Code session.") == .choices(ids: ["4", "6"]))
}

@Test func typingIntoARepeatedNameStillRefusesToGuess() {
    #expect(said("Tell farol to run the tests") == .ambiguous(spoken: "farol", names: ["farol", "farol"]))
}

@Test func aBranchPicksOutASession() {
    #expect(said("Go to read docs") == .session(id: "6", text: nil, send: false, focus: true))
    #expect(said("Tell read docs to summarize") == .session(id: "6", text: "summarize", send: false, focus: false))
}

@Test func acceptsNaturalWaysToNameASession() {
    #expect(said("Go to the dashmin session and run the tests.") == .session(id: "7", text: "run the tests.", send: false, focus: true))
    #expect(said("Take me to session dashmin") == .session(id: "7", text: nil, send: false, focus: true))
    #expect(said("Tell the pingbuddy app session to deploy") == .session(id: "2", text: "deploy", send: false, focus: false))
}

@Test func aNameBeatsABranchThatSoundsTheSame() {
    let sidebar = [VoiceCommand.Target(id: "a", name: "docs"), VoiceCommand.Target(id: "b", name: "api", aliases: ["docs"])]
    #expect(VoiceCommand.parse("go to docs", sessions: sidebar) == .session(id: "a", text: nil, send: false, focus: true))
}

@Test func opensTheAppByName() {
    #expect(said("Open Farol.") == .openFarol)
    #expect(said("open the Farol app") == .openFarol)
    #expect(said("Can you please open Farol?") == .openFarol)
    #expect(said("I want to launch Farol") == .openFarol)
    #expect(said("Farol.") == .openFarol)
}

@Test func goingToFarolStillMeansASession() {
    #expect(said("Go to Farol.") == .choices(ids: ["3", "5"]))
}

@Test func acceptsPoliteWays() {
    let dashmin = VoiceCommand.session(id: "7", text: nil, send: false, focus: true)
    #expect(said("Can you go to dashmin?") == dashmin)
    #expect(said("Please open dashmin") == dashmin)
    #expect(said("Okay, go over to dashmin, please") == dashmin)
    #expect(said("I want to go to dashmin") == dashmin)
    #expect(said("Farol, go to dashmin") == dashmin)
    #expect(said("Could you tell read docs to summarize") == .session(id: "6", text: "summarize", send: false, focus: false))
}
