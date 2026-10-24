// Writes the backup compatibility fixture for the current app version:
//
//   flutter test tool/backup_fixture/backup_fixture_test.dart
//
// Output: test/fixtures/bundles/v<MAJOR.MINOR.PATCH>.zip. Run once per
// release (see docs/VERSIONING.md); existing fixtures are never
// overwritten, because every released format must stay restorable
// (`test/features/export/backup_invariants_test.dart`). Not part of the
// regular test suite.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/app_version.dart';
import 'package:personal_finance/features/export/data/bundle_service.dart';

import '../../test/features/export/export_fixtures.dart';
import '../../test/helpers/test_app.dart';

void main() {
  test('write backup fixture', () async {
    final file = File('test/fixtures/bundles/v$appVersionName.zip');
    if (file.existsSync()) {
      markTestSkipped('${file.path} exists; fixtures are immutable');
      return;
    }
    final db = newTestDb();
    addTearDown(db.close);
    await seed(db);
    await fillEveryColumn(db);
    final bytes = await exportBundle(
      db,
      deviceId: 'fixture-device',
      now: DateTime.utc(2026, 10, 24, 12),
    );
    readBundle(db, bytes);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    // Tool output for the developer running it.
    // ignore: avoid_print
    print('Wrote ${file.path} (${bytes.length} bytes)');
  });
}
