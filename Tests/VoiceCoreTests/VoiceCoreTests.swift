import XCTest
@testable import VoiceCore

final class VoiceCoreTests: XCTestCase {
    func testTextCanNeverPressReturnOrDriveATerminal() {
        XCTAssertEqual(DictationText.clean("rm -rf build\nyes\r"), "rm -rf build yes ")
        XCTAssertEqual(DictationText.clean("hi\u{1B}[31m"), "hi [31m ")
    }

    func testKeepsAccents() {
        XCTAssertEqual(DictationText.clean("  Olá, ça va?  "), "Olá, ça va? ")
    }

    func testEmptyTypesNothing() {
        XCTAssertEqual(DictationText.clean(" \n "), "")
    }

    func testFixesYourWords() {
        let words = ["Farol", "snowztech", "git"]
        XCTAssertEqual(DictationText.clean("hey Farrol.", customWords: words), "hey Farol. ")
        XCTAssertEqual(DictationText.clean("open farole, please", customWords: words), "open Farol, please ")
        XCTAssertEqual(DictationText.clean("I work at SNOWZTECH", customWords: words), "I work at snowztech ")
        XCTAssertEqual(DictationText.clean("use GIT now", customWords: words), "use git now ")
    }

    func testJoinsANameSplitInTwo() {
        XCTAssertEqual(DictationText.clean("hey fa roll!", customWords: ["Farol"]), "hey Farol! ")
    }

    func testLeavesOtherWordsAlone() {
        let words = ["Farol", "git"]
        XCTAssertEqual(DictationText.clean("hey Carol", customWords: words), "hey Carol ")
        XCTAssertEqual(DictationText.clean("for all of it", customWords: words), "for all of it ")
        XCTAssertEqual(DictationText.clean("get it", customWords: words), "get it ")
    }

    func testReadsTheListFromSettings() {
        XCTAssertEqual(DictationText.words(from: " Farol, snowztech,, "), ["Farol", "snowztech"])
    }

    func testRecommendsParakeetForLanguagesItKnows() {
        XCTAssertEqual(VoiceModel.recommended(languages: ["pt-PT", "en"]), .parakeetV3)
        XCTAssertEqual(VoiceModel.recommended(languages: ["fr_FR"]), .parakeetV3)
        XCTAssertEqual(VoiceModel.recommended(languages: []), .parakeetV3)
    }

    func testRecommendsWhisperOtherwise() {
        XCTAssertEqual(VoiceModel.recommended(languages: ["ja-JP", "en"]), .whisperTurbo)
    }
}
