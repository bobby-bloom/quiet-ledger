import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/categories/data/custom_fields_repository.dart';
import 'package:personal_finance/features/categories/data/tags_repository.dart';
import 'package:personal_finance/features/categories/domain/default_categories.dart';
import 'package:personal_finance/features/categories/domain/drafts.dart';
import 'package:personal_finance/features/categories/presentation/categories_screen.dart';
import 'package:personal_finance/features/categories/presentation/custom_fields_screen.dart';
import 'package:personal_finance/features/categories/presentation/tags_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late SyncWriter writer;

  setUp(() {
    db = newTestDb();
    writer = SyncWriter(db, testClock(), 'dev-1');
  });

  tearDown(() => db.close());

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('category screen shows the hierarchy per kind', (tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seedDefaultCategories(writer, db, DefaultCategorySet.de);

    await tester.pumpWidget(
      testApp(const CategoriesScreen(), db: db, locale: const Locale('de')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kategorien'), findsOneWidget);
    expect(find.text('Wohnen'), findsOneWidget);
    expect(find.text('Miete'), findsOneWidget);
    expect(find.text('5 Unterkategorien · Noch nicht verwendet'), findsOne);
    expect(find.text('Gehalt'), findsNothing);

    // Subcategories are indented below their parent.
    final parentX = tester.getTopLeft(find.text('Wohnen')).dx;
    final childX = tester.getTopLeft(find.text('Miete')).dx;
    expect(childX, greaterThan(parentX));

    // The editor opens as a sheet with the budget overrides.
    await tester.tap(find.text('Miete'));
    await tester.pumpAndSettle();
    expect(find.text('Kategorie bearbeiten'), findsOneWidget);
    expect(find.text('Übertrag'), findsOneWidget);
    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Einnahme'));
    await tester.pumpAndSettle();
    expect(find.text('Gehalt'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('empty categories offer the default set', (tester) async {
    await tester.pumpWidget(testApp(const CategoriesScreen(), db: db));
    await tester.pumpAndSettle();
    expect(find.text('Add default categories'), findsOneWidget);
    await tester.tap(find.text('Add default categories'));
    await tester.pumpAndSettle();
    final rows = await db.select(db.categories).get();
    expect(rows, isNotEmpty);
    await unmount(tester);
  });

  testWidgets('tags screen shows a notice when the module is off', (
    tester,
  ) async {
    await writer.insert(
      db.settings,
      SettingsCompanion(
        key: Value(NavigationSettings.module(AppModule.tags).key),
        value: const Value('false'),
      ),
      id: 'global|${NavigationSettings.module(AppModule.tags).key}',
    );
    await tester.pumpWidget(testApp(const TagsScreen(), db: db));
    await tester.pumpAndSettle();
    expect(find.textContaining('switched off'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tags and custom fields list their entries', (tester) async {
    await TagsRepository(db, writer).create('vacation-2026');
    await CustomFieldsRepository(db, writer).create(
      const CustomFieldDraft(
        name: 'Project',
        type: CustomFieldType.select,
        options: ['Home', 'Work'],
      ),
    );
    await tester.pumpWidget(testApp(const TagsScreen(), db: db));
    await tester.pumpAndSettle();
    expect(find.text('#vacation-2026'), findsOneWidget);
    await unmount(tester);

    await tester.pumpWidget(testApp(const CustomFieldsScreen(), db: db));
    await tester.pumpAndSettle();
    expect(find.text('Project'), findsOneWidget);
    expect(find.textContaining('Single choice'), findsOneWidget);
    expect(find.textContaining('2 options'), findsOneWidget);
    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    expect(find.text('Edit custom field'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    await unmount(tester);
  });
}
