import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:personal_finance/features/security/domain/pbkdf2.dart';

/// The kind of secret that unlocks the app. Biometrics are an optional
/// convenience on top of one of these (they are the fallback).
enum SecretKind { pin, password }

/// Minimum and maximum PIN length (digits).
const minPinLength = 4;
const maxPinLength = 8;

/// Minimum password length (characters).
const minPasswordLength = 6;

/// PBKDF2 iteration counts. The web runs the derivation on the UI thread
/// with dart2js, so it uses fewer rounds.
const nativeIterations = 120000;
const webIterations = 60000;

/// Validates a new secret. Returns null when acceptable, otherwise the
/// reason.
SecretProblem? validateSecret(SecretKind kind, String secret) {
  switch (kind) {
    case SecretKind.pin:
      if (!RegExp(r'^[0-9]+$').hasMatch(secret)) return SecretProblem.digits;
      if (secret.length < minPinLength) return SecretProblem.tooShort;
      if (secret.length > maxPinLength) return SecretProblem.tooLong;
      return null;
    case SecretKind.password:
      if (secret.trim().length < minPasswordLength) {
        return SecretProblem.tooShort;
      }
      return null;
  }
}

enum SecretProblem { digits, tooShort, tooLong }

/// Parameters for one PBKDF2 run, sendable to an isolate.
@immutable
class HashRequest {
  const HashRequest(this.secret, this.salt, this.iterations);
  final String secret;
  final Uint8List salt;
  final int iterations;
}

/// Runs PBKDF2-HMAC-SHA256 for [r] (top-level so it can run in an isolate).
Uint8List hashSecret(HashRequest r) => pbkdf2HmacSha256(
  password: utf8.encode(r.secret),
  salt: r.salt,
  iterations: r.iterations,
);

/// A stored, salted hash of the user's PIN or password. Never contains the
/// secret itself.
@immutable
class LockCredential {
  const LockCredential({
    required this.kind,
    required this.salt,
    required this.hash,
    required this.iterations,
    this.biometrics = false,
    this.pinLength,
  });

  factory LockCredential.fromJson(Map<String, Object?> json) => LockCredential(
    kind: SecretKind.values.byName(json['kind']! as String),
    salt: base64Decode(json['salt']! as String),
    hash: base64Decode(json['hash']! as String),
    iterations: json['iterations']! as int,
    biometrics: json['biometrics'] as bool? ?? false,
    pinLength: json['pinLength'] as int?,
  );

  static const algorithm = 'pbkdf2-hmac-sha256';

  final SecretKind kind;
  final Uint8List salt;
  final Uint8List hash;
  final int iterations;

  /// Whether biometric unlock is enabled on top of the secret.
  final bool biometrics;

  /// Number of PIN digits, so the number pad can submit automatically.
  final int? pinLength;

  LockCredential copyWith({bool? biometrics}) => LockCredential(
    kind: kind,
    salt: salt,
    hash: hash,
    iterations: iterations,
    biometrics: biometrics ?? this.biometrics,
    pinLength: pinLength,
  );

  Map<String, Object?> toJson() => {
    'v': 1,
    'alg': algorithm,
    'kind': kind.name,
    'salt': base64Encode(salt),
    'hash': base64Encode(hash),
    'iterations': iterations,
    'biometrics': biometrics,
    if (pinLength != null) 'pinLength': pinLength,
  };

  /// Whether [derived] (PBKDF2 of the candidate with this salt) matches.
  bool matches(List<int> derived) => constantTimeEquals(derived, hash);
}

/// Random salt from a cryptographically secure source.
Uint8List newSalt([int length = 16]) {
  final rnd = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => rnd.nextInt(256)),
  );
}
