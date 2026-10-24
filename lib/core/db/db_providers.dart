import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/sync/hlc.dart';

/// The open app database. Overridden in `main()` (and in tests) with the
/// instance opened during bootstrap.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// This device's stable id (also the HLC node id). Overridden at bootstrap.
final deviceIdProvider = Provider<String>(
  (ref) => throw UnimplementedError('deviceIdProvider must be overridden'),
);

final hlcClockProvider = Provider<HlcClock>(
  (ref) => throw UnimplementedError('hlcClockProvider must be overridden'),
);

/// The single write path for synced tables.
final syncWriterProvider = Provider<SyncWriter>(
  (ref) => SyncWriter(
    ref.watch(databaseProvider),
    ref.watch(hlcClockProvider),
    ref.watch(deviceIdProvider),
  ),
);

/// Restores the clock so new HLCs are greater than any stored one.
Future<HlcClock> restoreClock(AppDatabase db, String deviceId) async {
  final max = db.changeLog.hlc.max();
  final row = await (db.selectOnly(
    db.changeLog,
  )..addColumns([max])).getSingle();
  final last = row.read(max);
  return HlcClock(deviceId, last: last == null ? null : Hlc.parse(last));
}

/// Convenience to override all DB-related providers, e.g. in tests:
/// `ProviderScope(overrides: dbOverrides(db, 'test-device'))`.
List<Override> dbOverrides(
  AppDatabase db,
  String deviceId, {
  HlcClock? clock,
}) => [
  databaseProvider.overrideWithValue(db),
  deviceIdProvider.overrideWithValue(deviceId),
  hlcClockProvider.overrideWithValue(clock ?? HlcClock(deviceId)),
];
