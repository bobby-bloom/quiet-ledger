import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/settings/presentation/font_licenses.dart';
import 'package:personal_finance/features/settings/presentation/nav_tabs_editor.dart';
import 'package:personal_finance/features/settings/presentation/setting_tiles.dart';
import 'package:personal_finance/features/settings/presentation/settings_catalog.dart';

/// App version shown under About (package_info is not a dependency; keep in
/// sync with `version:` in pubspec.yaml).
const appVersion = '1.0.0+1';

typedef RowWrap = Widget Function(String id, Widget child);

/// Settings › Privacy: the catalogue switches plus "Hide amounts now"
/// (the session's privacy mode).
List<Widget> privacySectionRows(
  BuildContext context,
  WidgetRef ref,
  RowWrap wrap,
) {
  final l = context.l10n;
  final s = ref.watch(settingsProvider);
  final caps = ref.watch(platformCapabilitiesProvider);
  final privacyNow = ref.watch(privacyModeProvider);
  return [
    wrap(
      SettingsActions.privacyNow,
      MergeSemantics(
        child: SettingRow(
          title: l.settingsUiPrivacyNow,
          subtitle: l.settingsUiPrivacyNowDesc,
          onTap: () => ref.read(privacyModeProvider.notifier).toggle(),
          trailing: Switch(
            value: privacyNow,
            onChanged: (v) => ref.read(privacyModeProvider.notifier).hidden = v,
          ),
        ),
      ),
    ),
    for (final d in visibleSettings(SettingSection.privacy, s, caps))
      wrap(d.key, SettingTile(d)),
  ];
}

/// Settings › Navigation & modules: the tab editor and one card of module
/// switches.
List<Widget> navigationTabRows(RowWrap wrap) => [
  wrap(NavigationSettings.tabs.key, const NavTabsEditor()),
];

List<Widget> moduleRows(RowWrap wrap) => [
  for (final m in AppModule.values)
    wrap(
      NavigationSettings.module(m).key,
      SettingTile(NavigationSettings.module(m)),
    ),
];

/// Settings › About.
class AboutSection extends ConsumerWidget {
  const AboutSection({required this.wrap, super.key});

  final RowWrap wrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final caps = ref.watch(platformCapabilitiesProvider);
    // Written by app/bootstrap.dart: true = encrypted, false = secure
    // storage was unavailable on first start.
    final encrypted = ref
        .watch(sharedPreferencesProvider)
        ?.getBool('db.encrypted');
    final encryptionText = !caps.dbEncryption
        ? l.settingsUiAboutEncryptionUnavailable
        : (encrypted ?? false)
        ? l.settingsUiAboutEncryptionOn
        : l.settingsUiAboutEncryptionOff;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.md,
            Space.lg,
            Space.md,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.colors.primaryContainer,
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: context.colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.appTitle, style: context.text.titleMedium),
                    Text(
                      l.settingsUiAboutPrivacy,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SettingsGroupCard(
          children: [
            wrap(
              SettingsActions.version,
              SettingRow(
                title: l.settingsUiAboutVersion,
                trailing: SelectableText(appVersion, style: context.mono),
              ),
            ),
            SettingRow(
              title: l.settingsUiAboutEncryption,
              subtitle: encryptionText,
              trailing: Icon(
                caps.dbEncryption && (encrypted ?? false)
                    ? Icons.lock_outline
                    : Icons.lock_open,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            wrap(
              SettingsActions.licenses,
              SettingRow(
                title: l.settingsUiAboutLicenses,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  registerFontLicenses();
                  showLicensePage(
                    context: context,
                    applicationName: l.appTitle,
                    applicationVersion: appVersion,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
