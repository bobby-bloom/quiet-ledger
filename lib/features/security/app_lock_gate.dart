import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/security/data/privacy_channel.dart';
import 'package:personal_finance/features/security/presentation/app_lock_controller.dart';
import 'package:personal_finance/features/security/presentation/lock_screen.dart';
import 'package:personal_finance/features/settings/presentation/font_licenses.dart';

/// Wraps the app and shows the lock screen when the app lock is enabled.
///
/// * locks on start (Settings › Security › Lock on start), after the
///   background timeout, and on "Lock now"
/// * keeps the app mounted but hidden, unfocusable and silent to
///   accessibility services while locked
/// * applies the privacy options: FLAG_SECURE on Android, a blurred cover
///   while the app is inactive elsewhere (app switcher snapshot)
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  late final AppLifecycleListener _lifecycle;
  bool _inactive = false;

  @override
  void initState() {
    super.initState();
    registerFontLicenses();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applySecureFlag());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onLifecycle(AppLifecycleState s) {
    final lock = ref.read(appLockProvider.notifier);
    switch (s) {
      case AppLifecycleState.resumed:
        lock.onShown();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        lock.onHidden();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
    final inactive = s != AppLifecycleState.resumed;
    if (inactive != _inactive) setState(() => _inactive = inactive);
  }

  void _applySecureFlag() {
    final s = ref.read(settingsProvider);
    unawaited(
      ref
          .read(privacyChannelProvider)
          .setSecure(
            secure:
                s.get(PrivacySettings.hideInAppSwitcher) ||
                s.get(PrivacySettings.blockScreenshots),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      settingsProvider.select(
        (s) =>
            s.get(PrivacySettings.hideInAppSwitcher) ||
            s.get(PrivacySettings.blockScreenshots),
      ),
      (_, secure) =>
          unawaited(ref.read(privacyChannelProvider).setSecure(secure: secure)),
    );
    final locked = ref.watch(appLockProvider.select((s) => s.locked));
    final cover =
        _inactive &&
        // Android uses FLAG_SECURE; desktop windows are "inactive" whenever
        // they lose focus, so the cover is for iOS (app-switcher snapshot).
        !PrivacyChannel.supported &&
        ref.watch(platformCapabilitiesProvider).hideInAppSwitcher &&
        ref.watch(
          settingsProvider.select(
            (s) => s.get(PrivacySettings.hideInAppSwitcher),
          ),
        );

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: locked,
          child: TickerMode(
            enabled: !locked,
            child: Offstage(offstage: locked, child: widget.child),
          ),
        ),
        if (locked)
          // Outside the app's Navigator: give the lock screen its own
          // overlay for tooltips and text selection.
          Overlay(
            initialEntries: [OverlayEntry(builder: (_) => const LockScreen())],
          ),
        if (cover) const _PrivacyCover(),
      ],
    );
  }
}

/// Blurred, opaque-enough cover shown while the app is not in the
/// foreground, so the app-switcher snapshot shows no amounts.
class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.securityContentHidden,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: ColoredBox(
            color: context.colors.surface.withValues(alpha: 0.85),
            child: Center(
              child: Icon(
                Icons.lock_outline,
                size: 48,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
