import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:personal_finance/core/db/database.dart';

/// Whether database files can be moved aside on this platform.
const bool canQuarantineDatabase = true;

const _suffixes = ['', '-wal', '-shm', '-journal'];

/// Moves the database files (`<name>.sqlite` plus WAL/SHM/journal) from
/// [directory] (default: app support) into
/// `<app support>/unreadable/<yyyyMMdd-HHmmss>/`, so a fresh database can
/// be created without deleting anything. Returns the new folder, or null
/// when there was no database file. [supportDirectory] overrides the app
/// support directory (tests).
Future<String?> quarantineDatabaseFiles({
  String? directory,
  DateTime? now,
  String? supportDirectory,
}) async {
  final support =
      supportDirectory ?? (await getApplicationSupportDirectory()).path;
  final from = directory ?? support;
  final main = File(p.join(from, '$appDbName.sqlite'));
  if (!main.existsSync()) return null;
  final stamp = DateFormat('yyyyMMdd-HHmmss').format(now ?? DateTime.now());
  var to = Directory(p.join(support, 'unreadable', stamp));
  for (var n = 2; to.existsSync(); n++) {
    to = Directory(p.join(support, 'unreadable', '$stamp-$n'));
  }
  await to.create(recursive: true);
  // Copy all files (main, WAL, SHM, journal) and check them before any
  // original is removed, so the set is never split.
  final originals = <File>[];
  for (final s in _suffixes) {
    final f = File(p.join(from, '$appDbName.sqlite$s'));
    if (!f.existsSync()) continue;
    final target = File(p.join(to.path, '$appDbName.sqlite$s'));
    await f.copy(target.path);
    if (target.lengthSync() != f.lengthSync()) {
      throw FileSystemException('Incomplete copy', target.path);
    }
    originals.add(f);
  }
  // Side files first, the main file last.
  for (final f in originals.reversed) {
    await f.delete();
  }
  return to.path;
}

/// Copies the database files in [directory] (default: app support) to
/// `<app support>/safety/pre-migration-<label>-<yyyyMMdd-HHmmss>/` before a
/// schema migration runs. The copy is byte-identical (an encrypted file
/// stays encrypted with the same key). Keeps the newest [keep] copies.
/// Returns the folder, or null when there is no database file yet. Throws
/// when the copy fails, so the migration does not run.
Future<String?> copyDatabaseBeforeMigration({
  required String label,
  String? directory,
  DateTime? now,
  String? supportDirectory,
  int keep = 3,
}) async {
  final support =
      supportDirectory ?? (await getApplicationSupportDirectory()).path;
  final from = directory ?? support;
  if (!File(p.join(from, '$appDbName.sqlite')).existsSync()) return null;
  final stamp = DateFormat('yyyyMMdd-HHmmss').format(now ?? DateTime.now());
  final safety = Directory(p.join(support, 'safety'));
  var to = Directory(p.join(safety.path, 'pre-migration-$label-$stamp'));
  for (var n = 2; to.existsSync(); n++) {
    to = Directory(p.join(safety.path, 'pre-migration-$label-$stamp-$n'));
  }
  await to.create(recursive: true);
  for (final s in _suffixes) {
    final f = File(p.join(from, '$appDbName.sqlite$s'));
    if (!f.existsSync()) continue;
    final target = File(p.join(to.path, '$appDbName.sqlite$s'));
    await f.copy(target.path);
    if (target.lengthSync() != f.lengthSync()) {
      throw FileSystemException('Incomplete copy', target.path);
    }
  }
  // Newest first by the timestamp in the name (`…-<stamp>[-n]`).
  final stampOf = RegExp(r'(\d{8}-\d{6})(?:-(\d+))?$');
  String key(Directory d) {
    final m = stampOf.firstMatch(p.basename(d.path));
    return m == null ? '' : '${m[1]}-${(m[2] ?? '1').padLeft(4, '0')}';
  }

  final old =
      safety
          .listSync()
          .whereType<Directory>()
          .where((d) => p.basename(d.path).startsWith('pre-migration-'))
          .toList()
        ..sort((a, b) => key(b).compareTo(key(a)));
  for (final d in old.skip(keep)) {
    if (d.path != to.path) await d.delete(recursive: true);
  }
  return to.path;
}
