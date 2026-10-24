# Backup & restore

How Quiet Ledger keeps user data from being lost: what a backup contains,
when backups are made, how they are encrypted and checked, and what guards
the operations that replace or delete data. Read this before changing
anything that writes, deletes, migrates or restores data.

Code lives in `lib/features/export/` (backups, restore, safety copies,
encryption), `lib/core/attachments/` (receipt files), `lib/core/db/`
(schema, pre-migration copy, unreadable databases) and
`lib/app/boot_error.dart`.

## Guarantees

Each one has a test; a failing test there means data could be lost.

| # | Guarantee | Test |
|---|---|---|
| 1 | **Lossless round trip.** Backup → restore into an empty database → backup gives byte-identical tables, for every column of every table (including soft-deleted rows, sync columns, blobs and receipt files). | `test/features/export/backup_invariants_test.dart`, `receipts_backup_test.dart` |
| 2 | **Complete coverage.** Every table is either in `syncedTableNames` (backed up) or in `backupExcludedTables`. A new table fails the test until it is classified. | `backup_invariants_test.dart` |
| 3 | **Old backups stay restorable.** A backup from every released version is kept in `test/fixtures/bundles/` and must restore without losing a value. | `backup_invariants_test.dart` |
| 4 | **Write → verify → prune.** A scheduled backup counts only after it has been read back from its folder, decrypted and validated; a file that fails is removed again. Old backups are deleted only after that, never the file just written and never a manual backup. | `backup_reliability_test.dart` |
| 5 | **Copy before destroy.** Restore, reset, import undo, merging categories or tags, restoring a safety copy and purging old tombstones first take a verified safety copy. If the copy fails, the operation does not run. Schema migrations first copy the database file. | `backup_reliability_test.dart`, `test/core/db/db_safety_test.dart` |
| 6 | **No silent failure.** A failed, interrupted or paused scheduled backup, a lost folder permission and a stale last backup are shown on the dashboard and the export screen. Failures also raise a notification once. | `backup_reliability_test.dart`, `backup_ui_test.dart` |
| 7 | **Atomic restore.** A failed restore leaves the database and the receipt files exactly as they were. | `receipts_backup_test.dart` |
| 8 | **Never delete what cannot be read.** A database the app cannot open (missing key, newer schema, damage) is moved aside, never overwritten, deleted or downgraded. | `test/core/db/db_safety_test.dart`, `test/app/boot_error_test.dart` |
| 9 | **Never weaker than the device.** While the app lock or the database encryption is on, no backup leaves the device unencrypted. | `backup_encryption_test.dart` |

## What a backup contains

A **bundle** (`.zip`) holds:

- one CSV per synced table (`<table>.csv`): RFC 4180, comma, UTF-8, header
  = SQL column names, raw SQL values (dates as unix time, bools 0/1, blobs
  base64, null as an unquoted empty field), all rows including tombstones;
- receipt files stored uncompressed as `files/<sha256>`, once per content;
- `manifest.json`: format and schema version, app version, creation time,
  device id, row count and SHA-256 per table, and `files` (attachment id →
  file, size, SHA-256) plus `missingFiles` (receipts whose file was already
  gone when the backup was made).

On the web, receipts live in `attachments.data` and are part of the CSV.
Restoring a native backup on the web moves receipt files into that column;
the other direction keeps the column.

`bundleFormatVersion` is still 1: `files` and `missingFiles` were added in
0.2.0, and older readers ignore unknown manifest keys and zip entries.
Readers reject a higher format or schema version.

Not in a backup: `change_log`, `sync_state` (reset by a restore), the
full-text index (rebuilt), `safety_copies` (on-device only), the database
key, the app-lock credential and the backup keys (secure storage). Settings
that describe the device (`deviceLocalSettingKeys`: backup schedule,
retention, folder and its name, last backup times and errors, password
check, storage location, tombstone purge) keep their current value on
restore, so restoring another device's backup cannot shrink retention and
prune this device's backups.

## Encrypted backups (`.pfbackup`)

```
"PFBK" | version u8 | header length u32 BE | header JSON |
AES-256-GCM(data key, nonce, bundle zip, aad = everything before) | tag
```

- A random 256-bit **data key** per file encrypts the unchanged bundle
  zip. The header (KDF parameters, slots, nonce, time, app version) is
  authenticated, so changing it is detected.
- The data key is wrapped twice with AES-256-GCM: under the **password
  key** (PBKDF2-HMAC-SHA256, 600 000 iterations, 16-byte salt; parameters
  in the header) and under the **recovery key** (HKDF-SHA256 with its own
  salt). Either one opens the file.
- The **recovery key** is 160 random bits shown once as 8 groups of 4
  base32 characters (`ABCD-EFGH-…`). Setup is finished only after the user
  types two random groups back. Input is forgiving: case, spaces, dashes
  and 0/O, 1/I, 8/B are accepted.
- **Changing the password** keeps the recovery key. Older files still open
  with their old password or the recovery key. The device keeps its
  earlier keys, so it opens old files without asking.
- **A new recovery key** keeps the password; older files need the old
  recovery key or their password.
- The device stores only derived keys, never the password or the recovery
  key, in secure storage (`backup.keys`: current plus earlier key sets). So
  scheduled backups run unattended.
- KDF and AES run in a background isolate (`compute`; inline on the web).

**When encryption is used.** If a backup password is set, every backup
that leaves the device is encrypted: manual, scheduled and saved safety
copies. While the app lock or the database encryption is on
(`backupEncryptionRequiredProvider`), a password is **required**. Without
one, backups are refused rather than written plain: scheduled backups
pause, and the banner says "Backups are paused until you set a backup
password." Existing plain backups are not pruned meanwhile, because no new
backup is written. Since the database is encrypted by default wherever
secure storage exists, native users need a backup password for any backup.

**Not losing the key.** The recovery key must be confirmed at setup. Every
30 days the app asks for the backup password once
(`BackupStatus.checkPassword`), so a forgotten password shows up while the
device can still set a new one. A wrong answer offers to set a new password
right away.

## Scheduled backups

Settings: Export & backup › Automatic backup (`/more/export/folder`).

- **When.** Daily or weekly, checked at start, when the app returns to the
  foreground and hourly while it stays open (`BackupScheduler`). After a
  failure it retries on every check instead of waiting for the next day.
  Concurrent runs share one backup.
- **Run** (`runAutoExportNow`): record the attempt → create and verify the
  backup (`createVerifiedBackup`) → write
  `personal-finance-backup-<yyyyMMdd-HHmmss>.zip|.pfbackup` → read it back,
  compare bytes, decrypt and validate (`openBackup`), deleting it again if
  that fails → prune to the newest N, never the new file and never other
  files → record success. Manual backups are named
  `personal-finance-manual-…`, so a manual backup saved into the backup
  folder is never pruned.
- **Folder access.**
  - Linux and Windows: a plain path.
  - Android: a Storage Access Framework tree with a persisted permission
    (`BackupFolderChannel.kt`). It works with local storage and cloud
    providers.
  - iOS and macOS: a security-scoped bookmark (`BackupFolderChannel` in
    `ios/Runner/AppDelegate.swift` and `macos/Runner/MainFlutterWindow.swift`).
    macOS has the user-selected read-write and app-scope bookmark
    entitlements.
  - iOS can also use the app's Documents folder, visible in Files › On My
    iPhone. It is stored as `appdocs:Backups` and resolved on every use,
    because iOS moves the app container on updates.
  - A revoked permission is detected at start and shown as "Choose the
    folder again".
- **Health** (`backupHealth`, shown by `BackupHealthBanner` on the
  dashboard and the export screen). The states, in order: password needed,
  failing (with the error), interrupted (started more than 10 minutes ago,
  never finished), never backed up, stale (last verified backup older than
  `export.backupStaleDays`, default 7), check password, ok. The "last
  verified backup" counts scheduled backups and manual ones that were
  saved, shared or downloaded.
- **Web:** no folder. Manual downloads count as backups for the stale
  warning, and the app asks the browser for persistent storage
  (`navigator.storage.persist()`); the export screen shows whether the
  browser granted it.

## Safety copies

`features/export/data/safety_copies.dart`, screen `/more/export/safety`.

A safety copy is a full bundle **without** receipt files, stored in the
`safety_copies` table of the app database. That way it is encrypted with
the database and works on the web. Receipt files are never deleted by the
guarded operations (restore writes new files and keeps the old ones), so
the copy's rows still find them. Restore and reset leave the table alone.
The newest 10 copies are kept, plus the newest copy taken before a
restore, a reset and restoring a safety copy (`protectedSafetyReasons`),
so later small operations cannot push out the state before the last
restore or reset. When nothing changed since the newest copy (same table
hashes), other operations reuse that copy instead of storing a new one.
Saving a copy elsewhere adds the receipt files from disk
(`withReceiptFiles`), and encrypts it like any backup.

Taken before:
- restoring a backup or another safety copy;
- Reset app (optional, ticked by default; unticking it also deletes the
  safety copies for a real wipe);
- undoing an import;
- merging categories or tags;
- purging tombstones older than `data.tombstoneDays` (weekly at start and
  from Settings › Data, in both cases only when there are any).

Bulk deletes are soft deletes with undo. The rows stay as tombstones until
the purge, which is guarded.

Use `withSafetyCopy(read, SafetyReason.x, () => operation())` for any new
operation that replaces, merges or hard-deletes data. It throws
`SafetyCopyException` and skips the operation when no copy can be taken.

**Before a schema migration**, bootstrap copies the database files
byte-for-byte (an encrypted file stays encrypted with its key) to
`<app support>/safety/pre-migration-v<old>-<time>/`. It keeps the newest 3.
The schema version a device last opened is in shared preferences
(`db.schemaVersion`). The web keeps no pre-migration copy.

## Restore

Export & backup › Restore backup…, or a backup in the folder list on the
automatic-backup screen.

1. Open: plain bundles directly, encrypted ones with the keys on this
   device or the password / recovery key the user types (asked again after
   a wrong one).
2. Validate everything: manifest, versions, checksums, row counts, columns,
   every value, receipt files.
3. Summary:
   - rows, receipts and their size;
   - receipts that were already missing when the backup was made;
   - how many changes on this device are newer than the backup (they are
     replaced, and kept in the safety copy).
4. Optionally save a backup of the current data elsewhere. Then the
   safety copy is taken; without it, nothing is restored.
5. Write receipt files under new names (identical files on the same device
   are reused), then replace all synced tables in one transaction. If the
   transaction fails, the files written in this step are removed and
   nothing else has changed.

**Check a backup** runs steps 1–2 without restoring.

## Database that cannot be opened

When bootstrap fails, `BootErrorApp` explains why (`classifyBootError`):
missing key, a file that is damaged or cannot be unlocked (SQLite
`CORRUPT`/`NOTADB`), newer schema, or other. It says nothing was deleted
and offers **Retry**. Only for the first two, and only on native
platforms, it also offers **Start with an empty database**. A newer schema
asks for an app update; any other error (secure storage, disk full, ...)
may be temporary, so the file is never moved aside for it. Start with an
empty database does the following:

- moves the database files to `<app support>/unreadable/<time>/` (all of
  them are copied and checked before any original is removed);
- keeps their key in secure storage as `db.key.unreadable.<ms>`;
- starts empty, so a backup can be restored.

A database written by a newer schema is refused (`NewerDatabaseException`)
rather than stamped down by Drift.

Android Auto Backup and device transfer are turned off
(`android:allowBackup="false"`, `data_extraction_rules.xml`). The database
key lives in the Keystore, which is never restored, so a restored database
could not be opened. The app's own backups are the supported way to move
data.

## Receipt files

Native receipts are copied to `<app support>/attachments/`.
`attachments.file_path` holds the **file name** there. Versions before
0.2.0 stored an absolute path; those still resolve, also after the app
container moved, by looking up the file name in the current folder. A
startup task (`migrateAttachmentPaths`) rewrites them.

## Rules for contributors

- A new table: add it to `syncedTableNames`, or, after review, to
  `backupExcludedTables`.
- A schema change: keep `onUpgrade` forward-only and add a migration test.
  The pre-migration copy and the downgrade guard are automatic.
- A new destructive operation: wrap it in `withSafetyCopy`.
- A new way to create a backup: go through `createVerifiedBackup`, which
  applies encryption and the policy. Never write `exportBundle` output to
  a user-visible place directly.
- A new device-specific setting: add it to `deviceLocalSettingKeys` or
  `BackupSettings.deviceLocalKeys`.
- Releasing: freeze the backup format with
  `flutter test tool/backup_fixture/backup_fixture_test.dart`
  (`docs/VERSIONING.md`).

## Limits

- Bundles are built in memory. Very large receipt collections (hundreds of
  MB) need that much free memory on the device. If a run dies, it shows as
  "did not finish".
- The iOS and macOS folder channels and the macOS entitlements have not
  been compiled or tested in this repository's environment. The Android
  channel compiles but needs a test on real devices with local and cloud
  folders.
- The web keeps no pre-migration copy. Its safety copies live in the same
  browser storage as the data.
