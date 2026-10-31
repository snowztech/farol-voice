#!/bin/sh
# Builds the helper and puts it where Farol looks for it, until releases exist to download.
set -eu

swift build -c release
folder="$HOME/Library/Application Support/Farol/Voice/bin"
mkdir -p "$folder"
cp .build/release/farol-voice "$folder/farol-voice"
# speech-swift ships resource bundles the helper loads next to itself.
find .build/release -maxdepth 1 -name '*.bundle' -exec cp -R {} "$folder/" \;
echo "Installed to $folder"
