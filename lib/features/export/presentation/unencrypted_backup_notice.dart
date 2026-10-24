import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/features/export/data/backup_keys.dart';

/// Says that backups leave the device unencrypted, while no backup password
/// is set (docs/BACKUP.md, guarantee 9). Renders nothing while the keyring
/// loads or once a password is set. [showAction] adds a button to the
/// password screen.
class UnencryptedBackupNotice extends ConsumerWidget {
  const UnencryptedBackupNotice({this.showAction = true, super.key});

  final bool showAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ring = ref.watch(backupKeyringProvider);
    if (!ring.hasValue || ring.value != null) return const SizedBox.shrink();
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_open_outlined,
            size: 18,
            color: context.finance.warning,
          ),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.backupUnencryptedWarning, style: context.text.bodySmall),
                if (showAction)
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => context.push('/more/export/encryption'),
                    child: Text(l.backupPasswordSet),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Snackbar after a backup was saved: [message], plus a warning and a way
/// to set a password when the backup is not [encrypted].
SnackBar backupSavedSnackBar(
  BuildContext context,
  String message, {
  required bool encrypted,
}) {
  if (encrypted) return SnackBar(content: Text(message));
  final l = context.l10n;
  return SnackBar(
    content: Text(
      [message, l.backupSavedUnencrypted].where((s) => s.isNotEmpty).join('\n'),
    ),
    duration: const Duration(seconds: 8),
    persist: false,
    action: SnackBarAction(
      label: l.backupPasswordSet,
      onPressed: () {
        if (context.mounted) unawaited(context.push('/more/export/encryption'));
      },
    ),
  );
}
