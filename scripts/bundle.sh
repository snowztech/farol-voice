#!/usr/bin/env bash
# Builds "build/Farol Voice.app". UPDATES=1 adds the update feed, which only releases have.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/build/Farol Voice.app"
# Dev builds get their own identity. macOS ties permissions to an app's id and signature, so a dev build sharing the release's id takes its permissions away.
if [ "${UPDATES:-0}" = "1" ]; then
  bundle_id="dev.farol.Voice"
  name="Farol Voice"
else
  bundle_id="dev.farol.Voice.debug"
  name="Farol Voice Dev"
fi

# Version from the latest v* tag. Builds after a tag read like 0.1.0-3-gabc1234, and -dirty marks uncommitted changes.
described=$(git -C "$root" describe --tags --match 'v[0-9]*' --dirty 2>/dev/null || echo "v0.0.0-dev")
version="${described#v}"
# macOS wants plain numbers in the short version, so the full string gets its own key.
short_version="${version%%-*}"
build_number=$(git -C "$root" rev-list --count HEAD 2>/dev/null || echo 0)

swift build --package-path "$root" -c release --product FarolVoice

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp "$root/.build/release/FarolVoice" "$app/Contents/MacOS/FarolVoice"
cp "$root/assets/FarolVoice.icns" "$app/Contents/Resources/"
cp "$root/THIRD_PARTY_NOTICES" "$root/LICENSE" "$app/Contents/Resources/"
find "$root/.build/release/" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$app/Contents/Resources/" \;

# Sparkle installs updates. Its XPC services are only for sandboxed apps, which this isn't.
sparkle="$app/Contents/Frameworks/Sparkle.framework"
ditto "$root/.build/release/Sparkle.framework" "$sparkle"
rm -rf "$sparkle/XPCServices" "$sparkle/Versions/B/XPCServices"
install_name_tool -add_rpath @executable_path/../Frameworks "$app/Contents/MacOS/FarolVoice"

feed=""
if [ "${UPDATES:-0}" = "1" ]; then
  feed="<key>SUFeedURL</key><string>https://github.com/snowztech/farol-voice/releases/latest/download/appcast.xml</string>
  <key>SUPublicEDKey</key><string>dM34MTvAy3WD6i7iUg5jEyQH6CKH8BhBJw0pMZeq8l4=</string>
  <key>SUEnableAutomaticChecks</key><true/>"
fi

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$bundle_id</string>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundleExecutable</key><string>FarolVoice</string>
  <key>CFBundleIconFile</key><string>FarolVoice</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$short_version</string>
  <key>CFBundleVersion</key><string>$build_number</string>
  <key>FarolVoiceVersion</key><string>$version</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>Farol Voice listens while you hold the key, and turns your speech into text on this Mac.</string>
  $feed
</dict>
</plist>
PLIST

# A real identity keeps macOS's permissions across rebuilds. An ad hoc signature loses them every time.
identity=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -1)
codesign --force --deep --sign "${identity:--}" "$app" >/dev/null
echo "built $app ($version)"
