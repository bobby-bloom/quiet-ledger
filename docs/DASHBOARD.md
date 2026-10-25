# Dashboard

The dashboard (Home) is a board (docs/BOARD.md): views, Auto and Custom,
rows, arrange mode, the order sheet and storage work as described there.
This is what is the dashboard's own. Read it before changing
`lib/features/dashboard/`.

Code: `domain/dashboard_view.dart` (`DashboardWidgetType`, `dashboardBoard`,
default rows), `domain/dashboard_legacy.dart` (the 0.1 layouts),
`data/dashboard_layout.dart` (`DashboardItem`, the repository for this
board), `presentation/dashboard_menu.dart` (`dashboardLabels`, the layout
button with folding), `presentation/dashboard_screen.dart`,
`presentation/widget_registry.dart` and `widgets/` (the cards),
`presentation/card_expansion.dart` (folding).

## Widgets

Nine widget types, their `name` the card id: net worth, month summary,
budgets, upcoming bills, forecast, accounts, goals, top categories, recent
transactions — the order of `DashboardWidgetType`, which is the board's
card order. Wide screens show all by default; phones six (Net worth, month
summary, budgets, upcoming, forecast, recent transactions). Options: the
forecast's `accountId`, a list's row `limit`.

**Default rows** at three columns: `2:1` Net worth | month summary +
forecast · `1:1:1` budgets | upcoming | goals · `2:1` recent transactions |
top categories + accounts. At two columns: Net worth · `1:1` month summary +
budgets | forecast + upcoming · recent transactions · `1:1` goals + accounts
| top categories.

In arrange mode and the phone sheet the forecast is named with its account
("Mini forecast · Everyday checking"); Add, hidden widgets and toasts use
the type's name. The menu and the phone sheet add Expand all / Collapse all.

## Folding

Every widget folds with its chevron except Net worth on phones (the hero).
Folded, a card shows its header and its peek line; its footer link moves into
⋮. The open state is per widget type, shared by both views, and
**device-local** (`dashboard.cardExpansion`, `deviceLocal: true`): it is
situational, never synced, and a restore keeps the device's own.


## Storage

The dashboard's keys predate other boards: `expanded.v2` and `compact.v2`,
no prefix (`keyPrefix: ''`).

The 0.1 rows `compact` / `expanded` (a flat list of `{type, size,
options}`) stay as they are, because a 0.1 build would fail on the new
shape. While no `*.v2` row exists they are migrated on read: a list equal to
the old default becomes Auto; another wide list is packed the way the old
grid laid it out at three columns (`[wide, normal]` → `2:1`, `[normal,
wide]` → `1:2`, three normal → `1:1:1`, a lone wide card → its own row, a
short row of normal cards → `1:1:1` with empty columns) and saved as Custom
on the first write; a phone list becomes the custom order. Listed widgets
keep their options; the others are hidden.
