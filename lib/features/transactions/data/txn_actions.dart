import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';

final txnActionsProvider = Provider<TxnActions>(
  (ref) => TxnActions(ref.watch(ledgerRepositoryProvider)),
);

/// Drafts of transactions as they were before an edit, keyed by the id the
/// edit must be applied to (the outgoing leg for transfers). Re-applying
/// the snapshot undoes the edit.
typedef TxnSnapshot = Map<String, TxnDraft>;

/// List-level operations with undo support, built on [LedgerRepository].
class TxnActions {
  TxnActions(this.ledger);

  final LedgerRepository ledger;

  /// The id edits of [id] are expressed against: for an incoming transfer
  /// leg this is its peer (the outgoing leg), otherwise [id] itself.
  Future<String?> editableId(String id) async {
    final t = await ledger.txnById(id);
    if (t == null) return null;
    if (t.transferPeerId != null && t.amountMinor > 0) return t.transferPeerId;
    return id;
  }

  /// Captures the current state of [ids] for undo.
  Future<TxnSnapshot> snapshot(Iterable<String> ids) async {
    final out = <String, TxnDraft>{};
    for (final id in ids) {
      final key = await editableId(id);
      if (key == null || out.containsKey(key)) continue;
      final d = await ledger.draftFor(key);
      if (d != null) out[key] = d;
    }
    return out;
  }

  /// Writes [snapshot] back (undo of an edit or bulk edit).
  Future<void> restoreSnapshot(TxnSnapshot snapshot) =>
      ledger.writer.transaction(() async {
        for (final e in snapshot.entries) {
          if (await ledger.txnById(e.key) == null) continue;
          await ledger.update(e.key, e.value);
        }
      });

  /// Soft-deletes [ids] (and transfer peers). Returns the ids to pass to
  /// [undoDelete].
  Future<List<String>> delete(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    await ledger.deleteAll(unique);
    return unique;
  }

  Future<void> undoDelete(Iterable<String> ids) =>
      ledger.writer.transaction(() async {
        for (final id in ids) {
          await ledger.restore(id);
        }
      });

  /// Creates a copy of [id] dated [date] (default today). Import and
  /// recurring bookkeeping is not copied. Returns the new id.
  Future<String?> duplicate(String id, {DateTime? date}) async {
    final key = await editableId(id);
    if (key == null) return null;
    final d = await ledger.draftFor(key);
    if (d == null) return null;
    return await ledger.create(
      d.copyWith(
        date: dateOnly(date ?? DateTime.now()),
        recurringRuleId: null,
        importBatchId: null,
        importRowRef: null,
        dedupeHash: null,
      ),
    );
  }

  /// Toggles between cleared and pending (planned becomes cleared).
  Future<TxnSnapshot> toggleCleared(String id) async {
    final t = await ledger.txnById(id);
    if (t == null) return const {};
    final snap = await snapshot([id]);
    await ledger.bulkUpdate(
      [id],
      status: t.status == TxnStatus.cleared
          ? TxnStatus.pending
          : TxnStatus.cleared,
    );
    return snap;
  }

  /// Bulk edit; returns the snapshot for undo.
  Future<TxnSnapshot> bulkUpdate(
    Iterable<String> ids, {
    String? categoryId,
    TxnStatus? status,
    DateTime? date,
    String? accountId,
    List<String>? addTagIds,
  }) async {
    final list = ids.toList();
    final snap = await snapshot(list);
    await ledger.writer.transaction(() async {
      if (categoryId != null) {
        // A split transaction becomes a single-category one; the generic
        // bulk update would leave its split lines in place.
        for (final e in snap.entries.where((e) => e.value.isSplit)) {
          await ledger.update(
            e.key,
            e.value.copyWith(categoryId: categoryId, splits: const []),
          );
        }
      }
      await ledger.bulkUpdate(
        list,
        categoryId: categoryId,
        status: status,
        date: date,
        accountId: accountId,
        addTagIds: addTagIds,
      );
    });
    return snap;
  }
}
