// Unit tests for the data-import normalizer + private-mode merge engine
// (lib/core/import_merge.dart). Runs the merge against an in-memory FFI SQLite
// seeded with the real PrivateDbSchema — encryption is orthogonal to the merge
// logic, so this exercises identity matching, last-write-wins, category dedup,
// orphan/FK handling and streak recomputation without SQLCipher or the network.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:mattioli_os/core/import_merge.dart';
import 'package:mattioli_os/core/import_merge_stats.dart';
import 'package:mattioli_os/core/time_formatting.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/models/macro_goal.dart';
import 'package:evolve_sync/evolve_sync.dart';
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

    test('round-trips the verification rule (verify_* columns)', () async {
      final db = await openDb();
      final canonical = normalizeBackup({
        'mode': 'private',
        'habits': [
          {
            'id': 'gv',
            'title': 'Steps',
            'color': '#3B82F6',
            'start_date': '2026-01-01',
            'updated_at': now,
            'verify_provider': 'healthkit',
            'verify_metric': 'steps',
            'verify_comparator': 'gte',
            'verify_threshold': 10000,
            'verify_unit': 'count',
            'verify_effective_from': '2026-06-15',
          },
        ],
      });
      await merge(db, canonical);

      final row =
          (await db.query('goals', where: 'id = ?', whereArgs: ['gv'])).single;
      expect(row['verify_provider'], 'healthkit');
      expect(row['verify_metric'], 'steps');
      expect(row['verify_comparator'], 'gte');
      expect(row['verify_threshold'], 10000.0);
      expect(row['verify_unit'], 'count');
      // The D10 forward-only anchor survives the backup round-trip.
      expect(row['verify_effective_from'], '2026-06-15');
      // And it reconstructs into a VerificationRule (the model round-trips too).
      final rule = VerificationRule.fromColumns(row);
      expect(rule, isNotNull);
      expect(rule!.metricKey, 'steps');
      expect(rule.threshold, 10000.0);
      await db.close();
    });

    test('round-trips a compound habit (verify_conditions)', () async {
      final db = await openDb();
      final steps = VerificationCatalog.steps.ruleWith(10000);
      final exercise = VerificationCatalog.exerciseMinutes.ruleWith(30);
      final blob = encodeVerifyConditions([steps, exercise], VerificationJoin.and);
      final canonical = normalizeBackup({
        'mode': 'private',
        'habits': [
          {
            'id': 'gcompound',
            'title': 'Move',
            'color': '#3B82F6',
            'start_date': '2026-01-01',
            'updated_at': now,
            // Compound on disk: flat verify_* columns null, conditions blob set.
            'verify_conditions': blob,
          },
        ],
      });
      await merge(db, canonical);

      final row = (await db
              .query('goals', where: 'id = ?', whereArgs: ['gcompound']))
          .single;
      expect(row['verify_conditions'], blob);
      expect(row['verify_provider'], isNull); // flat columns stay null
      final decoded = decodeVerifyConditions(row['verify_conditions'])!;
      expect(decoded.conditions, [steps, exercise]);
      expect(decoded.op, VerificationJoin.and);
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

  // ── Validation + must-fix hardening ───────────────────────────────────────

  Map<String, dynamic> clean(Map<String, dynamic> raw) =>
      validateCanonical(normalizeBackup(raw)).canonical;

  group('validateCanonical', () {
    test('drops invalid rows per entity and counts them as skipped', () {
      final v = validateCanonical(normalizeBackup({
        'mode': 'private',
        'habits': [
          nativeGoal(id: 'ok', updatedAt: now),
          {'id': 'bad', 'title': 'No start', 'color': '#fff'}, // no start_date
        ],
        'habitLogs': [
          {'id': 'l1', 'goal_id': 'ok', 'date': '2026-01-01', 'status': 'done'},
          {'id': 'l2', 'goal_id': 'ok', 'date': '2026-01-02', 'status': 'pending'},
        ],
        'dailyMoods': [
          {'id': 'd1', 'date': '2026-01-01', 'mood_score': 5, 'energy_score': 5},
          {'id': 'd2', 'date': '2026-01-02', 'mood_score': 99, 'energy_score': 5},
        ],
        'macroGoals': [
          {'id': 'm1', 'title': 'ok', 'status': 'active', 'type': 'annual'},
          {'id': 'm2', 'title': 'bad', 'status': 'active', 'type': 'weekly', 'week_number': 99},
        ],
        'macroGoalCategories': [
          {'id': 'c1', 'name': 'Health', 'color': '#10B981'},
          {'id': 'c2', 'name': '', 'color': '#000'}, // empty name
        ],
      }));
      expect((v.canonical[kGoalsKey] as List).length, 1);
      expect(v.skipped['habits'], 1);
      expect((v.canonical[kLogsKey] as List).length, 1);
      expect(v.skipped['logs'], 1);
      expect((v.canonical[kMoodsKey] as List).length, 1);
      expect(v.skipped['moods'], 1);
      expect((v.canonical[kMacrosKey] as List).length, 1);
      expect(v.skipped['macroGoals'], 1);
      expect((v.canonical[kCategoriesKey] as List).length, 1);
      expect(v.skipped['categories'], 1);
    });

    test('coerces a non-string id to its string form (no crash)', () {
      final v = validateCanonical(normalizeBackup({
        'mode': 'private',
        'habits': [
          {'id': 42, 'title': 'Num', 'color': '#fff', 'start_date': '2026-01-01', 'updated_at': now},
        ],
      }));
      expect((v.canonical[kGoalsKey] as List).single['id'], '42');
      expect(v.skipped['habits'], 0);
    });
  });

  group('must-fix hardening (private)', () {
    test('#3: a dropped goal never FK-aborts the import via its logs', () async {
      final db = await openDb();
      final v = validateCanonical(normalizeBackup({
        'mode': 'private',
        'habits': [
          nativeGoal(id: 'good', updatedAt: now),
          {'id': 'bad', 'title': 'No start', 'color': '#fff'}, // dropped
        ],
        'habitLogs': [
          {'id': 'lg', 'goal_id': 'good', 'date': '2026-01-01', 'status': 'done', 'updated_at': now},
          {'id': 'lb', 'goal_id': 'bad', 'date': '2026-01-01', 'status': 'done', 'updated_at': now},
        ],
      }));
      final s = await merge(db, v.canonical); // must NOT throw
      expect((await db.query('goals')).length, 1);
      expect(
        (await db.query('goals', where: 'id = ?', whereArgs: ['bad'])).isEmpty,
        isTrue,
      );
      expect((await db.query('goal_logs')).length, 1,
          reason: 'orphan log of the dropped goal is skipped, not FK-aborted');
      expect(s.logs.added, 1);
      await db.close();
    });

    test('#4: an invalid-status winning log is dropped, not a CHECK abort',
        () async {
      final db = await openDb();
      await merge(
        db,
        clean({
          'mode': 'private',
          'habits': [
            nativeGoal(id: 'g1', updatedAt: '2026-01-01T00:00:00.000Z'),
          ],
          'habitLogs': [
            {'id': 'l1', 'goal_id': 'g1', 'date': '2026-01-05', 'status': 'done', 'updated_at': '2026-01-01T00:00:00.000Z'},
          ],
        }),
      );

      // A NEWER log for the same (g1, 2026-01-05) but with a status outside the
      // CHECK vocabulary. Validation drops it; the merge must not abort.
      final v = validateCanonical(normalizeBackup({
        'mode': 'private',
        'habitLogs': [
          {'id': 'l1b', 'goal_id': 'g1', 'date': '2026-01-05', 'status': 'completed', 'updated_at': '2026-02-01T00:00:00.000Z'},
        ],
      }));
      expect(v.skipped['logs'], 1);
      final s = await merge(db, v.canonical); // must NOT throw
      final log = (await db.query('goal_logs',
              where: 'date = ?', whereArgs: ['2026-01-05']))
          .single;
      expect(log['status'], 'done', reason: 'existing log untouched');
      expect(s.logs.total, 0);
      await db.close();
    });

    test('#4b: a non-numeric log value is nulled, never a bind abort',
        () async {
      final db = await openDb();
      final v = validateCanonical(normalizeBackup({
        'mode': 'private',
        'habits': [nativeGoal(id: 'g1', updatedAt: now)],
        'habitLogs': [
          {
            'id': 'l1',
            'goal_id': 'g1',
            'date': '2026-01-01',
            'status': 'done',
            'value': {'oops': true}, // a JSON object sqflite cannot bind
            'updated_at': now,
          },
        ],
      }));
      // The log is kept (value is optional) with value coerced to null.
      expect((v.canonical[kLogsKey] as List).single['value'], isNull);
      expect(v.skipped['logs'], 0);
      final s = await merge(db, v.canonical); // must NOT throw
      expect(s.logs.added, 1);
      expect((await db.query('goal_logs')).single['value'], isNull);
      await db.close();
    });

    test('an LWW update keeps the existing local created_at', () async {
      final db = await openDb();
      await merge(
        db,
        clean({
          'mode': 'private',
          'habits': [
            {'id': 'g1', 'title': 'A', 'color': '#111111', 'start_date': '2026-01-01', 'created_at': '2020-01-01T00:00:00.000Z', 'updated_at': '2026-01-01T00:00:00.000Z'},
          ],
        }),
      );
      await merge(
        db,
        clean({
          'mode': 'private',
          'habits': [
            {'id': 'g1', 'title': 'B', 'color': '#222222', 'start_date': '2026-01-01', 'created_at': '2099-01-01T00:00:00.000Z', 'updated_at': '2026-02-01T00:00:00.000Z'},
          ],
        }),
      );
      final row =
          (await db.query('goals', where: 'id = ?', whereArgs: ['g1'])).single;
      expect(row['title'], 'B', reason: 'newer import applied');
      expect(row['created_at'], '2020-01-01T00:00:00.000Z',
          reason: "existing created_at kept, not the file's future value");
      await db.close();
    });
  });

  // ── Malformed-import hardening ────────────────────────────────────────────
  //
  // The read paths these guard are eager (`rows.map(...).toList()`), so a single
  // poisoned row throws for the WHOLE list and the provider's catch turns that
  // into an empty screen. Each test therefore imports a bad row ALONGSIDE a good
  // one and reads the merged table back through the real decode.

  /// Mirrors PrivateLocalDatabase._goalFromRow + loadGoals: the strict decode a
  /// poisoned row has to survive. Kept here because loadGoals itself needs
  /// SQLCipher, which the FFI harness deliberately does not use.
  List<Goal> readGoals(List<Map<String, Object?>> rows) => rows
      .map((row) => Goal.fromJson({
            'id': row['id'],
            'title': row['title'],
            'description': row['description'],
            'icon': row['icon'],
            'color': row['color'],
            'frequency_days': row['frequency_days'] == null
                ? null
                : List<int>.from(jsonDecode(row['frequency_days'] as String)),
            'start_date': row['start_date'],
            'end_date': row['end_date'],
            'display_order': row['display_order'],
            'reminder_time': row['reminder_time'],
          }))
      .toList();

  group('malformed import hardening', () {
    test('#16: an unparseable start_date drops the goal instead of poisoning '
        'the whole habit list', () async {
      final db = await openDb();
      final v = validateCanonical(normalizeBackup({
        'mode': 'private',
        'habits': [
          nativeGoal(id: 'good', updatedAt: now),
          {
            'id': 'bad',
            'title': 'Locale date',
            'color': '#fff',
            'start_date': '01/02/2024', // parses nowhere
            'updated_at': now,
          },
          {
            'id': 'bad2',
            'title': 'Junk date',
            'color': '#fff',
            'start_date': 'not-a-date',
            'updated_at': now,
          },
        ],
      }));
      expect((v.canonical[kGoalsKey] as List).length, 1);
      expect(v.skipped['habits'], 2, reason: 'reported to the user, not silent');

      await merge(db, v.canonical);
      final goals = readGoals(await db.query('goals')); // must NOT throw
      expect(goals.map((g) => g.id), ['good']);
      expect(goals.single.startDate, DateTime.parse('2026-01-01'));
      await db.close();
    });

    test('#16: an unparseable end_date drops the goal too', () async {
      final v = validateCanonical(normalizeBackup({
        'mode': 'private',
        'habits': [
          nativeGoal(id: 'good', updatedAt: now),
          {
            'id': 'bad',
            'title': 'Bad end',
            'color': '#fff',
            'start_date': '2026-01-01',
            'end_date': '31-12-2026',
            'updated_at': now,
          },
        ],
      }));
      expect((v.canonical[kGoalsKey] as List).single['id'], 'good');
      expect(v.skipped['habits'], 1);
    });

    test('#16: well-formed dates survive validation unchanged', () {
      final v = validateCanonical(normalizeBackup({
        'mode': 'private',
        'habits': [
          {
            'id': 'g1',
            'title': 'Run',
            'color': '#fff',
            'start_date': '2026-01-01',
            'end_date': '2026-12-31T23:59:59.000Z',
            'updated_at': now,
          },
        ],
      }));
      final g = (v.canonical[kGoalsKey] as List).single;
      expect(g['start_date'], '2026-01-01');
      expect(g['end_date'], '2026-12-31T23:59:59.000Z');
      expect(v.skipped['habits'], 0);
    });

    test('#16: Goal.fromJson tolerates an already-persisted bad date rather '
        'than throwing for the whole list', () {
      final goal = Goal.fromJson({
        'id': 'g1',
        'title': 'Run',
        'color': '#3B82F6',
        'start_date': '01/02/2024',
        'end_date': 'nope',
      });
      expect(goal.startDate, DateTime(2000));
      expect(goal.endDate, isNull);
      expect(goal.isActiveOn(DateTime(2026, 1, 1)), isTrue,
          reason: 'the habit stays visible and repairable');
    });

    test('#50: a non-int-list frequency_days is sanitized, never jsonEncoded '
        'verbatim into the column', () async {
      final db = await openDb();
      final v = validateCanonical(normalizeBackup({
        'mode': 'private',
        'habits': [
          {...nativeGoal(id: 'strings', updatedAt: now), 'frequency_days': ['1', '3']},
          {...nativeGoal(id: 'doubles', updatedAt: now), 'frequency_days': [1.0, 2.0]},
          {...nativeGoal(id: 'bare', updatedAt: now), 'frequency_days': 'mon,tue'},
          {...nativeGoal(id: 'map', updatedAt: now), 'frequency_days': {'a': 1}},
          {...nativeGoal(id: 'junk', updatedAt: now), 'frequency_days': ['a', 'b']},
          {...nativeGoal(id: 'range', updatedAt: now), 'frequency_days': [1, 9, 0]},
          {...nativeGoal(id: 'ok', updatedAt: now), 'frequency_days': [2, 4]},
        ],
      }));
      expect(v.skipped['habits'], 0, reason: 'coerced, not dropped');
      final byId = {
        for (final g in (v.canonical[kGoalsKey] as List).cast<Map<String, dynamic>>())
          g['id'] as String: g['frequency_days'],
      };
      expect(byId['strings'], [1, 3]);
      expect(byId['doubles'], [1, 2]);
      expect(byId['bare'], isNull);
      expect(byId['map'], isNull);
      expect(byId['junk'], isNull, reason: 'null = every day, not "no day"');
      expect(byId['range'], [1]);
      expect(byId['ok'], [2, 4]);

      await merge(db, v.canonical);
      final goals = readGoals(await db.query('goals')); // must NOT throw
      expect(goals.length, 7);
      expect(
        goals.firstWhere((g) => g.id == 'strings').frequencyDays,
        [1, 3],
      );
      await db.close();
    });

    test('#63: a malformed reminder_time is nulled so the edit modal can '
        'render it', () async {
      final db = await openDb();
      final v = validateCanonical(normalizeBackup({
        'mode': 'private',
        'habits': [
          {...nativeGoal(id: 'ampm', updatedAt: now), 'reminder_time': '9am'},
          {...nativeGoal(id: 'dots', updatedAt: now), 'reminder_time': '09.00'},
          {...nativeGoal(id: 'letters', updatedAt: now), 'reminder_time': '9:aa'},
          {...nativeGoal(id: 'hour', updatedAt: now), 'reminder_time': '25:00'},
          {...nativeGoal(id: 'minute', updatedAt: now), 'reminder_time': '10:75'},
          {...nativeGoal(id: 'unpadded', updatedAt: now), 'reminder_time': '9:30'},
          {...nativeGoal(id: 'ok', updatedAt: now), 'reminder_time': '07:45'},
        ],
      }));
      expect(v.skipped['habits'], 0, reason: 'the field is optional; null it');

      await merge(db, v.canonical);
      for (final goal in readGoals(await db.query('goals'))) {
        if (goal.id == 'ok') {
          expect(goal.reminderTime, '07:45');
        } else {
          expect(goal.reminderTime, isNull, reason: goal.id);
        }
        // The consumer that throws inside build(): every surviving value parses.
        if (goal.reminderTime != null) {
          expect(AppTimeFormatting.parseTimeOfDay(goal.reminderTime!),
              const TimeOfDay(hour: 7, minute: 45));
        }
      }
      await db.close();
    });

    test('#64: a non-hex category colour drops the row instead of wiping the '
        'category list', () async {
      final db = await openDb();
      final v = validateCanonical(normalizeBackup({
        'mode': 'private',
        'macroGoalCategories': [
          {'id': 'c1', 'name': 'Health', 'color': '#10B981'},
          {'id': 'c2', 'name': 'Work', 'color': 'blue'},
          {'id': 'c3', 'name': 'Home', 'color': 'hsl(210 40% 50%)'},
          {'id': 'c4', 'name': 'Money', 'color': 'rgb(1,2,3)'},
        ],
      }));
      expect((v.canonical[kCategoriesKey] as List).map((c) => c['id']), ['c1']);
      expect(v.skipped['categories'], 3,
          reason: 'reported to the user, not silently admitted');

      await merge(db, v.canonical);
      final cats = (await db.query('macro_goal_categories'))
          .map(GoalCategory.fromJson) // must NOT throw
          .toList();
      expect(cats.map((c) => c.key), ['c1']);
      expect(cats.single.color, const Color(0xFF10B981));
      await db.close();
    });

    test('#64: a 3-digit hex is expanded, not read as a near-transparent '
        'colour', () {
      final v = validateCanonical(normalizeBackup({
        'mode': 'private',
        'macroGoalCategories': [
          {'id': 'c1', 'name': 'Health', 'color': '#fff'},
        ],
      }));
      final cat = (v.canonical[kCategoriesKey] as List).single;
      expect(cat['color'], '#FFFFFF');
      expect(GoalCategory.fromJson(cat).color, const Color(0xFFFFFFFF));
    });

    test('#64: GoalCategory.fromJson falls back to grey on an unparseable '
        'persisted colour, mirroring Goal.fromJson', () {
      final cat = GoalCategory.fromJson({
        'id': 'c1',
        'name': 'Work',
        'color': 'blue',
        'archived_at': 'yesterday',
      });
      expect(cat.color, const Color(0xFF6B7280));
      expect(cat.archivedAt, isNull);
    });
  });

  // ── Quantitative targets (v9) round-trip ──────────────────────────────────
  group('targets + goal_progress', () {
    const targetBlob =
        '{"v":1,"src":"manual","dir":"gte","per":"day","agg":"sum",'
        '"amount":80,"unit":"count","step":20,"input":"stepper","preset":"count_daily"}';

    test('a habit target round-trips through native normalize', () {
      final c = normalizeBackup({
        'mode': 'private',
        'habits': [
          {
            'id': 'g1',
            'title': 'Push-ups',
            'color': '#3B82F6',
            'start_date': '2026-01-01',
            'target': targetBlob,
          },
        ],
      });
      expect((c[kGoalsKey] as List).single['target'], targetBlob);
    });

    test('import writes goals.target so a restore keeps the target', () async {
      final db = await openDb();
      final canonical = validateCanonical(normalizeBackup({
        'mode': 'private',
        'habits': [
          {
            'id': 'g1',
            'title': 'Push-ups',
            'color': '#3B82F6',
            'start_date': '2026-01-01',
            'target': targetBlob,
          },
        ],
      })).canonical;
      await merge(db, canonical);

      final row = (await db.query('goals', where: 'id = ?', whereArgs: ['g1']))
          .single;
      expect(row['target'], targetBlob);
      await db.close();
    });

    test('goal_progress rows round-trip (habitProgress key) with a deterministic id',
        () async {
      final db = await openDb();
      final canonical = validateCanonical(normalizeBackup({
        'mode': 'private',
        'habits': [
          {
            'id': 'g1',
            'title': 'Push-ups',
            'color': '#3B82F6',
            'start_date': '2026-01-01',
            'target': targetBlob,
          },
        ],
        'habitProgress': [
          {
            'goal_id': 'g1',
            'date': '2026-01-05',
            'amount': 40,
            'source': 'manual',
            'updated_at': '2026-01-05T10:00:00.000Z',
          },
        ],
      })).canonical;
      await merge(db, canonical);

      final row =
          (await db.query('goal_progress', where: 'goal_id = ?', whereArgs: ['g1']))
              .single;
      expect(row['id'], 'g1:2026-01-05', reason: 'deterministic id');
      expect((row['amount'] as num).toDouble(), 40);
      expect(row['source'], 'manual');
      await db.close();
    });

    test('a progress row for an unknown goal is skipped (FK-safe)', () async {
      final db = await openDb();
      final canonical = validateCanonical(normalizeBackup({
        'mode': 'private',
        'habitProgress': [
          {'goal_id': 'ghost', 'date': '2026-01-05', 'amount': 40},
        ],
      })).canonical;
      await merge(db, canonical);
      expect(await db.query('goal_progress'), isEmpty);
      await db.close();
    });

    test('a non-positive progress amount is dropped in validation', () {
      final v = validateCanonical(normalizeBackup({
        'mode': 'private',
        'habitProgress': [
          {'goal_id': 'g1', 'date': '2026-01-05', 'amount': 0},
          {'goal_id': 'g1', 'date': '2026-01-06', 'amount': -3},
          {'goal_id': 'g1', 'date': '2026-01-07', 'amount': 20},
        ],
      }));
      expect((v.canonical[kProgressKey] as List).length, 1);
      expect((v.canonical[kProgressKey] as List).single['date'], '2026-01-07');
    });

    test('replace mode wipes goal_progress before re-inserting', () async {
      final db = await openDb();
      // Seed a habit + a stale progress row directly.
      await db.insert('goals', {
        'id': 'g1',
        'user_id': owner,
        'title': 'Push-ups',
        'color': '#3B82F6',
        'start_date': '2026-01-01',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('goal_progress', {
        'id': 'g1:2026-01-01',
        'user_id': owner,
        'goal_id': 'g1',
        'date': '2026-01-01',
        'amount': 99,
        'source': 'manual',
        'created_at': now,
        'updated_at': now,
      });

      final canonical = validateCanonical(normalizeBackup({
        'mode': 'private',
        'habits': [
          {
            'id': 'g1',
            'title': 'Push-ups',
            'color': '#3B82F6',
            'start_date': '2026-01-01',
            'target': targetBlob,
          },
        ],
        'habitProgress': [
          {'goal_id': 'g1', 'date': '2026-01-05', 'amount': 40},
        ],
      })).canonical;
      await merge(db, canonical, replace: true);

      final rows = await db.query('goal_progress');
      expect(rows.length, 1);
      expect(rows.single['date'], '2026-01-05', reason: 'stale row wiped');
      await db.close();
    });
  });
}
