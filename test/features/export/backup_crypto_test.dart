import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/export/domain/backup_crypto.dart';

void main() {
  // Few iterations keep the tests fast; the count travels in the header.
  const it = 1000;
  final zip = Uint8List.fromList(utf8.encode('PK… a bundle zip' * 100));
  final recovery = newRecoveryKey(Random(1));
  late BackupKeys keys;

  setUpAll(() async {
    keys = await createBackupKeys('correct horse', recovery, iterations: it);
  });

  Future<Uint8List> enc([BackupKeys? k]) =>
      encryptBackup(zip, k ?? keys, appVersion: '0.2.0+2');

  Matcher fails(BackupCryptoError e) =>
      throwsA(isA<BackupCryptoException>().having((x) => x.error, 'error', e));

  test(
    'opens with the password, the recovery key or the stored keys',
    () async {
      final file = await enc();
      expect(isEncryptedBackup(file), isTrue);
      expect(isEncryptedBackup(zip), isFalse);
      // The bundle is not readable inside the file.
      expect(
        utf8.decode(file, allowMalformed: true),
        isNot(contains('bundle')),
      );

      expect(
        await decryptBackup(
          file,
          const BackupUnlock(password: 'correct horse'),
        ),
        zip,
      );
      expect(
        await decryptBackup(file, BackupUnlock(recoveryKey: recovery)),
        zip,
      );
      expect(await decryptBackup(file, BackupUnlock(known: [keys])), zip);

      final h = readEncryptedHeader(file);
      expect(h.keyId, keys.keyId);
      expect(h.iterations, it);
      expect(h.appVersion, '0.2.0+2');
    },
  );

  test('wrong password or recovery key', () async {
    final file = await enc();
    expect(
      () => decryptBackup(file, const BackupUnlock(password: 'Correct horse')),
      fails(BackupCryptoError.wrongKey),
    );
    expect(
      () => decryptBackup(file, BackupUnlock(recoveryKey: newRecoveryKey())),
      fails(BackupCryptoError.wrongKey),
    );
    expect(
      () => decryptBackup(file, const BackupUnlock()),
      fails(BackupCryptoError.wrongKey),
    );
  });

  test('tampering is detected', () async {
    final file = await enc();
    final h = readEncryptedHeader(file);

    final body = Uint8List.fromList(file);
    body[h.payloadOffset + 5] ^= 1;
    expect(
      () => decryptBackup(body, BackupUnlock(known: [keys])),
      fails(BackupCryptoError.damaged),
    );

    final truncated = Uint8List.sublistView(file, 0, file.length - 3);
    expect(
      () => decryptBackup(truncated, BackupUnlock(known: [keys])),
      fails(BackupCryptoError.damaged),
    );

    // The header is authenticated too (here: the app version).
    final text = utf8.decode(file.sublist(9, h.payloadOffset));
    final edited = utf8.encode(text.replaceFirst('0.2.0+2', '0.2.0+3'));
    final header = Uint8List.fromList([
      ...file.sublist(0, 9),
      ...edited,
      ...file.sublist(h.payloadOffset),
    ]);
    expect(
      () => decryptBackup(header, BackupUnlock(known: [keys])),
      fails(BackupCryptoError.damaged),
    );

    final newer = Uint8List.fromList(file)..[4] = encryptedFormatVersion + 1;
    expect(
      () => readEncryptedHeader(newer),
      fails(BackupCryptoError.newerVersion),
    );
    expect(
      () => readEncryptedHeader(zip),
      fails(BackupCryptoError.notEncrypted),
    );
  });

  test('a new password keeps the recovery key and old files', () async {
    final old = await enc();
    final next = await withNewPassword(keys, 'battery staple', iterations: it);
    final fresh = await enc(next);

    expect(next.recoveryKek, keys.recoveryKek);
    expect(next.keyId, isNot(keys.keyId));
    // Old file: old password or recovery key; new file: new password or
    // the same recovery key.
    expect(
      await decryptBackup(old, const BackupUnlock(password: 'correct horse')),
      zip,
    );
    expect(await decryptBackup(old, BackupUnlock(recoveryKey: recovery)), zip);
    expect(
      await decryptBackup(
        fresh,
        const BackupUnlock(password: 'battery staple'),
      ),
      zip,
    );
    expect(
      await decryptBackup(fresh, BackupUnlock(recoveryKey: recovery)),
      zip,
    );
    expect(
      () => decryptBackup(fresh, const BackupUnlock(password: 'correct horse')),
      fails(BackupCryptoError.wrongKey),
    );
    // A device that only stored the new keys still opens the old file
    // through the shared recovery slot.
    expect(await decryptBackup(old, BackupUnlock(known: [next])), zip);
  });

  test('a new recovery key keeps the password', () async {
    final other = newRecoveryKey(Random(2));
    final next = await withNewRecoveryKey(keys, other);
    final file = await enc(next);
    expect(await decryptBackup(file, BackupUnlock(recoveryKey: other)), zip);
    expect(
      await decryptBackup(file, const BackupUnlock(password: 'correct horse')),
      zip,
    );
    expect(
      () => decryptBackup(file, BackupUnlock(recoveryKey: recovery)),
      fails(BackupCryptoError.wrongKey),
    );
  });

  test('stored keys round-trip through JSON', () async {
    final again = BackupKeys.fromJson(
      (jsonDecode(jsonEncode(keys.toJson())) as Map).cast<String, Object?>(),
    );
    expect(await decryptBackup(await enc(), BackupUnlock(known: [again])), zip);
  });

  test('a damaged header is reported as damaged, never as a crash', () async {
    final file = await enc();
    final h = readEncryptedHeader(file);
    final json = Map<String, Object?>.from(h.json);
    final payload = file.sublist(h.payloadOffset);

    Uint8List withHeader(Map<String, Object?> j) {
      final header = utf8.encode(jsonEncode(j));
      return Uint8List.fromList([
        ...file.sublist(0, 5),
        ...(ByteData(4)..setUint32(0, header.length)).buffer.asUint8List(),
        ...header,
        ...payload,
      ]);
    }

    Map<String, Object?> kdfWith(Object? iterations) => {
      ...json,
      'kdf': {...(json['kdf']! as Map), 'iterations': iterations},
    };

    final broken = <String, Uint8List>{
      'no slots': withHeader({...json}..remove('slots')),
      'no nonce': withHeader({...json}..remove('nonce')),
      'slots of the wrong type': withHeader({...json, 'slots': 'x'}),
      'short slot': withHeader({
        ...json,
        'slots': {...(json['slots']! as Map), 'password': 'AAAA'},
      }),
      'short nonce': withHeader({...json, 'nonce': 'AAAA'}),
      'nonce not base64': withHeader({...json, 'nonce': '%%%'}),
      'iterations 0': withHeader(kdfWith(0)),
      'iterations 2^31': withHeader(kdfWith(1 << 31)),
      'iterations as text': withHeader(kdfWith('many')),
      'header longer than the file': Uint8List.fromList([
        ...file.sublist(0, 5),
        0xff,
        0xff,
        0xff,
        0xff,
        ...file.sublist(9),
      ]),
      'cut after the header': file.sublist(0, h.payloadOffset + 3),
      'only the magic number': file.sublist(0, 12),
    };
    for (final e in broken.entries) {
      for (final unlock in [
        const BackupUnlock(password: 'correct horse'),
        BackupUnlock(recoveryKey: recovery),
        BackupUnlock(known: [keys]),
      ]) {
        await expectLater(
          decryptBackup(e.value, unlock),
          fails(BackupCryptoError.damaged),
          reason: e.key,
        );
      }
    }
  });

  test('recovery key text: 8 groups, forgiving input', () {
    final text = formatRecoveryKey(recovery);
    expect(RegExp(r'^([A-Z2-7]{4}-){7}[A-Z2-7]{4}$').hasMatch(text), isTrue);
    expect(parseRecoveryKey(text), recovery);
    final sloppy = ' ${text.toLowerCase().replaceAll('-', ' ')} '
        .replaceAll('o', '0')
        .replaceAll('i', '1');
    expect(parseRecoveryKey(sloppy), recovery);
    expect(parseRecoveryKey('ABCD-EFGH'), isNull);
    expect(normalizeRecoveryKey(' 87 kd-o1 '), 'B7KDOI');
    expect(parseRecoveryKey('${text.substring(0, 38)}!'), isNull);
  });
}
