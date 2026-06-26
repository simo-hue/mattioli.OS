import 'dart:typed_data';

import 'cloudkit_bridge.dart';
import 'private_db_schema.dart';
import 'sync_crypto.dart';
import 'sync_key_store.dart';
import 'sync_local_store.dart';
import 'app_logger.dart';

class SyncResult {
  final int pushed;
  final int applied;
  final int skipped;
  final bool wiped;

  /// Set when sync didn't run because iCloud isn't available; local mode is
  /// unaffected.
  final CloudAccountStatus? blockedBy;

  const SyncResult({
    this.pushed = 0,
    this.applied = 0,
    this.skipped = 0,
    this.wiped = false,
    this.blockedBy,
  });

  bool get ran => blockedBy == null;
}

/// The Dart-side sync brain: pushes dirty rows, pulls remote changes, resolves
/// conflicts by last-write-wins on edit time, and applies tombstones — all over
/// an abstract [CloudKitBridge] (real on device, fake in tests). Re-key/identity
/// merge and avatar assets are layered on in later steps.
class SyncEngine {
  final SyncLocalStore store;
  final CloudKitBridge bridge;
  final SyncCrypto crypto;

  SyncEngine({
    required this.store,
    required this.bridge,
    required this.crypto,
  });

  /// FK-safe apply order: parents before children (profiles → goals/categories →
  /// logs/macro-goals/moods). Applied across the whole pulled batch.
  static const Map<String, int> _applyPriority = {
    'profiles': 0,
    'goals': 1,
    'macro_goal_categories': 1,
    'goal_category_settings': 1,
    'goal_logs': 2,
    'long_term_goals': 2,
    'daily_moods': 2,
  };

  /// Reject timestamps more than this far in the future (clock-skew guard, Q10).
  static const int _maxFutureSkewMs = 5 * 60 * 1000;

  /// Turn sync on for this device: obtain the shared E2E key, establish/adopt
  /// the canonical owner (re-keying local data to it on a second device so
  /// everything unions under one identity), mark existing data for upload, then
  /// run the first sync. Returns [SyncResult.blockedBy] if iCloud is unavailable.
  Future<SyncResult> enable({
    required SyncKeyStore keys,
    required String localOwner,
  }) async {
    final status = await bridge.accountStatus();
    if (status != CloudAccountStatus.available) {
      return SyncResult(blockedBy: status);
    }
    final key = await keys.getOrCreateKey();
    final canonical = await keys.getOrSetCanonicalOwner(localOwner);
    if (canonical != localOwner) {
      // Second device: unify identity (also clears+rebuilds sync_state dirty).
      await store.reKeyOwner(localOwner, canonical);
    } else {
      // First device: upload the data that pre-dates sync.
      await store.markAllDirty();
    }
    return syncNow(key);
  }

  Future<SyncResult> syncNow(Uint8List key) async {
    final status = await bridge.accountStatus();
    if (status != CloudAccountStatus.available) {
      return SyncResult(blockedBy: status);
    }

    // A queued full-reset wins over everything: wipe the cloud zone, then stop.
    if (await store.pendingZoneWipe()) {
      await bridge.deleteZone();
      await store.setPendingZoneWipe(false);
      await store.setChangeToken(null);
      return const SyncResult(wiped: true);
    }

    await bridge.ensureZone();
    // Pull BEFORE push: a newer remote record overwrites the local copy and
    // clears its dirty flag, so a stale local edit is never pushed over it. With
    // the native savePolicy of `.allKeys` (overwrite), this ordering is what
    // enforces last-write-wins — pushing first could clobber a newer cloud
    // record. It also gives a freshly-enabled second device the canonical data
    // before it uploads its own.
    final pull = await _pull(key);
    final pushed = await _push(key);
    await store.setLastFullSync(_nowIso());
    return SyncResult(pushed: pushed, applied: pull.$1, skipped: pull.$2);
  }

  Future<int> _push(Uint8List key) async {
    final entries = await store.dirtyEntries();
    if (entries.isEmpty) return 0;

    final records = <CloudRecord>[];
    for (final e in entries) {
      if (e.deleted) {
        records.add(_tombstone(e.recordName, e.tableName, e.updatedAt));
        continue;
      }
      final row = await store.readRow(e.tableName, e.rowId);
      if (row == null) {
        // Row vanished under us — push a tombstone instead.
        records.add(_tombstone(e.recordName, e.tableName, e.updatedAt));
        continue;
      }
      final data = Map<String, dynamic>.from(row);
      // Drop device-local columns (e.g. profiles.avatar_url, a local file path)
      // so they never overwrite another device's local value.
      for (final col in PrivateDbSchema.localOnlyColumns[e.tableName] ?? const []) {
        data.remove(col);
      }
      records.add(CloudRecord(
        recordName: e.recordName,
        tableName: e.tableName,
        updatedAtMs: _ms((row['updated_at'] as String?) ?? e.updatedAt),
        deleted: false,
        payload: crypto.encryptJson(data, key),
      ));
    }

    final outcome = await bridge.saveRecords(records);
    final at = _nowIso();
    for (final rn in outcome.saved) {
      await store.markSynced(rn, at);
    }
    for (final err in outcome.errors) {
      await store.markError(err.recordName, err.code);
      AppLogger.error(
        '[CloudKit] Record push failed',
        err.code,
        null,
        {'recordName': err.recordName},
      );
    }
    // Conflicts (server has a newer version) are intentionally left dirty: the
    // pull below fetches the newer record and LWW-applies it, clearing dirty.
    return outcome.saved.length;
  }

  Future<(int, int)> _pull(Uint8List key) async {
    // Collect all changed records across pages, then apply FK-safely.
    final all = <CloudRecord>[];
    final originalToken = await store.changeToken();
    String? token = originalToken;
    while (true) {
      final out = await bridge.fetchChanges(token);
      all.addAll(out.records);
      token = out.newToken;
      if (!out.moreComing) break;
    }
    all.sort((a, b) => (_applyPriority[a.tableName] ?? 9)
        .compareTo(_applyPriority[b.tableName] ?? 9));

    var applied = 0;
    var skipped = 0;
    var deferredFutureRecord = false;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final rec in all) {
      if (rec.updatedAtMs > nowMs + _maxFutureSkewMs) {
        // Clock-skew guard: another device's clock is ahead of ours. DEFER this
        // record rather than dropping it — see the token handling below.
        deferredFutureRecord = true;
        skipped++;
        continue;
      }
      if (await _applyRemote(rec, key)) {
        applied++;
      } else {
        skipped++;
      }
    }
    // Only advance the change token if nothing was deferred. A future-skewed
    // record must be re-fetched on a later sync (once our clock catches up),
    // so we hold the token at its pre-fetch value instead of stepping past the
    // record and losing it forever. Re-applying the already-applied records on
    // the next pull is harmless (LWW skips them).
    await store.setChangeToken(deferredFutureRecord ? originalToken : token);
    return (applied, skipped);
  }

  Future<bool> _applyRemote(CloudRecord rec, Uint8List key) async {
    final local = await store.stateOf(rec.recordName);
    final localMs = local == null ? -1 : _ms(local.updatedAt);
    // Strict >: equal timestamps keep the local copy. Exact-millisecond
    // conflicts on the same record are vanishingly rare for a single user.
    if (rec.updatedAtMs <= localMs) return false;

    final rowId = rec.recordName.substring(rec.tableName.length + 1);
    try {
      if (rec.deleted) {
        await store.applyDelete(
          rec.tableName,
          rowId,
          rec.recordName,
          _iso(rec.updatedAtMs),
          _nowIso(),
        );
      } else {
        final row = crypto.decryptJson(rec.payload!, key);
        await store.applyUpsert(
          rec.tableName,
          rec.recordName,
          Map<String, Object?>.from(row),
          _nowIso(),
        );
      }
      return true;
    } catch (e, stack) {
      await store.markError(rec.recordName, e.toString());
      AppLogger.error(
        '[CloudKit] Record apply failed',
        e,
        stack,
        {'recordName': rec.recordName, 'tableName': rec.tableName},
      );
      return false;
    }
  }

  CloudRecord _tombstone(String recordName, String tableName, String updatedAt) =>
      CloudRecord(
        recordName: recordName,
        tableName: tableName,
        updatedAtMs: _ms(updatedAt),
        deleted: true,
        payload: Uint8List(0),
      );

  int _ms(String iso) => DateTime.tryParse(iso)?.millisecondsSinceEpoch ?? 0;
  String _iso(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
  String _nowIso() => DateTime.now().toUtc().toIso8601String();
}
