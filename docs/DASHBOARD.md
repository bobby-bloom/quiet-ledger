# Dashboard

How the dashboard decides which widgets show, where they sit and whether
they are folded: views, Auto and Custom, rows, fitting the window, arrange
mode, storage and migration. Read this before changing
`lib/features/dashboard/` or the `dashboard_layouts` table.

Code: `domain/board_layout.dart` (rows, fitting, Layout control),
`domain/arrange.dart` (moves, drops, row edits), `domain/dashboard_view.dart`
(views, selection, default rows), `data/dashboard_layout.dart` (storage,
migration), `presentation/dashboard_layout_actions.dart` (what the controls
do, the arrange session), `presentation/board/` (arrange mode, ported from
keeper's card board), `presentation/card_expansion.dart` (folding).

## Views

The dashboard keeps two arrangements that never change each other:

| View | Used | Arrangement |
|------|------|-------------|
| `compact` | windows < 600 dp (phones) | one ordered list |
| `expanded` | every wider window, medium included | rows of columns |

Both sync and are backed up. One `expanded` layout is shared by every wide
screen and folded to whatever window shows it (below).

## Selection

Each view stores an entry per widget type: `visible` and `options` (the
forecast's account, a list's row `limit`). Every save writes an entry for
every type the build knows.

- **Remove** sets `visible: false`. The widget keeps its options and its slot
  in the arrangement; Undo or Add widget brings it back there.
- **New types**: a type without an entry shipped after the last save. On Auto
  it shows in its default slot; on Custom it does not show and Add widget
  marks it "New" until it is added or the view is saved again.
- Defaults: all nine types on wide screens; six on phones (Net worth, month
  summary, budgets, upcoming, forecast, recent transactions).

## Auto and Custom

A view is on **Auto** (the app's responsive default) or **Custom** (the
person's saved arrangement). Switching to Auto keeps the saved arrangement.

Wide, the board menu's Layout control is **Auto · 1 · 2 · 3** plus
**Custom** while the saved layout is more than one equal row. The selected
segment is what shows. A number restores a saved layout of exactly that many
equal columns, or deals the widgets on screen into one such row — with
"Layout set to n columns · Undo" when that replaces a saved layout.

Phones have Auto · Custom in the editor sheet (Custom only once an order is
saved). The first move on Auto copies the default order.

## Rows and fitting

A wide layout is a list of rows. A row has a split (column weights:
`1`, `1:1`, `2:1`, `1:2`, `1:1:1`) and one list of widget ids per column;
widgets stack in their column, and a row is as tall as its tallest column.

- A column needs at least **320 dp**, with 20 dp gaps: three columns from
  1000 dp of content, two from 660 dp. Content width is the board's own
  constraint, after the sidebar and gutters.
- **Default rows** at three columns: `2:1` Net worth | month summary +
  forecast · `1:1:1` budgets | upcoming | goals · `2:1` recent transactions |
  top categories + accounts. At two columns: Net worth · `1:1` month summary
  + budgets | forecast + upcoming · recent transactions · `1:1` goals +
  accounts | top categories. One column reads those rows row by row, column
  by column.
- A saved row wider than the window shows with the columns that fit, the
  rest appended to the last one. Nothing saved changes; the menu says "This
  window fits up to n columns. Your layout shows in full on wider screens."
- An unequal split leans towards equal rather than make a column narrower
  than 320 dp.
- A widget that shows but has no slot (new, or never placed) goes after its
  nearest predecessor in the default reading order, else to the top.

## Arrange mode

Wide, "Arrange widgets…" (board menu or a card's ⋮) needs two fitting
columns. The header becomes the arrange bar (Add widget, Reset, Cancel,
Done); widgets become 52 dp rows, rows dashed bands with a split picker and
a row menu (move up / down, remove — its widgets go to the row above, the
first row's to the row below); "Add row" sits under the last row.

- Drag a widget anywhere in its row (mouse and touch, immediate), or use its
  ⋮ Move menu: Up, Down, One column left / right, Remove from dashboard. Up
  from the top of a column continues at the bottom of the row above (same
  column index, clamped); Down at the top of the row below. The same moves
  are screen-reader actions; each move is announced. Dropping into the gap
  between rows makes a new one-column row.
- There is no auto-scroll: the arranged board is short; the Move menu is the
  way when it is taller than the window.
- Removing and adding inside the session are part of it: Cancel undoes them.
- **Done** saves rows and selection as Custom in one write. From Auto without
  a change it leaves like Cancel; from Auto over a different saved layout it
  offers "Layout replaced · Undo". **Cancel** with changes offers "Changes
  discarded · Undo", which comes back with the work. **Reset** puts the
  default rows in, inside the session. Done drops rows left with no widget
  (hidden ones count) and keeps empty columns.
- A window too narrow to arrange **pauses** the session: the normal board
  shows and the session resumes once two columns fit. A paused session goes
  when the saved wide layout changes meanwhile.
- A synced change while arranging (not paused) does not disturb the
  session; Done wins.

## Phones

The header's layout button opens the editor sheet: Auto · Custom, Expand all
/ Collapse all, one row per widget with a grip (drag starts at once), ▲ ▼
and Remove, "Not on your dashboard" with Add, and Done. Every change applies
at once; there is no Cancel (Auto is the way back). ▲ ▼ skip hidden widgets,
which keep their place.

## Folding

Every widget folds with its chevron except Net worth on phones (the hero).
Folded, a card shows its header and its peek line; its footer link moves into
⋮. The open state is per widget type, shared by both views, and
**device-local** (`dashboard.cardExpansion`, `deviceLocal: true`): it is
situational, never synced, and a restore keeps the device's own.

## Storage

`dashboard_layouts` rows, synced and backed up, keyed by `breakpoint`:

| Key | `widgets` JSON |
|-----|----------------|
| `expanded.v2` | `{"v": 2, "mode": "auto" \| "custom", "items": {"<type>": {"visible": bool, "options": {…}}}, "rows": [{"split": [2, 1], "columns": [["netWorth"], ["monthSummary", "forecast"]]}]}` |
| `compact.v2` | the same with `"order": ["<type>", …]` instead of `rows` |

- `rows` / `order` are absent until a custom arrangement is saved.
- Reading drops unknown types and keeps a duplicated id in its first slot;
  anything malformed reads as nothing saved (logged once).
- The 0.1 rows `compact` / `expanded` (a flat list of `{type, size, options}`)
  stay as they are, because a 0.1 build would fail on the new shape. While no
  `*.v2` row exists they are migrated on read: a list equal to the old
  default becomes Auto; another wide list is packed the way the old grid laid
  it out at three columns (`[wide, normal]` → `2:1`, `[normal, wide]` → `1:2`,
  three normal → `1:1:1`, a lone wide card → its own row, a short row of
  normal cards → `1:1:1` with empty columns) and saved as Custom on the first
  write; a phone list becomes the custom order. Listed widgets keep their
  options; the others are hidden.

## Known limitations

- No auto-scroll while dragging.
- Undo writes the whole view back as it was before the action.
- Adding a widget does not scroll it into view.
