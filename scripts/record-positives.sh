#!/bin/sh
# Records clips of you saying the wake word, for `farol-voice score`.
# Usage: scripts/record-positives.sh <label> [count]
# Use a label per setup, like desk-macbook or across-room-headset.
set -eu

label=${1:?usage: record-positives.sh <label> [count]}
count=${2:-20}
dir=corpus/positive
mkdir -p "$dir"

i=1
while [ "$i" -le "$count" ]; do
    printf 'Clip %s of %s. Press return, then say "hey Farol".' "$i" "$count"
    read -r _
    ffmpeg -loglevel error -y -f avfoundation -i ":0" -t 3 -ar 16000 -ac 1 "$dir/$label-$i.wav"
    i=$((i + 1))
done
