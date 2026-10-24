import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';

/// Shown instead of a screen whose module is switched off in
/// Settings › Navigation & modules.
class ModuleDisabledNotice extends StatelessWidget {
  const ModuleDisabledNotice({required this.moduleName, super.key});

  final String moduleName;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.toggle_off_outlined,
              size: 40,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: Space.sm),
            Text(
              l.categoriesModuleOff(moduleName),
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.md),
            FilledButton.tonal(
              onPressed: () => context.push('/more/settings'),
              child: Text(l.categoriesOpenSettings),
            ),
          ],
        ),
      ),
    );
  }
}
