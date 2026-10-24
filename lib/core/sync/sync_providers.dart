import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/sync/sync_backend.dart';
import 'package:personal_finance/core/sync/sync_engine.dart';

/// The configured sync backend. v1 ships none: always [NoopSyncBackend]
/// (PLAN.md decision #4). Override in tests or dev tools.
final syncBackendProvider = Provider<SyncBackend>(
  (ref) => const NoopSyncBackend(),
);

/// Whether a real backend is configured. Tombstones are purged only when
/// this is false.
final syncConfiguredProvider = Provider<bool>(
  (ref) => ref.watch(syncBackendProvider) is! NoopSyncBackend,
);

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    db: ref.watch(databaseProvider),
    clock: ref.watch(hlcClockProvider),
    deviceId: ref.watch(deviceIdProvider),
    backend: ref.watch(syncBackendProvider),
  ),
);
