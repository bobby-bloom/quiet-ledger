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
covered). Without a limit it repeats until changed. `cadence` is always
`period` for now, meaning the rule follows the global budget period
setting. Other values are reserved for budgets with their own length
(week, month, quarter, year).

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
