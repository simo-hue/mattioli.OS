// A1, second instance — a pull failure that reports success.
//
// Found while verifying A1, not on the original defect list.
//
// `SyncLocalStore.markError` is a bare `UPDATE ... WHERE record_name = ?`. The
// PUSH path may use it safely: every record it names came out of
// `dirtyEntries()`, so the row provably exists. The PULL path may not. A record
// arriving from another device that this build has never seen has NO
// `sync_state` row — `stateOf()` returned null moments earlier — so the UPDATE
// matches zero rows and the error is silently discarded.
//
// The consequence is the worst shape this codebase produces: `_pull` sets
// `holdToken` for that record and rewinds the change token, so the device
// re-downloads the entire delta on every single sync, forever, and never
// converges — while `SyncDiagnostics.isFullySynced` returns true and the
// details row in both apps reads "Everything uploaded". There is no error
// string to read out, nothing to paste into a bug report, and no per-table
// count that moves.
//
// These tests assert the OBSERVABLE contract: a record the pull could not
// apply must be visible in diagnostics, and must be distinguishable from one
// that is parked forever — the two need opposite advice.
import 'dart:typed_data';

import 'package:evolve_sync/evolve_sync.dart';
import 'package:evolve_sync/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final crypto = SyncCrypto();
  final key = crypto.generateKey();

  String t(int hour) =>
      DateTime.utc(2020, 1, 1).add(Duration(hours: hour)).toIso8601String();

  Future<Database> openFresh() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: PrivateDbSchema.version,
          singleInstance: false,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: PrivateDbSchema.onCreate,
          onUpgrade: PrivateDbSchema.onUpgrade,
        ),
      );

  Future<Database> seeded() async {
    final db = await openFresh();
    await db.insert(
        'profiles', {'id': 'owner', 'created_at': t(1), 'updated_at': t(1)});
    await db.update(PrivateDbSchema.syncStateTable, {'dirty': 0});
    return db;
  }

  /// An avatar record with no CKAsset: `_applyRemoteAvatar` throws
  /// `StateError('avatar record without an asset')`, which is a genuine,
  /// potentially-transient apply FAILURE (the real-world cause is a CKAsset
  /// CloudKit has not materialised yet), so the token is held.
  Future<void> putUnapplyableAvatar(FakeCloudKitBridge cloud) =>
      cloud.saveRecords([
        CloudRecord(
          recordName: PrivateDbSchema.avatarRecordName('owner'),
          tableName: PrivateDbSchema.avatarRecordTable,
          updatedAtMs: DateTime.utc(2024).millisecondsSinceEpoch,
          deleted: false,
          payload: Uint8List(0),
        ),
      ]);

  test('a record the pull could not apply is NOT reported as fully synced',
      () async {
    final db = await seeded();
    final cloud = FakeCloudKitBridge();
    await putUnapplyableAvatar(cloud);
    final store = SyncLocalStore(db);

    await SyncEngine(
      store: store,
      bridge: cloud,
      crypto: crypto,
      avatarStore: FakeSyncAvatarStore(name: 'B'),
    ).syncNow(key);

    final d = await store.diagnostics();
    expect(d.isFullySynced, isFalse,
        reason: 'the change token was rewound for this record — the device '
            'will re-download the whole delta on every sync until it applies');
    expect(d.totalStuck, 1);
    await db.close();
  });

  test('the failure reason reaches the copyable report', () async {
    final db = await seeded();
    final cloud = FakeCloudKitBridge();
    await putUnapplyableAvatar(cloud);
    final store = SyncLocalStore(db);

    await SyncEngine(
      store: store,
      bridge: cloud,
      crypto: crypto,
      avatarStore: FakeSyncAvatarStore(name: 'B'),
    ).syncNow(key);

    final report = (await store.diagnostics()).toReport();
    expect(report, contains('avatar record without an asset'),
        reason: 'this string is the only thing a user can read out or paste');
    await db.close();
  });

  test(
      'a pull failure is counted apart from a quarantined record — one is '
      'being retried, the other never will be', () async {
    final db = await seeded();
    final cloud = FakeCloudKitBridge();
    await putUnapplyableAvatar(cloud);
    // ...plus a record for a table this build has no schema for, which is
    // quarantined and whose token DOES advance.
    await cloud.saveRecords([
      CloudRecord(
        recordName: 'future_table:x1',
        tableName: 'future_table',
        updatedAtMs: DateTime.utc(2024).millisecondsSinceEpoch,
        deleted: false,
        payload: crypto.encryptJson({'id': 'x1'}, key),
      ),
    ]);
    final store = SyncLocalStore(db);

    await SyncEngine(
      store: store,
      bridge: cloud,
      crypto: crypto,
      avatarStore: FakeSyncAvatarStore(name: 'B'),
    ).syncNow(key);

    final d = await store.diagnostics();
    expect(d.totalHeld, 1, reason: 'the avatar — re-delivered on the next sync');
    expect(d.totalParked, 1,
        reason: 'the unknown table — only a full re-fetch revives it');
    await db.close();
  });

  test('a pull failure that later succeeds stops being reported', () async {
    final db = await seeded();
    final cloud = FakeCloudKitBridge();
    final transport = <String, Uint8List>{};
    final avatars = FakeSyncAvatarStore(name: 'B', assetTransport: transport);
    await putUnapplyableAvatar(cloud);
    final store = SyncLocalStore(db);

    final engine = SyncEngine(
      store: store,
      bridge: cloud,
      crypto: crypto,
      avatarStore: avatars,
    );
    await engine.syncNow(key);
    expect((await store.diagnostics()).totalHeld, 1);

    // The asset materialises: the held token re-delivers the record and it
    // applies. The error must clear, not linger as a permanent scare.
    transport['staged:A:1'] = crypto.encryptBytes(
      Uint8List.fromList([1, 2, 3]),
      key,
    );
    await cloud.saveRecords([
      CloudRecord(
        recordName: PrivateDbSchema.avatarRecordName('owner'),
        tableName: PrivateDbSchema.avatarRecordTable,
        updatedAtMs: DateTime.utc(2024, 2).millisecondsSinceEpoch,
        deleted: false,
        payload: Uint8List(0),
        assetPath: 'staged:A:1',
      ),
    ]);
    await engine.syncNow(key);

    final d = await store.diagnostics();
    expect(d.totalHeld, 0);
    expect(d.isFullySynced, isTrue);
    await db.close();
  });

  test('a clean sync reports nothing stuck', () async {
    final db = await seeded();
    final cloud = FakeCloudKitBridge();
    final store = SyncLocalStore(db);

    await SyncEngine(store: store, bridge: cloud, crypto: crypto).syncNow(key);

    final d = await store.diagnostics();
    expect(d.totalStuck, 0);
    expect(d.isFullySynced, isTrue);
    await db.close();
  });
}
