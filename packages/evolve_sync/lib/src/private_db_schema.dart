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
  static const int version = 3;

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
  ];

  static const String syncStateTable = 'sync_state';
  static const String syncMetaTable = 'sync_meta';

  /// Columns whose values are device-local and MUST NOT cross the sync boundary.
  /// `profiles.avatar_url` is a local filesystem path to the cached avatar — the
  /// image itself rides along as a CloudKit asset, but the path is meaningless
  /// (and different) on another device. The engine strips these from the push
  /// payload and the local store preserves the existing local value on apply.
  static const Map<String, List<String>> localOnlyColumns = {
    'profiles': ['avatar_url'],
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
  reminder_time TEXT
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
  pending_zone_wipe INTEGER NOT NULL DEFAULT 0
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
    const nowExpr = "strftime('%Y-%m-%dT%H:%M:%fZ','now')";
    for (final t in syncedTables) {
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
}
