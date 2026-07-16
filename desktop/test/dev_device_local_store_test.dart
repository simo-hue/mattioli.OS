// Unit tests for the DEBUG-only file-backed device-local secret store
// ([DevDeviceLocalStore]). This is the escape hatch [SecureStorageUtils] routes
// the Private-mode device-local secrets (SQLCipher DB key + owner id) to on a
// local `flutter run`, so an unstable ad-hoc Team ID no longer resets the DB on
// every launch.
//
// The `kDebugMode` BRANCH FLIP inside [SecureStorageUtils.readDeviceLocal] etc.
// cannot be unit-tested here: `flutter test` always runs with kDebugMode == true
// AND the test harness deliberately keeps the escape hatch off (FLUTTER_TEST is
// set), so the store is never reached through SecureStorageUtils in a test. What
// IS tested — and all that carries the persistence guarantee — is the store
// class SecureStorageUtils delegates to, exercised directly against a temp file
// via the `forFile` test seam (no path_provider channel mock needed).
import 'dart:convert';
import 'dart:io';

import 'package:evolve_desktop/core/dev_device_local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late File file;

  DevDeviceLocalStore newStore() => DevDeviceLocalStore.forFile(file);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dev_device_local_store');
    file = File(p.join(tempDir.path, 'dev_device_local_secrets.json'));
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('read returns null for an absent key (missing file, no throw)', () async {
    final store = newStore();
    expect(await file.exists(), isFalse);
    expect(await store.read('evolve_private_db_key'), isNull);
    // A pure read must not create the backing file.
    expect(await file.exists(), isFalse);
  });

  test('write then read round-trips a value and persists it to disk', () async {
    final store = newStore();
    final key = 'k' * 64;
    await store.write('evolve_private_db_key', key);

    expect(await store.read('evolve_private_db_key'), key);
    expect(await file.exists(), isTrue);
    // The on-disk payload is a plain JSON map (readable/round-trippable).
    final decoded = jsonDecode(await file.readAsString());
    expect(decoded, {'evolve_private_db_key': key});
  });

  test('a value survives across a fresh store instance (restart persistence)',
      () async {
    await newStore().write('evolve_private_owner_id', 'owner-123');
    // A brand-new instance reads the same file — the whole point of the hatch:
    // secrets survive a process restart (the second `flutter run`).
    expect(await newStore().read('evolve_private_owner_id'), 'owner-123');
  });

  test('multiple keys coexist and update independently', () async {
    final store = newStore();
    await store.write('evolve_private_db_key', 'key-A');
    await store.write('evolve_private_owner_id', 'owner-A');
    await store.write('evolve_private_db_key', 'key-B'); // overwrite

    expect(await store.read('evolve_private_db_key'), 'key-B');
    expect(await store.read('evolve_private_owner_id'), 'owner-A');
  });

  test('delete removes only the target key, leaving others intact', () async {
    final store = newStore();
    await store.write('evolve_private_db_key', 'key-A');
    await store.write('evolve_private_owner_id', 'owner-A');

    await store.delete('evolve_private_db_key');

    expect(await store.read('evolve_private_db_key'), isNull);
    expect(await store.read('evolve_private_owner_id'), 'owner-A');
  });

  test('delete of an absent key is a no-op and does not create the file',
      () async {
    final store = newStore();
    await store.delete('evolve_private_db_key');
    expect(await file.exists(), isFalse);
  });

  test('a corrupt (non-JSON) file is treated as empty, never throws', () async {
    await file.writeAsString('}{ this is not valid json at all');
    final store = newStore();

    // Reads recover to empty rather than throwing …
    expect(await store.read('evolve_private_db_key'), isNull);
    // … and a subsequent write transparently overwrites the corrupt file.
    await store.write('evolve_private_db_key', 'fresh');
    expect(await store.read('evolve_private_db_key'), 'fresh');
    expect(jsonDecode(await file.readAsString()), {
      'evolve_private_db_key': 'fresh',
    });
  });

  test('a JSON value that is not an object is treated as empty', () async {
    await file.writeAsString('[1, 2, 3]'); // valid JSON, wrong shape
    final store = newStore();
    expect(await store.read('anything'), isNull);
  });

  test('an empty / whitespace-only file is treated as empty', () async {
    await file.writeAsString('   \n  ');
    final store = newStore();
    expect(await store.read('anything'), isNull);
  });

  test('non-string values in the map are skipped, string ones survive',
      () async {
    // A hand-edited / foreign file could carry non-string values; those are
    // ignored rather than crashing the store.
    await file.writeAsString(jsonEncode({
      'good': 'value',
      'bad': 42,
      'alsoBad': true,
    }));
    final store = newStore();
    expect(await store.read('good'), 'value');
    expect(await store.read('bad'), isNull);
    expect(await store.read('alsoBad'), isNull);
  });

  test(
    'concurrent writes are serialized: no lost update, JSON stays valid',
    () async {
      final store = newStore();
      // Fire many overlapping writes without awaiting between them; the internal
      // lock must serialize the read-modify-write of the shared JSON map so no
      // key is dropped and the file never ends up corrupt.
      final futures = <Future<void>>[
        for (var i = 0; i < 50; i++) store.write('key_$i', 'val_$i'),
      ];
      await Future.wait(futures);

      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(decoded.length, 50);
      for (var i = 0; i < 50; i++) {
        expect(decoded['key_$i'], 'val_$i');
      }
    },
  );

  test('interleaved write/delete under contention leaves a consistent file',
      () async {
    final store = newStore();
    final ops = <Future<void>>[
      for (var i = 0; i < 20; i++) store.write('key_$i', 'v$i'),
      for (var i = 0; i < 20; i += 2) store.delete('key_$i'),
    ];
    await Future.wait(ops);

    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    // Every even key deleted, every odd key present — deterministic because the
    // deletes were enqueued after their matching writes and all ops serialize.
    for (var i = 0; i < 20; i++) {
      if (i.isEven) {
        expect(decoded.containsKey('key_$i'), isFalse, reason: 'key_$i');
      } else {
        expect(decoded['key_$i'], 'v$i');
      }
    }
  });
}
