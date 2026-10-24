# Budgets

How a budget line is calculated: what counts as spent, what is shown as
outstanding, and how rollover and the envelope "left to assign" use them.
Read this before changing budget maths or the queries behind it.

Code lives in `lib/features/budgets/` (`data/budgets_repository.dart`,
`data/budget_providers.dart`, `domain/budget_math.dart`,
`domain/outstanding.dart`) and `lib/core/calendar/budget_period.dart`
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
