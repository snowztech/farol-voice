# Releasing

Every release is a signed, notarized DMG and zip on GitHub Releases, so Farol Voice opens on any Mac without warnings.

## Publish a release

1. Move the changes under `## [Unreleased]` in `CHANGELOG.md` into a new section like `## [0.1.0] - 2026-11-01`. Its text becomes the release notes.
2. Commit, then tag and push:

```sh
git tag -a v0.1.0 -m "Farol Voice 0.1.0" && git push origin v0.1.0
```

The tag runs `.github/workflows/release.yml`. It tests, builds, signs, notarizes and publishes the release. Tags with a suffix, like `v0.2.0-beta`, become pre-releases.

## Build a signed release locally

`make dist` builds a signed, notarized DMG and zip. It needs a Developer ID Application certificate in your keychain and a notarytool profile named `farol`, the same one Farol uses:

```sh
xcrun notarytool store-credentials farol --key AuthKey_XXXX.p8 --key-id <Key ID> --issuer <Issuer ID>
```

`NOTARIZE=0 make dist` skips notarizing.

## Repository secrets

The release workflow uses the snowztech organization's secrets, shared with its other apps: `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD`, `NOTARY_KEY`, `NOTARY_KEY_ID` and `NOTARY_ISSUER_ID`. Each one has to list this repository among its selected repositories.

`SPARKLE_PRIVATE_KEY` is this repository's own secret. Farol Voice has its own update key, so don't share the organization's, which belongs to another app.

## Updates

Farol Voice installs its own updates with [Sparkle](https://sparkle-project.org). Each release publishes `appcast.xml` next to the zip, and installed copies read it at `releases/latest/download/appcast.xml`. They only accept an update signed with the private half of `SUPublicEDKey`, and the release fails if its signature doesn't match that key.

The key lives in your Keychain under the account `farol-voice`. Keep a copy of the private key somewhere safe, like a password manager. If it's lost, installed copies refuse every update signed with a new key, and everyone has to download the app again once.

## The site

`site/` is published to GitHub Pages by `.github/workflows/site.yml` when it changes on `main`, and is served at `voice.farol.sh`. Pages needs its source set to GitHub Actions in the repository's settings, and a DNS `CNAME` record from `voice.farol.sh` to `snowztech.github.io`.
