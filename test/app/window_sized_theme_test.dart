import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/app/theme/app_theme.dart';

void main() {
  // The last action's tap target ends 4 px outside the page margin, so the
  // IconButton's circle sits on the margin.
  for (final (width, margin) in const [(400.0, 16.0), (1280.0, 24.0)]) {
    testWidgets('app bar actions end on the margin at ${width.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: const AppTheme().light(),
          builder: (context, child) => WindowSizedTheme(child: child!),
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Title'),
              actions: [
                IconButton(
                  tooltip: 'Last',
                  icon: const Icon(Icons.add),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      final button = tester.getRect(find.byType(IconButton));
      expect(button.right, width - (margin - 4));
    });
  }
}
