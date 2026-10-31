import XCTest
@testable import WakeWord

final class ScoreTests: XCTestCase {
    func testOneUtteranceFiringTwiceIsOneWake() {
        var gate = WakeGate(cooldown: 2)
        XCTAssertTrue(gate.accept(at: 10))
        XCTAssertFalse(gate.accept(at: 11.9))
        XCTAssertTrue(gate.accept(at: 12))
    }

    func testPassesOnlyWithEnoughAudio() {
        var score = Score()
        score.attempts = 40
        score.caught = 38
        score.negativeSeconds = Score.workdaySeconds
        score.falseWakes = 1
        XCTAssertTrue(score.passes)

        score.negativeSeconds = 3600
        score.falseWakes = 0
        XCTAssertFalse(score.passes)
    }

    func testFailsOnEitherBar() {
        var score = Score()
        score.attempts = 40
        score.caught = 37
        score.negativeSeconds = Score.workdaySeconds
        XCTAssertFalse(score.passes)

        score.caught = 40
        score.falseWakes = 2
        XCTAssertFalse(score.passes)
    }

    func testEmptyScoreDoesNotPass() {
        XCTAssertEqual(Score().recall, 0)
        XCTAssertFalse(Score().passes)
    }

    func testEverySpellingIsRegistered() {
        XCTAssertEqual(HeyFarol.keywords(threshold: 0.15, boost: 0.5).count, HeyFarol.spellings.count)
    }
}
