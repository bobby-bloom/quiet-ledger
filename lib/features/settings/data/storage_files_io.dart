import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:personal_finance/core/db/database.dart';

/// File name used by `openAppConnection` (drift_flutter: `<name>.sqlite`).
const databaseFileName = '$appDbName.sqlite';

Future<String?> defaultDbDirectory() async =>
    (await getApplicationSupportDirectory()).path;

Future<bool> databaseExistsIn(String dir) async =>
    File(p.join(dir, databaseFileName)).existsSync();

/// Checkpoints the WAL into the main file, then copies it to [toDir]. The
/// copy keeps the encryption (same file, same key).
Future<void> copyDatabaseTo(
  AppDatabase db,
  String fromDir,
  String toDir,
) async {
  await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  await Directory(toDir).create(recursive: true);
  final src = File(p.join(fromDir, databaseFileName));
  final target = p.join(toDir, databaseFileName);
  final tmp = File('$target.tmp');
  await src.copy(tmp.path);
  await tmp.rename(target);
}

Future<int?> databaseFileSize(String? dir) async {
  if (dir == null) return null;
  var total = 0;
  for (final suffix in ['', '-wal']) {
    final f = File(p.join(dir, '$databaseFileName$suffix'));
    if (f.existsSync()) total += f.lengthSync();
  }
  return total;
}
