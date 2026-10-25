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

- The dashboard's backup reminder (never backed up, last backup too old,
  check the password) has an × that hides it for a week or until the next
  backup. A failed backup still shows until it is fixed.
- Arranging the dashboard: whole rows can be dragged by their toolbar,
  with their widgets; a line shows where the row will land.
- Dashboard layout: wide windows show the widgets in rows of columns
  without the gaps of the old grid. The new dashboard layout menu picks
  Auto (the app's arrangement), one to three columns or your own layout,
  and "Arrange widgets…" lets you drag widgets, move them with a menu,
  split rows and add rows in place. Phones get an editor sheet with ▲ ▼,
  Remove and Add. The layouts sync and are backed up; a narrower window
  shows your layout folded to fit. See `docs/DASHBOARD.md`.
- Dashboard widgets fold with a chevron and show one summary line while
  folded; Expand all / Collapse all in the layout menu. Folding is
  remembered on this device only.
- Lists on the dashboard (budgets, upcoming, goals, top categories, recent
  transactions, accounts) offer Rows 3 · 5 · 10 in their menu.
- Removing a dashboard widget can be undone, and it keeps its settings and
  its place for when it is added back.
- An app icon of its own, a tick over a double rule, in your accent
  colour: in the app, on the window, taskbar and Dock while the app runs
  (Linux, Windows, macOS), as the web app's tab icon, and as the tint of
  Android notifications. On Android and iOS the home-screen icon switches
  to the preset closest to the accent (Settings › Appearance › App icon in
  accent colour; iOS confirms each change). Installer and file icons stay
  in the default spruce.
- Budgets show planned entries and recurring items that are not booked
  yet as outstanding: a striped part of the bar, "€80 planned" or
  "Planned: €30 over" on the row, the planned total on the summary card
  and an "Outstanding" list with Confirm and Skip on the budget's detail
  screen. They never
  count as spent, so alerts, rollover and "left to assign" are unchanged.
  Settings › Budgets › Show planned and upcoming turns this off.
- Repeating budgets: a budget can repeat every period, every n-th period,
  for a number of periods or until a date, so new periods no longer
  start empty. New budgets repeat every period by default. Changing or
  removing a repeating budget asks whether it applies to this period only
  or to this and the following periods; budgets set by hand in a period
  always win. "Repeat these budgets every period" in the Fill menu turns
  a period's budgets into repeating ones. Database schema 4.
- Budgets with their own length: a budget can last a week, month, quarter
  or year instead of the budget period, e.g. a yearly holiday budget or a
  weekly groceries budget on a monthly board. The board shows the window
  containing today with its own bar; the detail screen lists every window
  of the period and the last windows' history. Totals stay for budgets of
  the period; in envelope mode and the forecast a long window's amount is
  spread evenly over the budget periods it covers.
- Merging categories with repeating budgets: budgets of the same period
  are added up; the target's repeating budgets stay, and the source's
  take over when they end.
- Backups include receipt files.
- Encrypted backups (`.pfbackup`) with an optional backup password and a
  recovery key that must be confirmed; the app asks for the password once
  a month. Without a password, backups are not encrypted and the app says
  so.
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

- Wide windows: the long-term projection's assumptions panel can be hidden
  from the app bar, like the forecast's side panel. Plan's budgets,
  recurring items and goals and the bills calendar's day list open in a
  side panel only once you pick an entry (or a day), and its × closes it;
  until then the list or calendar takes the whole width.
- Dashboard widget links ("All budgets", "Calendar", "View all") moved
  from the card header to the bottom of the card.
- Scheduled backups are read back and verified before old ones are
  pruned, retried after a failure (after 1, 4 and 12 hours, then daily)
  and checked while the app stays open.
- Settings that describe this device (backup folder, schedule and status,
  storage location) are kept by a restore and never synced.
- Receipt paths are stored relative to the app's folder.
- Android Auto Backup and device transfer are off, because a restored
  database could not be opened without its key.
- The web app asks the browser to keep its storage.
- Dashboard: "Edit dashboard" is an icon button on wide screens; phones
  get an "Edit dashboard" button too.
- Desktop sidebar shows only the tabs chosen in Navigation & modules plus
  More; Settings and Import are reached through More.
- Forecast: up to 5 scenarios can be compared at once (was 3).
- Forecast: the balances table keeps its columns readable and scrolls
  sideways on every screen size; phones now show every compared scenario
  and the combined column too.
- Forecast: on wide screens the side panel (scenarios, "Can I afford
  it?", warnings, big events) can be hidden from the app bar; the choice
  is remembered on this device.
- Desktop sidebar can be collapsed to icons with the button at its
  bottom; the choice is remembered on this device.
- Plan › Budgets adds a budget with the + in the header, like Recurring
  and Goals, instead of a button below the list.
- Accounts on wide screens offer Reconcile once, as the button in the
  account's pane, instead of also in the app bar and the pane's header.

### Removed

- The separate dashboard editor screen, "Make wide" and Settings ›
  Dashboard widgets; the dashboard layout menu replaces them.
- The "New transaction" buttons in the Home and Transactions headers on
  wide screens; the sidebar's "Add transaction" button and Ctrl/Cmd+N do
  the same.

### Fixed

- Plan › Recurring: the amounts in the list of rules are as large as in
  the due items and transaction rows instead of tiny.
- Arranging the dashboard: dragging a widget into an empty column no
  longer makes the row flicker.
- Dashboard card titles sit where they did before folding came, instead
  of 2 px lower.
- Privacy mode now also hides the amounts in the dashboard's budget rows
  ("of €…", "€… over") and goals ("saved / target"), the running balance
  under a transaction, and the amounts screen readers read out for
  transactions.
- The app is called Quiet Ledger everywhere: on the Android and iOS home
  screen, in the macOS menu bar and the released `Quiet Ledger.app`, in
  the Linux and Windows window titles, the Windows task manager and the
  web app's title and install name (some still said `personal_finance`
  or "Personal Finance"). Data stays where it is. New backup files are
  named `quiet-ledger-backup-…` (manual: `quiet-ledger-manual-…`); older
  `personal-finance-backup-…` files are still listed for restore and
  cleaned up as before.
- The program in the Linux and Windows downloads is called `quiet-ledger`
  (`quiet-ledger.exe`) instead of `personal_finance`. Shortcuts or pinned
  taskbar entries to the old file need to be made again; data, settings
  and the database key are found as before.
- The app bar's last button lines up with the page margin on every
  screen instead of sitting at the window edge (or wherever each screen
  put its own spacer); the phone headers of Home and Transactions match.
- Restoring a backup over existing transactions failed.
- A scheduled backup to a folder on a drive that was not connected
  recreated the folder on the system disk; it is now reported instead.
- A newer database file could be stamped down to an older schema version.
- macOS: added the sandbox entitlements for user-selected files and
  bookmarks, which saving a backup and backing up to a picked folder need.
- Dashboard: recent transaction rows were indented more than the rows of
  other cards.
- Desktop sidebar showed Accounts and Reports even when they were not
  chosen as tabs.

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
