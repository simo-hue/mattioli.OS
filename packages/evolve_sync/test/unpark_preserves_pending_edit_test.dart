// C1, as actually diagnosed — silent loss of an unpushed local edit.
//
// The original C1 claim (quarantineRecord's ON CONFLICT updates only
// last_error) is NOT a defect: that clause is specified verbatim in the method's
// own doc comment, and forcing `dirty = 0` there would drop a pending local
// write out of the push queue entirely. The conflict branch is right.
//
// The bug is in its counterpart. `clearUndecryptableParks` and
// `clearUnknownTableParks` rewind `updated_at` to the epoch for EVERY row
// carrying the reason, with no `dirty` filter. Because the conflict branch
// deliberately preserves `dirty`, a row can be both parked AND queued for push
// — a record quarantined during a key split that the user then edits, which the
// dirty trigger re-stamps without clearing `last_error`.
//
// Epoch-stamping such a row destroys it in both directions:
//   * PULL — `_applyRemote` compares `rec.updatedAtMs <= localMs`; with localMs
//     forced to 0, ANY remote copy, including one older than the user's edit,
//     wins last-write-wins and `applyUpsert` overwrites the row and clears
//     dirty. The edit is gone and nothing retries it.
//   * PUSH — a pending DELETE is sent as a tombstone stamped from
//     `sync_state.updated_at`, so it goes out dated 1970 and loses LWW on every
//     other device, while `markSynced` clears dirty locally and the sync reports
//     success. The user's deletion silently never propagates.
//
// The rewind exists so a re-delivered record beats the parked placeholder. For
// an INSERT-branch park the row is ALREADY at `quarantineStamp`, so the rewind
// changes nothing there. The only rows whose value it actually changes are the
// dirty ones — the ones it corrupts.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  String t(int hour) =>
      DateTime.utc(2020, 1, 1).add(Duration(hours: hour)).toIso8601String();

  Future<Database> seeded() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: PrivateDbSchema.version,
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: PrivateDbSchema.onCreate,
        onUpgrade: PrivateDbSchema.onUpgrade,
      ),
    );
    await db.insert(
        'profiles', {'id': 'owner', 'created_at': t(1), 'updated_at': t(1)});
    return db;
  }

  Future<void> insertHabit(Database db, String id, {required String at}) =>
      db.insert('goals', {
        'id': id,
        'user_id': 'owner',
        'title': 'edited during the split',
        'color': '#FFFFFF',
        'start_date': at,
        'created_at': at,
        'updated_at': at,
      });

  group('un-parking must not rewind a record with an unpushed local write', () {
    test('an undecryptable park keeps a pending edit at its real version',
        () async {
      final db = await seeded();
      final store = SyncLocalStore(db);
      await insertHabit(db, 'g1', at: t(10));
      final stampBefore = (await store.stateOf('goals:g1'))!.updatedAt;

      // A remote copy sealed under a rival key arrives for a record this device
      // ALREADY tracks — quarantineRecord takes its ON CONFLICT branch.
      await store.quarantineRecord(
        'goals:g1',
        'goals',
        'g1',
        SyncLocalStore.undecryptableReason,
      );
      expect((await store.stateOf('goals:g1'))!.updatedAt, stampBefore,
          reason: 'sanity: the conflict branch, not the INSERT branch');

      // The user repairs the key; the engine un-parks and forces a re-fetch.
      final unparked = await store.clearUndecryptableParks();

      expect((await store.stateOf('goals:g1'))!.updatedAt, stampBefore,
          reason: 'epoch-stamping a row with a queued local write makes every '
              'stale remote copy beat it on LWW, and makes its tombstone lose '
              'LWW on every other device');
      expect(unparked, 1,
          reason: 'the engine drops the change token on a non-zero count — a '
              'dirty parked record still needs its newer remote copy '
              're-delivered');
      final d = await store.diagnostics();
      expect(d.totalStuck, 0,
          reason: 'last_error must still be cleared, or both apps would keep '
              'reporting the record as stuck forever');
      await db.close();
    });

    test('an unknown-table park keeps a pending edit at its real version',
        () async {
      final db = await seeded();
      final store = SyncLocalStore(db);
      await insertHabit(db, 'g2', at: t(11));
      final stampBefore = (await store.stateOf('goals:g2'))!.updatedAt;

      await store.quarantineRecord(
        'goals:g2',
        'goals',
        'g2',
        SyncLocalStore.unknownTableReason,
      );
      await store.clearUnknownTableParks();

      expect((await store.stateOf('goals:g2'))!.updatedAt, stampBefore);
      await db.close();
    });

    test('a park with NO pending local write is still rewound to the epoch',
        () async {
      // The whole point of the rewind: a record this device has never held must
      // lose LWW to the copy that is about to be re-delivered. The fix must not
      // break this.
      final db = await seeded();
      final store = SyncLocalStore(db);
      await store.quarantineRecord(
        'goals:never-seen',
        'goals',
        'never-seen',
        SyncLocalStore.undecryptableReason,
      );

      await store.clearUndecryptableParks();

      expect((await store.stateOf('goals:never-seen'))!.updatedAt,
          SyncLocalStore.quarantineStamp,
          reason: 'a re-delivered copy must beat this placeholder');
      await db.close();
    });
  });

  // Locks in the behaviour the ORIGINAL C1 claim wanted changed. Forcing
  // dirty = 0 / deleted = 0 in the ON CONFLICT clause would drop the user's
  // pending write out of the push queue while the UI still showed it as saved.
  test('quarantining a record with a pending local edit keeps it queued', () async {
    final db = await seeded();
    final store = SyncLocalStore(db);
    await insertHabit(db, 'g3', at: t(12));

    await store.quarantineRecord(
      'goals:g3',
      'goals',
      'g3',
      SyncLocalStore.undecryptableReason,
    );

    expect(
      (await store.dirtyEntries()).map((e) => e.recordName),
      contains('goals:g3'),
      reason: 'the local edit must still reach the cloud',
    );
    await db.close();
  });
}
