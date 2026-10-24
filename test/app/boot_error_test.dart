import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/app/boot_error.dart';
import 'package:personal_finance/app/bootstrap.dart';
import 'package:personal_finance/core/db/database.dart';

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

  testWidgets('newer database: asks for an update', (tester) async {
    await tester.pumpWidget(
      BootErrorApp(error: const NewerDatabaseException(3, 2), onRetry: () {}),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('newer version'), findsOneWidget);
    expect(find.text('Start with an empty database'), findsNothing);
  });
}
