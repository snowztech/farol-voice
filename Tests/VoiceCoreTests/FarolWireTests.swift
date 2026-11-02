import Foundation
import Testing
@testable import VoiceCore

private func json(_ action: FarolAction) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return String(decoding: try encoder.encode(FarolRequest(action: action)), as: UTF8.self)
}

@Test func speaksFarolsFormat() throws {
    #expect(try json(.focus(session: "A")) == #"{"action":{"focus":{"session":"A"}}}"#)
    #expect(try json(.sessions) == #"{"action":{"sessions":{}}}"#)
    #expect(try json(.watch(after: 3, timeout: 25)) == #"{"action":{"watch":{"after":3,"timeout":25}}}"#)
    #expect(try json(.answer(session: "A", asking: "Allow?", choice: 2)) == #"{"action":{"answer":{"asking":"Allow?","choice":2,"session":"A"}}}"#)
    #expect(try json(.type(session: "A", text: "hi", submit: true, asking: nil)) == #"{"action":{"type":{"session":"A","submit":true,"text":"hi"}}}"#)
    #expect(try json(.task(text: "add search", repo: "/r", agent: nil)) == #"{"action":{"task":{"repo":"\/r","text":"add search"}}}"#)
}

@Test func readsFarolsReply() throws {
    let line = #"{"sessions":[{"id":"A","name":"auth","folder":"/r","branch":"main","status":"waiting","asking":"Allow rm?","isCaller":false}]}"#
    let reply = try JSONDecoder().decode(FarolReply.self, from: Data(line.utf8))
    #expect(reply.sessions?.first?.isWaiting == true)
    #expect(reply.sessions?.first?.target.aliases == ["main"])
    #expect(reply.error == nil)
}

@Test func readsWhatTheProbeSays() {
    #expect(FarolStatus(probeError: "Only Farol Voice can do this.") == .notVerified)
    #expect(FarolStatus(probeError: "Turn on Settings → Agents → Let Farol Voice control sessions in Farol.") == .needsSetting)
    #expect(FarolStatus(probeError: "No session is called . `farol sessions` lists them.") == .ready)
}

@Test func readsWhatAWatchSays() throws {
    let line = #"{"generation":4,"sessions":[{"id":"A","name":"auth","folder":"/r","status":"waiting","asking":"Allow?","isCaller":false,"inFront":true,"choices":["Yes","No"]}]}"#
    let reply = try JSONDecoder().decode(FarolReply.self, from: Data(line.utf8))
    #expect(reply.generation == 4)
    #expect(reply.sessions?.first?.choices == ["Yes", "No"])
    #expect(reply.sessions?.first?.inFront == true)
}
