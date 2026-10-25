import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/settings/presentation/sections/data_section.dart';
import 'package:personal_finance/features/settings/presentation/sections/other_sections.dart';
import 'package:personal_finance/features/settings/presentation/sections/security_section.dart';
import 'package:personal_finance/features/settings/presentation/setting_tiles.dart';
import 'package:personal_finance/features/settings/presentation/settings_catalog.dart';

/// Settings that "Reset section" leaves alone: the app lock is turned off
/// only through its own flow (which removes the credential), and resetting
/// the storage location would silently switch to another database.
final _protectedFromReset = <SettingDef<Object?>>{
  SecuritySettings.appLock,
  SecuritySettings.lockMethod,
  DataSettings.storageLocation,
};

/// Search ids that land on another row of a custom page.
final _focusAliases = <String, String>{
  SecuritySettings.lockMethod.key: SecuritySettings.appLock.key,
};

/// Resets every user-visible setting of [section] to its default. Hidden
/// internal values (e.g. onboarding state) and [_protectedFromReset] are
/// kept.
Future<void> resetSettingsPage(
  SettingsController controller,
  SettingSection section,
) async {
  for (final d in allSettings) {
    if (d.section != section || d.hidden) continue;
    if (_protectedFromReset.contains(d)) continue;
    await controller.reset(d);
  }
}

/// Asks for confirmation, then resets [section].
Future<bool> confirmResetSection(
  BuildContext context,
  WidgetRef ref,
  SettingSection section,
) async {
  final l = context.l10n;
  final ok = await confirmDialog(
    context,
    title: l.settingsUiResetSectionTitle(sectionLabel(l, section)),
    message: l.settingsUiResetSectionMessage,
    confirmLabel: l.commonReset,
  );
  if (!ok) return false;
  await resetSettingsPage(ref.read(settingsProvider.notifier), section);
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(l.settingsUiResetDone)));
  }
  return true;
}

/// "Reset section" text button.
class ResetSectionButton extends ConsumerWidget {
  const ResetSectionButton({required this.section, super.key, this.onReset});

  final SettingSection section;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      key: const ValueKey('reset-section'),
      onPressed: () async {
        if (await confirmResetSection(context, ref, section)) onReset?.call();
      },
      child: Text(context.l10n.settingsUiResetSection),
    );
  }
}

/// The content of one settings page. Renders every visible setting of the
/// section by its editor, plus the custom rows of Privacy, Navigation,
/// Security, Data and About. Scrolls to and highlights [focusId].
class SettingsSectionView extends ConsumerStatefulWidget {
  const SettingsSectionView({
    required this.page,
    super.key,
    this.focusId,
    this.showHeader = true,
  });

  final SettingsPage page;

  /// Setting key or [SettingsActions] id to jump to.
  final String? focusId;

  /// Show the section title and "Reset section" inside the first card
  /// (two-pane layout). On phones they live in the app bar.
  final bool showHeader;

  @override
  ConsumerState<SettingsSectionView> createState() =>
      _SettingsSectionViewState();
}

class _SettingsSectionViewState extends ConsumerState<SettingsSectionView> {
  final _keys = <String, GlobalKey>{};
  int _generation = 0;
  String? _scrolledTo;

  String? get _focus => _focusAliases[widget.focusId] ?? widget.focusId;

  @override
  void initState() {
    super.initState();
    _scheduleScroll();
  }

  @override
  void didUpdateWidget(SettingsSectionView old) {
    super.didUpdateWidget(old);
    if (old.focusId != widget.focusId || old.page != widget.page) {
      _scrolledTo = null;
      _scheduleScroll();
    }
  }

  void _scheduleScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = _focus;
      if (!mounted || id == null || _scrolledTo == id) return;
      final ctx = _keys[id]?.currentContext;
      if (ctx == null) return;
      _scrolledTo = id;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.2,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _wrap(String id, Widget child) {
    final key = _keys.putIfAbsent(id, () => GlobalKey(debugLabel: id));
    return KeyedSubtree(
      key: key,
      child: SettingHighlight(active: id == _focus, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final caps = ref.watch(platformCapabilitiesProvider);
    final section = widget.page.section;

    Widget? resetAction;
    if (section != null) {
      resetAction = ResetSectionButton(
        section: section,
        onReset: () => setState(() {
          // Fresh keys: text fields re-read their (reset) values.
          _keys.clear();
          _generation++;
        }),
      );
    }
    String? title(int i) =>
        widget.showHeader && i == 0 ? widget.page.label(l) : null;
    Widget? action(int i) => widget.showHeader && i == 0 ? resetAction : null;

    final List<Widget> cards;
    switch (section) {
      case null:
        cards = [AboutSection(wrap: _wrap)];
      case SettingSection.privacy:
        cards = [
          SettingsGroupCard(
            title: title(0),
            action: action(0),
            children: privacySectionRows(context, ref, _wrap),
          ),
        ];
      case SettingSection.navigation:
        cards = [
          SettingsGroupCard(
            title: title(0),
            action: action(0),
            children: navigationTabRows(_wrap),
          ),
          // The cards' own margins make up the rest of the card gap.
          const SizedBox(height: Space.cardGap - 2 * Space.xxs),
          SettingsGroupCard(
            title: l.settingsUiModulesTitle,
            children: [
              SettingRow(
                title: l.settingsUiModulesDesc,
                titleColor: context.colors.onSurfaceVariant,
              ),
              ...moduleRows(_wrap),
            ],
          ),
        ];
      case SettingSection.security:
        cards = [
          SettingsGroupCard(
            title: title(0),
            action: action(0),
            children: securitySectionRows(context, ref, _wrap),
          ),
        ];
      case SettingSection.data:
        final generic = visibleSettings(
          SettingSection.data,
          s,
          caps,
        ).where((d) => d != DataSettings.storageLocation);
        cards = [
          SettingsGroupCard(
            title: title(0),
            action: action(0),
            children: [
              ...dataSectionRows(context, ref, _wrap),
              for (final d in generic) _wrap(d.key, SettingTile(d)),
            ],
          ),
        ];
      case SettingSection.general ||
          SettingSection.appearance ||
          SettingSection.dashboard ||
          SettingSection.entry ||
          SettingSection.transactions ||
          SettingSection.categories ||
          SettingSection.budgets ||
          SettingSection.recurring ||
          SettingSection.forecast ||
          SettingSection.reports ||
          SettingSection.importExport ||
          SettingSection.sync:
        final defs = visibleSettings(section, s, caps);
        cards = [
          SettingsGroupCard(
            title: title(0),
            action: action(0),
            children: defs.isEmpty
                ? [_ModuleOffNotice(section: section)]
                : [for (final d in defs) _wrap(d.key, SettingTile(d))],
          ),
        ];
    }
    _scheduleScroll();
    return KeyedSubtree(
      key: ValueKey('gen-$_generation'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: Space.xxs, bottom: Space.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards,
        ),
      ),
    );
  }
}

/// Shown when every setting of a section belongs to a switched-off module.
class _ModuleOffNotice extends ConsumerWidget {
  const _ModuleOffNotice({required this.section});

  final SettingSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final name = allSettings
        .where((d) => d.section == section && d.module != null)
        .map((d) => d.module)
        .firstOrNull;
    final module = AppModule.values.where((m) => m.name == name).firstOrNull;
    if (module == null) {
      return SettingRow(title: l.commonEmpty);
    }
    return SettingRow(
      title: l.settingsUiModuleOffNotice(moduleLabel(l, module)),
      titleColor: context.colors.onSurfaceVariant,
      trailing: FilledButton.tonal(
        onPressed: () => ref
            .read(settingsProvider.notifier)
            .set(NavigationSettings.module(module), true),
        child: Text(l.settingsUiTurnOn),
      ),
    );
  }
}
