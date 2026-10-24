import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart';

// Encrypted backup container `.pfbackup` (docs/BACKUP.md):
//
//   "PFBK" | version u8 | header length u32 (big endian) | header JSON |
//   AES-256-GCM(data key, nonce, bundle zip, aad = everything before) | tag
//
// A random 256-bit data key per file encrypts the unchanged bundle zip. The
// data key is wrapped twice with AES-256-GCM: under a key derived from the
// backup password (PBKDF2-HMAC-SHA256, parameters in the header) and under
// a key derived from the recovery key (HKDF-SHA256 with its own salt), so
// either one opens the file. Changing the password keeps the recovery key;
// older files stay readable with their password or the recovery key.

const _magic = [0x50, 0x46, 0x42, 0x4b]; // PFBK

/// Container version; readers reject higher versions.
const encryptedFormatVersion = 1;

const encryptedBackupExtension = '.pfbackup';

/// PBKDF2 iterations for new passwords (OWASP 2023 for HMAC-SHA256).
const defaultPbkdf2Iterations = 600000;

/// Shortest backup password accepted.
const minBackupPasswordLength = 8;

const _recoveryInfo = 'personal-finance backup recovery v1';
final _aes = AesGcm.with256bits();

/// Whether [bytes] is an encrypted backup (by its magic number).
bool isEncryptedBackup(List<int> bytes) =>
    bytes.length > 9 &&
    bytes[0] == _magic[0] &&
    bytes[1] == _magic[1] &&
    bytes[2] == _magic[2] &&
    bytes[3] == _magic[3];

enum BackupCryptoError {
  /// Not a `.pfbackup`, or its header is damaged.
  notEncrypted,

  /// Written by a newer app.
  newerVersion,

  /// Neither the given password/recovery key nor any key on this device
  /// opens the file.
  wrongKey,

  /// The key is right but the content was changed or truncated.
  damaged,
}

class BackupCryptoException implements Exception {
  const BackupCryptoException(this.error);
  final BackupCryptoError error;

  @override
  String toString() => 'BackupCryptoException(${error.name})';
}

Uint8List _random(int n, [Random? rnd]) {
  final r = rnd ?? Random.secure();
  return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
}

String _b64(List<int> b) => base64Encode(b);
Uint8List _unb64(Object? s) => base64Decode(s! as String);

/// The device-side secret of a backup password: KDF parameters and the
/// derived wrapping keys (never the password or recovery key themselves).
/// Kept in secure storage so scheduled backups run unattended.
@immutable
class BackupKeys {
  const BackupKeys({
    required this.keyId,
    required this.salt,
    required this.iterations,
    required this.passwordKek,
    required this.recoveryId,
    required this.recoverySalt,
    required this.recoveryKek,
    required this.createdAt,
  });

  factory BackupKeys.fromJson(Map<String, Object?> j) => BackupKeys(
    keyId: j['keyId']! as String,
    salt: _unb64(j['salt']),
    iterations: (j['iterations']! as num).toInt(),
    passwordKek: _unb64(j['passwordKek']),
    recoveryId: j['recoveryId']! as String,
    recoverySalt: _unb64(j['recoverySalt']),
    recoveryKek: _unb64(j['recoveryKek']),
    createdAt: DateTime.parse(j['createdAt']! as String),
  );

  /// Identifies this password (changes with the password).
  final String keyId;
  final Uint8List salt;
  final int iterations;
  final Uint8List passwordKek;

  /// Identifies the recovery key (changes only when a new one is made).
  final String recoveryId;
  final Uint8List recoverySalt;
  final Uint8List recoveryKek;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'keyId': keyId,
    'salt': _b64(salt),
    'iterations': iterations,
    'passwordKek': _b64(passwordKek),
    'recoveryId': recoveryId,
    'recoverySalt': _b64(recoverySalt),
    'recoveryKek': _b64(recoveryKek),
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

/// A new recovery key: 20 random bytes (160 bits), shown as
/// [formatRecoveryKey].
Uint8List newRecoveryKey([Random? rnd]) => _random(20, rnd);

const _base32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/// `ABCD-EFGH-…` (8 groups of 4, RFC 4648 base32).
String formatRecoveryKey(Uint8List key) {
  final out = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final b in key) {
    buffer = (buffer << 8) | b;
    bits += 8;
    while (bits >= 5) {
      out.write(_base32[(buffer >> (bits - 5)) & 31]);
      bits -= 5;
    }
  }
  if (bits > 0) out.write(_base32[(buffer << (5 - bits)) & 31]);
  final s = out.toString();
  return [
    for (var i = 0; i < s.length; i += 4) s.substring(i, min(i + 4, s.length)),
  ].join('-');
}

/// Parses a typed recovery key; tolerant of case, spaces, dashes and the
/// look-alikes 0/O, 1/I, 8/B. Null when it is not 20 bytes.
Uint8List? parseRecoveryKey(String input) {
  final s = input
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\-]'), '')
      .replaceAll('0', 'O')
      .replaceAll('1', 'I')
      .replaceAll('8', 'B');
  if (s.length != 32) return null;
  final out = <int>[];
  var buffer = 0;
  var bits = 0;
  for (final c in s.split('')) {
    final v = _base32.indexOf(c);
    if (v < 0) return null;
    buffer = ((buffer << 5) | v) & 0xffff;
    bits += 5;
    if (bits >= 8) {
      out.add((buffer >> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return out.length == 20 ? Uint8List.fromList(out) : null;
}

Future<Uint8List> derivePasswordKek(
  String password,
  Uint8List salt,
  int iterations,
) async {
  final kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  final key = await kdf.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt,
  );
  return Uint8List.fromList(await key.extractBytes());
}

Future<Uint8List> deriveRecoveryKek(
  Uint8List recoveryKey,
  Uint8List salt,
) async {
  final kdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final key = await kdf.deriveKey(
    secretKey: SecretKey(recoveryKey),
    nonce: salt,
    info: utf8.encode(_recoveryInfo),
  );
  return Uint8List.fromList(await key.extractBytes());
}

String _newId([Random? rnd]) =>
    _random(8, rnd).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Keys for a new password and recovery key.
Future<BackupKeys> createBackupKeys(
  String password,
  Uint8List recoveryKey, {
  int iterations = defaultPbkdf2Iterations,
  DateTime? now,
  Random? random,
}) async {
  final salt = _random(16, random);
  final recoverySalt = _random(16, random);
  return BackupKeys(
    keyId: _newId(random),
    salt: salt,
    iterations: iterations,
    passwordKek: await derivePasswordKek(password, salt, iterations),
    recoveryId: _newId(random),
    recoverySalt: recoverySalt,
    recoveryKek: await deriveRecoveryKek(recoveryKey, recoverySalt),
    createdAt: (now ?? DateTime.now()).toUtc(),
  );
}

/// [keys] with a new password; the recovery key stays.
Future<BackupKeys> withNewPassword(
  BackupKeys keys,
  String password, {
  int iterations = defaultPbkdf2Iterations,
  DateTime? now,
  Random? random,
}) async {
  final salt = _random(16, random);
  return BackupKeys(
    keyId: _newId(random),
    salt: salt,
    iterations: iterations,
    passwordKek: await derivePasswordKek(password, salt, iterations),
    recoveryId: keys.recoveryId,
    recoverySalt: keys.recoverySalt,
    recoveryKek: keys.recoveryKek,
    createdAt: (now ?? DateTime.now()).toUtc(),
  );
}

/// [keys] with a new recovery key; the password stays.
Future<BackupKeys> withNewRecoveryKey(
  BackupKeys keys,
  Uint8List recoveryKey, {
  Random? random,
}) async {
  final recoverySalt = _random(16, random);
  return BackupKeys(
    keyId: keys.keyId,
    salt: keys.salt,
    iterations: keys.iterations,
    passwordKek: keys.passwordKek,
    recoveryId: _newId(random),
    recoverySalt: recoverySalt,
    recoveryKek: await deriveRecoveryKek(recoveryKey, recoverySalt),
    createdAt: keys.createdAt,
  );
}

/// Constant-time comparison of two keys.
bool sameKey(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    d |= a[i] ^ b[i];
  }
  return d == 0;
}

/// Parsed header of a `.pfbackup`.
@immutable
class EncryptedBackupHeader {
  const EncryptedBackupHeader({
    required this.keyId,
    required this.recoveryId,
    required this.salt,
    required this.iterations,
    required this.recoverySalt,
    required this.createdAt,
    required this.appVersion,
    required this.json,
    required this.payloadOffset,
  });

  final String keyId;
  final String recoveryId;
  final Uint8List salt;
  final int iterations;
  final Uint8List recoverySalt;
  final DateTime createdAt;
  final String appVersion;
  final Map<String, Object?> json;

  /// Start of the ciphertext; the bytes before it are the AAD.
  final int payloadOffset;
}

EncryptedBackupHeader readEncryptedHeader(Uint8List bytes) {
  if (!isEncryptedBackup(bytes)) {
    throw const BackupCryptoException(BackupCryptoError.notEncrypted);
  }
  if (bytes[4] > encryptedFormatVersion) {
    throw const BackupCryptoException(BackupCryptoError.newerVersion);
  }
  try {
    final len = ByteData.sublistView(bytes, 5, 9).getUint32(0);
    final end = 9 + len;
    final json = (jsonDecode(utf8.decode(bytes.sublist(9, end))) as Map)
        .cast<String, Object?>();
    final kdf = (json['kdf']! as Map).cast<String, Object?>();
    if (kdf['alg'] != 'pbkdf2-hmac-sha256' || json['cipher'] != 'aes-256-gcm') {
      throw const BackupCryptoException(BackupCryptoError.newerVersion);
    }
    final recovery = (json['recovery']! as Map).cast<String, Object?>();
    return EncryptedBackupHeader(
      keyId: json['keyId']! as String,
      recoveryId: recovery['id']! as String,
      salt: _unb64(kdf['salt']),
      iterations: (kdf['iterations']! as num).toInt(),
      recoverySalt: _unb64(recovery['salt']),
      createdAt: DateTime.parse(json['createdAt']! as String),
      appVersion: json['appVersion'] as String? ?? '',
      json: json,
      payloadOffset: end,
    );
  } on BackupCryptoException {
    rethrow;
  } on Object {
    throw const BackupCryptoException(BackupCryptoError.notEncrypted);
  }
}

Future<Uint8List> _wrap(Uint8List kek, Uint8List dataKey, String kind) async {
  final box = await _aes.encrypt(
    dataKey,
    secretKey: SecretKey(kek),
    nonce: _aes.newNonce(),
    aad: utf8.encode('PFBK slot $kind'),
  );
  return Uint8List.fromList(box.concatenation());
}

Future<Uint8List?> _unwrap(
  Uint8List kek,
  Uint8List wrapped,
  String kind,
) async {
  try {
    final box = SecretBox.fromConcatenation(
      wrapped,
      nonceLength: _aes.nonceLength,
      macLength: _aes.macAlgorithm.macLength,
    );
    final key = await _aes.decrypt(
      box,
      secretKey: SecretKey(kek),
      aad: utf8.encode('PFBK slot $kind'),
    );
    return Uint8List.fromList(key);
  } on SecretBoxAuthenticationError {
    return null;
  }
}

/// Encrypts the bundle [zip] with [keys].
Future<Uint8List> encryptBackup(
  Uint8List zip,
  BackupKeys keys, {
  required String appVersion,
  DateTime? now,
}) async {
  final dataKey = _random(32);
  final nonce = _aes.newNonce();
  final header = utf8.encode(
    jsonEncode({
      'cipher': 'aes-256-gcm',
      'keyId': keys.keyId,
      'kdf': {
        'alg': 'pbkdf2-hmac-sha256',
        'iterations': keys.iterations,
        'salt': _b64(keys.salt),
      },
      'recovery': {
        'id': keys.recoveryId,
        'kdf': 'hkdf-sha256',
        'salt': _b64(keys.recoverySalt),
      },
      'slots': {
        'password': _b64(await _wrap(keys.passwordKek, dataKey, 'password')),
        'recovery': _b64(await _wrap(keys.recoveryKek, dataKey, 'recovery')),
      },
      'nonce': _b64(nonce),
      'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'appVersion': appVersion,
    }),
  );
  final prefix = BytesBuilder(copy: false)
    ..add(_magic)
    ..addByte(encryptedFormatVersion)
    ..add((ByteData(4)..setUint32(0, header.length)).buffer.asUint8List())
    ..add(header);
  final aad = prefix.toBytes();
  final box = await _aes.encrypt(
    zip,
    secretKey: SecretKey(dataKey),
    nonce: nonce,
    aad: aad,
  );
  return (BytesBuilder(copy: false)
        ..add(aad)
        ..add(box.cipherText)
        ..add(box.mac.bytes))
      .toBytes();
}

/// Ways to open an encrypted backup, tried in order.
@immutable
class BackupUnlock {
  const BackupUnlock({this.known = const [], this.password, this.recoveryKey});

  /// Keys stored on this device (current and earlier passwords).
  final List<BackupKeys> known;
  final String? password;
  final Uint8List? recoveryKey;
}

/// Decrypts [bytes] to the bundle zip. Throws [BackupCryptoException].
Future<Uint8List> decryptBackup(Uint8List bytes, BackupUnlock unlock) async {
  final h = readEncryptedHeader(bytes);
  final slots = (h.json['slots']! as Map).cast<String, Object?>();
  final pwSlot = _unb64(slots['password']);
  final recSlot = _unb64(slots['recovery']);

  Uint8List? dataKey;
  for (final k in unlock.known) {
    if (dataKey != null) break;
    if (sameKey(k.salt, h.salt) && k.iterations == h.iterations) {
      dataKey = await _unwrap(k.passwordKek, pwSlot, 'password');
    }
    if (dataKey == null && sameKey(k.recoverySalt, h.recoverySalt)) {
      dataKey = await _unwrap(k.recoveryKek, recSlot, 'recovery');
    }
  }
  if (dataKey == null && unlock.password != null) {
    final kek = await derivePasswordKek(unlock.password!, h.salt, h.iterations);
    dataKey = await _unwrap(kek, pwSlot, 'password');
  }
  if (dataKey == null && unlock.recoveryKey != null) {
    final kek = await deriveRecoveryKek(unlock.recoveryKey!, h.recoverySalt);
    dataKey = await _unwrap(kek, recSlot, 'recovery');
  }
  if (dataKey == null) {
    throw const BackupCryptoException(BackupCryptoError.wrongKey);
  }

  final macLength = _aes.macAlgorithm.macLength;
  if (bytes.length < h.payloadOffset + macLength) {
    throw const BackupCryptoException(BackupCryptoError.damaged);
  }
  try {
    final clear = await _aes.decrypt(
      SecretBox(
        Uint8List.sublistView(bytes, h.payloadOffset, bytes.length - macLength),
        nonce: _unb64(h.json['nonce']),
        mac: Mac(Uint8List.sublistView(bytes, bytes.length - macLength)),
      ),
      secretKey: SecretKey(dataKey),
      aad: Uint8List.sublistView(bytes, 0, h.payloadOffset),
    );
    return Uint8List.fromList(clear);
  } on SecretBoxAuthenticationError {
    throw const BackupCryptoException(BackupCryptoError.damaged);
  }
}
