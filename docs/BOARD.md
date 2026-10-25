# Boards

A board is a screen region of cards the person arranges: one ordered list on
phones, rows of columns on wider windows, the app's Auto layout or their
own, arranged in place, synced and backed up. The dashboard is the first
board; any screen can have one. Read this before changing
`lib/core/board/` or `lib/app/ui/board/`, or putting a board on a screen.

Code:
- `lib/core/board/` (pure Dart): `board_layout.dart` (rows, fitting, the
  Layout control's rules), `arrange.dart` (moves, drops, row edits),
  `board_state.dart` (`BoardDefinition`, `BoardState`, `BoardView`),
  `board_storage.dart` (codec, `BoardRepository`, `boardStateProvider`).
- `lib/app/ui/board/`: `card_board.dart` (`CardBoard`, `BoardRowsView`,
  `BoardArrangeBar`), `arrange_board.dart` and its parts (arrange mode,
  ported from keeper's card board), `board_menu.dart` (`BoardLayoutButton`,
  `BoardLayoutChoice`, `showAddCards`), `board_order_sheet.dart`,
  `board_actions.dart` (what the controls do, Undo, the arrange session),
  `board_labels.dart`.

## A board on a new screen

1. **Define it** — a `const BoardDefinition` next to the feature:
   `id` (storage key prefix), `cards` (every card id, in their canonical
   order), `compactDefaults` (what a phone shows at first, in order) and
   `defaultRows(fits)` (the Auto rows for 3+, 2 and — read row by row — 1
   column). Ids are stored: never rename one, never reuse one for another
   card.
2. **Name it** — `BoardLabels`: the screen's words (menu tooltip,
   "Arrange…", "Add…", "Remove from …", the empty-column and hint lines,
   the reset toast) and `cardName` / `cardTitle` / `cardIcon` /
   `cardDescription` per card. The board's structure words (Row n, splits,
   Move up …) are shared `board*` strings.
3. **Show it** — `CardBoard(def:, labels:, width:, card:, builder:,
   empty:)`. `card` builds a card by id (its options are
   `scene.saved.optionsOf(id)`; change them with `setCardOptions`).
   `builder` lays out the screen: the header is the `arrangeBar` it gets
   while arranging, else the screen's own with a `BoardLayoutButton(def:,
   labels:, view: scene.view, saved: scene.saved, layout: scene.layout,
   focusNode: scene.layoutButtonFocus)`; `menuExtras` / `orderExtras` add
   the screen's own controls to its menu and order sheet.
4. A card's own ⋮ can offer Remove (`removeCard`, with Undo) and Arrange
   (`arrangeSessionProvider(def).notifier.enter(scene.saved,
   scene.layout!.placed)`).

## Views

A board keeps two arrangements that never change each other:

| View | Used | Arrangement |
|------|------|-------------|
| `compact` | windows < 600 dp (phones) | one ordered list |
| `expanded` | every wider window, medium included | rows of columns |

Both sync and are backed up. One `expanded` layout is shared by every wide
screen and folded to whatever window shows it (below).

## Selection

Each view stores an entry per card: `visible` and `options` (what the
screen keeps per card, e.g. the dashboard forecast's account). Every save
writes an entry for every card the build knows.

- **Remove** sets `visible: false`. The card keeps its options and its slot
  in the arrangement; Undo or Add brings it back there.
- **New cards**: a card without an entry shipped after the last save. On Auto
  it shows in its default slot; on Custom it does not show and Add
  marks it "New" until it is added or the view is saved again.
- Defaults: every card on wide screens; `compactDefaults` on phones.

## Auto and Custom

A view is on **Auto** (the app's responsive default) or **Custom** (the
person's saved arrangement). Switching to Auto keeps the saved arrangement.

Wide, the board menu's Layout control is **Auto · 1 · 2 · 3** plus
**Custom** while the saved layout is more than one equal row. The selected
segment is what shows. A number restores a saved layout of exactly that many
equal columns, or deals the cards on screen into one such row — with
"Layout set to n columns · Undo" when that replaces a saved layout.

Phones have Auto · Custom in the order sheet (Custom only once an order is
saved). The first move on Auto copies the default order; when that replaces
a saved order, the sheet offers "Your earlier order was replaced · Undo",
which goes back to Auto with that order kept.

Switching to Custom (a number, Custom, Done, a phone move) first writes an
entry for every card as it shows on Auto, so a card that shipped after the
last save and shows on Auto stays shown.

Undo puts back only what its action changed — a removed card, the mode
and rows a pick replaced, the visibility a reset changed — on the state as
it is then, so other changes made meanwhile stay.

## Rows and fitting

A wide layout is a list of rows. A row has a split (column weights:
`1`, `1:1`, `2:1`, `1:2`, `1:1:1`) and one list of card ids per column;
cards stack in their column, and a row is as tall as its tallest column.

- A column needs at least **320 dp**, with 20 dp gaps: three columns from
  1000 dp of content, two from 660 dp. Content width is the board's own
  constraint, after the sidebar and gutters.
- A saved row wider than the window shows with the columns that fit, the
  rest appended to the last one. Nothing saved changes; the menu says "This
  window fits up to n columns. Your layout shows in full on wider screens."
- An unequal split leans towards equal rather than make a column narrower
  than 320 dp.
- A card that shows but has no slot (new, or never placed) goes after its
  nearest predecessor in the default reading order, else to the top.

## Arrange mode

Wide, "Arrange…" (board menu or a card's ⋮) needs two fitting
columns. The header becomes the arrange bar (Add, Reset, Cancel,
Done); cards become 52 dp rows, rows dashed bands with a split picker and
a row menu (move up / down, remove — its cards go to the row above, the
first row's to the row below); "Add row" sits under the last row.

- Drag a card anywhere in its row (mouse and touch, immediate), or use its
  ⋮ Move menu: Up, Down, One column left / right, and Remove (the board's
  `removeFromBoard`, e.g. "Remove from dashboard"). Up from the top of a column continues at the bottom of the row above (same
  column index, clamped); Down at the top of the row below. The same moves
  are screen-reader actions; each move is announced. Dropping into the gap
  between rows makes a new one-column row.
- Drag a whole row, its cards with it, by its toolbar (the grip and
  "Row n"; the columns stay for dragging cards). It moves up and down
  only; while it is lifted the board keeps its layout — the row dims in
  place and a line marks the gap it would land in (before the first row
  whose middle lies below the pointer). Let go next to itself, it stays.
  The row menu's Move row up / down are the same moves without a drag, and
  screen-reader actions on the row. One drag at a time: a card or a row.
- There is no auto-scroll: the arranged board is short; the Move menu is the
  way when it is taller than the window.
- Removing and adding inside the session are part of it: Cancel undoes them.
  Remove is announced and focus goes to the next card.
- **Done** saves the rows and the cards the session removed or added as
  Custom, on top of the saved state as it is then (options changed meanwhile
  stay). Without a change it leaves like Cancel; from Auto over a
  different saved layout it offers "Layout replaced · Undo". **Cancel** with changes offers "Changes
  discarded · Undo", which comes back with the work. **Reset** puts the
  default rows in, inside the session. Done drops rows left with no card
  (hidden ones count) and keeps empty columns.
- A window too narrow to arrange **pauses** the session: the normal board
  shows and the session resumes once two columns fit. A paused session goes
  when the saved wide layout changes meanwhile.
- A synced change while arranging (not paused) does not disturb the
  session; Done wins.

## Phones

The layout button opens the order sheet: Auto · Custom, the screen's own
controls (`orderExtras`), one row per card with a grip (drag starts at
once), ▲ ▼ and Remove, the cards not shown (`notOnBoard`) with Add, and
Done. Every change applies at once; there is no Cancel (Auto is the way
back). ▲ ▼ skip hidden cards, which keep their place.

## Storage

Every board's views are rows of the `dashboard_layouts` table (synced and
backed up), keyed by `breakpoint` = `BoardDefinition.storageKey(view)`:
`<id>.expanded.v2` and `<id>.compact.v2` (the dashboard's own predate that
and have no prefix, see docs/DASHBOARD.md).

| View | `widgets` column (JSON) |
|------|-------------------------|
| expanded | `{"v": 2, "mode": "auto" \| "custom", "items": {"<card>": {"visible": bool, "options": {…}}}, "rows": [{"split": [2, 1], "columns": [["a"], ["b", "c"]]}]}` |
| compact | the same with `"order": ["<card>", …]` instead of `rows` |

- `rows` / `order` are absent until a custom arrangement is saved.
- Every change is one `update`: the row is read and written inside one
  transaction, so two changes in quick succession never undo each other.
- Reading skips only what is malformed — an item, a row with an unusable
  split, a non-string id — and keeps the rest; columns beyond a split join
  its last column. A value that is not a JSON object reads as nothing saved.
  All skips are logged once.
- Nothing this build cannot read in full is lost: before a save replaces a
  stored value that is malformed, of another version (`v` ≠ 2) or carries
  fields this build does not know (also the other view's `rows` / `order`),
  a copy goes to a `<key>.unreadable` row (one per distinct value).
- Ids and items of cards this build does not know (a newer build's) are
  kept and written back unchanged; they never show.
- Two `*.v2` rows of one key (two devices that each started one before
  they synced) are both kept. Every device reads and writes the same one: a
  row that reads as a state before one that does not, then the last written,
  then the smallest id. Nothing is moved or deleted. Changes made on two
  devices before a sync are resolved like any synced data: the later write
  wins.
- At most ten copies are kept aside per view; a save that would make an
  eleventh logs it and keeps none.
- A save that would write the same state as stored (in whatever key order
  it was written) writes nothing.
- A board with an older format names its rows and how to read them
  (`BoardDefinition.legacyKey`, `migrateLegacy`); they are read while no
  v2 row exists and never written.

## Known limitations

- No auto-scroll while dragging.
- Adding a card neither scrolls it into view nor moves focus to it.
- In the phone sheet, focus after Remove or Add is not placed.
- Undo of a session restored after Cancel ("Changes discarded") brings back
  the session as it was; Done then applies it on top of the current state.
