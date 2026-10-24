import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/security/data/biometrics.dart';
import 'package:personal_finance/features/security/data/secret_store.dart';
import 'package:personal_finance/features/security/domain/lock_credential.dart';
import 'package:personal_finance/features/security/domain/lockout.dart';

/// Clock used for lock timeouts and the failed-attempt delay. Overridden in
/// tests.
final lockClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Escalation policy for wrong entries.
final lockoutPolicyProvider = Provider<LockoutPolicy>(
  (ref) => const LockoutPolicy(),
);

@immutable
class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.locked,
    required this.ready,
    this.kind,
    this.pinLength,
    this.biometrics = false,
    this.failures = 0,
    this.lockedUntil,
  });

  /// App lock is switched on and a credential exists.
  final bool enabled;

  /// The lock screen is showing.
  final bool locked;

  /// The stored credential has been loaded.
  final bool ready;

  /// PIN or password, null when no credential is stored.
  final SecretKind? kind;
  final int? pinLength;

  /// Biometric unlock is enabled (Settings › Security › Method).
  final bool biometrics;
  final int failures;

  /// Next attempt allowed after this instant (UTC), if throttled.
  final DateTime? lockedUntil;

  AppLockState copyWith({
    bool? enabled,
    bool? locked,
    bool? ready,
    SecretKind? kind,
    int? pinLength,
    bool? biometrics,
    int? failures,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
    bool clearKind = false,
  }) => AppLockState(
    enabled: enabled ?? this.enabled,
    locked: locked ?? this.locked,
    ready: ready ?? this.ready,
    kind: clearKind ? null : (kind ?? this.kind),
    pinLength: clearKind ? null : (pinLength ?? this.pinLength),
    biometrics: biometrics ?? this.biometrics,
    failures: failures ?? this.failures,
    lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
  );
}

enum UnlockResult { success, wrong, throttled }

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);

/// Owns the lock state: lock on start, lock after the background timeout,
/// manual lock, PIN/password/biometric unlock with escalating delays, and
/// setting up, changing or removing the credential.
class AppLockController extends Notifier<AppLockState> {
  LockCredential? _credential;
  late AttemptTracker _tracker;
  DateTime? _hiddenSince;
  bool _biometricPromptActive = false;
  Completer<void>? _loaded;

  CredentialRepository get _repo => ref.read(credentialRepositoryProvider);
  DateTime _now() => ref.read(lockClockProvider)();

  @override
  AppLockState build() {
    final s = ref.read(settingsProvider);
    final enabled = s.get(SecuritySettings.appLock);
    _tracker = AttemptTracker(
      now: ref.read(lockClockProvider),
      policy: ref.read(lockoutPolicyProvider),
    );
    ref.listen(
      settingsProvider.select(
        (s) => (
          s.get(SecuritySettings.appLock),
          s.get(SecuritySettings.lockMethod),
        ),
      ),
      (prev, next) {
        final (on, method) = next;
        if (!on) {
          state = state.copyWith(enabled: false, locked: false);
        } else {
          state = state.copyWith(
            enabled: _credential != null,
            biometrics: method == LockMethod.biometric,
          );
        }
      },
    );
    _loaded = Completer<void>();
    unawaited(_load(lockNow: enabled && s.get(SecuritySettings.lockOnStart)));
    // Secure default: when the lock is on, start locked until the
    // credential has been checked.
    return AppLockState(
      enabled: enabled,
      locked: enabled && s.get(SecuritySettings.lockOnStart),
      ready: false,
      biometrics: s.get(SecuritySettings.lockMethod) == LockMethod.biometric,
    );
  }

  /// Completes once the stored credential has been read.
  Future<void> get loaded => _loaded?.future ?? Future.value();

  Future<void> _load({required bool lockNow}) async {
    // Runs from build(): yield first so `state` is initialised.
    await Future<void>.value();
    if (!ref.read(settingsProvider).get(SecuritySettings.appLock)) {
      // Lock off: don't touch the keystore (on Linux reading it may prompt
      // to unlock the keyring). enable() provides the credential later.
      state = state.copyWith(enabled: false, locked: false, ready: true);
      if (!(_loaded?.isCompleted ?? true)) _loaded!.complete();
      return;
    }
    final cred = await _repo.load();
    final attempts = await _repo.loadAttempts();
    _credential = cred;
    _tracker = AttemptTracker(
      now: ref.read(lockClockProvider),
      policy: ref.read(lockoutPolicyProvider),
      initial: attempts,
    );
    final s = ref.read(settingsProvider);
    final on = s.get(SecuritySettings.appLock);
    if (on && cred == null) {
      // The setting survived but the credential did not (e.g. the keystore
      // was cleared). Nothing could unlock the app, so turn the lock off.
      debugPrint('App lock enabled without a stored credential; disabling.');
      await ref
          .read(settingsProvider.notifier)
          .set(SecuritySettings.appLock, false);
    }
    state = AppLockState(
      enabled: on && cred != null,
      locked: on && cred != null && (state.locked || lockNow),
      ready: true,
      kind: cred?.kind,
      pinLength: cred?.pinLength,
      biometrics: s.get(SecuritySettings.lockMethod) == LockMethod.biometric,
      failures: attempts.failures,
      lockedUntil: attempts.lockedUntil,
    );
    if (!(_loaded?.isCompleted ?? true)) _loaded!.complete();
  }

  /// Time until the next PIN/password attempt is allowed.
  Duration get throttleRemaining => _tracker.remaining;

  /// Shows the lock screen (no-op when the lock is off).
  void lock() {
    if (state.enabled) state = state.copyWith(locked: true);
  }

  /// Checks [secret] against the stored credential, counting failures.
  /// Unlocks on success when [unlock] is set.
  Future<UnlockResult> submit(String secret, {bool unlock = true}) async {
    await loaded;
    final cred = _credential;
    if (cred == null) return UnlockResult.wrong;
    if (!_tracker.canAttempt) return UnlockResult.throttled;
    final derived = await ref.read(secretHasherProvider)(
      HashRequest(secret, cred.salt, cred.iterations),
    );
    if (cred.matches(derived)) {
      final s = _tracker.recordSuccess();
      unawaited(_repo.saveAttempts(s));
      state = state.copyWith(
        locked: !unlock && state.locked,
        failures: 0,
        clearLockedUntil: true,
      );
      return UnlockResult.success;
    }
    final s = _tracker.recordFailure();
    await _repo.saveAttempts(s);
    state = state.copyWith(
      failures: s.failures,
      lockedUntil: s.lockedUntil,
      clearLockedUntil: s.lockedUntil == null,
    );
    return UnlockResult.wrong;
  }

  /// Asks for biometrics and unlocks on success.
  Future<bool> unlockWithBiometrics(String reason) async {
    if (!state.biometrics || _biometricPromptActive) return false;
    final ok = await authenticateBiometric(reason);
    if (ok) {
      final s = _tracker.recordSuccess();
      unawaited(_repo.saveAttempts(s));
      state = state.copyWith(
        locked: false,
        failures: 0,
        clearLockedUntil: true,
      );
    }
    return ok;
  }

  /// Runs the system biometric prompt without changing the lock state.
  Future<bool> authenticateBiometric(String reason) async {
    if (_biometricPromptActive) return false;
    _biometricPromptActive = true;
    try {
      return await ref.read(biometricAuthProvider).authenticate(reason);
    } finally {
      _biometricPromptActive = false;
      // The system prompt may have sent the app to the background briefly.
      _hiddenSince = null;
    }
  }

  // ------------------------------------------------------------ lifecycle

  /// The app went to the background (hidden/paused).
  void onHidden() {
    if (_biometricPromptActive || !state.enabled) return;
    _hiddenSince ??= _now();
    if (ref.read(settingsProvider).get(SecuritySettings.lockTimeout) == 0) {
      lock();
    }
  }

  /// The app came back to the foreground.
  void onShown() {
    final since = _hiddenSince;
    _hiddenSince = null;
    if (since == null || !state.enabled || _biometricPromptActive) return;
    final timeout = ref
        .read(settingsProvider)
        .get(SecuritySettings.lockTimeout);
    if (_now().difference(since) >= Duration(seconds: timeout)) lock();
  }

  // --------------------------------------------------------------- setup

  Future<LockCredential> _create(SecretKind kind, String secret) async {
    final problem = validateSecret(kind, secret);
    if (problem != null) throw ArgumentError.value(problem, 'secret');
    final salt = newSalt();
    final iterations = ref.read(hashIterationsProvider);
    final hash = await ref.read(secretHasherProvider)(
      HashRequest(secret, salt, iterations),
    );
    return LockCredential(
      kind: kind,
      salt: salt,
      hash: hash,
      iterations: iterations,
      pinLength: kind == SecretKind.pin ? secret.length : null,
    );
  }

  /// Stores a new credential and switches the lock on.
  Future<void> enable({
    required SecretKind kind,
    required String secret,
    bool biometrics = false,
  }) async {
    final cred = await _create(kind, secret);
    await _repo.save(cred);
    await _repo.saveAttempts(AttemptState.initial);
    _credential = cred;
    _tracker.recordSuccess();
    final n = ref.read(settingsProvider.notifier);
    await n.set(SecuritySettings.lockMethod, _method(kind, biometrics));
    await n.set(SecuritySettings.appLock, true);
    state = AppLockState(
      enabled: true,
      locked: false,
      ready: true,
      kind: kind,
      pinLength: cred.pinLength,
      biometrics: biometrics,
    );
  }

  /// Replaces the PIN/password (the caller has verified the old one).
  Future<void> changeSecret({
    required SecretKind kind,
    required String secret,
  }) async {
    final cred = await _create(kind, secret);
    await _repo.save(cred);
    _credential = cred;
    await ref
        .read(settingsProvider.notifier)
        .set(SecuritySettings.lockMethod, _method(kind, state.biometrics));
    state = AppLockState(
      enabled: state.enabled,
      locked: state.locked,
      ready: true,
      kind: kind,
      pinLength: cred.pinLength,
      biometrics: state.biometrics,
      failures: state.failures,
      lockedUntil: state.lockedUntil,
    );
  }

  /// Turns biometric unlock on or off (the PIN/password stays the fallback).
  Future<void> setBiometrics({required bool enabled}) async {
    final kind = _credential?.kind ?? SecretKind.pin;
    await ref
        .read(settingsProvider.notifier)
        .set(SecuritySettings.lockMethod, _method(kind, enabled));
    state = state.copyWith(biometrics: enabled);
  }

  /// Removes the credential and switches the lock off (the caller has
  /// verified the user).
  Future<void> disable() async {
    await _repo.clear();
    _credential = null;
    _tracker.recordSuccess();
    await ref
        .read(settingsProvider.notifier)
        .set(SecuritySettings.appLock, false);
    state = const AppLockState(enabled: false, locked: false, ready: true);
  }

  static LockMethod _method(SecretKind kind, bool biometrics) => biometrics
      ? LockMethod.biometric
      : (kind == SecretKind.pin ? LockMethod.pin : LockMethod.password);
}
