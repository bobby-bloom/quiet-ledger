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
- The summary card adds "Planned" and "After planned: €X left".
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

### Rows

- `budgets.ruleId` is set on a row the rule generated and nobody has
  edited since. A row with `ruleId = null` was **set by hand**: by
  editing one period, Copy previous, Average, Template or Edit all. A rule
  never touches a row set by hand, and the row overrides the rule for
  that period.
- Rows are generated for the current and the next period at startup
  (`budgetRulesStartupTask`, before the budget alerts), and up to any
  later period when the board shows it (`budgetRulesSyncProvider`).
  Earlier periods are filled only once, when a rule starts in the past.
- **Watermark.** `generatedUntil` is the start of the last period a rule
  has handled. Periods up to it are never generated again, so a budget
  the user removed stays removed. This holds even after the tombstone
  purge hard-deletes the removed row, which can happen after 7 days.
  One exception: a period that now contains the watermark but starts
  earlier is generated again. That happens to a salary-based period when
  the salary lands earlier than expected.
- **Deterministic ids.** A generated row's id is a UUIDv5 of the rule id
  and the period start (`generatedBudgetId`). Two devices that generate
  the same period create the same row, and sync merges them.

### Editing

The amount dialog has a **Repeat** field: this period only, every period
(the default for a new budget), for a number of periods, or until a
date, each with "every … periods". Then:

| Action | Result |
|---|---|
| New budget, repeating | `repeatFrom`: a rule from this period, plus this period's row |
| Changed amount, same repeat setting | asks **Only this period** (the row becomes a hand-set override) or **This and following periods** (`repeatFrom`) |
| Changed repeat setting | applies from this period on: `repeatFrom`, or for "this period only" the rule ends with this period (`stopRepeating` from the next one) |
| Remove, only this period | the row is soft-deleted, with Undo. The watermark keeps it removed |
| Remove, this and following | `stopRepeating` from this period, then this period's row is removed |
| Stop repeating (detail screen) | `stopRepeating` from the next period; this period's budget stays |
| Fill › Repeat these budgets every period | `repeatPeriod`: every row of the period becomes a rule from that period |

`repeatFrom` ends the category's existing rules the day before the
period, and removes rules that start at or after it. Their generated
rows from the period on move to the new rule with the new amount, or
are removed where the new rule doesn't cover that period. Rows set by
hand stay. The new rule takes over the old watermark.

`stopRepeating` ends the rules the same way and soft-deletes their
generated rows from the given period on.

### Categories, backup, sync

- A category with rules counts as in use, so deleting it is refused.
- Merging moves the source's rules to the target. If the target has
  rules of its own, the amount of the source's newest rule is added to
  each of them, the same way merged period amounts are added up. Merged
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

**Totals.** Budgeted, Spent, Planned and Left on the summary card cover
budgets of the period only, with a note when windowed budgets are on the
board. Spending of a category with a window budget does not count as
"spent in categories without a budget".

**Shares** (`windowShare`, `windowTargets`). In envelope mode a window's
amount is assigned evenly to the budget periods it covers: a window
longer than the budget period is spread over the periods starting inside
it (a yearly budget gives each month 1/12, leftover cents to the first
months), a shorter one counts fully in the period it starts in (each week
in its month). The envelope carry along the chain (`syncChain`) adds the
same shares. The forecast's "variable spending = budget" method gets the
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
