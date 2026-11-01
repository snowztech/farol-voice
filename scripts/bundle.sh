#!/usr/bin/env bash
# Builds "build/Farol Voice.app".
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/build/Farol Voice.app"

swift build --package-path "$root" -c release --product FarolVoice

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$root/.build/release/FarolVoice" "$app/Contents/MacOS/FarolVoice"
cp "$root/assets/FarolVoice.icns" "$app/Contents/Resources/"
find "$root/.build/release/" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$app/Contents/Resources/" \;

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>dev.farol.Voice</string>
  <key>CFBundleName</key><string>Farol Voice</string>
  <key>CFBundleExecutable</key><string>FarolVoice</string>
  <key>CFBundleIconFile</key><string>FarolVoice</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>Farol Voice listens while you hold the key, and turns your speech into text on this Mac.</string>
</dict>
</plist>
PLIST

# A real identity keeps macOS's permissions across rebuilds. An ad hoc signature loses them every time.
identity=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -1)
codesign --force --deep --sign "${identity:--}" "$app" >/dev/null
echo "built $app"
