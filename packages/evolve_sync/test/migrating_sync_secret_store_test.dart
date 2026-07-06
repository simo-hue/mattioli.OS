// MigratingSyncSecretStore: legacy → shared-group keychain migration semantics
// (P1 of desktop/ICLOUD_SYNC_PLAN.md). The store must heal the primary from
// legacy on read, dual-write so not-yet-updated app versions keep seeing the
// secrets, and wipe both locations on delete.
import 'dart:convert';

import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements SyncSecretStore {
  final Map<String, String> values = {};
  int reads = 0, writes = 0, deletes = 0;

  @override
  Future<String?> read(String key) async {
    reads++;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    deletes++;
    values.remove(key);
  }
}

void main() {
  late _MemoryStore primary;
  late _MemoryStore legacy;
  late MigratingSyncSecretStore store;

  setUp(() {
    primary = _MemoryStore();
    legacy = _MemoryStore();
    store = MigratingSyncSecretStore(primary: primary, legacy: legacy);
  });

  test('read returns primary value without touching legacy', () async {
    primary.values['k'] = 'shared';
    legacy.values['k'] = 'stale-old';
    expect(await store.read('k'), 'shared');
    expect(legacy.reads, 0);
    // Stale legacy copy is left alone — primary is authoritative.
    expect(legacy.values['k'], 'stale-old');
  });

  test('read migrates a legacy-only value into primary (healing)', () async {
    legacy.values['k'] = 'v1';
    expect(await store.read('k'), 'v1');
    expect(primary.values['k'], 'v1', reason: 'healed into the shared group');
    expect(legacy.values['k'], 'v1',
        reason: 'legacy copy kept for older app versions');
  });

  test('migration is idempotent — second read is a plain primary hit',
      () async {
    legacy.values['k'] = 'v1';
    await store.read('k');
    final writesAfterFirst = primary.writes;
    expect(await store.read('k'), 'v1');
    expect(primary.writes, writesAfterFirst, reason: 'no re-migration');
    expect(legacy.reads, 1, reason: 'legacy not consulted once primary has it');
  });

  test('read returns null when neither location has the key', () async {
    expect(await store.read('missing'), isNull);
    expect(primary.writes, 0, reason: 'nothing to heal');
  });

  test('empty-string values are treated as absent', () async {
    primary.values['k'] = '';
    legacy.values['k'] = '';
    expect(await store.read('k'), isNull);
  });

  test('write lands in both locations (older versions read legacy only)',
      () async {
    await store.write('k', 'v2');
    expect(primary.values['k'], 'v2');
    expect(legacy.values['k'], 'v2');
  });

  test('delete wipes both locations (full reset leaves nothing behind)',
      () async {
    primary.values['k'] = 'a';
    legacy.values['k'] = 'b';
    await store.delete('k');
    expect(primary.values, isEmpty);
    expect(legacy.values, isEmpty);
  });

  test('SyncKeyStore over a migrating store adopts the legacy key', () async {
    // End-to-end shape of the 1.0.9 → 1.0.10 upgrade: the key exists only in
    // the legacy location; the key store must return THAT key (not mint a new
    // one, which would orphan every record in the zone).
    final legacyKeyB64 = base64Encode(SyncCrypto().generateKey());
    legacy.values[SyncKeyStore.keyKey] = legacyKeyB64;

    final keys = SyncKeyStore(store);
    final key = await keys.getOrCreateKey();
    expect(base64Encode(key), legacyKeyB64);
    expect(primary.values[SyncKeyStore.keyKey], legacyKeyB64);
  });
}
