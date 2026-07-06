// Item 1 — Cloud/Private backup export/import round-trip.
//
// Proves the single authoritative importer ([DesktopBackupImportService]) turns
// every `.json` backup shape (the legacy snake_case DB-row shape, the canonical
// camelCase cross-client export, and the raw web backup.json) into the
// canonical VALIDATED import model, and that model persists losslessly to the
// encrypted schema via [DesktopPrivateDb.applyImport] — categories, goals,
// logs, macro goals (with their category link), moods, and the profile all
// preserved.
//
// Runs headless against an in-memory `sqflite_common_ffi` database — no
// SQLCipher / Keychain / Supabase / path_provider needed.
import 'package:evolve_desktop/core/desktop_backup_import_service.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/import_merge.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

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
  const ts = '2026-06-01T08:00:00.000Z';

  Future<Database> seeded() async {
    final db = await openFresh();
    await DesktopPrivateDb.seedProfile(db, owner: owner, now: now);
    return db;
  }

  Future<void> apply(Database db, Map<String, dynamic> model) => db.transaction(
    (txn) => DesktopPrivateDb.applyImport(
      txn,
      owner: owner,
      backupData: model,
      replaceExisting: true,
      now: now,
    ),
  );

  // A full native DB-row export, as produced by DesktopPrivateDb.exportData()
  // and the Cloud export (raw Supabase rows).
  Map<String, dynamic> nativeExport() => {
    'exportDate': ts,
    'mode': 'private',
    'profile': {
      'id': 'source-owner-should-be-ignored',
      'full_name': 'Alice Example',
      'username': 'alice',
      'date_of_birth': '1990-05-15',
      'language': 'en',
      'theme_mode': 'light',
      'accent_color': '#FF0000',
      'is_pro': 0, // must be forced back to 1 (Private invariant)
      'sentry_consent': 1, // must be forced back to 0
      'avatar_url': '/local/path/avatar.png', // must be dropped
    },
    'macro_goal_categories': [
      {
        'id': 'cat-1',
        'name': 'Work',
        'color': '#123456',
        'created_at': ts,
        'archived_at': null,
      },
    ],
    'goals': [
      {
        'id': 'goal-1',
        'title': 'Read',
        'description': 'Books',
        'icon': 'book',
        'color': '#00FF00',
        // The private DB serializes frequency_days as a JSON *string*.
        'frequency_days': '[1,2,3]',
        'start_date': '2026-06-01',
        'display_order': 0,
        'created_at': ts,
        'updated_at': ts,
        'reminder_time': '09:00',
      },
    ],
    'goal_logs': [
      {
        'id': 'log-1',
        'goal_id': 'goal-1',
        'date': '2026-06-01',
        'status': 'done',
        'streak': 1,
        'created_at': ts,
      },
      {
        'id': 'log-2',
        'goal_id': 'goal-1',
        'date': '2026-06-02',
        'status': 'done',
        'streak': 2,
        'created_at': ts,
      },
    ],
    'long_term_goals': [
      {
        'id': 'macro-1',
        'title': 'Career',
        'status': 'active',
        'type': 'annual',
        'year': 2026,
        'category_id': 'cat-1',
        'created_at': ts,
        'updated_at': ts,
      },
    ],
    'daily_moods': [
      {
        'id': 'mood-1',
        'date': '2026-06-01',
        'mood_score': 7,
        'energy_score': 6,
        'created_at': ts,
      },
    ],
  };

  group('native DB-row export round-trip', () {
    test('build model preserves every entity + profile', () {
      final validated = DesktopBackupImportService.buildCanonicalModel(
        nativeExport(),
      );
      final model = validated.canonical;
      expect(validated.totalSkipped, 0);

      expect((model['goals'] as List).single['id'], 'goal-1');
      // frequency_days is decoded from the JSON string into a real list so the
      // cloud integer[] column accepts it.
      expect((model['goals'] as List).single['frequency_days'], [1, 2, 3]);
      expect((model['goal_logs'] as List).length, 2);
      final cat = (model['macro_goal_categories'] as List).single as Map;
      expect(cat['id'], 'cat-1');
      expect(cat['color'], '#123456');
      final macro = (model['long_term_goals'] as List).single;
      expect(macro['id'], 'macro-1');
      expect(macro['category_id'], 'cat-1'); // link preserved
      expect((model['daily_moods'] as List).single['mood_score'], 7);

      final profile = model['profile'] as Map;
      expect(profile['full_name'], 'Alice Example');
      expect(profile['date_of_birth'], '1990-05-15');
    });

    test('cloud plan categories never emit updated_at', () {
      // macro_goal_categories has no updated_at column in the cloud schema —
      // the PLAN row must not emit that key (would fail the Supabase upsert),
      // even though the canonical model carries it for the private store.
      final model = DesktopBackupImportService.buildCanonicalModel(
        nativeExport(),
      ).canonical;
      final plan = planCloudImport(
        userId: 'cloud-user',
        canonical: model,
        replaceExisting: true,
        now: now,
        existingCategories: const [],
        existingGoals: const {},
        existingMacros: const {},
        existingLogs: const {},
        existingMoods: const {},
        newId: () => 'unused',
      );
      final planCat = plan.categories.single;
      expect(planCat.containsKey('updated_at'), isFalse);
      expect(planCat['id'], 'cat-1');
      expect(planCat['user_id'], 'cloud-user');
    });

    test('persists losslessly to the encrypted schema', () async {
      final db = await seeded();
      addTearDown(db.close);

      final model = DesktopBackupImportService.buildCanonicalModel(
        nativeExport(),
      ).canonical;
      await apply(db, model);

      final goals = await db.query('goals');
      expect(goals.single['title'], 'Read');
      expect(goals.single['user_id'], owner);
      expect(goals.single['color'], '#00FF00');

      final logs = await db.query('goal_logs');
      expect(logs.length, 2);
      expect(logs.every((l) => l['goal_id'] == 'goal-1'), isTrue);

      final cats = await db.query('macro_goal_categories');
      expect(cats.single['name'], 'Work');

      final macro = await db.query('long_term_goals');
      expect(macro.single['category_id'], 'cat-1');

      final moods = await db.query('daily_moods');
      expect(moods.single['mood_score'], 7);
      expect(moods.single['energy_score'], 6);

      // Profile restored under the safe allow-list.
      final profile = (await db.query(
        'profiles',
        where: 'id = ?',
        whereArgs: [owner],
      )).single;
      expect(profile['full_name'], 'Alice Example');
      expect(profile['date_of_birth'], '1990-05-15');
      expect(profile['theme_mode'], 'light');
      expect(profile['is_pro'], 1); // forced (source was 0)
      expect(profile['sentry_consent'], 0); // forced (source was 1)
      expect(profile['avatar_url'], isNull); // local path dropped
    });
  });

  group('merge mode', () {
    test('keeps original ids so a re-import dedups by identity', () {
      // The canonical model is mode-independent: ids are NEVER remapped, so
      // the merge can match records by identity (a fresh id per import would
      // duplicate every record on re-import instead).
      final model = DesktopBackupImportService.buildCanonicalModel(
        nativeExport(),
      ).canonical;

      expect((model['goals'] as List).single['id'], 'goal-1');
      expect(
        (model['goal_logs'] as List).every((l) => l['goal_id'] == 'goal-1'),
        isTrue,
      );
      expect((model['macro_goal_categories'] as List).single['id'], 'cat-1');
      expect((model['long_term_goals'] as List).single['id'], 'macro-1');
      expect((model['long_term_goals'] as List).single['category_id'], 'cat-1');
    });
  });

  group('mobile camelCase (cross-device) export round-trip', () {
    Map<String, dynamic> camelExport() => {
      'exportDate': ts,
      'profile': {
        'firstName': 'Bob',
        'lastName': 'Smith',
        'dateOfBirth': '1985-01-01',
      },
      'macroGoalCategories': [
        {'id': 'c1', 'name': 'Health', 'color': '#abcdef'},
      ],
      'habits': [
        {
          'id': 'h1',
          'title': 'Run',
          'color': '#111111',
          'frequency_days': [1],
          'start_date': '2026-06-01',
        },
      ],
      // habitLogs may arrive as a nested { date: { goalId: status } } map.
      'habitLogs': {
        '2026-06-01': {'h1': 'done'},
      },
      'macroGoals': [
        {
          'id': 'm1',
          'title': 'Fit',
          'status': 'active',
          'type': 'annual',
          'category_id': 'c1',
        },
      ],
      // dailyMoods may arrive as a { date: {...} } map.
      'dailyMoods': {
        '2026-06-01': {
          'id': 'dm1',
          'date': '2026-06-01',
          'mood_score': 8,
          'energy_score': 5,
        },
      },
    };

    test('normalizes container keys + map-shaped logs/moods', () {
      final model = DesktopBackupImportService.buildCanonicalModel(
        camelExport(),
      ).canonical;

      expect((model['goals'] as List).single['title'], 'Run');
      final logs = model['goal_logs'] as List;
      expect(logs.length, 1); // map expanded to a row
      expect(logs.single['goal_id'], 'h1');
      expect(logs.single['status'], 'done');
      expect((model['daily_moods'] as List).single['mood_score'], 8);
      expect((model['long_term_goals'] as List).single['category_id'], 'c1');

      final profile = model['profile'] as Map;
      expect(profile['full_name'], 'Bob Smith');
      expect(profile['date_of_birth'], '1985-01-01');
    });

    test('persists to the encrypted schema', () async {
      final db = await seeded();
      addTearDown(db.close);

      final model = DesktopBackupImportService.buildCanonicalModel(
        camelExport(),
      ).canonical;
      await apply(db, model);

      expect((await db.query('goals')).single['title'], 'Run');
      expect((await db.query('goal_logs')).single['goal_id'], 'h1');
      expect((await db.query('daily_moods')).single['mood_score'], 8);
      expect((await db.query('long_term_goals')).single['category_id'], 'c1');
      final profile = (await db.query(
        'profiles',
        where: 'id = ?',
        whereArgs: [owner],
      )).single;
      expect(profile['full_name'], 'Bob Smith');
      expect(profile['date_of_birth'], '1985-01-01');
    });
  });

  group('web backup.json picked directly as .json', () {
    test('carries goal_category_settings so categories + links survive', () {
      final webJson = {
        'goals': [
          {
            'id': 'g1',
            'title': 'W',
            'color': 'hsl(187 94% 47%)',
            'start_date': '2026-06-01',
          },
        ],
        'goal_logs': [],
        'long_term_goals': [
          {
            'id': 'm1',
            'title': 'M',
            'status': 'active',
            'type': 'annual',
            'color': 'red', // web references categories via a color-key
          },
        ],
        'goal_category_settings': {
          'mappings': {
            'red': {'label': 'Work', 'color': 'hsl(0 100% 50%)'},
          },
        },
        'daily_moods': [],
      };

      final model = DesktopBackupImportService.buildCanonicalModel(
        webJson,
      ).canonical;

      final cats = model['macro_goal_categories'] as List;
      expect(cats.length, 1);
      expect(cats.single['name'], 'Work');
      // The macro goal is linked to the synthesized category id.
      final catId = cats.single['id'];
      expect((model['long_term_goals'] as List).single['category_id'], catId);
    });
  });

  group('reconcileCategoriesByName (shared private/cloud brain)', () {
    test('matches by id, else case-insensitive name; remap stays safe', () {
      final rec = reconcileCategoriesByName(
        categories: [
          {'id': 'c-new', 'name': 'Health'},
          // Name collision, different id AND different case: must reuse the
          // existing row (UNIQUE(user_id, name) would otherwise drop it).
          {'id': 'c-work', 'name': 'work'},
          // Id collision: matched by id even though the name differs.
          {'id': 'existing-focus-id', 'name': 'Renamed Focus'},
        ],
        existing: [
          {'id': 'existing-work-id', 'name': 'Work', 'archived_at': null},
          {'id': 'existing-focus-id', 'name': 'Focus', 'archived_at': null},
        ],
        newId: () => 'minted',
      );

      // 'Health' is new; the other two matched existing rows.
      expect(rec.toInsert.map((c) => c['name']), ['Health']);
      expect(rec.remap['c-new'], 'c-new');
      expect(rec.remap['c-work'], 'existing-work-id');
      expect(rec.remap['existing-focus-id'], 'existing-focus-id');
      expect(rec.unchanged, 2);
      // Every id a macro goal may reference after the merge.
      expect(
        rec.validIds,
        containsAll(['c-new', 'existing-work-id', 'existing-focus-id']),
      );
    });

    test('fills a missing archived_at from the import; existing wins', () {
      final rec = reconcileCategoriesByName(
        categories: [
          {'id': 'x', 'name': 'Work', 'archived_at': '2026-01-01T00:00:00Z'},
          {'id': 'y', 'name': 'Done', 'archived_at': '2026-01-01T00:00:00Z'},
        ],
        existing: [
          {'id': 'w', 'name': 'Work', 'archived_at': null},
          {'id': 'd', 'name': 'Done', 'archived_at': '2025-01-01T00:00:00Z'},
        ],
        newId: () => 'minted',
      );

      expect(rec.archiveFills.single.id, 'w');
      expect(rec.archiveFills.single.archivedAt, '2026-01-01T00:00:00Z');
      expect(rec.unchanged, 1); // 'Done' already archived — untouched
    });

    test('intra-file duplicate names dedup onto the first occurrence', () {
      final rec = reconcileCategoriesByName(
        categories: [
          {'id': 'a', 'name': 'Work'},
          {'id': 'b', 'name': 'WORK'},
        ],
        existing: const [],
        newId: () => 'minted',
      );

      expect(rec.toInsert.map((c) => c['id']), ['a']);
      expect(rec.remap['b'], 'a');
    });
  });

  group('profile import resilience', () {
    test(
      'an invalid CHECK value skips the profile but keeps the data',
      () async {
        final db = await seeded();
        addTearDown(db.close);

        final export = nativeExport();
        (export['profile'] as Map)['theme_mode'] = 'auto'; // violates the CHECK
        final model = DesktopBackupImportService.buildCanonicalModel(
          export,
        ).canonical;
        await apply(db, model);

        // Data still imported (no whole-transaction rollback).
        expect((await db.query('goals')).length, 1);
        expect((await db.query('daily_moods')).length, 1);
        // The invalid profile update was skipped; theme_mode kept its default.
        final profile = (await db.query(
          'profiles',
          where: 'id = ?',
          whereArgs: [owner],
        )).single;
        expect(profile['theme_mode'], isNot('auto'));
      },
    );
  });

  group('color normalization', () {
    String colorOf(String color) {
      final model = DesktopBackupImportService.buildCanonicalModel({
        'goals': [
          {'id': 'g', 'title': 'T', 'color': color, 'start_date': '2026-06-01'},
        ],
        'goal_logs': [],
        'long_term_goals': [],
        'macro_goal_categories': [],
        'daily_moods': [],
      }).canonical;
      return (model['goals'] as List).single['color'] as String;
    }

    test('hex is preserved, named tokens map, unknowns are not blue-washed', () {
      expect(colorOf('#12AB34'), '#12AB34'); // valid hex preserved
      expect(colorOf('red'), '#EF4444'); // named token mapped
      expect(colorOf('hsl(0 0% 0%)'), '#000000'); // hsl converted
      // An unrecognized value is preserved, NOT silently turned blue (#3B82F6).
      expect(colorOf('totally-unknown'), 'totally-unknown');
    });
  });
}
