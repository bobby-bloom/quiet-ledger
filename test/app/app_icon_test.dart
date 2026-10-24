import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/app/app_icon/app_icon_image.dart';
import 'package:personal_finance/app/app_icon/app_icon_sync.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/platform/notifications.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';

import '../helpers/test_app.dart';

class _FakeIcons implements AppIconPlatform {
  final applied = <(AppIconSpec, bool)>[];

  @override
  Future<void> apply(AppIconSpec spec, {required bool launcher}) async =>
      applied.add((spec, launcher));
}

class _Notifications extends NoopNotificationService {
  Color? accent;

  @override
  void setAccentColor(Color color) => accent = color;
}

AppIconSpec _spec(AccentScheme accent, {Color custom = Colors.black}) {
  final theme = AppTheme(accent: accent, customAccent: custom);
  return AppIconSpec.of(theme, theme.light().colorScheme);
}

void main() {
  group('launcher preset', () {
    test('presets keep their own icon', () {
      for (final p in launcherIconPresets) {
        expect(_spec(p).preset, p);
        expect(closestIconPreset(_spec(p).background), p);
      }
    });

    test('custom colours take the closest preset', () {
      expect(
        _spec(AccentScheme.custom, custom: const Color(0xFF2050B0)).preset,
        AccentScheme.blue,
      );
      expect(
        _spec(AccentScheme.custom, custom: const Color(0xFFB03050)).preset,
        AccentScheme.rose,
      );
      expect(
        _spec(AccentScheme.custom, custom: const Color(0xFF1F5A53)).preset,
        AccentScheme.spruce,
      );
    });

    test('the background is the light primary, the mark onPrimary', () {
      final light = const AppTheme(accent: AccentScheme.violet).light();
      final spec = _spec(AccentScheme.violet);
      expect(spec.background, light.colorScheme.primary);
      expect(spec.foreground, light.colorScheme.onPrimary);
    });
  });

  group('icon images', () {
    test('ICO directory and 32-bit bitmap entries', () {
      // 2×2: red, green / blue, transparent (RGBA, top row first).
      final rgba = Uint8List.fromList([
        255, 0, 0, 255, 0, 255, 0, 255, //
        0, 0, 255, 255, 0, 0, 0, 0,
      ]);
      final bmp = icoBitmap(2, rgba);
      final info = ByteData.sublistView(bmp);
      expect(info.getUint32(0, Endian.little), 40);
      expect(info.getInt32(8, Endian.little), 4); // height doubled
      // Bottom row first, BGRA: blue, then transparent.
      expect(bmp.sublist(40, 48), [255, 0, 0, 255, 0, 0, 0, 0]);
      expect(bmp.sublist(48, 56), [0, 0, 255, 255, 0, 255, 0, 255]);
      expect(bmp.length, 40 + 16 + 2 * 4); // pixels + 32-bit mask rows

      final ico = encodeIco([(2, bmp), (256, Uint8List(3))]);
      final d = ByteData.sublistView(ico);
      expect(d.getUint16(2, Endian.little), 1);
      expect(d.getUint16(4, Endian.little), 2);
      expect(d.getUint8(6), 2);
      expect(d.getUint8(22), 0); // 256 is stored as 0
      expect(d.getUint32(6 + 12, Endian.little), 6 + 32);
      expect(d.getUint32(22 + 12, Endian.little), 6 + 32 + bmp.length);
      expect(ico.length, 6 + 32 + bmp.length + 3);
    });

    testWidgets('rendered icon: accent background, mark in onPrimary', (
      tester,
    ) async {
      await tester.runAsync(() async {
        const bg = Color(0xFF2D5DA8);
        final image = await renderAppIcon(
          256,
          background: bg,
          foreground: Colors.white,
        );
        final px = (await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!;
        image.dispose();
        Color at(int x, int y) {
          final i = (y * 256 + x) * 4;
          return Color.fromARGB(
            px.getUint8(i + 3),
            px.getUint8(i),
            px.getUint8(i + 1),
            px.getUint8(i + 2),
          );
        }

        expect(at(0, 0).a, 0); // rounded corner
        expect(at(20, 128), bg); // background
        expect(at(128, 152), Colors.white); // the total line
      });
    });
  });

  group('AppIconSync', () {
    late AppDatabase db;
    late _FakeIcons icons;
    late _Notifications notifications;

    setUp(() {
      db = newTestDb();
      icons = _FakeIcons();
      notifications = _Notifications();
    });
    tearDown(() => db.close());

    Widget app(AppIconSpec spec, {bool launcher = true}) => testApp(
      AppIconSync(spec: spec, child: const SizedBox()),
      db: db,
      overrides: [
        appIconPlatformProvider.overrideWithValue(icons),
        notificationServiceProvider.overrideWithValue(notifications),
        if (!launcher)
          initialSettingsProvider.overrideWithValue(
            SettingsSnapshot({
              SettingsSnapshot.rowId(
                AppearanceSettings.accentAppIcon.key,
                'global',
              ): false,
            }),
          ),
      ],
    );

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('applies once the colour settles', (tester) async {
      await tester.pumpWidget(app(_spec(AccentScheme.spruce)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(app(_spec(AccentScheme.blue)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(app(_spec(AccentScheme.rose)));
      expect(icons.applied, isEmpty);
      expect(notifications.accent, _spec(AccentScheme.rose).background);
      await tester.pump(const Duration(seconds: 1));
      expect(icons.applied, [(_spec(AccentScheme.rose), true)]);

      // Same spec again: nothing to do.
      await tester.pumpWidget(app(_spec(AccentScheme.rose)));
      await tester.pump(const Duration(seconds: 1));
      expect(icons.applied, hasLength(1));
      await unmount(tester);
    });

    testWidgets('passes the launcher setting on', (tester) async {
      await tester.pumpWidget(app(_spec(AccentScheme.amber), launcher: false));
      await tester.pump(const Duration(seconds: 1));
      expect(icons.applied.single.$2, isFalse);
      await unmount(tester);
    });
  });
}
