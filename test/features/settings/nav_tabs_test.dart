import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/settings/domain/nav_tabs.dart';

void main() {
  final known = NavTab.values.map((e) => e.name);

  test('normalize keeps More last and drops unknown/duplicates', () {
    expect(normalizeNavTabs(['more', 'home', 'bogus', 'home', 'plan'], known), [
      'home',
      'plan',
      'more',
    ]);
    expect(normalizeNavTabs([], known), ['more']);
    expect(
      normalizeNavTabs([
        'home',
        'transactions',
        'plan',
        'forecast',
        'accounts',
        'reports',
      ], known),
      ['home', 'transactions', 'plan', 'forecast', 'more'],
    );
  });

  test('at most 5 tabs including More', () {
    const full = ['home', 'transactions', 'plan', 'forecast', 'more'];
    expect(canToggleNavTab(full, 'accounts'), isFalse);
    expect(toggleNavTab(full, 'accounts'), full);
    final four = toggleNavTab(full, 'plan');
    expect(four, ['home', 'transactions', 'forecast', 'more']);
    expect(toggleNavTab(four, 'reports'), [
      'home',
      'transactions',
      'forecast',
      'reports',
      'more',
    ]);
  });

  test('at least 2 tabs including More; More cannot be removed', () {
    const two = ['home', 'more'];
    expect(canToggleNavTab(two, 'home'), isFalse);
    expect(toggleNavTab(two, 'home'), two);
    expect(canToggleNavTab(two, 'more'), isFalse);
    expect(toggleNavTab(['home', 'plan', 'more'], 'more'), [
      'home',
      'plan',
      'more',
    ]);
  });

  test('reorder never moves More', () {
    const tabs = ['home', 'transactions', 'plan', 'more'];
    expect(moveNavTab(tabs, 0, 2), ['transactions', 'plan', 'home', 'more']);
    expect(moveNavTab(tabs, 2, 0), ['plan', 'home', 'transactions', 'more']);
    expect(moveNavTab(tabs, 1, 99), ['home', 'plan', 'transactions', 'more']);
  });

  test('recommendation when neither Home nor Transactions', () {
    expect(lacksRecommendedTab(['plan', 'more']), isTrue);
    expect(lacksRecommendedTab(['transactions', 'more']), isFalse);
  });
}
