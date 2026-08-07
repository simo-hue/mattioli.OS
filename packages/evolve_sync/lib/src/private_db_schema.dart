import 'package:sqflite_common/sqlite_api.dart';

import 'order_key.dart';
import 'private_db_open_failure.dart';

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
  /// - v7: add `goals.verify_effective_from` — the day the goal's current
  ///   verification rule took effect (D10, forward-only rule edits). Nullable;
  ///   null ⇒ fall back to `start_date`, so habits that predate this column keep
  ///   their existing behavior until the rule is next edited. Reconcile never
  ///   rewrites days before this date, so editing a threshold no longer silently
  ///   re-derives recent history.
  /// - v8: add `goals.verify_conditions` — a JSON `{v,op,conditions:[...]}`
  ///   joining 2–3 conditions for a compound verifiable habit (steps OR/AND
  ///   exercise, …). When set, the flat `verify_*` columns are NULL, so a
  ///   pre-compound client reads the habit as manual and never mis-verifies it.
  ///   Null ⇒ an ordinary single-rule or manual habit (the flat columns rule).
  /// - v9: quantitative habit targets. Adds `goals.target` (a versioned JSON
  ///   `{v,src,dir,per,agg,amount,unit,step,input}` envelope — see
  ///   `package:evolve_targets`) and the new `goal_progress` table holding ONE
  ///   accumulated number per habit-day.
  ///
  ///   Progress deliberately does NOT live on `goal_logs`. Two hard reasons:
  ///   `goal_logs.status` is CHECK-constrained to ('done','missed','skipped') in
  ///   both backends, so a part-done day has no honest status to carry — and
  ///   `goal_logs.value` is nulled by three separate guards, one of which
  ///   (mobile's REPLACE-based setHabitLog) clears it intentionally on every
  ///   manual toggle. Keeping progress in its own table means `goal_logs` stays
  ///   exactly what it is — the VERDICT record — so all 11 Supabase analytics
  ///   objects, both Dart mirrors, every heatmap and every older client keep
  ///   working untouched, and a half-finished day stays out of every rate
  ///   denominator while still rendering its ring.
  /// - v10: cumulative numeric macro goals. Adds four nullable columns to
  ///   `long_term_goals`: `target_amount` (the number to reach), `target_unit`
  ///   (a `TargetUnit` wire name — count/minutes/…), `progress_amount` (the
  ///   STORED value for a manual-entry numeric goal) and `linked_goal_id` (the
  ///   habit whose daily `goal_progress` feeds this goal, **ON DELETE SET
  ///   NULL**). Null `target_amount` ⇒ today's ordinary boolean macro goal, so
  ///   every pre-v10 row reads unchanged. Progress is DERIVED (summed from the
  ///   linked habit over the goal's period) when `linked_goal_id` is set, and
  ///   STORED (`progress_amount`) otherwise. SET NULL rather than CASCADE so
  ///   deleting the linked habit un-links the goal instead of destroying it; the
  ///   delete path first snapshots the derived total into `progress_amount` so a
  ///   "500 km" goal that reached 320 keeps showing 320 as a now-manual value.
  ///   Unconstrained (like `verify_*`/`target`) so a future unit round-trips.
  /// - v11: forward-only quantitative-target edits. Adds one nullable
  ///   `goals.target_effective_from` date — the day the goal's current `target`
  ///   took effect, the exact analogue of `verify_effective_from` (v7) for the
  ///   verification rule. NULL ⇒ fall back to `start_date`. The manual-target
  ///   end-of-day sweep never rewrites days before this date, so editing a
  ///   target's amount (or changing a habit's tracking class) applies forward
  ///   instead of retroactively re-deriving past `done`/`missed` verdicts.
  ///   Additive and unconstrained for the same round-trip reason as `verify_*`.
  static const int version = 12;

  /// The user-data tables whose rows sync to iCloud. Each gets dirty/tombstone
  /// triggers that maintain [syncStateTable]. (Order matters for nothing here,
  /// but mirrors the create order.)
  static const List<String> syncedTables = [
    'profiles',
    'goals',
    'goal_logs',
    'goal_progress',
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
    if (oldVersion < 7) {
      await _upgradeToV7(db);
    }
    if (oldVersion < 8) {
      await _upgradeToV8(db);
    }
    if (oldVersion < 9) {
      await _upgradeToV9(db);
    }
    if (oldVersion < 10) {
      await _upgradeToV10(db);
    }
    if (oldVersion < 11) {
      await _upgradeToV11(db);
    }
    if (oldVersion < 12) {
      await _upgradeToV12(db);
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
  ///
  /// The exception is TYPED ([PrivateDbSchemaTooNewException]) rather than a
  /// bare `StateError`. That distinction is load-bearing, not cosmetic: an
  /// untyped throw fell into the same catch-all as every other open failure and
  /// put the user on a generic error screen whose only state-changing button
  /// PERMANENTLY DELETED the database — over data this very method has just
  /// established is intact and decryptable. The release that first moves the
  /// private schema v6 → v11 makes this reachable for anyone who installs a
  /// previous build from TestFlight, so it must arrive at the UI as its own
  /// state with no destructive action attached.
  static Future<void> onDowngrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    throw PrivateDbSchemaTooNewException(
      storedVersion: oldVersion,
      knownVersion: newVersion,
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

  // ── v10 migration ─────────────────────────────────────────────────────────

  /// The four columns v10 adds to `long_term_goals`, in DDL form. Declared once
  /// so the fresh-install DDL ([_longTermGoalsTableDdl]) and this additive
  /// migration cannot drift on type or FK behaviour.
  ///
  /// `linked_goal_id` carries a `REFERENCES goals(id) ON DELETE SET NULL` clause
  /// even when added via `ALTER TABLE ADD COLUMN` — SQLite permits a REFERENCES
  /// clause on an added column precisely because its default is NULL, so no
  /// existing row can violate it. SET NULL (not CASCADE): deleting the linked
  /// habit un-links the goal, it does not delete it.
  static const List<String> _macroTargetColumnsDdl = [
    'target_amount REAL',
    'target_unit TEXT',
    'progress_amount REAL',
    'linked_goal_id TEXT REFERENCES goals(id) ON DELETE SET NULL',
  ];

  /// v12: fractional habit ordering.
  ///
  /// Adds `order_key` (REAL) and `order_key_updated_at` (TEXT) to `goals` and
  /// BACKFILLS them from the existing `display_order`, tie-broken by
  /// `created_at` then `id` so two devices computing this independently agree
  /// wherever their inputs already agree.
  ///
  /// Backfilling from `display_order` rather than from `created_at` alone is
  /// deliberate: a single-device user's hand-picked order is preserved exactly,
  /// and only rows whose `display_order` genuinely diverged between devices can
  /// move. Seeding from `created_at` would converge perfectly but reset the
  /// order of every user whose order was never broken.
  ///
  /// The rows are stamped with a fresh `updated_at` so the backfill PROPAGATES:
  /// the AFTER UPDATE trigger records `sync_state.updated_at` from the row's own
  /// value, and peers apply on strict greater-than, so an unbumped row would be
  /// pushed and then discarded everywhere. That is what makes the settling
  /// happen once, right after both apps update, rather than latently weeks later.
  ///
  /// Idempotent (a version round-trip re-enters it), like every migration here.
  static Future<void> _upgradeToV12(DatabaseExecutor db) async {
    final existing = <String>{
      for (final row in await db.rawQuery('PRAGMA table_info(goals)'))
        row['name'] as String,
    };
    if (existing.contains('order_key')) return;
    await db.execute('ALTER TABLE goals ADD COLUMN order_key REAL');
    await db.execute('ALTER TABLE goals ADD COLUMN order_key_updated_at TEXT');

    // Both of the following need `user_id`, which every real database has (it
    // is in the v1 DDL). Guard anyway, for the reason _upgradeToV10 guards a
    // missing table: a migration that ASSUMES its predecessor's side effects is
    // how an upgrade chain becomes unrecoverable, and an index or UPDATE naming
    // a column that is not there THROWS — wedging every future open.
    if (!existing.contains('user_id')) return;
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_goals_user_order_key '
      'ON goals (user_id, order_key)',
    );
    await backfillOrderKeys(db);
  }

  /// Assigns `order_key` to every goal that has none, per owner, following the
  /// order the app currently displays (`display_order ASC, created_at ASC`,
  /// with `id` as the final tie-break so the result is fully deterministic).
  ///
  /// Public so both apps can re-run it after an import, which writes goal rows
  /// straight into the table without keys.
  /// [bumpUpdatedAt] controls whether corrected rows also get a fresh
  /// `updated_at`. The MIGRATION needs it (the AFTER UPDATE trigger stamps
  /// sync_state from the row's own value, and peers apply on strict
  /// greater-than, so an unbumped row is pushed and then discarded). The IMPORT
  /// must NOT have it: `applyPrivateImportMerge` decides add/update/unchanged by
  /// comparing `updated_at`, so rewriting it here makes every later import lose
  /// its own last-write-wins comparison against the rows this just touched.
  static Future<void> backfillOrderKeys(
    DatabaseExecutor db, {
    bool bumpUpdatedAt = true,
  }) async {
    // Callable from the import path, which runs against whatever shape the
    // database happens to be — including a fixture or an older schema with no
    // `order_key`. Querying a missing column THROWS and would roll the whole
    // import back, so check first rather than assume the migration has run.
    final columns = <String>{
      for (final row in await db.rawQuery('PRAGMA table_info(goals)'))
        row['name'] as String,
    };
    if (!columns.contains('order_key') || !columns.contains('user_id')) return;

    final owners = await db.rawQuery(
      'SELECT DISTINCT user_id FROM goals WHERE order_key IS NULL',
    );
    for (final ownerRow in owners) {
      final owner = ownerRow['user_id'];
      // ONLY the keyless rows. Selecting every goal — which this did — meant a
      // single imported habit renumbered the WHOLE list from `display_order`,
      // and `display_order` is frozen at migration time because nothing
      // maintains it after v12. So importing a pre-v12 backup silently reverted
      // every reorder the user had made since, and nulled every
      // `order_key_updated_at` along with it, throwing away the field-level LWW
      // clock that lets a real drag defend its position against a peer.
      final rows = await db.rawQuery(
        'SELECT id FROM goals WHERE user_id = ? AND order_key IS NULL '
        'ORDER BY display_order IS NULL, display_order ASC, created_at ASC, id ASC',
        [owner],
      );
      if (rows.isEmpty) continue;
      // Keyless rows go AFTER everything already positioned, rather than
      // renumbering from 1: an import appends, it does not reshuffle.
      final maxRow = await db.rawQuery(
        'SELECT MAX(order_key) AS m FROM goals WHERE user_id = ?',
        [owner],
      );
      final base = (maxRow.first['m'] as num?)?.toDouble() ?? 0.0;
      final stamp = DateTime.now().toUtc().toIso8601String();
      for (var i = 0; i < rows.length; i++) {
        await db.update(
          'goals',
          {
            'order_key': base + kOrderKeyStep * (i + 1),
            // DELIBERATELY LEFT NULL. `order_key_updated_at` is the FIELD-level
            // LWW clock (SyncLocalStore._preserveNewerOrderKey), not a
            // propagation stamp — writing `now` here would be this migration
            // CLAIMING to have positioned every habit at migration time.
            //
            // iOS and macOS ship independently, so the second device routinely
            // migrates days after the first. Every drag made on device A in that
            // window carries an older stamp than B's migration, so B's backfill
            // would win the field merge on every row and the user's order would
            // snap back to B's stale `display_order` — then propagate to A.
            //
            // A fixed constant does not work either: the merge needs STRICTLY
            // greater, so two devices with equal stamps would each keep their own
            // keys and never converge. NULL is the honest value and resolves
            // both: a null LOCAL stamp means "never positioned here", so a peer's
            // key is adopted (devices converge); a null REMOTE stamp cannot prove
            // it is newer, so a real drag always defends its position against a
            // backfill.
            'order_key_updated_at': null,
            // See [bumpUpdatedAt].
            if (bumpUpdatedAt) 'updated_at': stamp,
          },
          where: 'id = ?',
          whereArgs: [rows[i]['id']],
        );
      }
    }
  }

  static Future<void> _upgradeToV11(DatabaseExecutor db) async {
    // Forward-only quantitative-target edits: one nullable `target_effective_from`
    // date on `goals`, the exact analogue of _upgradeToV7's verify_effective_from.
    // Additive, so a plain ADD COLUMN; existing rows get NULL, and the sweep
    // treats NULL as `start_date` — so upgraded databases keep their current
    // behaviour until the target is next edited (no surprise re-freezing of
    // history). Synced rows carry it automatically (whole-row serialization), so
    // no push/pull code changes are required.
    //
    // Idempotent for the same reason as _upgradeToV7: a version round-trip (v11 →
    // a downgrade silently stamps user_version to 10 → v11) re-enters this
    // against a `goals` table that already has the column, and a bare ADD COLUMN
    // would then raise "duplicate column name" and permanently fail every open.
    final existing = <String>{
      for (final row in await db.rawQuery('PRAGMA table_info(goals)'))
        row['name'] as String,
    };
    if (existing.contains('target_effective_from')) return;
    await db.execute(
      'ALTER TABLE goals ADD COLUMN target_effective_from TEXT',
    );
  }

  static Future<void> _upgradeToV10(DatabaseExecutor db) async {
    // Cumulative numeric macro goals: four additive nullable columns on
    // `long_term_goals`. Existing rows get NULL and read as ordinary boolean
    // macro goals (null target_amount). Synced rows carry the columns
    // automatically (the engine serializes whole rows), so no push/pull change.
    //
    // `long_term_goals` is a core table present since v1, so in the field it is
    // always here. Guard for its absence anyway (like _upgradeToV5 guards
    // sync_meta): a migration that ASSUMES its predecessor's side effects is
    // exactly how an upgrade chain becomes unrecoverable — and ALTERing a missing
    // table throws and would wedge every future open. When it is absent
    // createCoreTables declares these columns inline, so the table is born with
    // them and nothing is lost by skipping here.
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      ['long_term_goals'],
    );
    if (tables.isEmpty) return;

    // Idempotent for the same version-round-trip reason as _upgradeToV4: a
    // downgrade silently stamps user_version back, so a re-entered migration
    // must be a harmless no-op rather than a "duplicate column name" that wedges
    // every future open.
    final existing = <String>{
      for (final row in await db.rawQuery('PRAGMA table_info(long_term_goals)'))
        row['name'] as String,
    };
    for (final col in _macroTargetColumnsDdl) {
      if (existing.contains(col.split(' ').first)) continue;
      await db.execute('ALTER TABLE long_term_goals ADD COLUMN $col');
    }
  }

  // ── v9 migration ──────────────────────────────────────────────────────────

  /// DDL for the per-habit-day progress table. Shared between [createCoreTables]
  /// and the v9 upgrade so a fresh install and a migrated database cannot drift.
  ///
  /// `id` is DETERMINISTIC — `'<goal_id>:<date>'`, the same trick `user_settings`
  /// uses. That is not cosmetic. With random ids, two devices logging progress
  /// for the same habit-day mint two rows for one natural key, and the pull's
  /// natural-key merge resolves that by DELETING the loser and tombstoning it.
  /// A shared id makes the collision an ordinary row-level last-write-wins
  /// instead: still lossy for simultaneous edits (see below), but never a
  /// deletion, and never a tombstone that races back to the authoring device.
  ///
  /// `amount` is the total accumulated for the period so far, not a delta. The
  /// engine is a whole-row last-write-wins with no column-aware merge, so two
  /// devices incrementing the same day inside one sync window keep the later
  /// write rather than summing — documented and accepted for v1; the increment
  /// affordance is single-device by design.
  ///
  /// `source` is unconstrained by deliberate policy, matching `verify_provider`:
  /// a fill source added by a newer client must round-trip through this device
  /// rather than be rejected, because a rejected row is quarantined and the
  /// user's number would simply vanish until they upgrade.
  static const String _goalProgressTableDdl = '''
CREATE TABLE goal_progress (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  goal_id TEXT NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  amount REAL NOT NULL,
  source TEXT NOT NULL DEFAULT 'manual',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(goal_id, date)
)
''';

  static const List<String> _goalProgressIndexes = [
    'CREATE INDEX idx_goal_progress_user_date ON goal_progress (user_id, date DESC)',
  ];

  /// The deterministic `goal_progress.id` for a habit-day. Declared HERE, beside
  /// the DDL, so both apps and the sync layer cannot disagree about it — a
  /// second spelling would reintroduce exactly the rival-row merge this format
  /// exists to prevent.
  static String goalProgressId(String goalId, String date) => '$goalId:$date';

  static Future<void> _upgradeToV9(DatabaseExecutor db) async {
    // Both halves are additive and independently idempotent, for the same
    // version-round-trip reason as _upgradeToV4: a downgrade silently stamps
    // user_version back, and a re-entered migration must be a harmless no-op
    // rather than a "duplicate column name" that wedges every future open.
    final existing = <String>{
      for (final row in await db.rawQuery('PRAGMA table_info(goals)'))
        row['name'] as String,
    };
    if (!existing.contains('target')) {
      await db.execute('ALTER TABLE goals ADD COLUMN target TEXT');
    }

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      ['goal_progress'],
    );
    if (tables.isEmpty) {
      await db.execute(_goalProgressTableDdl);
      for (final ddl in _goalProgressIndexes) {
        await db.execute(ddl);
      }
      // `goal_progress` is in [syncedTables], so it needs the dirty/tombstone
      // trigger set. Installed for THIS table alone — createSyncTriggers would
      // fail re-creating the ones that already exist. Mirrors the v6 path that
      // introduced `user_settings`, including the consequence that a peer still
      // on v8 quarantines these records until it upgrades, at which point the
      // `sync_meta.schema_version` increase re-fetches them.
      await _createTriggersFor(db, 'goal_progress');
    }
  }

  // ── v8 migration ──────────────────────────────────────────────────────────

  static Future<void> _upgradeToV8(DatabaseExecutor db) async {
    // Compound verifiable habits: one nullable JSON `verify_conditions` column on
    // `goals`. Additive, so a plain ADD COLUMN; existing rows get NULL and read
    // as single/manual via the flat verify_* columns — the compound-aware read
    // path only prefers verify_conditions when it is present and valid. Synced
    // rows carry it automatically (whole-row serialization), so no push/pull
    // change. Idempotent for the same version-round-trip reason as _upgradeToV4.
    final existing = <String>{
      for (final row in await db.rawQuery('PRAGMA table_info(goals)'))
        row['name'] as String,
    };
    if (existing.contains('verify_conditions')) return;
    await db.execute('ALTER TABLE goals ADD COLUMN verify_conditions TEXT');
  }

  // ── v7 migration ──────────────────────────────────────────────────────────

  static Future<void> _upgradeToV7(DatabaseExecutor db) async {
    // Forward-only verification-rule edits (D10): one nullable `effective_from`
    // date on `goals`. Additive, so a plain ADD COLUMN; existing rows get NULL,
    // and the wiring treats NULL as `start_date` — so upgraded databases keep
    // their current behavior until the rule is next edited (no surprise
    // re-freezing of history). Synced rows carry it automatically (the engine
    // serializes whole rows), so no push/pull code changes are required.
    //
    // Idempotent for the same reason as _upgradeToV4: a version round-trip (v7 →
    // a downgrade silently stamps user_version to 6 → v7) re-enters this against
    // a `goals` table that already has the column, and a bare ADD COLUMN would
    // then raise "duplicate column name" and permanently fail every open.
    final existing = <String>{
      for (final row in await db.rawQuery('PRAGMA table_info(goals)'))
        row['name'] as String,
    };
    if (existing.contains('verify_effective_from')) return;
    await db.execute(
      'ALTER TABLE goals ADD COLUMN verify_effective_from TEXT',
    );
  }

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
  category_id TEXT REFERENCES macro_goal_categories(id) ON DELETE SET NULL,
  -- Cumulative numeric macro goals (v10). NULL target_amount ⇒ an ordinary
  -- boolean macro goal (every row before v10). Progress is DERIVED (summed from
  -- the linked habit's goal_progress over this goal's period) when
  -- linked_goal_id is set, else STORED in progress_amount. target_unit is a
  -- TargetUnit wire name (count/minutes/hours/kilocalories/kilometers), left
  -- unconstrained so a newer client's unit round-trips. linked_goal_id is
  -- ON DELETE SET NULL: deleting the linked habit un-links (does not delete)
  -- this goal — the delete path snapshots the derived total into
  -- progress_amount first so the accumulated value survives as a manual one.
  target_amount REAL,
  target_unit TEXT,
  progress_amount REAL,
  linked_goal_id TEXT REFERENCES goals(id) ON DELETE SET NULL
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
  -- Fractional habit order (v12). A habit's position is a property of ITS OWN
  -- ROW — a value strictly between its neighbours — which is what makes the
  -- sync engine's per-row last-write-wins merge correct. `display_order` was a
  -- dense 0..n-1 sequence, i.e. a property of the whole COLLECTION, so one
  -- pulled row overwrote one habit's slot in isolation and left duplicates and
  -- holes for `created_at` to tie-break arbitrarily. Kept alongside
  -- display_order, which older builds still read.
  order_key REAL,
  -- When order_key was last set, for FIELD-level last-write-wins on that one
  -- column. Whole-row LWW would let an unrelated edit (a rename on another
  -- device, carrying its own older order_key) drag a habit back to a position
  -- the user already moved it out of. See SyncLocalStore.applyUpsert.
  order_key_updated_at TEXT,
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
  verify_unit TEXT,
  -- Forward-only rule edit anchor (v7): the day the current verification rule
  -- took effect. NULL ⇒ fall back to start_date. Reconcile never rewrites days
  -- before this date.
  verify_effective_from TEXT,
  -- Compound verifiable habits (v8): JSON {v,op,conditions:[...]} joining 2..3
  -- conditions. When set, the flat verify_* columns above are NULL. NULL here ⇒
  -- an ordinary single-rule or manual habit.
  verify_conditions TEXT,
  -- Quantitative target (v9): a versioned JSON envelope describing how much, of
  -- what, over which period, in which direction, filled by whom. NULL ⇒ an
  -- ordinary boolean habit, which is every habit that existed before v9.
  -- Unconstrained for the same reason as verify_*: a newer client's axis value
  -- must round-trip rather than be rejected. See `package:evolve_targets`.
  target TEXT,
  -- Forward-only target edit anchor (v11): the day the current `target` took
  -- effect. NULL ⇒ fall back to start_date. The manual-target sweep never
  -- rewrites days before this date, so editing a target's amount applies
  -- forward. Direct analogue of verify_effective_from (v7) for targets.
  target_effective_from TEXT
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

    await db.execute(_goalProgressTableDdl);

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
    // v12 reads order_key first; the legacy index stays for older builds, which
    // still sort by display_order.
    await db.execute(
      'CREATE INDEX idx_goals_user_order_key ON goals (user_id, order_key)',
    );
    await db.execute(
      'CREATE INDEX idx_goal_logs_user_date ON goal_logs (user_id, date DESC)',
    );
    for (final ddl in _goalProgressIndexes) {
      await db.execute(ddl);
    }
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
