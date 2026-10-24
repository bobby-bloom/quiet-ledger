import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:personal_finance/core/platform/capabilities.dart';

/// Biometric authentication (fingerprint, Face ID, Windows Hello).
abstract interface class BiometricAuth {
  /// Whether biometrics are supported and enrolled on this device.
  Future<bool> isAvailable();

  /// Shows the system prompt. Returns true on success; false when the user
  /// cancels or the check fails.
  Future<bool> authenticate(String reason);
}

class NoBiometrics implements BiometricAuth {
  const NoBiometrics();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}

class LocalAuthBiometrics implements BiometricAuth {
  LocalAuthBiometrics([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (defaultTargetPlatform == TargetPlatform.windows) {
        // Windows Hello reports no individual biometric types.
        return await _auth.canCheckBiometrics;
      }
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on Object catch (e) {
      debugPrint('Biometrics unavailable: $e');
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Windows Hello cannot restrict to biometrics; elsewhere the app's
        // own PIN/password is the fallback, not the device passcode.
        biometricOnly: defaultTargetPlatform != TargetPlatform.windows,
        persistAcrossBackgrounding: true,
      );
    } on Object catch (e) {
      debugPrint('Biometric authentication failed: $e');
      return false;
    }
  }
}

final biometricAuthProvider = Provider<BiometricAuth>((ref) {
  final caps = ref.watch(platformCapabilitiesProvider);
  return caps.biometrics ? LocalAuthBiometrics() : const NoBiometrics();
});

/// Whether biometric unlock can be offered right now.
final biometricsAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricAuthProvider).isAvailable(),
);
