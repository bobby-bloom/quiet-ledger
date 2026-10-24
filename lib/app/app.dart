import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/app_icon/app_icon_sync.dart';
import 'package:personal_finance/app/router.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/security/app_lock_gate.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class PersonalFinanceApp extends ConsumerWidget {
  const PersonalFinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    final lang = ref.watch(languageCodeProvider);
    final caps = ref.watch(platformCapabilitiesProvider);
    final useDynamic =
        caps.dynamicColor && s.get(AppearanceSettings.dynamicColor);

    final dynamicSeed = useDynamic
        ? ref.watch(dynamicSeedProvider).value
        : null;
    final theme = AppTheme(
      accent: dynamicSeed != null
          ? AccentScheme.custom
          : s.get(AppearanceSettings.accentScheme),
      customAccent:
          dynamicSeed ?? Color(s.get(AppearanceSettings.customAccent)),
      highContrast: s.get(AppearanceSettings.highContrast),
      density: s.get(AppearanceSettings.density),
    );
    final textScale = s.get(AppearanceSettings.textScale) / 100;
    final light = theme.light();
    return AppIconSync(
      spec: AppIconSpec.of(theme, light.colorScheme),
      child: MaterialApp.router(
        onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: light,
        darkTheme: theme.dark(),
        themeMode: switch (s.get(AppearanceSettings.themeMode)) {
          AppThemeMode.system => ThemeMode.system,
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
        },
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(mq.textScaler.scale(1) * textScale),
            ),
            child: WindowSizedTheme(
              child: AppLockGate(child: child ?? const SizedBox.shrink()),
            ),
          );
        },
      ),
    );
  }
}

/// Platform accent colour (Material You on Android, accent colour on
/// desktop), used as seed when dynamic colour is enabled.
final dynamicSeedProvider = FutureProvider<Color?>((ref) async {
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    if (palette != null) return Color(palette.primary.get(40));
    return await DynamicColorPlugin.getAccentColor();
  } on Object {
    return null;
  }
});
