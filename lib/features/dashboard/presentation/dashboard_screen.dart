import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_grid.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_period.dart';
import 'package:personal_finance/features/dashboard/presentation/widget_registry.dart';
import 'package:personal_finance/features/dashboard/presentation/widgets/dash_card.dart';
import 'package:personal_finance/features/export/presentation/backup_health_banner.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add.dart';

DashboardBreakpoint breakpointOf(WindowSize s) =>
    s.isCompact ? DashboardBreakpoint.compact : DashboardBreakpoint.expanded;

/// Home: configurable widgets — a stack on phones, a grid on wide screens.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = WindowSize.of(context);
    final bp = breakpointOf(size);
    final items =
        ref.watch(dashboardLayoutProvider(bp)).value ?? defaultLayouts[bp]!;
    final width = MediaQuery.sizeOf(context).width;
    final columns = size.isCompact ? 1 : (width >= 1400 ? 3 : 2);

    List<DashOption> optionsFor(int index) {
      final l = context.l10n;
      final item = items[index];
      final repo = ref.read(dashboardLayoutRepositoryProvider);
      void save(List<DashboardItem> next) => repo.save(bp, next);
      return [
        ...widgetOptions(context, ref, item, (updated) {
          save([...items]..[index] = updated);
        }),
        if (!size.isCompact)
          DashOption(
            item.size == WidgetSize.wide ? l.dashMakeNormal : l.dashMakeWide,
            item.size == WidgetSize.wide
                ? Icons.close_fullscreen
                : Icons.open_in_full,
            () => save(
              [...items]
                ..[index] = item.copyWith(
                  size: item.size == WidgetSize.wide
                      ? WidgetSize.normal
                      : WidgetSize.wide,
                ),
            ),
          ),
        DashOption(l.dashRemove, Icons.remove_circle_outline, () {
          save([...items]..removeAt(index));
        }),
        DashOption(
          l.dashEdit,
          Icons.dashboard_customize_outlined,
          () => context.push('/home/edit'),
        ),
      ];
    }

    final children = <Widget>[
      for (final (i, item) in items.indexed)
        buildDashboardWidget(
          context,
          item,
          compact: size.isCompact,
          options: optionsFor(i),
        ),
    ];

    final gutter = size.isCompact ? Space.phoneGutter : Space.xxl;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: size.isCompact
                  ? const _PhoneHeader()
                  : const _WideHeader(),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              sliver: const SliverToBoxAdapter(child: BackupHealthBanner()),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 32),
              sliver: SliverToBoxAdapter(
                child: DashboardGrid(
                  columns: columns,
                  gap: size.isCompact ? 10 : 20,
                  spans: [for (final i in items) i.span],
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodButton extends ConsumerWidget {
  const _PeriodButton({this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final range = ref.watch(dashboardPeriodProvider);
    final notifier = ref.read(dashboardPeriodProvider.notifier);
    final label = _label(ref, range);
    return MenuAnchor(
      builder: (context, controller, _) => TextButton(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        style: TextButton.styleFrom(
          foregroundColor: context.colors.onSurface,
          textStyle: context.text.titleMedium,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(48, 48),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.chevron_left),
          onPressed: notifier.previous,
          child: Text(l.dashPrevPeriod),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.chevron_right),
          onPressed: notifier.next,
          child: Text(l.dashNextPeriod),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.today_outlined),
          onPressed: notifier.today,
          child: Text(l.dashToday),
        ),
      ],
    );
  }

  static String _label(WidgetRef ref, DateRange r) {
    final dates = ref.watch(dateFormatsProvider);
    final monthly =
        ref.watch(
          settingsProvider.select((s) => s.get(BudgetSettings.periodType)),
        ) ==
        BudgetPeriodType.monthly;
    final calendarMonth =
        r.start.day == 1 && r.end == DateTime(r.start.year, r.start.month + 1);
    if (calendarMonth) return dates.monthYear(r.start);
    // A shifted monthly budget period (e.g. 30 Sep – 29 Oct) is named after
    // the month holding most of its days, like the Plan screen.
    if (monthly && r.days >= 27 && r.days <= 33) {
      return dates.monthYear(
        DateTime(r.start.year, r.start.month, r.start.day + r.days ~/ 2),
      );
    }
    return '${dates.medium(r.start)} – ${dates.medium(r.last)}';
  }
}

class _PhoneHeader extends ConsumerWidget {
  const _PhoneHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final privacy = ref.watch(privacyModeProvider);
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _PeriodButton(),
              ),
            ),
            IconButton(
              tooltip: l.commonSearch,
              icon: const Icon(Icons.search),
              onPressed: () => context.go('/transactions?focus=search'),
            ),
            IconButton(
              tooltip: l.privacyToggle,
              isSelected: privacy,
              icon: const Icon(Icons.visibility_outlined),
              selectedIcon: const Icon(Icons.visibility_off_outlined),
              onPressed: () => ref.read(privacyModeProvider.notifier).toggle(),
            ),
            IconButton(
              tooltip: l.navReports,
              icon: const Icon(Icons.bar_chart),
              onPressed: () => context.push('/reports'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideHeader extends ConsumerWidget {
  const _WideHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final privacy = ref.watch(privacyModeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.navHome,
                style: context.text.headlineSmall?.copyWith(fontSize: 26),
              ),
              const SizedBox(width: 12),
              const _PeriodButton(large: true),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 300,
                height: 44,
                child: TextField(
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l.dashSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: context.colors.surfaceContainer,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.full),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.full),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (q) => context.go(
                    Uri(
                      path: '/transactions',
                      queryParameters: {if (q.trim().isNotEmpty) 'q': q.trim()},
                    ).toString(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: l.privacyToggle,
                isSelected: privacy,
                icon: const Icon(Icons.visibility_outlined),
                selectedIcon: const Icon(Icons.visibility_off_outlined),
                onPressed: () =>
                    ref.read(privacyModeProvider.notifier).toggle(),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: () => context.push('/home/edit'),
                icon: const Icon(Icons.dashboard_customize_outlined),
                label: Text(l.dashEdit),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => showQuickAdd(context),
                icon: const Icon(Icons.add),
                label: Text(l.dashNewTransaction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dashboard editor: choose, order and size widgets per layout.
class DashboardEditorScreen extends ConsumerStatefulWidget {
  const DashboardEditorScreen({super.key});

  @override
  ConsumerState<DashboardEditorScreen> createState() =>
      _DashboardEditorScreenState();
}

class _DashboardEditorScreenState extends ConsumerState<DashboardEditorScreen> {
  DashboardBreakpoint? _bp;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bp = _bp ?? breakpointOf(WindowSize.of(context));
    final items =
        ref.watch(dashboardLayoutProvider(bp)).value ?? defaultLayouts[bp]!;
    final repo = ref.read(dashboardLayoutRepositoryProvider);
    final missing = DashboardWidgetType.values
        .where((t) => !items.any((i) => i.type == t))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.dashEditTitle),
        actions: [
          TextButton(
            onPressed: () => repo.reset(bp),
            child: Text(l.dashResetLayout),
          ),
        ],
      ),
      floatingActionButton: missing.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'dash-add',
              onPressed: () async {
                final type = await showAdaptiveSheet<DashboardWidgetType>(
                  context,
                  builder: (ctx) => ListView(
                    shrinkWrap: true,
                    children: [
                      for (final t in missing)
                        ListTile(
                          leading: Icon(widgetIcon(t)),
                          title: Text(widgetTypeLabel(ctx.l10n, t)),
                          onTap: () => Navigator.pop(ctx, t),
                        ),
                    ],
                  ),
                );
                if (type != null) {
                  await repo.save(bp, [...items, DashboardItem(type)]);
                }
              },
              icon: const Icon(Icons.add),
              label: Text(l.dashAddWidget),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<DashboardBreakpoint>(
              segments: [
                ButtonSegment(
                  value: DashboardBreakpoint.compact,
                  icon: const Icon(Icons.smartphone),
                  label: Text(l.dashLayoutPhone),
                ),
                ButtonSegment(
                  value: DashboardBreakpoint.expanded,
                  icon: const Icon(Icons.desktop_windows_outlined),
                  label: Text(l.dashLayoutWide),
                ),
              ],
              selected: {bp},
              onSelectionChanged: (s) => setState(() => _bp = s.first),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: items.length,
              onReorderItem: (from, to) {
                final next = [...items];
                final item = next.removeAt(from);
                next.insert(to, item);
                unawaited(repo.save(bp, next));
              },
              itemBuilder: (context, i) {
                final item = items[i];
                return ListTile(
                  key: ValueKey(item.type),
                  leading: Icon(widgetIcon(item.type)),
                  title: Text(widgetTypeLabel(l, item.type)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (bp == DashboardBreakpoint.expanded)
                        IconButton(
                          tooltip: item.size == WidgetSize.wide
                              ? l.dashMakeNormal
                              : l.dashMakeWide,
                          icon: Icon(
                            item.size == WidgetSize.wide
                                ? Icons.close_fullscreen
                                : Icons.open_in_full,
                          ),
                          onPressed: () => repo.save(
                            bp,
                            [...items]
                              ..[i] = item.copyWith(
                                size: item.size == WidgetSize.wide
                                    ? WidgetSize.normal
                                    : WidgetSize.wide,
                              ),
                          ),
                        ),
                      IconButton(
                        tooltip: l.dashRemove,
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => repo.save(bp, [...items]..removeAt(i)),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
