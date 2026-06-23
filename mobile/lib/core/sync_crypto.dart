import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Client-side AES-256-GCM for iCloud sync payloads (true E2E: the native
/// CloudKit bridge only ever sees ciphertext). Pure Dart so it's fully unit
/// testable; no platform channels.
///
/// Wire format of a sealed blob: `nonce(12) || ciphertext || tag(16)`.
/// GCM is authenticated, so a wrong key or any tampering makes [decryptBytes]
/// throw rather than return garbage.
class SyncCrypto {
  /// 256-bit key.
  static const int keyLengthBytes = 32;

  /// 96-bit nonce — the standard/recommended GCM IV size.
  static const int _nonceLengthBytes = 12;

  /// 128-bit authentication tag.
  static const int _macBits = 128;
  static const int _tagLengthBytes = _macBits ~/ 8;

  final Random _random;

  /// [random] is injectable for tests; production uses a CSPRNG.
  SyncCrypto({Random? random}) : _random = random ?? Random.secure();

  /// A fresh random 256-bit key.
  Uint8List generateKey() => _randomBytes(keyLengthBytes);

  Uint8List _randomBytes(int n) {
    final b = Uint8List(n);
    for (var i = 0; i < n; i++) {
      b[i] = _random.nextInt(256);
    }
    return b;
  }

  void _checkKey(Uint8List key) {
    if (key.length != keyLengthBytes) {
      throw ArgumentError(
        'Key must be $keyLengthBytes bytes, got ${key.length}',
      );
    }
  }

  GCMBlockCipher _cipher(bool forEncryption, Uint8List key, Uint8List nonce) =>
      GCMBlockCipher(AESEngine())
        ..init(
          forEncryption,
          AEADParameters(KeyParameter(key), _macBits, nonce, Uint8List(0)),
        );

  /// Seals [plaintext] → `nonce || ciphertext || tag`.
  Uint8List encryptBytes(Uint8List plaintext, Uint8List key) {
    _checkKey(key);
    final nonce = _randomBytes(_nonceLengthBytes);
    final sealed = _cipher(true, key, nonce).process(plaintext);
    final out = Uint8List(nonce.length + sealed.length);
    out.setAll(0, nonce);
    out.setAll(nonce.length, sealed);
    return out;
  }

  /// Opens a blob produced by [encryptBytes]. Throws on a wrong key, tampering,
  /// or a truncated blob.
  Uint8List decryptBytes(Uint8List blob, Uint8List key) {
    _checkKey(key);
    if (blob.length < _nonceLengthBytes + _tagLengthBytes) {
      throw ArgumentError('Ciphertext too short: ${blob.length} bytes');
    }
    final nonce = blob.sublist(0, _nonceLengthBytes);
    final body = blob.sublist(_nonceLengthBytes);
    // Throws InvalidCipherTextException on a failed tag check (wrong key/tamper).
    return _cipher(false, key, nonce).process(body);
  }

  Uint8List encryptString(String text, Uint8List key) =>
      encryptBytes(Uint8List.fromList(utf8.encode(text)), key);

  String decryptString(Uint8List blob, Uint8List key) =>
      utf8.decode(decryptBytes(blob, key));

  Uint8List encryptJson(Map<String, dynamic> json, Uint8List key) =>
      encryptString(jsonEncode(json), key);

  Map<String, dynamic> decryptJson(Uint8List blob, Uint8List key) =>
      jsonDecode(decryptString(blob, key)) as Map<String, dynamic>;
}
