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
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

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
  final dbFileName = DesktopPrivateDb.databaseFileName;

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
    'resetLockedDatabase MOVES the db aside instead of deleting it — the '
    'ciphertext survives byte-for-byte and stays recoverable',
    () async {
      await dbFile().writeAsString('enc');
      await File('${dbFile().path}-wal').writeAsString('wal');
      await File('${dbFile().path}-shm').writeAsString('shm');
      keychain[keyStorageKey] = 'short'; // unreadable remnant
      expect(await db.isDatabaseLocked(), isTrue);

      await db.resetLockedDatabase();

      // Gone from the canonical path so the next open starts fresh...
      expect(await dbFile().exists(), isFalse);
      expect(await File('${dbFile().path}-wal').exists(), isFalse);
      expect(await File('${dbFile().path}-shm').exists(), isFalse);
      expect(keychain.containsKey(keyStorageKey), isFalse);
      expect(await db.isDatabaseLocked(), isFalse);

      // ...but NOT destroyed. This is the whole point: every common cause of
      // "can't open" leaves the ciphertext intact and merely separated from its
      // key, so a delete would make a recoverable situation permanent.
      final aside = await db.lockedAsideCopy();
      expect(aside, isNotNull,
          reason: 'the encrypted database must still exist somewhere');
      expect(await File(aside!.path).readAsString(), 'enc');
      expect(aside.bytes, 3);
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

      // The live key is cleared so the next open mints a fresh one...
      expect(keychain.containsKey(keyStorageKey), isFalse);
      // ...but the one that belongs to the retained copy is parked, not lost.
      final parked = keychain.entries
          .where((e) => e.key.startsWith('evolve_private_db_key.aside.'))
          .toList();
      expect(parked, hasLength(1));
      expect(parked.single.value, key,
          reason: 'the aside copy must remain decryptable');
    },
  );

  test('deleting the aside copy also removes its parked key', () async {
    await dbFile().writeAsString('enc');
    keychain[keyStorageKey] = 'k' * 64;
    await db.resetLockedDatabase();
    expect(
      keychain.keys.any((k) => k.startsWith('evolve_private_db_key.aside.')),
      isTrue,
    );

    await db.deleteLockedAsideCopy();

    // A parked key outliving its ciphertext is a secret with no purpose.
    expect(await db.lockedAsideCopy(), isNull);
    expect(
      keychain.keys.any((k) => k.startsWith('evolve_private_db_key.aside.')),
      isFalse,
    );
  });

  test(
    'TWO generations are retained, and the THIRD reset drops the oldest — one '
    'slot would mean the second reset destroys what the first one saved, and '
    '"reset, still broken, reset again" is the ordinary path here',
    () async {
      Future<void> resetWith(String contents) async {
        await dbFile().writeAsString(contents);
        await db.resetLockedDatabase();
      }

      await resetWith('first');
      await resetWith('second');

      var copies = await tempDir
          .list()
          .where((e) =>
              e is File &&
              p.basename(e.path).startsWith('$dbFileName.locked-'))
          .toList();
      expect(copies, hasLength(2),
          reason: 'the original must survive the second reset');

      await resetWith('third');

      copies = await tempDir
          .list()
          .where((e) =>
              e is File &&
              p.basename(e.path).startsWith('$dbFileName.locked-'))
          .toList();
      expect(copies, hasLength(2), reason: 'bounded, not unbounded');
      final contents = <String>[];
      for (final c in copies) {
        contents.add(await File(c.path).readAsString());
      }
      expect(contents, containsAll(<String>['second', 'third']));
      expect(contents, isNot(contains('first')),
          reason: 'the OLDEST generation is the one that goes');
    },
  );

  test(
    'deleteLockedAsideCopy is the ONLY way ciphertext is destroyed, and it is '
    'a separate explicit act',
    () async {
      await dbFile().writeAsString('enc');
      await db.resetLockedDatabase();
      expect(await db.lockedAsideCopy(), isNotNull);

      await db.deleteLockedAsideCopy();

      expect(await db.lockedAsideCopy(), isNull);
    },
  );

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

    // Fresh DB discarded, the original restored byte-for-byte, .bak gone, and the
    // store is LOCKED again so a later launch re-enters recovery.
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
        // Make the Keychain delete fail the way a real one can.
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
        expect(await File('${dbFile().path}$bak').exists(), isFalse);
      },
    );

    test(
      'stashLockedDatabase refuses to clobber an existing stash — that stash is '
      'the only copy of an earlier attempt\'s data',
      () async {
        await File('${dbFile().path}$bak').writeAsString('earlier-attempt');
        await dbFile().writeAsString('current');
        keychain[keyStorageKey] = 'short';

        final stashed = await db.stashLockedDatabase();

        expect(stashed, isFalse);
        expect(await File('${dbFile().path}$bak').readAsString(),
            'earlier-attempt');
      },
    );

    test(
      'resetLockedDatabase PROMOTES an orphaned stash instead of deleting it — '
      'a stash still on disk here IS the real database, and the live file is '
      'the empty one minted for a re-pull that restored nothing',
      () async {
        await dbFile().writeAsString('OLD-real-data');
        keychain[keyStorageKey] = 'short';
        await db.stashLockedDatabase();
        // The cloud re-pull created a fresh empty DB and applied nothing.
        await dbFile().writeAsString('FRESH-empty');
        expect(await File('${dbFile().path}$bak').exists(), isTrue);

        await db.resetLockedDatabase();

        // The stash must not survive — the orphan sweep would otherwise restore
        // it over the fresh database and silently undo the reset...
        expect(await File('${dbFile().path}$bak').exists(), isFalse);
        // ...but it must not be DELETED either: it is the only real copy.
        final aside = await db.lockedAsideCopy();
        expect(aside, isNotNull);
        expect(await File(aside!.path).readAsString(), 'OLD-real-data',
            reason: 'archiving the EMPTY file and deleting the real one is the '
                'unconfirmed permanent delete this change exists to abolish');
      },
    );

    test(
      'a promoted stash is NOT advertised with a key that cannot open it — '
      'stashLockedDatabase destroyed the key that opens the stash',
      () async {
        await dbFile().writeAsString('OLD-real-data');
        keychain[keyStorageKey] = 'short';
        await db.stashLockedDatabase();
        await dbFile().writeAsString('FRESH-empty');
        keychain[keyStorageKey] = 'n' * 64; // the fresh DB's key

        await db.resetLockedDatabase();

        expect(
          keychain.keys.any((k) => k.startsWith('evolve_private_db_key.aside.')),
          isFalse,
          reason: 'parking the fresh key beside the OLD ciphertext would claim '
              'a recoverability that does not exist',
        );
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
        keychain[keyStorageKey] = 'k' * 64; // right length, wrong key

        expect(await db.isDatabaseLocked(), isTrue,
            reason: 'the length test alone called this healthy');
      },
    );

    test('and false when the sidecar matches the key actually held', () async {
      await dbFile().writeAsString('enc');
      final key = 'k' * 64;
      keychain[keyStorageKey] = key;
      // Fingerprint is sha256(key)[0:16]; write what the code will compute.
      final fp = sha256.convert(utf8.encode(key)).toString().substring(0, 16);
      await File('${dbFile().path}.keyfp')
          .writeAsString('{"fp":"$fp","store":"devfile"}');

      expect(await db.isDatabaseLocked(), isFalse);
    });

    test('a missing sidecar is NOT evidence of a mismatch', () async {
      await dbFile().writeAsString('enc');
      keychain[keyStorageKey] = 'k' * 64;
      // Legacy databases predate the sidecar; absence must stay silent rather
      // than declaring every one of them broken.
      expect(await db.isDatabaseLocked(), isFalse);
    });
  });

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
