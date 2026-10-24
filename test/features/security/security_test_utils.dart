import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart';
import 'package:personal_finance/features/security/data/biometrics.dart';
import 'package:personal_finance/features/security/data/secret_store.dart';
import 'package:personal_finance/features/security/domain/lock_credential.dart';
import 'package:personal_finance/features/security/presentation/app_lock_controller.dart';

/// Fast, deterministic security wiring for tests: in-memory keystore,
/// inline hashing with few iterations, no biometrics, optional clock.
List<Override> securityOverrides({
  MemorySecretStore? store,
  DateTime Function()? clock,
  BiometricAuth biometrics = const NoBiometrics(),
}) => [
  secretStoreProvider.overrideWithValue(store ?? MemorySecretStore()),
  secretHasherProvider.overrideWithValue((r) async => hashSecret(r)),
  hashIterationsProvider.overrideWithValue(1000),
  biometricAuthProvider.overrideWithValue(biometrics),
  biometricsAvailableProvider.overrideWith((ref) => biometrics.isAvailable()),
  if (clock != null) lockClockProvider.overrideWithValue(clock),
];

/// Stores a PIN credential in [store] as the setup flow would.
void storePin(MemorySecretStore store, String pin) {
  final salt = Uint8List.fromList(List.generate(16, (i) => i * 7));
  final cred = LockCredential(
    kind: SecretKind.pin,
    salt: salt,
    hash: hashSecret(HashRequest(pin, salt, 1000)),
    iterations: 1000,
    pinLength: pin.length,
  );
  store.values[CredentialRepository.credentialKey] = jsonEncode(cred.toJson());
}

class FakeBiometrics implements BiometricAuth {
  FakeBiometrics({this.result = true});

  bool result;
  int calls = 0;

  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return result;
  }

  @override
  Future<bool> isAvailable() async => true;
}
