# Roadmap

The goal: a voice assistant for your terminal and agents, with dictation that works everywhere. Say "OK Farol" from anywhere, and it opens Farol if needed, runs your agents and talks back. When you just want to write, it types into any app.

Farol Voice is its own menu bar app, so it works whether Farol is open or not, and Farol itself carries no voice code. Everything stays on your Mac. Farol only gets small additions to its socket.

Dictation is the way in, but Handy and Wispr Flow are already great at it. Running agents by voice is the reason to choose this one.

## How we'll know it's good

A milestone isn't done until it clears its bar on real use. These are starting numbers, and they can change once we've lived with them.

| What | Bar |
|---|---|
| Wake word catches real attempts | At least 95%, at the desk and across the room |
| False wakes | At most 1 per workday, with calls, music and typing |
| Stop talking until the turn is detected | Under 500 ms |
| Turn detected until final text | Under 200 ms |
| First spoken word of a prepared reply | Under 300 ms |
| Speech stops after you interrupt | Under 100 ms |
| Sent to the wrong session | Never |

The launch test: run 5 agents for an hour, mostly without looking at the screen, with no wrong sends and no missed questions.

## 1. Dictation everywhere

In progress, and done when it has replaced Handy for a week.

- [x] Menu bar app with a global hold-to-talk key
- [x] A pill with a waveform from the real mic level
- [x] Typing into any app, with the clipboard put back afterwards
- [x] Installing, choosing and deleting models, loading with no network once installed
- [x] Custom words for names and terms
- [ ] Use it for a week, on real work
- [ ] Compare it with Wispr Flow on the same speech, and add an optional cleanup pass if the gap shows

## 2. First release: dictation

The first version people can use, before it controls Farol. Publish it once it has passed the week above. The page says agent control is coming, so this doesn't read as one more dictation app.

- [ ] Its own app icon, instead of Farol's
- [ ] Signed and notarized DMG, adapted from Farol's `scripts/dist.sh`
- [ ] Automatic updates with Sparkle
- [ ] Make this repo public
- [ ] A one-page site at `voice.farol.sh`
- [ ] Only claim what works today: local, private and free. No agent control or "OK Farol" until they ship

**Next, and the reason this app exists: step 3, Control Farol.** Don't stop at dictation.

## 3. Control Farol

Done when you can switch sessions and message agents from any app, and it opens Farol if it's closed. The rules were first tried on Farol's `feat/voice-input` branch, which stays as a reference and won't be merged.

- A second key to tell Farol what to do: go to a session, message one, start a task
- Each of these first as a small PR in Farol's socket: its own permission, focus a session, a send that only goes through if the session is still waiting on the same question
- Launch Farol and wait for its socket when it's closed
- A shell command spoken aloud is always read back and only runs after you say yes

## 4. Spoken replies

Hear what agents ask, and answer them, using `farol sessions`, `read` and `send`.

- Kokoro for speech. Compare it with Cartesia and ElevenLabs on real spoken summaries
- Compare Parakeet with WhisperKit and Deepgram Flux on about 100 real commands, aiming for 95% understood

## 5. Conductor

A small, fast agent that hears you, works out which session you mean, and acts.

- Spoken status: "what's everyone doing?"
- Routing, with the target locked and shown before anything is sent
- Rebuilding your request from session context, with your approval before it's sent

## 6. "OK Farol"

Comes after the assistant is worth waking. It becomes one more toggle in Settings. Test "OK Farol" and "hey Farol" aloud and pick one before training.

- [x] `farol-voice listen` and `farol-voice score`, scoring through the same streaming path the mic uses
- [x] Baseline on `SpeechWakeWord`, an off-the-shelf keyword spotter
- [x] Try `listen` on a real microphone
- [ ] Find out why CoreML can't compile a model for the Neural Engine at startup, and what that costs in power
- [ ] Train a custom "hey Farol" model on openWakeWord. Training is synthetic, then checked on real voices. Check the license of its shared speech embedding model before shipping it
- [ ] Run it from Swift, through ONNX Runtime or converted to CoreML
- [ ] Record real clips with `scripts/record-positives.sh`: desk, across the room, headset, several people and accents
- [ ] Clear the bar on a full day of negatives

### What we've learned

The baseline doesn't work well enough, and tuning won't fix it. On clean synthetic speech from `say`, it caught 9 of 60 clips, with no false wakes in 24 minutes of speech and near misses like "hey Carol". The model has a fixed English vocabulary and "Farol" isn't in it. The best of 270 spellings caught 4 or 5 of 8 clips, while phrases it knows, like "light up", caught 8 of 8. A real voice got the same result: 3 of 20 clips at the desk on a MacBook mic.

Porcupine is out. Home Assistant users report Picovoice ended its free tier in June 2026 with no non-commercial plan, and it needs an access key, which doesn't suit an open source app. We haven't confirmed this with Picovoice.

openWakeWord's pretrained models are non-commercial, but its code is Apache 2.0 and we'd train our own. Its own target is under 5% missed and under 0.5 false wakes an hour, which is well short of our bar for false wakes, so we should expect to need a confirmation step, such as checking the phrase again with the speech recognizer.

Calling CoreML in a long loop without an autorelease pool crashes after a few minutes of audio. Anything that listens all day has to drain one per chunk.

## 7. Natural talking

- Smart Turn v3 with Silero VAD, so a thinking pause doesn't end your turn
- Echo cancelling, so Farol never wakes itself
- Instant interruption
- Live text, then a final pass, then correction against session, branch and file names

## 8. Agent launch

The big launch, once it runs your agents by voice. Safety gating, then launch as the open source voice harness, with an uncut recording of the launch test.

## 9. Phone

Voice in Farol for iPhone over Remote. Talking to your agents away from your desk is what SKI's site doesn't offer today.

## 10. Chains and PRs by voice

One command starts a planning agent and then a building agent. PRs by voice on Farol's worktrees. These come last because they depend on everything above.

## Not planned

- Plugins in Farol. Everything goes through its socket.
- Sending audio to the cloud by default. Cloud engines stay optional, on your own key.
