# Changelog

All notable changes to Quiet Ledger are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the app uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) as defined in
[`docs/VERSIONING.md`](docs/VERSIONING.md).

Add notes under **Unreleased** as you work (Added / Changed / Fixed /
Removed / Security); `dart run tool/version.dart bump <part>` moves them into
a dated release section.

## [Unreleased]

### Added

- Backups include receipt files.
- Encrypted backups (`.pfbackup`) with a backup password and a recovery key
  that must be confirmed. Required while the app lock or the database
  encryption is on; the app asks for the password once a month.
- Safety copies, taken automatically before restoring, resetting, undoing
  an import, merging categories or tags and purging old deleted entries.
  They can be restored from Export & backup › Safety copies. The copy from
  before the last restore or reset is always kept.
- A copy of the database file before every schema migration.
- Scheduled backups to folders picked on Android (Storage Access
  Framework), iOS and macOS (security-scoped bookmarks), including cloud
  providers; on iOS also the app's folder in Files.
- Warnings on the dashboard and the export screen when a backup failed,
  did not finish, is paused or is older than a set number of days; a
  notification when a scheduled backup fails.
- List of the backups in the backup folder with restore and "Check a
  backup".
- The restore summary shows how many newer changes it would replace.
- If the database cannot be opened, the app explains why. When the file
  itself is unreadable, it can start empty while keeping the old file.

### Changed

- Scheduled backups are read back and verified before old ones are
  pruned, retried after a failure (after 1, 4 and 12 hours, then daily)
  and checked while the app stays open.
- Settings that describe this device (backup folder, schedule and status,
  storage location) are kept by a restore and never synced.
- Receipt paths are stored relative to the app's folder.
- Android Auto Backup and device transfer are off, because a restored
  database could not be opened without its key.
- The web app asks the browser to keep its storage.

### Fixed

- Restoring a backup over existing transactions failed.
- A scheduled backup to a folder on a drive that was not connected
  recreated the folder on the system disk; it is now reported instead.
- A newer database file could be stamped down to an older schema version.
- macOS: added the sandbox entitlements for user-selected files and
  bookmarks, which saving a backup and backing up to a picked folder need.

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
