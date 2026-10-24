import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/settings/domain/nav_tabs.dart';
import 'package:personal_finance/features/settings/presentation/setting_tiles.dart';

/// Editor for the bottom-bar / rail tabs: 2–5 destinations, reorderable,
/// "More" always last.
class NavTabsEditor extends ConsumerWidget {
  const NavTabsEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final known = NavTab.values.map((e) => e.name);
    final tabs = normalizeNavTabs(s.get(NavigationSettings.tabs), known);
    final movable = tabs.where((t) => t != moreTab).toList();
    final others = NavTab.values
        .map((e) => e.name)
        .where((t) => t != moreTab && !tabs.contains(t))
        .toList();
    final forecastOff = !s.moduleEnabled(AppModule.forecast);

    Future<void> store(List<String> list) => ref
        .read(settingsProvider.notifier)
        .set(NavigationSettings.tabs, normalizeNavTabs(list, known));

    String label(String t) => navTabLabel(l, NavTab.values.byName(t));

    Widget row(String t, {required bool on, int? index}) {
      final allowed = canToggleNavTab(tabs, t);
      final moduleOff = t == NavTab.forecast.name && forecastOff;
      return Semantics(
        key: ValueKey('nav-$t'),
        customSemanticsActions: index == null
            ? null
            : {
                if (index > 0)
                  CustomSemanticsAction(label: l.settingsUiMoveUp): () =>
                      store(moveNavTab(tabs, index, index - 1)),
                if (index < movable.length - 1)
                  CustomSemanticsAction(label: l.settingsUiMoveDown): () =>
                      store(moveNavTab(tabs, index, index + 1)),
              },
        child: Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.only(left: Space.xs),
            value: on,
            onChanged: allowed ? (_) => store(toggleNavTab(tabs, t)) : null,
            title: Text(label(t)),
            subtitle: moduleOff ? Text(l.settingsUiNavTabModuleOff) : null,
            secondary: index == null
                ? null
                : ReorderableDragStartListener(
                    index: index,
                    child: Tooltip(
                      message: l.settingsUiDragHandle,
                      child: const Padding(
                        padding: EdgeInsets.all(Space.sm),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ),
          ),
        ),
      );
    }

    return SettingRow(
      title: l.setNavTabs,
      subtitle: l.settingsUiNavTabsHint(minNavTabs, maxNavTabs),
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) => store(moveNavTab(tabs, from, to)),
            children: [
              for (var i = 0; i < movable.length; i++)
                row(movable[i], on: true, index: i),
            ],
          ),
          ListTile(
            key: const ValueKey('nav-more'),
            dense: true,
            contentPadding: const EdgeInsets.only(left: Space.xs, right: 4),
            leading: const Checkbox(value: true, onChanged: null),
            title: Text(navTabLabel(l, NavTab.more)),
            subtitle: Text(l.settingsUiNavMoreAlways),
            trailing: const Padding(
              padding: EdgeInsets.all(Space.sm),
              child: Icon(Icons.lock_outline, size: 20),
            ),
          ),
          if (others.isNotEmpty) ...[
            Divider(height: Space.md, color: context.colors.surfaceContainer),
            for (final t in others) row(t, on: false),
          ],
          if (lacksRecommendedTab(tabs))
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: context.finance.warning,
                  ),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      l.settingsUiNavTabsRecommend,
                      style: context.text.labelMedium?.copyWith(
                        color: context.finance.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
