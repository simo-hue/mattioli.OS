// F50 — the private export read its settings from the LEGACY `profiles`
// columns, which are not authoritative.
//
// Settings are dual-written to the per-key `user_settings` row AND the legacy
// column, and [SyncedSettingsStore.readAll] resolves them row-first on purpose
// ("a row always wins, even if the column looks newer"). An unrelated profile
// write can leave the column holding a value the row has already superseded, so
// the export carried a setting the app itself does not use — and a REPLACE
// restore then wrote that stale value back over BOTH stores (via
// _restoreSyncedSettingRows) and pushed it to the user's other devices.
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const owner = 'owner-1';
  final now = DateTime.utc(2026, 1, 1).toIso8601String();

  Future<Database> seeded() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: PrivateDbSchema.version,
        singleInstance: false,
        onConfigure: PrivateDbSchema.onConfigure,
        onCreate: PrivateDbSchema.onCreate,
        onUpgrade: PrivateDbSchema.onUpgrade,
      ),
    );
    await DesktopPrivateDb.seedProfile(db, owner: owner, now: now);
    return db;
  }

  test('the export carries the authoritative user_settings values', () async {
    final db = await seeded();
    addTearDown(db.close);

    // The stale legacy half: a later unrelated profile write left the column
    // behind while the row moved on.
    await db.update(
      'profiles',
      {'theme_mode': 'dark', 'notif_habit_reminders': 1},
      where: 'id = ?',
      whereArgs: [owner],
    );
    // The authoritative half — what loadSettingsRow(), and therefore the app,
    // actually reads.
    await SyncedSettingsStore(db).writeAll(owner, {
      'theme_mode': 'light',
      'notif_habit_reminders': SyncedSettingsStore.encodeBool(false),
    });
    await db.update(
      'profiles',
      {'theme_mode': 'dark', 'notif_habit_reminders': 1},
      where: 'id = ?',
      whereArgs: [owner],
    );

    final payload = await DesktopPrivateDb.exportSnapshot(db, owner: owner);
    final settings = payload['settings'] as Map;
    final profile = payload['profile'] as Map;

    expect(settings['theme_mode'], 'light',
        reason: 'a REPLACE restore of this file writes the exported value back '
            'over the authoritative row and pushes it to the iPhone');
    expect(profile['theme_mode'], 'light');
    // The INTEGER prefs keep the column's storage class, so the file looks
    // exactly like the row it came from.
    expect(profile['notif_habit_reminders'], 0);
    expect(settings['notif_habit_reminders'], 0);
  });

  test('a setting only the legacy column holds still travels', () async {
    final db = await seeded();
    addTearDown(db.close);
    await db.update(
      'profiles',
      {'accent_color': '#FF0000'},
      where: 'id = ?',
      whereArgs: [owner],
    );

    final payload = await DesktopPrivateDb.exportSnapshot(db, owner: owner);
    expect((payload['settings'] as Map)['accent_color'], '#FF0000');
  });
}
