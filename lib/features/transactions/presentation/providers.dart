import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/transactions/data/entry_repository.dart';
import 'package:personal_finance/features/transactions/data/saved_filters_repository.dart';
import 'package:personal_finance/features/transactions/data/txn_list_repository.dart';
import 'package:personal_finance/features/transactions/domain/txn_filter.dart';

/// The latest `limit` transactions (newest first, transfers once), live.
/// For the dashboard's "Recent transactions" widget; render rows with
/// `TransactionTile`. The family argument is the number of rows.
final recentTransactionsProvider =
    StreamProvider.family<List<TxnListItem>, int>(
      (ref, limit) => ref
          .watch(txnListRepositoryProvider)
          .watch(TxnFilter.empty, limit: limit),
    );

/// Count and in/out totals for a filter, live.
final txnTotalsProvider = StreamProvider.family<TxnTotals, TxnFilter>(
  (ref, filter) => ref.watch(txnListRepositoryProvider).watchTotals(filter),
);

/// Ids of recently used categories (Settings › Entry › recent categories).
final recentCategoryIdsProvider = StreamProvider<List<String>>((ref) {
  final n = ref.watch(
    settingsProvider.select((s) => s.get(EntrySettings.recentCategories)),
  );
  return ref.watch(entryRepositoryProvider).watchRecentCategories(limit: n);
});

/// Everything the detail view shows about one transaction.
@immutable
class TxnDetail {
  const TxnDetail({
    required this.txn,
    required this.splits,
    required this.tagIds,
    required this.customFields,
    this.peer,
    this.recurringRuleName,
    this.importFileName,
  });

  final Txn txn;

  /// The other leg of a transfer.
  final Txn? peer;
  final List<TxnSplit> splits;
  final List<String> tagIds;
  final Map<String, Object?> customFields;
  final String? recurringRuleName;
  final String? importFileName;

  bool get isTransfer => txn.transferPeerId != null;

  /// Id edits are applied to (outgoing leg for transfers).
  String get editId =>
      isTransfer && txn.amountMinor > 0 ? txn.transferPeerId! : txn.id;
}

/// Live detail of transaction `id`; null when it was deleted.
final txnDetailProvider = StreamProvider.family<TxnDetail?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  final ledger = ref.watch(ledgerRepositoryProvider);
  final changes = ref.watch(txnListRepositoryProvider).changes();

  Future<TxnDetail?> load() async {
    final t = await ledger.txnById(id);
    if (t == null) return null;
    final peer = t.transferPeerId == null
        ? null
        : await ledger.txnById(t.transferPeerId!);
    String? ruleName;
    if (t.recurringRuleId != null) {
      final r = await (db.select(
        db.recurringRules,
      )..where((x) => x.id.equals(t.recurringRuleId!))).getSingleOrNull();
      ruleName = r?.name;
    }
    String? fileName;
    if (t.importBatchId != null) {
      final b = await (db.select(
        db.importBatches,
      )..where((x) => x.id.equals(t.importBatchId!))).getSingleOrNull();
      fileName = b?.fileName;
    }
    return TxnDetail(
      txn: t,
      peer: peer,
      splits: await ledger.splitsFor(t.id),
      tagIds: await ledger.tagIdsFor(t.id),
      customFields: await ledger.customFieldsFor(t.id),
      recurringRuleName: ruleName,
      importFileName: fileName,
    );
  }

  final controller = StreamController<TxnDetail?>();
  var disposed = false;
  Future<void> emit() async {
    try {
      final d = await load();
      if (!disposed) controller.add(d);
    } on Object catch (e, st) {
      if (!disposed) controller.addError(e, st);
    }
  }

  unawaited(emit());
  final sub = changes.listen((_) => emit());
  ref.onDispose(() {
    disposed = true;
    unawaited(sub.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
});

/// State of the main transaction screen: the active filter and, when it
/// came from a saved filter, that filter's id.
@immutable
class TxnScreenState {
  const TxnScreenState({this.filter = TxnFilter.empty, this.savedFilterId});

  final TxnFilter filter;
  final String? savedFilterId;
}

final txnScreenProvider = NotifierProvider<TxnScreenController, TxnScreenState>(
  TxnScreenController.new,
);

/// Holds the main list's filter for the session. Starts with the default
/// saved filter (Settings › Transactions › Default filter).
class TxnScreenController extends Notifier<TxnScreenState> {
  var _touched = false;

  @override
  TxnScreenState build() {
    final defaultId = ref
        .read(settingsProvider)
        .get(TransactionSettings.defaultFilterId);
    if (defaultId != null) unawaited(_loadDefault(defaultId));
    return const TxnScreenState();
  }

  Future<void> _loadDefault(String id) async {
    final f = await ref.read(savedFiltersRepositoryProvider).byId(id);
    if (f == null || _touched) return;
    state = TxnScreenState(filter: decodeSavedFilter(f), savedFilterId: f.id);
  }

  void setFilter(TxnFilter filter) {
    _touched = true;
    final keepSaved = state.savedFilterId != null && filter == state.filter;
    state = TxnScreenState(
      filter: filter,
      savedFilterId: keepSaved ? state.savedFilterId : null,
    );
  }

  void setSearch(String search) =>
      setFilter(state.filter.copyWith(search: search));

  void applySaved(SavedFilter f) {
    _touched = true;
    state = TxnScreenState(filter: decodeSavedFilter(f), savedFilterId: f.id);
  }

  /// Marks [id] as the source of the current filter (after saving it).
  void markSaved(String id) =>
      state = TxnScreenState(filter: state.filter, savedFilterId: id);

  void clear() {
    _touched = true;
    state = const TxnScreenState();
  }
}

/// Number of transactions matching a saved filter (sidebar badges).
final txnCountProvider = StreamProvider.family<int, TxnFilter>(
  (ref, filter) => ref.watch(txnListRepositoryProvider).watchCount(filter),
);

/// Tags that are not archived, for pickers.
final activeTagsProvider = StreamProvider<List<Tag>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.tags)
        ..where((t) => t.deletedAt.isNull() & t.archived.equals(false))
        ..orderBy([(t) => OrderingTerm(expression: t.name)]))
      .watch();
});
