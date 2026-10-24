import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add.dart';

/// One navigation destination.
class _Dest {
  const _Dest(this.tab, this.branch, this.icon, this.selectedIcon);
  final NavTab tab;
  final ShellBranch branch;
  final IconData icon;
  final IconData selectedIcon;
}

const _allDests = <NavTab, _Dest>{
  NavTab.home: _Dest(
    NavTab.home,
    ShellBranch.home,
    Icons.home_outlined,
    Icons.home,
  ),
  NavTab.transactions: _Dest(
    NavTab.transactions,
    ShellBranch.transactions,
    Icons.format_list_bulleted,
    Icons.format_list_bulleted,
  ),
  NavTab.plan: _Dest(
    NavTab.plan,
    ShellBranch.plan,
    Icons.track_changes_outlined,
    Icons.track_changes,
  ),
  NavTab.forecast: _Dest(
    NavTab.forecast,
    ShellBranch.forecast,
    Icons.show_chart,
    Icons.show_chart,
  ),
  NavTab.accounts: _Dest(
    NavTab.accounts,
    ShellBranch.accounts,
    Icons.account_balance_outlined,
    Icons.account_balance,
  ),
  NavTab.reports: _Dest(
    NavTab.reports,
    ShellBranch.reports,
    Icons.bar_chart_outlined,
    Icons.bar_chart,
  ),
  NavTab.more: _Dest(
    NavTab.more,
    ShellBranch.more,
    Icons.grid_view_outlined,
    Icons.grid_view,
  ),
};

/// Visible nav tabs from settings, filtered by switched-off modules. "More"
/// is always present (it is the way to every other screen).
final visibleTabsProvider = Provider<List<NavTab>>((ref) {
  final s = ref.watch(settingsProvider);
  final configured = s
      .get(NavigationSettings.tabs)
      .map((n) => NavTab.values.where((t) => t.name == n).firstOrNull)
      .nonNulls
      .toList();
  final tabs = configured.where((t) {
    if (t == NavTab.forecast) return s.moduleEnabled(AppModule.forecast);
    return true;
  }).toList();
  if (!tabs.contains(NavTab.more)) tabs.add(NavTab.more);
  return tabs.toSet().toList();
});

class _QuickAddIntent extends Intent {
  const _QuickAddIntent();
}

class _GoTabIntent extends Intent {
  const _GoTabIntent(this.index);
  final int index;
}

/// The app's adaptive scaffold (PLAN.md §4.1):
/// * compact (< 600): bottom bar with the quick-add FAB in its centre
/// * medium (600–839): navigation rail with the FAB on top
/// * expanded (≥ 840): extended rail with an "Add transaction" button
///
/// Shortcuts: Ctrl/Cmd+N quick add, Ctrl/Cmd+1…9 switch tabs.
class AdaptiveShell extends ConsumerWidget {
  const AdaptiveShell({required this.shell, this.location = '', super.key});

  final StatefulNavigationShell shell;

  /// Current location (used by the desktop sidebar for highlighting).
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(visibleTabsProvider);
    final dests = [for (final t in tabs) _allDests[t]!];
    final current = ShellBranch.values[shell.currentIndex];
    var selected = dests.indexWhere((d) => d.branch == current);
    if (selected < 0) selected = dests.indexWhere((d) => d.tab == NavTab.more);
    final size = WindowSize.of(context);
    final l = context.l10n;

    void go(int i) {
      final branch = dests[i].branch.index;
      shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
    }

    void add() => showQuickAdd(context);

    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          const _QuickAddIntent(),
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
          const _QuickAddIntent(),
      for (var i = 0; i < dests.length && i < 9; i++) ...{
        SingleActivator(
          LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
          control: true,
        ): _GoTabIntent(
          i,
        ),
        SingleActivator(
          LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
          meta: true,
        ): _GoTabIntent(
          i,
        ),
      },
    };

    final Widget body;
    if (size.isCompact) {
      body = Scaffold(
        body: shell,
        bottomNavigationBar: _BottomBar(
          dests: dests,
          selected: selected,
          onSelect: go,
          onAdd: add,
        ),
      );
    } else {
      final Widget nav;
      if (size.isExpanded) {
        nav = _Sidebar(dests: dests, path: location, onSelect: go, onAdd: add);
      } else {
        nav = NavigationRail(
          selectedIndex: selected,
          onDestinationSelected: go,
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.only(top: Space.xs, bottom: Space.md),
            child: FloatingActionButton(
              heroTag: 'quick-add',
              tooltip: l.addTransaction,
              onPressed: add,
              child: const Icon(Icons.add),
            ),
          ),
          destinations: [
            for (final d in dests)
              NavigationRailDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: Text(navTabLabel(l, d.tab)),
              ),
          ],
        );
      }
      body = Scaffold(
        body: Row(
          children: [
            nav,
            VerticalDivider(
              width: 1,
              color: context.colors.surfaceContainerHigh,
            ),
            Expanded(child: shell),
          ],
        ),
      );
    }

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          _QuickAddIntent: CallbackAction<_QuickAddIntent>(
            onInvoke: (_) => add(),
          ),
          _GoTabIntent: CallbackAction<_GoTabIntent>(
            onInvoke: (i) => go(i.index),
          ),
        },
        child: Focus(autofocus: true, child: body),
      ),
    );
  }
}

/// Bottom navigation styled after the design: 80 px, surfaceContainer,
/// pill indicator, with the quick-add FAB in the middle slot.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.dests,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
  });

  final List<_Dest> dests;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mid = (dests.length / 2).floor();
    final items = <Widget>[];
    for (var i = 0; i < dests.length; i++) {
      if (i == mid) {
        items.add(
          SizedBox(
            width: 72,
            child: Center(
              child: FloatingActionButton(
                heroTag: 'quick-add',
                tooltip: l.addTransaction,
                onPressed: onAdd,
                child: const Icon(Icons.add, size: 26),
              ),
            ),
          ),
        );
      }
      final d = dests[i];
      final isSel = i == selected;
      items.add(
        Expanded(
          flex: d.tab == NavTab.transactions ? 135 : 100,
          child: _NavItem(
            icon: isSel ? d.selectedIcon : d.icon,
            label: navTabLabel(l, d.tab),
            selected: isSel,
            onTap: () => onSelect(i),
          ),
        ),
      );
    }
    return Material(
      color: context.colors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final color = selected ? cs.onSecondaryContainer : cs.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: SizedBox(
          height: 72,
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.secondaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop sidebar (DesktopDashboard board): logo, the configured nav tabs as
/// pill rows, More pinned to the bottom (it holds every other screen).
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.dests,
    required this.path,
    required this.onSelect,
    required this.onAdd,
  });

  final List<_Dest> dests;
  final String path;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = context.colors;
    bool active(String prefix) => path == prefix || path.startsWith('$prefix/');
    // Screens without their own tab (Settings, Import, ...) live under More.
    final inTab = dests.any(
      (d) => d.tab != NavTab.more && active(_branchRoot(d.branch)),
    );

    return Container(
      width: 232,
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: cs.onPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.appTitle,
                    style: context.text.titleSmall?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(l.addTransaction),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final (i, d) in dests.indexed)
                  if (d.tab != NavTab.more)
                    _SidebarItem(
                      icon: d.icon,
                      label: navTabLabel(l, d.tab),
                      selected: active(_branchRoot(d.branch)),
                      onTap: () => onSelect(i),
                    ),
              ],
            ),
          ),
          _SidebarItem(
            icon: Icons.grid_view_outlined,
            label: l.navMore,
            selected: !inTab,
            onTap: () => context.go('/more'),
          ),
        ],
      ),
    );
  }

  static String _branchRoot(ShellBranch b) => switch (b) {
    ShellBranch.home => '/home',
    ShellBranch.transactions => '/transactions',
    ShellBranch.plan => '/plan',
    ShellBranch.forecast => '/forecast',
    ShellBranch.accounts => '/accounts',
    ShellBranch.reports => '/reports',
    ShellBranch.more => '/more',
  };
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final fg = selected ? cs.onSecondaryContainer : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? cs.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Semantics(
            selected: selected,
            button: true,
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(icon, size: 22, color: fg),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium?.copyWith(
                          color: fg,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
