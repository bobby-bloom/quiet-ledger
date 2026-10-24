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
git tag -a v0.2.0 -m v0.2.0
git push --follow-tags
```

`bump build` only increments `BUILD` (re-submitting the same version to a
store) and does not touch the changelog.

## Checks

`dart run tool/version.dart --check` (run in CI) fails if
`lib/core/app_version.dart` is stale or `CHANGELOG.md` has no section for
the current version. On a `v*` tag CI also runs it with `--tag <tag>`, so a
tag that does not match `pubspec.yaml` fails the build.
