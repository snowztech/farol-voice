#!/usr/bin/env bash
# Builds a signed, notarized build/FarolVoice-<version>.dmg and .zip that open on any Mac without warnings.
# Needs a Developer ID Application certificate and a notarytool profile named farol (see RELEASING.md).
# NOTARIZE=0 signs without notarizing.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
profile="${NOTARY_PROFILE:-farol}"
identity="${DEVELOPER_ID:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)}"
[ -n "$identity" ] || { echo "No Developer ID Application certificate in the keychain." >&2; exit 1; }

UPDATES=1 "$root/scripts/bundle.sh"
app="$root/build/Farol Voice.app"
version=$(defaults read "$app/Contents/Info.plist" FarolVoiceVersion)
zip="$root/build/FarolVoice-$version.zip"
dmg="$root/build/FarolVoice-$version.dmg"

# Inside out: Sparkle's own programs first, without the app's entitlements, then the app that contains them.
sign_plain() {
  codesign --force --timestamp --options runtime --sign "$identity" "$1"
}
sparkle="$app/Contents/Frameworks/Sparkle.framework"
sign_plain "$sparkle/Versions/B/Autoupdate"
sign_plain "$sparkle/Versions/B/Updater.app"
sign_plain "$sparkle"
codesign --force --timestamp --options runtime --entitlements "$root/assets/FarolVoice.entitlements" --sign "$identity" "$app"
codesign --verify --strict --deep "$app"
echo "signed with $identity"

# Locally the key lives in a keychain profile. CI passes the key file instead.
notarize() {
  if [ -n "${NOTARY_KEY_PATH:-}" ]; then
    xcrun notarytool submit "$1" --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" --wait
  else
    xcrun notarytool submit "$1" --keychain-profile "$profile" --wait
  fi
}

# The drag-to-Applications window: the app next to a link to /Applications.
make_dmg() {
  local staging
  staging=$(mktemp -d)
  cp -R "$app" "$staging/"
  ln -s /Applications "$staging/Applications"
  # Window size and icon positions. Finder matches it by item name.
  if [ -f "$root/assets/dmg.DS_Store" ]; then cp "$root/assets/dmg.DS_Store" "$staging/.DS_Store"; fi
  rm -f "$dmg"
  hdiutil create -quiet -volname "Farol Voice" -srcfolder "$staging" -ov -format UDZO "$dmg"
  rm -rf "$staging"
  codesign --force --timestamp --sign "$identity" "$dmg"
}

if [ "${NOTARIZE:-1}" = "0" ]; then
  rm -f "$zip"
  ditto -c -k --keepParent "$app" "$zip"
  make_dmg
  echo "built $zip and $dmg (signed, not notarized)"
  exit 0
fi

# The app first, so its ticket is stapled before it goes into the zip and the disk image.
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
notarize "$zip"
xcrun stapler staple "$app"
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"

make_dmg
notarize "$dmg"
xcrun stapler staple "$dmg"

spctl --assess --type execute --verbose "$app"
spctl --assess --type open --context context:primary-signature --verbose "$dmg"
echo "built $zip and $dmg (signed and notarized)"
