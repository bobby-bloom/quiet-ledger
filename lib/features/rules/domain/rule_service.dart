import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/rules/data/db_rule_service.dart';
import 'package:personal_finance/features/rules/data/rule_repository.dart';

/// When rules are applied (PLAN.md §2.1).
enum RuleTrigger { entry, import }

/// One transaction that a re-run would change.
@immutable
class RerunChange {
  const RerunChange(this.txnId, this.before, this.after);

  final String txnId;
  final TxnDraft before;
  final TxnDraft after;
}

/// What "re-run rules" would do (Settings › Data).
@immutable
class RerunPreview {
  const RerunPreview({
    required this.scanned,
    required this.changes,
    required this.ruleCount,
  });

  static const empty = RerunPreview(scanned: 0, changes: [], ruleCount: 0);

  /// Transactions looked at.
  final int scanned;

  /// Transactions that would change.
  final List<RerunChange> changes;

  /// Enabled rules taking part.
  final int ruleCount;

  int get changedCount => changes.length;
}

/// Applies auto-categorisation rules to drafts.
///
/// Callers: quick add (trigger: entry, only fills empty fields), the import
/// pipeline (trigger: import, only rows without a category) and
/// Settings › Data › Re-run rules.
abstract interface class RuleService {
  /// Returns [draft] with rule actions applied. Rules only fill fields the
  /// user has not set unless the rule is marked to overwrite.
  Future<TxnDraft> apply(TxnDraft draft, {required RuleTrigger trigger});

  /// Applies to many drafts at once (loads the rules once). With
  /// [RuleTrigger.import] only drafts without a category are touched.
  Future<List<TxnDraft>> applyAll(
    List<TxnDraft> drafts, {
    required RuleTrigger trigger,
  });

  /// Computes what [rerunRules] would change without writing anything.
  ///
  /// With [onlyUncategorised] only transactions without a category are
  /// considered and only empty fields are filled; otherwise every
  /// (non-transfer, non-split) transaction is re-evaluated and rule values
  /// replace existing ones.
  Future<RerunPreview> previewRerun({bool onlyUncategorised = true});

  /// Re-runs all enabled rules on existing transactions in one DB
  /// transaction. Returns the number of changed transactions.
  Future<int> rerunRules({bool onlyUncategorised = true});
}

class NoopRuleService implements RuleService {
  const NoopRuleService();

  @override
  Future<TxnDraft> apply(
    TxnDraft draft, {
    required RuleTrigger trigger,
  }) async => draft;

  @override
  Future<List<TxnDraft>> applyAll(
    List<TxnDraft> drafts, {
    required RuleTrigger trigger,
  }) async => drafts;

  @override
  Future<RerunPreview> previewRerun({bool onlyUncategorised = true}) async =>
      RerunPreview.empty;

  @override
  Future<int> rerunRules({bool onlyUncategorised = true}) async => 0;
}

final ruleServiceProvider = Provider<RuleService>(
  (ref) => DbRuleService(
    ref.watch(ruleRepositoryProvider),
    ref.watch(ledgerRepositoryProvider),
  ),
);
