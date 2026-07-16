// Regression tests for two Private-Mode private-DB findings, both locked at the
// SQL/schema contract the apps rely on (the app-level PrivateLocalDatabase /
// DesktopPrivateDb need SQLCipher + path_provider — a device — so these run the
// same PrivateDbSchema against an in-memory / temp-file FFI SQLite; encryption
// is orthogonal to schema correctness).
//
//  * #67 — re-creating a soft-archived macro-goal category. The archived row
//    keeps the UNIQUE(user_id, name) slot, so a bare insert of the same name
//    collides. The app's create path now REVIVES the archived row (clear
//    archived_at, apply the new colour, bump updated_at) instead of inserting;
//    these tests pin the constraint that makes the collision real and the
//    UPDATE that revives the row.
//
//  * #78 — no onDowngrade guard + a non-idempotent v4 migration. A version
//    round-trip stamped user_version down and the re-run of _upgradeToV4 raised
//    "duplicate column name", permanently failing to open. These tests pin the
//    onDowngrade guard (fail closed) and the now-idempotent v4 migration.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:evolve_sync/evolve_sync.dart';
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
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: PrivateDbSchema.onCreate,
          onUpgrade: PrivateDbSchema.onUpgrade,
          onDowngrade: PrivateDbSchema.onDowngrade,
        ),
      );

  Future<Set<String>> columnNames(Database db, String table) async =>
      (await db.rawQuery('PRAGMA table_info($table)'))
          .map((r) => r['name'] as String)
          .toSet();

  const now = '2026-07-15T00:00:00.000Z';
  const later = '2026-07-16T00:00:00.000Z';

  Future<void> seedProfile(Database db, String id) =>
      db.insert('profiles', {'id': id, 'created_at': now, 'updated_at': now});

  Future<void> insertCategory(
    Database db, {
    required String id,
    required String owner,
    required String name,
    required String color,
    String? archivedAt,
  }) =>
      db.insert('macro_goal_categories', {
        'id': id,
        'user_id': owner,
        'name': name,
        'color': color,
        'created_at': now,
        'updated_at': now,
        'archived_at': archivedAt,
      });

  group('#67 archived macro-goal category revive contract', () {
    test('a soft-archived row keeps the UNIQUE(user_id, name) slot — a bare '
        're-insert of the same name collides', () async {
      final db = await openFresh();
      await seedProfile(db, 'owner');
      await insertCategory(db,
          id: 'c1', owner: 'owner', name: 'Work', color: '#111111');
      // Delete is a soft archive: the row stays.
      await db.update('macro_goal_categories', {'archived_at': now},
          where: 'id = ?', whereArgs: ['c1']);

      // The exact failure the create button hit: a fresh insert of the same
      // (owner, name) violates UNIQUE even though the row is archived.
      await expectLater(
        () => insertCategory(db,
            id: 'c2', owner: 'owner', name: 'Work', color: '#222222'),
        throwsA(isA<DatabaseException>()),
      );
      await db.close();
    });

    test('reviving the archived row clears archived_at, applies the new colour '
        'and bumps updated_at, keeping the single row', () async {
      final db = await openFresh();
      await seedProfile(db, 'owner');
      await insertCategory(db,
          id: 'c1', owner: 'owner', name: 'Work', color: '#111111');
      await db.update('macro_goal_categories',
          {'archived_at': now, 'updated_at': now},
          where: 'id = ?', whereArgs: ['c1']);

      // The revive the app now performs instead of a colliding insert.
      final matches = await db.query(
        'macro_goal_categories',
        columns: ['id', 'archived_at'],
        where: 'user_id = ? AND name = ?',
        whereArgs: ['owner', 'Work'],
        limit: 1,
      );
      expect(matches, hasLength(1));
      expect(matches.first['archived_at'], isNotNull);
      await db.update(
        'macro_goal_categories',
        {'archived_at': null, 'color': '#222222', 'updated_at': later},
        where: 'id = ?',
        whereArgs: [matches.first['id']],
      );

      // Exactly one row, same id, revived and recoloured — and now visible to
      // the active-only load path (archived_at IS NULL).
      final all = await db.query('macro_goal_categories',
          where: 'user_id = ?', whereArgs: ['owner']);
      expect(all, hasLength(1));
      final row = all.first;
      expect(row['id'], 'c1', reason: 'same row revived, no new id');
      expect(row['archived_at'], isNull);
      expect(row['color'], '#222222');
      expect(row['updated_at'], later);

      final active = await db.query('macro_goal_categories',
          where: 'user_id = ? AND archived_at IS NULL', whereArgs: ['owner']);
      expect(active, hasLength(1));
      await db.close();
    });

    test('UNIQUE(user_id, name) is case-sensitive — a differently-cased name '
        'does NOT collide with an archived row, so revive must match exactly',
        () async {
      final db = await openFresh();
      await seedProfile(db, 'owner');
      await insertCategory(db,
          id: 'c1', owner: 'owner', name: 'Work', color: '#111111');
      await db.update('macro_goal_categories', {'archived_at': now},
          where: 'id = ?', whereArgs: ['c1']);

      // Lower-case "work" is a distinct name: it inserts cleanly. This is why
      // the app matches for revive with the same binary collation the UNIQUE
      // constraint uses — a case-insensitive match would wrongly revive "Work".
      await insertCategory(db,
          id: 'c2', owner: 'owner', name: 'work', color: '#333333');
      final rows = await db.query('macro_goal_categories',
          where: 'user_id = ?', whereArgs: ['owner']);
      expect(rows, hasLength(2));
      await db.close();
    });
  });

  group('#78 downgrade guard + idempotent v4 migration', () {
    test('onDowngrade fails closed (throws) rather than silently stamping '
        'user_version down', () async {
      final db = await openFresh();
      await expectLater(
        PrivateDbSchema.onDowngrade(db, 4, 3),
        throwsA(isA<StateError>()),
      );
      await db.close();
    });

    test('_upgradeToV4 is idempotent: re-running it against a goals table that '
        'already has the verify_* columns does not throw', () async {
      // createCoreTables builds the current (v4) goals table, i.e. the verify_*
      // columns are already physically present — exactly the state after a
      // v4 → downgrade-stamps-3 → v4 round-trip re-enters _upgradeToV4.
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );
      await PrivateDbSchema.createCoreTables(db);
      await db.insert('profiles', {
        'id': 'o',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('goals', {
        'id': 'g1',
        'user_id': 'o',
        'title': 'Walk',
        'color': '#FFFFFF',
        'start_date': now,
        'created_at': now,
        'updated_at': now,
      });

      // The re-run: with the non-idempotent migration this raised
      // "duplicate column name: verify_provider"; now it is a harmless no-op.
      await PrivateDbSchema.onUpgrade(db, 3, PrivateDbSchema.version);

      expect(
        await columnNames(db, 'goals'),
        containsAll(<String>{
          'verify_provider',
          'verify_metric',
          'verify_comparator',
          'verify_threshold',
          'verify_unit',
        }),
      );
      // Existing row is untouched by the no-op re-run.
      final row =
          (await db.query('goals', where: 'id = ?', whereArgs: ['g1'])).first;
      expect(row['title'], 'Walk');
      await db.close();
    });

    test('a real v4 → v3 file round-trip is refused by onDowngrade instead of '
        'corrupting the migration bookkeeping', () async {
      final dir = await Directory.systemTemp.createTemp('evolve_pdb_test');
      final path = '${dir.path}/private.db';
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      OpenDatabaseOptions opts(int version) => OpenDatabaseOptions(
            version: version,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
            onCreate: PrivateDbSchema.onCreate,
            onUpgrade: PrivateDbSchema.onUpgrade,
            onDowngrade: PrivateDbSchema.onDowngrade,
          );

      // Newer build creates the v4 DB.
      final v4 = await databaseFactory.openDatabase(path, options: opts(4));
      await v4.close();

      // Older build (v3) opening the same file must be refused (fail closed),
      // NOT silently stamp user_version to 3.
      await expectLater(
        () => databaseFactory.openDatabase(path, options: opts(3)),
        throwsA(isA<StateError>()),
      );

      // user_version untouched, so the newer build still opens cleanly.
      final again = await databaseFactory.openDatabase(path, options: opts(4));
      expect(await again.getVersion(), 4);
      await again.close();
    });
  });
}
