# Budgets

How a budget line is calculated: what counts as spent, what is shown as
outstanding, how repeating budgets fill new periods, and how rollover and
the envelope "left to assign" use them. Read this before changing budget
maths, the queries behind it or the `budgets` / `budget_rules` tables.

Code lives in `lib/features/budgets/` (`data/budgets_repository.dart`,
`data/budget_providers.dart`, `domain/budget_math.dart`,
`domain/outstanding.dart`, `domain/budget_rules.dart`,
`budgets_startup.dart`) and `lib/core/calendar/budget_period.dart`
(periods).

## Spent

`BudgetsRepository` sums transactions and split lines dated in the period
on accounts with **include in budgets**, without transfers and **without
planned entries**. Pending entries count as spent. Parent categories
include their children; refunds reduce spending.

`spentMinor` alone decides a line's state (on track, warning at the
threshold, over). Budget alerts, rollover (`syncChain`) and the envelope
"left to assign" use spent amounts only.

## Outstanding

Money that is expected in the period but not booked yet. It is shown next
to the spent amount and **never** added to it.

1. **Planned entries**: transactions and split lines with status
   *planned*, under the same account and transfer rules as spent amounts.
   A planned entry dated before today is shown as overdue.
2. **Recurring occurrences not posted yet** (`recurringOutstanding`): active
   rules on budget accounts, not transfers, with occurrences in the period
   after the rule's last posted date. For auto-post rules, only
   occurrences from today on count, because the startup task posts
   earlier ones. Remind & confirm occurrences stay until they are
   confirmed or skipped. The amount includes dated amount changes. Split
   templates give one share per split line, scaled to that amount.
   An occurrence is left out when a ledger row of the same rule already
   exists on that date (any status), so a planned entry created for an
   occurrence counts once.

`PeriodPlanned` aggregates these items per category, like the actuals.
`BudgetLine.plannedMinor` is the outstanding spending of the line, and
these values build on it:

| Value | Meaning |
|---|---|
| `projectedSpentMinor` | spent + planned |
| `projectedRemainingMinor` | available − projected spent |
| `projectedState` | state once everything outstanding is booked |
| `plannedPushesOver` | not over yet, but over once booked |

On screen:

- The bar shows planned amounts as a lighter, striped segment after the
  spent fill.
- The row says "€80 planned", or "Planned: €30 over" in the warning colour
  when the planned amount would take the line over.
- The summary card adds a line "€X planned · After planned: €Y left"
  under its figures.
- The detail screen lists the items under "Outstanding". Planned entries
  open the transaction. Recurring occurrences open the rule. A rule's
  next remind & confirm occurrence also offers Confirm and Skip; later
  occurrences don't, because confirming one marks every earlier one as
  done.

Expected income is shown on the envelope banner ("€X expected income")
and is not included in "left to assign" until it arrives. A planned
overspend never raises a notification.

**Settings › Budgets › Show planned and upcoming**
(`BudgetSettings.showOutstanding`, on by default, synced) turns all of
this off.

Outstanding amounts don't change the forecast, which has its own settings
for planned entries (`ForecastSettings.includePlanned`).

## Repeating budgets

A budget is one `budgets` row per category and period. A **rule**
(`budget_rules`) fills in rows for new periods so a budget only has to be
set once.

### Rules

A rule has an amount, a start (the first period it covers), an interval
(`every`: every n-th period) and an optional limit: a number of periods
(`count`) or an end date (`endDate`: periods starting after it are not
covered). Without a limit it repeats until changed. `cadence` is the
length of one budget: `period` follows the global budget period setting;
`week`, `month`, `quarter` and `year` give the budget its own length (see
below). For those, "period" in this section means one window.

When two live rules cover the same category and period, which can happen
after sync or a category merge, the newest (`updatedAt`) wins.

A rule is **never changed in place** once it may have generated rows
(only its end and its watermark move). A change ends it and continues
with a new rule (`repeatFrom`, `mergeRules`), so devices that generated
rows from the old rule never disagree about what the rule says.

### Rows

- `budgets.ruleId` is set on a row the rule generated and nobody has
  edited since. A row with `ruleId = null` was **set by hand**: by
  editing one period, Copy previous, Average, Template or Edit all (an
  explicit write marks the row as set by hand even when the amount stays
  the same). A rule never touches a row set by hand, and the row
  overrides the rule for that period.
- Rows are generated up to the end of the next period at startup
  (`budgetRulesStartupTask`, before the budget alerts): for a weekly
  budget every week starting in it, so the forecast sees a whole month.
  The board generates up to the end of any later period it shows
  (`budgetRulesSyncProvider`). Earlier periods are filled only once, when
  a rule starts in the past.
- A window is not generated while any window of the category overlaps it
  (after the first day of week, start day or fiscal year changed), so
  generated windows never overlap. The window straddling such a change is
  skipped, so a few days can be without a budget.
- Rows a rule generated after its end (by a device that did not know yet
  that a newer rule took over) are removed when rules generate.
- **Watermark.** `generatedUntil` is the start of the last period a rule
  has handled. Periods up to it are never generated again, so a budget
  the user removed stays removed. This holds even after the tombstone
  purge hard-deletes the removed row, which can happen after 7 days.
  One exception: a period that now contains the watermark but starts
  earlier is generated again. That happens to a salary-based period when
  the salary lands earlier than expected.
- **Deterministic ids.** A generated row's id is a UUIDv5 of the rule id
  and the period start (`generatedBudgetId`), and its sync timestamp is
  fixed one second before the rule's creation (`SyncWriter.insert(hlc:
  …)`), older than any edit made after the rule existed. Two devices
  that generate the same period create the same row, and any edit or
  removal by the user, on any device, wins over a generated row.
- **Period type changes.** A `period` rule records the period type it was
  made for (`budget_rules.period_type`). After the type changes it keeps
  its length: a monthly rule on a weekly board becomes a monthly budget
  with its own length (`lengthOn`), and the rows it generated turn into
  windows (and back when the type returns). Budgets of a period set by
  hand are not converted; they only show where a period of the new type
  starts on the same day.

### Editing

The amount dialog has a **Repeat** field: this period only, every period
(the default for a new budget), for a number of periods, or until a
date, each with "every … periods". Then:

| Action | Result |
|---|---|
| New budget, repeating | `repeatFrom`: a rule from this period, plus this period's row |
| Changed amount, same repeat setting | asks **Only this period** (the row becomes a hand-set override) or **This and following periods** (`repeatFrom`) |
| Changed repeat setting or length | applies from this period on: `repeatFrom`, or for "this period only" the rule ends with this period (`stopRepeating` from the next one). Only the budget shown is replaced; earlier budgets stay |
| Remove, only this period | the row is soft-deleted, with Undo. The watermark keeps it removed |
| Remove, this and following | `stopRepeating` from this period, then this period's row is removed (confirmed by a snackbar) |
| Stop repeating (detail screen) | `stopRepeating` from the next period; this period's budget stays |
| Fill › Repeat these budgets every period | `repeatPeriod`: every row of the period that no rule covers yet becomes a rule from that period |
| New budget for a category whose rule skips this period (every n-th) | the dialog suggests "this period only", so the rule is not replaced by accident |

`repeatFrom(from:, replace:)` starts the new rule at `from` (a period, or
a window of the new length) and replaces the budget shown (`replace`,
by default `from`). Budgets starting before `replace` are history and
stay untouched, whatever their length or origin. The category's
existing rules end the day before `replace`, and rules that start at or
after it are removed. Any budget overlapping `replace` is replaced.
Later rows the old rules generated move to the new rule with the new
amount, or are removed where the new rule doesn't cover that period.
Later rows set by hand stay. The new rule takes over the watermark of the
old rules of the same length, so periods they handled (and the user may
have removed) are not generated again; periods it covers that they did
not ("every 2 months" changed to "every month") are generated right away.

`stopRepeating` ends the rules the same way and soft-deletes their
generated rows from the given period on.

### Categories, backup, sync

- A category with rules counts as in use, so deleting it is refused.
- Merging (`mergeRules`, before the rows are merged) first generates the
  rows of both categories' rules through a common horizon (the end of the
  next period or the furthest watermark; a source rule with an end or a
  count through its last period), so the merged rows add up. After the
  horizon a target rule continues as a new rule with the newest
  open-ended source amount of its length added; an open-ended source rule
  of a length the target has no rule of continues as a new rule of the
  target. The source rules end. Merged
  period rows become hand-set.
- `budget_rules` is in `syncedTableNames`, so it is backed up, restored
  and synced like every other table. A restore brings back the rules
  together with their watermarks, so nothing the user removed comes back.
  Backups from before schema 4 restore with `ruleId = null` on every
  budget.

## Budgets with their own length

A budget can last a week, month, quarter or year instead of the budget
period: a yearly holiday budget or a weekly groceries budget on a monthly
board. Its rows carry `periodEnd` (exclusive); `periodEnd = null` is a
budget of the budget period starting at `periodStart`. Every query for a
period's budgets filters `periodEnd IS NULL`, so a yearly window starting
on 1 January is not mistaken for January's budget.

**Windows** come from `windowPeriods`: the budget period settings with the
period type of the length (first day of week, start day and weekend shift
for months, fiscal year start for quarters and years) and no salary-based
start.

**On the board** of a budget period a category shows:

1. its budget of the period, if it has one (this always wins);
2. otherwise the window containing the period's reference day
   (`referenceDay`: today in the current period, the last day of a past
   period, the first day of a future one); failing that the last window
   starting before that day, else the first one overlapping the period.

Spent, outstanding amounts, rollover and the state are measured over the
window, and the today tick marks today's place in it. The row is labelled
with its length and window ("Weekly · Oct 19 – Oct 25, 2026"). The detail
screen lists every window of the category within the period (each week of
the month) and its history shows the last windows.

**Totals.** Budgeted, Spent, Left and the planned line on the summary card cover
budgets of the period only, with a note when windowed budgets are on the
board. Spending of a category with a window budget does not count as
"spent in categories without a budget".

**Nested windows.** A window inside a longer window of the same category
(weeks left from before the category switched to a quarterly budget) is
covered by the longer one: it is not shown on the board and not counted
in shares or the forecast (`dropNestedWindows`). The rows stay as
history.

**Shares** (`windowShare`, `windowTargets`). In envelope mode a window's
amount is assigned evenly to the budget periods it covers: a window
longer than the budget period is spread over the periods starting inside
it (a yearly budget gives each month 1/12, leftover cents to the first
months), a shorter one counts fully in the period it starts in (each week
in its month). `assignedInPeriod` decides what counts, for the board and
for the envelope carry along the chain (`syncChain`) alike: budgets of
the period for root categories, window shares for categories without a
budget of the period, and nothing for a category whose parent has a
budget of either kind. A period with only window budgets still belongs
to the chain. The forecast's "variable spending = budget" method gets the
same per-period shares, unless the category has a budget of that period.

**Rollover** of a window budget runs along the chain of directly
preceding windows of the category (`windowRollover`, at most 12) with the
category's rollover mode; it is computed when shown, not stored.

**Editing.** The amount dialog has a **Length** field (Budget period, One
week, month, quarter or year; the length equal to the budget period type
is not offered separately). Keeping the length, edits work as described
above for the window shown (this window only, or this and the following
windows). A new length applies from the window containing the shown
period's first day: `repeatFrom` replaces the budget overlapping that
window (of any length), and later budgets of the old rules are moved or
removed as usual; budgets set by hand later on stay. A one-off window is a
row with `periodEnd` and no rule (`setWindowAmount`).

**Alerts** for a window budget are keyed by the window, so each week can
warn once.
