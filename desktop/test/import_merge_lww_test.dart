// Import merge semantics — identity-based last-write-wins, streak
// recomputation, skipped-row counting, export round-trips, and sync
// bookkeeping consistency after an import.
//
// Mirrors the mobile client's merge semantics (mobile/lib/core/import_merge.dart
// is the gold standard): newer imported records win, older ones lose, matching
// is by id / natural key, categories reconcile by name, and streaks are
// rebuilt from the MERGED history rather than trusted from the file.
//
// Runs headless against an in-memory `sqflite_common_ffi` database with the
// real PrivateDbSchema (which installs the dirty/tombstone sync triggers).
import 'dart:convert';

import 'package:evolve_desktop/core/desktop_backup_import_service.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/import_merge_stats.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const owner = 'owner-uuid';
  const t0 = '2026-05-01T08:00:00.000Z'; // oldest
  const t1 = '2026-06-01T08:00:00.000Z';
  const t2 = '2026-06-10T08:00:00.000Z';
  const t3 = '2026-06-20T08:00:00.000Z'; // newest
  const now = '2026-07-01T10:00:00.000Z';

  Future<Database> openFresh() => databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: PrivateDbSchema.version,
      singleInstance: false,
      onConfigure: PrivateDbSchema.onConfigure,
      onCreate: PrivateDbSchema.onCreate,
      onUpgrade: PrivateDbSchema.onUpgrade,
    ),
  );

  Future<Database> seeded() async {
    final db = await openFresh();
    await DesktopPrivateDb.seedProfile(db, owner: owner, now: t0);
    return db;
  }

  Future<ImportMergeStats> apply(
    Database db,
    Map<String, dynamic> model, {
    bool replace = false,
  }) => db.transaction(
    (txn) => DesktopPrivateDb.applyImport(
      txn,
      owner: owner,
      backupData: model,
      replaceExisting: replace,
      now: now,
    ),
  );

  /// Seeds the "device" state the merges run against:
  ///   goal g1 (title 'Old title', updated t2) with a done log on 06-01
  ///   (updated t2), a mood on 06-01 (score 5, updated t2), category cat-A
  ///   'Work', and macro m1 (title 'Old macro', updated t2, in cat-A).
  Future<void> seedExistingData(Database db) async {
    await db.insert('goals', {
      'id': 'g1',
      'user_id': owner,
      'title': 'Old title',
      'color': '#111111',
      'start_date': '2026-06-01',
      'created_at': t1,
      'updated_at': t2,
    });
    await db.insert('goal_logs', {
      'id': 'log-1',
      'user_id': owner,
      'goal_id': 'g1',
      'date': '2026-06-01',
      'status': 'done',
      'streak': 1,
      'created_at': t2,
      'updated_at': t2,
    });
    await db.insert('daily_moods', {
      'id': 'mood-1',
      'user_id': owner,
      'date': '2026-06-01',
      'mood_score': 5,
      'energy_score': 5,
      'created_at': t2,
      'updated_at': t2,
    });
    await db.insert('macro_goal_categories', {
      'id': 'cat-A',
      'user_id': owner,
      'name': 'Work',
      'color': '#222222',
      'created_at': t1,
      'updated_at': t1,
    });
    await db.insert('long_term_goals', {
      'id': 'm1',
      'user_id': owner,
      'title': 'Old macro',
      'status': 'active',
      'type': 'annual',
      'year': 2026,
      'category_id': 'cat-A',
      'created_at': t1,
      'updated_at': t2,
    });
  }

  /// The imported backup, canonical-shaped (as produced by
  /// buildCanonicalModel): g1 NEWER (t3), g2 new, g1's 06-01 log NEWER
  /// (missed, t3), a new log for g2, the 06-01 mood OLDER (t1), a new mood,
  /// a same-name category under a different id, m1 OLDER (t1), m2 new
  /// referencing the colliding category id.
  Map<String, dynamic> mergeBackup() =>
      DesktopBackupImportService.buildCanonicalModel({
        'goals': [
          {
            'id': 'g1',
            'title': 'New title',
            'color': '#333333',
            'start_date': '2026-06-01',
            'created_at': t1,
            'updated_at': t3,
          },
          {
            'id': 'g2',
            'title': 'Second habit',
            'color': '#444444',
            'start_date': '2026-06-02',
            'created_at': t1,
            'updated_at': t1,
          },
        ],
        'goal_logs': [
          {
            'id': 'log-1-import',
            'goal_id': 'g1',
            'date': '2026-06-01',
            'status': 'missed',
            'created_at': t2,
            'updated_at': t3,
          },
          {
            'id': 'log-2-import',
            'goal_id': 'g2',
            'date': '2026-06-02',
            'status': 'done',
            'created_at': t1,
            'updated_at': t1,
          },
        ],
        'daily_moods': [
          {
            'id': 'mood-1-import',
            'date': '2026-06-01',
            'mood_score': 9,
            'energy_score': 9,
            'created_at': t1,
            'updated_at': t1, // OLDER than the existing t2 — must lose
          },
          {
            'id': 'mood-2-import',
            'date': '2026-06-03',
            'mood_score': 7,
            'energy_score': 6,
            'created_at': t1,
            'updated_at': t1,
          },
        ],
        'macro_goal_categories': [
          // Same name as cat-A (different case + id): reconciles onto cat-A.
          {'id': 'cat-B', 'name': 'work', 'color': '#555555', 'created_at': t1},
        ],
        'long_term_goals': [
          {
            'id': 'm1',
            'title': 'Renamed macro',
            'status': 'active',
            'type': 'annual',
            'year': 2026,
            'category_id': 'cat-B',
            'created_at': t1,
            'updated_at': t1, // OLDER than the existing t2 — must lose
          },
          {
            'id': 'm2',
            'title': 'Second macro',
            'status': 'active',
            'type': 'annual',
            'year': 2026,
            'category_id': 'cat-B',
            'created_at': t1,
            'updated_at': t1,
          },
        ],
      }).canonical;

  group('merge-mode last-write-wins', () {
    test('newer import wins, older loses, stats are exact', () async {
      final db = await seeded();
      addTearDown(db.close);
      await seedExistingData(db);

      final stats = await apply(db, mergeBackup());

      // Stats: per-entity added / updated / unchanged.
      expect(stats.replaced, isFalse);
      expect(stats.habits.added, 1); // g2
      expect(stats.habits.updated, 1); // g1 (t3 > t2)
      expect(stats.habits.unchanged, 0);
      expect(stats.logs.added, 1); // g2's log
      expect(stats.logs.updated, 1); // g1's 06-01 log (t3 > t2)
      expect(stats.moods.added, 1); // 06-03
      expect(stats.moods.unchanged, 1); // 06-01 (t1 < t2)
      expect(stats.categories.added, 0);
      expect(stats.categories.unchanged, 1); // name-matched onto cat-A
      expect(stats.macroGoals.added, 1); // m2
      expect(stats.macroGoals.unchanged, 1); // m1 (t1 < t2)

      // g1: the newer import superseded it — but created_at is preserved.
      final g1 = (await db.query(
        'goals',
        where: 'id = ?',
        whereArgs: ['g1'],
      )).single;
      expect(g1['title'], 'New title');
      expect(g1['updated_at'], t3);
      expect(g1['created_at'], t1);

      // g1's log was superseded in place (same row id, new status).
      final log1 = (await db.query(
        'goal_logs',
        where: 'goal_id = ? AND date = ?',
        whereArgs: ['g1', '2026-06-01'],
      )).single;
      expect(log1['id'], 'log-1'); // updated in place, not duplicated
      expect(log1['status'], 'missed');

      // The older mood lost: existing values kept.
      final mood1 = (await db.query(
        'daily_moods',
        where: 'date = ?',
        whereArgs: ['2026-06-01'],
      )).single;
      expect(mood1['id'], 'mood-1');
      expect(mood1['mood_score'], 5);

      // The older macro lost; the new macro's category was remapped onto the
      // existing same-name category (cat-B was never inserted).
      final m1 = (await db.query(
        'long_term_goals',
        where: 'id = ?',
        whereArgs: ['m1'],
      )).single;
      expect(m1['title'], 'Old macro');
      final m2 = (await db.query(
        'long_term_goals',
        where: 'id = ?',
        whereArgs: ['m2'],
      )).single;
      expect(m2['category_id'], 'cat-A');
      final cats = await db.query('macro_goal_categories');
      expect(cats.length, 1);
      expect(cats.single['id'], 'cat-A');
    });

    test('re-importing the same backup is a no-op (identity dedup)', () async {
      final db = await seeded();
      addTearDown(db.close);
      await seedExistingData(db);

      await apply(db, mergeBackup());
      final second = await apply(db, mergeBackup());

      // Everything already present and equally new — nothing written.
      for (final m in [
        second.habits,
        second.logs,
        second.macroGoals,
        second.categories,
        second.moods,
      ]) {
        expect(m.added, 0);
        expect(m.updated, 0);
      }
      expect((await db.query('goals')).length, 2);
      expect((await db.query('goal_logs')).length, 2);
      expect((await db.query('daily_moods')).length, 2);
      expect((await db.query('long_term_goals')).length, 2);
      expect((await db.query('macro_goal_categories')).length, 1);
    });

    test('a log for a pre-existing habit merges onto it', () async {
      // Mobile semantics: merge-mode logs may reference goals that already
      // exist locally, not just goals contained in the file.
      final db = await seeded();
      addTearDown(db.close);
      await seedExistingData(db);

      final stats = await apply(
        db,
        DesktopBackupImportService.buildCanonicalModel({
          'goal_logs': [
            {
              'id': 'log-extra',
              'goal_id': 'g1',
              'date': '2026-06-05',
              'status': 'done',
              'created_at': t2,
              'updated_at': t2,
            },
          ],
        }).canonical,
      );

      expect(stats.logs.added, 1);
      expect(
        (await db.query(
          'goal_logs',
          where: 'goal_id = ?',
          whereArgs: ['g1'],
        )).length,
        2,
      );
    });

    test('orphan logs are skipped instead of aborting the txn', () async {
      final db = await seeded();
      addTearDown(db.close);

      final stats = await apply(
        db,
        DesktopBackupImportService.buildCanonicalModel({
          'goals': [
            {
              'id': 'g-ok',
              'title': 'Valid',
              'color': '#123456',
              'start_date': '2026-06-01',
            },
          ],
          'goal_logs': [
            {'goal_id': 'g-ok', 'date': '2026-06-01', 'status': 'done'},
            // References a goal that exists neither locally nor in the file.
            {'goal_id': 'ghost', 'date': '2026-06-01', 'status': 'done'},
          ],
        }).canonical,
      );

      expect(stats.habits.added, 1);
      expect(stats.logs.added, 1); // the orphan was silently dropped
      expect((await db.query('goal_logs')).length, 1);
    });
  });

  group('streak recomputation after merge', () {
    test(
      'gap-filling import rebuilds streaks from the MERGED history',
      () async {
        final db = await seeded();
        addTearDown(db.close);
        await db.insert('goals', {
          'id': 'g1',
          'user_id': owner,
          'title': 'Read',
          'color': '#111111',
          'start_date': '2026-06-01',
          'created_at': t1,
          'updated_at': t1,
        });
        // Existing: done on 06-01 and 06-03. 06-02 is a gap, so 06-03's stored
        // streak is (correctly) 1.
        await db.insert('goal_logs', {
          'id': 'log-a',
          'user_id': owner,
          'goal_id': 'g1',
          'date': '2026-06-01',
          'status': 'done',
          'streak': 1,
          'created_at': t1,
          'updated_at': t1,
        });
        await db.insert('goal_logs', {
          'id': 'log-c',
          'user_id': owner,
          'goal_id': 'g1',
          'date': '2026-06-03',
          'status': 'done',
          'streak': 1,
          'created_at': t1,
          'updated_at': t1,
        });

        // The import fills the 06-02 gap — with a nonsense streak value that
        // must NOT be trusted.
        await apply(
          db,
          DesktopBackupImportService.buildCanonicalModel({
            'goal_logs': [
              {
                'id': 'log-b',
                'goal_id': 'g1',
                'date': '2026-06-02',
                'status': 'done',
                'streak': 99,
                'created_at': t2,
                'updated_at': t2,
              },
            ],
          }).canonical,
        );

        final logs = {
          for (final l in await db.query(
            'goal_logs',
            where: 'goal_id = ?',
            whereArgs: ['g1'],
          ))
            l['date'] as String: l['streak'] as int,
        };
        // Recomputed over the merged history: 1, 2, 3 — including 06-03, which
        // was NOT part of the file but whose run length changed.
        expect(logs['2026-06-01'], 1);
        expect(logs['2026-06-02'], 2);
        expect(logs['2026-06-03'], 3);
      },
    );

    test(
      'replace-mode import recomputes signed streaks for all logs',
      () async {
        final db = await seeded();
        addTearDown(db.close);

        await apply(
          db,
          DesktopBackupImportService.buildCanonicalModel({
            'goals': [
              {
                'id': 'g1',
                'title': 'Read',
                'color': '#111111',
                'start_date': '2026-06-01',
              },
            ],
            // File carries no/false streaks: two done days then a missed one.
            'goal_logs': [
              {'goal_id': 'g1', 'date': '2026-06-01', 'status': 'done'},
              {
                'goal_id': 'g1',
                'date': '2026-06-02',
                'status': 'done',
                'streak': 42,
              },
              {'goal_id': 'g1', 'date': '2026-06-03', 'status': 'missed'},
            ],
          }).canonical,
          replace: true,
        );

        final logs = {
          for (final l in await db.query('goal_logs'))
            l['date'] as String: l['streak'] as int,
        };
        expect(logs['2026-06-01'], 1);
        expect(logs['2026-06-02'], 2);
        expect(logs['2026-06-03'], -1); // negative 💔 run
      },
    );
  });

  group('skipped-row counting', () {
    test('invalid rows are dropped and counted per entity', () {
      final validated = DesktopBackupImportService.buildCanonicalModel({
        'goals': [
          {
            'id': 'ok',
            'title': 'Valid',
            'color': '#123456',
            'start_date': '2026-06-01',
          },
          {'id': 'no-title', 'color': '#123456', 'start_date': '2026-06-01'},
        ],
        'goal_logs': [
          {'goal_id': 'ok', 'date': '2026-06-01', 'status': 'done'},
          {'goal_id': 'ok', 'date': '2026-06-02', 'status': 'partying'},
          {'goal_id': null, 'date': '2026-06-03', 'status': 'done'},
        ],
        'macro_goal_categories': [
          {'id': 'c-ok', 'name': 'Work', 'color': '#111111'},
          {'id': 'c-bad', 'color': '#111111'}, // no name
        ],
        'long_term_goals': [
          {'id': 'm-ok', 'title': 'M', 'status': 'active', 'type': 'annual'},
          {'id': 'm-bad', 'title': 'M2', 'status': 'active', 'type': 'decade'},
        ],
        'daily_moods': [
          {'date': '2026-06-01', 'mood_score': 5, 'energy_score': 5},
          {'date': '2026-06-02', 'mood_score': 42, 'energy_score': 5},
          {'mood_score': 5, 'energy_score': 5}, // no date
        ],
      });

      expect(validated.skipped, {
        'habits': 1,
        'logs': 2,
        'macroGoals': 1,
        'categories': 1,
        'moods': 2,
      });
      expect(validated.totalSkipped, 7);
      expect((validated.canonical['goals'] as List).length, 1);
      expect((validated.canonical['goal_logs'] as List).length, 1);
      expect((validated.canonical['macro_goal_categories'] as List).length, 1);
      expect((validated.canonical['long_term_goals'] as List).length, 1);
      expect((validated.canonical['daily_moods'] as List).length, 1);
    });
  });

  group('desktop → desktop full round-trip', () {
    test('exportSnapshot → JSON → import reproduces the data space', () async {
      final source = await seeded();
      addTearDown(source.close);
      await seedExistingData(source);
      await source.update(
        'profiles',
        {'full_name': 'Alice Example', 'theme_mode': 'light'},
        where: 'id = ?',
        whereArgs: [owner],
      );
      // frequency_days round-trip: stored JSON-encoded, exported as a list.
      await source.update(
        'goals',
        {'frequency_days': '[1,2,3]'},
        where: 'id = ?',
        whereArgs: ['g1'],
      );

      final payload = await DesktopPrivateDb.exportSnapshot(
        source,
        owner: owner,
      );

      // Canonical cross-client shape, mirroring the mobile private export.
      expect(payload['schemaVersion'], 1);
      expect(payload['mode'], 'private');
      expect(payload['settings'], isA<Map<dynamic, dynamic>>());
      expect((payload['settings'] as Map)['theme_mode'], 'light');
      expect((payload['profile'] as Map)['full_name'], 'Alice Example');
      expect((payload['habits'] as List).single['frequency_days'], [1, 2, 3]);
      expect((payload['habitLogs'] as List).single['streak'], 1);
      expect((payload['macroGoalCategories'] as List).single['name'], 'Work');
      expect((payload['macroGoals'] as List).single['category_id'], 'cat-A');
      expect((payload['dailyMoods'] as List).single['mood_score'], 5);

      // Honest round-trip: through real JSON text, like a file on disk.
      final rehydrated =
          jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      final validated = DesktopBackupImportService.buildCanonicalModel(
        rehydrated,
      );
      expect(validated.totalSkipped, 0);

      final target = await seeded();
      addTearDown(target.close);
      final stats = await target.transaction(
        (txn) => DesktopPrivateDb.applyImport(
          txn,
          owner: owner,
          backupData: validated.canonical,
          replaceExisting: true,
          now: now,
        ),
      );
      expect(stats.habits.added, 1);
      expect(stats.logs.added, 1);
      expect(stats.macroGoals.added, 1);
      expect(stats.categories.added, 1);
      expect(stats.moods.added, 1);

      final goal = (await target.query('goals')).single;
      expect(goal['id'], 'g1');
      expect(goal['title'], 'Old title');
      expect(goal['frequency_days'], '[1,2,3]'); // re-encoded for storage
      expect(goal['updated_at'], t2); // timestamps preserved
      final log = (await target.query('goal_logs')).single;
      expect(log['id'], 'log-1');
      expect(log['status'], 'done');
      final macro = (await target.query('long_term_goals')).single;
      expect(macro['id'], 'm1');
      expect(macro['category_id'], 'cat-A');
      final profile = (await target.query(
        'profiles',
        where: 'id = ?',
        whereArgs: [owner],
      )).single;
      expect(profile['full_name'], 'Alice Example');
      expect(profile['theme_mode'], 'light');
    });
  });

  group('mobile 1.0.10 export → desktop import', () {
    test('the mobile private exportData shape imports losslessly', () async {
      // Byte-shape of mobile/lib/core/private_local_database.dart exportData:
      // schemaVersion + mode + profile + settings + camelCase containers with
      // snake_case DB-row elements (habitLogs as a LIST with streaks).
      final mobileExport = {
        'schemaVersion': 1,
        'exportDate': '2026-06-20T09:00:00.000Z',
        'mode': 'private',
        'profile': {
          'id': 'mobile-owner-ignored',
          'full_name': 'Bob Mobile',
          'language': 'it',
          'theme_mode': 'dark',
          'accent_color': '#FF0000',
          'is_pro': 1,
          'created_at': t1,
          'updated_at': t2,
          'date_of_birth': '1990-05-15',
        },
        'settings': {
          'id': 'mobile-owner-ignored',
          'full_name': 'Bob Mobile',
          'language': 'it',
          'theme_mode': 'dark',
        },
        'habits': [
          {
            'id': 'h1',
            'title': 'Meditate',
            'description': null,
            'icon': 'sun',
            'color': '#8B5CF6',
            'frequency_days': [1, 2, 3, 4, 5],
            'start_date': '2026-06-01',
            'end_date': null,
            'display_order': 0,
            'created_at': t1,
            'updated_at': t2,
            'reminder_time': '08:00',
          },
        ],
        'habitLogs': [
          {
            'id': 'hl1',
            'goal_id': 'h1',
            'date': '2026-06-01',
            'status': 'done',
            'value': null,
            'created_at': t1,
            'updated_at': t1,
            'streak': 1,
          },
          {
            'id': 'hl2',
            'goal_id': 'h1',
            'date': '2026-06-02',
            'status': 'done',
            'value': 2.5,
            'created_at': t1,
            'updated_at': t1,
            'streak': 2,
          },
        ],
        'macroGoals': [
          {
            'id': 'mg1',
            'title': 'Inner peace',
            'status': 'active',
            'type': 'annual',
            'year': 2026,
            'month': null,
            'week_number': null,
            'quarter': null,
            'category_key': null,
            'category_id': 'mc1',
            'created_at': t1,
            'updated_at': t1,
          },
        ],
        'macroGoalCategories': [
          {
            'id': 'mc1',
            'name': 'Mind',
            'color': '#06B6D4',
            'created_at': t1,
            'updated_at': t1,
            'archived_at': null,
          },
        ],
        'dailyMoods': [
          {
            'id': 'dm1',
            'date': '2026-06-01',
            'mood_score': 8,
            'energy_score': 7,
            'created_at': t1,
            'updated_at': t1,
          },
        ],
      };

      final rehydrated =
          jsonDecode(jsonEncode(mobileExport)) as Map<String, dynamic>;
      final validated = DesktopBackupImportService.buildCanonicalModel(
        rehydrated,
      );
      expect(validated.totalSkipped, 0);

      final db = await seeded();
      addTearDown(db.close);
      final stats = await apply(db, validated.canonical, replace: true);
      expect(stats.habits.added, 1);
      expect(stats.logs.added, 2);
      expect(stats.macroGoals.added, 1);
      expect(stats.categories.added, 1);
      expect(stats.moods.added, 1);

      final goal = (await db.query('goals')).single;
      expect(goal['id'], 'h1');
      expect(goal['frequency_days'], '[1,2,3,4,5]'); // re-encoded TEXT
      expect(goal['user_id'], owner); // re-owned by this device
      final macro = (await db.query('long_term_goals')).single;
      expect(macro['category_id'], 'mc1');
      final logs = await db.query('goal_logs', orderBy: 'date ASC');
      expect(logs.length, 2);
      expect(logs.last['value'], 2.5);
      expect(logs.last['streak'], 2); // recomputed — happens to match
      final profile = (await db.query(
        'profiles',
        where: 'id = ?',
        whereArgs: [owner],
      )).single;
      expect(profile['full_name'], 'Bob Mobile');
      expect(profile['theme_mode'], 'dark');
      expect(profile['id'], owner); // foreign id never smuggled in
    });
  });

  group('profile restore is gated to REPLACE imports (#12)', () {
    Map<String, dynamic> profileOnlyBackup() => {
      'goals': <Map<String, dynamic>>[],
      'goal_logs': <Map<String, dynamic>>[],
      'long_term_goals': <Map<String, dynamic>>[],
      'macro_goal_categories': <Map<String, dynamic>>[],
      'daily_moods': <Map<String, dynamic>>[],
      'profile': {
        'full_name': 'Backup User',
        'theme_mode': 'dark',
        'language': 'it',
      },
    };

    test('a MERGE import does not overwrite the live profile', () async {
      final db = await seeded();
      addTearDown(db.close);
      await db.update(
        'profiles',
        {'full_name': 'Local User', 'theme_mode': 'light', 'language': 'en'},
        where: 'id = ?',
        whereArgs: [owner],
      );

      await apply(db, profileOnlyBackup()); // replace: false (merge)

      final profile = (await db.query(
        'profiles',
        where: 'id = ?',
        whereArgs: [owner],
      )).single;
      expect(profile['full_name'], 'Local User');
      expect(profile['theme_mode'], 'light');
      expect(profile['language'], 'en');
    });

    test('a REPLACE import still restores the backup profile', () async {
      final db = await seeded();
      addTearDown(db.close);
      await db.update(
        'profiles',
        {'full_name': 'Local User', 'theme_mode': 'light', 'language': 'en'},
        where: 'id = ?',
        whereArgs: [owner],
      );

      await apply(db, profileOnlyBackup(), replace: true);

      final profile = (await db.query(
        'profiles',
        where: 'id = ?',
        whereArgs: [owner],
      )).single;
      expect(profile['full_name'], 'Backup User');
      expect(profile['theme_mode'], 'dark');
      expect(profile['language'], 'it');
    });
  });

  group('sync bookkeeping stays consistent after imports', () {
    Future<Map<String, Map<String, Object?>>> syncState(Database db) async => {
      for (final r in await db.query(PrivateDbSchema.syncStateTable))
        r['record_name'] as String: r,
    };

    Future<void> markAllSynced(Database db) async {
      await db.update(PrivateDbSchema.syncStateTable, {'dirty': 0});
    }

    test('merge import dirties exactly the rows it wrote', () async {
      final db = await seeded();
      addTearDown(db.close);
      await seedExistingData(db);
      await markAllSynced(db); // simulate: everything already pushed

      await apply(db, mergeBackup());

      final state = await syncState(db);
      // Written rows are dirty and alive.
      for (final record in ['goals:g1', 'goals:g2', 'goal_logs:log-1']) {
        expect(state[record]!['dirty'], 1, reason: '$record must need a push');
        expect(state[record]!['deleted'], 0);
      }
      // LWW losers were never touched — still clean.
      for (final record in [
        'daily_moods:mood-1',
        'long_term_goals:m1',
        'macro_goal_categories:cat-A',
      ]) {
        expect(state[record]!['dirty'], 0, reason: '$record must stay clean');
      }
      // No tombstone may exist for a row that is still alive.
      for (final entry in state.entries) {
        if (entry.value['deleted'] == 1) {
          final rows = await db.query(
            entry.value['table_name'] as String,
            where: 'id = ?',
            whereArgs: [entry.value['row_id']],
          );
          expect(
            rows,
            isEmpty,
            reason: '${entry.key} is tombstoned but still exists',
          );
        }
      }
      expect(state.values.where((r) => r['deleted'] == 1), isEmpty);
    });

    test('no-op merge leaves the sync state untouched', () async {
      final db = await seeded();
      addTearDown(db.close);
      await seedExistingData(db);
      await apply(db, mergeBackup());
      await markAllSynced(db);

      // Same file again: every record unchanged → no trigger may fire.
      await apply(db, mergeBackup());

      final state = await syncState(db);
      expect(
        state.values.where((r) => r['dirty'] == 1),
        isEmpty,
        reason: 'an unchanged import must not re-dirty synced rows',
      );
    });

    test(
      'replace import tombstones removed rows, re-dirties surviving ids',
      () async {
        final db = await seeded();
        addTearDown(db.close);
        await seedExistingData(db);
        await markAllSynced(db);

        // Replace with a backup containing g1 (same id, survives) but NOT m1 /
        // mood-1 / log-1 / cat-A (they disappear -> deletions must propagate).
        await apply(
          db,
          DesktopBackupImportService.buildCanonicalModel({
            'goals': [
              {
                'id': 'g1',
                'title': 'Replaced title',
                'color': '#999999',
                'start_date': '2026-06-01',
                'created_at': t1,
                'updated_at': t3,
              },
            ],
          }).canonical,
          replace: true,
        );

        final state = await syncState(db);
        // g1 was deleted and re-inserted under the same id: alive + dirty (the
        // insert trigger overwrites the delete tombstone).
        expect(state['goals:g1']!['dirty'], 1);
        expect(state['goals:g1']!['deleted'], 0);
        // Rows not in the backup are tombstoned so the deletion syncs.
        for (final record in [
          'goal_logs:log-1',
          'daily_moods:mood-1',
          'long_term_goals:m1',
          'macro_goal_categories:cat-A',
        ]) {
          expect(state[record]!['dirty'], 1);
          expect(
            state[record]!['deleted'],
            1,
            reason: '$record must propagate as a delete',
          );
        }
        // And the tombstoned rows really are gone locally.
        expect((await db.query('goal_logs')).length, 0);
        expect((await db.query('daily_moods')).length, 0);
        expect((await db.query('long_term_goals')).length, 0);
        expect((await db.query('macro_goal_categories')).length, 0);
      },
    );
  });
}
