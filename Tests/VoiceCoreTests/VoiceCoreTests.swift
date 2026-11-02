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

    func testAddsWordsOnce() {
        XCTAssertEqual(DictationText.list("Farol", adding: " snowztech "), "Farol, snowztech")
        XCTAssertEqual(DictationText.list("Farol", adding: "farol, Ghostty"), "Farol, Ghostty")
        XCTAssertEqual(DictationText.list("", adding: "Farol"), "Farol")
        XCTAssertEqual(DictationText.list("Farol", adding: " , "), "Farol")
    }

    func testRemovesAWord() {
        XCTAssertEqual(DictationText.list("Farol, Ghostty", removing: "Farol"), "Ghostty")
        XCTAssertEqual(DictationText.list("Farol", removing: "Farol"), "")
    }

    func testRecommendsParakeetForLanguagesItKnows() {
        XCTAssertEqual(VoiceModel.recommended(languages: ["pt-PT", "en"]), .parakeetV3)
        XCTAssertEqual(VoiceModel.recommended(languages: ["fr_FR"]), .parakeetV3)
        XCTAssertEqual(VoiceModel.recommended(languages: []), .parakeetV3)
    }

    func testRecommendsWhisperOtherwise() {
        XCTAssertEqual(VoiceModel.recommended(languages: ["ja-JP", "en"]), .whisperTurbo)
    }

    func testChoosesTheModelFromTheLanguage() {
        XCTAssertEqual(VoiceModel.best(for: "en"), .parakeetV2)
        XCTAssertEqual(VoiceModel.best(for: "pt"), .parakeetV3)
        XCTAssertEqual(VoiceModel.best(for: "ja"), .whisperTurbo)
        XCTAssertEqual(VoiceModel.best(for: nil), .parakeetV3)
    }

    func testOnlyWhisperIsHeldToALanguage() {
        XCTAssertEqual(VoiceModel.whisperTurbo.lockedLanguage("ja"), "ja")
        XCTAssertNil(VoiceModel.whisperTurbo.lockedLanguage(nil))
        XCTAssertNil(VoiceModel.parakeetV3.lockedLanguage("en"))
    }

    func testStartsFromTheMacsLanguage() {
        XCTAssertEqual(SpeechLanguage.initial(preferred: ["pt-PT", "en"]), "pt")
        XCTAssertEqual(SpeechLanguage.initial(preferred: ["ja_JP"]), "ja")
        XCTAssertEqual(SpeechLanguage.initial(preferred: ["tlh"]), SpeechLanguage.automatic)
        XCTAssertEqual(SpeechLanguage.initial(preferred: []), SpeechLanguage.automatic)
    }

    func testPutsYourLanguagesFirst() {
        XCTAssertEqual(SpeechLanguage.yours(preferred: ["pt-PT", "en-GB", "pt-BR", "tlh"]), ["pt", "en"])
    }

    func testOffersEveryLanguageEitherModelKnows() {
        XCTAssertEqual(SpeechLanguage.codes.count, Set(SpeechLanguage.codes).count)
        for code in ["bg", "cs", "da", "de", "el", "en", "es", "et", "fi", "fr", "hr", "hu", "it", "lt", "lv", "mt", "nl", "pl", "pt", "ro", "ru", "sk", "sl", "sv", "uk"] {
            XCTAssertTrue(SpeechLanguage.codes.contains(code), code)
            XCTAssertEqual(VoiceModel.best(for: code), code == "en" ? .parakeetV2 : .parakeetV3, code)
        }
    }

    func testEveryLanguageOnOfferCanBeChosenFromTheList() {
        XCTAssertTrue(SpeechLanguage.codes.contains("en"))
        XCTAssertTrue(SpeechLanguage.codes.contains("ja"))
        XCTAssertNil(SpeechLanguage.language(from: SpeechLanguage.automatic))
        XCTAssertEqual(SpeechLanguage.language(from: "fr"), "fr")
    }
}
