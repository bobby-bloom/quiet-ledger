import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/features/import/data/import_service.dart';
import 'package:personal_finance/features/import/domain/import_analysis.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/domain/source_reader.dart';

/// Lets real async work (drift) and fake time advance together.
Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Awaits [future] (started in the test zone) while pumping.
Future<T> drive<T>(WidgetTester tester, Future<T> future) async {
  var done = false;
  T? result;
  Object? error;
  StackTrace? stack;
  unawaited(
    future.then(
      (v) {
        result = v;
        done = true;
      },
      onError: (Object e, StackTrace s) {
        error = e;
        stack = s;
        done = true;
      },
    ),
  );
  for (var i = 0; i < 400 && !done; i++) {
    await settle(tester, rounds: 1);
  }
  if (error != null) Error.throwWithStackTrace(error!, stack!);
  if (!done) fail('future did not complete');
  await settle(tester, rounds: 2);
  return result as T;
}

/// Tears the tree down first; awaiting `db.close()` inside runAsync would
/// deadlock with queries started by the tree.
Future<void> disposeDb(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  unawaited(db.close());
  await tester.pump(const Duration(seconds: 1));
}

/// [ImportService] without background isolates (fake-async friendly).
class InlineImportService extends ImportService {
  InlineImportService(super.repository, super.profiles, super.rules);

  @override
  Future<RawWorkbook> read(
    ImportSource source, {
    CsvReadOptions csv = const CsvReadOptions(),
  }) async => source.bytes != null
      ? readImportFile(source.bytes!, fileName: source.name, csv: csv)
      : readClipboardText(source.text!, name: source.name);

  @override
  Future<ImportAnalysis> analyse(
    List<RawWorkbook> workbooks,
    ImportConfig config,
    ImportContext context,
  ) async => analyseImport(workbooks, config, context);
}
