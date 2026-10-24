import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
// `timezone` is a dependency of flutter_local_notifications; only its UTC
// location is used (scheduled instants are converted to UTC).
import 'package:timezone/timezone.dart' as tz;

/// Kinds of local notifications; each maps to an Android channel and, except
/// [backup] (always on: a failing backup must not go unnoticed), to a
/// per-type toggle in Settings › Recurring & reminders.
enum NotificationKind { bill, income, lowBalance, budget, backup }

/// A reminder to be shown at [at] (local time). Quiet hours are applied by
/// the service.
@immutable
class ReminderRequest {
  const ReminderRequest({
    required this.at,
    required this.title,
    required this.body,
    required this.kind,
    this.payload,
  });

  final DateTime at;
  final String title;
  final String body;
  final NotificationKind kind;

  /// Passed back on tap, e.g. `plan:recurring` or `budget:<categoryId>`.
  final String? payload;
}

/// When the reminder for an occurrence on [occurrenceDate] fires:
/// [remindDaysBefore] days earlier at [notifyTimeMinutes] after midnight.
DateTime reminderTime(
  DateTime occurrenceDate,
  int remindDaysBefore,
  int notifyTimeMinutes,
) {
  final minutes = notifyTimeMinutes.clamp(0, 24 * 60 - 1);
  return DateTime(
    occurrenceDate.year,
    occurrenceDate.month,
    occurrenceDate.day - remindDaysBefore,
    minutes ~/ 60,
    minutes % 60,
  );
}

/// Whether [minuteOfDay] falls in quiet hours `[start, end)` (which may wrap
/// past midnight). Equal start and end means no quiet hours.
bool inQuietHours(int minuteOfDay, int start, int end) {
  if (start == end) return false;
  if (start < end) return minuteOfDay >= start && minuteOfDay < end;
  return minuteOfDay >= start || minuteOfDay < end;
}

/// Moves [at] to the end of the quiet hours `[start, end)` when it falls
/// inside them.
DateTime applyQuietHours(DateTime at, int start, int end) {
  final m = at.hour * 60 + at.minute;
  if (!inQuietHours(m, start, end)) return at;
  final base = DateTime(at.year, at.month, at.day, end ~/ 60, end % 60);
  // Wrapping window: before midnight the end is tomorrow.
  if (start > end && m >= start) {
    return DateTime(at.year, at.month, at.day + 1, end ~/ 60, end % 60);
  }
  return base;
}

/// Stable 31-bit notification id for [key] (FNV-1a).
int notificationId(String key) {
  var h = 0x811c9dc5;
  for (final c in key.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

/// Local notifications (bill reminders, low-balance and budget alerts).
///
/// Every method is best effort: failures are swallowed and the service is
/// a no-op where notifications are unavailable (web, failed init).
abstract interface class NotificationService {
  /// Initialises the plugin. Returns false when notifications are not
  /// available. Safe to call repeatedly.
  Future<bool> init({Map<NotificationKind, String> channelNames});

  /// Asks the OS for permission (Android 13+, iOS, macOS). Call from a user
  /// action.
  Future<bool> requestPermission();

  /// Accent colour for Android's notification icon and accents, kept in
  /// sync with the theme (lib/app/app_icon). Applies to notifications
  /// shown or scheduled from now on.
  void setAccentColor(Color color);

  /// Replaces all scheduled reminders of [ruleId] with [reminders] (at most
  /// [maxRemindersPerRule]; past ones and disabled kinds are dropped).
  Future<void> scheduleRuleReminders(
    String ruleId,
    List<ReminderRequest> reminders,
  );

  /// Cancels the scheduled reminders of [ruleId].
  Future<void> cancelRule(String ruleId);

  /// Cancels every scheduled reminder, then schedules [byRule].
  Future<void> rescheduleAll(Map<String, List<ReminderRequest>> byRule);

  /// Shows a low-balance alert for [accountId] now (or after quiet hours).
  Future<void> showLowBalance({
    required String accountId,
    required String title,
    required String body,
  });

  /// Shows a budget alert identified by [key] (e.g. `<period>|<category>`).
  Future<void> showBudgetAlert({
    required String key,
    required String title,
    required String body,
    String? payload,
  });

  /// Shows a backup problem (failed or paused scheduled backup) now; tapping
  /// it opens the export screen (payload `backup`).
  Future<void> showBackupProblem({required String title, required String body});

  /// Payloads of tapped notifications (including the one that launched the
  /// app).
  Stream<String> get taps;
}

const maxRemindersPerRule = 3;

/// No-op implementation (web, tests, failed init).
class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<bool> init({Map<NotificationKind, String> channelNames = const {}}) =>
      Future.value(false);

  @override
  Future<bool> requestPermission() => Future.value(false);

  @override
  void setAccentColor(Color color) {}

  @override
  Future<void> scheduleRuleReminders(
    String ruleId,
    List<ReminderRequest> reminders,
  ) async {}

  @override
  Future<void> cancelRule(String ruleId) async {}

  @override
  Future<void> rescheduleAll(Map<String, List<ReminderRequest>> byRule) async {}

  @override
  Future<void> showLowBalance({
    required String accountId,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> showBudgetAlert({
    required String key,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<void> showBackupProblem({
    required String title,
    required String body,
  }) async {}

  @override
  Stream<String> get taps => const Stream.empty();
}

/// [NotificationService] over flutter_local_notifications.
class LocalNotificationService implements NotificationService {
  LocalNotificationService({
    required this.settings,
    FlutterLocalNotificationsPlugin? plugin,
    DateTime Function()? now,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _now = now ?? DateTime.now;

  /// Current settings (toggles, quiet hours).
  final SettingsSnapshot Function() settings;
  final FlutterLocalNotificationsPlugin _plugin;
  final DateTime Function() _now;
  final _taps = StreamController<String>.broadcast();
  Future<bool>? _init;
  bool _ready = false;
  Map<NotificationKind, String> _channelNames = const {};
  Color? _accent;

  static const _channelIds = {
    NotificationKind.bill: 'bills',
    NotificationKind.income: 'income',
    NotificationKind.lowBalance: 'low_balance',
    NotificationKind.budget: 'budget',
    NotificationKind.backup: 'backup',
  };

  static const _defaultChannelNames = {
    NotificationKind.bill: 'Bills',
    NotificationKind.income: 'Income',
    NotificationKind.lowBalance: 'Low balance',
    NotificationKind.budget: 'Budgets',
    NotificationKind.backup: 'Backups',
  };

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<bool> init({Map<NotificationKind, String> channelNames = const {}}) {
    if (channelNames.isNotEmpty) _channelNames = channelNames;
    return _init ??= _doInit();
  }

  @override
  void setAccentColor(Color color) => _accent = color;

  Future<bool> _doInit() async {
    try {
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      final ok = await _plugin.initialize(
        settings: const InitializationSettings(
          // White mark from tool/app_icons, tinted with [setAccentColor].
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          iOS: darwin,
          macOS: darwin,
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
          windows: WindowsInitializationSettings(
            appName: 'Quiet Ledger',
            appUserModelId: 'Dev.PersonalFinance.QuietLedger',
            guid: '5b0c2f62-8a3e-4d7a-9b61-3f1d2c8e7a10',
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          final p = r.payload;
          if (p != null && p.isNotEmpty) _taps.add(p);
        },
      );
      _ready = ok ?? true;
      if (_ready) unawaited(_emitLaunchPayload());
      return _ready;
    } on Object catch (e) {
      debugPrint('Notifications unavailable: $e');
      _ready = false;
      return false;
    }
  }

  Future<void> _emitLaunchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      final p = details?.notificationResponse?.payload;
      if ((details?.didNotificationLaunchApp ?? false) &&
          p != null &&
          p.isNotEmpty) {
        _taps.add(p);
      }
    } on Object {
      // Not supported on this platform.
    }
  }

  Future<bool> _ensure() async => _ready || await init();

  @override
  Future<bool> requestPermission() async {
    if (!await _ensure()) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      final mac = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (mac != null) {
        return await mac.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return true;
    } on Object {
      return false;
    }
  }

  bool _enabled(NotificationKind kind) {
    final s = settings();
    return switch (kind) {
      NotificationKind.bill => s.get(RecurringSettings.notifyBills),
      NotificationKind.income => s.get(RecurringSettings.notifyIncome),
      NotificationKind.lowBalance => s.get(RecurringSettings.notifyLowBalance),
      NotificationKind.budget =>
        s.get(RecurringSettings.notifyBudget) &&
            s.moduleEnabled(AppModule.budgets),
      NotificationKind.backup => true,
    };
  }

  DateTime _quiet(DateTime at) {
    final s = settings();
    return applyQuietHours(
      at,
      s.get(RecurringSettings.quietHoursStart),
      s.get(RecurringSettings.quietHoursEnd),
    );
  }

  NotificationDetails _details(NotificationKind kind) {
    final channel = _channelIds[kind]!;
    final name = _channelNames[kind] ?? _defaultChannelNames[kind]!;
    final important =
        kind == NotificationKind.bill || kind == NotificationKind.lowBalance;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        name,
        importance: important ? Importance.high : Importance.defaultImportance,
        priority: important ? Priority.high : Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
        color: _accent,
      ),
      iOS: DarwinNotificationDetails(threadIdentifier: channel),
      macOS: DarwinNotificationDetails(threadIdentifier: channel),
    );
  }

  static String _slotKey(String ruleId, int slot) => 'rule:$ruleId#$slot';

  @override
  Future<void> cancelRule(String ruleId) async {
    if (!await _ensure()) return;
    for (var i = 0; i < maxRemindersPerRule; i++) {
      try {
        await _plugin.cancel(id: notificationId(_slotKey(ruleId, i)));
      } on Object {
        // ignore
      }
    }
  }

  @override
  Future<void> scheduleRuleReminders(
    String ruleId,
    List<ReminderRequest> reminders,
  ) async {
    if (!await _ensure()) return;
    await cancelRule(ruleId);
    await _scheduleSlots(ruleId, reminders);
  }

  Future<void> _scheduleSlots(
    String ruleId,
    List<ReminderRequest> reminders,
  ) async {
    final now = _now();
    var slot = 0;
    for (final r in reminders) {
      if (slot >= maxRemindersPerRule) break;
      if (!_enabled(r.kind)) continue;
      final at = _quiet(r.at);
      if (!at.isAfter(now)) continue;
      try {
        await _plugin.zonedSchedule(
          id: notificationId(_slotKey(ruleId, slot)),
          title: r.title,
          body: r.body,
          payload: r.payload,
          scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
          notificationDetails: _details(r.kind),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        slot++;
      } on Object catch (e) {
        // Scheduling unsupported (e.g. Linux) or permission missing.
        debugPrint('Could not schedule reminder: $e');
        return;
      }
    }
  }

  @override
  Future<void> rescheduleAll(Map<String, List<ReminderRequest>> byRule) async {
    if (!await _ensure()) return;
    try {
      await _plugin.cancelAllPendingNotifications();
    } on Object {
      // Not supported everywhere: fall back to cancelling known slots.
      for (final id in byRule.keys) {
        await cancelRule(id);
      }
    }
    for (final e in byRule.entries) {
      await _scheduleSlots(e.key, e.value);
    }
  }

  Future<void> _showNow(
    String key,
    NotificationKind kind,
    String title,
    String body,
    String? payload,
  ) async {
    if (!_enabled(kind) || !await _ensure()) return;
    final now = _now();
    final at = _quiet(now);
    final id = notificationId(key);
    try {
      if (at.isAfter(now)) {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          payload: payload,
          scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
          notificationDetails: _details(kind),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } else {
        await _plugin.show(
          id: id,
          title: title,
          body: body,
          payload: payload,
          notificationDetails: _details(kind),
        );
      }
    } on Object catch (e) {
      debugPrint('Could not show notification: $e');
    }
  }

  @override
  Future<void> showLowBalance({
    required String accountId,
    required String title,
    required String body,
  }) => _showNow(
    'low:$accountId',
    NotificationKind.lowBalance,
    title,
    body,
    'account:$accountId',
  );

  @override
  Future<void> showBudgetAlert({
    required String key,
    required String title,
    required String body,
    String? payload,
  }) => _showNow('budget:$key', NotificationKind.budget, title, body, payload);

  @override
  Future<void> showBackupProblem({
    required String title,
    required String body,
  }) => _showNow('backup', NotificationKind.backup, title, body, 'backup');

  void dispose() => unawaited(_taps.close());
}

/// The app's notification service; a no-op where notifications are not
/// available.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  if (!ref.watch(platformCapabilitiesProvider).notifications) {
    return const NoopNotificationService();
  }
  final service = LocalNotificationService(
    settings: () => ref.read(settingsProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
