import Testing
@testable import VoiceCore

@Test func acceptsHowItReallyHearsOkFarol() {
    // From real recordings of someone saying "OK Farol".
    for heard in ["Okay, Pharaoh.", "Okay, Faro.", "Okay for all.", "Ok for all.", "Okay, Farrell.", "Okay, Ferrell.", "Okie fall.", "Okay, Vault.", "Ok, Faro.", "Okay, far."] {
        #expect(WakeCheck.confirms(heard), "\(heard)")
    }
}

@Test func rejectsTheNearMisses() {
    for heard in ["Hey Farol.", "Hey Pharaoh.", "Okay, Carol.", "OK Google.", "Okay, fine.", "Okay.", "Okay, so then.", "They fell.", "Who gave a hole?", ""] {
        #expect(!WakeCheck.confirms(heard), "\(heard)")
    }
}
