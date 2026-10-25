import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/features/security/data/biometrics.dart';
import 'package:personal_finance/features/security/domain/lock_credential.dart';
import 'package:personal_finance/features/security/presentation/app_lock_controller.dart';
import 'package:personal_finance/features/security/presentation/lock_screen.dart';
import 'package:personal_finance/features/security/presentation/pin_pad.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// Opens the set-up flow (choose PIN or password, enter, confirm). With
/// [change] the lock stays on and only the secret is replaced. Returns true
/// when a credential was stored.
Future<bool> showLockSetup(BuildContext context, {bool change = false}) async {
  final r = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LockSetupPage(change: change),
    ),
  );
  return r ?? false;
}

String? secretProblemText(
  AppLocalizations l,
  SecretKind kind,
  SecretProblem? p,
) => switch (p) {
  null => null,
  SecretProblem.digits => l.securityPinDigitsOnly,
  SecretProblem.tooShort || SecretProblem.tooLong =>
    kind == SecretKind.pin
        ? l.securityPinLength(minPinLength, maxPinLength)
        : l.securityPasswordTooShort(minPasswordLength),
};

enum _Step { choose, enter, confirm }

class LockSetupPage extends ConsumerStatefulWidget {
  const LockSetupPage({super.key, this.change = false});

  final bool change;

  @override
  ConsumerState<LockSetupPage> createState() => _LockSetupPageState();
}

class _LockSetupPageState extends ConsumerState<LockSetupPage> {
  _Step _step = _Step.choose;
  SecretKind _kind = SecretKind.pin;
  bool _biometrics = false;
  String _first = '';
  String _entry = '';
  String? _error;
  bool _saving = false;
  final _text = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final st = ref.read(appLockProvider);
    if (widget.change && st.kind != null) _kind = st.kind!;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _value => _kind == SecretKind.pin ? _entry : _text.text;

  void _resetInput() {
    _entry = '';
    _text.clear();
  }

  Future<void> _next() async {
    final l = context.l10n;
    switch (_step) {
      case _Step.choose:
        setState(() {
          _step = _Step.enter;
          _error = null;
          _resetInput();
        });
      case _Step.enter:
        final problem = validateSecret(_kind, _value);
        if (problem != null) {
          setState(() => _error = secretProblemText(l, _kind, problem));
          return;
        }
        setState(() {
          _first = _value;
          _step = _Step.confirm;
          _error = null;
          _resetInput();
        });
      case _Step.confirm:
        if (_value != _first) {
          setState(() {
            _error = l.securityMismatch;
            _step = _Step.enter;
            _first = '';
            _resetInput();
          });
          return;
        }
        setState(() => _saving = true);
        final ctrl = ref.read(appLockProvider.notifier);
        try {
          if (widget.change) {
            await ctrl.changeSecret(kind: _kind, secret: _first);
          } else {
            await ctrl.enable(
              kind: _kind,
              secret: _first,
              biometrics: _biometrics,
            );
          }
        } on Object catch (e) {
          if (!mounted) return;
          setState(() {
            _saving = false;
            _error = l.commonError(e.toString());
          });
          return;
        }
        if (mounted) Navigator.of(context).pop(true);
    }
  }

  void _back() {
    if (_step == _Step.choose) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _step = _step == _Step.confirm ? _Step.enter : _Step.choose;
      _error = null;
      _resetInput();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = widget.change
        ? (_kind == SecretKind.pin
              ? l.securityChangePin
              : l.securityChangePassword)
        : l.securitySetupTitle;
    final body = switch (_step) {
      _Step.choose => _choose(l),
      _Step.enter || _Step.confirm => _input(l),
    };
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.commonBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: _saving ? null : _back,
        ),
        title: Text(title),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: WindowSize.of(context).isCompact
                  ? Space.phoneGutter
                  : Space.desktopGutter,
              vertical: Space.lg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  Widget _choose(AppLocalizations l) {
    final bioAvailable = ref.watch(biometricsAvailableProvider).value ?? false;
    Widget option(SecretKind k, IconData icon, String title, String desc) {
      final sel = _kind == k;
      return Card(
        color: sel ? context.colors.secondaryContainer : null,
        child: RadioListTile<SecretKind>(
          value: k,
          title: Text(title),
          subtitle: Text(desc),
          secondary: Icon(icon),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.securityChooseMethod, style: context.text.titleMedium),
        const SizedBox(height: Space.md),
        RadioGroup<SecretKind>(
          groupValue: _kind,
          onChanged: (v) => setState(() => _kind = v ?? _kind),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              option(
                SecretKind.pin,
                Icons.dialpad,
                l.securityMethodPin,
                l.securityPinLength(minPinLength, maxPinLength),
              ),
              const SizedBox(height: Space.cardGap),
              option(
                SecretKind.password,
                Icons.password,
                l.securityMethodPassword,
                l.securityPasswordTooShort(minPasswordLength),
              ),
            ],
          ),
        ),
        if (bioAvailable && !widget.change) ...[
          const SizedBox(height: Space.cardGap),
          Card(
            child: SwitchListTile(
              value: _biometrics,
              onChanged: (v) => setState(() => _biometrics = v),
              secondary: const Icon(Icons.fingerprint),
              title: Text(l.securityAlsoBiometrics),
              subtitle: Text(l.securityAlsoBiometricsDesc),
            ),
          ),
        ],
        const SizedBox(height: Space.xl),
        FilledButton(onPressed: _next, child: Text(l.commonNext)),
      ],
    );
  }

  Widget _input(AppLocalizations l) {
    final confirm = _step == _Step.confirm;
    final isPin = _kind == SecretKind.pin;
    final heading = isPin
        ? (confirm ? l.securityConfirmPin : l.securityNewPin)
        : (confirm ? l.securityConfirmPassword : l.securityNewPassword);
    final canContinue = isPin
        ? _entry.length >= minPinLength
        : _text.text.isNotEmpty;
    return Column(
      key: ValueKey(_step),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            heading,
            style: context.text.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: Space.lg),
        if (isPin) ...[
          Center(
            child: PinDots(count: _entry.length, error: _error != null),
          ),
          const SizedBox(height: Space.xl),
          Center(
            child: PinPad(
              enabled: !_saving,
              onDigit: (d) {
                if (_entry.length >= maxPinLength) return;
                setState(() {
                  _entry += d;
                  _error = null;
                });
              },
              onDelete: () {
                if (_entry.isEmpty) return;
                setState(() => _entry = _entry.substring(0, _entry.length - 1));
              },
              onSubmit: canContinue ? _next : null,
            ),
          ),
        ] else
          TextField(
            key: const ValueKey('setup-password'),
            controller: _text,
            autofocus: true,
            obscureText: _obscure,
            enabled: !_saving,
            autofillHints: const [AutofillHints.newPassword],
            inputFormatters: [LengthLimitingTextInputFormatter(128)],
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _next(),
            decoration: InputDecoration(
              labelText: l.securityPasswordLabel,
              helperText: l.securityPasswordTooShort(minPasswordLength),
              suffixIcon: IconButton(
                tooltip: _obscure
                    ? l.securityShowPassword
                    : l.securityHidePassword,
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        const SizedBox(height: Space.md),
        SizedBox(
          height: 44,
          child: Semantics(
            liveRegion: true,
            child: Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.error,
              ),
            ),
          ),
        ),
        FilledButton(
          onPressed: _saving || !canContinue ? null : _next,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(confirm ? l.commonSave : l.commonNext),
        ),
      ],
    );
  }
}

/// Asks for biometrics (when enabled) or the current PIN/password before a
/// sensitive change. Returns true when the user proved their identity.
Future<bool> confirmIdentity(BuildContext context, WidgetRef ref) async {
  final st = ref.read(appLockProvider);
  if (!st.enabled) return true;
  final l = context.l10n;
  if (st.biometrics) {
    final ok = await ref
        .read(appLockProvider.notifier)
        .authenticateBiometric(l.securityConfirmIdentity);
    if (ok) return true;
  }
  if (!context.mounted) return false;
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => const _VerifyDialog(),
  );
  return r ?? false;
}

class _VerifyDialog extends ConsumerStatefulWidget {
  const _VerifyDialog();

  @override
  ConsumerState<_VerifyDialog> createState() => _VerifyDialogState();
}

class _VerifyDialogState extends ConsumerState<_VerifyDialog> {
  final _c = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_busy || _c.text.isEmpty) return;
    final l = context.l10n;
    final ctrl = ref.read(appLockProvider.notifier);
    setState(() => _busy = true);
    final r = await ctrl.submit(_c.text, unlock: false);
    if (!mounted) return;
    if (r == UnlockResult.success) {
      Navigator.of(context).pop(true);
      return;
    }
    final isPin = ref.read(appLockProvider).kind == SecretKind.pin;
    setState(() {
      _busy = false;
      _c.clear();
      _error =
          r == UnlockResult.throttled || ctrl.throttleRemaining > Duration.zero
          ? l.securityTryAgainIn(formatDelay(ctrl.throttleRemaining))
          : (isPin ? l.securityWrongPin : l.securityWrongPassword);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isPin = ref.watch(appLockProvider).kind == SecretKind.pin;
    return AlertDialog(
      title: Text(l.securityConfirmIdentity),
      content: TextField(
        key: const ValueKey('verify-secret'),
        controller: _c,
        autofocus: true,
        obscureText: true,
        enabled: !_busy,
        keyboardType: isPin ? TextInputType.number : TextInputType.text,
        inputFormatters: isPin
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(maxPinLength),
              ]
            : null,
        onSubmitted: (_) => _check(),
        decoration: InputDecoration(
          labelText: isPin ? l.securityCurrentPin : l.securityCurrentPassword,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _check,
          child: Text(l.commonConfirm),
        ),
      ],
    );
  }
}

/// Small helper for the security settings: lock immediately.
void lockNow(WidgetRef ref) => ref.read(appLockProvider.notifier).lock();
