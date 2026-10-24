import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2 (RFC 8018) with HMAC-SHA256 as the pseudo-random function.
///
/// Returns [keyLength] bytes derived from [password] and [salt] using
/// [iterations] rounds.
Uint8List pbkdf2HmacSha256({
  required List<int> password,
  required List<int> salt,
  required int iterations,
  int keyLength = 32,
}) {
  if (iterations < 1) {
    throw ArgumentError.value(iterations, 'iterations', 'must be ≥ 1');
  }
  if (keyLength < 1) {
    throw ArgumentError.value(keyLength, 'keyLength', 'must be ≥ 1');
  }
  const hLen = 32;
  final hmac = Hmac(sha256, password);
  final blocks = (keyLength + hLen - 1) ~/ hLen;
  final out = Uint8List(blocks * hLen);
  final first = Uint8List(salt.length + 4)..setAll(0, salt);
  for (var i = 1; i <= blocks; i++) {
    first
      ..[salt.length] = (i >> 24) & 0xff
      ..[salt.length + 1] = (i >> 16) & 0xff
      ..[salt.length + 2] = (i >> 8) & 0xff
      ..[salt.length + 3] = i & 0xff;
    var u = hmac.convert(first).bytes;
    final t = Uint8List.fromList(u);
    for (var j = 1; j < iterations; j++) {
      u = hmac.convert(u).bytes;
      for (var k = 0; k < hLen; k++) {
        t[k] ^= u[k];
      }
    }
    out.setAll((i - 1) * hLen, t);
  }
  return keyLength == out.length
      ? out
      : Uint8List.sublistView(out, 0, keyLength);
}

/// Compares two byte lists in time independent of where they differ.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
