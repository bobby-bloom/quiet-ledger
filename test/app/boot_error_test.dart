import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/app/boot_error.dart';
import 'package:personal_finance/app/bootstrap.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:sqlite3/common.dart' show SqliteException;

void main() {
  testWidgets('missing key: explains, keeps data, can start fresh', (
    tester,
  ) async {
    var retried = 0;
    var freshCalls = 0;
    await tester.pumpWidget(
      BootErrorApp(
        error: const MissingDatabaseKeyException(),
        onRetry: () => retried++,
        onStartFresh: () async {
          freshCalls++;
          return '/data/unreadable/20261024-090000';
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('key that unlocks'), findsOneWidget);
    expect(find.textContaining('Nothing has been deleted'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retried, 1);

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Start with an empty database'),
    );
    await tester.pumpAndSettle();
    // Confirmation first; cancelling does nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(freshCalls, 0);

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Start with an empty database'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Start with an empty database'),
    );
    await tester.pumpAndSettle();
    expect(freshCalls, 1);
    expect(find.textContaining('20261024-090000'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(retried, 2);
  });

  Future<void> pumpError(WidgetTester tester, Object error) async {
    await tester.pumpWidget(
      BootErrorApp(
        error: error,
        onRetry: () {},
        onStartFresh: () async => fail('must not move the database aside'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('newer database: asks for an update, never starts fresh', (
    tester,
  ) async {
    await pumpError(tester, const NewerDatabaseException(3, 2));
    expect(find.textContaining('newer version'), findsOneWidget);
    expect(find.text('Start with an empty database'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('other errors only offer a retry', (tester) async {
    await pumpError(tester, StateError('secure storage is locked'));
    expect(find.textContaining('can be temporary'), findsOneWidget);
    expect(find.text('Start with an empty database'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a file that is not a database can start fresh', (tester) async {
    await pumpError(
      tester,
      SqliteException(
        extendedResultCode: 26,
        message: 'file is not a database',
      ),
    );
    expect(
      find.textContaining('damaged or cannot be unlocked'),
      findsOneWidget,
    );
    expect(find.text('Start with an empty database'), findsOneWidget);
  });

  test('classifyBootError', () {
    expect(
      classifyBootError(const MissingDatabaseKeyException()),
      BootFailure.unreadable,
    );
    expect(
      classifyBootError(const NewerDatabaseException(4, 3)),
      BootFailure.newer,
    );
    // SQLITE_CORRUPT and SQLITE_NOTADB, extended codes included.
    for (final code in [11, 26, 11 | (1 << 8)]) {
      expect(
        classifyBootError(
          SqliteException(extendedResultCode: code, message: 'x'),
        ),
        BootFailure.unreadable,
      );
    }
    // Busy, I/O error, disk full, read-only: the file may be fine.
    for (final code in [5, 10, 13, 8]) {
      expect(
        classifyBootError(
          SqliteException(extendedResultCode: code, message: 'x'),
        ),
        BootFailure.other,
      );
    }
    expect(
      classifyBootError(const FileSystemException('No space left')),
      BootFailure.other,
    );
  });
}
