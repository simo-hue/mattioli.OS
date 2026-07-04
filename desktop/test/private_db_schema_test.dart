// WS1 — Private-Mode DB foundation.
//
// Exercises the aligned schema ([PrivateDbSchema], ported from mobile) and the
// static lifecycle helpers on [DesktopPrivateDb] against an in-memory
// `sqflite_common_ffi` database — no SQLCipher / Keychain / path_provider
// needed. Guards the WS1 bug fixes: B1 (profile bootstrap + FKs on), B2 (import
// under the real owner), B3 (`goal_logs.value` column), and the delete flow.
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/private_db_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // singleInstance:false → each call is an independent in-memory DB.
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

  const owner = 'owner-uuid';
  const now = '2026-07-04T10:00:00.000Z';

  Future<Set<String>> tableNames(Database db) async {
    final rows = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ?',
      whereArgs: ['table'],
    );
    return rows.map((r) => r['name'] as String).toSet();
  }

  group('schema bootstrap', () {
    test('creates all core + sync tables at version 3', () async {
      final db = await openFresh();
      addTearDown(db.close);

      expect(PrivateDbSchema.version, 3);
      final names = await tableNames(db);
      expect(
        names,
        containsAll(<String>{
          'profiles',
          'goals',
          'goal_logs',
          'long_term_goals',
          'daily_moods',
          'goal_category_settings',
          'macro_goal_categories',
          'sync_state',
          'sync_meta',
        }),
      );
      // sync_meta is seeded with its singleton row.
      final meta = await db.query('sync_meta');
      expect(meta, hasLength(1));
    });

    test('goal_logs has the value column (B3)', () async {
      final db = await openFresh();
      addTearDown(db.close);
      final cols = await db.rawQuery('PRAGMA table_info(goal_logs)');
      expect(cols.map((c) => c['name']), contains('value'));
    });

    test('seedProfile is idempotent and creates the owner row (B1)', () async {
      final db = await openFresh();
      addTearDown(db.close);

      await DesktopPrivateDb.seedProfile(db, owner: owner, now: now);
      await DesktopPrivateDb.seedProfile(db, owner: owner, now: now);

      final profiles = await db.query('profiles');
      expect(profiles, hasLength(1));
      expect(profiles.first['id'], owner);
      // Defaults from the aligned schema.
      expect(profiles.first['is_pro'], 1);
      expect(profiles.first['private_ai_external_consent'], 0);
    });
  });

  group('foreign keys (B1: PRAGMA foreign_keys = ON)', () {
    test('inserting a goal without a parent profile fails', () async {
      final db = await openFresh();
      addTearDown(db.close);

      expect(
        () => db.insert('goals', {
          'id': 'g1',
          'user_id': 'ghost',
          'title': 'Read',
          'color': '#fff',
          'start_date': now,
          'created_at': now,
          'updated_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('goal insert succeeds once the owner profile exists', () async {
      final db = await openFresh();
      addTearDown(db.close);
      await DesktopPrivateDb.seedProfile(db, owner: owner, now: now);

      await db.insert('goals', {
        'id': 'g1',
        'user_id': owner,
        'title': 'Read',
        'color': '#fff',
        'start_date': now,
        'created_at': now,
        'updated_at': now,
      });
      expect(await db.query('goals'), hasLength(1));
    });
  });

  group('constraints', () {
    test('mood_score CHECK rejects out-of-range values', () async {
      final db = await openFresh();
      addTearDown(db.close);
      await DesktopPrivateDb.seedProfile(db, owner: owner, now: now);

      expect(
        () => db.insert('daily_moods', {
          'id': 'm1',
          'user_id': owner,
          'date': '2026-07-04',
          'mood_score': 60, // 0..10 only
          'energy_score': 5,
          'created_at': now,
          'updated_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('goal_logs UNIQUE(goal_id, date) holds', () async {
      final db = await openFresh();
      addTearDown(db.close);
      await DesktopPrivateDb.seedProfile(db, owner: owner, now: now);
      await db.insert('goals', {
        'id': 'g1',
        'user_id': owner,
        'title': 'Read',
        'color': '#fff',
        'start_date': now,
        'created_at': now,
        'updated_at': now,
      });
      Map<String, Object?> log(String id) => {
        'id': id,
        'user_id': owner,
        'goal_id': 'g1',
        'date': '2026-07-04',
        'status': 'done',
        'created_at': now,
        'updated_at': now,
      };
      await db.insert('goal_logs', log('l1'));
      expect(
        () => db.insert('goal_logs', log('l2')),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('sync triggers (Phase-2 foundation)', () {
    test('insert marks dirty; delete writes a tombstone', () async {
      final db = await openFresh();
      addTearDown(db.close);
      await DesktopPrivateDb.seedProfile(db, owner: owner, now: now);

      await db.insert('goals', {
        'id': 'g1',
        'user_id': owner,
        'title': 'Read',
        'color': '#fff',
        'start_date': now,
        'created_at': now,
        'updated_at': now,
      });

      final afterInsert = await db.query(
        'sync_state',
        where: 'record_name = ?',
        whereArgs: ['goals:g1'],
      );
      expect(afterInsert, hasLength(1));
      expect(afterInsert.first['dirty'], 1);
      expect(afterInsert.first['deleted'], 0);

      await db.delete('goals', where: 'id = ?', whereArgs: ['g1']);
      final afterDelete = await db.query(
        'sync_state',
        where: 'record_name = ?',
        whereArgs: ['goals:g1'],
      );
      expect(afterDelete.first['dirty'], 1);
      expect(afterDelete.first['deleted'], 1); // tombstone
    });
  });

  group('applyImport (B2 owner, B3 value)', () {
    test('imports rows under the real owner, including value', () async {
      final db = await openFresh();
      addTearDown(db.close);
      await DesktopPrivateDb.seedProfile(db, owner: owner, now: now);

      await DesktopPrivateDb.applyImport(
        db,
        owner: owner,
        replaceExisting: true,
        now: now,
        backupData: {
          'macro_goal_categories': [
            {'id': 'c1', 'name': 'Salute', 'color': '#0f0'},
          ],
          'goals': [
            {'id': 'g1', 'title': 'Meditate'},
          ],
          'goal_logs': [
            {
              'id': 'l1',
              'goal_id': 'g1',
              'date': '2026-07-01',
              'status': 'done',
              'value': 3.5,
            },
          ],
          'daily_moods': [
            {
              'id': 'm1',
              'date': '2026-07-01',
              'mood_score': 7,
              'energy_score': 6,
            },
          ],
        },
      );

      final goals = await db.query('goals');
      expect(goals, hasLength(1));
      expect(goals.first['user_id'], owner); // B2: not 'local_user'
      expect(goals.first['color'], isNotNull); // NOT NULL coalesced

      final logs = await db.query('goal_logs');
      expect(logs.first['value'], 3.5); // B3: value column persisted
      expect(logs.first['user_id'], owner);

      expect(await db.query('daily_moods'), hasLength(1));
      expect(await db.query('macro_goal_categories'), hasLength(1));
    });
  });

  group('wipeUserData + reseed (delete flow)', () {
    test('clears all user data then re-seeds an empty profile', () async {
      final db = await openFresh();
      addTearDown(db.close);
      await DesktopPrivateDb.seedProfile(db, owner: owner, now: now);
      await db.insert('goals', {
        'id': 'g1',
        'user_id': owner,
        'title': 'Read',
        'color': '#fff',
        'start_date': now,
        'created_at': now,
        'updated_at': now,
      });

      await db.transaction((txn) async {
        await DesktopPrivateDb.wipeUserData(txn);
        await DesktopPrivateDb.seedProfile(txn, owner: owner, now: now);
      });

      expect(await db.query('goals'), isEmpty);
      final profiles = await db.query('profiles');
      expect(profiles, hasLength(1)); // re-seeded, app stays usable
    });
  });
}
