import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_controller.dart';

/// Shown after a successful commit.
class ImportDoneView extends ConsumerWidget {
  const ImportDoneView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(importWizardProvider);
    final c = ref.read(importWizardProvider.notifier);
    final count = s.preparation?.summary.transactions ?? 0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: context.colors.primary,
            ),
            const SizedBox(height: Space.md),
            Text(l.importDoneTitle, style: context.text.headlineSmall),
            const SizedBox(height: Space.xs),
            Text(l.importDoneMessage(count), textAlign: TextAlign.center),
            const SizedBox(height: Space.xl),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.format_list_bulleted),
                  label: Text(l.importShowTransactions),
                  onPressed: () => context.go('/transactions'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: Text(l.importHistory),
                  onPressed: () => context.push('/more/import/history'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l.importAgain),
                  onPressed: c.reset,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.undo),
                  label: Text(l.importUndo),
                  onPressed: s.busy
                      ? null
                      : () => c.run(() async {
                          final messenger = ScaffoldMessenger.of(context);
                          await c.undoCommitted();
                          messenger.showSnackBar(
                            SnackBar(content: Text(l.importUndone)),
                          );
                        }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
