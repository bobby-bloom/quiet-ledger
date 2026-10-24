import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:personal_finance/app/bootstrap.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_files.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// Shown when [bootstrap] fails. Never deletes anything: it offers to retry
/// or, on native platforms, to move the unreadable database aside
/// ([onStartFresh]) and start empty so a backup can be restored.
class BootErrorApp extends StatelessWidget {
  const BootErrorApp({
    required this.error,
    required this.onRetry,
    this.onStartFresh,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;

  /// Moves the database aside; returns the folder it went to. Hidden where
  /// files cannot be moved (web) or when null.
  final Future<String?> Function()? onStartFresh;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: const AppTheme().light(),
      darkTheme: const AppTheme().dark(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _BootErrorScreen(
        error: error,
        onRetry: onRetry,
        onStartFresh: onStartFresh,
      ),
    );
  }
}

class _BootErrorScreen extends StatefulWidget {
  const _BootErrorScreen({
    required this.error,
    required this.onRetry,
    required this.onStartFresh,
  });

  final Object error;
  final VoidCallback onRetry;
  final Future<String?> Function()? onStartFresh;

  @override
  State<_BootErrorScreen> createState() => _BootErrorScreenState();
}

class _BootErrorScreenState extends State<_BootErrorScreen> {
  bool _busy = false;

  Future<void> _startFresh() async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.backupBootStartFresh,
      message: l.backupBootStartFreshConfirm,
      confirmLabel: l.backupBootStartFresh,
      destructive: false,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final moved = await widget.onStartFresh!();
      if (!mounted) return;
      if (moved != null) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: SelectableText(l.backupBootMoved(moved)),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.commonClose),
              ),
            ],
          ),
        );
      }
      widget.onRetry();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.commonError('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cause = switch (widget.error) {
      MissingDatabaseKeyException() => l.backupBootMissingKey,
      NewerDatabaseException() => l.backupBootNewer,
      _ => l.backupBootGeneric,
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: context.colors.error,
                  ),
                  const SizedBox(height: Space.md),
                  Text(
                    l.backupBootTitle,
                    textAlign: TextAlign.center,
                    style: context.text.titleLarge,
                  ),
                  const SizedBox(height: Space.sm),
                  Text(cause, textAlign: TextAlign.center),
                  const SizedBox(height: Space.sm),
                  Text(
                    l.backupBootKept,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  ExpansionTile(
                    title: Text(l.backupBootDetails),
                    children: [
                      SelectableText('${widget.error}', style: context.mono),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  FilledButton(
                    onPressed: _busy ? null : widget.onRetry,
                    child: Text(l.commonRetry),
                  ),
                  if (widget.onStartFresh != null && canQuarantineDatabase) ...[
                    const SizedBox(height: Space.sm),
                    OutlinedButton(
                      onPressed: _busy ? null : _startFresh,
                      child: Text(l.backupBootStartFresh),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
