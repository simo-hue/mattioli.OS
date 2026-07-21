// CloudKit silent push is a LATENCY optimisation over the periodic poll, never
// a replacement for it: Apple explicitly does not guarantee delivery of
// `content-available` pushes — the system throttles and drops them on battery,
// usage and thermal grounds.
//
// The native push path cannot be exercised off-device, so these tests pin the
// properties that make shipping it untested acceptable: registration is
// idempotent, a registration failure never breaks sync, and push introduces no
// second sync path that could drift from the hardened one.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:evolve_sync/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Secrets implements SyncSecretStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _Enabled implements SyncEnabledStore {
  bool value = false;
  @override
  Future<bool> isEnabled() async => value;
  @override
  Future<void> setEnabled(bool v) async => value = v;
}

/// A bridge whose subscription registration always fails, standing in for a
/// device that is offline, lacks the entitlement, or hits a CloudKit error.
class _UnsubscribableBridge extends FakeCloudKitBridge {
  int attempts = 0;
  @override
  Future<void> ensureSubscription() async {
    attempts++;
    throw StateError('no push on this device');
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const now = '2026-07-21T00:00:00.000Z';
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

  Future<Database> seeded() async {
    final db = await openDb();
    await db.insert(
      'profiles',
      {'id': 'owner', 'created_at': now, 'updated_at': now},
    );
    await db.insert('goals', {
      'id': 'h1',
      'user_id': 'owner',
      'title': 'Read',
      'color': '#FFFFFF',
      'start_date': '2026-01-01',
      'created_at': now,
      'updated_at': now,
    });
    return db;
  }

  CloudKitPrivateSyncService service(
    Database db,
    CloudKitBridge cloud,
    SyncEnabledStore enabled,
  ) =>
      CloudKitPrivateSyncService(
        bridge: cloud,
        keys: SyncKeyStore(_Secrets(), crypto: crypto),
        crypto: crypto,
        storeProvider: () async => SyncLocalStore(db),
        ownerProvider: () async => 'owner',
        ownerWriter: (_) async {},
        enabledStore: enabled,
      );

  test('registers the subscription once, not on every sync', () async {
    // CloudKit subscriptions outlive app reinstalls, so re-registering is the
    // common case — but hammering it on every sync is wasted round-trips.
    final db = await seeded();
    final cloud = FakeCloudKitBridge();
    final enabled = _Enabled();
    final svc = service(db, cloud, enabled);

    await svc.enable();
    await svc.syncNow();
    await svc.syncNow();

    expect(cloud.ensureSubscriptionCalls, 1);
    await db.close();
  });

  test('a device that cannot subscribe still syncs', () async {
    // The property that makes push safe to ship untested: no entitlement, no
    // network, no CloudKit — sync degrades to exactly its pre-push behaviour.
    final db = await seeded();
    final cloud = _UnsubscribableBridge();
    final svc = service(db, cloud, _Enabled());

    final st = await svc.enable();

    expect(st.isEnabled, isTrue, reason: 'enable must not fail over push');
    expect(cloud.records.containsKey('goals:h1'), isTrue,
        reason: 'data still reached CloudKit');
    await db.close();
  });

  test('a failed registration is retried on a later sync', () async {
    // Process-scoped, not permanent: a transient failure should not write the
    // device off until the next launch.
    final db = await seeded();
    final cloud = _UnsubscribableBridge();
    final svc = service(db, cloud, _Enabled());

    await svc.enable(); // attempt 1 — fails
    await svc.syncNow(); // attempt 2 — the retry

    expect(cloud.attempts, greaterThan(1),
        reason: 'a transient failure must not write the device off until the '
            'next app launch');
    await db.close();
  });

  test('push adds no second sync path — the poll alone still converges',
      () async {
    // Push only changes WHEN sync runs. A device that never receives one must
    // reach the same state, or push would be load-bearing rather than an
    // optimisation.
    final cloud = FakeCloudKitBridge();
    final key = crypto.generateKey();

    final dbA = await seeded();
    await SyncLocalStore(dbA).markAllDirty();
    await SyncEngine(store: SyncLocalStore(dbA), bridge: cloud, crypto: crypto)
        .syncNow(key);

    final dbB = await openDb();
    // No push is ever delivered to B; it only ever polls.
    await SyncEngine(store: SyncLocalStore(dbB), bridge: cloud, crypto: crypto)
        .syncNow(key);

    expect((await dbB.query('goals')).length, 1);
    await dbA.close();
    await dbB.close();
  });
}
