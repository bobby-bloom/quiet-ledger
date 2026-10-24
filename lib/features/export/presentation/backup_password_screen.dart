import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/csv/file_output.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/export/data/backup_keys.dart';
import 'package:personal_finance/features/export/domain/backup_crypto.dart';
import 'package:personal_finance/features/export/domain/backup_settings.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// `/more/export/encryption`: set, check and change the backup password and
/// the recovery key (docs/BACKUP.md).
class BackupPasswordScreen extends ConsumerWidget {
  const BackupPasswordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ring = ref.watch(backupKeyringProvider);
    final required = ref.watch(backupEncryptionRequiredProvider);
    final dates = ref.watch(dateFormatsProvider);
    final checked = DateTime.tryParse(
      ref.watch(settingsProvider).get(BackupSettings.passwordCheckedAt) ?? '',
    );
    final gutter = WindowSize.of(context).isCompact
        ? Space.phoneGutter
        : Space.desktopGutter;
    return Scaffold(
      appBar: AppBar(title: Text(l.backupPasswordTitle)),
      body: SafeArea(
        top: false,
        child: AsyncView(
          value: ring,
          data: (keys) => ListView(
            padding: EdgeInsets.fromLTRB(gutter, Space.xs, gutter, Space.xxl),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.backupPasswordDesc),
                        if (required) ...[
                          const SizedBox(height: Space.sm),
                          Text(
                            l.backupPasswordRequired,
                            style: context.text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: Space.md),
                        if (keys == null)
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.lock_outline),
                              label: Text(l.backupPasswordSet),
                              onPressed: () =>
                                  _showSetup(context, ref, _SetupMode.create),
                            ),
                          )
                        else ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.lock_outline,
                              color: context.colors.primary,
                            ),
                            title: Text(l.backupPasswordOn),
                            subtitle: Text(
                              l.backupPasswordSince(
                                dates.medium(keys.current.createdAt.toLocal()),
                              ),
                            ),
                          ),
                          if (checked != null)
                            Text(
                              l.backupPasswordLastChecked(
                                dates.medium(checked.toLocal()),
                              ),
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          const SizedBox(height: Space.sm),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: Space.xs,
                            runSpacing: Space.xs,
                            children: [
                              TextButton(
                                onPressed: () => _showSetup(
                                  context,
                                  ref,
                                  _SetupMode.recoveryKey,
                                ),
                                child: Text(l.backupPasswordNewRecovery),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    _showSetup(context, ref, _SetupMode.change),
                                child: Text(l.backupPasswordChange),
                              ),
                              FilledButton.tonal(
                                onPressed: () => checkBackupPassword(
                                  context,
                                  ref,
                                  keys.current,
                                ),
                                child: Text(l.backupPasswordCheck),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _markChecked(WidgetRef ref) => ref
    .read(settingsProvider.notifier)
    .set(BackupSettings.passwordCheckedAt, DateTime.now().toIso8601String());

/// Asks for the backup password and confirms it is still known.
Future<void> checkBackupPassword(
  BuildContext context,
  WidgetRef ref,
  BackupKeys keys,
) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final password = await showDialog<String>(
    context: context,
    builder: (_) => _PasswordPrompt(title: l.backupPasswordCheck),
  );
  if (password == null || !context.mounted) return;
  final ok = await checkPasswordInBackground(keys, password);
  if (ok) {
    await _markChecked(ref);
    messenger.showSnackBar(SnackBar(content: Text(l.backupPasswordCorrect)));
    return;
  }
  if (!context.mounted) return;
  final change = await confirmDialog(
    context,
    title: l.backupPasswordWrong,
    message: l.backupPasswordWrongDesc,
    confirmLabel: l.backupPasswordChange,
    destructive: false,
  );
  if (change && context.mounted) {
    await _showSetup(context, ref, _SetupMode.change);
  }
}

enum _SetupMode { create, change, recoveryKey }

/// Opens the setup flow for a new password (with a new recovery key), a
/// changed password (recovery key kept) or a new recovery key.
Future<void> _showSetup(
  BuildContext context,
  WidgetRef ref,
  _SetupMode mode,
) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _SetupFlow(mode: mode),
    ),
  );
  if (saved ?? false) {
    ref.invalidate(backupKeyringProvider);
    // A paused backup can run again.
    await ref.read(settingsProvider.notifier).reset(BackupSettings.lastError);
  }
}

/// Starts the password setup from anywhere (e.g. the backup button when a
/// password is required).
Future<void> startBackupPasswordSetup(BuildContext context, WidgetRef ref) =>
    _showSetup(context, ref, _SetupMode.create);

class _SetupFlow extends ConsumerStatefulWidget {
  const _SetupFlow({required this.mode});
  final _SetupMode mode;

  @override
  ConsumerState<_SetupFlow> createState() => _SetupFlowState();
}

enum _Step { password, recoveryKey, confirm }

class _SetupFlowState extends ConsumerState<_SetupFlow> {
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  final _groupA = TextEditingController();
  final _groupB = TextEditingController();
  late _Step _step = widget.mode == _SetupMode.recoveryKey
      ? _Step.recoveryKey
      : _Step.password;
  late final Uint8List _recovery = newRecoveryKey();
  late final List<String> _groups = formatRecoveryKey(_recovery).split('-');
  late final List<int> _ask = () {
    final r = Random.secure();
    final a = r.nextInt(_groups.length);
    var b = r.nextInt(_groups.length - 1);
    if (b >= a) b++;
    return [a, b]..sort();
  }();
  bool _obscure = true;
  bool _stored = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    _groupA.dispose();
    _groupB.dispose();
    super.dispose();
  }

  bool get _passwordOk =>
      _password.text.length >= minBackupPasswordLength &&
      _password.text == _repeat.text;

  bool _matches(TextEditingController c, int group) =>
      normalizeRecoveryKey(c.text) == _groups[group];

  Future<void> _save() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(backupKeyRepositoryProvider);
      final current = (await repo.load())?.current;
      final BackupKeys keys;
      switch (widget.mode) {
        case _SetupMode.create:
          keys = await createKeysInBackground(_password.text, _recovery);
        case _SetupMode.change:
          keys = await newPasswordInBackground(current!, _password.text);
        case _SetupMode.recoveryKey:
          keys = await withNewRecoveryKey(current!, _recovery);
      }
      await repo.save(keys);
      if (widget.mode != _SetupMode.recoveryKey) await _markChecked(ref);
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      setState(() {
        _busy = false;
        _error = l.commonError('$e');
      });
    }
  }

  Future<void> _saveRecoveryFile() async {
    final l = context.l10n;
    final text = '${l.backupRecoveryFileIntro}\n\n${_groups.join('-')}\n';
    await saveOrShareBytes(
      bytes: Uint8List.fromList(utf8.encode(text)),
      fileName: 'personal-finance-recovery-key.txt',
      mimeType: 'text/plain',
      capabilities: ref.read(platformCapabilitiesProvider),
    );
  }

  Future<void> _next() async {
    switch (_step) {
      case _Step.password:
        if (widget.mode == _SetupMode.change) {
          await _save();
        } else {
          setState(() => _step = _Step.recoveryKey);
        }
      case _Step.recoveryKey:
        setState(() => _step = _Step.confirm);
      case _Step.confirm:
        await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final canNext =
        !_busy &&
        switch (_step) {
          _Step.password => _passwordOk,
          _Step.recoveryKey => _stored,
          _Step.confirm =>
            _matches(_groupA, _ask[0]) && _matches(_groupB, _ask[1]),
        };
    final last =
        _step == _Step.confirm ||
        (_step == _Step.password && widget.mode == _SetupMode.change);
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (widget.mode) {
          _SetupMode.create => l.backupPasswordSet,
          _SetupMode.change => l.backupPasswordChange,
          _SetupMode.recoveryKey => l.backupPasswordNewRecovery,
        }),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...switch (_step) {
                      _Step.password => _passwordStep(l),
                      _Step.recoveryKey => _recoveryStep(l),
                      _Step.confirm => _confirmStep(l),
                    },
                    if (_error != null) ...[
                      const SizedBox(height: Space.sm),
                      Text(
                        _error!,
                        style: TextStyle(color: context.colors.error),
                      ),
                    ],
                    const SizedBox(height: Space.lg),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton(
                        onPressed: canNext ? _next : null,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                last ? l.backupPasswordFinish : l.commonNext,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _passwordStep(AppLocalizations l) => [
    Text(l.backupPasswordStepIntro),
    const SizedBox(height: Space.md),
    TextField(
      key: const ValueKey('backup-password'),
      controller: _password,
      obscureText: _obscure,
      autofocus: true,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: l.backupPasswordField,
        helperText: l.backupPasswordMinLength(minBackupPasswordLength),
        suffixIcon: IconButton(
          tooltip: _obscure ? l.backupPasswordShow : l.backupPasswordHide,
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    ),
    const SizedBox(height: Space.sm),
    TextField(
      key: const ValueKey('backup-password-repeat'),
      controller: _repeat,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: l.backupPasswordRepeat,
        errorText: _repeat.text.isNotEmpty && _repeat.text != _password.text
            ? l.backupPasswordMismatch
            : null,
      ),
    ),
  ];

  List<Widget> _recoveryStep(AppLocalizations l) => [
    Text(l.backupRecoveryIntro),
    const SizedBox(height: Space.md),
    Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: SelectableText(
        _groups.join('  '),
        key: const ValueKey('recovery-key'),
        textAlign: TextAlign.center,
        style: context.mono.copyWith(fontSize: 18, height: 1.6),
      ),
    ),
    const SizedBox(height: Space.sm),
    Wrap(
      alignment: WrapAlignment.center,
      spacing: Space.xs,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.copy),
          label: Text(l.backupRecoveryCopy),
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: _groups.join('-'))),
        ),
        TextButton.icon(
          icon: const Icon(Icons.save_alt),
          label: Text(l.backupRecoverySave),
          onPressed: _saveRecoveryFile,
        ),
      ],
    ),
    const SizedBox(height: Space.xs),
    Text(
      l.backupRecoveryWarning,
      style: context.text.bodyMedium?.copyWith(color: context.colors.error),
    ),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _stored,
      onChanged: (v) => setState(() => _stored = v ?? false),
      title: Text(l.backupRecoveryStored),
    ),
  ];

  List<Widget> _confirmStep(AppLocalizations l) => [
    Text(l.backupRecoveryConfirmIntro),
    const SizedBox(height: Space.md),
    for (final (i, c) in [(_ask[0], _groupA), (_ask[1], _groupB)]) ...[
      TextField(
        key: ValueKey('recovery-group-$i'),
        controller: c,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.characters,
        // Spaces and dashes are not part of a group; drop them before the
        // length limit cuts the group short.
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\s\-]'))],
        maxLength: 4,
        style: context.mono,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: l.backupRecoveryGroup(i + 1)),
      ),
      const SizedBox(height: Space.xs),
    ],
    TextButton(
      onPressed: () => setState(() => _step = _Step.recoveryKey),
      child: Text(l.backupRecoveryShowAgain),
    ),
  ];
}

class _PasswordPrompt extends StatefulWidget {
  const _PasswordPrompt({required this.title});
  final String title;

  @override
  State<_PasswordPrompt> createState() => _PasswordPromptState();
}

class _PasswordPromptState extends State<_PasswordPrompt> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('backup-password-prompt'),
        controller: _c,
        obscureText: true,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(labelText: l.backupPasswordField),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _c.text),
          child: Text(l.backupPasswordCheck),
        ),
      ],
    );
  }
}

/// Asks how to open an encrypted backup that the keys on this device do not
/// open: its password or the recovery key. Null when cancelled.
Future<BackupUnlock?> askBackupUnlock(BuildContext context, {String? error}) =>
    showDialog<BackupUnlock>(
      context: context,
      builder: (_) => _UnlockDialog(error: error),
    );

class _UnlockDialog extends StatefulWidget {
  const _UnlockDialog({this.error});
  final String? error;

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> {
  final _c = TextEditingController();
  bool _recovery = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  BackupUnlock? get _value {
    if (!_recovery) {
      return _c.text.isEmpty ? null : BackupUnlock(password: _c.text);
    }
    final key = parseRecoveryKey(_c.text);
    return key == null ? null : BackupUnlock(recoveryKey: key);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final value = _value;
    return AlertDialog(
      icon: const Icon(Icons.lock_outline),
      title: Text(l.backupUnlockTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.backupUnlockDesc),
          const SizedBox(height: Space.md),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(l.backupPasswordField)),
              ButtonSegment(value: true, label: Text(l.backupRecoveryKey)),
            ],
            selected: {_recovery},
            onSelectionChanged: (v) => setState(() {
              _recovery = v.first;
              _c.clear();
            }),
          ),
          const SizedBox(height: Space.sm),
          TextField(
            key: const ValueKey('backup-unlock'),
            controller: _c,
            obscureText: !_recovery,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            style: _recovery ? context.mono : null,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _recovery
                  ? l.backupRecoveryKey
                  : l.backupPasswordField,
              hintText: _recovery ? 'ABCD-EFGH-…' : null,
              errorText: widget.error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: value == null ? null : () => Navigator.pop(context, value),
          child: Text(l.backupUnlockOpen),
        ),
      ],
    );
  }
}
