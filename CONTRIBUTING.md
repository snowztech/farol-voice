# Contributing

Thanks for helping. Small, focused pull requests are the easiest to review and merge. For a new feature, open an issue first: [ROADMAP.md](ROADMAP.md) lists what's planned and what's not.

## Run it

You need macOS 15 or later on Apple Silicon, and Xcode 26.

```sh
make run
```

macOS keeps its permissions across rebuilds when the app is signed with an Apple Development certificate, which `scripts/bundle.sh` uses if you have one. Without one, you'll be asked to allow Accessibility again after each build.

## Before you open a PR

```sh
make test
```

- Branch from `main`. One change per PR.
- Commits are one line in the Conventional Commits style: `fix(typer): keep the clipboard when pasting fails`.
- If users would notice the change, add a line under **Unreleased** in `CHANGELOG.md`.
- For UI changes, add a screenshot. A debug build renders the screens with `.build/debug/FarolVoice --snapshot <folder>`.

## Where things live

| Folder | What it is |
|---|---|
| `Sources/FarolVoice` | The menu bar app: the key, the pill, typing, settings and setup |
| `Sources/VoiceEngine` | The mic, recording, and installing and running models |
| `Sources/VoiceCore` | Models and text clean-up, tested without audio |
| `Sources/farol-voice` | A command line tool for comparing models on recordings |

Logic that can be wrong without a microphone belongs in `VoiceCore`, with a test.

## Writing

Docs, comments and PRs are short and plain.

- Say what changed and why, in a few sentences.
- Comments explain why, not what the code does.
- No em dashes.

AI tools are welcome. You're responsible for what they write: read it, trim it and test it before you open the PR.
