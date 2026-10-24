import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/rules/data/rule_repository.dart';
import 'package:personal_finance/features/rules/domain/rule_engine.dart';
import 'package:personal_finance/features/rules/domain/rule_model.dart';
import 'package:personal_finance/features/rules/domain/rule_service.dart';

/// [RuleService] backed by the `rules` table.
class DbRuleService implements RuleService {
  DbRuleService(this.rules, this.ledger);

  final RuleRepository rules;
  final LedgerRepository ledger;

  AppDatabase get _db => ledger.db;

  Future<RuleEngine> _engine(RuleTrigger? trigger) async {
    final all = await rules.all();
    return RuleEngine(
      all.where(
        (r) => switch (trigger) {
          RuleTrigger.entry => r.applyOnEntry,
          RuleTrigger.import => r.applyOnImport,
          null => true,
        },
      ),
    );
  }

  @override
  Future<TxnDraft> apply(
    TxnDraft draft, {
    required RuleTrigger trigger,
  }) async => (await applyAll([draft], trigger: trigger)).single;

  @override
  Future<List<TxnDraft>> applyAll(
    List<TxnDraft> drafts, {
    required RuleTrigger trigger,
  }) async {
    if (drafts.isEmpty) return drafts;
    final engine = await _engine(trigger);
    if (engine.rules.isEmpty) return drafts;
    return [
      for (final d in drafts)
        if (trigger == RuleTrigger.import &&
            (d.categoryId != null || d.isTransfer || d.isSplit))
          d
        else
          engine.apply(d).draft,
    ];
  }

  @override
  Future<RerunPreview> previewRerun({bool onlyUncategorised = true}) async {
    final engine = await _engine(null);
    if (engine.rules.isEmpty) return RerunPreview.empty;
    final candidates = await _candidates(onlyUncategorised: onlyUncategorised);
    final mode = onlyUncategorised
        ? RuleApplyMode.fillEmpty
        : RuleApplyMode.overwrite;
    final changes = <RerunChange>[];
    for (final (id, draft) in candidates) {
      final outcome = engine.apply(draft, mode: mode);
      if (outcome.hasChanges) {
        changes.add(RerunChange(id, draft, outcome.draft));
      }
    }
    return RerunPreview(
      scanned: candidates.length,
      changes: changes,
      ruleCount: engine.rules.length,
    );
  }

  @override
  Future<int> rerunRules({bool onlyUncategorised = true}) async {
    final preview = await previewRerun(onlyUncategorised: onlyUncategorised);
    if (preview.changes.isEmpty) return 0;
    await ledger.writer.transaction(() async {
      for (final c in preview.changes) {
        await ledger.update(c.txnId, c.after);
      }
    });
    return preview.changedCount;
  }

  /// Live, non-transfer, non-split transactions as drafts.
  Future<List<(String, TxnDraft)>> _candidates({
    required bool onlyUncategorised,
  }) async {
    final splitIds = {
      for (final r
          in await (_db.selectOnly(_db.transactionSplits)
                ..addColumns([_db.transactionSplits.transactionId])
                ..where(_db.transactionSplits.deletedAt.isNull()))
              .get())
        r.read(_db.transactionSplits.transactionId)!,
    };
    final query = _db.select(_db.transactions)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.transferPeerId.isNull() &
            t.type.equalsValue(TxnType.transfer).not(),
      );
    if (onlyUncategorised) query.where((t) => t.categoryId.isNull());
    final rows = (await query.get())
        .where((t) => !splitIds.contains(t.id))
        .toList();
    if (rows.isEmpty) return const [];

    final tags = <String, List<String>>{};
    for (final t in await (_db.select(
      _db.transactionTags,
    )..where((x) => x.deletedAt.isNull())).get()) {
      (tags[t.transactionId] ??= []).add(t.tagId);
    }
    final fields = <String, Map<String, Object?>>{};
    for (final v in await (_db.select(
      _db.customFieldValues,
    )..where((x) => x.deletedAt.isNull())).get()) {
      Object? value;
      try {
        value = jsonDecode(v.value);
      } on FormatException {
        value = v.value;
      }
      (fields[v.entityId] ??= {})[v.fieldId] = value;
    }
    return [
      for (final t in rows)
        (
          t.id,
          TxnDraft(
            accountId: t.accountId,
            amountMinor: t.amountMinor,
            date: t.date,
            type: t.type,
            valueDate: t.valueDate,
            payee: t.payee,
            note: t.note,
            categoryId: t.categoryId,
            status: t.status,
            tagIds: tags[t.id] ?? const [],
            customFields: fields[t.id] ?? const {},
            recurringRuleId: t.recurringRuleId,
            importBatchId: t.importBatchId,
            importRowRef: t.importRowRef,
            dedupeHash: t.dedupeHash,
            currency: t.currency,
          ),
        ),
    ];
  }

  /// Applies an unsaved [rule] alone to [draft] (the editor's live test).
  static RuleOutcome test(RuleDef rule, TxnDraft draft) =>
      RuleEngine([rule.copyWith(enabled: true)]).apply(draft);
}
