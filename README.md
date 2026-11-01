# Farol Voice

A voice assistant for your terminal and agents, with dictation that works everywhere. It lives in the menu bar and runs on your Mac.

Early. Today it's dictation: hold a key, talk, let go, and your words appear wherever you were typing. Controlling [Farol](https://github.com/snowztech/farol) and its agents comes next. See [ROADMAP.md](ROADMAP.md).

## Try it

Needs macOS 15 and Xcode.

```sh
make run
```

Allow the microphone and Accessibility in the window that opens, and install a model if none is installed. Then hold Fn, talk and let go. If Fn opens the emoji picker, choose Right Option in Settings, or change what Fn does in System Settings, Keyboard.

Speech runs on this Mac and audio is never sent anywhere or saved. Models are in `~/Library/Application Support/Farol Voice/models`, and once installed they load with no network.

## Measure it

The `farol-voice` command tests models on recordings, so results stay comparable. Recordings in `corpus/` are ignored by git and stay on your machine.

```sh
swift run -c release farol-voice transcribe clip.wav --words "Farol, snowztech"
swift run -c release farol-voice listen
swift run -c release farol-voice score corpus
scripts/record-positives.sh desk-macbook
```

`listen` and `score` test the wake word. A corpus has `positive/` and `negative/` folders of 16 kHz mono WAV files.

## Work on it

```sh
make test
```

## License

[MIT](LICENSE).
