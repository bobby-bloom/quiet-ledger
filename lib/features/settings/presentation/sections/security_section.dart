import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/security/data/biometrics.dart';
import 'package:personal_finance/features/security/domain/lock_credential.dart';
import 'package:personal_finance/features/security/presentation/app_lock_controller.dart';
import 'package:personal_finance/features/security/presentation/lock_setup.dart';
import 'package:personal_finance/features/settings/presentation/setting_tiles.dart';
import 'package:personal_finance/features/settings/presentation/settings_catalog.dart';

/// Lock-timeout presets in seconds.
const lockTimeoutPresets = [0, 30, 60, 300, 900, 3600];

/// Settings › Security: app lock on/off with set-up flow, biometrics,
/// change PIN/password, timeout, lock on start, lock now.
List<Widget> securitySectionRows(
  BuildContext context,
  WidgetRef ref,
  Widget Function(String id, Widget child) wrap,
) {
  final l = context.l10n;
  final s = ref.watch(settingsProvider);
  final lock = ref.watch(appLockProvider);
  final caps = ref.watch(platformCapabilitiesProvider);
  final bioAvailable =
      caps.biometrics &&
      (ref.watch(biometricsAvailableProvider).value ?? false);
  final on = s.get(SecuritySettings.appLock) && lock.enabled;
  final ctrl = ref.read(appLockProvider.notifier);
  final isPin = lock.kind != SecretKind.password;

  Future<void> toggle(bool value) async {
    if (value) {
      await showLockSetup(context);
      return;
    }
    if (!await confirmIdentity(context, ref)) return;
    if (!context.mounted) return;
    final ok = await confirmDialog(
      context,
      title: l.securityDisableTitle,
      message: l.securityDisableMessage,
      confirmLabel: l.securityTurnOff,
    );
    if (ok) await ctrl.disable();
  }

  final methodText = !on
      ? l.securityLockOffDesc
      : [
          if (lock.biometrics) l.setOptBiometric,
          if (isPin) l.securityMethodPin else l.securityMethodPassword,
        ].join(' + ');

  final timeout = s.get(SecuritySettings.lockTimeout);
  final presets = {...lockTimeoutPresets, timeout}.toList()..sort();

  return [
    wrap(
      SecuritySettings.appLock.key,
      MergeSemantics(
        child: SettingRow(
          title: l.setAppLock,
          subtitle: methodText,
          onTap: () => toggle(!on),
          trailing: Switch(value: on, onChanged: toggle),
        ),
      ),
    ),
    if (on) ...[
      if (bioAvailable)
        wrap(
          SettingsActions.biometrics,
          MergeSemantics(
            child: SettingRow(
              title: l.setOptBiometric,
              subtitle: l.securityAlsoBiometricsDesc,
              trailing: Switch(
                value: lock.biometrics,
                onChanged: (v) async {
                  if (v &&
                      !await ctrl.authenticateBiometric(
                        l.securityConfirmIdentity,
                      )) {
                    return;
                  }
                  await ctrl.setBiometrics(enabled: v);
                },
              ),
            ),
          ),
        ),
      wrap(
        SettingsActions.changeSecret,
        SettingRow(
          title: isPin ? l.securityChangePin : l.securityChangePassword,
          subtitle: l.securityChangeDesc,
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            if (!await confirmIdentity(context, ref)) return;
            if (context.mounted) await showLockSetup(context, change: true);
          },
        ),
      ),
      wrap(
        SecuritySettings.lockTimeout.key,
        SettingRow(
          title: l.setLockTimeout,
          subtitle: l.securityLockTimeoutDesc,
          trailing: DropdownButton<int>(
            value: timeout,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(8),
            items: [
              for (final p in presets)
                DropdownMenuItem(value: p, child: Text(lockTimeoutLabel(l, p))),
            ],
            onChanged: (v) {
              if (v != null) {
                unawaited(
                  ref
                      .read(settingsProvider.notifier)
                      .set(SecuritySettings.lockTimeout, v),
                );
              }
            },
          ),
        ),
      ),
      wrap(
        SecuritySettings.lockOnStart.key,
        SettingTile(SecuritySettings.lockOnStart),
      ),
      wrap(
        SettingsActions.lockNow,
        SettingRow(
          title: l.securityLockNow,
          leading: Icon(Icons.lock_outline, color: context.colors.primary),
          titleColor: context.colors.primary,
          onTap: () => lockNow(ref),
        ),
      ),
    ],
  ];
}
