import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal_finance/features/security/domain/lock_credential.dart';
import 'package:personal_finance/features/security/domain/lockout.dart';

/// Minimal key/value interface over the platform keystore, so tests can use
/// [MemorySecretStore].
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Keychain (Apple), EncryptedSharedPreferences/Keystore (Android),
/// Credential Locker (Windows), libsecret (Linux), WebCrypto (web).
class SecureSecretStore implements SecretStore {
  const SecureSecretStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemorySecretStore implements SecretStore {
  MemorySecretStore([Map<String, String>? values]) : values = values ?? {};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

final secretStoreProvider = Provider<SecretStore>(
  (ref) => const SecureSecretStore(),
);

/// Stores the lock credential and the failure counter in secure storage.
/// Neither ever lands in the database or shared preferences.
class CredentialRepository {
  CredentialRepository(this._store);

  final SecretStore _store;

  static const credentialKey = 'security.credential';
  static const attemptsKey = 'security.attempts';

  Future<LockCredential?> load() async {
    try {
      final raw = await _store.read(credentialKey);
      if (raw == null) return null;
      return LockCredential.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on Object catch (e) {
      debugPrint('Could not read lock credential: $e');
      return null;
    }
  }

  Future<void> save(LockCredential c) =>
      _store.write(credentialKey, jsonEncode(c.toJson()));

  Future<AttemptState> loadAttempts() async {
    try {
      final raw = await _store.read(attemptsKey);
      if (raw == null) return AttemptState.initial;
      return AttemptState.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on Object {
      return AttemptState.initial;
    }
  }

  Future<void> saveAttempts(AttemptState s) async {
    try {
      if (s == AttemptState.initial) {
        await _store.delete(attemptsKey);
      } else {
        await _store.write(attemptsKey, jsonEncode(s.toJson()));
      }
    } on Object catch (e) {
      debugPrint('Could not store attempt counter: $e');
    }
  }

  Future<void> clear() async {
    await _store.delete(credentialKey);
    await _store.delete(attemptsKey);
  }
}

final credentialRepositoryProvider = Provider<CredentialRepository>(
  (ref) => CredentialRepository(ref.watch(secretStoreProvider)),
);

/// Runs the PBKDF2 derivation. Native platforms use a background isolate;
/// the web runs it inline (no isolates). Overridden in tests.
typedef SecretHasher = Future<Uint8List> Function(HashRequest request);

final secretHasherProvider = Provider<SecretHasher>(
  (ref) => kIsWeb
      ? (r) async => hashSecret(r)
      : (r) => compute(hashSecret, r, debugLabel: 'pbkdf2'),
);

/// Iterations used for new credentials on this platform.
final hashIterationsProvider = Provider<int>(
  (ref) => kIsWeb ? webIterations : nativeIterations,
);
