import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/export/data/safety_copies.dart';
import 'package:personal_finance/features/export/domain/backup_settings.dart';
import 'package:personal_finance/features/export/presentation/backup_health_banner.dart';
import 'package:personal_finance/features/export/presentation/safety_copies_screen.dart';

import '../../helpers/test_app.dart';
import 'export_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = newTestDb());
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(Scaffold(body: child), db: db));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('banner: shown until there is a recent backup', (tester) async {
    await tester.runAsync(() => seed(db));
    await pump(tester, const BackupHealthBanner());
    expect(find.text('Your data has not been backed up yet.'), findsOneWidget);
    expect(find.text('Back up now'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BackupHealthBanner)),
    );
    await tester.runAsync(
      () => container
          .read(settingsProvider.notifier)
          .set(BackupSettings.lastVerified, DateTime.now().toIso8601String()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Back up now'), findsNothing);

    await tester.runAsync(
      () => container
          .read(settingsProvider.notifier)
          .set(BackupSettings.lastError, 'Folder not writable'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Folder not writable'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('banner: nothing to nag about in an empty app', (tester) async {
    await pump(tester, const BackupHealthBanner());
    expect(find.text('Back up now'), findsNothing);
    await unmount(tester);
  });

  testWidgets('safety copies: list and restore', (tester) async {
    await tester.runAsync(() async {
      await seed(db);
      await takeSafetyCopy(db, SafetyReason.importUndo, deviceId: 'd');
      await db.delete(db.tags).go();
    });
    await pump(tester, const SafetyCopiesScreen());
    expect(find.text('Before undoing an import'), findsOneWidget);

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Safety copy restored'), findsOneWidget);
    final tags = await tester.runAsync(() => db.select(db.tags).get());
    expect(tags, hasLength(2));
    // The state before the restore was kept as well.
    expect(find.text('Before restoring a safety copy'), findsOneWidget);
    await unmount(tester);
  });
}
