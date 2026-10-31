# Farol Voice

Say "hey Farol" and control your terminal and agents by voice. A companion app for [Farol](https://github.com/snowztech/farol), running on your Mac.

Early. Today it's only the wake word, and it isn't good enough yet. See [ROADMAP.md](ROADMAP.md).

## Try it

Needs macOS 15. The model downloads on first run.

```sh
swift run -c release farol-voice listen
```

macOS asks your terminal for microphone access the first time. To keep a log for the workday test:

```sh
swift run -c release farol-voice listen | tee wakes.log
```

## Score it

Scoring runs recordings through the same streaming path as the mic, so results stay comparable between models and settings. A corpus has two folders of 16 kHz mono WAV files:

```text
corpus/positive/   clips of someone saying "hey Farol"
corpus/negative/   anything else, ideally a full day of it
```

```sh
scripts/record-positives.sh desk-macbook     # 20 clips of you
ffmpeg -f avfoundation -i ":0" -ar 16000 -ac 1 corpus/negative/workday.wav   # stop with q
swift run -c release farol-voice score corpus
```

`corpus/` is ignored by git, so recordings stay on your machine.

## Work on it

```sh
swift test
```

## License

[MIT](LICENSE).
