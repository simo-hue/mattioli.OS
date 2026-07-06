// Enable-flow + identity-merge tests (iCloud sync step 3b): a second device
// with its own private data adopts the canonical owner, re-keys, and unions
// with the first device's data — no loss, FK-clean.
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:evolve_sync/testing.dart';

/// Shared in-memory iCloud-Keychain stand-in (one instance => the user's
/// devices see the same key + canonical owner).
class _FakeSecretStore implements SyncSecretStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final crypto = SyncCrypto();
  String t(int hour) =>
      DateTime.utc(2020, 1, 1).add(Duration(hours: hour)).toIso8601String();

  Future<Database> openFreshV3() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: PrivateDbSchema.version,
          singleInstance: false,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: PrivateDbSchema.onCreate,
          onUpgrade: PrivateDbSchema.onUpgrade,
        ),
      );

  Future<void> seed(Database db, String owner, String goalId) async {
    await db.insert('profiles',
        {'id': owner, 'created_at': t(1), 'updated_at': t(1)});
    await db.insert('goals', {
      'id': goalId,
      'user_id': owner,
      'title': 'goal $goalId',
      'color': '#FFFFFF',
      'start_date': t(2),
      'created_at': t(2),
      'updated_at': t(2),
    });
  }

  Future<List<Map<String, Object?>>> goals(Database db) =>
      db.query('goals', orderBy: 'id');

  SyncEngine engine(Database db, CloudKitBridge bridge) =>
      SyncEngine(store: SyncLocalStore(db), bridge: bridge, crypto: crypto);

  group('reKeyOwner migration', () {
    test('renames the owner across all tables, FK-clean', () async {
      final db = await openFreshV3();
      await seed(db, 'localA', 'g1');
      final store = SyncLocalStore(db);

      await store.reKeyOwner('localA', 'canonical');

      expect(await db.query('profiles', where: 'id = ?', whereArgs: ['localA']),
          isEmpty);
      expect(
          await db.query('profiles', where: 'id = ?', whereArgs: ['canonical']),
          hasLength(1));
      expect((await goals(db)).single['user_id'], 'canonical');
      expect(await store.foreignKeyCheck(), isEmpty);
      // sync_state rebuilt under the canonical record_name, all dirty.
      final s = await db.query(PrivateDbSchema.syncStateTable,
          where: 'record_name = ?', whereArgs: ['profiles:canonical']);
      expect(s.single['dirty'], 1);
      await db.close();
    });

    test('merges into an already-present canonical profile', () async {
      final db = await openFreshV3();
      await seed(db, 'localB', 'g1');
      // A canonical profile already exists locally (e.g. pulled before re-key).
      await db.insert('profiles',
          {'id': 'canonical', 'created_at': t(1), 'updated_at': t(5)});

      await SyncLocalStore(db).reKeyOwner('localB', 'canonical');

      expect(await db.query('profiles', where: 'id = ?', whereArgs: ['localB']),
          isEmpty);
      expect(
          await db.query('profiles', where: 'id = ?', whereArgs: ['canonical']),
          hasLength(1));
      expect((await goals(db)).single['user_id'], 'canonical');
      expect(await SyncLocalStore(db).foreignKeyCheck(), isEmpty);
      await db.close();
    });
  });

  test('two devices with separate data merge under one canonical owner',
      () async {
    final cloud = FakeCloudKitBridge();
    final secrets = _FakeSecretStore(); // shared iCloud Keychain
    final keysA = SyncKeyStore(secrets, crypto: crypto);
    final keysB = SyncKeyStore(secrets, crypto: crypto);

    final dbA = await openFreshV3();
    final dbB = await openFreshV3();
    await seed(dbA, 'ownerA', 'gA');
    await seed(dbB, 'ownerB', 'gB');

    // A enables first -> publishes canonical = ownerA, uploads gA.
    await engine(dbA, cloud).enable(keys: keysA, localOwner: 'ownerA');
    // B enables -> adopts ownerA, re-keys gB to it, uploads gB, pulls gA.
    final resB =
        await engine(dbB, cloud).enable(keys: keysB, localOwner: 'ownerB');

    expect(resB.ran, isTrue);
    final bGoals = await goals(dbB);
    expect(bGoals.map((g) => g['id']), containsAll(['gA', 'gB']));
    expect(bGoals.every((g) => g['user_id'] == 'ownerA'), isTrue);
    expect(await SyncLocalStore(dbB).foreignKeyCheck(), isEmpty);

    // A syncs again -> receives gB. Both devices now hold the union.
    await engine(dbA, cloud).syncNow(await keysA.getOrCreateKey());
    final aGoals = await goals(dbA);
    expect(aGoals.map((g) => g['id']), containsAll(['gA', 'gB']));
    expect(aGoals.every((g) => g['user_id'] == 'ownerA'), isTrue);

    await dbA.close();
    await dbB.close();
  });

  test('enable is a no-op when iCloud is unavailable', () async {
    final cloud = FakeCloudKitBridge()..status = CloudAccountStatus.noAccount;
    final keys = SyncKeyStore(_FakeSecretStore(), crypto: crypto);
    final db = await openFreshV3();
    await seed(db, 'ownerA', 'gA');

    final res = await engine(db, cloud).enable(keys: keys, localOwner: 'ownerA');
    expect(res.ran, isFalse);
    expect(res.blockedBy, CloudAccountStatus.noAccount);
    expect(cloud.saveCalls, 0);
    await db.close();
  });
}
