import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/cloudkit_bridge.dart';
import 'package:mattioli_os/core/cloudkit_private_sync_service.dart';
import 'package:mattioli_os/core/private_db_schema.dart';
import 'package:mattioli_os/core/sync_crypto.dart';
import 'package:mattioli_os/core/sync_key_store.dart';
import 'package:mattioli_os/core/sync_local_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_cloudkit_bridge.dart';

class _FakeSecretStore implements SyncSecretStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _FakeEnabled implements SyncEnabledStore {
  bool value = false;
  @override
  Future<bool> isEnabled() async => value;
  @override
  Future<void> setEnabled(bool v) async => value = v;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final crypto = SyncCrypto();
  String t(int h) =>
      DateTime.utc(2020, 1, 1).add(Duration(hours: h)).toIso8601String();

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

  Future<void> seed(Database db) async {
    await db.insert('profiles',
        {'id': 'owner', 'created_at': t(1), 'updated_at': t(1)});
    await db.insert('goals', {
      'id': 'g1',
      'user_id': 'owner',
      'title': 'Read',
      'color': '#FFFFFF',
      'start_date': t(2),
      'created_at': t(2),
      'updated_at': t(2),
    });
  }

  CloudKitPrivateSyncService service(
    Database db,
    FakeCloudKitBridge cloud,
    _FakeEnabled enabled,
  ) =>
      CloudKitPrivateSyncService(
        bridge: cloud,
        keys: SyncKeyStore(_FakeSecretStore(), crypto: crypto),
        crypto: crypto,
        storeProvider: () async => SyncLocalStore(db),
        ownerProvider: () async => 'owner',
        enabledStore: enabled,
      );

  test('status reflects disabled state + account availability', () async {
    final db = await openFreshV3();
    final st = await service(db, FakeCloudKitBridge(), _FakeEnabled()).status();
    expect(st.isEnabled, isFalse);
    expect(st.isAvailable, isTrue);
    expect(st.account, CloudAccountStatus.available);
    await db.close();
  });

  test('enable turns sync on and uploads existing data', () async {
    final db = await openFreshV3();
    await seed(db);
    final cloud = FakeCloudKitBridge();
    final enabled = _FakeEnabled();

    final st = await service(db, cloud, enabled).enable();

    expect(st.isEnabled, isTrue);
    expect(enabled.value, isTrue);
    expect(cloud.records.containsKey('goals:g1'), isTrue);
    expect(st.lastSyncedAt, isNotNull);
    await db.close();
  });

  test('enable is rejected when iCloud is unavailable', () async {
    final db = await openFreshV3();
    await seed(db);
    final cloud = FakeCloudKitBridge()..status = CloudAccountStatus.noAccount;
    final enabled = _FakeEnabled();

    final st = await service(db, cloud, enabled).enable();

    expect(st.isEnabled, isFalse);
    expect(enabled.value, isFalse);
    expect(cloud.saveCalls, 0);
    await db.close();
  });

  test('syncNow is a no-op while disabled', () async {
    final db = await openFreshV3();
    await seed(db);
    final cloud = FakeCloudKitBridge();
    await service(db, cloud, _FakeEnabled()).syncNow();
    expect(cloud.saveCalls, 0);
    await db.close();
  });

  test('disable stops syncing but leaves cloud data intact', () async {
    final db = await openFreshV3();
    await seed(db);
    final cloud = FakeCloudKitBridge();
    final enabled = _FakeEnabled();
    final svc = service(db, cloud, enabled);

    await svc.enable();
    expect(cloud.records.containsKey('goals:g1'), isTrue);

    final st = await svc.disable();
    expect(st.isEnabled, isFalse);
    expect(enabled.value, isFalse);
    // Cloud data is NOT deleted by disable.
    expect(cloud.records.containsKey('goals:g1'), isTrue);
    await db.close();
  });

  CloudKitPrivateSyncService serviceWith(
    Database db,
    FakeCloudKitBridge cloud,
    _FakeEnabled enabled,
    _FakeSecretStore secrets,
  ) =>
      CloudKitPrivateSyncService(
        bridge: cloud,
        keys: SyncKeyStore(secrets, crypto: crypto),
        crypto: crypto,
        storeProvider: () async => SyncLocalStore(db),
        ownerProvider: () async => 'owner',
        enabledStore: enabled,
      );

  test('requestFullReset wipes cloud + keys and disables (online)', () async {
    final db = await openFreshV3();
    await seed(db);
    final cloud = FakeCloudKitBridge();
    final enabled = _FakeEnabled();
    final secrets = _FakeSecretStore();
    final svc = serviceWith(db, cloud, enabled, secrets);

    await svc.enable();
    expect(secrets.values, isNotEmpty); // key + owner published

    await svc.requestFullReset();

    expect(enabled.value, isFalse);
    expect(secrets.values, isEmpty); // key + owner removed from Keychain
    expect(cloud.zoneDeleted, isTrue);
    expect(cloud.records, isEmpty);
    expect(await SyncLocalStore(db).pendingZoneWipe(), isFalse); // completed
    await db.close();
  });

  test('requestFullReset queues the wipe when offline, finishes later',
      () async {
    final db = await openFreshV3();
    await seed(db);
    final cloud = FakeCloudKitBridge();
    final enabled = _FakeEnabled();
    final secrets = _FakeSecretStore();
    final svc = serviceWith(db, cloud, enabled, secrets);

    await svc.enable();
    cloud.status = CloudAccountStatus.noAccount; // go offline

    await svc.requestFullReset();
    expect(enabled.value, isFalse);
    expect(secrets.values, isEmpty); // keys removed regardless of connectivity
    expect(cloud.zoneDeleted, isFalse); // couldn't reach iCloud
    expect(await SyncLocalStore(db).pendingZoneWipe(), isTrue); // queued

    // Back online: the next syncNow completes the queued wipe even though
    // sync is disabled.
    cloud.status = CloudAccountStatus.available;
    await svc.syncNow();
    expect(cloud.zoneDeleted, isTrue);
    expect(await SyncLocalStore(db).pendingZoneWipe(), isFalse);
    await db.close();
  });
}
