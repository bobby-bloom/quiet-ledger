import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/backup_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/export/data/backup_keys.dart';
import 'package:personal_finance/features/export/domain/backup_health.dart';

/// Whether there is any live transaction (no backup nagging on an empty
/// app).
final hasLedgerDataProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT EXISTS(SELECT 1 FROM transactions WHERE deleted_at IS NULL) '
        'AS e',
        readsFrom: {db.transactions},
      )
      .watchSingle()
      .map((r) => r.read<bool>('e'));
});

/// Current [BackupHealth] from the backup settings and the backup
/// password check.
final backupHealthProvider = Provider<BackupHealth>((ref) {
  final s = ref.watch(settingsProvider);
  DateTime? at(String? v) => v == null ? null : DateTime.tryParse(v);
  final ring = ref.watch(backupKeyringProvider);
  final hasKeys = ring.value != null;
  return backupHealth(
    passwordCheckedAt: hasKeys
        ? at(s.get(BackupSettings.passwordCheckedAt)) ??
              ring.value!.current.createdAt
        : null,
    now: DateTime.now(),
    hasData: ref.watch(hasLedgerDataProvider).value ?? false,
    staleDays: s.get(BackupSettings.staleDays),
    lastVerified: at(s.get(BackupSettings.lastVerified)),
    lastScheduled: at(s.get(ImportExportSettings.lastAutoExport)),
    lastAttempt: at(s.get(BackupSettings.lastAttempt)),
    lastError: s.get(BackupSettings.lastError),
  );
});

/// Warning shown on the dashboard and the export screen while the data is
/// not safely backed up. Renders nothing when everything is fine.
/// [onBackUp] replaces the default action (open the export screen).
class BackupHealthBanner extends ConsumerWidget {
  const BackupHealthBanner({this.onBackUp, this.margin, super.key});

  final VoidCallback? onBackUp;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(backupHealthProvider);
    if (health.ok) return const SizedBox.shrink();
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final last = health.lastVerified?.toLocal();
    final failing =
        health.status == BackupStatus.failing ||
        health.status == BackupStatus.interrupted;
    final text = switch (health.status) {
      BackupStatus.checkPassword => l.backupHealthCheckPassword,
      BackupStatus.never => l.backupHealthNever,
      BackupStatus.stale => l.backupHealthStale(
        last == null ? '' : dates.medium(last),
      ),
      BackupStatus.failing => l.backupHealthFailing(health.error ?? ''),
      BackupStatus.interrupted => l.backupHealthInterrupted,
      BackupStatus.ok => '',
    };
    final bg = failing
        ? context.colors.errorContainer
        : context.colors.secondaryContainer;
    final fg = failing
        ? context.colors.onErrorContainer
        : context.colors.onSecondaryContainer;
    return Padding(
      padding: margin ?? const EdgeInsets.only(bottom: Space.md),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.sm,
            Space.xs,
            Space.sm,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            children: [
              Icon(
                failing ? Icons.error_outline : Icons.backup_outlined,
                color: fg,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  text,
                  style: context.text.bodyMedium?.copyWith(color: fg),
                ),
              ),
              const SizedBox(width: Space.xs),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: fg),
                onPressed: switch (health.status) {
                  BackupStatus.checkPassword => () => context.push(
                    '/more/export/encryption',
                  ),
                  _ when failing => () => context.push('/more/export/folder'),
                  _ => onBackUp ?? () => context.push('/more/export'),
                },
                child: Text(switch (health.status) {
                  BackupStatus.checkPassword => l.backupPasswordCheck,
                  _ when failing => l.backupHealthDetails,
                  _ => l.backupHealthBackUp,
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
