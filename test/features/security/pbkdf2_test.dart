import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/security/domain/lock_credential.dart';
import 'package:personal_finance/features/security/domain/pbkdf2.dart';

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PBKDF2-HMAC-SHA256 known answers', () {
    // Vectors from RFC 7914 §11 and the widely used SHA-256 variants of the
    // RFC 6070 vectors (cross-checked with Python's hashlib.pbkdf2_hmac).
    final vectors = [
      (
        'password',
        'salt',
        1,
        32,
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      ),
      (
        'password',
        'salt',
        4096,
        32,
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      ),
      (
        'passwordPASSWORDpassword',
        'saltSALTsaltSALTsaltSALTsaltSALTsalt',
        4096,
        40,
        '348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1'
            'c635518c7dac47e9',
      ),
      (
        'passwd',
        'salt',
        1,
        64,
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
            '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
      ),
    ];
    for (final (p, s, c, len, expected) in vectors) {
      test('P="$p" S="$s" c=$c dkLen=$len', () {
        final dk = pbkdf2HmacSha256(
          password: utf8.encode(p),
          salt: utf8.encode(s),
          iterations: c,
          keyLength: len,
        );
        expect(_hex(dk), expected);
      });
    }

    test('binary salt (hashSecret)', () {
      final dk = hashSecret(
        HashRequest(
          '1234',
          Uint8List.fromList(List.generate(16, (i) => i)),
          1000,
        ),
      );
      expect(
        _hex(dk),
        '2240ea2a22754a3c4610356ef8e4d7acf25af2ac3d2d11866de97a8b7812c52c',
      );
    });

    test('rejects zero iterations', () {
      expect(
        () => pbkdf2HmacSha256(password: [1], salt: [2], iterations: 0),
        throwsArgumentError,
      );
    });
  });

  test('constantTimeEquals', () {
    expect(constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
    expect(constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
    expect(constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
  });

  test('credential JSON round trip keeps no secret', () {
    final salt = newSalt();
    expect(salt.length, 16);
    final c = LockCredential(
      kind: SecretKind.pin,
      salt: salt,
      hash: hashSecret(HashRequest('2468', salt, 10)),
      iterations: 10,
      pinLength: 4,
    );
    final json = jsonEncode(c.toJson());
    expect(json, isNot(contains('2468')));
    final back = LockCredential.fromJson(
      (jsonDecode(json) as Map).cast<String, Object?>(),
    );
    expect(back.kind, SecretKind.pin);
    expect(back.pinLength, 4);
    expect(
      back.matches(hashSecret(HashRequest('2468', back.salt, 10))),
      isTrue,
    );
    expect(
      back.matches(hashSecret(HashRequest('2469', back.salt, 10))),
      isFalse,
    );
  });

  test('validateSecret', () {
    expect(validateSecret(SecretKind.pin, '1234'), isNull);
    expect(validateSecret(SecretKind.pin, '12345678'), isNull);
    expect(validateSecret(SecretKind.pin, '123'), SecretProblem.tooShort);
    expect(validateSecret(SecretKind.pin, '123456789'), SecretProblem.tooLong);
    expect(validateSecret(SecretKind.pin, '12a4'), SecretProblem.digits);
    expect(validateSecret(SecretKind.password, 'abc'), SecretProblem.tooShort);
    expect(validateSecret(SecretKind.password, 'correct horse'), isNull);
  });
}
