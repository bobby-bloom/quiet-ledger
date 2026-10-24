import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:personal_finance/app/bootstrap.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_files_io.dart';
import 'package:sqlite3/sqlite3.dart';

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

    test(
      'pre-migration copy is byte-identical and keeps the newest 3',
      () async {
        db(tmp.path).writeAsBytesSync([9, 8, 7]);
        db(tmp.path, '-wal').writeAsBytesSync([6]);
        String? last;
        for (var m = 0; m < 5; m++) {
          last = await copyDatabaseBeforeMigration(
            label: 'v2',
            supportDirectory: tmp.path,
            now: DateTime(2026, 10, 24, 9, m),
          );
        }
        expect(db(last!).readAsBytesSync(), [9, 8, 7]);
        expect(db(last, '-wal').readAsBytesSync(), [6]);
        // The original stays in place.
        expect(db(tmp.path).readAsBytesSync(), [9, 8, 7]);
        final copies = [
          for (final d in Directory(p.join(tmp.path, 'safety')).listSync())
            p.basename(d.path),
        ]..sort();
        expect(copies, [
          'pre-migration-v2-20261024-090200',
          'pre-migration-v2-20261024-090300',
          'pre-migration-v2-20261024-090400',
        ]);
      },
    );

    void writeDb(int version, {String? key, bool wal = false}) {
      final raw = sqlite3.open(db(tmp.path).path);
      if (key != null) raw.execute("PRAGMA key = \"x'$key'\"");
      if (wal) raw.execute('PRAGMA journal_mode = WAL');
      raw
        ..execute('CREATE TABLE t (x)')
        ..execute('PRAGMA user_version = $version');
      if (!wal) {
        raw.close();
        return;
      }
      // Keep the WAL: write through a second connection and leave it open
      // while the first one closes, so no checkpoint removes the -wal file.
      final other = sqlite3.open(db(tmp.path).path);
      if (key != null) other.execute("PRAGMA key = \"x'$key'\"");
      other.execute('INSERT INTO t VALUES (1)');
      raw.close();
      addTearDown(other.close);
    }

    test('reads the schema version from the file itself', () async {
      expect(await readDatabaseFileVersion(supportDirectory: tmp.path), isNull);
      writeDb(2);
      expect(await readDatabaseFileVersion(supportDirectory: tmp.path), 2);
    });

    test('a damaged file has no version, nothing is changed', () async {
      db(tmp.path).writeAsBytesSync(List.filled(4096, 7));
      expect(await readDatabaseFileVersion(supportDirectory: tmp.path), isNull);
      expect(db(tmp.path).readAsBytesSync(), List.filled(4096, 7));
    });

    test('reading the version leaves the WAL in place', () async {
      writeDb(2, wal: true);
      final wal = db(tmp.path, '-wal');
      expect(wal.existsSync(), isTrue);
      final before = wal.readAsBytesSync();
      expect(await readDatabaseFileVersion(supportDirectory: tmp.path), 2);
      expect(wal.readAsBytesSync(), before);
    });

    test('an encrypted file needs its key', () async {
      final probe = sqlite3.openInMemory();
      final hasCipher = probe.select('PRAGMA cipher').isNotEmpty;
      probe.close();
      if (!hasCipher) {
        markTestSkipped('SQLite build without encryption');
        return;
      }
      const key =
          '00112233445566778899aabbccddeeff'
          '00112233445566778899aabbccddeeff';
      writeDb(2, key: key);
      expect(
        await readDatabaseFileVersion(
          supportDirectory: tmp.path,
          encryptionKey: key,
        ),
        2,
      );
      expect(await readDatabaseFileVersion(supportDirectory: tmp.path), isNull);
    });

    test('the file version decides about the pre-migration copy', () {
      const current = AppDatabase.currentSchemaVersion;
      // An older file under a preference that says "up to date".
      expect(
        needsPreMigrationCopy(fileVersion: current - 1, opened: current),
        isTrue,
      );
      expect(
        needsPreMigrationCopy(fileVersion: current, opened: current - 1),
        isFalse,
      );
      // Newer files are refused, never migrated; empty ones have nothing.
      expect(
        needsPreMigrationCopy(fileVersion: current + 1, opened: null),
        isFalse,
      );
      expect(needsPreMigrationCopy(fileVersion: 0, opened: null), isFalse);
      // Unreadable or no file: the preference decides.
      expect(needsPreMigrationCopy(fileVersion: null, opened: null), isTrue);
      expect(
        needsPreMigrationCopy(fileVersion: null, opened: current - 1),
        isTrue,
      );
      expect(
        needsPreMigrationCopy(fileVersion: null, opened: current),
        isFalse,
      );
    });

    test('no database file: nothing to do', () async {
      expect(await quarantineDatabaseFiles(supportDirectory: tmp.path), isNull);
    });
  });
}
