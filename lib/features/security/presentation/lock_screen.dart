import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/features/security/domain/lock_credential.dart';
import 'package:personal_finance/features/security/presentation/app_lock_controller.dart';
import 'package:personal_finance/features/security/presentation/pin_pad.dart';

/// Formats a throttle delay as m:ss.
String formatDelay(Duration d) {
  final s = d.inSeconds + (d.inMilliseconds % 1000 > 0 ? 1 : 0);
  final m = s ~/ 60;
  return '$m:${(s % 60).toString().padLeft(2, '0')}';
}

/// Full-screen lock: number pad for a PIN, a password field otherwise, and
/// a biometric button where enabled.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  final _password = TextEditingController();
  final _padFocus = FocusNode(debugLabel: 'pin-pad');
  bool _obscure = true;
  bool _busy = false;
  bool _wrong = false;
  Timer? _ticker;
  bool _promptedBiometrics = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoBiometrics());
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _password.dispose();
    _padFocus.dispose();
    super.dispose();
  }

  AppLockController get _ctrl => ref.read(appLockProvider.notifier);

  Future<void> _autoBiometrics() async {
    if (!mounted || _promptedBiometrics) return;
    await _ctrl.loaded;
    if (!mounted || !ref.read(appLockProvider).biometrics) return;
    _promptedBiometrics = true;
    await _biometrics();
  }

  Future<void> _biometrics() async {
    await _ctrl.unlockWithBiometrics(context.l10n.securityBiometricReason);
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (_ctrl.throttleRemaining > Duration.zero) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (_ctrl.throttleRemaining == Duration.zero) _ticker?.cancel();
      });
    }
  }

  Future<void> _submit(String secret) async {
    if (_busy || secret.isEmpty) return;
    setState(() => _busy = true);
    final r = await _ctrl.submit(secret);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _wrong = r != UnlockResult.success;
      _pin = '';
      if (r != UnlockResult.success) _password.clear();
    });
    _syncTicker();
  }

  void _digit(String d) {
    final st = ref.read(appLockProvider);
    if (_busy || _pin.length >= maxPinLength) return;
    setState(() {
      _pin += d;
      _wrong = false;
    });
    if (st.pinLength != null && _pin.length == st.pinLength) {
      unawaited(_submit(_pin));
    }
  }

  void _delete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final st = ref.watch(appLockProvider);
    final remaining = _ctrl.throttleRemaining;
    final throttled = remaining > Duration.zero;
    final isPin = (st.kind ?? SecretKind.pin) == SecretKind.pin;
    final policy = ref.watch(lockoutPolicyProvider);

    String? message;
    if (throttled) {
      message = l.securityTryAgainIn(formatDelay(remaining));
    } else if (_wrong) {
      final left = policy.freeAttempts - st.failures;
      final base = isPin ? l.securityWrongPin : l.securityWrongPassword;
      message = left > 0 ? '$base · ${l.securityAttemptsLeft(left)}' : base;
    }

    final bio = st.biometrics
        ? PadIconButton(
            icon: Icons.fingerprint,
            tooltip: l.securityUseBiometrics,
            onPressed: _busy ? null : _biometrics,
          )
        : null;

    if (st.ready && isPin && !_padFocus.hasFocus) {
      // The lock screen lives outside the app's navigator; claim keyboard
      // focus explicitly so digits typed on a hardware keyboard arrive.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_padFocus.hasFocus) _padFocus.requestFocus();
      });
    }

    final input = !st.ready
        ? const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator.adaptive()),
          )
        : isPin
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PinDots(count: _pin.length, length: st.pinLength, error: _wrong),
              const SizedBox(height: Space.xl),
              PinPad(
                focusNode: _padFocus,
                enabled: !_busy && !throttled,
                onDigit: _digit,
                onDelete: _delete,
                onSubmit: () => _submit(_pin),
                leading: bio,
              ),
              if (st.pinLength == null) ...[
                const SizedBox(height: Space.md),
                FilledButton(
                  onPressed: _busy || throttled || _pin.length < minPinLength
                      ? null
                      : () => _submit(_pin),
                  child: Text(l.securityUnlock),
                ),
              ],
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('lock-password'),
                controller: _password,
                autofocus: true,
                obscureText: _obscure,
                enabled: !_busy && !throttled,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
                decoration: InputDecoration(
                  labelText: l.securityPasswordLabel,
                  errorText: _wrong && !throttled ? ' ' : null,
                  errorStyle: const TextStyle(height: 0, fontSize: 0),
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
              FilledButton(
                onPressed: _busy || throttled
                    ? null
                    : () => _submit(_password.text),
                child: Text(l.securityUnlock),
              ),
              if (bio != null) ...[
                const SizedBox(height: Space.xs),
                TextButton.icon(
                  onPressed: _busy ? null : _biometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(l.securityUseBiometrics),
                ),
              ],
            ],
          );

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: context.colors.primaryContainer,
                      borderRadius: BorderRadius.circular(Radii.lg),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 32,
                      color: context.colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  Semantics(
                    header: true,
                    child: Text(
                      l.securityLockedTitle,
                      style: context.text.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: Space.xxs),
                  Text(
                    isPin ? l.securityEnterPin : l.securityEnterPassword,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  input,
                  const SizedBox(height: Space.md),
                  SizedBox(
                    height: 40,
                    child: Semantics(
                      liveRegion: true,
                      child: message == null
                          ? (_busy
                                ? Text(
                                    l.securityChecking,
                                    style: context.text.bodySmall,
                                  )
                                : const SizedBox.shrink())
                          : Text(
                              message,
                              textAlign: TextAlign.center,
                              style: context.text.bodyMedium?.copyWith(
                                color: context.colors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
