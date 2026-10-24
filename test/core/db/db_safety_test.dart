import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_files_io.dart';

void main() {
  test('a newer database file is refused, not downgraded', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA user_version = 99'),
      ),
    );
    addTearDown(db.close);
    await expectLater(
      db.customSelect('SELECT 1').get(),
      throwsA(isA<NewerDatabaseException>()),
    );
  });

  group('quarantineDatabaseFiles', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('pf_quarantine'));
    tearDown(() => tmp.deleteSync(recursive: true));

    File db(String dir, [String suffix = '']) =>
        File(p.join(dir, '$appDbName.sqlite$suffix'));

    test('moves the file and its WAL, keeping the bytes', () async {
      db(tmp.path).writeAsBytesSync([1, 2, 3]);
      db(tmp.path, '-wal').writeAsBytesSync([4]);
      final to = await quarantineDatabaseFiles(
        supportDirectory: tmp.path,
        now: DateTime(2026, 10, 24, 9),
      );
      expect(to, p.join(tmp.path, 'unreadable', '20261024-090000'));
      expect(db(tmp.path).existsSync(), isFalse);
      expect(db(to!).readAsBytesSync(), [1, 2, 3]);
      expect(db(to, '-wal').readAsBytesSync(), [4]);
    });

    test('never overwrites an earlier quarantine', () async {
      final at = DateTime(2026, 10, 24, 9);
      db(tmp.path).writeAsBytesSync([1]);
      final first = await quarantineDatabaseFiles(
        supportDirectory: tmp.path,
        now: at,
      );
      db(tmp.path).writeAsBytesSync([2]);
      final second = await quarantineDatabaseFiles(
        supportDirectory: tmp.path,
        now: at,
      );
      expect(second, isNot(first));
      expect(db(first!).readAsBytesSync(), [1]);
      expect(db(second!).readAsBytesSync(), [2]);
    });

    test('no database file: nothing to do', () async {
      expect(await quarantineDatabaseFiles(supportDirectory: tmp.path), isNull);
    });
  });
}
