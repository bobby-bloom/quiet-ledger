# Versioning

Quiet Ledger uses [Semantic Versioning 2.0](https://semver.org/) in the form
`MAJOR.MINOR.PATCH+BUILD`.

## Source of truth

`version:` in `pubspec.yaml` is the only place the version lives. Flutter
passes it to every platform (Android `versionName`/`versionCode`, iOS and
macOS `CFBundleShortVersionString`/`CFBundleVersion`, Windows and Linux
runners, web `version.json`). Dart code reads the generated
`lib/core/app_version.dart` (`appVersion`, `appVersionName`,
`appBuildNumber`). Never edit either by hand; use `tool/version.dart`.

Pre-release suffixes (`-rc.1`) are not used: the App Store rejects them in
`CFBundleShortVersionString`. Test builds use a higher `BUILD` instead.

## What the numbers mean

An app has no code API, so the "public API" here is **the user's data**: the
database, backup bundles and export files, and the features people rely on.

| Bump | When | Examples |
|---|---|---|
| **MAJOR** | Data from the previous major can no longer be used without a manual step, or a feature/platform is removed | `bundleFormatVersion` bump, dropping an old Drift migration path, CSV export columns renamed/removed, a platform dropped |
| **MINOR** | Backwards-compatible additions | New feature, screen or setting; new import format; forward-only Drift migration (`schemaVersion` bump); new CSV export column at the end |
| **PATCH** | No new behaviour, no schema change | Bug fixes, translations, performance, UI polish |
| **BUILD** | Every build that is distributed | +1 on every bump, never reset (stores require a strictly increasing `versionCode`/`CFBundleVersion`) |

A `schemaVersion` bump is MINOR: newer apps migrate older databases and
restore older bundles. Downgrades are not supported (an older app rejects a
bundle with a newer schema), which SemVer allows.

While on `0.x` the data formats may still change in a MINOR release. `1.0.0`
is the first release after the M2 acceptance check against the owner's real
spreadsheet and the open items in the README's known limitations.

## Releasing

```sh
# 1. Notes are already under "## [Unreleased]" in CHANGELOG.md.
dart run tool/version.dart bump minor     # or major / patch / build
# 2. Review pubspec.yaml, lib/core/app_version.dart, CHANGELOG.md.
git commit -am "Release 0.2.0"
git push                                  # or merge the PR; the tag must be on main
git tag -a v0.2.0 -m v0.2.0
git push origin v0.2.0
```

Pushing the tag starts the [Release workflow](../.github/workflows/release.yml).
It checks that the tagged commit is on `main`, runs the full CI on it
(including the tag/`pubspec.yaml` match), builds the platforms and publishes
a GitHub release with the version's CHANGELOG section as notes:

| Platform | File |
|---|---|
| `android` | `quiet-ledger-X.Y.Z-android.apk` (sideload) |
| `linux` | `quiet-ledger-X.Y.Z-linux-x64.tar.gz` |
| `windows` | `quiet-ledger-X.Y.Z-windows-x64.zip`, VC++ runtime included |
| `macos` | `quiet-ledger-X.Y.Z-macos.zip`, unsigned (right-click › Open) |
| `web` | `quiet-ledger-X.Y.Z-web.zip`, static files |

plus `SHA256SUMS.txt`. iOS is not released: it needs an Apple Developer
account and signing.

### Choosing platforms

- **Tag push:** builds the platforms in the repository variable
  `RELEASE_PLATFORMS` (Settings › Secrets and variables › Actions ›
  Variables), e.g. `android,linux`. Unset means all five.
- **Manual run:** Actions › Release › Run workflow, enter an existing tag and
  tick the platforms. If that release is already published, the new builds
  are added to it (same-named files are replaced, checksums merged), e.g. to
  add macOS later or rebuild a broken file. A draft left by a failed run is
  replaced.

`bump build` only increments `BUILD` (re-submitting the same version to a
store) and does not touch the changelog.

### Android signing key

Release APKs must always be signed with the same key, or Android refuses to
install an update over an earlier version. Create the key once and keep a
backup outside the repository; losing it means users must uninstall to
update.

```sh
keytool -genkeypair -v -keystore quiet-ledger-release.jks -alias upload \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 quiet-ledger-release.jks   # value for ANDROID_KEYSTORE_BASE64
```

Add these repository secrets (Settings › Secrets and variables › Actions):
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`
(`upload`) and `ANDROID_KEY_PASSWORD`. Without them the workflow warns and
signs with a throwaway debug key. For a local signed build, put the same
values in `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`,
`keyPassword`; git-ignored).

## Checks

`dart run tool/version.dart --check` (run in CI) fails if
`lib/core/app_version.dart` is stale or `CHANGELOG.md` has no section for
the current version. The Release workflow runs CI with the tag, which adds
`--tag <tag>`, so a tag that does not match `pubspec.yaml` fails the release.
