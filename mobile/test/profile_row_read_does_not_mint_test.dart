// Reading the profile must never MINT an identity.
//
// `loadProfileRow()` used to seed a `profiles` + `goal_category_settings` pair
// whenever the current owner id had no row — from a READ, on ~8 paths (settings
// load, the avatar widget, the profile screen).
//
// `_open()` already names that hazard: it reconciles the owner id BEFORE
// seeding precisely because "a stale owner id gets a full identity minted for
// it ... that is how a user ended up with 3 profiles". A read that seeds puts
// the hazard back, and it is reachable: `SyncEngine.enable` adopts the
// canonical owner id (Keychain + the singleton's cached `_ownerId`) BEFORE
// `reKeyOwner` moves the rows, so if the re-key fails — SQLITE_BUSY from the
// notification isolate, an app kill — `ownerId()` returns the canonical id for
// the rest of the session while every row still carries the old one.
//
// The minted `goal_category_settings.user_id` is UNIQUE, so every later
// `reKeyOwner` then dies on that constraint: iCloud sync wedged for good.
//
// `PrivateLocalDatabase` opens through SQLCipher, whose native plugin does not
// exist in the Flutter test VM, so the read is exercised through
// `readProfileRow` against the REAL schema on a plain sqflite-ffi database —
// the same split (and the same reason) as `readExistingHabitLog`.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const owner = 'owner-with-rows';
  const stranger = 'owner-with-no-rows';
  const now = '2026-06-01T00:00:00.000Z';

  Future<Database> openDb() async {
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
    await db.insert('profiles', {
      'id': owner,
      'full_name': 'Simone',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('goal_category_settings', {
      'id': 'gcs-1',
      'user_id': owner,
      'mappings': '{}',
      'created_at': now,
      'updated_at': now,
    });
    return db;
  }

  test('reading the profile of an owner that has none mints nothing', () async {
    final db = await openDb();

    final row = await readProfileRow(db, stranger);

    expect(row, isEmpty,
        reason: 'no row exists for that owner — every caller already tolerates '
            'missing keys');
    expect((await db.query('profiles')).map((r) => r['id']), [owner],
        reason: 'a READ must not create a second identity');
    expect(
      (await db.query('goal_category_settings')).map((r) => r['user_id']),
      [owner],
      reason: 'goal_category_settings.user_id is UNIQUE — a minted shell here '
          'makes every later reKeyOwner fail on the constraint, forever',
    );
    await db.close();
  });

  test('reading the profile of the real owner still returns it', () async {
    final db = await openDb();

    expect((await readProfileRow(db, owner))['full_name'], 'Simone');

    await db.close();
  });
}
