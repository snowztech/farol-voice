<p align="center">
  <img src="assets/icon.png" width="128" alt="Farol Voice icon">
</p>

<h1 align="center">Farol Voice</h1>

<p align="center">Talk to your Mac. Your words stay on it.</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS%2015%2B-Apple%20Silicon-007ec6?style=flat&logo=apple" alt="macOS 15 or later on Apple Silicon">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-007ec6?style=flat" alt="MIT license"></a>
</p>

Hold a key, talk, let go, and your words appear wherever you were typing: your editor, your terminal, Slack, a browser. Speech runs on your Mac, with no account, no subscription and nothing sent anywhere.

Hold a second key to tell [Farol](https://github.com/snowztech/farol), the terminal for coding agents, what to do. It's on its way to being a voice assistant for your agents. See [what's next](ROADMAP.md).

<p align="center">
  <img src="site/setup.png" width="49%" alt="The setup window, with steps to allow the microphone and Accessibility, install a speech model and try it.">
  <img src="site/settings.png" width="49%" alt="Settings, showing it's connected to Farol, the key to hold and what you can say.">
</p>

## What it does

- **Talks to your agents.** Say "open Farol", "go to auth", "tell auth to run the tests", or "new task, add a search box", from any app. It needs Farol 0.54.1 or later, with **Settings, Agents, Let Farol Voice control sessions** turned on.
- **Tells you what agents ask.** Turn it on in Settings, Farol, and it says when an agent asks something or finishes, then listens for your answer with no key: yes, no or an option's name. It needs the next version of Farol.
- **Works everywhere.** It types into any app, and puts your clipboard back afterwards.
- **Runs on your Mac.** Audio is never sent anywhere or saved. Once a model is installed, it needs no network.
- **Fast.** About a tenth of a second to transcribe a short phrase on Apple Silicon, using the Parakeet V3 model.
- **Pick your language.** It recommends the model for it: Parakeet for speed in English and 24 more languages, or Whisper for about 100. Install, switch and delete them yourself.
- **Gets your words right.** Add names and terms, and close matches become exactly what you wrote.
- **Careful with your words.** It won't type into a password field, and if you switch apps while it's working, the text goes to your clipboard and not the wrong window.
- **Quiet.** A small waveform shows while the mic is open, and it uses no CPU between uses.

## Install

[Download Farol Voice](https://github.com/snowztech/farol-voice/releases/latest/download/FarolVoice.dmg), and drag it to Applications. It needs macOS 15 or later on Apple Silicon, and it updates itself.

The setup window walks you through the rest: allow the microphone and Accessibility, install a model, and try it. After that it lives in your menu bar, under the sound bars.

Hold **Fn** to dictate and **Right Option** to tell Farol, or choose other keys in Settings. If Fn opens the emoji picker, change what it does in System Settings, Keyboard.

Models are in `~/Library/Application Support/Farol Voice/models`.

### Build it yourself

You need Xcode 26.

```sh
git clone https://github.com/snowztech/farol-voice && cd farol-voice
make run
```

## Why Accessibility?

macOS needs it for two things: noticing the key while you're in another app, and typing your words for you. Farol Voice only looks for the key you chose, and doesn't record or store what you type. The code is here to read: [`Dictation.swift`](Sources/FarolVoice/Dictation.swift) and [`Typer.swift`](Sources/FarolVoice/Typer.swift).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). To compare models on your own recordings:

```sh
swift run -c release farol-voice transcribe clip.wav --words "Farol, snowztech"
```

## License

[MIT](LICENSE). The speech models have their own licenses, listed in [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES).
