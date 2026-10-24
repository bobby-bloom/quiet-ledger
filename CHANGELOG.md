# Changelog

All notable changes to Quiet Ledger are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the app uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) as defined in
[`docs/VERSIONING.md`](docs/VERSIONING.md).

Add notes under **Unreleased** as you work (Added / Changed / Fixed /
Removed / Security); `dart run tool/version.dart bump <part>` moves them into
a dated release section.

## [Unreleased]

## [0.1.0] - 2026-10-24

First feature-complete build of the PLAN.md v1 scope (M0–M6). Pre-1.0: data
formats may still change before 1.0.0.

### Added

- Accounts, categories, tags, custom fields and transactions (transfers,
  splits, templates, quick add, saved filters, swipe actions).
- Rules engine for auto-categorisation.
- CSV / Excel import with column mapping; CSV and backup-bundle export,
  restore and scheduled auto-export.
- Budgets, recurring entries, goals, plan, forecast and scenarios.
- Reports and dashboard.
- Settings catalogue with search, EN/DE localisation, onboarding.
- App lock (biometric / PIN) and encrypted database on native and web.
- Adaptive layout for phone, tablet and desktop on Android, iOS, web,
  Windows, macOS and Linux.

### Known limitations

- Web DB encryption not yet verified in a real browser.
- Android auto-export to a picked folder may need a Storage Access Framework
  writer.
- Linux cannot schedule notifications.
- iOS, macOS and Windows builds not yet compiled outside CI.
