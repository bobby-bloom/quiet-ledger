import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/budgets/data/budget_providers.dart';
import 'package:personal_finance/features/budgets/presentation/budget_actions.dart';
import 'package:personal_finance/features/budgets/presentation/budgets_tab.dart';
import 'package:personal_finance/features/goals/presentation/goals_tab.dart';
import 'package:personal_finance/features/recurring/presentation/recurring_tab.dart';

enum PlanTab { budgets, recurring, goals }

/// Plan hub: Budgets · Recurring · Goals (module-dependent) and the bills
/// calendar action.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key, this.initialTab});

  /// 'budgets' | 'recurring' | 'goals' (route query `tab`).
  final String? initialTab;

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen>
    with TickerProviderStateMixin {
  TabController? _controller;
  List<PlanTab> _tabs = const [];
  PlanTab? _requested;

  @override
  void initState() {
    super.initState();
    _requested = PlanTab.values.asNameMap()[widget.initialTab];
  }

  @override
  void didUpdateWidget(PlanScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != old.initialTab) {
      final t = PlanTab.values.asNameMap()[widget.initialTab];
      if (t != null && _tabs.contains(t)) {
        _controller?.animateTo(_tabs.indexOf(t));
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _sync(List<PlanTab> tabs) {
    if (_controller != null &&
        tabs.length == _tabs.length &&
        _tabs.every(tabs.contains)) {
      return;
    }
    final current = _controller == null
        ? _requested
        : _tabs[_controller!.index];
    _controller?.dispose();
    _tabs = tabs;
    var index = current == null ? 0 : tabs.indexOf(current);
    if (index < 0) index = 0;
    _controller =
        TabController(length: tabs.length, vsync: this, initialIndex: index)
          ..addListener(() {
            if (mounted) setState(() {});
          });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final tabs = [
      if (settings.moduleEnabled(AppModule.budgets)) PlanTab.budgets,
      PlanTab.recurring,
      if (settings.moduleEnabled(AppModule.goals)) PlanTab.goals,
    ];
    _sync(tabs);
    final controller = _controller!;
    final active = _tabs[controller.index];
    String label(PlanTab t) => switch (t) {
      PlanTab.budgets => l.planTabBudgets,
      PlanTab.recurring => l.planTabRecurring,
      PlanTab.goals => l.planTabGoals,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navPlan),
        actions: [
          if (active == PlanTab.budgets)
            IconButton(
              tooltip: l.budgetsAdd,
              icon: const Icon(Icons.add),
              onPressed: () =>
                  addBudget(context, ref, ref.read(shownBudgetPeriodProvider)),
            ),
          if (active == PlanTab.recurring)
            IconButton(
              tooltip: l.recurringNew,
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/plan/recurring/new'),
            ),
          if (active == PlanTab.goals)
            IconButton(
              tooltip: l.goalsNew,
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/plan/goals/new'),
            ),
          IconButton(
            tooltip: l.planBillsCalendar,
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push('/plan/calendar'),
          ),
        ],
        bottom: tabs.length < 2
            ? null
            : TabBar(
                controller: controller,
                tabs: [for (final t in tabs) Tab(text: label(t))],
              ),
      ),
      body: TabBarView(
        controller: controller,
        children: [
          for (final t in tabs)
            switch (t) {
              PlanTab.budgets => const BudgetsTab(),
              PlanTab.recurring => const RecurringTab(),
              PlanTab.goals => const GoalsTab(),
            },
        ],
      ),
    );
  }
}
