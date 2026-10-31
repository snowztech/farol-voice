# Roadmap

The goal: say "hey Farol" from across the room, without touching the keyboard, and your terminal and agents do what you asked.

Voice lives outside Farol so it can never slow the terminal down. Audio, models and the conductor stay here. Farol only gets small additions to its socket.

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

## 1. Wake word

In progress. This comes first because everything starts with those two words.

- [x] `farol-voice listen` and `farol-voice score`, scoring through the same streaming path the mic uses
- [x] Baseline on `SpeechWakeWord`, an off-the-shelf keyword spotter
- [ ] Try `listen` on a real microphone
- [ ] Train a custom "hey Farol" model on openWakeWord. Training is synthetic, then checked on real voices. Check the license of its shared speech embedding model before shipping it
- [ ] Run it from Swift, through ONNX Runtime or converted to CoreML
- [ ] Record real clips with `scripts/record-positives.sh`: desk, across the room, headset, several people and accents
- [ ] Clear the bar on a full day of negatives

### What we've learned

The baseline doesn't work well enough, and tuning won't fix it. On clean synthetic speech from `say`, it caught 9 of 60 clips, with no false wakes in 24 minutes of speech and near misses like "hey Carol". The model has a fixed English vocabulary and "Farol" isn't in it. The best of 270 spellings caught 4 or 5 of 8 clips, while phrases it knows, like "light up", caught 8 of 8.

Porcupine is out. Home Assistant users report Picovoice ended its free tier in June 2026 with no non-commercial plan, and it needs an access key, which doesn't suit an open source app. We haven't confirmed this with Picovoice.

openWakeWord's pretrained models are non-commercial, but its code is Apache 2.0 and we'd train our own. Its own target is under 5% missed and under 0.5 false wakes an hour, which is well short of our bar for false wakes, so we should expect to need a confirmation step, such as checking the phrase again with the speech recognizer.

Calling CoreML in a long loop without an autorelease pool crashes after a few minutes of audio. Anything that listens all day has to drain one per chunk.

## 2. Voice loop

Hear what agents ask, and answer them, using `farol sessions`, `read` and `send`.

- Parakeet for speech recognition. Compare it with WhisperKit and Deepgram Flux on about 100 real commands, aiming for 95% understood
- Kokoro for speech. Compare it with Cartesia and ElevenLabs on real spoken summaries
- A hotkey that always works, for noisy rooms and calls

## 3. Natural talking

- Smart Turn v3 with Silero VAD, so a thinking pause doesn't end your turn
- Echo cancelling, so Farol never wakes itself
- Instant interruption
- Live text, then a final pass, then correction against session, branch and file names

## 4. Conductor

A small, fast agent that hears you, works out which session you mean, and acts.

- Spoken status: "what's everyone doing?"
- Routing, with the target locked and shown before anything is sent
- Rebuilding your request from session context, with your approval before it's sent

## 5. Control the terminal

Farol needs these on its socket first. Each is a small PR in Farol, ahead of the work here.

- Its own permission, separate from letting agents message each other
- Live session events, instead of polling
- A send that only goes through if the session is still waiting on the same question
- Focus a session, open a panel, run a command
- A shell command spoken aloud is always read back and only runs after you say yes

## 6. Public beta

Safety gating, then launch as the open source voice harness, with an uncut recording of the launch test.

## 7. Phone

Voice in Farol for iPhone over Remote. Talking to your agents away from your desk is what SKI's site doesn't offer today.

## 8. Chains and PRs by voice

One command starts a planning agent and then a building agent. PRs by voice on Farol's worktrees. These come last because they depend on everything above.

## Not planned

- Plugins in Farol. Everything goes through its socket.
- Sending audio to the cloud by default. Cloud engines stay optional, on your own key.
