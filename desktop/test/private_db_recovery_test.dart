// Recovery from a LOCKED private database — the encrypted file exists but its
// SQLCipher key is unreadable from the Keychain (post-migration / re-signing).
//
// Covers the two core primitives the in-app recovery flow relies on:
//   • [DesktopPrivateDb.isDatabaseLocked] — the probe that decides whether to
//     offer recovery instead of a dead-end error, and
//   • [DesktopPrivateDb.resetLockedDatabase] — the file-level reset that clears
//     the orphaned (unrecoverable) db so the next open mints a fresh key.
//
// Runs headless: path_provider and flutter_secure_storage are channel-mocked so
// the real singleton exercises real file IO against a temp Application Support
// directory, with an in-memory Keychain.
import 'dart:io';

import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  const privateStorageChannel = MethodChannel('evolve/private_storage');
  const keyStorageKey = 'evolve_private_db_key';
  const dbFileName = 'evolve_private_v2.db';

  late Directory tempDir;
  final keychain = <String, String>{};

  File dbFile() => File(p.join(tempDir.path, dbFileName));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('evolve_reset_test');
    keychain.clear();

    messenger.setMockMethodCallHandler(pathChannel, (call) async {
      if (call.method == 'getApplicationSupportDirectory') return tempDir.path;
      return null;
    });
    messenger.setMockMethodCallHandler(secureChannel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return key == null ? null : keychain[key];
        case 'write':
          if (key != null) keychain[key] = args['value'] as String;
          return null;
        case 'delete':
          if (key != null) keychain.remove(key);
          return null;
        case 'containsKey':
          return key != null && keychain.containsKey(key);
        case 'readAll':
          return Map<String, String>.from(keychain);
        case 'deleteAll':
          keychain.clear();
          return null;
      }
      return null;
    });
    // excludeFromBackup is a fire-and-forget no-op in the headless harness.
    messenger.setMockMethodCallHandler(
      privateStorageChannel,
      (call) async => null,
    );
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(pathChannel, null);
    messenger.setMockMethodCallHandler(secureChannel, null);
    messenger.setMockMethodCallHandler(privateStorageChannel, null);
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  final db = DesktopPrivateDb.instance;

  test('isDatabaseLocked: false on a true first run (no db file)', () async {
    expect(await db.isDatabaseLocked(), isFalse);
  });

  test('isDatabaseLocked: true when the file exists but the key is gone',
      () async {
    await dbFile().writeAsString('encrypted-bytes');
    expect(await db.isDatabaseLocked(), isTrue);
  });

  test('isDatabaseLocked: false when a valid key is present', () async {
    await dbFile().writeAsString('encrypted-bytes');
    keychain[keyStorageKey] = 'k' * 64;
    expect(await db.isDatabaseLocked(), isFalse);
  });

  test('isDatabaseLocked: true when only a too-short key remnant survives',
      () async {
    await dbFile().writeAsString('encrypted-bytes');
    keychain[keyStorageKey] = 'short'; // < 32 chars ⇒ unusable
    expect(await db.isDatabaseLocked(), isTrue);
  });

  test(
    'resetLockedDatabase deletes the db file, its -wal/-shm sidecars and the '
    'key remnant, leaving the store unlocked',
    () async {
      await dbFile().writeAsString('enc');
      await File('${dbFile().path}-wal').writeAsString('wal');
      await File('${dbFile().path}-shm').writeAsString('shm');
      keychain[keyStorageKey] = 'short'; // unreadable remnant
      expect(await db.isDatabaseLocked(), isTrue);

      await db.resetLockedDatabase();

      expect(await dbFile().exists(), isFalse);
      expect(await File('${dbFile().path}-wal').exists(), isFalse);
      expect(await File('${dbFile().path}-shm').exists(), isFalse);
      expect(keychain.containsKey(keyStorageKey), isFalse);
      // No file ⇒ the next open takes the first-run path and mints a fresh key.
      expect(await db.isDatabaseLocked(), isFalse);
    },
  );

  test(
    'syncStore throws PrivateDatabaseLockedException on a locked DB — the exact '
    'crash path CloudKitPrivateSyncService._syncNow → storeProvider takes, and '
    'the typed exception DesktopSyncLifecycle._sync must catch to no-op instead '
    'of surfacing an unhandled zone crash',
    () async {
      await dbFile().writeAsString('encrypted-bytes'); // file exists, key gone
      await expectLater(
        db.syncStore(), // → database → _open → _encryptionKey (throws)
        throwsA(isA<PrivateDatabaseLockedException>()),
      );
    },
  );

  test('the guard throws the typed PrivateDatabaseLockedException', () {
    // toString stays byte-identical to the historical StateError message so any
    // UI surfacing error.toString() (and mobile parity) is unchanged.
    expect(
      const PrivateDatabaseLockedException().toString(),
      'Private database key unavailable while the database file exists; '
      'refusing to regenerate it so the data stays recoverable.',
    );
  });
}
