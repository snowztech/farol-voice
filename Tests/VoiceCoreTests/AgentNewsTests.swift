import Foundation
import Testing
@testable import VoiceCore

private func session(_ id: String, _ status: String, asking: String? = nil, choices: [String]? = nil, inFront: Bool = false) -> FarolSession {
    FarolSession(id: id, name: id, folder: "/r", status: status, asking: asking, choices: choices, inFront: inFront)
}

@Test func saysWhenASessionStartsAsking() {
    let new = session("auth", "waiting", asking: "Allow rm?")
    #expect(AgentNews.changes(from: [session("auth", "working")], to: [new]) == [.question(new)])
}

@Test func saysItAgainOnlyForANewQuestion() {
    let first = session("auth", "waiting", asking: "Allow rm?")
    let second = session("auth", "waiting", asking: "Allow push?")
    #expect(AgentNews.changes(from: [first], to: [first]).isEmpty)
    #expect(AgentNews.changes(from: [first], to: [second]) == [.question(second)])
}

@Test func staysQuietAboutWhatYoureLookingAt() {
    #expect(AgentNews.changes(from: [session("auth", "working")], to: [session("auth", "waiting", asking: "Allow?", inFront: true)]).isEmpty)
    #expect(AgentNews.changes(from: [session("auth", "working")], to: [session("auth", "done", inFront: true)]).isEmpty)
}

@Test func saysNothingAboutSessionsItHasNotSeenBefore() {
    #expect(AgentNews.changes(from: [], to: [session("auth", "waiting", asking: "Allow?")]).isEmpty)
}

@Test func onlyWorkThatEndedCountsAsFinished() {
    #expect(AgentNews.changes(from: [session("a", "working")], to: [session("a", "done")]) == [.finished(["a"])])
    #expect(AgentNews.changes(from: [session("a", "idle")], to: [session("a", "done")]).isEmpty)
}

@Test func readsWell() {
    #expect(AgentNews.finished(["auth"]).sentence == "auth is done.")
    #expect(AgentNews.finished(["a", "b"]).sentence == "2 agents are done.")
    #expect(AgentNews.question(session("auth", "waiting")).sentence == "auth needs you.")
    #expect(AgentNews.question(session("auth", "waiting", asking: "Bash · `npm test`", choices: ["Yes", "No"])).sentence == "auth asks: Bash: npm test Yes or no?")
}

@Test func doesNotReadAWholeScript() {
    let long = String(repeating: "word ", count: 100)
    let sentence = AgentNews.question(session("a", "waiting", asking: long)).sentence
    #expect(sentence.count < 200)
    #expect(sentence.contains(", and more."))
}

@Test func questionsGoFirstAndFinishedOnesMerge() {
    var queue = NewsQueue()
    let question = session("auth", "waiting", asking: "Allow?")
    queue.add([.finished(["a"])])
    queue.add([.question(question), .finished(["b"])])
    #expect(queue.next() == .question(question))
    #expect(queue.next() == .finished(["a", "b"]))
    #expect(queue.next() == nil)
}

@Test func aNewerQuestionReplacesTheOlderOne() {
    var queue = NewsQueue()
    let newer = session("auth", "waiting", asking: "Allow push?")
    queue.add([.question(session("auth", "waiting", asking: "Allow rm?")), .question(newer)])
    #expect(queue.items == [.question(newer)])
}

@Test func dropsAQuestionAnsweredElsewhere() {
    var queue = NewsQueue()
    let question = session("auth", "waiting", asking: "Allow?")
    queue.add([.question(question)])
    queue.drop(outdatedBy: [question])
    #expect(!queue.isEmpty)
    queue.drop(outdatedBy: [session("auth", "working")])
    #expect(queue.isEmpty)
}

private let claude = ["Yes", "Yes, and don't ask again for npm commands", "No, and tell Claude what to do differently"]

@Test func aPlainYesPicksTheOnceOnlyOption() {
    for spoken in ["Yes", "Yes.", "yeah go ahead", "go ahead", "Okay, do it", "yes please", "Allow", "Oui"] {
        #expect(AgentAnswer.parse(spoken, choices: claude) == .choice(1), "\(spoken)")
    }
}

@Test func aPlainNoPicksNo() {
    for spoken in ["No", "no thanks", "Don't do it.", "stop", "Nope", "Non"] {
        #expect(AgentAnswer.parse(spoken, choices: claude) == .choice(3), "\(spoken)")
    }
}

@Test func yesNeverAllowsSomethingForGood() {
    #expect(AgentAnswer.parse("yes", choices: ["Yes, always", "No"]) == .unclear)
    #expect(AgentAnswer.parse("Yes, and don't ask again for npm commands", choices: claude) == .choice(2))
}

@Test func anythingMixedOrUnrelatedAsksAgain() {
    for spoken in ["yes no", "no, go ahead", "maybe", "what does it do", "yes but only for tests", "", "the weather is nice"] {
        #expect(AgentAnswer.parse(spoken, choices: claude) == .unclear, "\(spoken)")
    }
}

@Test func optionsCanBeNamedOrNumbered() {
    let choices = ["Postgres", "SQLite"]
    #expect(AgentAnswer.parse("SQLite.", choices: choices) == .choice(2))
    #expect(AgentAnswer.parse("option two", choices: choices) == .choice(2))
    #expect(AgentAnswer.parse("1", choices: choices) == .choice(1))
    #expect(AgentAnswer.parse("three", choices: choices) == .unclear)
}

@Test func onlyAMenuItCouldReadGetsAnsweredAloud() {
    #expect(session("a", "waiting", asking: "Allow?", choices: ["Yes", "No"]).canAnswerAloud)
    #expect(!session("a", "waiting", asking: "Allow?").canAnswerAloud)
    #expect(!session("a", "waiting", asking: "Allow?", choices: []).canAnswerAloud)
    #expect(!session("a", "waiting", choices: ["Yes", "No"]).canAnswerAloud)
    #expect(AgentNews.question(session("a", "waiting", asking: "Allow?")).sentence == "a asks: Allow? It's waiting on screen.")
}

private func run(_ levels: [(Double, Double)], patience: Double = 8) -> SpeechEndpoint.State {
    var endpoint = SpeechEndpoint(startingAt: 0, patience: patience)
    for (time, level) in levels { endpoint.hear(level: level, at: time) }
    return endpoint.state
}

@Test func finishesAfterAQuietMomentFollowingSpeech() {
    #expect(run([(0.1, 0.1), (0.5, 0.7), (1, 0.7), (1.5, 0.1)]) == .speaking)
    #expect(run([(0.1, 0.1), (0.5, 0.7), (1, 0.7), (2.1, 0.1)]) == .finished)
}

@Test func givesUpWhenNobodyTalks() {
    #expect(run([(0.1, 0.1), (5, 0.1)]) == .listening)
    #expect(run([(0.1, 0.1), (8.1, 0.1)]) == .nothing)
}

@Test func aNoisyRoomIsNotSpeech() {
    #expect(run([(0.1, 0.4), (5, 0.45), (9, 0.45)]) == .nothing)
    #expect(run([(0.1, 0.4), (1, 0.7)]) == .speaking)
}

@Test func aShortPauseDoesNotEndIt() {
    #expect(run([(0.5, 0.7), (1.2, 0.1), (1.4, 0.7), (2, 0.1)]) == .speaking)
}
