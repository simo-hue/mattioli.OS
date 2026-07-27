// Recovery from a LOCKED private database — the encrypted file exists but its
// SQLCipher key is unreadable from the Keychain (post-migration / re-signing).
// Mirrors desktop/test/private_db_recovery_test.dart.
//
// Exercises the two primitives the in-app recovery flow relies on:
//   • [PrivateLocalDatabase.isDatabaseLocked] — the probe that decides whether
//     to offer recovery instead of a dead-end error, and
//   • [PrivateLocalDatabase.resetLockedDatabase] — the file-level reset that
//     clears the orphaned (unrecoverable) db so the next open mints a fresh key.
//
// Runs headless: path_provider and flutter_secure_storage are channel-mocked so
// the real singleton exercises real file IO against a temp Application Support
// directory, with an in-memory Keychain.
import 'dart:io';

import 'package:mattioli_os/core/private_local_database.dart';
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
  const keyStorageKey = 'private_mode_db_password_v1';
  const dbFileName = 'private_mode_v1.db';

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

  final db = PrivateLocalDatabase();

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
    keychain[keyStorageKey] = 'short';
    expect(await db.isDatabaseLocked(), isTrue);
  });

  test(
    'resetLockedDatabase MOVES the db aside instead of deleting it, keeps its '
    'key, and still clears the avatar folder + live key',
    () async {
      await dbFile().writeAsString('enc');
      await File('${dbFile().path}-wal').writeAsString('wal');
      await File('${dbFile().path}-shm').writeAsString('shm');
      final avatarDir = Directory(p.join(tempDir.path, 'private_profile'));
      await avatarDir.create(recursive: true);
      await File(p.join(avatarDir.path, 'avatar.img')).writeAsString('img');
      keychain[keyStorageKey] = 'short';
      expect(await db.isDatabaseLocked(), isTrue);

      await db.resetLockedDatabase();

      expect(await dbFile().exists(), isFalse);
      expect(await File('${dbFile().path}-wal').exists(), isFalse);
      expect(await File('${dbFile().path}-shm').exists(), isFalse);
      expect(await avatarDir.exists(), isFalse);
      expect(keychain.containsKey(keyStorageKey), isFalse);
      expect(await db.isDatabaseLocked(), isFalse);

      // NOT destroyed: every common cause of "can't open" leaves the ciphertext
      // intact and merely separated from its key, so a delete would make a
      // recoverable situation permanent.
      final aside = await db.lockedAsideCopy();
      expect(aside, isNotNull,
          reason: 'the encrypted database must still exist somewhere');
      expect(await File(aside!.path).readAsString(), 'enc');
    },
  );

  test(
    'the aside copy keeps its KEY — preserving ciphertext while destroying the '
    'key that opens it would preserve something nobody can ever read',
    () async {
      await dbFile().writeAsString('enc');
      final key = 'k' * 64;
      keychain[keyStorageKey] = key;

      await db.resetLockedDatabase();

      expect(keychain.containsKey(keyStorageKey), isFalse);
      expect(keychain['private_mode_db_password_v1.aside'], key,
          reason: 'the aside copy must remain decryptable');
    },
  );

  test('deleting the aside copy also removes its parked key', () async {
    await dbFile().writeAsString('enc');
    keychain[keyStorageKey] = 'k' * 64;
    await db.resetLockedDatabase();

    await db.deleteLockedAsideCopy();

    expect(await db.lockedAsideCopy(), isNull);
    expect(keychain.containsKey('private_mode_db_password_v1.aside'), isFalse);
  });

  group('the primitives cannot be turned against intact data', () {
    test(
      'restoreStashedDatabase with NO stash present leaves the live database '
      'untouched — it used to delete it unconditionally and restore nothing',
      () async {
        await dbFile().writeAsString('healthy-and-in-use');
        keychain[keyStorageKey] = 'k' * 64;

        // The recovery's catch-all calls this blind on any failure.
        await db.restoreStashedDatabase();

        expect(await dbFile().exists(), isTrue,
            reason: 'a healthy database must survive a no-op restore');
        expect(await dbFile().readAsString(), 'healthy-and-in-use');
        expect(keychain[keyStorageKey], 'k' * 64,
            reason: 'and its key must survive with it');
      },
    );

    test(
      'stashLockedDatabase ABORTS when clearing the key fails, leaving the '
      'database where it is — the old order renamed first and swallowed the '
      'key failure, which is exactly how a wrongly-keyed database is made',
      () async {
        await dbFile().writeAsString('enc');
        keychain[keyStorageKey] = 'short';
        messenger.setMockMethodCallHandler(secureChannel, (call) async {
          if (call.method == 'delete') {
            throw PlatformException(code: '-25300', message: 'keychain error');
          }
          final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
          final key = args['key'] as String?;
          if (call.method == 'read') return key == null ? null : keychain[key];
          return null;
        });

        final stashed = await db.stashLockedDatabase();

        expect(stashed, isFalse);
        expect(await dbFile().exists(), isTrue,
            reason: 'nothing may move once the key could not be parked');
      },
    );

    test(
      'stashLockedDatabase refuses to clobber an existing stash — that stash is '
      'the only copy of an earlier attempt\'s data',
      () async {
        await File('${dbFile().path}.recovery-bak')
            .writeAsString('earlier-attempt');
        await dbFile().writeAsString('current');
        keychain[keyStorageKey] = 'short';

        final stashed = await db.stashLockedDatabase();

        expect(stashed, isFalse);
        expect(await File('${dbFile().path}.recovery-bak').readAsString(),
            'earlier-attempt');
      },
    );
  });

  group('a key of the right LENGTH is not a key that WORKS', () {
    test(
      'isDatabaseLocked reports true when the fingerprint sidecar proves the '
      'key belongs to a different database',
      () async {
        await dbFile().writeAsString('enc');
        await File('${dbFile().path}.keyfp').writeAsString(
          '{"fp":"0000000000000000","store":"devfile"}',
        );
        keychain[keyStorageKey] = 'k' * 64;

        expect(await db.isDatabaseLocked(), isTrue,
            reason: 'the length test alone called this healthy');
      },
    );

    test('a missing sidecar is NOT evidence of a mismatch', () async {
      await dbFile().writeAsString('enc');
      keychain[keyStorageKey] = 'k' * 64;
      expect(await db.isDatabaseLocked(), isFalse);
    });
  });

  const bak = '.recovery-bak';

  test('stashLockedDatabase renames the db aside and clears the key', () async {
    await dbFile().writeAsString('enc');
    await File('${dbFile().path}-wal').writeAsString('wal');
    keychain[keyStorageKey] = 'short';
    expect(await db.isDatabaseLocked(), isTrue);

    final stashed = await db.stashLockedDatabase();

    expect(stashed, isTrue);
    // Original moved aside to .bak (not deleted); key remnant cleared.
    expect(await dbFile().exists(), isFalse);
    expect(await File('${dbFile().path}$bak').exists(), isTrue);
    expect(await File('${dbFile().path}-wal$bak').exists(), isTrue);
    expect(keychain.containsKey(keyStorageKey), isFalse);
    // With no db file present, a fresh open can proceed (no longer "locked").
    expect(await db.isDatabaseLocked(), isFalse);
  });

  test('restoreStashedDatabase puts the stashed db back and re-locks', () async {
    await dbFile().writeAsString('enc-original');
    keychain[keyStorageKey] = 'short';
    await db.stashLockedDatabase();
    // Simulate the fresh empty DB + minted key a cloud re-pull would create.
    await dbFile().writeAsString('fresh-empty');
    keychain[keyStorageKey] = 'n' * 64;

    await db.restoreStashedDatabase();

    // Fresh DB discarded, the original restored byte-for-byte, .bak gone, and
    // the store is LOCKED again so a later launch re-enters recovery.
    expect(await dbFile().readAsString(), 'enc-original');
    expect(await File('${dbFile().path}$bak').exists(), isFalse);
    expect(keychain.containsKey(keyStorageKey), isFalse);
    expect(await db.isDatabaseLocked(), isTrue);
  });

  test('discardStashedDatabase deletes the stashed .bak set', () async {
    await dbFile().writeAsString('enc');
    keychain[keyStorageKey] = 'short';
    await db.stashLockedDatabase();
    expect(await File('${dbFile().path}$bak').exists(), isTrue);

    await db.discardStashedDatabase();

    expect(await File('${dbFile().path}$bak').exists(), isFalse);
  });

  test('the guard exception toString matches desktop parity', () {
    expect(
      const PrivateDatabaseLockedException().toString(),
      'Private database key unavailable while the database file exists; '
      'refusing to regenerate it so the data stays recoverable.',
    );
  });
}
