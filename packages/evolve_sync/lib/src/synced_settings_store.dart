import 'package:sqflite_common/sqlite_api.dart';

import 'private_db_schema.dart';

/// Reads and writes the user's synced settings.
///
/// Lives in the shared package rather than in either app so the two clients
/// cannot drift: a key spelled differently, a boolean encoded differently, or a
/// different rule for which store wins would each produce a setting that
/// silently refuses to travel between devices — the failure this whole table was
/// introduced to eliminate.
///
/// ## Dual-write, for one release
///
/// Every write goes to BOTH the per-key `user_settings` row AND the legacy
/// `profiles` column. macOS ships directly while iOS goes through App Store
/// review, so the two apps CANNOT land simultaneously: there is guaranteed to be
/// a window where one device writes v6 rows and the other still reads v5
/// columns. Dual-writing keeps the lagging device working and keeps its edits
/// visible to the upgraded one.
///
/// Reads prefer the `user_settings` row and fall back to the column. The
/// precedence is deliberate and one-directional: **a row always wins, even if
/// the column looks newer.** The inverse rule would let a stale column resurrect
/// a setting the user had deliberately cleared on a v6 device, and "the setting
/// I turned off came back" is far worse than "an edit from my not-yet-updated
/// device took a sync to arrive".
///
/// Drop the legacy half once both apps are on v6 in the field.
class SyncedSettingsStore {
  final Database _db;
  SyncedSettingsStore(this._db);

  /// Deterministic row id: BOTH devices derive the same id for the same
  /// setting, so they converge on ONE CloudKit record and ordinary
  /// last-write-wins resolves them — no natural-key merge required.
  ///
  /// The `naturalKeys` entry for `user_settings` stays as a safety net for rows
  /// minted before this convention (or by any future client that ignores it),
  /// but in the normal case it never has to fire.
  static String rowId(String owner, String key) => '$owner:$key';

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  /// Whether the legacy `profiles` column for [key] still exists on this
  /// database. Cached per instance — the schema is fixed once the DB is open.
  final Map<String, bool> _legacyColumnCache = {};

  Future<bool> _hasLegacyColumn(String key) async {
    final cached = _legacyColumnCache[key];
    if (cached != null) return cached;
    final cols = {
      for (final r in await _db.rawQuery('PRAGMA table_info(profiles)'))
        r['name'] as String,
    };
    for (final k in PrivateDbSchema.syncedSettingKeys) {
      _legacyColumnCache[k] = cols.contains(k);
    }
    return _legacyColumnCache[key] ?? false;
  }

  /// Every synced setting for [owner], row-first with a legacy-column fallback.
  /// Keys absent from both stores are omitted, so a caller can distinguish
  /// "never set" from "set to null" and apply its own default.
  Future<Map<String, String?>> readAll(String owner) async {
    final out = <String, String?>{};

    // Legacy columns first, so rows overwrite them rather than the reverse.
    final profile = await _db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [owner],
      limit: 1,
    );
    if (profile.isNotEmpty) {
      for (final k in PrivateDbSchema.syncedSettingKeys) {
        final v = profile.first[k];
        if (v != null) out[k] = '$v';
      }
    }

    for (final r in await _db.query(
      'user_settings',
      columns: ['key', 'value'],
      where: 'user_id = ?',
      whereArgs: [owner],
    )) {
      final k = r['key'] as String;
      // Unknown keys are ignored rather than surfaced: a NEWER client may sync
      // a setting this build has no concept of, and handing it to the app would
      // be meaningless at best.
      if (!PrivateDbSchema.syncedSettingKeys.contains(k)) continue;
      out[k] = r['value'] as String?;
    }
    return out;
  }

  Future<String?> read(String owner, String key) async =>
      (await readAll(owner))[key];

  /// Write one setting to both stores. [value] of null means "explicitly unset"
  /// — stored as a NULL value rather than by deleting the row, because a
  /// deletion emits a tombstone and a tombstone racing an edit from another
  /// device is precisely the resurrection problem per-key records avoid.
  Future<void> write(String owner, String key, String? value) =>
      writeAll(owner, {key: value});

  /// Write several settings at once. Each key is an INDEPENDENT record, so a
  /// batch here is a convenience only — it never couples the keys' fates the
  /// way the single `profiles` row did.
  Future<void> writeAll(String owner, Map<String, String?> values) async {
    if (values.isEmpty) return;
    final now = _nowIso();

    // Validate BEFORE opening the transaction: a throw from inside gets wrapped
    // in a DatabaseException, which buries the actual programming error.
    for (final k in values.keys) {
      if (!PrivateDbSchema.syncedSettingKeys.contains(k)) {
        throw ArgumentError(
          '"$k" is not in PrivateDbSchema.syncedSettingKeys — add it there '
          '(both apps read that list) or store it device-locally instead.',
        );
      }
    }

    // Compute legacy-column membership before opening the transaction; the
    // PRAGMA would otherwise run inside it on every call.
    final legacy = <String, bool>{};
    for (final k in values.keys) {
      legacy[k] = await _hasLegacyColumn(k);
    }

    await _db.transaction((txn) async {
      for (final e in values.entries) {
        final k = e.key;
        await txn.rawInsert(
          'INSERT INTO user_settings '
          '(id, user_id, key, value, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?) '
          'ON CONFLICT(user_id, key) DO UPDATE SET '
          'value = excluded.value, updated_at = excluded.updated_at',
          [rowId(owner, k), owner, k, e.value, now, now],
        );
      }

      // Legacy half of the dual-write. Bumping profiles.updated_at is required:
      // without it the row is not newer than a peer's copy and the legacy
      // values would never reach a device still reading columns.
      //
      // NULL is deliberately skipped: most of these `profiles` columns are
      // NOT NULL with a default, so "explicitly unset" is simply not
      // representable there and writing it would abort the whole transaction.
      // The per-key row carries the null, and it is the row that wins on read —
      // so a cleared setting still reads as cleared on any v6 device. A device
      // still reading columns keeps the last non-null value, which is the best
      // the old shape can express.
      final legacyValues = {
        for (final e in values.entries)
          if (legacy[e.key] == true && e.value != null) e.key: e.value,
      };
      if (legacyValues.isNotEmpty) {
        await txn.update(
          'profiles',
          {...legacyValues, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [owner],
        );
      }
    });
  }

  // ── Typed helpers ─────────────────────────────────────────────────────────
  //
  // Values are stored as TEXT in one canonical encoding shared by both apps.
  // Booleans are '0'/'1' to match how they are already persisted on `profiles`,
  // so the dual-write does not have to translate between representations — a
  // translation layer is exactly where an encoding mismatch would hide.

  static String encodeBool(bool v) => v ? '1' : '0';

  static bool? decodeBool(String? v) =>
      v == null ? null : (v == '1' || v.toLowerCase() == 'true');

  static String encodeInt(int v) => '$v';

  static int? decodeInt(String? v) => v == null ? null : int.tryParse(v);
}
