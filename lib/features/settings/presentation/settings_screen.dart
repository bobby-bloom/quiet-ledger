import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/app_version.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/settings/presentation/section_view.dart';
import 'package:personal_finance/features/settings/presentation/settings_catalog.dart';

/// Settings: search on top, then the sections. Phones show the list and
/// push one page per section (`/more/settings/<section>`); expanded windows
/// show the list and the selected section side by side.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.pageId, this.focusId});

  /// `SettingSection.name` or `about`; null = the list.
  final String? pageId;

  /// Setting key (or action id) to scroll to and highlight.
  final String? focusId;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _search = TextEditingController();
  String _query = '';
  SettingsPage? _selected;
  String? _focus;

  @override
  void initState() {
    super.initState();
    _selected = SettingsPage.parse(widget.pageId);
    _focus = widget.focusId;
  }

  @override
  void didUpdateWidget(SettingsScreen old) {
    super.didUpdateWidget(old);
    if (old.pageId != widget.pageId || old.focusId != widget.focusId) {
      _selected = SettingsPage.parse(widget.pageId) ?? _selected;
      _focus = widget.focusId;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(SettingsPage page, {required bool twoPane, String? focus}) {
    if (twoPane) {
      setState(() {
        _selected = page;
        _focus = focus;
      });
      return;
    }
    final q = focus == null ? '' : '?focus=${Uri.encodeQueryComponent(focus)}';
    unawaited(context.push('/more/settings/${page.id}$q'));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final twoPane = WindowSize.of(context).isExpanded;
    final routePage = SettingsPage.parse(widget.pageId);

    if (!twoPane && routePage != null) {
      final section = routePage.section;
      return Scaffold(
        appBar: AppBar(
          title: Text(routePage.label(l)),
          actions: [
            if (section != null) ResetSectionButton(section: section),
            const SizedBox(width: Space.xxs),
          ],
        ),
        body: SettingsSectionView(
          page: routePage,
          focusId: widget.focusId,
          showHeader: false,
        ),
      );
    }

    final master = _MasterPane(
      controller: _search,
      query: _query,
      selected: twoPane ? (_selected ?? settingsPages.first) : null,
      onQuery: (q) => setState(() => _query = q),
      onOpen: (p, focus) => _open(p, focus: focus, twoPane: twoPane),
    );

    if (!twoPane) {
      return Scaffold(
        appBar: AppBar(title: Text(l.navSettings)),
        body: master,
      );
    }
    final page = _selected ?? settingsPages.first;
    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 360, child: master),
          VerticalDivider(width: 1, color: context.colors.surfaceContainerHigh),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SettingsSectionView(
                  key: ValueKey('pane-${page.id}'),
                  page: page,
                  focusId: _focus,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MasterPane extends ConsumerWidget {
  const _MasterPane({
    required this.controller,
    required this.query,
    required this.selected,
    required this.onQuery,
    required this.onOpen,
  });

  final TextEditingController controller;
  final String query;
  final SettingsPage? selected;
  final ValueChanged<String> onQuery;
  final void Function(SettingsPage page, String? focus) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final caps = ref.watch(platformCapabilitiesProvider);
    final cs = context.colors;

    final Widget list;
    if (query.trim().isNotEmpty) {
      final hits = searchSettings(query, l, s, caps);
      list = hits.isEmpty
          ? EmptyState(
              icon: Icons.search_off,
              message: l.settingsUiNoResults(query.trim()),
            )
          : ListView.builder(
              itemCount: hits.length,
              itemBuilder: (context, i) {
                final h = hits[i];
                return ListTile(
                  key: ValueKey('hit-${h.id}'),
                  leading: Icon(h.page.icon),
                  title: Text(h.label),
                  subtitle: Text(
                    [h.page.label(l), ?h.description].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onOpen(h.page, h.id),
                );
              },
            );
    } else {
      final pages = settingsPages
          .where((p) => isPageVisible(p, s, caps))
          .toList();
      list = ListView.separated(
        padding: const EdgeInsets.only(bottom: Space.xl),
        itemCount: pages.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: Space.lg,
          endIndent: Space.md,
          color: cs.surfaceContainer,
        ),
        itemBuilder: (context, i) {
          final p = pages[i];
          final isSel = p == selected;
          final summary = pageSummary(p, l, s, caps, appVersion);
          return Material(
            color: isSel ? cs.secondaryContainer : Colors.transparent,
            child: InkWell(
              key: ValueKey('page-${p.id}'),
              onTap: () => onOpen(p, null),
              child: Semantics(
                selected: isSel,
                button: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: Space.lg,
                      right: Space.md,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          p.icon,
                          size: 22,
                          color: isSel
                              ? cs.onSecondaryContainer
                              : cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            p.label(l),
                            style: context.text.bodyLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Space.xs),
                        Flexible(
                          child: Text(
                            summary,
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xs),
          child: TextField(
            key: const ValueKey('settings-search'),
            controller: controller,
            onChanged: onQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l.settingsUiSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l.settingsUiClear,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        controller.clear();
                        onQuery('');
                      },
                    ),
              filled: true,
              fillColor: cs.surfaceContainer,
              contentPadding: const EdgeInsets.symmetric(vertical: Space.md),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(Radii.full)),
                borderSide: BorderSide.none,
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(Radii.full)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(
                  Radius.circular(Radii.full),
                ),
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
            ),
          ),
        ),
        Expanded(child: list),
      ],
    );
  }
}
