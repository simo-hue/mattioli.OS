import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/sync_crypto.dart';

void main() {
  final crypto = SyncCrypto();

  Uint8List key() => crypto.generateKey();

  group('SyncCrypto AES-256-GCM', () {
    test('generateKey returns 32 bytes', () {
      expect(key().length, SyncCrypto.keyLengthBytes);
      expect(SyncCrypto.keyLengthBytes, 32);
    });

    test('bytes round-trip', () {
      final k = key();
      final plain = Uint8List.fromList(List<int>.generate(257, (i) => i % 256));
      final sealed = crypto.encryptBytes(plain, k);
      expect(crypto.decryptBytes(sealed, k), plain);
    });

    test('string + json round-trip', () {
      final k = key();
      expect(crypto.decryptString(crypto.encryptString('héllo 🔒', k), k),
          'héllo 🔒');
      final json = {'a': 1, 'b': 'x', 'c': [1, 2, 3], 'd': null};
      expect(crypto.decryptJson(crypto.encryptJson(json, k), k), json);
    });

    test('wrong key fails to decrypt (authenticated)', () {
      final sealed = crypto.encryptString('secret', key());
      expect(() => crypto.decryptString(sealed, key()),
          throwsA(isA<Exception>()));
    });

    test('tampered ciphertext fails to decrypt', () {
      final k = key();
      final sealed = crypto.encryptString('secret', k);
      // Flip a byte in the ciphertext/tag region (after the 12-byte nonce).
      sealed[sealed.length - 1] ^= 0xFF;
      expect(() => crypto.decryptBytes(sealed, k), throwsA(isA<Exception>()));
    });

    test('nonce is random per encryption (same input -> different blobs)', () {
      final k = key();
      final a = crypto.encryptString('same', k);
      final b = crypto.encryptString('same', k);
      expect(a, isNot(equals(b)));
      // ...but both decrypt back to the same plaintext.
      expect(crypto.decryptString(a, k), 'same');
      expect(crypto.decryptString(b, k), 'same');
    });

    test('rejects wrong-size key and truncated blob', () {
      expect(() => crypto.encryptBytes(Uint8List(1), Uint8List(16)),
          throwsArgumentError);
      expect(() => crypto.decryptBytes(Uint8List(4), key()),
          throwsArgumentError);
    });

    test('blob layout is nonce(12) || ciphertext || tag(16)', () {
      final sealed = crypto.encryptBytes(Uint8List(0), key());
      // empty plaintext -> 12 (nonce) + 0 (ct) + 16 (tag)
      expect(sealed.length, 12 + 0 + 16);
    });
  });

  test('key is base64-stable (store as text)', () {
    final k = key();
    expect(base64Decode(base64Encode(k)), k);
  });
}
