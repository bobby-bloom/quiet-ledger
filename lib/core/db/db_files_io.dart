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
  for (final s in _suffixes) {
    final f = File(p.join(from, '$appDbName.sqlite$s'));
    if (!f.existsSync()) continue;
    final target = p.join(to.path, '$appDbName.sqlite$s');
    try {
      await f.rename(target);
    } on FileSystemException {
      // Other volume: copy, check, then remove the original.
      await f.copy(target);
      if (File(target).lengthSync() != f.lengthSync()) {
        throw FileSystemException('Incomplete copy', target);
      }
      await f.delete();
    }
  }
  return to.path;
}
