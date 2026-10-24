import 'package:go_router/go_router.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/rules/presentation/rule_editor_screen.dart';
import 'package:personal_finance/features/rules/presentation/rules_list_screen.dart';

export 'package:personal_finance/features/rules/presentation/rerun_rules_dialog.dart'
    show showRerunRulesDialog;
export 'package:personal_finance/features/rules/presentation/rule_editor_screen.dart'
    show openRuleEditor;

/// Routes of the rules feature:
/// * `/more/rules` – list (priority order, enable toggle)
/// * `/more/rules/new` – editor; `extra: TxnDraft` pre-fills it
/// * `/more/rules/:id` – edit a rule
final rulesRoutes = <RouteBase>[
  GoRoute(
    path: '/more/rules',
    builder: (context, state) => const RulesListScreen(),
    routes: [
      GoRoute(
        path: 'new',
        builder: (context, state) => RuleEditorScreen(
          from: state.extra is TxnDraft ? state.extra! as TxnDraft : null,
        ),
      ),
      GoRoute(
        path: ':id',
        builder: (context, state) =>
            RuleEditorScreen(ruleId: state.pathParameters['id']),
      ),
    ],
  ),
];
