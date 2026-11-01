# Roadmap

The goal: a voice assistant for your terminal and agents, with dictation that works everywhere. Say "OK Farol" from anywhere, and it opens [Farol](https://github.com/snowztech/farol) if needed, runs your agents and talks back. When you just want to write, it types into any app.

Farol Voice is its own app, so it works whether Farol is open or not, and Farol itself carries no voice code. Everything runs on your Mac.

## How we'll know it's good

A step isn't done until it clears its bar in real use. These are starting numbers, and they can change once we've lived with them.

| What | Bar |
|---|---|
| Wake word catches real attempts | At least 95%, at the desk and across the room |
| False wakes | At most 1 per workday, with calls, music and typing |
| Stop talking until the turn is detected | Under 500 ms |
| Turn detected until final text | Under 200 ms |
| First spoken word of a prepared reply | Under 300 ms |
| Speech stops after you interrupt | Under 100 ms |
| Sent to the wrong session | Never |

## 1. Dictation everywhere

In progress, and done when it has replaced other dictation apps for a week of real work.

- [x] Menu bar app with a global hold-to-talk key
- [x] A small waveform from the real mic level
- [x] Typing into any app, with the clipboard put back afterwards
- [x] Installing, choosing and deleting models, with no network once installed
- [x] Custom words for names and terms
- [x] First-time setup
- [ ] A week of daily use
- [ ] Compare accuracy with paid tools on the same speech, and add an optional cleanup pass if the gap shows
- [x] A choice of Fn or any right-side modifier key
- [ ] Record any shortcut, and tap to start and stop
- [ ] Rethink how you choose a model, in plain terms like fast or more languages rather than model names

## 2. First release

The first version anyone can download, before it controls Farol. It only claims what works today.

- [x] Its own app icon
- [x] Signed and notarized DMG
- [x] Automatic updates
- [ ] A full license check of everything the app includes
- [ ] A demo GIF in the README
- [ ] Make this repo public
- [x] A one-page site for `voice.farol.sh`
- [ ] Link the site from About once it's live
- [ ] A Homebrew cask

**Next, and the reason this app exists: step 3.** Don't stop at dictation.

## 3. Control Farol

Done when you can switch sessions and message agents from any app, and it opens Farol if it's closed.

- A second key to tell Farol what to do: go to a session, message one, start a task
- Each of these first as a small PR in Farol's socket: its own permission, focus a session, a send that only goes through if the session is still waiting on the same question
- Launch Farol and wait for its socket when it's closed
- A shell command spoken aloud is always read back and only runs after you say yes

## 4. Spoken replies

Hear what agents ask, and answer them, even minutes later.

- Live events from Farol's socket when a session waits or finishes
- Text to speech on your Mac, starting with Kokoro
- One voice at a time, with questions first, and never talking over you
- After it speaks, answer without pressing anything

## 5. Conductor

A small, fast agent that hears you, works out which session you mean, and acts.

- Spoken status: "what's everyone doing?"
- Routing, with the target locked and shown before anything is sent
- Rebuilding your request from session context, with your approval before it's sent
- Plain rules stay as the instant path, and the language model handles the rest, on your own key or running locally

## 6. "OK Farol"

Comes once the assistant is worth waking. It's one more toggle in Settings, and works from any app.

- Train a custom model with openWakeWord, since off-the-shelf keyword spotters don't know the word Farol
- Check each wake again with the speech recognizer, to reach the false wake bar
- Test on real voices: at the desk, across the room, on a headset, several accents, and a full day of negatives

## 7. Natural talking

- Smart Turn with Silero VAD, so a thinking pause doesn't end your turn
- Echo cancelling, so it never wakes itself
- Instant interruption
- Correction against session, branch and file names

## 8. Agent launch

The big launch, once it runs your agents by voice, with an uncut recording of an hour running five agents mostly without looking at the screen.

## 9. Phone

Voice in Farol for iPhone over Remote, to talk to your agents away from your desk.

## 10. Chains and PRs by voice

One command starts a planning agent and then a building agent. PRs by voice on Farol's worktrees.

## Not planned

- Sending audio to the cloud by default. Cloud engines stay optional, on your own key.
- Accounts or a subscription for dictation.
