import 'dart:io';

import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'opening a v12 file upgrades once and preserves user data after reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'calendar-weeks-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/private.db';
      var db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 12,
          singleInstance: false,
          onConfigure: PrivateDbSchema.onConfigure,
          onCreate: (db, version) async {
            // v12 has the same tables, without the explicit Monday column.
            await PrivateDbSchema.onCreate(db, version);
            await db.execute(
              'ALTER TABLE long_term_goals DROP COLUMN week_start_date',
            );
          },
        ),
      );
      addTearDown(() async {
        if (db.isOpen) await db.close();
      });
      expect(await db.getVersion(), 12);
      var upgrades = 0;
      Future<Database> openUpdatedApp() => databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: PrivateDbSchema.version,
          singleInstance: false,
          onConfigure: PrivateDbSchema.onConfigure,
          onCreate: PrivateDbSchema.onCreate,
          onUpgrade: (db, oldVersion, newVersion) async {
            upgrades++;
            await PrivateDbSchema.onUpgrade(db, oldVersion, newVersion);
          },
          onDowngrade: PrivateDbSchema.onDowngrade,
        ),
      );
      const stamp = '2026-09-01T12:00:00Z';
      await db.insert('profiles', {
        'id': 'u',
        'created_at': stamp,
        'updated_at': stamp,
      });
      await db.insert('goals', {
        'id': 'habit',
        'user_id': 'u',
        'title': 'Read',
        'color': '#123456',
        'start_date': '2026-01-01',
        'created_at': stamp,
        'updated_at': stamp,
      });
      for (final (id, month, week, status) in [
        ('a', 8, 5, 'active'),
        ('b', 9, 1, 'completed'),
        ('c', 5, 1, 'failed'),
      ]) {
        await db.insert('long_term_goals', {
          'id': id,
          'user_id': 'u',
          'title': 'Original $id',
          'status': status,
          'type': 'weekly',
          'year': 2026,
          'month': month,
          'quarter': 1,
          'week_number': week,
          'target_amount': 10,
          'target_unit': 'count',
          'progress_amount': 7,
          'linked_goal_id': 'habit',
          'created_at': stamp,
          'updated_at': stamp,
        });
      }
      final before = await db.query('long_term_goals', orderBy: 'id');
      await db.close();
      db = await openUpdatedApp();
      expect(await db.getVersion(), PrivateDbSchema.version);
      expect(upgrades, 1);
      final after = await db.query('long_term_goals', orderBy: 'id');
      expect(after.map((r) => r['week_start_date']), [
        '2026-08-31',
        '2026-08-31',
        '2026-04-27',
      ]);
      expect(after.map((r) => r['quarter']), [3, 3, 2]);
      for (var i = 0; i < before.length; i++) {
        for (final key in [
          'id',
          'user_id',
          'title',
          'status',
          'target_amount',
          'target_unit',
          'progress_amount',
          'linked_goal_id',
          'created_at',
          'updated_at',
        ]) {
          expect(after[i][key], before[i][key], reason: key);
        }
      }
      expect((after.last['month'], after.last['week_number']), (4, 5));
      await PrivateDbSchema.onUpgrade(db, 12, PrivateDbSchema.version);
      expect(await db.query('long_term_goals', orderBy: 'id'), after);
      await db.close();
      db = await openUpdatedApp();
      expect(upgrades, 1);
      expect(await db.query('long_term_goals', orderBy: 'id'), after);
    },
  );

  test(
    'sync converts a pre-update peer and round-trips an explicit week',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(db.close);
      await PrivateDbSchema.onCreate(db, PrivateDbSchema.version);
      final store = SyncLocalStore(db);
      final row = <String, Object?>{
        'id': 'g',
        'user_id': 'u',
        'title': 'Keep me',
        'type': 'weekly',
        'status': 'completed',
        'year': 2026,
        'month': 5,
        'week_number': 1,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-09-01T00:00:00Z',
      };
      await store.applyUpsert(
        'long_term_goals',
        'long_term_goals:g',
        row,
        DateTime.utc(2026, 9).millisecondsSinceEpoch,
        '2026-09-01T00:00:00Z',
      );
      final converted = (await db.query('long_term_goals')).single;
      expect(converted['week_start_date'], '2026-04-27');
      expect(converted['status'], 'completed');
      await store.applyUpsert(
        'long_term_goals',
        'long_term_goals:g',
        {...converted, 'updated_at': '2026-09-02T00:00:00Z'},
        DateTime.utc(2026, 9, 2).millisecondsSinceEpoch,
        '2026-09-02T00:00:00Z',
      );
      expect(
        (await db.query('long_term_goals')).single['week_start_date'],
        '2026-04-27',
      );
      // A new May week one differs from a legacy May week one. An older peer
      // echoing this address during a rename must retain its explicit Monday.
      await store.applyUpsert(
        'long_term_goals',
        'long_term_goals:g',
        {
          ...row,
          'month': 5,
          'week_number': 1,
          'week_start_date': '2026-05-04',
          'updated_at': '2026-09-03T00:00:00Z',
        },
        DateTime.utc(2026, 9, 3).millisecondsSinceEpoch,
        '2026-09-03T00:00:00Z',
      );
      await store.applyUpsert(
        'long_term_goals',
        'long_term_goals:g',
        {
          ...row,
          'title': 'Renamed by older client',
          'updated_at': '2026-09-04T00:00:00Z',
        },
        DateTime.utc(2026, 9, 4).millisecondsSinceEpoch,
        '2026-09-04T00:00:00Z',
      );
      final renamed = (await db.query('long_term_goals')).single;
      expect(renamed['title'], 'Renamed by older client');
      expect(renamed['week_start_date'], '2026-05-04');
    },
  );
}
