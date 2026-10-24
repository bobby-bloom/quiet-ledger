import 'dart:async';

import 'package:personal_finance/core/sync/change.dart';
import 'package:personal_finance/core/sync/hlc.dart';

/// Transport for replicated changes (PLAN.md §4.3). v1 ships no real
/// backend; [NoopSyncBackend] is the default and [InMemorySyncBackend] is
/// used by tests and dev tools.
///
/// Contract:
/// * [push] stores changes durably. It must be idempotent: pushing a change
///   with the same [Change.key] again has no effect (the engine retries
///   after failures).
/// * [pull] emits every change the backend has *received* after the
///   position `since`, setting [Change.received] to the change's position in
///   the backend's log (positions are only compared with positions from the
///   same backend). The first pull uses `Hlc.zero`. Changes pushed by the
///   pulling device itself may be included; the engine skips them.
/// * [id] is stable per backend/account and keys `sync_state`.
abstract interface class SyncBackend {
  String get id;

  Future<void> push(List<Change> changes);

  Stream<Change> pull(Hlc since);
}

/// No sync configured (v1 default). Pushes are dropped, pulls are empty.
class NoopSyncBackend implements SyncBackend {
  const NoopSyncBackend();

  @override
  String get id => 'noop';

  @override
  Future<void> push(List<Change> changes) async {}

  @override
  Stream<Change> pull(Hlc since) => const Stream.empty();
}

/// A shared in-memory change log. Several devices (each with its own
/// database and `SyncEngine`) syncing through the same instance behave like
/// clients of one server.
///
/// [deliver] can reorder the changes of one pull to simulate out-of-order
/// delivery (default: arrival order).
class InMemorySyncBackend implements SyncBackend {
  InMemorySyncBackend({this.id = 'memory', this.deliver});

  @override
  final String id;

  /// Reorders the changes of one pull (simulates out-of-order delivery).
  final List<Change> Function(List<Change> changes)? deliver;
  final List<Change> _log = [];
  final Set<String> _keys = {};

  /// Number of [push] calls (for tests).
  int pushCalls = 0;

  /// All stored changes in arrival order (with [Change.received] set).
  List<Change> get log => List.unmodifiable(_log);

  @override
  Future<void> push(List<Change> changes) async {
    pushCalls++;
    for (final c in changes) {
      if (!_keys.add(c.key)) continue;
      _log.add(c.withReceived(Hlc(_log.length + 1, 0, id)));
    }
  }

  @override
  Stream<Change> pull(Hlc since) {
    final pending = [
      for (final c in _log)
        if (c.received! > since) c,
    ];
    return Stream.fromIterable(deliver?.call(pending) ?? pending);
  }

  /// Removes everything (tests).
  void clear() {
    _log.clear();
    _keys.clear();
  }
}
