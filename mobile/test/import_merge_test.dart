// Unit tests for the data-import normalizer + private-mode merge engine
// (lib/core/import_merge.dart). Runs the merge against an in-memory FFI SQLite
// seeded with the real PrivateDbSchema — encryption is orthogonal to the merge
// logic, so this exercises identity matching, last-write-wins, category dedup,
// orphan/FK handling and streak recomputation without SQLCipher or the network.
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/import_merge.dart';
import 'package:mattioli_os/core/import_merge_stats.dart';
import 'package:mattioli_os/core/private_db_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const owner = 'owner-1';
  const now = '2026-06-01T00:00:00.000Z';
  var idCounter = 0;
  String newId() => 'gen-${idCounter++}';

  Future<Database> openDb() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: PrivateDbSchema.version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: PrivateDbSchema.onCreate,
        onUpgrade: PrivateDbSchema.onUpgrade,
      ),
    );
    await db.insert('profiles', {
      'id': owner,
      'created_at': now,
      'updated_at': now,
    });
    return db;
  }

  Future<ImportMergeStats> merge(
    Database db,
    Map<String, dynamic> canonical, {
    bool replace = false,
  }) =>
      db.transaction<ImportMergeStats>(
        (txn) => applyPrivateImportMerge(
          txn: txn,
          owner: owner,
          canonical: canonical,
          replaceExisting: replace,
          now: now,
          newId: newId,
        ),
      );

  Map<String, dynamic> nativeGoal({
    required String id,
    String title = 'Run',
    String color = '#3B82F6',
    String start = '2026-01-01',
    String? updatedAt,
  }) => {
        'id': id,
        'title': title,
        'color': color,
        'start_date': start,
        'updated_at': ?updatedAt,
      };

  // ── Normalizer ────────────────────────────────────────────────────────────

  group('normalizeBackup', () {
    test('web shape: converts HSL→hex and maps color-slug categories', () {
      final c = normalizeBackup({
        'goals': [
          {
            'id': 'g1',
            'title': 'Run',
            'color': 'hsl(210 90% 50%)',
            'start_date': '2026-01-01',
            'frequency_days': [1, 2, 3],
            'updated_at': '2026-01-02T00:00:00.000Z',
          },
        ],
        'goal_logs': [
          {'id': 'l1', 'goal_id': 'g1', 'date': '2026-01-01', 'status': 'done'},
        ],
        'long_term_goals': [
          {
            'id': 'm1',
            'title': 'Fit',
            'status': 'active',
            'type': 'annual',
            'year': 2026,
            'color': 'health',
          },
        ],
        'goal_category_settings': {
          'mappings': {
            'health': {'label': 'Health', 'color': 'hsl(140 50% 50%)'},
          },
          'created_at': now,
        },
        'daily_moods': [
          {'id': 'd1', 'date': '2026-01-01', 'mood_score': 7, 'energy_score': 6},
        ],
      });

      expect((c[kGoalsKey] as List).single['color'], startsWith('#'));
      final cats = c[kCategoriesKey] as List;
      expect(cats.single['name'], 'Health');
      // The macro goal's color slug is resolved to the synthesized category id.
      expect((c[kMacrosKey] as List).single['category_id'], cats.single['id']);
    });

    test('native shape: passes hex + list logs through', () {
      final c = normalizeBackup({
        'mode': 'private',
        'habits': [nativeGoal(id: 'g1')],
        'habitLogs': [
          {'id': 'l1', 'goal_id': 'g1', 'date': '2026-01-01', 'status': 'done'},
        ],
        'macroGoalCategories': [
          {'id': 'c1', 'name': 'Health', 'color': '#10B981'},
        ],
        'dailyMoods': [
          {'id': 'd1', 'date': '2026-01-01', 'mood_score': 5, 'energy_score': 5},
        ],
      });
      expect((c[kGoalsKey] as List).length, 1);
      expect((c[kLogsKey] as List).single['goal_id'], 'g1');
      expect((c[kCategoriesKey] as List).single['id'], 'c1');
    });

    test('legacy native shape: expands map-of-logs into rows', () {
      final c = normalizeBackup({
        'mode': 'private',
        'habitLogs': {
          '2026-01-01': {'g1': 'done'},
          '2026-01-02': {'g1': 'missed'},
        },
        'dailyMoods': {
          '2026-01-01': {'mood_score': 5, 'energy_score': 5},
        },
      });
      expect((c[kLogsKey] as List).length, 2);
      expect((c[kMoodsKey] as List).single['date'], '2026-01-01');
    });
  });

  // ── Merge semantics ───────────────────────────────────────────────────────

  group('applyPrivateImportMerge', () {
    test('merges into empty, then re-import dedups (no duplicates)', () async {
      final db = await openDb();
      final canonical = normalizeBackup({
        'mode': 'private',
        'habits': [nativeGoal(id: 'g1', updatedAt: now)],
        'habitLogs': [
          {
            'id': 'l1',
            'goal_id': 'g1',
            'date': '2026-01-01',
            'status': 'done',
            'updated_at': now,
          },
        ],
      });

      final s1 = await merge(db, canonical);
      expect(s1.habits.added, 1);
      expect(s1.logs.added, 1);
      expect((await db.query('goals')).length, 1);

      final s2 = await merge(db, canonical);
      expect(s2.habits.added, 0);
      expect(s2.habits.unchanged, 1);
      expect(s2.logs.unchanged, 1);
      expect((await db.query('goals')).length, 1, reason: 'no duplicate goal');
      expect((await db.query('goal_logs')).length, 1, reason: 'no duplicate log');
      await db.close();
    });

    test('last-write-wins: newer import updates, older is ignored', () async {
      final db = await openDb();
      await merge(
        db,
        normalizeBackup({
          'mode': 'private',
          'habits': [
            nativeGoal(
              id: 'g1',
              title: 'Old',
              updatedAt: '2026-01-01T00:00:00.000Z',
            ),
          ],
        }),
      );

      final newer = await merge(
        db,
        normalizeBackup({
          'mode': 'private',
          'habits': [
            nativeGoal(
              id: 'g1',
              title: 'New',
              updatedAt: '2026-02-01T00:00:00.000Z',
            ),
          ],
        }),
      );
      expect(newer.habits.updated, 1);
      expect(
        (await db.query('goals', where: 'id = ?', whereArgs: ['g1'])).single['title'],
        'New',
      );

      final older = await merge(
        db,
        normalizeBackup({
          'mode': 'private',
          'habits': [
            nativeGoal(
              id: 'g1',
              title: 'Stale',
              updatedAt: '2025-01-01T00:00:00.000Z',
            ),
          ],
        }),
      );
      expect(older.habits.unchanged, 1);
      expect(
        (await db.query('goals', where: 'id = ?', whereArgs: ['g1'])).single['title'],
        'New',
        reason: 'stale import must not clobber newer data',
      );
      await db.close();
    });

    test('category identity by name dedups and remaps macro goals', () async {
      final db = await openDb();
      await merge(
        db,
        normalizeBackup({
          'mode': 'private',
          'macroGoalCategories': [
            {'id': 'c1', 'name': 'Health', 'color': '#10B981'},
          ],
        }),
      );

      final s = await merge(
        db,
        normalizeBackup({
          'mode': 'private',
          'macroGoalCategories': [
            {'id': 'c2', 'name': 'health', 'color': '#123456'},
          ],
          'macroGoals': [
            {
              'id': 'm1',
              'title': 'Fit',
              'status': 'active',
              'type': 'annual',
              'category_id': 'c2',
            },
          ],
        }),
      );

      expect(s.categories.unchanged, 1);
      expect((await db.query('macro_goal_categories')).length, 1,
          reason: 'same-name category is deduped');
      expect(
        (await db.query('long_term_goals', where: 'id = ?', whereArgs: ['m1']))
            .single['category_id'],
        'c1',
        reason: 'macro goal remapped onto the existing category id',
      );
      await db.close();
    });

    test('replace mode wipes existing data first', () async {
      final db = await openDb();
      await merge(
        db,
        normalizeBackup({
          'mode': 'private',
          'habits': [nativeGoal(id: 'g1', updatedAt: now)],
        }),
      );
      final s = await merge(
        db,
        normalizeBackup({
          'mode': 'private',
          'habits': [nativeGoal(id: 'g2', updatedAt: now)],
        }),
        replace: true,
      );
      expect(s.replaced, isTrue);
      final goals = await db.query('goals');
      expect(goals.length, 1);
      expect(goals.single['id'], 'g2');
      await db.close();
    });

    test('recomputes streaks across the merged log history', () async {
      final db = await openDb();
      await merge(
        db,
        normalizeBackup({
          'mode': 'private',
          'habits': [nativeGoal(id: 'g1', start: '2026-01-01', updatedAt: now)],
          'habitLogs': [
            {'id': 'l1', 'goal_id': 'g1', 'date': '2026-01-01', 'status': 'done', 'updated_at': now},
            {'id': 'l2', 'goal_id': 'g1', 'date': '2026-01-02', 'status': 'done', 'updated_at': now},
          ],
        }),
      );

      // A later import adds a third consecutive day (goals list empty on purpose:
      // the goal already exists locally).
      await merge(
        db,
        normalizeBackup({
          'mode': 'private',
          'habitLogs': [
            {'id': 'l3', 'goal_id': 'g1', 'date': '2026-01-03', 'status': 'done', 'updated_at': now},
          ],
        }),
      );

      final l3 = (await db.query('goal_logs',
              where: 'date = ?', whereArgs: ['2026-01-03']))
          .single;
      expect(l3['streak'], 3,
          reason: 'streak spans existing + newly merged logs');
      await db.close();
    });

    test('skips orphan logs whose goal is absent (respects FK)', () async {
      final db = await openDb();
      final s = await merge(
        db,
        normalizeBackup({
          'mode': 'private',
          'habitLogs': [
            {'id': 'l1', 'goal_id': 'ghost', 'date': '2026-01-01', 'status': 'done', 'updated_at': now},
          ],
        }),
      );
      expect(s.logs.added, 0);
      expect((await db.query('goal_logs')).length, 0);
      await db.close();
    });
  });
}
