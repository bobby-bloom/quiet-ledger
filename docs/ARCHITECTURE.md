# Architecture & conventions

Read this before changing code. `PLAN.md` is the approved product plan; the
design draft ("Quiet Ledger") is mirrored in `docs/design/` (one `.dc.html`
per screen, `Foundations.dc.html` holds the tokens). `docs/BACKUP.md`
describes backups, restore and the data-safety rules below;
`docs/BUDGETS.md` describes how budget lines are calculated.

## Layout

```
lib/
  app/            app widget, bootstrap, router, AdaptiveShell, theme, shared UI
    theme/        tokens.dart (design tokens), app_theme.dart, finance_colors.dart, theme_ext.dart
    ui/           AmountText, SectionCard, ProgressBar, StatusBadge, EmptyState, AsyncView,
                  IconTile, confirmDialog, formatters (money/date providers), breakpoints, AppIcons,
                  pickers.dart (showCategoryPicker/MultiPicker, showAccountPicker/MultiPicker,
                  showAdaptiveSheet, MoneyField)
  core/
    money/        Money (int minor units), MoneyFormatter, money_input.dart (parseAmountInput)
    db/           tables.dart (schema), database.dart (+ .g.dart; syncedTableNames,
                  backupExcludedTables), search.drift (FTS5), sync_writer.dart (THE write
                  path), db_providers.dart, db_files.dart (quarantine, pre-migration
                  copy), connection/
    attachments/  attachment_files.dart (receipt files, relative names), receipt_store.dart
    sync/         hlc.dart
    settings/     setting_def.dart, app_settings.dart (catalogue), settings_controller.dart
    ledger/       txn_draft.dart, ledger_repository.dart, lookups.dart
    calendar/     holidays.dart, recurrence.dart (RRULE expansion), budget_period.dart
    platform/     capabilities.dart
  features/<name>/
    <name>_routes.dart     exported route list (absolute paths)
    data/                  repositories, queries (Drift)
    domain/                pure Dart (no Flutter imports), heavily unit-tested
    presentation/          widgets + Riverpod providers/notifiers
  l10n/parts/<feature>_{en,de}.arb   per-feature strings (merged by tool/l10n.dart)
test/  (mirrors lib/)   test/helpers/test_app.dart   test/fixtures/
```

## Rules

**Money.** Always `int` minor units (cents) in the DB and domain, `Money` for
arithmetic, `Decimal` for rates/percentages. Never `double` for amounts
(doubles are OK only for chart coordinates and progress ratios).
Sign convention: negative = money leaves the account. Display via
`AmountText` or `ref.watch(moneyFormatterProvider)`; minus is U+2212.

**Writes.** Every write to a synced table goes through `SyncWriter`
(`ref.read(syncWriterProvider)`): `insert`, `insertAll`, `update`, `delete`
(soft), `deleteWhere`, `undelete`, `transaction`. Never call
`db.into(...)`, `db.update(...)` or `db.delete(...)` on synced tables yourself.
Build companions with `XCompanion(field: Value(...))`, not
`XCompanion.insert`. Transactions are written only through
`LedgerRepository` (`ledgerRepositoryProvider`), which handles transfers
(two linked legs), splits, tags and custom field values.

**Reads.** Always filter `deletedAt.isNull()`. Use the shared lookups in
`core/ledger/lookups.dart` (`accountsProvider`, `categoriesProvider`,
`tagsProvider`, `accountBalancesProvider`, `categoryMapProvider`, ...).
Aggregations run in SQL (`db.customSelect(..., readsFrom: {...})`) so the
app stays fast with 100k rows. Use `.watch()` streams for reactive UI.

**Dates.** Ledger dates are local midnight (`dateOnly()`); ranges are
half-open `[start, end)` (`DateRange`). Budget periods come from
`BudgetPeriods`, recurrence from `expandRecurrence`, holidays from
`HolidayCalendar`.

**Settings.** All settings are typed `SettingDef`s in
`core/settings/app_settings.dart`. Read: `ref.watch(settingsProvider).get(def)`
(scoped: `get(def, scope: 'account:<id>')`). Write:
`ref.read(settingsProvider.notifier).set(def, value)`. Module toggles:
`settings.moduleEnabled(AppModule.goals)` — hide UI for disabled modules. To
add a setting, add the def to its section class and its `all` list, and the
label to `lib/l10n/parts/settings_{en,de}.arb`.

**State.** Riverpod 3 without code generation: `Provider`, `StreamProvider`,
`FutureProvider`, `NotifierProvider`, `.family`. Import `Override` from
`package:flutter_riverpod/misc.dart`. No freezed: write small immutable
classes by hand (`@immutable`, `copyWith`, `==`). The only code generator is
Drift; do **not** run `build_runner` from a feature agent — the schema is
owned centrally. If you need a schema change, stop and report it.

**Routing.** go_router with a `StatefulShellRoute` (branches: home,
transactions, plan, forecast, accounts, reports, more). Each feature exports
a `List<RouteBase>` of absolute paths in `<feature>_routes.dart`; the
variable names and root paths are fixed (see `app/router.dart`). Drill down
with `context.push(...)`; switch tabs with `context.go(...)`.
Routes under More: `/more/settings`, `/more/categories`, `/more/tags`,
`/more/custom-fields`, `/more/rules`, `/more/import`, `/more/export`,
`/more/templates`.

**Adaptive layout** (`WindowSize.of(context)`): compact < 600 (bottom bar,
full-screen details, bottom sheets), medium 600–839 (rail, list-detail where
useful), expanded ≥ 840 (extended rail, list-detail panes, dialogs, grid
dashboard, hover, context menus, keyboard shortcuts). Never just stretch the
phone UI.

**Design.** Use theme roles (`context.colors`, `context.text`) and
`context.finance` (income/expense/transfer/warning colours) — never hex
literals in feature code. Spacing from `Space`, radii from `Radii`. Cards:
`SectionCard` / `Card` (level 0, hairline border). Expense amounts stay
onSurface with "−"; income uses `finance.income` with "+"; transfers use
`finance.transfer` and no sign (AmountText does this). Budget bars: on
track → primary, ≥ threshold → warningFill, over → error, always with a
text label. Touch targets ≥ 44 px. Icons: Material outlined; stored icon keys
map through `AppIcons`.

**Strings.** No hard-coded user-visible strings. Put them in
`lib/l10n/parts/<feature>_en.arb` and `_de.arb` (both!), keys prefixed with
the feature (`txnSearchHint`, `budgetsTitle`, ...), then run
`dart run tool/l10n.dart` and use `context.l10n.key`. Shared words
(`commonSave`, `commonCancel`, `fieldAmount`, `typeExpense`, ...) already
exist in `core_*.arb` and `settings_*.arb`; do not edit those two files
except to add keys you are sure are generic. The app is EN/DE.

**Lints.** `very_good_analysis`. Before finishing: `dart format` your files
and `dart analyze lib/features/<yours> test/features/<yours>` must report no
errors or warnings.

**Tests.** Domain logic: unit tests with fixtures. Data: Drift in-memory DB
via `newTestDb()` from `test/helpers/test_app.dart`; containers via
`testContainer(db)`; widget tests via `testApp(widget, db: db)`. Run only
your tests: `flutter test test/features/<yours>`.

**Data safety** (`docs/BACKUP.md`). Every table is in `syncedTableNames`
(backed up) or `backupExcludedTables`; a test enforces it. Operations that
replace, merge or hard-delete data run inside
`withSafetyCopy(read, SafetyReason.x, ...)`. Backups that leave the device
are made only by `createVerifiedBackup` (encryption when a password is set, verification)
and opened by `openBackup`. Device-specific settings are marked
`deviceLocal: true` and listed in `allSettings`: they are never synced
(written without a `change_log` entry, skipped by `SyncEngine` both ways)
and a restore keeps them (`deviceLocalSettingKeys`). Migrations are
forward-only; a newer database is refused, never downgraded.

**Startup tasks** (post due recurring entries, auto-export, purge): register
in `app/startup_tasks.dart` (idempotent, never throw).

**Versioning.** `version:` in `pubspec.yaml` is the only source; read it in
Dart via `lib/core/app_version.dart` (generated, never hand-edited). Change
it with `dart run tool/version.dart bump <part>` and note user-visible
changes under "Unreleased" in `CHANGELOG.md`. A `bundleFormatVersion` bump
is a MAJOR release, a `schemaVersion` bump at least MINOR (see
`docs/VERSIONING.md`).

**Platform differences** go through `platformCapabilitiesProvider`
(biometrics, notifications, folders, encryption, ...). On the web there is
no `dart:io`; guard file-system code with conditional imports.
