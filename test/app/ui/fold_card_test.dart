import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/app/ui/fold_card.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/settings/app_settings.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = newTestDb());
  tearDown(() => db.close());

  Widget card({required bool actionWhenFolded}) => Scaffold(
    body: FoldCard(
      title: 'Upcoming',
      fold: (setting: ForecastSettings.cardExpansion, id: 'upcoming'),
      actionLabel: 'Show all',
      onAction: () {},
      actionWhenFolded: actionWhenFolded,
      child: const Text('Rent'),
    ),
  );

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> fold(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Collapse Upcoming'));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsNothing);
    expect(find.text('Show all'), findsNothing);
  }

  testWidgets('a folded card offers its link in ⋮', (tester) async {
    await tester.pumpWidget(testApp(card(actionWhenFolded: true), db: db));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Widget options'), findsNothing);
    await fold(tester);
    await tester.tap(find.byTooltip('Widget options'));
    await tester.pumpAndSettle();
    expect(find.text('Show all'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await unmount(tester);
  });

  testWidgets('a link that only changes the body stays out of ⋮', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(card(actionWhenFolded: false), db: db));
    await tester.pumpAndSettle();
    expect(find.text('Show all'), findsOneWidget);
    await fold(tester);
    expect(find.byTooltip('Widget options'), findsNothing);
    await unmount(tester);
  });

  test('CardFolds decodes ids stored as false', () {
    expect(CardFolds.decode('').folded, isEmpty);
    expect(CardFolds.decode('{not json').folded, isEmpty);
    expect(CardFolds.decode('{"a":false,"b":true,"c":1}').folded, {'a'});
    expect(CardFolds.decode(const CardFolds({'x'}).encode()).folded, {'x'});
    expect(const CardFolds().encode(), '');
  });
}
