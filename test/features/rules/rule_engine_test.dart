import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/rules/domain/rule_engine.dart';
import 'package:personal_finance/features/rules/domain/rule_model.dart';

TxnDraft draft({
  String payee = '',
  String? note,
  int amount = -1000,
  String account = 'giro',
  String? category,
  TxnType type = TxnType.expense,
  List<String> tags = const [],
  TxnStatus status = TxnStatus.cleared,
}) => TxnDraft(
  accountId: account,
  amountMinor: amount,
  date: DateTime(2024),
  payee: payee,
  note: note,
  categoryId: category,
  type: type,
  tagIds: tags,
  status: status,
);

RuleDef rule(
  String name,
  List<RuleCondition> conditions,
  RuleActions actions, {
  int priority = 0,
  MatchMode mode = MatchMode.all,
  bool enabled = true,
}) => RuleDef(
  id: name,
  name: name,
  priority: priority,
  conditions: RuleConditions(mode: mode, items: conditions),
  actions: actions,
  enabled: enabled,
);

void main() {
  group('conditions', () {
    final e = RuleEngine(const []);
    bool m(RuleCondition c, TxnDraft d) =>
        e.matches(rule('r', [c], const RuleActions(categoryId: 'x')), d);

    test('text operators are case-insensitive', () {
      final d = draft(payee: 'REWE Markt GmbH', note: 'Einkauf');
      expect(m(const TextCondition(value: 'rewe'), d), isTrue);
      expect(
        m(
          const TextCondition(
            field: RuleTextField.payee,
            operator: TextOperator.equals,
            value: 'rewe markt gmbh',
          ),
          d,
        ),
        isTrue,
      );
      expect(
        m(
          const TextCondition(
            field: RuleTextField.payee,
            operator: TextOperator.startsWith,
            value: 'REWE',
          ),
          d,
        ),
        isTrue,
      );
      expect(
        m(
          const TextCondition(
            field: RuleTextField.payee,
            operator: TextOperator.endsWith,
            value: 'gmbh',
          ),
          d,
        ),
        isTrue,
      );
      expect(
        m(const TextCondition(field: RuleTextField.note, value: 'rewe'), d),
        isFalse,
      );
      expect(m(const TextCondition(value: 'einkauf'), d), isTrue);
      expect(m(const TextCondition(value: 'aral', negate: true), d), isTrue);
    });

    test('regex', () {
      final d = draft(payee: 'PAYPAL *NETFLIX 4029357733');
      expect(
        m(
          const TextCondition(
            operator: TextOperator.regex,
            value: r'netflix\s+\d+',
          ),
          d,
        ),
        isTrue,
      );
      expect(
        m(
          const TextCondition(operator: TextOperator.regex, value: '^spotify'),
          d,
        ),
        isFalse,
      );
      // Invalid regex: incomplete, never matches.
      expect(
        const TextCondition(
          operator: TextOperator.regex,
          value: '(',
        ).isComplete,
        isFalse,
      );
      expect(
        m(const TextCondition(operator: TextOperator.regex, value: '('), d),
        isFalse,
      );
    });

    test('amount range, account, type', () {
      expect(
        m(const AmountCondition(minMinor: 500, maxMinor: 1500), draft()),
        isTrue,
      );
      expect(m(const AmountCondition(minMinor: 1500), draft()), isFalse);
      expect(
        m(const AmountCondition(maxMinor: -500, absolute: false), draft()),
        isTrue,
      );
      expect(m(const AccountCondition(['giro']), draft()), isTrue);
      expect(m(const AccountCondition(['spar']), draft()), isFalse);
      expect(m(const TypeCondition([TxnType.income]), draft()), isFalse);
      expect(
        m(const TypeCondition([TxnType.expense, TxnType.income]), draft()),
        isTrue,
      );
    });

    test('match all / any; rules without conditions never match', () {
      final d = draft(payee: 'Aral', amount: -5000);
      const c1 = TextCondition(value: 'aral');
      const c2 = AmountCondition(maxMinor: 1000);
      expect(
        e.matches(rule('a', [c1, c2], const RuleActions(categoryId: 'x')), d),
        isFalse,
      );
      expect(
        e.matches(
          rule(
            'a',
            [c1, c2],
            const RuleActions(categoryId: 'x'),
            mode: MatchMode.any,
          ),
          d,
        ),
        isTrue,
      );
      expect(
        e.matches(rule('a', [], const RuleActions(categoryId: 'x')), d),
        isFalse,
      );
      // Incomplete conditions are ignored.
      expect(
        e.matches(
          rule('a', [
            c1,
            const TextCondition(),
          ], const RuleActions(categoryId: 'x')),
          d,
        ),
        isTrue,
      );
    });
  });

  group('actions', () {
    test(
      'only empty fields are filled; first rule by priority wins per field',
      () {
        final engine = RuleEngine([
          rule(
            'b',
            [const TextCondition(value: 'rewe')],
            const RuleActions(
              categoryId: 'shopping',
              addTagIds: ['t2'],
              note: 'B',
            ),
            priority: 2,
          ),
          rule(
            'a',
            [const TextCondition(value: 'rewe')],
            const RuleActions(categoryId: 'groceries', payee: 'REWE'),
            priority: 1,
          ),
          rule(
            'off',
            [const TextCondition(value: 'rewe')],
            const RuleActions(categoryId: 'never'),
            enabled: false,
          ),
        ]);
        final out = engine.apply(draft(payee: 'rewe sagt danke 123'));
        expect(out.draft.categoryId, 'groceries');
        expect(out.draft.payee, 'REWE');
        expect(out.draft.tagIds, ['t2']);
        expect(out.draft.note, 'B');
        expect(out.matchedRuleIds, ['a', 'b']);
        expect(
          out.changed,
          containsAll([
            RuleField.category,
            RuleField.payee,
            RuleField.tags,
            RuleField.note,
          ]),
        );

        final already = engine.apply(
          draft(payee: 'REWE', category: 'mine', note: 'own'),
        );
        expect(already.draft.categoryId, 'mine');
        expect(already.draft.note, 'own');
      },
    );

    test('overwrite flag and overwrite mode', () {
      final engine = RuleEngine([
        rule('a', [
          const TextCondition(value: 'x'),
        ], const RuleActions(categoryId: 'c', status: TxnStatus.pending)),
      ]);
      final d = draft(payee: 'x', category: 'old', status: TxnStatus.planned);
      expect(engine.apply(d).draft.categoryId, 'old');
      expect(engine.apply(d).draft.status, TxnStatus.planned);
      final forced = engine.apply(d, mode: RuleApplyMode.overwrite).draft;
      expect(forced.categoryId, 'c');
      expect(forced.status, TxnStatus.pending);
      final ow = RuleEngine([
        rule('a', [
          const TextCondition(value: 'x'),
        ], const RuleActions(categoryId: 'c', overwrite: true)),
      ]);
      expect(ow.apply(d).draft.categoryId, 'c');
    });

    test('custom fields per field, transfers never get a category', () {
      final engine = RuleEngine([
        rule(
          'a',
          [const TextCondition(value: 'x')],
          const RuleActions(customFields: {'f1': 'A', 'f2': 2}),
          priority: 1,
        ),
        rule(
          'b',
          [const TextCondition(value: 'x')],
          const RuleActions(
            customFields: {'f1': 'B', 'f3': true},
            categoryId: 'c',
          ),
          priority: 2,
        ),
      ]);
      final out = engine.apply(draft(payee: 'x'));
      expect(out.draft.customFields, {'f1': 'A', 'f2': 2, 'f3': true});
      final t = engine.apply(draft(payee: 'x', type: TxnType.transfer));
      expect(t.draft.categoryId, isNull);
    });

    test('no changes when nothing matches', () {
      final engine = RuleEngine([
        rule('a', [
          const TextCondition(value: 'x'),
        ], const RuleActions(categoryId: 'c')),
      ]);
      final out = engine.apply(draft(payee: 'y'));
      expect(out.hasChanges, isFalse);
      expect(out.matchedRuleIds, isEmpty);
    });
  });

  group('JSON', () {
    test('conditions and actions round trip', () {
      const c = RuleConditions(
        mode: MatchMode.any,
        items: [
          TextCondition(
            field: RuleTextField.note,
            operator: TextOperator.regex,
            value: r'^\d+',
            negate: true,
          ),
          AmountCondition(minMinor: -100, maxMinor: 200, absolute: false),
          AccountCondition(['a', 'b']),
          TypeCondition([TxnType.income]),
        ],
      );
      expect(RuleConditions.decode(c.encode()), c);
      const a = RuleActions(
        categoryId: 'c',
        addTagIds: ['t'],
        customFields: {'f': 1},
        payee: 'P',
        status: TxnStatus.pending,
        note: 'N',
        overwrite: true,
      );
      expect(RuleActions.decode(a.encode()), a);
      expect(RuleActions.decode(''), const RuleActions());
      expect(RuleConditions.decode('[]'), const RuleConditions());
      expect(
        () => RuleCondition.fromJson(const {'kind': 'nope'}),
        throwsFormatException,
      );
    });

    test('validity', () {
      expect(
        rule('', [
          const TextCondition(value: 'x'),
        ], const RuleActions(categoryId: 'c')).isValid,
        isFalse,
      );
      expect(
        rule('n', [
          const TextCondition(),
        ], const RuleActions(categoryId: 'c')).isValid,
        isFalse,
      );
      expect(
        rule('n', [
          const TextCondition(value: 'x'),
        ], const RuleActions()).isValid,
        isFalse,
      );
      expect(
        rule('n', [
          const TextCondition(value: 'x'),
        ], const RuleActions(payee: 'y')).isValid,
        isTrue,
      );
    });
  });
}
