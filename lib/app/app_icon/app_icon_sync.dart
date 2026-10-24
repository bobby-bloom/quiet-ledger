import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/app_icon/app_icon_host.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/platform/notifications.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';

/// Accent presets that ship as launcher icons on Android and iOS
/// (tool/app_icons generates them; the native side knows them by their
/// `AccentScheme.name`).
const launcherIconPresets = [
  AccentScheme.spruce,
  AccentScheme.blue,
  AccentScheme.violet,
  AccentScheme.amber,
  AccentScheme.rose,
  AccentScheme.slate,
];

/// What the app icon shows: the light theme's primary as background, the
/// mark in onPrimary, and the launcher preset for platforms that only have
/// the generated presets.
@immutable
class AppIconSpec {
  const AppIconSpec({
    required this.background,
    required this.foreground,
    required this.preset,
  });

  /// From the light colour scheme of [theme] (the dark scheme's primary is
  /// too light to carry a white mark).
  factory AppIconSpec.of(AppTheme theme, ColorScheme light) => AppIconSpec(
    background: light.primary,
    foreground: light.onPrimary,
    preset: launcherIconPresets.contains(theme.accent)
        ? theme.accent
        : closestIconPreset(light.primary),
  );

  final Color background;
  final Color foreground;
  final AccentScheme preset;

  @override
  bool operator ==(Object other) =>
      other is AppIconSpec &&
      other.background == background &&
      other.foreground == foreground &&
      other.preset == preset;

  @override
  int get hashCode => Object.hash(background, foreground, preset);
}

final Map<AccentScheme, Color> _presetPrimaries = {
  for (final p in launcherIconPresets)
    p: AppTheme(accent: p).light().colorScheme.primary,
};

/// The launcher preset whose primary is nearest to [primary] (custom and
/// system accent colours).
AccentScheme closestIconPreset(Color primary) {
  double distance(Color c) {
    final dr = c.r - primary.r;
    final dg = c.g - primary.g;
    final db = c.b - primary.b;
    return dr * dr + dg * dg + db * db;
  }

  return launcherIconPresets.reduce(
    (a, b) => distance(_presetPrimaries[a]!) <= distance(_presetPrimaries[b]!)
        ? a
        : b,
  );
}

/// Applies an [AppIconSpec] to the platform.
abstract interface class AppIconPlatform {
  /// [launcher]: whether the Android/iOS home-screen icon follows the
  /// accent (otherwise it shows the default spruce icon).
  Future<void> apply(AppIconSpec spec, {required bool launcher});
}

final appIconPlatformProvider = Provider<AppIconPlatform>(
  (ref) => const _SystemAppIcon(),
);

class _SystemAppIcon implements AppIconPlatform {
  const _SystemAppIcon();

  static const _channel = MethodChannel('personal_finance/app_icon');

  @override
  Future<void> apply(AppIconSpec spec, {required bool launcher}) async {
    final mobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (mobile) {
      final preset = launcher ? spec.preset : AccentScheme.spruce;
      await _channel.invokeMethod<void>('setLauncherIcon', {
        'name': preset.name,
      });
    } else {
      await applyHostIcon(
        background: spec.background,
        foreground: spec.foreground,
      );
    }
  }
}

/// Keeps the app icon in the accent colour: applies [spec] at start and
/// whenever it (or the launcher setting) changes, after the changes settle
/// (a colour picker sends many in a row).
class AppIconSync extends ConsumerStatefulWidget {
  const AppIconSync({required this.spec, required this.child, super.key});

  final AppIconSpec spec;
  final Widget child;

  @override
  ConsumerState<AppIconSync> createState() => _AppIconSyncState();
}

class _AppIconSyncState extends ConsumerState<AppIconSync> {
  static const _settle = Duration(milliseconds: 500);

  Timer? _timer;
  (AppIconSpec, bool)? _wanted;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _request(AppIconSpec spec, bool launcher) {
    if (_wanted == (spec, launcher)) return;
    _wanted = (spec, launcher);
    ref.read(notificationServiceProvider).setAccentColor(spec.background);
    _timer?.cancel();
    _timer = Timer(_settle, () async {
      try {
        await ref.read(appIconPlatformProvider).apply(spec, launcher: launcher);
      } on MissingPluginException {
        // Platform without an icon hook (tests, older runners).
      } on Object catch (e) {
        debugPrint('Could not update the app icon: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _request(
      widget.spec,
      ref.watch(
        settingsProvider.select((s) => s.get(AppearanceSettings.accentAppIcon)),
      ),
    );
    return widget.child;
  }
}
