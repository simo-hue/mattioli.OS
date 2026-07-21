// The dual-write store both apps share. Its job is to make the two clients
// behave identically during the one release where settings have two sources of
// truth (per-key rows and the legacy profiles columns), because macOS ships
// directly while iOS goes through review and they cannot land together.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const now = '2026-07-21T00:00:00.000Z';
  const owner = 'owner-1';

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
      {'id': owner, 'created_at': now, 'updated_at': now},
    );
    return db;
  }

  test('a write lands in BOTH stores', () async {
    final db = await seeded();
    final store = SyncedSettingsStore(db);

    await store.write(owner, 'accent_color', '#FF9500');

    final row = await db.query('user_settings',
        where: 'user_id = ? AND key = ?', whereArgs: [owner, 'accent_color']);
    expect(row.single['value'], '#FF9500');
    final profile =
        await db.query('profiles', where: 'id = ?', whereArgs: [owner]);
    expect(profile.single['accent_color'], '#FF9500',
        reason: 'a device still reading columns must see the change');
    await db.close();
  });

  test('the per-key row wins over the legacy column', () async {
    final db = await seeded();
    final store = SyncedSettingsStore(db);

    // Simulate a v5 device having written the column directly...
    await db.update('profiles', {'language': 'it'},
        where: 'id = ?', whereArgs: [owner]);
    // ...and this v6 device holding a different value as a row.
    await store.write(owner, 'language', 'en');
    await db.update('profiles', {'language': 'it'},
        where: 'id = ?', whereArgs: [owner]);

    expect(await store.read(owner, 'language'), 'en',
        reason: 'a stale column must never override an explicit row');
    await db.close();
  });

  test('a cleared setting is NOT resurrected by the legacy column', () async {
    // The reason row-beats-column is one-directional. If the column won when it
    // looked newer, a setting the user deliberately turned off would come back.
    final db = await seeded();
    final store = SyncedSettingsStore(db);

    await store.write(owner, 'pref_focus_mode', SyncedSettingsStore.encodeBool(true));
    await store.write(owner, 'pref_focus_mode', null); // user clears it
    await db.update('profiles', {'pref_focus_mode': 1},
        where: 'id = ?', whereArgs: [owner]);

    final all = await store.readAll(owner);
    expect(all.containsKey('pref_focus_mode'), isTrue);
    expect(all['pref_focus_mode'], isNull, reason: 'stays cleared');
    await db.close();
  });

  test('a v5 device\'s column edit is visible until a row exists', () async {
    // The other half of the compatibility story: an edit made on the
    // not-yet-updated device must still reach this one.
    final db = await seeded();
    final store = SyncedSettingsStore(db);

    await db.update('profiles', {'theme_mode': 'light'},
        where: 'id = ?', whereArgs: [owner]);

    expect(await store.read(owner, 'theme_mode'), 'light');
    await db.close();
  });

  test('unset keys are omitted so callers can apply their own default',
      () async {
    final db = await seeded();
    final all = await SyncedSettingsStore(db).readAll(owner);
    // tutorial_completed has NO legacy profiles column, so it is genuinely
    // absent until written. Most other keys DO have a NOT NULL column with a
    // default, so they always read as set — which is correct.
    expect(all.containsKey('tutorial_completed'), isFalse);
    expect(all['accent_color'], isNotNull,
        reason: 'a column with a default IS a value, not an absence');
    await db.close();
  });

  test('both devices derive the SAME row id, so they converge without a merge',
      () async {
    // Deterministic ids mean one CloudKit record per setting; the natural key is
    // only a safety net for rows minted by some other convention.
    expect(SyncedSettingsStore.rowId('u', 'language'), 'u:language');
    final db = await seeded();
    await SyncedSettingsStore(db).write(owner, 'language', 'it');
    final row = await db.query('user_settings',
        where: 'user_id = ? AND key = ?', whereArgs: [owner, 'language']);
    expect(row.single['id'], SyncedSettingsStore.rowId(owner, 'language'));
    await db.close();
  });

  test('writing an unregistered key throws rather than failing silently',
      () async {
    // A key not in the shared list would create a row no other client reads —
    // a setting that looks like it works until you check the other device.
    final db = await seeded();
    expect(
      () => SyncedSettingsStore(db).write(owner, 'not_a_real_setting', 'x'),
      throwsArgumentError,
    );
    await db.close();
  });

  test('writes mark each key dirty independently', () async {
    final db = await seeded();
    final store = SyncedSettingsStore(db);
    final sync = SyncLocalStore(db);

    await store.writeAll(owner, {'language': 'en', 'theme_mode': 'dark'});
    // markSynced only clears a record still carrying the stamp the push saw, so
    // acknowledge each entry with its ACTUAL sync_state.updated_at.
    for (final e in await sync.dirtyEntries()) {
      await sync.markSynced(e.recordName, now, e.updatedAt);
    }
    await store.write(owner, 'language', 'it');

    final d = await sync.diagnostics();
    expect(d.pendingByTable['user_settings'], 1,
        reason: 'only the edited key needs pushing — this is the whole point');
    await db.close();
  });

  test('bool encoding round-trips and matches the legacy column form', () async {
    expect(SyncedSettingsStore.encodeBool(true), '1');
    expect(SyncedSettingsStore.decodeBool('1'), isTrue);
    expect(SyncedSettingsStore.decodeBool('0'), isFalse);
    expect(SyncedSettingsStore.decodeBool(null), isNull);
    // Tolerate the other spelling on read so a value written by any older path
    // is not misread as false.
    expect(SyncedSettingsStore.decodeBool('true'), isTrue);
  });
}
