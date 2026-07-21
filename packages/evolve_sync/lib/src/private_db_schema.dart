import 'package:sqflite_common/sqlite_api.dart';

/// Schema + migrations for the Private-Mode local database — the single source
/// of truth for BOTH apps (iOS `mobile/` and macOS `desktop/`): identical
/// tables, columns, constraints, indexes and sync triggers, so iCloud-sync
/// records stay format-compatible across platforms and a schema migration can
/// never ship on one platform without the other.
///
/// Kept over `DatabaseExecutor` so the DDL and migration logic run against both
/// the production SQLCipher databases AND an in-memory `sqflite_common_ffi`
/// database in tests (encryption is orthogonal to schema correctness), and
/// inside transactions too.
class PrivateDbSchema {
  PrivateDbSchema._();

  /// Bump on any schema change.
  /// - v2: widen `long_term_goals.week_number` CHECK to 1..53.
  /// - v3: add `macro_goal_categories.updated_at`; add the `sync_state` /
  ///   `sync_meta` tables + per-table triggers that drive iCloud sync.
  /// - v4: add `goals.verify_*` columns (auto-verified habits rule; all
  ///   nullable, null ⇒ ordinary manual habit). Left unconstrained (no CHECK)
  ///   so a rule synced from a newer client with a future provider/metric is
  ///   stored rather than rejected.
  /// - v5: add `sync_meta.key_fingerprint` — the E2E key this device last
  ///   synced with. A change means previously-undecryptable records may now be
  ///   readable, which is what triggers the full re-fetch that recovers them.
  /// - v6: add the `user_settings` key/value table (one synced record PER
  ///   SETTING) and `sync_meta.schema_version`. Settings previously lived only
  ///   as columns on the single `profiles` row, so the whole row was one sync
  ///   record under row-level last-write-wins: changing accent on one device and
  ///   language on the other inside a sync window silently reverted one of them.
  ///   Per-key records make that structurally impossible.
  static const int version = 6;

  /// The user-data tables whose rows sync to iCloud. Each gets dirty/tombstone
  /// triggers that maintain [syncStateTable]. (Order matters for nothing here,
  /// but mirrors the create order.)
  static const List<String> syncedTables = [
    'profiles',
    'goals',
    'goal_logs',
    'long_term_goals',
    'daily_moods',
    'goal_category_settings',
    'macro_goal_categories',
    'user_settings',
  ];

  static const String syncStateTable = 'sync_state';
  static const String syncMetaTable = 'sync_meta';

  /// Pseudo-table name for the avatar CKAsset record (`avatar:<owner>`). It has
  /// no DB table — the image is a file — but it flows through `sync_state` and
  /// the engine like a row. NOT trigger-managed: the avatar write path marks it
  /// dirty explicitly ([SyncLocalStore.markAvatarDirty]).
  static const String avatarRecordTable = 'avatar';

  static String avatarRecordName(String owner) => 'avatar:$owner';

  /// The settings that sync, as canonical keys in the `user_settings` table.
  ///
  /// Declared HERE, in the shared package, so the two apps cannot drift: a key
  /// spelled differently on iOS and macOS would produce two independent records
  /// that never converge, and the user would see a setting that simply refuses
  /// to travel.
  ///
  /// Membership is a product decision, not a technical one — everything a user
  /// thinks of as "my preference" belongs here, and everything derived from what
  /// a specific device can DO does not (see [deviceLocalProfileColumns]).
  static const List<String> syncedSettingKeys = [
    'language',
    'theme_mode',
    'accent_color',
    'pref_glass_effects',
    'pref_default_calendar_view',
    'pref_start_week_on_monday',
    'pref_show_weekend',
    'pref_haptic_feedback',
    'pref_time_format_24h',
    'pref_ai_suggestions',
    'pref_focus_mode',
    'pref_milestones',
    'pref_deep_work_insights',
    'notif_habit_reminders',
    'notif_goal_deadlines',
    'notif_ai_insights',
    'notif_weekly_reports',
    'notif_evening_review',
    'morning_brief_time',
    'evening_review_time',
    'tutorial_completed',
  ];

  /// `profiles` columns that must NEVER cross the sync boundary, beyond the
  /// avatar path. Stripped on push and preserved on apply by [localOnlyColumns].
  ///
  /// Two distinct reasons, both deliberate:
  ///  * **Device capability** — `biometric_lock` means Face ID on one device,
  ///    Touch ID or nothing on another. A synced `true` either locks a user out
  ///    of a device that cannot satisfy it, or silently does nothing; for a
  ///    security setting the silent case is the worse one.
  ///  * **Entitlement and consent** — `is_pro`/`pro_expires_at` must derive from
  ///    the device's OWN receipt, never from a row another device wrote (a synced
  ///    `is_pro = 1` is an in-app-purchase bypass). Consent is given on the
  ///    device that asked for it: propagating "accepted" to a device that never
  ///    showed the dialog is wrong both legally and ethically.
  ///
  /// Until this list existed, macOS stamped `is_pro: 1` and `sentry_consent: 0`
  /// into the synced row on EVERY settings write, so toggling any unrelated
  /// preference on the Mac silently reset crash-reporting consent on the iPhone.
  static const List<String> deviceLocalProfileColumns = [
    'biometric_lock',
    'is_pro',
    'pro_expires_at',
    'sentry_consent',
    'private_ai_external_consent',
    'terms_accepted_at',
  ];

  /// Columns whose values are device-local and MUST NOT cross the sync boundary.
  /// `profiles.avatar_url` is a local filesystem path to the cached avatar — the
  /// image itself rides along as a CloudKit asset, but the path is meaningless
  /// (and different) on another device. The engine strips these from the push
  /// payload and the local store preserves the existing local value on apply.
  ///
  /// `goal_logs.value` — which carries HealthKit measurements — is deliberately
  /// absent: it is meant to reach the user's other devices, and this zone is the
  /// user's own CloudKit private database, AES-GCM encrypted under a key we never
  /// hold.
  ///
  /// That is a decision, not a settled reading of the rules. App Store guideline
  /// 5.1.3(ii) is written about storage location — apps "may not store personal
  /// health information in iCloud" — and carves out no exception for encrypted or
  /// developer-unreadable storage, so syncing measurements through this zone is a
  /// risk the owner has chosen to carry on the grounds that the container is the
  /// user's own and the payload is opaque to us. Revisit if review says otherwise.
  ///
  /// The separate rule the owner treats as absolute — a measurement never reaches
  /// Supabase — is enforced where those payloads are built (the mobile app's
  /// `applyAutoVerdict` and `stripHealthMeasurements`), not here.
  static const Map<String, List<String>> localOnlyColumns = {
    'profiles': ['avatar_url', ...deviceLocalProfileColumns],
  };

  // ── sqflite open callbacks ────────────────────────────────────────────────

  static Future<void> onConfigure(Database db) async {
    // Enforce referential integrity (SQLite leaves FKs off by default).
    //
    // Set in `onConfigure` (not at open time) so foreign keys are enforced for
    // the WHOLE connection — including `onCreate`/`onUpgrade` migrations and,
    // crucially, backup imports (a malformed FK row is rejected/skipped rather
    // than silently orphaned). This is per-connection, matching the mobile
    // client's intent; `onConfigure` is simply the canonical sqflite hook for it.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> onCreate(Database db, int version) async {
    await createCoreTables(db);
    await createSyncObjects(db);
  }

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _upgradeToV2(db);
    }
    if (oldVersion < 3) {
      await _upgradeToV3(db);
    }
    if (oldVersion < 4) {
      await _upgradeToV4(db);
    }
    if (oldVersion < 5) {
      await _upgradeToV5(db);
    }
    if (oldVersion < 6) {
      await _upgradeToV6(db);
    }
  }

  /// Fail closed on a schema downgrade. With NO onDowngrade, sqflite's default
  /// is neither a throw nor a delete: it silently stamps `user_version` DOWN
  /// while leaving the newer physical schema in place (sqflite_common
  /// database_mixin.dart). The next upgrade then re-runs a migration against
  /// columns that already exist and the database permanently fails to open.
  /// Throwing here keeps `user_version` at the newer version, so the newer
  /// build still opens cleanly and the older build refuses a database it does
  /// not understand rather than corrupting its migration bookkeeping.
  ///
  /// Realistic on these apps: iOS and macOS ship independently and share a
  /// synced private DB, so a user WILL open an older build after a newer one
  /// (TestFlight, a kept macOS .app). Never use `onDatabaseDowngradeDelete` —
  /// it would wipe the user's private data, which is intact and decryptable.
  static Future<void> onDowngrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    throw StateError(
      'Private DB is at schema v$oldVersion; this build only knows '
      'v$newVersion. Refusing to downgrade.',
    );
  }

  // ── v6 migration ──────────────────────────────────────────────────────────

  /// DDL for the per-setting sync table. Shared between [createCoreTables] and
  /// the v6 upgrade so a fresh install and a migrated database cannot drift.
  ///
  /// `value` is TEXT and nullable: every setting is stored as its string form
  /// (booleans as `'0'`/`'1'`, matching how they are already persisted on
  /// `profiles`), and NULL means "explicitly unset". Storing an unset as NULL
  /// rather than deleting the row matters — a deletion would emit a tombstone,
  /// and a tombstone racing an edit from another device is exactly the
  /// resurrection problem per-key records exist to avoid.
  static const String _userSettingsTableDdl = '''
CREATE TABLE user_settings (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  key TEXT NOT NULL,
  value TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(user_id, key)
)
''';

  static Future<void> _upgradeToV6(DatabaseExecutor db) async {
    // Idempotent: a version round-trip must not wedge every future open.
    final existing = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      ['user_settings'],
    );
    if (existing.isEmpty) {
      await db.execute(_userSettingsTableDdl);
      await db.execute(
        'CREATE INDEX idx_user_settings_owner ON user_settings (user_id)',
      );
      // The sync triggers are generated from `syncedTables`, which now includes
      // this table — but createSyncTriggers would fail re-creating the existing
      // ones, so add just this table's set.
      await _createTriggersFor(db, 'user_settings');
    }

    // sync_meta.schema_version: lets the engine notice that THIS build now
    // understands a table it previously quarantined records for, and re-fetch
    // them. Without it, records pushed by an already-upgraded device while this
    // one was behind are skipped, the token advances past them, and CloudKit
    // never re-delivers them — the settings would silently never arrive.
    final metaExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [syncMetaTable],
    );
    if (metaExists.isNotEmpty) {
      final cols = <String>{
        for (final r in await db.rawQuery('PRAGMA table_info($syncMetaTable)'))
          r['name'] as String,
      };
      if (!cols.contains('schema_version')) {
        await db.execute(
          'ALTER TABLE $syncMetaTable ADD COLUMN schema_version INTEGER',
        );
      }
    }

    // Backfill from the profiles columns so an upgrading device keeps the
    // settings it already had. Only the SYNCED keys move; device-local columns
    // (entitlement, consent, biometric) deliberately stay on `profiles` and out
    // of the sync payload entirely.
    final profileCols = <String>{
      for (final r in await db.rawQuery('PRAGMA table_info(profiles)'))
        r['name'] as String,
    };
    final movable =
        syncedSettingKeys.where(profileCols.contains).toList(growable: false);
    if (movable.isEmpty) return;

    for (final p in await db.rawQuery(
      'SELECT id, ${movable.join(', ')}, created_at FROM profiles',
    )) {
      final ownerId = p['id'] as String;
      for (final k in movable) {
        final v = p[k];
        if (v == null) continue;
        await db.rawInsert(
          'INSERT OR IGNORE INTO user_settings '
          '(id, user_id, key, value, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [
            '$ownerId:$k',
            ownerId,
            k,
            '$v',
            p['created_at'],
            // Stamped NOW, not from profiles.updated_at: these rows must win
            // last-write-wins against a peer that has not migrated yet and is
            // still pushing the legacy columns. A backfill that loses to stale
            // data would silently undo the user's settings.
            _nowExprValue(),
          ],
        );
      }
    }
  }

  /// UTC ISO-8601 stamp matching the format every other table uses.
  static String _nowExprValue() => DateTime.now().toUtc().toIso8601String();

  // ── v5 migration ──────────────────────────────────────────────────────────

  static Future<void> _upgradeToV5(DatabaseExecutor db) async {
    // `PRAGMA table_info` returns EMPTY both for a table without the column and
    // for a table that does not exist at all, so the two must be told apart:
    // ALTERing a missing table throws and would wedge every future open. A
    // database reaching v5 without `sync_meta` is not the normal path (v3
    // creates it), but a migration that assumes its predecessor's side effects
    // is exactly how an upgrade chain becomes unrecoverable in the field.
    // Nothing to do when it is absent — createSyncTables declares the column
    // inline, so the table will be born with it.
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [syncMetaTable],
    );
    if (tables.isEmpty) return;

    // Idempotent for the same reason as v4: a version round-trip must not
    // permanently wedge every future open on "duplicate column name".
    final existing = <String>{
      for (final row in await db.rawQuery('PRAGMA table_info($syncMetaTable)'))
        row['name'] as String,
    };
    if (existing.contains('key_fingerprint')) return;
    await db.execute(
      'ALTER TABLE $syncMetaTable ADD COLUMN key_fingerprint TEXT',
    );
  }

  // ── v4 migration ──────────────────────────────────────────────────────────

  static Future<void> _upgradeToV4(DatabaseExecutor db) async {
    // Auto-verified habits: nullable verification-rule columns on `goals`
    // (null ⇒ manual habit). Additive, so plain ADD COLUMNs; existing rows get
    // NULLs. Synced rows carry these automatically — the sync engine serializes
    // whole rows (SELECT *), so no push/pull code changes are required.
    //
    // Idempotent: read the existing columns first and skip any already present.
    // A version round-trip (v4 → a downgrade silently stamps user_version to 3
    // → v4) re-enters this migration against a `goals` table that already has
    // these columns; a bare `ADD COLUMN` would then raise "duplicate column
    // name" and permanently fail every open. Skipping present columns makes the
    // re-run a harmless no-op that re-stamps user_version to 4, data intact.
    final existing = <String>{
      for (final row in await db.rawQuery('PRAGMA table_info(goals)'))
        row['name'] as String,
    };
    for (final col in const [
      'verify_provider TEXT',
      'verify_metric TEXT',
      'verify_comparator TEXT',
      'verify_threshold REAL',
      'verify_unit TEXT',
    ]) {
      if (existing.contains(col.split(' ').first)) continue;
      await db.execute('ALTER TABLE goals ADD COLUMN $col');
    }
  }

  // ── v3 migration ──────────────────────────────────────────────────────────

  static Future<void> _upgradeToV3(DatabaseExecutor db) async {
    // macro_goal_categories gained updated_at for per-record last-write-wins.
    // ADD COLUMN can't be NOT NULL without a default; backfill from created_at.
    await db.execute(
      'ALTER TABLE macro_goal_categories ADD COLUMN updated_at TEXT',
    );
    await db.execute(
      'UPDATE macro_goal_categories SET updated_at = created_at '
      'WHERE updated_at IS NULL',
    );
    await createSyncObjects(db);
  }

  // ── v2 migration (unchanged; preserved from the original schema) ───────────

  static Future<void> _upgradeToV2(DatabaseExecutor db) async {
    // Widen long_term_goals.week_number CHECK from 1..6 to 1..53 to match cloud
    // schema.sql. SQLite can't ALTER a CHECK constraint, so rebuild the table.
    // Nothing references long_term_goals via FK, so rename/copy/drop is safe;
    // existing rows (week-of-month, always <= 6) all satisfy the new bound.
    await db.execute(
      'ALTER TABLE long_term_goals RENAME TO long_term_goals_old',
    );
    await db.execute(_longTermGoalsTableDdl);
    await db.execute('''
INSERT INTO long_term_goals (
  id, user_id, title, status, type, year, month, week_number, quarter,
  color, category_key, created_at, updated_at, category_id
)
SELECT
  id, user_id, title, status, type, year, month, week_number, quarter,
  color, category_key, created_at, updated_at, category_id
FROM long_term_goals_old
''');
    await db.execute('DROP TABLE long_term_goals_old');
    for (final ddl in _longTermGoalsIndexes) {
      await db.execute(ddl);
    }
  }

  // ── Core user-data tables ──────────────────────────────────────────────────

  /// DDL for `long_term_goals`. Shared between [createCoreTables] and the v2
  /// upgrade so the CHECK constraints can't drift between fresh installs and
  /// migrated databases.
  static const String _longTermGoalsTableDdl = '''
CREATE TABLE long_term_goals (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'completed', 'failed')),
  type TEXT NOT NULL
    CHECK (type IN ('lifetime', 'annual', 'quarterly', 'monthly', 'weekly')),
  year INTEGER,
  month INTEGER CHECK (month >= 1 AND month <= 12),
  -- week_number is a week-of-month index (the app emits 1..6 via weeksInMonth).
  -- The 1..53 bound matches cloud schema.sql to avoid cross-backend CHECK drift.
  week_number INTEGER CHECK (week_number >= 1 AND week_number <= 53),
  quarter INTEGER CHECK (quarter >= 1 AND quarter <= 4),
  -- color is legacy/vestigial: macro goals derive their color from their
  -- category (GoalCategory.color); the app never writes this column.
  color TEXT,
  category_key TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  category_id TEXT REFERENCES macro_goal_categories(id) ON DELETE SET NULL
)
''';

  static const List<String> _longTermGoalsIndexes = [
    'CREATE INDEX idx_ltg_user_type_year ON long_term_goals (user_id, type, year)',
    'CREATE INDEX idx_ltg_user_status ON long_term_goals (user_id, status)',
  ];

  static Future<void> createCoreTables(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE profiles (
  id TEXT PRIMARY KEY,
  username TEXT,
  full_name TEXT,
  avatar_url TEXT,
  language TEXT NOT NULL DEFAULT 'it',
  theme_mode TEXT NOT NULL DEFAULT 'dark'
    CHECK (theme_mode IN ('dark', 'light', 'system')),
  accent_color TEXT NOT NULL DEFAULT '#FFFFFF',
  pref_glass_effects INTEGER NOT NULL DEFAULT 1,
  pref_default_calendar_view TEXT NOT NULL DEFAULT 'settimana',
  pref_start_week_on_monday INTEGER NOT NULL DEFAULT 1,
  pref_show_weekend INTEGER NOT NULL DEFAULT 1,
  pref_haptic_feedback INTEGER NOT NULL DEFAULT 1,
  pref_time_format_24h INTEGER NOT NULL DEFAULT 1,
  pref_ai_suggestions INTEGER NOT NULL DEFAULT 0,
  pref_focus_mode INTEGER NOT NULL DEFAULT 0,
  pref_milestones INTEGER NOT NULL DEFAULT 1,
  pref_deep_work_insights INTEGER NOT NULL DEFAULT 0,
  is_pro INTEGER NOT NULL DEFAULT 1,
  pro_expires_at TEXT,
  notif_habit_reminders INTEGER NOT NULL DEFAULT 1,
  notif_goal_deadlines INTEGER NOT NULL DEFAULT 1,
  notif_ai_insights INTEGER NOT NULL DEFAULT 0,
  notif_weekly_reports INTEGER NOT NULL DEFAULT 0,
  notif_evening_review INTEGER NOT NULL DEFAULT 1,
  biometric_lock INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  date_of_birth TEXT,
  morning_brief_time TEXT DEFAULT '09:00',
  evening_review_time TEXT DEFAULT '21:00',
  terms_accepted_at TEXT,
  sentry_consent INTEGER NOT NULL DEFAULT 0,
  private_ai_external_consent INTEGER NOT NULL DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE goals (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  color TEXT NOT NULL,
  icon TEXT,
  frequency_days TEXT,
  start_date TEXT NOT NULL,
  end_date TEXT,
  display_order INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  reminder_time TEXT,
  -- Auto-verified habits (v4): the verification rule, all null ⇒ manual habit.
  -- Intentionally unconstrained so a future provider/metric from a newer client
  -- round-trips through sync instead of being rejected.
  verify_provider TEXT,
  verify_metric TEXT,
  verify_comparator TEXT,
  verify_threshold REAL,
  verify_unit TEXT
)
''');

    await db.execute('''
CREATE TABLE goal_logs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  goal_id TEXT NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('done', 'missed', 'skipped')),
  value REAL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  streak INTEGER DEFAULT 0,
  UNIQUE(goal_id, date)
)
''');

    await db.execute(_longTermGoalsTableDdl);

    await db.execute('''
CREATE TABLE daily_moods (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  mood_score INTEGER NOT NULL CHECK (mood_score >= 0 AND mood_score <= 10),
  energy_score INTEGER NOT NULL CHECK (energy_score >= 0 AND energy_score <= 10),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(user_id, date)
)
''');

    // NOTE: goal_category_settings mirrors the cloud table for schema parity
    // and future iCloud-sync completeness, but the app does not currently read
    // or write its `mappings` (no provider touches it — category data lives in
    // macro_goal_categories). It is seeded once in _ensureProfile and wiped by
    // deleteAllPrivateData. Kept intentionally; if the cloud feature is ever
    // wired in, the storage is already here.
    await db.execute('''
CREATE TABLE goal_category_settings (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  mappings TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');

    // macro_goal_categories.updated_at (added in v3) supports per-record
    // last-write-wins for iCloud sync. Fresh installs get it inline here; v2
    // databases get it via _upgradeToV3's ALTER.
    await db.execute('''
CREATE TABLE macro_goal_categories (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  archived_at TEXT,
  UNIQUE(user_id, name)
)
''');

    await db.execute(
      'CREATE INDEX idx_goals_user_order ON goals (user_id, display_order)',
    );
    await db.execute(
      'CREATE INDEX idx_goal_logs_user_date ON goal_logs (user_id, date DESC)',
    );
    for (final ddl in _longTermGoalsIndexes) {
      await db.execute(ddl);
    }
    await db.execute(
      'CREATE INDEX idx_moods_user_date ON daily_moods (user_id, date DESC)',
    );
    await db.execute(
      'CREATE INDEX macro_goal_categories_active_idx ON macro_goal_categories (user_id, created_at) WHERE archived_at IS NULL',
    );
    await db.execute(_userSettingsTableDdl);
    await db.execute(
      'CREATE INDEX idx_user_settings_owner ON user_settings (user_id)',
    );
  }

  // ── Sync bookkeeping (v3) ───────────────────────────────────────────────────

  static Future<void> createSyncObjects(DatabaseExecutor db) async {
    await createSyncTables(db);
    await createSyncTriggers(db);
  }

  static Future<void> createSyncTables(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE $syncStateTable (
  record_name TEXT PRIMARY KEY,
  table_name TEXT NOT NULL,
  row_id TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_synced_at TEXT,
  dirty INTEGER NOT NULL DEFAULT 1,
  deleted INTEGER NOT NULL DEFAULT 0,
  last_error TEXT
)
''');
    await db.execute(
      'CREATE INDEX idx_sync_state_dirty ON $syncStateTable (dirty) '
      'WHERE dirty = 1',
    );
    await db.execute('''
CREATE TABLE $syncMetaTable (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  server_change_token TEXT,
  last_full_sync_at TEXT,
  pending_zone_wipe INTEGER NOT NULL DEFAULT 0,
  -- Fingerprint of the E2E key this device last synced with (v5). A change
  -- means records parked as undecryptable might now open, so the engine drops
  -- the change token and re-fetches the whole zone.
  key_fingerprint TEXT,
  -- Schema version at the last sync (v6). An INCREASE means this build now
  -- understands tables it previously had to quarantine records for, so those
  -- records must be re-fetched — the token has already advanced past them and
  -- CloudKit will not replay them on its own.
  schema_version INTEGER
)
''');
    await db.execute('INSERT OR IGNORE INTO $syncMetaTable (id) VALUES (1)');
  }

  /// Per-table triggers that keep [syncStateTable] current. INSERT/UPDATE mark
  /// the row dirty (needs push); DELETE writes a tombstone (dirty + deleted).
  ///
  /// The sync engine clears `dirty` itself after a successful push or after
  /// applying a pulled record — that is the ONLY place `dirty` is cleared, which
  /// prevents the apply step from re-marking pulled rows and ping-ponging.
  ///
  /// `COALESCE(NEW.updated_at, <now>)` guards the one nullable case
  /// (`macro_goal_categories.updated_at` on legacy rows) so sync_state.updated_at
  /// (NOT NULL) is always satisfied.
  static Future<void> createSyncTriggers(DatabaseExecutor db) async {
    // Skip tables that do not exist YET. This runs from the v3 migration, which
    // predates later additive tables (`user_settings` arrives in v6), so a
    // database migrating 2 -> 6 reaches here before those tables are created.
    // Creating a trigger on a missing table is a hard error that would wedge the
    // whole upgrade chain. Each later migration installs its own table's
    // triggers, so nothing is lost by skipping here.
    final present = <String>{
      for (final r in await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
        r['name'] as String,
    };
    for (final t in syncedTables) {
      if (!present.contains(t)) continue;
      await _createTriggersFor(db, t);
    }
  }

  /// The dirty/tombstone trigger set for ONE table. Split out so a migration
  /// that adds a single synced table can install just its triggers — running the
  /// whole loop would fail re-creating the ones that already exist.
  static Future<void> _createTriggersFor(DatabaseExecutor db, String t) async {
    const nowExpr = "strftime('%Y-%m-%dT%H:%M:%fZ','now')";
    const upsertCols =
        '(record_name, table_name, row_id, updated_at, dirty, deleted)';
    String writeTrigger(String suffix, String event) =>
        '''
CREATE TRIGGER ${t}_sync_$suffix AFTER $event ON $t BEGIN
  INSERT INTO $syncStateTable $upsertCols
  VALUES ('$t:'||NEW.id, '$t', NEW.id, COALESCE(NEW.updated_at, $nowExpr), 1, 0)
  ON CONFLICT(record_name) DO UPDATE SET
    updated_at=COALESCE(NEW.updated_at, $nowExpr), dirty=1, deleted=0;
END;
''';
    await db.execute(writeTrigger('ai', 'INSERT'));
    await db.execute(writeTrigger('au', 'UPDATE'));
    await db.execute('''
CREATE TRIGGER ${t}_sync_ad AFTER DELETE ON $t BEGIN
  INSERT INTO $syncStateTable $upsertCols
  VALUES ('$t:'||OLD.id, '$t', OLD.id, $nowExpr, 1, 1)
  ON CONFLICT(record_name) DO UPDATE SET
    updated_at=$nowExpr, dirty=1, deleted=1;
END;
''');
  }
}
