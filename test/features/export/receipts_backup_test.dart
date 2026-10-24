import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/attachments/receipt_store.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/features/export/data/bundle_service.dart';
import 'package:personal_finance/features/export/domain/bundle_manifest.dart';

import '../../helpers/test_app.dart';
import 'export_fixtures.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;
  late SyncWriter w;
  late Fixture f;
  late MemoryReceiptStore sourceFiles;

  final png = Uint8List.fromList(List.generate(300, (i) => i % 256));
  final pdf = Uint8List.fromList(utf8.encode('%PDF-1.7 receipt'));

  Future<String> attach(String path, {String name = 'beleg.png'}) => w.insert(
    source.attachments,
    AttachmentsCompanion(
      transactionId: Value(f.expense),
      fileName: Value(name),
      filePath: Value(path),
      mimeType: const Value('image/png'),
      sizeBytes: const Value(1),
    ),
  );

  setUp(() async {
    source = newTestDb();
    target = newTestDb();
    w = SyncWriter(source, testClock(), 'dev-1');
    f = await seed(source, writer: w);
    sourceFiles = MemoryReceiptStore()
      ..files['a_beleg.png'] = png
      ..files['b_rechnung.pdf'] = pdf;
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<Uint8List> export() =>
      exportBundle(source, deviceId: 'dev-1', receipts: sourceFiles);

  Future<List<Attachment>> attachmentsOf(AppDatabase db) => (db.select(
    db.attachments,
  )..orderBy([(a) => OrderingTerm(expression: a.id)])).get();

  test('receipt files are in the bundle, shared files once', () async {
    final a = await attach('a_beleg.png');
    final b = await attach('b_rechnung.pdf', name: 'rechnung.pdf');
    final copy = await attach('a_beleg.png'); // duplicated transaction
    final gone = await attach('b_rechnung.pdf', name: 'rechnung.pdf');
    await w.delete(source.attachments, gone); // tombstone keeps its file

    final zip = await export();
    final m = readBundle(source, zip).manifest;
    expect(m.files.keys, containsAll([a, b, copy, gone]));
    expect(m.files[a]!.file, m.files[copy]!.file);
    expect(m.fileCount, 2);
    expect(m.fileBytes, png.length + pdf.length);
    expect(m.missingFiles, isEmpty);

    final entries = ZipDecoder().decodeBytes(zip).files;
    final stored = entries.where((e) => e.name.startsWith('files/')).toList();
    expect(stored, hasLength(2));
  });

  test('a receipt file missing at export is reported', () async {
    final lost = await attach('lost.png');
    final m = readBundle(source, await export()).manifest;
    expect(m.missingFiles, [lost]);
    expect(m.files, isEmpty);
  });

  test('restore on another device writes the files and relinks rows', () async {
    final a = await attach('a_beleg.png');
    final copy = await attach('a_beleg.png');
    final b = await attach('b_rechnung.pdf', name: 'rechnung.pdf');
    final zip = await export();

    final targetFiles = MemoryReceiptStore();
    await restoreBundle(target, readBundle(target, zip), receipts: targetFiles);
    expect(targetFiles.files, hasLength(2));
    final rows = {for (final r in await attachmentsOf(target)) r.id: r};
    expect(targetFiles.files[rows[a]!.filePath], png);
    expect(rows[copy]!.filePath, rows[a]!.filePath);
    expect(targetFiles.files[rows[b]!.filePath], pdf);
    // The web-style blob of the seed attachment is untouched.
    expect(rows.values.where((r) => r.data != null), hasLength(1));
  });

  test('restore on the same device reuses identical files', () async {
    await attach('a_beleg.png');
    final zip = await export();
    final before = Map.of(sourceFiles.files);
    await restoreBundle(source, readBundle(source, zip), receipts: sourceFiles);
    expect(sourceFiles.files, before);
  });

  test('restore on the web puts receipts into attachments.data', () async {
    final a = await attach('a_beleg.png');
    final zip = await export();
    final web = MemoryReceiptStore(usesFiles: false);
    await restoreBundle(target, readBundle(target, zip), receipts: web);
    final row = (await attachmentsOf(target)).firstWhere((r) => r.id == a);
    expect(row.data, png);
    expect(row.filePath, isNull);
    expect(web.files, isEmpty);
  });

  test('damaged or unreferenced receipt files are rejected', () async {
    final a = await attach('a_beleg.png');
    final zip = await export();
    final m = readBundle(source, zip).manifest;

    Uint8List rebuild(void Function(Map<String, List<int>> files) edit) {
      final files = {
        for (final e in ZipDecoder().decodeBytes(zip).files)
          e.name: e.content.toList(),
      };
      edit(files);
      final out = Archive();
      for (final e in files.entries) {
        out.add(ArchiveFile.bytes(e.key, e.value));
      }
      return ZipEncoder().encodeBytes(out);
    }

    Matcher kind(BundleErrorKind k) =>
        throwsA(isA<BundleException>().having((e) => e.kind, 'kind', k));

    final damaged = rebuild((x) => x[m.files[a]!.file]![0] ^= 0xff);
    expect(
      () => readBundle(target, damaged),
      kind(BundleErrorKind.checksumMismatch),
    );

    final removed = rebuild((x) => x.remove(m.files[a]!.file));
    expect(
      () => readBundle(target, removed),
      kind(BundleErrorKind.checksumMismatch),
    );

    final unknown = rebuild((x) {
      final json = (jsonDecode(utf8.decode(x[bundleManifestFile]!)) as Map)
          .cast<String, Object?>();
      final files = (json['files']! as Map).cast<String, Object?>();
      json['files'] = {'no-such-attachment': files.values.first};
      x[bundleManifestFile] = utf8.encode(jsonEncode(json));
    });
    expect(
      () => readBundle(target, unknown),
      kind(BundleErrorKind.invalidContent),
    );
  });

  test(
    'a failed restore removes the files it wrote and keeps the data',
    () async {
      await attach('a_beleg.png');
      final contents = readBundle(target, await export());
      final tw = SyncWriter(target, testClock(node: 'dev-2'), 'dev-2');
      await tw.insert(
        target.tags,
        const TagsCompanion(name: Value('Bestehend')),
      );
      final before = await dumpTables(target);

      // Two rows with the same id make the insert fail inside the transaction.
      final tags = contents.tables['tags']!;
      final broken = BundleContents(contents.manifest, {
        ...contents.tables,
        'tags': BundleTable(tags.columns, [...tags.rows, tags.rows.first]),
      }, contents.files);

      final targetFiles = MemoryReceiptStore()..files['keep.png'] = pdf;
      await expectLater(
        restoreBundle(target, broken, receipts: targetFiles),
        throwsA(anything),
      );
      expect(targetFiles.files.keys, ['keep.png']);
      expect(await dumpTables(target), before);
    },
  );
}
