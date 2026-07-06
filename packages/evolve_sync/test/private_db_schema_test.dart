// Schema + migration tests for the Private-Mode local database (iCloud sync
// Step 1). Runs PrivateDbSchema against an in-memory FFI SQLite — encryption
// (SQLCipher) is orthogonal to schema correctness, so these open unencrypted.
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> openFreshV3() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: PrivateDbSchema.version,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: PrivateDbSchema.onCreate,
          onUpgrade: PrivateDbSchema.onUpgrade,
        ),
      );

  Future<Set<String>> tableNames(Database db) async => (await db.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'table'",
      )).map((r) => r['name'] as String).toSet();

  Future<Set<String>> columnNames(Database db, String table) async =>
      (await db.rawQuery('PRAGMA table_info($table)'))
          .map((r) => r['name'] as String)
          .toSet();

  const now = '2026-06-23T00:00:00.000Z';

  Future<void> seedProfile(Database db, String id) =>
      db.insert('profiles', {'id': id, 'created_at': now, 'updated_at': now});

  group('fresh v3 schema', () {
    test('creates all core + sync tables, meta singleton, categories.updated_at',
        () async {
      final db = await openFreshV3();
      final tables = await tableNames(db);
      expect(
        tables,
        containsAll(<String>{
          ...PrivateDbSchema.syncedTables,
          PrivateDbSchema.syncStateTable,
          PrivateDbSchema.syncMetaTable,
        }),
      );
      // sync_meta has exactly the single enforced row.
      expect((await db.query(PrivateDbSchema.syncMetaTable)).length, 1);
      // macro_goal_categories gained updated_at.
      expect(await columnNames(db, 'macro_goal_categories'), contains('updated_at'));
      await db.close();
    });

    test('insert/update/delete on a synced table maintains sync_state', () async {
      final db = await openFreshV3();
      await seedProfile(db, 'owner1');
      await db.insert('goals', {
        'id': 'g1',
        'user_id': 'owner1',
        'title': 'Read',
        'color': '#FFFFFF',
        'start_date': now,
        'created_at': now,
        'updated_at': now,
      });

      var s = await db.query('sync_state',
          where: 'record_name = ?', whereArgs: ['goals:g1']);
      expect(s, hasLength(1));
      expect(s.first['table_name'], 'goals');
      expect(s.first['row_id'], 'g1');
      expect(s.first['dirty'], 1);
      expect(s.first['deleted'], 0);
      expect(s.first['updated_at'], now);

      // Simulate the engine clearing dirty after a successful push...
      await db.update('sync_state', {'dirty': 0},
          where: 'record_name = ?', whereArgs: ['goals:g1']);
      // ...then a local edit must re-mark it dirty with the new updated_at.
      const now2 = '2026-06-24T00:00:00.000Z';
      await db.update('goals', {'title': 'Read more', 'updated_at': now2},
          where: 'id = ?', whereArgs: ['g1']);
      s = await db.query('sync_state',
          where: 'record_name = ?', whereArgs: ['goals:g1']);
      expect(s.first['dirty'], 1);
      expect(s.first['deleted'], 0);
      expect(s.first['updated_at'], now2);

      // Delete writes a tombstone (dirty + deleted), surviving the row.
      await db.delete('goals', where: 'id = ?', whereArgs: ['g1']);
      expect(await db.query('goals', where: 'id = ?', whereArgs: ['g1']), isEmpty);
      s = await db.query('sync_state',
          where: 'record_name = ?', whereArgs: ['goals:g1']);
      expect(s, hasLength(1));
      expect(s.first['dirty'], 1);
      expect(s.first['deleted'], 1);
      await db.close();
    });

    // Mirrors PrivateLocalDatabase.deleteAllPrivateData's sync-bookkeeping
    // reset (#6/#7). The class itself needs SQLCipher + path_provider (a
    // device), so this locks the SQL contract it relies on: a full local wipe
    // clears sync_state + the delta token, but MUST preserve pending_zone_wipe
    // so the queued cloud-zone wipe still runs on the next sync.
    test('#6/#7 full wipe clears sync_state + token but keeps pending_zone_wipe',
        () async {
      final db = await openFreshV3();
      await seedProfile(db, 'owner');
      await db.insert('goals', {
        'id': 'g1',
        'user_id': 'owner',
        'title': 'Read',
        'color': '#FFFFFF',
        'start_date': now,
        'created_at': now,
        'updated_at': now,
      });
      // requestFullReset (runs first) queued the cloud wipe + left a stale token.
      await db.update(
        PrivateDbSchema.syncMetaTable,
        {
          'server_change_token': 'tok-123',
          'last_full_sync_at': now,
          'pending_zone_wipe': 1,
        },
        where: 'id = 1',
      );

      // --- the exact statements deleteAllPrivateData runs ---
      await db.delete('goals'); // fires the tombstone trigger
      await db.delete('profiles');
      await seedProfile(db, 'owner'); // _ensureProfile re-queues a profile row
      // sanity: at this point sync_state is non-empty (tombstones + new profile)
      expect(await db.query(PrivateDbSchema.syncStateTable), isNotEmpty);
      await db.delete(PrivateDbSchema.syncStateTable);
      await db.update(
        PrivateDbSchema.syncMetaTable,
        {'server_change_token': null, 'last_full_sync_at': null},
        where: 'id = 1',
      );
      // ------------------------------------------------------

      expect(await db.query(PrivateDbSchema.syncStateTable), isEmpty);
      final meta =
          (await db.query(PrivateDbSchema.syncMetaTable, where: 'id = 1')).first;
      expect(meta['server_change_token'], isNull);
      expect(meta['last_full_sync_at'], isNull);
      expect(meta['pending_zone_wipe'], 1, reason: 'queued cloud wipe preserved');
      await db.close();
    });

    test('category insert without updated_at is COALESCEd in sync_state',
        () async {
      final db = await openFreshV3();
      await seedProfile(db, 'o');
      // updated_at column is nullable post-migration; omit it.
      await db.insert('macro_goal_categories', {
        'id': 'c1',
        'user_id': 'o',
        'name': 'Health',
        'color': '#FFFFFF',
        'created_at': now,
      });
      final s = await db.query('sync_state',
          where: 'record_name = ?', whereArgs: ['macro_goal_categories:c1']);
      expect(s, hasLength(1));
      // sync_state.updated_at is NOT NULL — the trigger's COALESCE filled it.
      expect(s.first['updated_at'], isNotNull);
      expect((s.first['updated_at'] as String), isNotEmpty);
      await db.close();
    });
  });

  group('v2 -> v3 migration', () {
    test('adds categories.updated_at (backfilled) + sync objects + triggers',
        () async {
      // Minimal v2-shaped fixture: the 7 core tables, categories WITHOUT
      // updated_at, no sync objects. Each non-category table carries id +
      // updated_at so the v3 triggers can compile against them.
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            for (final t in const [
              'profiles',
              'goals',
              'goal_logs',
              'long_term_goals',
              'daily_moods',
              'goal_category_settings',
            ]) {
              await db.execute(
                  'CREATE TABLE $t (id TEXT PRIMARY KEY, updated_at TEXT)');
            }
            await db.execute(
                'CREATE TABLE macro_goal_categories (id TEXT PRIMARY KEY, created_at TEXT)');
          },
        ),
      );
      // A legacy category row, pre-updated_at.
      await db.insert('macro_goal_categories',
          {'id': 'c1', 'created_at': '2026-01-01T00:00:00.000Z'});

      // Run the real migration path (oldVersion 2 -> only _upgradeToV3 runs).
      await PrivateDbSchema.onUpgrade(db, 2, PrivateDbSchema.version);

      // updated_at added and backfilled from created_at.
      expect(await columnNames(db, 'macro_goal_categories'), contains('updated_at'));
      final cat = (await db.query('macro_goal_categories',
              where: 'id = ?', whereArgs: ['c1']))
          .first;
      expect(cat['updated_at'], '2026-01-01T00:00:00.000Z');

      // Sync objects created.
      final tables = await tableNames(db);
      expect(tables, containsAll(<String>{
        PrivateDbSchema.syncStateTable,
        PrivateDbSchema.syncMetaTable,
      }));
      expect((await db.query(PrivateDbSchema.syncMetaTable)).length, 1);

      // Triggers are live after migration.
      await db.insert('goals', {'id': 'g1', 'updated_at': now});
      final s = await db.query('sync_state',
          where: 'record_name = ?', whereArgs: ['goals:g1']);
      expect(s, hasLength(1));
      expect(s.first['dirty'], 1);
      await db.close();
    });
  });
}
