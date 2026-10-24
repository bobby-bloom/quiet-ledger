import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:personal_finance/core/attachments/attachment_files_io.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/features/transactions/data/attachment_paths.dart';

import '../../features/export/export_fixtures.dart';
import '../../helpers/test_app.dart';

void main() {
  late Directory tmp;
  late String dir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pf_attachments');
    dir = p.join(tmp.path, 'attachments');
    attachmentsDirectoryOverride = dir;
  });

  tearDown(() {
    attachmentsDirectoryOverride = null;
    tmp.deleteSync(recursive: true);
  });

  test('stores a relative name and never overwrites', () async {
    final a = await writeAttachmentFile('Beleg 1.png', Uint8List.fromList([1]));
    final b = await writeAttachmentFile('Beleg 1.png', Uint8List.fromList([2]));
    expect(p.isAbsolute(a!), isFalse);
    expect(a, isNot(b));
    expect(await readAttachmentFile(a), [1]);
    expect(await readAttachmentFile(b!), [2]);
  });

  test(
    'old absolute paths still resolve, also after the folder moved',
    () async {
      final name = await writeAttachmentFile('x.png', Uint8List.fromList([7]));
      final absolute = p.join(dir, name);
      expect(await readAttachmentFile(absolute), [7]);
      // iOS: the container path changed, the file is in the new folder.
      final moved = p.join('/var/old-container/attachments', name);
      expect(await resolveAttachmentPath(moved), absolute);
      expect(await relativeAttachmentPath(moved), name);
      expect(await relativeAttachmentPath(name!), isNull);
      expect(await resolveAttachmentPath('/nowhere/y.png'), isNull);
    },
  );

  test('migration rewrites only paths whose file is found', () async {
    final db = newTestDb();
    addTearDown(db.close);
    final w = SyncWriter(db, testClock(), 'dev-1');
    final f = await seed(db, writer: w);
    final name = await writeAttachmentFile('x.png', Uint8List.fromList([7]));
    Future<String> attach(String path) => w.insert(
      db.attachments,
      AttachmentsCompanion(
        transactionId: Value(f.expense),
        fileName: const Value('x.png'),
        filePath: Value(path),
        mimeType: const Value('image/png'),
      ),
    );
    final found = await attach(p.join(dir, name));
    final lost = await attach('/elsewhere/lost.png');

    expect(await migrateAttachmentPaths(db, w), 1);
    expect(await migrateAttachmentPaths(db, w), 0);
    final rows = {
      for (final a in await db.select(db.attachments).get()) a.id: a,
    };
    expect(rows[found]!.filePath, name);
    expect(rows[lost]!.filePath, '/elsewhere/lost.png');
  });
}
