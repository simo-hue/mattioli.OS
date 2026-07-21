import 'dart:typed_data';

import 'package:pointycastle/api.dart' show InvalidCipherTextException;

import 'cloudkit_bridge.dart';
import 'private_db_schema.dart';
import 'sync_avatar_store.dart';
import 'sync_crypto.dart';
import 'sync_key_store.dart';
import 'sync_local_store.dart';
import 'sync_logger.dart';

/// Outcome of applying ONE pulled record. Distinguishes a benign skip (we
/// already hold a newer/equal copy, the record isn't applyable on this app, it's
/// structurally malformed, or it was quarantined) from a real [failed] apply (a
/// transient DB error, a decrypt failure, a missing asset). A [failed] record
/// must HOLD the change token so it's retried on a later sync rather than
/// silently dropped — see [SyncEngine._pull].
///
/// The split turns on whether a RETRY could ever succeed: only a failure that
/// might resolve on its own earns the token-hold. A permanently-unapplyable
/// record is quarantined ([_ApplyOutcome.skipped]) precisely so it cannot pin
/// the token forever — see [SyncLocalStore.quarantineRecord].
/// [undecryptable] is deliberately distinct from [skipped]: both let the change
/// token advance, but only this one means "the user has a key problem". It is
/// counted separately so the caller can surface a real diagnosis instead of a
/// silent, permanently-empty sync.
enum _ApplyOutcome { applied, skipped, failed, undecryptable }

class SyncResult {
  final int pushed;
  final int applied;
  final int skipped;
  final bool wiped;

  /// Set when sync didn't run because iCloud isn't available; local mode is
  /// unaffected.
  final CloudAccountStatus? blockedBy;

  /// Set by [SyncEngine.enable] when the shared E2E key has synced to this
  /// device but the canonical-owner Keychain item hasn't yet. Enable is DEFERRED
  /// (not failed): retry on a later trigger once the owner propagates. The
  /// device deliberately does NOT self-elect a competing owner (split-identity
  /// guard), so no data is touched.
  final bool ownerPending;

  /// Set by [SyncEngine.enable] when this device has NO E2E key but the zone
  /// already holds records — i.e. another device enabled first and its key has
  /// not yet arrived through the iCloud Keychain. Enable is DEFERRED, never
  /// completed by minting a fresh key.
  ///
  /// Minting here is unrecoverable: the existing records were sealed with a key
  /// this device would then never adopt, so every one of them becomes permanent
  /// ciphertext garbage on EVERY device. Deferring costs the user a wait;
  /// minting costs them their history.
  final bool keyPending;

  /// Records the just-finished pull could not decrypt: they were sealed with a
  /// different sync key than this device holds. Non-zero means the devices are
  /// on divergent key lineages and this one cannot read the shared data — a
  /// condition that must reach the user, because every sync will otherwise
  /// report success while applying nothing.
  final int undecryptable;

  /// The canonical sync-owner id [SyncEngine.enable] resolved and (on a second
  /// device) re-keyed local rows onto. The service adopts THIS exact value as
  /// the device owner id, so its adoption can't diverge from a second Keychain
  /// read. Null on syncNow / blocked / deferred results.
  final String? canonicalOwner;

  const SyncResult({
    this.pushed = 0,
    this.applied = 0,
    this.skipped = 0,
    this.wiped = false,
    this.blockedBy,
    this.ownerPending = false,
    this.keyPending = false,
    this.undecryptable = 0,
    this.canonicalOwner,
  });

  bool get ran => blockedBy == null && !ownerPending && !keyPending;
}

/// The Dart-side sync brain: pushes dirty rows, pulls remote changes, resolves
/// conflicts by last-write-wins on edit time, and applies tombstones — all over
/// an abstract [CloudKitBridge] (real on device, fake in tests). Re-key/identity
/// merge and avatar assets are layered on in later steps.
class SyncEngine {
  final SyncLocalStore store;
  final CloudKitBridge bridge;
  final SyncCrypto crypto;
  final SyncLogger logger;

  /// File-side of avatar sync (app-provided). Null ⇒ avatar records are
  /// neither pushed nor applied (pulled ones are skipped).
  final SyncAvatarStore? avatarStore;

  SyncEngine({
    required this.store,
    required this.bridge,
    required this.crypto,
    this.avatarStore,
    this.logger = const SilentSyncLogger(),
  });

  /// FK-safe apply order: parents before children (profiles → goals/categories →
  /// logs/macro-goals/moods → the avatar, which rewrites profiles.avatar_url).
  /// Applied across the whole pulled batch.
  static const Map<String, int> _applyPriority = {
    'profiles': 0,
    'goals': 1,
    'macro_goal_categories': 1,
    'goal_category_settings': 1,
    'goal_logs': 2,
    'long_term_goals': 2,
    'daily_moods': 2,
    // Child of profiles, so it must not land before its parent.
    'user_settings': 2,
    PrivateDbSchema.avatarRecordTable: 3,
  };

  /// Added to a DELETED record's apply priority so every tombstone sorts after
  /// every upsert, whatever table it belongs to. Larger than any value in
  /// [_applyPriority] (including the `?? 9` fallback) so the two ranges cannot
  /// overlap as tables are added.
  static const int _deletePriorityBase = 100;

  /// Reject timestamps more than this far in the future (clock-skew guard, Q10).
  static const int _maxFutureSkewMs = 5 * 60 * 1000;

  /// Records per `saveRecords` call — see [_batches]. Apple documents no hard
  /// constant (the server bounds a modify operation by record count AND total
  /// request size, and returns `CKError.limitExceeded` with guidance to split
  /// and retry); 400 is the long-standing practical ceiling.
  static const int _maxRecordsPerBatch = 400;

  /// Cumulative encrypted-payload bytes per `saveRecords` call, covering the
  /// request-size half of the limit: row payloads are arbitrarily wide (a long
  /// goal description encrypts to a large blob), so a record count alone does
  /// not bound the request.
  static const int _maxPayloadBytesPerBatch = 2 * 1024 * 1024;

  /// Hard cap on delta-fetch pages per pull. A correct CloudKit bridge sets
  /// `moreComing` with a strictly-advancing token and terminates in a handful
  /// of pages; this only backstops a misbehaving/regressed bridge so the pull
  /// can't spin forever / grow unbounded in memory.
  static const int _maxFetchPages = 10000;

  /// Turn sync on for this device: obtain the shared E2E key, establish/adopt
  /// the canonical owner (re-keying local data to it on a second device so
  /// everything unions under one identity), mark existing data for upload, then
  /// run the first sync. Returns [SyncResult.blockedBy] if iCloud is unavailable.
  /// [force] skips the populated-zone guard and mints a key even when the zone
  /// already holds records. ONLY for a deliberate, user-confirmed "start fresh
  /// from this device" — the guard's whole purpose is that this is destructive:
  /// every existing record becomes unreadable. Never set it from an automatic
  /// path, a retry counter, or any heuristic about what the user probably meant.
  /// [adoptOwner] persists the canonical owner id as this device's own. It is
  /// invoked BEFORE the local re-key, not after.
  ///
  /// Ordering matters and used to be wrong. `reKeyOwner` commits the whole
  /// database onto the canonical id; if the Keychain write happens afterwards
  /// and anything interrupts the gap — app kill, a throw inside the first sync —
  /// the database is re-keyed while `ownerId()` still returns the old id. The
  /// next open then seeds a fresh identity for that stale id, and the orphan is
  /// permanent. Writing the Keychain first inverts the failure: the id is
  /// adopted but the rows are not yet moved, which the orphaned-owner self-heal
  /// already detects and repairs on the next open.
  Future<SyncResult> enable({
    required SyncKeyStore keys,
    required String localOwner,
    Future<void> Function(String canonicalOwner)? adoptOwner,
    bool force = false,
  }) async {
    final status = await bridge.accountStatus();
    if (status != CloudAccountStatus.available) {
      return SyncResult(blockedBy: status);
    }
    // Never mint a key into a zone that already holds records. `readKey()`
    // returns null both when no key exists anywhere AND when the key simply
    // has not propagated through the iCloud Keychain yet, and
    // getOrCreateKeyReporting() cannot tell those apart — it mints either way.
    // Minting against a populated zone permanently orphans every record in it,
    // on every device. Ask the zone instead: records present ⇒ some device
    // already enabled ⇒ this device is NOT first, so defer and wait for the
    // key rather than starting a second, incompatible encryption lineage.
    //
    // Ordered before ensureZone()/any write so a deferred enable touches
    // nothing at all.
    if (!force &&
        await keys.readKey() == null &&
        await bridge.zoneHasRecords()) {
      logger.info(
        '[CloudKit] Sync enable deferred: the zone already holds records but '
        'this device has no E2E key yet (waiting for iCloud Keychain). '
        'Refusing to mint a second key.',
      );
      return const SyncResult(keyPending: true);
    }

    final k = await keys.getOrCreateKeyReporting();
    final canonical = await keys.resolveCanonicalOwner(
      localOwner,
      isFirstDevice: k.created,
    );
    if (canonical == null) {
      // Key synced from another device but the canonical owner hasn't yet.
      // Defer rather than self-electing this device's owner (split-identity
      // guard). Nothing local is touched; a later enable completes the merge.
      return const SyncResult(ownerPending: true);
    }
    if (canonical != localOwner) {
      // Adopt the id FIRST, then move the rows. See [adoptOwner]: an interruption
      // between the two must leave the id ahead of the data (self-healing on the
      // next open), never the data ahead of the id (a permanent orphan).
      await adoptOwner?.call(canonical);
      // Second device: unify identity (also clears+rebuilds sync_state dirty).
      await store.reKeyOwner(localOwner, canonical);
    } else {
      // First device: upload the data that pre-dates sync.
      await store.markAllDirty();
    }
    final r = await syncNow(k.key);
    return SyncResult(
      pushed: r.pushed,
      applied: r.applied,
      skipped: r.skipped,
      wiped: r.wiped,
      blockedBy: r.blockedBy,
      undecryptable: r.undecryptable,
      canonicalOwner: canonical,
    );
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

    // Did this device's E2E key change since the last sync? If so, records
    // parked as undecryptable may now open — but CloudKit will not re-deliver a
    // record the change token has already passed. Drop the token to force ONE
    // full re-fetch and un-park those records so they re-apply.
    //
    // This is what makes advancing the token past an undecryptable record safe.
    // The alternative — holding the token — recovers the same records but pins
    // the device forever when the key never arrives, re-downloading and
    // re-discarding the entire zone on every sync. That is the state a real
    // key split left an iPhone in. Advance-and-refetch-on-rotation recovers in
    // both directions and livelocks in neither.
    final fingerprint = crypto.keyFingerprint(key);
    final lastFingerprint = await store.keyFingerprint();
    if (lastFingerprint != null && lastFingerprint != fingerprint) {
      final unparked = await store.clearUndecryptableParks();
      if (unparked > 0) {
        logger.info(
          '[CloudKit] Sync key changed — re-fetching the whole zone to retry '
          '$unparked record(s) previously sealed under a different key.',
        );
        await store.setChangeToken(null);
      }
    }
    await store.setKeyFingerprint(fingerprint);

    // Did THIS build's schema grow since the last sync? If so it may now
    // understand tables whose records it previously had to quarantine. The
    // change token has already advanced past them and CloudKit will not replay
    // them, so the only way to recover those rows is one full re-fetch.
    //
    // Generalises the key-rotation recovery above, and makes every FUTURE
    // additive table migration safe: without it, whichever device updates second
    // silently never receives the rows the first one pushed in the meantime.
    final syncedVersion = await store.syncedSchemaVersion();
    if (syncedVersion != null && syncedVersion < PrivateDbSchema.version) {
      final unparked = await store.clearUnknownTableParks();
      if (unparked > 0) {
        logger.info(
          '[CloudKit] Schema upgraded v$syncedVersion -> '
          'v${PrivateDbSchema.version}; re-fetching the zone to retry '
          '$unparked record(s) this build previously had no table for.',
        );
        await store.setChangeToken(null);
      }
    }
    await store.setSyncedSchemaVersion(PrivateDbSchema.version);
    // Pull BEFORE push: a newer remote record overwrites the local copy and
    // clears its dirty flag, so a stale local edit is never pushed over it. With
    // the native savePolicy of `.allKeys` (overwrite), this ordering is what
    // enforces last-write-wins — pushing first could clobber a newer cloud
    // record. It also gives a freshly-enabled second device the canonical data
    // before it uploads its own.
    final pull = await _pull(key);
    final pushed = await _push(key);
    await store.setLastFullSync(_nowIso());
    return SyncResult(
      pushed: pushed,
      applied: pull.$1,
      skipped: pull.$2,
      undecryptable: pull.$3,
    );
  }

  Future<int> _push(Uint8List key) async {
    final entries = await store.dirtyEntries();
    if (entries.isEmpty) return 0;

    final records = <CloudRecord>[];
    // `sync_state.updated_at` as observed when each record was serialized. A
    // record is only cleared of `dirty` if the row still carries its stamp, so
    // an app write racing the upload is re-pushed rather than dropped.
    final pushedStamp = <String, String>{};
    for (final e in entries) {
      pushedStamp[e.recordName] = e.updatedAt;
      if (e.deleted) {
        records.add(_tombstone(e.recordName, e.tableName, e.updatedAt));
        continue;
      }
      if (e.tableName == PrivateDbSchema.avatarRecordTable) {
        final rec = await _encodeAvatar(e, key);
        if (rec != null) records.add(rec);
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

    var pushed = 0;
    // Each batch is committed to sync_state before the next is sent, so a batch
    // that fails (or throws) leaves the batches already saved marked synced and
    // the rest still dirty for the next sync — never a silent all-or-nothing.
    for (final batch in _batches(records)) {
      final outcome = await bridge.saveRecords(batch);
      final at = _nowIso();
      for (final rn in outcome.saved) {
        final stamp = pushedStamp[rn];
        if (stamp != null) await store.markSynced(rn, at, stamp);
      }
      for (final err in outcome.errors) {
        await store.markError(err.recordName, err.code);
        logger.error(
          '[CloudKit] Record push failed',
          err.code,
          null,
          {'recordName': err.recordName},
        );
      }
      // Conflicts (server has a newer version) are intentionally left dirty: the
      // pull below fetches the newer record and LWW-applies it, clearing dirty.
      pushed += outcome.saved.length;
    }
    return pushed;
  }

  /// Split the push into operations CloudKit will accept. One unbounded
  /// `CKModifyRecordsOperation` is rejected wholesale with `CKError
  /// .limitExceeded` — a request-level failure, so no per-record block runs and
  /// NOTHING uploads. That is not hypothetical: [enable] marks the user's entire
  /// history dirty (both the first-device [SyncLocalStore.markAllDirty] path and
  /// the second-device [SyncLocalStore.reKeyOwner] one), so the very first push
  /// on an established dataset is thousands of records.
  ///
  /// A single record is never held back, even if it alone exceeds the byte cap.
  Iterable<List<CloudRecord>> _batches(List<CloudRecord> records) sync* {
    var batch = <CloudRecord>[];
    var bytes = 0;
    for (final r in records) {
      // An avatar record's payload is EMPTY by construction — its image travels
      // as the CKAsset at `assetPath` (see [_encodeAvatar]) — so it counts ~0
      // against the byte cap. Not a gap worth closing: `avatar:<owner>` is one
      // record per profile, so the record cap alone bounds any batch holding it.
      final size = r.payload?.lengthInBytes ?? 0;
      if (batch.isNotEmpty &&
          (batch.length >= _maxRecordsPerBatch ||
              bytes + size > _maxPayloadBytesPerBatch)) {
        yield batch;
        batch = [];
        bytes = 0;
      }
      batch.add(r);
      bytes += size;
    }
    if (batch.isNotEmpty) yield batch;
  }

  Future<(int, int, int)> _pull(Uint8List key) async {
    // Collect all changed records across pages, then apply FK-safely.
    final all = <CloudRecord>[];
    final originalToken = await store.changeToken();
    String? token = originalToken;
    var pages = 0;
    while (true) {
      final out = await bridge.fetchChanges(token);
      all.addAll(out.records);
      if (!out.moreComing) {
        token = out.newToken;
        break;
      }
      // moreComing == true promises another page AND a strictly-advancing
      // token. Guard against a misbehaving/regressed bridge that reports
      // moreComing without advancing the token: otherwise this loops forever
      // re-fetching the same page and grows `all` without bound (OOM). Bail
      // with what we've gathered — a held token (below) re-fetches next sync.
      final next = out.newToken;
      if (next == null || next == token || ++pages > _maxFetchPages) {
        logger.error(
          '[CloudKit] Pull paging halted: moreComing but the change token did '
          'not advance (or exceeded $_maxFetchPages pages)',
          'paging-no-progress',
          null,
          {'pages': pages},
        );
        token = next ?? token;
        break;
      }
      token = next;
    }
    // Parents before children for UPSERTS — but ALL deletions last.
    //
    // Sorting on table alone puts a `profiles` tombstone at priority 0, ahead of
    // the very child upserts that re-point rows away from the identity being
    // deleted. The peer then deletes the parent while its children still
    // reference it. That is survivable only because [SyncLocalStore.applyDelete]
    // now disables FK enforcement; before that it was a full-database cascade.
    // Ordering deletions last means the re-points land FIRST, so by the time the
    // tombstone applies nothing depends on the row — correct on its own terms
    // rather than relying on the FK guard as the only line of defence.
    int rank(CloudRecord r) =>
        (_applyPriority[r.tableName] ?? 9) + (r.deleted ? _deletePriorityBase : 0);
    all.sort((a, b) => rank(a).compareTo(rank(b)));

    var applied = 0;
    var skipped = 0;
    var undecryptable = 0;
    // Hold the change token at its pre-fetch value when ANY record in this
    // batch must be re-fetched on a later sync rather than lost: a clock-skew
    // deferral OR a real apply FAILURE (SQLite busy/locked, a decrypt error, a
    // transient DB error, a missing avatar asset). CloudKit will not re-deliver
    // a record once the token advances past it (unless it's edited again), so
    // stepping past an unapplied record would silently and permanently drop it
    // — the exact invariant the future-skew guard already protects. Re-applying
    // an already-applied record on the next pull is idempotent (LWW skips it).
    var holdToken = false;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final rec in all) {
      if (rec.updatedAtMs > nowMs + _maxFutureSkewMs) {
        // Clock-skew guard: another device's clock is ahead of ours. DEFER.
        holdToken = true;
        skipped++;
        continue;
      }
      switch (await _applyRemote(rec, key)) {
        case _ApplyOutcome.applied:
          applied++;
        case _ApplyOutcome.skipped:
          // Benign: an older/equal LWW copy, a not-wired avatar, or a record
          // this build can never apply (quarantined, so it is recorded and
          // re-appliable) — safe to let the token advance past.
          skipped++;
        case _ApplyOutcome.undecryptable:
          // Sealed under another key. PERMANENT, so the token must advance —
          // holding it here is what livelocks a key-split device forever.
          // Counted separately so the caller can tell "nothing to do" apart
          // from "this device cannot read the zone".
          skipped++;
          undecryptable++;
        case _ApplyOutcome.failed:
          // A real, potentially-transient apply failure: keep the token back so
          // the record is retried on a later sync instead of being dropped.
          skipped++;
          holdToken = true;
      }
    }
    await store.setChangeToken(holdToken ? originalToken : token);
    if (undecryptable > 0) {
      logger.error(
        '[CloudKit] $undecryptable record(s) in the zone could not be '
        'decrypted with this device\'s key — the devices are on different '
        'sync keys and this one cannot read the shared data.',
        'key-mismatch',
        null,
        {'undecryptable': undecryptable, 'applied': applied},
      );
    }
    return (applied, skipped, undecryptable);
  }

  /// Builds the avatar CloudRecord for push: plaintext bytes from the app's
  /// avatar store, sealed with the sync key, staged to a temp file the native
  /// bridge wraps as a CKAsset. A missing avatar (file gone / never set)
  /// degrades to a tombstone — same semantics as a vanished row.
  Future<CloudRecord?> _encodeAvatar(SyncStateEntry e, Uint8List key) async {
    final files = avatarStore;
    if (files == null) return null; // avatar sync not wired on this app
    final bytes = await files.readAvatarBytes();
    if (bytes == null) {
      return _tombstone(e.recordName, e.tableName, e.updatedAt);
    }
    final assetPath =
        await files.stageEncryptedUpload(crypto.encryptBytes(bytes, key));
    return CloudRecord(
      recordName: e.recordName,
      tableName: e.tableName,
      updatedAtMs: _ms(e.updatedAt),
      deleted: false,
      payload: Uint8List(0),
      assetPath: assetPath,
    );
  }

  Future<_ApplyOutcome> _applyRemote(CloudRecord rec, Uint8List key) async {
    final local = await store.stateOf(rec.recordName);
    final localMs = local == null ? -1 : _ms(local.updatedAt);
    // Strict >: equal timestamps keep the local copy. Exact-millisecond
    // conflicts on the same record are vanishingly rare for a single user.
    if (rec.updatedAtMs <= localMs) return _ApplyOutcome.skipped;

    if (rec.tableName == PrivateDbSchema.avatarRecordTable) {
      return _applyRemoteAvatar(rec, key);
    }

    // A well-formed record name is always "<tableName>:<id>". A name lacking
    // that prefix is structurally invalid (a foreign/corrupt record) — it can
    // never apply, so skip-with-error and let the token advance PAST it rather
    // than letting an unguarded substring RangeError escape and wedge the pull.
    final prefix = '${rec.tableName}:';
    if (!rec.recordName.startsWith(prefix)) {
      await store.markError(rec.recordName, 'malformed recordName');
      logger.error(
        '[CloudKit] Skipping malformed record (name has no "<table>:" prefix)',
        'malformed recordName',
        null,
        {'recordName': rec.recordName, 'tableName': rec.tableName},
      );
      return _ApplyOutcome.skipped;
    }

    final rowId = rec.recordName.substring(prefix.length);

    // A table this build's schema doesn't have — a newer client shipped an
    // additive migration first. There is nowhere to put the record and no
    // retry can change that, so quarantine it and let the token advance rather
    // than wedging the pull on it forever. The clients that DO have the table
    // keep it; this one simply can't see it until the app updates.
    if (!PrivateDbSchema.syncedTables.contains(rec.tableName)) {
      await store.quarantineRecord(
        rec.recordName,
        rec.tableName,
        rowId,
        SyncLocalStore.unknownTableReason,
      );
      logger.error(
        '[CloudKit] Skipping record for a table this build has no schema for',
        'unknown table',
        null,
        {'recordName': rec.recordName, 'tableName': rec.tableName},
      );
      return _ApplyOutcome.skipped;
    }

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
        final applied = await store.applyUpsert(
          rec.tableName,
          rec.recordName,
          Map<String, Object?>.from(row),
          rec.updatedAtMs,
          _nowIso(),
        );
        // The record lost a natural-key contest: the local row for that slot is
        // the deterministic winner on every device, so this one is dead and the
        // token may advance past it (the device holding it pushes its tombstone).
        if (!applied) return _ApplyOutcome.skipped;
      }
      return _ApplyOutcome.applied;
    } on InvalidCipherTextException catch (e) {
      // Sealed with a DIFFERENT key than this device holds. Retrying cannot
      // help — the bytes will never open with this key — so treating it as a
      // transient failure holds the change token and rewinds it on every sync,
      // forever, re-downloading and re-discarding the whole zone. That is not a
      // theoretical failure mode: it is the state a real two-key split left a
      // user's iPhone in (`change token: none`, 6238 records skipped per sync).
      //
      // Quarantine instead, exactly like a row this schema cannot store: skip
      // it, record why, let the token advance so every OTHER record still
      // syncs. The record is untouched in the cloud and parked (not marked
      // applied), so it re-applies if the correct key ever arrives.
      await store.quarantineRecord(
        rec.recordName,
        rec.tableName,
        rowId,
        SyncLocalStore.undecryptableReason,
      );
      logger.error(
        '[CloudKit] Quarantined an undecryptable record (key mismatch)',
        e,
        null,
        {'recordName': rec.recordName, 'tableName': rec.tableName},
      );
      return _ApplyOutcome.undecryptable;
    } on UnstorableRowException catch (e) {
      // This build's schema can never store this record (e.g. a status value a
      // newer client's widened CHECK allows), so every retry fails identically.
      // Holding the token for it would pin the pull on this one record FOREVER
      // and re-download the whole delta on every sync, with the rest of the zone
      // stuck behind it. QUARANTINE instead: skip it, record why, advance. The
      // record is untouched in the cloud and parked (not marked applied), so the
      // client re-applies it whenever it is delivered again — see
      // [SyncLocalStore.quarantineRecord].
      await store.quarantineRecord(
        rec.recordName,
        rec.tableName,
        rowId,
        e.reason,
      );
      logger.error(
        '[CloudKit] Quarantined a record this build cannot store',
        e.reason,
        null,
        {'recordName': rec.recordName, 'tableName': rec.tableName},
      );
      return _ApplyOutcome.skipped;
    } catch (e, stack) {
      await store.markError(rec.recordName, e.toString());
      logger.error(
        '[CloudKit] Record apply failed',
        e,
        stack,
        {'recordName': rec.recordName, 'tableName': rec.tableName},
      );
      return _ApplyOutcome.failed;
    }
  }

  /// Applies a pulled avatar record: tombstone removes the local avatar,
  /// otherwise the downloaded (encrypted) asset is opened with the sync key and
  /// re-localized by the app's avatar store. Bookkeeping mirrors the row paths:
  /// server edit time stamped, dirty cleared.
  Future<_ApplyOutcome> _applyRemoteAvatar(CloudRecord rec, Uint8List key) async {
    final files = avatarStore;
    if (files == null) return _ApplyOutcome.skipped; // not wired — skip, advance
    try {
      if (rec.deleted) {
        await files.removeAvatar();
      } else {
        final assetPath = rec.assetPath;
        if (assetPath == null) {
          throw StateError('avatar record without an asset');
        }
        final encrypted = await files.readStagedDownload(assetPath);
        await files.writeAvatarBytes(crypto.decryptBytes(encrypted, key));
      }
      await store.applyAvatarState(
        rec.recordName,
        _iso(rec.updatedAtMs),
        _nowIso(),
        deleted: rec.deleted,
      );
      return _ApplyOutcome.applied;
    } catch (e, stack) {
      // A read/decrypt failure here is often transient — e.g. a CKAsset temp
      // file that CloudKit hadn't materialized yet. Treat it as [failed] so the
      // token holds and the avatar record is re-fetched next sync (the asset is
      // re-staged), rather than advancing past it and losing the avatar.
      await store.markError(rec.recordName, e.toString());
      logger.error(
        '[CloudKit] Avatar apply failed',
        e,
        stack,
        {'recordName': rec.recordName},
      );
      return _ApplyOutcome.failed;
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
