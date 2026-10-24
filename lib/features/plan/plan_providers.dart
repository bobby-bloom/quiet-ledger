import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';

/// Today's date (local midnight). Overridden in tests for deterministic
/// periods, due lists and projections.
final planTodayProvider = Provider<DateTime>((ref) => dateOnly(DateTime.now()));
