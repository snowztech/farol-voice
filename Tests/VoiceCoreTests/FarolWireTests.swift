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
