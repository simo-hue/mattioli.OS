// Settings used to live as ~24 columns on the single `profiles` row, so the
// whole row was ONE sync record under row-level last-write-wins: changing the
// accent colour on the Mac and the language on the iPhone inside one sync
// window silently reverted whichever landed first. `user_settings` makes each
// setting its own record, so that class of loss is structurally impossible.
//
// These tests pin the three properties the design depends on: per-key
// independence, cross-device convergence on a shared natural key, and the
// migration/rollout behaviour that stops a lagging device losing records.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:evolve_sync/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const now = '2026-07-21T00:00:00.000Z';
  const owner = 'owner-1';
  final crypto = SyncCrypto();

  Future<Database> openDb() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: PrivateDbSchema.version,
          onConfigure: PrivateDbSchema.onConfigure,
          onCreate: PrivateDbSchema.onCreate,
          onUpgrade: PrivateDbSchema.onUpgrade,
          singleInstance: false,
        ),
      );

  Future<void> seedOwner(Database db) => db.insert(
        'profiles',
        {'id': owner, 'created_at': now, 'updated_at': now},
      );

  Future<void> setSetting(
    Database db,
    String key,
    String value, {
    String? id,
    String? at,
  }) =>
      db.rawInsert(
        'INSERT INTO user_settings (id, user_id, key, value, created_at, '
        'updated_at) VALUES (?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value, '
        'updated_at = excluded.updated_at',
        [id ?? '$owner:$key', owner, key, value, now, at ?? now],
      );

  Future<String?> readSetting(Database db, String key) async {
    final r = await db.query('user_settings',
        columns: ['value'], where: 'user_id = ? AND key = ?',
        whereArgs: [owner, key], limit: 1);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  SyncEngine engine(Database db, FakeCloudKitBridge cloud) => SyncEngine(
        store: SyncLocalStore(db), bridge: cloud, crypto: crypto);

  test('two devices editing DIFFERENT settings both survive', () async {
    // The exact failure row-level LWW produced: accent changed on one device,
    // language on the other, one silently reverting.
    final cloud = FakeCloudKitBridge();
    final key = crypto.generateKey();

    final dbA = await openDb();
    await seedOwner(dbA);
    await setSetting(dbA, 'accent_color', '#FF9500'); // orange
    await setSetting(dbA, 'language', 'it');
    await SyncLocalStore(dbA).markAllDirty();
    await engine(dbA, cloud).syncNow(key);

    final dbB = await openDb();
    await seedOwner(dbB);
    await engine(dbB, cloud).syncNow(key);
    expect(await readSetting(dbB, 'accent_color'), '#FF9500');

    // A changes accent; B changes language — concurrently, neither having seen
    // the other.
    await setSetting(dbA, 'accent_color', '#FFCC00', at: '2026-07-21T01:00:00.000Z');
    await setSetting(dbB, 'language', 'en', at: '2026-07-21T01:00:01.000Z');

    await engine(dbA, cloud).syncNow(key);
    await engine(dbB, cloud).syncNow(key);
    await engine(dbA, cloud).syncNow(key);

    // BOTH edits survive on BOTH devices. Under the old row-level LWW one of
    // them would have been silently discarded.
    for (final db in [dbA, dbB]) {
      expect(await readSetting(db, 'accent_color'), '#FFCC00');
      expect(await readSetting(db, 'language'), 'en');
    }
    await dbA.close();
    await dbB.close();
  });

  test('the same setting written independently on both devices converges to '
      'ONE row', () async {
    // Each app mints its own row id the first time a setting is written, so the
    // same logical setting can exist under two ids. The (user_id, key) natural
    // key is what merges them.
    expect(SyncLocalStore.naturalKeys['user_settings'], ['user_id', 'key']);

    final cloud = FakeCloudKitBridge();
    final key = crypto.generateKey();

    final dbA = await openDb();
    await seedOwner(dbA);
    await setSetting(dbA, 'theme_mode', 'dark', id: 'a-uuid');

    final dbB = await openDb();
    await seedOwner(dbB);
    await setSetting(dbB, 'theme_mode', 'light',
        id: 'b-uuid', at: '2026-07-21T02:00:00.000Z');

    await SyncLocalStore(dbA).markAllDirty();
    await SyncLocalStore(dbB).markAllDirty();
    await engine(dbA, cloud).syncNow(key);
    await engine(dbB, cloud).syncNow(key);
    await engine(dbA, cloud).syncNow(key);
    await engine(dbB, cloud).syncNow(key);

    for (final db in [dbA, dbB]) {
      final rows = await db.query('user_settings',
          where: 'key = ?', whereArgs: ['theme_mode']);
      expect(rows.length, 1,
          reason: 'two ids for one setting must merge, not coexist');
      expect(rows.first['value'], 'light', reason: 'newer edit wins');
    }
    await dbA.close();
    await dbB.close();
  });

  test('device-local columns never leave the device', () async {
    // Entitlement and consent must not travel: a synced is_pro = 1 is an IAP
    // bypass, and consent belongs to the device that asked for it.
    for (final c in const [
      'biometric_lock',
      'is_pro',
      'pro_expires_at',
      'sentry_consent',
      'private_ai_external_consent',
      'terms_accepted_at',
    ]) {
      expect(PrivateDbSchema.localOnlyColumns['profiles'], contains(c));
    }

    final cloud = FakeCloudKitBridge();
    final key = crypto.generateKey();
    final dbA = await openDb();
    await dbA.insert('profiles', {
      'id': owner,
      'created_at': now,
      'updated_at': now,
      'is_pro': 1,
      'biometric_lock': 1,
      'sentry_consent': 1,
    });
    await SyncLocalStore(dbA).markAllDirty();
    await engine(dbA, cloud).syncNow(key);

    // Device B starts with everything OFF and must stay that way.
    final dbB = await openDb();
    await dbB.insert('profiles', {
      'id': owner,
      'created_at': now,
      'updated_at': now,
      'is_pro': 0,
      'biometric_lock': 0,
      'sentry_consent': 0,
    });
    await engine(dbB, cloud).syncNow(key);

    final b = (await dbB.query('profiles', where: 'id = ?', whereArgs: [owner]))
        .first;
    expect(b['is_pro'], 0, reason: 'entitlement must come from this device');
    expect(b['biometric_lock'], 0, reason: 'capability differs per device');
    expect(b['sentry_consent'], 0, reason: 'consent is per device');
    await dbA.close();
    await dbB.close();
  });

  group('rollout', () {
    test('v5 -> v6 migrates the profiles columns into per-key rows', () async {
      // An upgrading device must keep the settings it already had.
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 5,
          singleInstance: false,
          onConfigure: PrivateDbSchema.onConfigure,
          onCreate: (db, _) async {
            await PrivateDbSchema.createCoreTables(db);
            await PrivateDbSchema.createSyncObjects(db);
          },
        ),
      );
      await db.insert('profiles', {
        'id': owner,
        'created_at': now,
        'updated_at': now,
        'accent_color': '#FF9500',
        'language': 'it',
        'theme_mode': 'dark',
      });

      await PrivateDbSchema.onUpgrade(db, 5, PrivateDbSchema.version);

      expect(await readSetting(db, 'accent_color'), '#FF9500');
      expect(await readSetting(db, 'language'), 'it');
      expect(await readSetting(db, 'theme_mode'), 'dark');
      // Device-local columns must NOT be migrated into the synced table.
      expect(await readSetting(db, 'is_pro'), isNull);
      expect(await readSetting(db, 'biometric_lock'), isNull);
      await db.close();
    });

    test('a schema upgrade re-fetches records the old build had to quarantine',
        () async {
      // The rollout hazard: while this device was on v5 it quarantined every
      // `user_settings` record the upgraded device pushed, and the change token
      // advanced past them. CloudKit never replays those, so without a
      // schema-version re-fetch the settings would silently never arrive.
      final db = await openDb();
      final store = SyncLocalStore(db);
      await seedOwner(db);
      await store.quarantineRecord(
        'user_settings:$owner:accent_color',
        'user_settings',
        '$owner:accent_color',
        SyncLocalStore.unknownTableReason,
      );
      // Pretend the last sync ran on the older schema.
      await store.setSyncedSchemaVersion(5);
      await store.setChangeToken('some-token');

      final cloud = FakeCloudKitBridge();
      await engine(db, cloud).syncNow(crypto.generateKey());

      expect(await store.changeToken(), isNot('some-token'),
          reason: 'the token must be dropped so the zone is re-fetched');
      final d = await store.diagnostics();
      expect(d.parkedByReason[SyncLocalStore.unknownTableReason], isNull,
          reason: 'the park is cleared so the record can re-apply');
      expect(await store.syncedSchemaVersion(), PrivateDbSchema.version);
      await db.close();
    });

    test('no re-fetch when the schema has not moved', () async {
      final db = await openDb();
      final store = SyncLocalStore(db);
      await seedOwner(db);
      await store.setSyncedSchemaVersion(PrivateDbSchema.version);
      await store.setChangeToken('keep-me');

      await engine(db, FakeCloudKitBridge()).syncNow(crypto.generateKey());

      expect(await store.changeToken(), isNot(null),
          reason: 'a steady-state sync must not force a full re-fetch');
      await db.close();
    });
  });
}
