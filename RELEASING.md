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

The release workflow uses the snowztech organization's secrets, shared with the Farol apps: `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD`, `NOTARY_KEY`, `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID` and `SPARKLE_PRIVATE_KEY`. Each one has to list this repository among its selected repositories.

## Updates

Farol Voice installs its own updates with [Sparkle](https://sparkle-project.org). Each release publishes `appcast.xml` next to the zip, and installed copies read it at `releases/latest/download/appcast.xml`. They only accept an update signed with the private half of `SUPublicEDKey`, which is Farol's key. If it's lost, everyone has to download the app again once.

## The site

`site/` is published to GitHub Pages by `.github/workflows/site.yml` when it changes on `main`, and is served at `voice.farol.sh`. Pages needs its source set to GitHub Actions in the repository's settings, and a DNS `CNAME` record from `voice.farol.sh` to `snowztech.github.io`.
