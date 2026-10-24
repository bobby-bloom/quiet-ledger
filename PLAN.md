# Personal Finance App — Project Plan

A local-first Flutter app to **track**, **record**, **plan** and **project** personal finances,
replacing the current Excel sheet in which every money movement is logged.

_Status: draft v2 · 2026-10-23 · Flutter 3.47 (stable) / Dart 3.x_

### Decisions (owner, 2026-10-23)
| # | Topic | Decision |
|---|---|---|
| 1 | Platforms | **All Flutter targets**: Android, iOS, Web, Windows, macOS, Linux |
| 2 | Excel import | As extensive as possible (see §2.5) |
| 3 | Currency | **EUR only in v1**. The schema stays currency-aware so multi-currency can come later. |
| 4 | Sync | Build the **base structure** for sync now (IDs, change tracking, adapter interface, §4.3). v1 ships **CSV export only**. |
| 5 | Budget period | **Configurable**: start day, salary-based start, weekend handling (§2.3) |
| 6 | Configurability | **Highly configurable**: every option that could plausibly be wanted becomes a setting (§2.7) |

---

## 1. Goals & principles

| Pillar | What it means in the app |
|---|---|
| **Record** | Logging a movement takes under 5 seconds. Transfers, splits, tags, notes, receipts and custom fields are supported. |
| **Track** | Every account balance, the total net worth and where money goes, all visible at a glance. |
| **Plan** | Budgets per category, recurring bills and income, savings goals. |
| **Project** | A day-by-day cash-flow forecast for the coming months, a net-worth projection for the coming years, and "what if" scenarios. |

Principles
- **Local-first & private**: all data lives on the device in an encrypted SQLite DB. The app needs no account, sends no telemetry and has no cloud dependency.
- **Runs everywhere, adapts its layout**: phone, tablet, desktop and browser each get a layout that fits the screen, not a stretched phone UI.
- **Excel migration path**: importing the existing sheet comes early, and CSV export is always available, so the user is never locked in.
- **Correct money math**: amounts are stored as integer minor units (cents) and never as `double`.
- **Configurable, not complicated**: sensible defaults mean the app is useful without opening Settings. Every behaviour that a reasonable user might want differently is a setting, and Settings has a search.
- **Projection = history + plan**: forecasts are built from data the user already entered. They are never typed in separately.
- **Sync-ready from day one**: the data model and write path already record what sync will need, so adding it later does not require a migration rewrite.

Non-goals for v1: actual sync, bank connections (PSD2/FinTS), multi-currency, multi-user, investment-lot tracking, taxes, xlsx export.

---

## 2. Feature scope

### 2.1 Record (transactions)
- **Quick add** (FAB on mobile; `Ctrl/Cmd+N` and a toolbar button on desktop/web):
  - The flow is amount keypad, then category (recent/favourites on top), then account, then date, then an optional payee/note.
  - The keypad works as a **calculator** (`12.50+3.20`).
  - The field order, which fields are required, and the default account, type and date are all configurable.
- Transaction types: **expense**, **income**, **transfer** (two linked legs, excluded from income/expense reports).
- **Split transactions** across several categories.
- **Tags**, **custom fields** (user-defined: text, number, date, single/multi-select, checkbox) and **receipt attachments**. Custom fields are also targets when importing extra Excel columns.
- **Status**: `cleared` / `pending` / `planned`.
- **Auto-categorisation rules**:
  - A rule has the form "if payee/note contains or matches a regex, or the amount is in a range, then set category, tags or custom fields".
  - Rules apply on entry and on import, and can be re-run on existing transactions.
- **Payee autocomplete** learns category and account from history (can be switched off).
- **Transaction list**:
  - Grouping (day/week/month/none), sort order, an optional running-balance column and visible columns are configurable.
  - Full-text search and filters (account, category, tag, custom field, amount range, date range, type, status).
  - Saved filters ("smart lists").
  - Swipe actions on touch and a context menu / keyboard on desktop.
  - Multi-select bulk edit, and undo.
- **Duplicate** a transaction and **templates** (favourite transactions for one-tap entry).

### 2.2 Track (accounts & insights)
- **Account types**:
  - checking, savings, cash, credit card, investment, loan/debt, other asset/liability
  - Each account has an opening balance, colour, icon, group, an "include in net worth/budgets/forecast" flag and a low-balance threshold, and can be archived.
- **Balance reconciliation**: the user enters the real bank balance and the app creates a correction entry, or flags transactions that are not yet cleared.
- **Dashboard made of configurable widgets**: users add, remove, reorder and resize them, and on desktop they lay out in a grid. Available widgets:
  - net worth
  - month summary / savings rate
  - budget progress
  - upcoming bills
  - mini forecast (lowest point)
  - account list
  - goal progress
  - top categories
  - recent transactions
- **Reports**:
  - spending by category (donut, with drill-down)
  - income vs expense per period
  - net worth over time
  - category trend
  - top payees
  - period comparison
  - cash-flow Sankey (phase 2)
  - Every report can be filtered by period, account, tag and custom field, and can be exported to CSV.

### 2.3 Plan
- **Budget periods (configurable)**:
  - period type: monthly (default), weekly, bi-weekly, quarterly, yearly
  - **start day** of the month (1–28 or "last day")
  - **salary-based start**: the period starts on the date a chosen recurring income actually lands
  - weekend/holiday handling: move to the previous or next business day, using a country-specific holiday calendar (Germany by default)
- **Budgets**: an amount per category per period, with options for:
  - **rollover** of leftover and/or overspent amounts (configurable per category)
  - **budget mode**:
    - *tracking*: a simple limit per category
    - *envelope / zero-based*: every euro of income gets assigned to a category
  - **warning thresholds**: 80 % by default, configurable globally and per category
  - filling a period by copying the previous one, starting from the N-period average, or using a template
  - **outstanding** amounts: planned entries and recurring items not posted yet are shown in each budget, marked as not spent (`docs/BUDGETS.md`)
  - **repeating budgets**: set a budget once for this period only, every (n-th) period, a number of periods or until a date; changes apply to this period only or to this and the following periods
- **Recurring rules**:
  - Recurrence is stored as an iCal RRULE (any frequency, "last business day", "every 3 months on the 15th").
  - Each rule has start/end dates or a number of occurrences, a template transaction (including splits/tags), and *auto-post* or *remind & confirm*.
  - The reminder lead time and notification time are configurable.
  - Rules can change their amount from a given date (e.g. a rent increase), so history stays correct.
- **Bills calendar**: a month view of upcoming recurring items.
- **Savings goals**:
  - a target amount and date, optionally linked to an account
  - the app shows the required contribution per period and the date the goal will be reached at the current pace
  - goals can be prioritised

### 2.4 Project (forecast & scenarios)
- **Cash-flow forecast**:
  - The horizon is configurable from 1 to 36 months, at daily resolution.
  - Inputs:
    - start = current balances
    - \+ expanded recurring rules
    - \+ expected variable spending per category, using a configurable method: the budget, or the trailing 3, 6 or 12-month mean or median
    - \+ goal contributions
  - Pending and planned entries can be included or excluded.
  - Output:
    - a balance curve per account and in total
    - the **lowest point**
    - warnings below 0 or below the account's threshold
    - the balance at the end of each period
- **Net-worth projection (1–40 years)**:
  - an expected return per account and loan interest
  - a savings rate taken from history or the plan
  - an inflation rate (configurable, nominal/real toggle)
  - milestone markers
- **Scenarios**: named sets of adjustments laid over the baseline:
  - a one-off event
  - a percentage or absolute change from a date
  - adding or ending a recurring item
  - changed return or inflation assumptions
  - Up to 3 scenarios can be compared against the baseline. Scenarios can be duplicated.
- **Uncertainty band** (phase 2): p10–p90 based on the historical variance of variable categories.

### 2.5 Import (Excel migration, as extensive as possible)
**Formats**
- `.xlsx`, `.xlsm` and legacy `.xls` via `excel_plus`.
- `.csv` and `.tsv` with **auto-detection** of the delimiter (`,` `;` tab `|`), quote character, **encoding** (UTF-8 with or without BOM, Windows-1252, ISO-8859-1/15) and line endings.
- `.ods`: users are asked to re-save it as xlsx (no maintained ODS reader exists), and the app explains this in the wizard.
- Clipboard paste: rows copied straight from Excel arrive as tab-separated text.

**Wizard steps**
1. **Source**: file or paste. Multiple files can be imported in one batch.
2. **Sheets**: choose one or several sheets. Each sheet can map to a fixed account, or the account can come from a column. The sheet name can supply the year or account (e.g. sheets named "2023" and "2024").
3. **Structure detection**:
   - finds the header row (it may not be row 1), and handles multi-row and merged headers
   - skips title/empty rows
   - **row filters** that skip subtotal and sum rows (e.g. a text pattern such as "Summe", "Total", or rows without a date)
   - reads **formula cells by their cached value**
4. **Column mapping**:
   - Target fields: date, value date, amount, payee, description/note, category, subcategory, account, tags, status, any custom field, or *ignore*.
   - **Amount variants**: one signed column; separate debit/credit columns; an amount plus a type column (e.g. "Einnahme/Ausgabe", "S/H", "+/-"); or negatives written in parentheses `(12,50)`.
   - **Category variants**: separate category and subcategory columns, or a single column with a separator ("Food > Groceries", "Food:Groceries").
   - **Tags** come from a column with a configurable separator.
5. **Formats**:
   - Dates: Excel serial numbers, `dd.MM.yyyy`, `dd.MM.yy`, ISO, `MM/dd/yyyy` and text month names in DE/EN. The format is detected automatically and can be overridden.
   - Numbers: `1.234,56`, `1,234.56` and `1 234,56`, with or without a currency symbol.
   - Every value that fails to parse is highlighted in the preview.
6. **Running-balance column (optional)**: if the sheet has a balance column, the import **checks the result against it row by row**, uses it to set the opening balance, and reports any mismatches.
7. **Category and account mapping**: each distinct value from the sheet maps to an existing category or account, or creates a new one (with the hierarchy). Fuzzy matching suggests matches.
8. **Transfer detection**: pairs a debit in account A with a credit of the same amount in account B within ±N days, and offers to merge them into a transfer.
9. **Auto-categorisation**: rules (§2.1) run for rows that have no category.
10. **Duplicates**: a hash of date, amount and normalised payee/note, with a choice per row or for all rows. **Incremental re-import** imports only the rows added since the last import of the same file or profile.
11. **Dry run and summary**: counts per account and category, the resulting balances, and warnings. The commit runs as one DB transaction.
- **Import profiles** store every choice above for one-click re-import. They can be exported and imported as JSON.
- **Import history**: every batch is listed with its source file, can be **undone completely**, and links to the rows it created.

### 2.6 Export & data
- **CSV export (v1)**:
  - transactions, either flat or one file per account
  - all entities (accounts, categories, budgets, rules, goals, settings) as a **zip bundle of CSVs plus a manifest**, which also serves as a full backup
  - per-report CSV
  - Delimiter, encoding, date format, decimal separator and column selection are configurable, and the app remembers presets.
- **Restore** works from the app's own CSV bundle.
- **Scheduled auto-export**: a CSV bundle written to a chosen folder (daily or weekly, keeping the last N). On desktop and mobile this can be a folder that a cloud client syncs.
- **Later**: xlsx export, an encrypted backup format, and real sync (§4.3).

### 2.7 Settings (high configurability)
Settings live in a **typed schema**, so each setting has a key, type, default, scope and validation. The settings screen has **search**, a **reset per section**, and **export/import** (part of the CSV bundle).

| Section | Options |
|---|---|
| **General** | Language (EN/DE), number & date format (locale-based or custom), first day of week, fiscal-year start, start screen |
| **Appearance** | Theme light/dark/system, accent colour/scheme (presets + custom), Material You dynamic colour (Android/desktop), high-contrast mode, text scale, density (compact/comfortable), income/expense colour style (colour-coded / neutral / +/− only), show cents, sign style (`-12,50` / `(12,50)` / `12,50 −`) |
| **Privacy** | Hide amounts (blur until tapped), privacy mode on start, hide content in app switcher, block screenshots (Android) |
| **Navigation & modules** | Choose and order the bottom-nav/rail tabs; **switch off whole modules** (Goals, Forecast, Scenarios, Budgets, Tags, Custom fields, Attachments) |
| **Dashboard** | Widget selection, order and size; per-widget options (period, accounts) |
| **Entry** | Quick-add field order and required fields, default account/type/date, calculator keypad, number of recent categories, payee suggestions on/off, confirm before delete |
| **Transactions** | Grouping, sorting, running balance, visible columns, default filter |
| **Categories & tags** | Hierarchy (2 levels), icons, colours, archive, merge, reorder, default category set (EN/DE) |
| **Budgets** | Period type, start day, salary-based start, weekend/holiday shift and holiday country, budget mode, default rollover, warning thresholds, which accounts count toward budgets |
| **Recurring & reminders** | Default posting mode, reminder lead time, notification time, quiet hours, per-type notification toggles |
| **Forecast & projection** | Default horizon, variable-spending method, include pending/planned, low-balance thresholds, inflation rate, default returns |
| **Reports** | Default period, excluded categories/accounts/tags (e.g. exclude one-offs) |
| **Security** | App lock on/off, method (biometric/PIN/password), lock timeout, lock on start |
| **Import / export** | Profiles, CSV presets, auto-export schedule & folder, retention |
| **Data** | Storage location (desktop), DB statistics, re-run rules, rebuild search index, reset app |
| **Sync (hidden in v1)** | Device name and ID. Placeholder for the future backend selection. |

Accounts and categories can **override** some global settings (low-balance threshold, rollover, warning threshold, colour).

---

## 3. Libraries

Versions are the latest on pub.dev as of 2026-10-23, and all were published within the last 12 months.

| Concern | Package | Version | Platforms / notes |
|---|---|---|---|
| State management / DI | `flutter_riverpod` + `riverpod_annotation` / `riverpod_generator` | 3.4.x / 4.0.x | All platforms |
| Database | `drift` + `drift_flutter` (+ `drift_dev`) | 2.35.x / 0.3.x | All platforms. **Web** uses `sqlite3.wasm` + a drift worker (OPFS/IndexedDB). Provides reactive streams, migrations and FTS5. |
| DB encryption | `sqlite3` 3.x, SQLCipher / SQLite3MultipleCiphers hook | 3.7.x | Native platforms; web uses `sqlite3mc.wasm`. (`sqlcipher_flutter_libs` is **EOL**.) |
| Secure key storage | `flutter_secure_storage` | 11.2.x | All platforms (on web it is protected by WebCrypto, so it is weaker) |
| Simple prefs (bootstrap only) | `shared_preferences` | 2.5.x | Theme and locale before the DB opens |
| Routing | `go_router` | 18.1.x | All platforms; deep links, URL paths on web |
| Adaptive layout | *built-in* (`NavigationBar` / `NavigationRail`, M3 window-size classes) | — | `flutter_adaptive_scaffold` is **discontinued**, so the app has its own small `AdaptiveShell` |
| Desktop window | `window_manager` | 0.5.x | Windows/macOS/Linux: minimum size, remembers window position |
| Theming | `flex_color_scheme` | 9.0.x | Many schemes, custom accent, high contrast, component themes |
| Dynamic colour | `dynamic_color` | 2.1.x | Android 12+, desktop accent colour |
| Charts | `fl_chart` | 1.3.x | All platforms |
| Excel read | `excel_plus` | 2.29.x | `.xlsx`/`.xls`, actively maintained (`excel` has had no release since 08/2024) |
| CSV | `csv` | 8.0.x | Import/export |
| Text encodings | `enough_convert` | 1.7.x | Windows-1252 / ISO-8859-x decoding for old CSV files |
| Zip bundle | `archive` | 4.5.x | CSV bundle export/restore |
| File picking / sharing | `file_picker`, `share_plus`, `path_provider` | 13.x / 13.x / 2.1.x | All platforms (on web, downloads replace saving to a folder) |
| Formatting / i18n | `intl` + `flutter_localizations` | 0.20.x | EN/DE, ARB files |
| Precise arithmetic | `decimal` | 3.2.x | Interest, percentages, projections |
| Recurrence | `rrule` | 0.2.x | RFC 5545 |
| Calendar UI | `table_calendar` | 3.3.x | Bills calendar |
| Biometrics | `local_auth` | 3.0.x | Android/iOS/macOS/Windows. **Linux and web fall back to PIN/password.** |
| Notifications | `flutter_local_notifications` | 22.x | All platforms (web support is limited) |
| Models | `freezed` + `json_serializable` | 4.0.x / 6.15.x | — |
| IDs | `uuid` | 4.6.x | UUIDv7 (time-ordered), which suits sync |
| Testing | `flutter_test`, `mocktail`, `integration_test` | 1.0.x | — |
| Lints | `very_good_analysis` | — | — |

Considered but not chosen:
- `excel` and `spreadsheet_decoder`: unmaintained.
- Syncfusion: commercial licence.
- Isar/Hive: not relational, and their maintenance is unstable.
- `flutter_adaptive_scaffold`: discontinued.
- `hotkey_manager`: stale. In-app shortcuts use Flutter's own `Shortcuts`/`Actions`.

---

## 4. Architecture

```
lib/
  app/                 # App widget, router, AdaptiveShell, theme, l10n, shortcuts
  core/
    money/             # Money value type (int minor units + currency code)
    db/                # Drift DB, tables, migrations, DAOs, encryption, platform connection
    settings/          # Typed settings schema, repository, providers
    sync/              # Change tracking, HLC clock, SyncBackend interface (no-op in v1)
    platform/          # Capability checks (biometrics? notifications? folders?)
  features/
    accounts/ transactions/ categories/ tags/ custom_fields/ rules/
    budgets/ recurring/ goals/ forecast/ scenarios/ reports/ dashboard/
    import/            # domain: file readers, structure detection, mapping, parsers, dedupe, transfer matcher
    export/            # CSV writer, bundle, scheduler
    settings/ security/ onboarding/
    # each feature has data/ · domain/ · presentation/
test/  integration_test/  test/fixtures/   # real-world-style .xlsx/.csv samples
```

- **Layers**: presentation (widgets + Riverpod notifiers) → domain (pure Dart) → data (Drift DAOs, repositories).
- **Reactive flow**: Drift `watch()` streams feed `StreamProvider`s, so new entries immediately update the dashboard, budgets and forecast.
- **The forecast engine and import pipeline are pure Dart** and run in a background isolate (`Isolate.run`, or a web worker on web). They are heavily unit-tested.
- **Aggregations run in SQL**. The app must stay fast with 100 k+ rows.
- **Platform capabilities** are accessed through one `PlatformCapabilities` provider, so the UI hides what a platform can't do (e.g. biometrics on Linux, folder auto-export on web).

### 4.1 Adaptive layout
| Width | Layout |
|---|---|
| Compact (< 600) | Bottom `NavigationBar` + FAB; detail views are full screen; quick add is a bottom sheet |
| Medium (600–839) | `NavigationRail`; list-detail where it helps (transactions) |
| Expanded (≥ 840) | Extended rail or sidebar; **list-detail panes**; dashboard grid; quick add as a dialog; keyboard shortcuts, context menus, hover states |

### 4.2 Data model (v1)

Every table has these **sync columns**:
- `id` (UUIDv7)
- `createdAt`, `updatedAt` (HLC timestamp)
- `deletedAt` (a tombstone instead of a hard delete)
- `originDeviceId`

```
Account          name, type, currency='EUR', openingBalanceMinor, openingDate, color, icon, groupId?,
                 includeInNetWorth, includeInBudgets, includeInForecast, lowBalanceThresholdMinor?,
                 expectedAnnualReturnBp?, interestRateBp?, archived, sortOrder
AccountGroup     name, sortOrder
Category         parentId?, name, kind(income|expense), icon, color, archived, sortOrder,
                 rolloverOverride?, warnThresholdOverride?
Transaction      accountId, date, valueDate?, amountMinor (signed), currency='EUR', payee?, note?,
                 categoryId?, transferPeerId?, status, recurringRuleId?, importBatchId?, importRowRef?,
                 dedupeHash
TransactionSplit transactionId, categoryId, amountMinor, note?
Tag / TransactionTag
CustomFieldDef   name, type(text|number|date|select|multiselect|bool), options, appliesTo
CustomFieldValue fieldId, entityId, value
Attachment       transactionId, filePath | blobRef, mimeType
Rule             name, priority, conditions(JSON), actions(JSON), applyOnEntry, applyOnImport, enabled
TransactionTemplate  name, fields(JSON)
RecurringRule    name, rrule, startDate, endDate?, count?, template(JSON), postingMode,
                 remindDaysBefore, notifyTime, lastPostedDate
RecurringAmountChange  ruleId, fromDate, amountMinor
Budget           categoryId, periodStart, amountMinor, rollover, ruleId?
BudgetRule       categoryId, amountMinor, cadence, every, startDate, endDate?, count?, generatedUntil?
BudgetTemplate   name, items(JSON)
Goal             name, targetMinor, targetDate?, accountId?, contributionMinor?, priority
Scenario         name, color, adjustments(JSON → freezed union)
SavedFilter      name, filter(JSON)
DashboardLayout  breakpoint, widgets(JSON)
ImportProfile    name, config(JSON: sheets, header, mapping, formats, filters, transfer matching…)
ImportBatch      fileName, fileHash, profileId?, importedAt, rowCount, undoneAt?
Setting          key, value(JSON), scope(global|account:<id>|category:<id>)
ChangeLog        seq, entity, entityId, op(insert|update|delete), hlc, changedFields, synced=false
SyncState        backendId, lastPulledHlc, lastPushedSeq     (unused in v1)
```
An FTS5 virtual table covers payee, note, category and tag names.

### 4.3 Sync base structure (v1 builds it but ships no backend)
- **Every write goes through repositories**, which in the same DB transaction (1) stamp the row with an **HLC** (hybrid logical clock), the device ID and `updatedAt`, and (2) append a row to `ChangeLog`. Deletes are **soft** (tombstones).
- `abstract interface class SyncBackend { Future<void> push(List<Change>); Stream<Change> pull(Hlc since); }`. v1 ships `NoopSyncBackend` and a test-only `InMemorySyncBackend`, so the merge logic is tested from the start.
- **Merge policy**: last-writer-wins per field by HLC. Transaction splits are merged as a unit.
- Possible later backends: a self-hosted server (REST), WebDAV/Nextcloud with a change-file exchange, or end-to-end encrypted cloud storage.
- A **CSV export is the only data-out path in v1** (§2.6). A periodic job purges tombstones older than a configurable age as long as no sync backend is configured.

---

## 5. Roadmap

| Milestone | Content | Exit criterion |
|---|---|---|
| **M0 Foundation** (1.5 wk) | Project for all 6 platforms, lints, CI (analyze, test, build matrix Android/iOS/Web/Win/macOS/Linux), theme from design tokens, `AdaptiveShell`, router, Drift schema v1 incl. sync columns + ChangeLog, settings framework, `Money` type | App starts on all platforms; CI green |
| **M1 Record** (2.5 wk) | Accounts, categories, tags, quick add (calculator), transaction list/search/filter, transfers, splits, templates, undo, custom fields | Daily logging replaces Excel |
| **M2 Import & CSV export** (3 wk) | Complete import wizard (§2.5), profiles, rules engine, transfer detection, balance verification, history/undo; CSV export + bundle + restore | **Full Excel history imported correctly, with balances matching the sheet** |
| **M3 Track** (2 wk) | Configurable dashboard, reports, net-worth history, reconciliation | Monthly review without Excel |
| **M4 Plan** (2.5 wk) | Configurable budget periods, budgets (tracking/envelope, rollover), recurring rules + reminders, bills calendar, goals | Next period fully planned in the app |
| **M5 Project** (2 wk) | Cash-flow forecast, net-worth projection, scenarios | "Can I afford X in March?" answerable |
| **M6 Hardening** (2 wk) | App lock (biometric/PIN per platform), DB encryption (incl. web), auto-export, full settings & search, DE/EN, accessibility, desktop shortcuts, performance with 100 k rows, store/installer packaging | Release candidate on all platforms |
| **Later** | Sync backend, multi-currency, xlsx export, encrypted backup, receipt OCR, home-screen widgets, bank CSV profiles, Sankey/uncertainty band | — |

### Testing strategy
- **Unit**: Money, rrule expansion (31st, leap years, business-day shifting, holidays), budget periods and rollover, the forecast engine (numeric fixtures), HLC/merge logic, settings schema.
- **Import**: a fixture library covering German/English number formats, Excel serial dates, debit/credit columns, S/H type columns, merged headers, subtotal rows, multiple sheets, Windows-1252 CSVs and running-balance checks. **The owner's anonymised sheet becomes the main acceptance fixture.**
- **DB**: Drift in-memory tests, migration tests (`drift_dev schema`), and a ChangeLog test that every repository write records a change.
- **Widget/golden**: compact and expanded layouts, light and dark themes.
- **Integration**: import, then dashboard totals, then a recurring rule, then the forecast. This runs on Android, Linux desktop and web (Chrome) in CI.

---

## 6. Screen inventory (for the design draft)

Design draft ("Quiet Ledger", 12 boards incl. a Foundations/tokens board): https://claude.ai/artifact/SwwnQe9TMqt27b7NkRvy8A

1. **Onboarding**: welcome, then language & formats, then budget-period start, then "Import from Excel" or "Start fresh", then accounts, then app lock
2. **Dashboard**: configurable widgets (phone stack / desktop grid) plus an edit mode
3. **Transactions**: list (+ detail pane on wide screens), search, filters, saved filters, bulk edit
4. **Quick add / edit**: bottom sheet (phone) or dialog (desktop), calculator keypad, split, custom fields
5. **Accounts**: grouped list with balances; account detail with chart; reconciliation
6. **Plan**: Budgets · Recurring · Goals tabs; bills calendar
7. **Forecast**: horizon, balance curve with lowest point and threshold, scenario toggles; long-term projection
8. **Scenario editor**
9. **Reports**
10. **Import wizard**: source → sheets → structure → mapping → formats → categories/accounts → transfers → duplicates → summary; plus import history
11. **Settings**: searchable sections (§2.7); module toggles; dashboard editor
12. **Rules editor** (auto-categorisation)

Navigation: Home · Transactions · Plan · Forecast · More. The tabs and their order are configurable, and on mobile there is a global quick-add FAB.

---

## 7. Remaining inputs needed
- **An anonymised copy of the Excel sheet** (or headers plus about 10 rows). It is not blocking, because the importer is built to be generic, but it becomes the M2 acceptance test.
- **Holiday calendar**: is Germany (nationwide) the right default for business-day shifting, or should a specific federal state be selected?
