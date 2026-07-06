import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:evolve_sync/evolve_sync.dart';

/// In-memory [SyncSecretStore] standing in for the iCloud Keychain.
class _FakeSecretStore implements SyncSecretStore {
  final Map<String, String> values = {};
  int writes = 0;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    writes++;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  late _FakeSecretStore store;
  late SyncKeyStore keys;

  setUp(() {
    store = _FakeSecretStore();
    keys = SyncKeyStore(store);
  });

  group('sync key', () {
    test('readKey is null before anything is stored', () async {
      expect(await keys.readKey(), isNull);
    });

    test('getOrCreateKey generates once, persists, and reuses', () async {
      final k1 = await keys.getOrCreateKey();
      expect(k1.length, SyncCrypto.keyLengthBytes);
      expect(store.values[SyncKeyStore.keyKey], isNotNull);
      final writesAfterCreate = store.writes;

      final k2 = await keys.getOrCreateKey();
      expect(k2, k1); // same key
      expect(store.writes, writesAfterCreate); // no second write
      expect(await keys.readKey(), k1);
    });

    test('a malformed stored key is treated as absent', () async {
      store.values[SyncKeyStore.keyKey] = base64Encode([1, 2, 3]); // too short
      expect(await keys.readKey(), isNull);
    });
  });

  group('canonical owner', () {
    test('getOrSetCanonicalOwner publishes fallback when none exists', () async {
      final owner = await keys.getOrSetCanonicalOwner('device-A-owner');
      expect(owner, 'device-A-owner');
      expect(await keys.readCanonicalOwner(), 'device-A-owner');
    });

    test('getOrSetCanonicalOwner adopts an already-published owner', () async {
      await keys.setCanonicalOwner('device-A-owner'); // first device set it
      final adopted = await keys.getOrSetCanonicalOwner('device-B-owner');
      expect(adopted, 'device-A-owner'); // B adopts A's, ignores its fallback
    });
  });

  test('deleteAll clears key and owner (full reset)', () async {
    await keys.getOrCreateKey();
    await keys.setCanonicalOwner('owner');
    await keys.deleteAll();
    expect(await keys.readKey(), isNull);
    expect(await keys.readCanonicalOwner(), isNull);
  });
}
