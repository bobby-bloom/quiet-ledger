import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/features/accounts/data/reconciliation.dart';

/// The account shown in the detail pane of the expanded list-detail layout.
final selectedAccountProvider = NotifierProvider<SelectedAccount, String?>(
  SelectedAccount.new,
);

class SelectedAccount extends Notifier<String?> {
  @override
  String? build() => null;

  // A method reads better than a setter at call sites (`.select(id)`).
  // ignore: use_setters_to_change_properties
  void select(String? id) => state = id;
}

/// Whether archived accounts are listed (session only).
final showArchivedAccountsProvider = NotifierProvider<ShowArchived, bool>(
  ShowArchived.new,
);

class ShowArchived extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// Recorded balances of an account as of a date (reconciliation).
final recordedBalanceProvider = StreamProvider.autoDispose
    .family<RecordedBalance, (String, DateTime)>(
      (ref, key) => ref
          .watch(reconciliationServiceProvider)
          .watchRecorded(key.$1, key.$2),
    );

/// Pending transactions of an account up to a date (reconciliation).
final pendingTransactionsProvider = StreamProvider.autoDispose
    .family<List<Txn>, (String, DateTime)>(
      (ref, key) =>
          ref.watch(reconciliationServiceProvider).watchPending(key.$1, key.$2),
    );
