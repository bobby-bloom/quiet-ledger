import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/settings/app_settings.dart';

/// A category of a default set. [colorIndex] indexes [ChartPalette.series];
/// children inherit the parent's colour.
@immutable
class DefaultCategory {
  const DefaultCategory(
    this.name,
    this.icon, {
    this.colorIndex = 0,
    this.children = const [],
  });

  final String name;

  /// AppIcons key.
  final String icon;
  final int colorIndex;
  final List<DefaultCategory> children;
}

/// Expense and income categories of one default set.
@immutable
class DefaultCategorySetData {
  const DefaultCategorySetData({required this.expense, required this.income});

  final List<DefaultCategory> expense;
  final List<DefaultCategory> income;
}

const _de = DefaultCategorySetData(
  expense: [
    DefaultCategory('Lebensmittel', 'groceries'),
    DefaultCategory('Restaurant & Café', 'restaurant', colorIndex: 4),
    DefaultCategory(
      'Wohnen',
      'home',
      colorIndex: 1,
      children: [
        DefaultCategory('Miete', 'rent'),
        DefaultCategory('Nebenkosten', 'utilities'),
        DefaultCategory('Strom', 'utilities'),
        DefaultCategory('Internet & Telefon', 'internet'),
        DefaultCategory('Einrichtung', 'home'),
      ],
    ),
    DefaultCategory(
      'Mobilität',
      'transport',
      colorIndex: 2,
      children: [
        DefaultCategory('ÖPNV', 'transport'),
        DefaultCategory('Auto', 'car'),
        DefaultCategory('Tanken', 'fuel'),
      ],
    ),
    DefaultCategory('Versicherungen', 'insurance', colorIndex: 3),
    DefaultCategory(
      'Gesundheit',
      'health',
      colorIndex: 4,
      children: [
        DefaultCategory('Arzt', 'health'),
        DefaultCategory('Apotheke', 'pharmacy'),
      ],
    ),
    DefaultCategory(
      'Freizeit',
      'entertainment',
      colorIndex: 5,
      children: [
        DefaultCategory('Sport', 'sport'),
        DefaultCategory('Kultur & Ausgehen', 'entertainment'),
      ],
    ),
    DefaultCategory(
      'Shopping',
      'shopping',
      colorIndex: 1,
      children: [
        DefaultCategory('Kleidung', 'clothing'),
        DefaultCategory('Elektronik', 'electronics'),
      ],
    ),
    DefaultCategory('Abos', 'subscriptions', colorIndex: 3),
    DefaultCategory(
      'Reisen',
      'travel',
      colorIndex: 2,
      children: [
        DefaultCategory('Unterkunft', 'hotel'),
        DefaultCategory('Anreise', 'travel'),
      ],
    ),
    DefaultCategory('Bildung', 'education', colorIndex: 1),
    DefaultCategory('Kinder', 'kids', colorIndex: 5),
    DefaultCategory('Haustiere', 'pets', colorIndex: 2),
    DefaultCategory('Geschenke & Spenden', 'gifts', colorIndex: 3),
    DefaultCategory('Gebühren', 'fees', colorIndex: 4),
    DefaultCategory('Steuern', 'taxes'),
  ],
  income: [
    DefaultCategory('Gehalt', 'salary'),
    DefaultCategory('Nebeneinkünfte', 'freelance', colorIndex: 1),
    DefaultCategory('Zinsen & Dividenden', 'interest', colorIndex: 2),
    DefaultCategory('Erstattungen', 'refund', colorIndex: 3),
    DefaultCategory('Sonstiges', 'other', colorIndex: 5),
  ],
);

const _en = DefaultCategorySetData(
  expense: [
    DefaultCategory('Groceries', 'groceries'),
    DefaultCategory('Restaurants & cafés', 'restaurant', colorIndex: 4),
    DefaultCategory(
      'Housing',
      'home',
      colorIndex: 1,
      children: [
        DefaultCategory('Rent', 'rent'),
        DefaultCategory('Utilities', 'utilities'),
        DefaultCategory('Electricity', 'utilities'),
        DefaultCategory('Internet & phone', 'internet'),
        DefaultCategory('Furnishing', 'home'),
      ],
    ),
    DefaultCategory(
      'Transport',
      'transport',
      colorIndex: 2,
      children: [
        DefaultCategory('Public transport', 'transport'),
        DefaultCategory('Car', 'car'),
        DefaultCategory('Fuel', 'fuel'),
      ],
    ),
    DefaultCategory('Insurance', 'insurance', colorIndex: 3),
    DefaultCategory(
      'Health',
      'health',
      colorIndex: 4,
      children: [
        DefaultCategory('Doctor', 'health'),
        DefaultCategory('Pharmacy', 'pharmacy'),
      ],
    ),
    DefaultCategory(
      'Leisure',
      'entertainment',
      colorIndex: 5,
      children: [
        DefaultCategory('Sport', 'sport'),
        DefaultCategory('Going out', 'entertainment'),
      ],
    ),
    DefaultCategory(
      'Shopping',
      'shopping',
      colorIndex: 1,
      children: [
        DefaultCategory('Clothing', 'clothing'),
        DefaultCategory('Electronics', 'electronics'),
      ],
    ),
    DefaultCategory('Subscriptions', 'subscriptions', colorIndex: 3),
    DefaultCategory(
      'Travel',
      'travel',
      colorIndex: 2,
      children: [
        DefaultCategory('Accommodation', 'hotel'),
        DefaultCategory('Getting there', 'travel'),
      ],
    ),
    DefaultCategory('Education', 'education', colorIndex: 1),
    DefaultCategory('Kids', 'kids', colorIndex: 5),
    DefaultCategory('Pets', 'pets', colorIndex: 2),
    DefaultCategory('Gifts & donations', 'gifts', colorIndex: 3),
    DefaultCategory('Fees', 'fees', colorIndex: 4),
    DefaultCategory('Taxes', 'taxes'),
  ],
  income: [
    DefaultCategory('Salary', 'salary'),
    DefaultCategory('Side income', 'freelance', colorIndex: 1),
    DefaultCategory('Interest & dividends', 'interest', colorIndex: 2),
    DefaultCategory('Refunds', 'refund', colorIndex: 3),
    DefaultCategory('Other income', 'other', colorIndex: 5),
  ],
);

/// The definitions of a default category set.
DefaultCategorySetData defaultCategorySet(DefaultCategorySet set) =>
    switch (set) {
      DefaultCategorySet.de => _de,
      DefaultCategorySet.en => _en,
    };

/// Seeds the default categories of [set] (two levels, icons, colours).
/// Does nothing when live categories already exist, so it is safe to call
/// repeatedly (onboarding, "Add default categories").
Future<void> seedDefaultCategories(
  SyncWriter writer,
  AppDatabase db,
  DefaultCategorySet set,
) => writer.transaction(() async {
  final count = db.categories.id.count();
  final existing =
      await (db.selectOnly(db.categories)
            ..addColumns([count])
            ..where(db.categories.deletedAt.isNull()))
          .getSingle();
  if ((existing.read(count) ?? 0) > 0) return;

  final data = defaultCategorySet(set);
  Future<void> insertAll(List<DefaultCategory> defs, CategoryKind kind) async {
    for (var i = 0; i < defs.length; i++) {
      final d = defs[i];
      final color = ChartPalette.at(d.colorIndex).toARGB32();
      final parentId = await writer.insert(
        db.categories,
        CategoriesCompanion(
          name: Value(d.name),
          kind: Value(kind),
          icon: Value(d.icon),
          color: Value(color),
          sortOrder: Value(i),
        ),
      );
      for (var j = 0; j < d.children.length; j++) {
        final c = d.children[j];
        await writer.insert(
          db.categories,
          CategoriesCompanion(
            parentId: Value(parentId),
            name: Value(c.name),
            kind: Value(kind),
            icon: Value(c.icon),
            color: Value(color),
            sortOrder: Value(j),
          ),
        );
      }
    }
  }

  await insertAll(data.expense, CategoryKind.expense);
  await insertAll(data.income, CategoryKind.income);
});
