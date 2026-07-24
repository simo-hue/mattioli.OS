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

/// What one push actually achieved. A bare `pushed` count cannot distinguish
/// "there was nothing to upload" from "everything was rejected" — both report 0
/// — which is why the failure and conflict counts travel with it.
class _PushOutcome {
  final int pushed;
  final int failed;
  final int conflicted;
  const _PushOutcome(this.pushed, this.failed, this.conflicted);
}

/// What one pull actually achieved. [heldToken] is the load-bearing field: it
/// means records were deferred or failed to apply and the change token was
/// deliberately rewound, so this device has NOT taken everything the zone holds.
class _PullOutcome {
  final int applied;
  final int skipped;
  final int undecryptable;
  final bool heldToken;
  const _PullOutcome({
    required this.applied,
    required this.skipped,
    required this.undecryptable,
    required this.heldToken,
  });
}

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

  /// Records CloudKit REJECTED in this push (a per-record error in a
  /// `.partialFailure`, e.g. rate limiting on a large first upload). Each one is
  /// an edit that exists only on this device and that the cloud has never seen.
  ///
  /// Exists because a push could previously fail for every single record while
  /// the sync reported success and stamped `last_full_sync_at` — see
  /// [SyncEngine.syncNow]. Left dirty, so they retry on the next sync.
  final int pushFailed;

  /// Records the server refused because it holds a NEWER version. Left dirty on
  /// purpose (the next pull LWW-resolves them), but they are still local edits
  /// the cloud does not have, so they count against [fullySynced].
  final int pushConflicted;

  /// The pull deliberately held the change token back: at least one record was
  /// deferred (clock skew) or failed to apply, and must be re-fetched on a later
  /// sync. The device has NOT taken everything the zone offered.
  final bool pullIncomplete;

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
    this.pushFailed = 0,
    this.pushConflicted = 0,
    this.pullIncomplete = false,
  });

  bool get ran => blockedBy == null && !ownerPending && !keyPending;

  /// This sync moved everything it attempted, in both directions — the ONLY
  /// condition under which `last_full_sync_at` may be stamped.
  ///
  /// Deliberately narrower than "did not throw". A sync that uploaded 3 of 4000
  /// records and a sync that uploaded all 4000 both returned normally before
  /// this existed, and both stamped the timestamp every UI renders as "Last
  /// synced". Note it says nothing about records PARKED by an earlier sync —
  /// that is [SyncDiagnostics.isFullySynced]'s job, and it is what a UI must
  /// consult before claiming "up to date".
  bool get fullySynced =>
      ran &&
      !wiped &&
      pushFailed == 0 &&
      pushConflicted == 0 &&
      !pullIncomplete;
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

  /// Wall clock. Injectable because the skew guard's whole correctness argument
  /// is about the PASSAGE of time — a deferral that resolves when `now` catches
  /// up, a park that expires when it does — and none of that is testable
  /// against a clock that only ever reads "now". Production never passes it.
  final DateTime Function() clock;

  SyncEngine({
    required this.store,
    required this.bridge,
    required this.crypto,
    this.avatarStore,
    this.logger = const SilentSyncLogger(),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  /// FK-safe apply order: parents before children (profiles → goals/categories →
  /// logs/macro-goals/moods → the avatar, which rewrites profiles.avatar_url).
  /// Applied across the whole pulled batch.
  static const Map<String, int> _applyPriority = {
    'profiles': 0,
    'goals': 1,
    'macro_goal_categories': 1,
    'goal_category_settings': 1,
    'goal_logs': 2,
    // Child of both profiles and goals (v9), so it lands with the other
    // second-level rows. Explicit rather than relying on the `?? 9` fallback:
    // the fallback happens to be FK-safe today only because every parent has a
    // lower number, which is a coincidence, not a guarantee.
    'goal_progress': 2,
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

  /// Beyond this, a future stamp is not clock skew — it is a clock that is
  /// simply wrong, or a corrupt value. The distinction decides whether the
  /// change token may be held.
  ///
  /// Holding it is safe ONLY while the deferral is self-limiting: the deferred
  /// band is `(now + _maxFutureSkewMs, now + this]`, a window that slides
  /// forward with real time, so `now` reaches any stamp inside it within a day
  /// and the record then applies — no attempt counter, no extra state. A stamp
  /// ABOVE the band never becomes plausible, so `rec.updatedAtMs > nowMs +
  /// skew` stays true on every pull forever: the token is rewound every sync,
  /// the whole delta is re-downloaded and re-discarded, and it grows without
  /// bound because the token never moves again. That is precisely the state the
  /// undecryptable branch below refuses to enter, and it is reachable without
  /// any corruption at all — iOS and macOS let a user set the date by hand, and
  /// nothing clamps `updated_at` on the way out.
  ///
  /// A day is the threshold because no honest clock error survives a day of
  /// NTP, while a device parked a day ahead is still worth waiting for.
  static const int _maxDeferrableSkewMs = 24 * 60 * 60 * 1000;

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

  /// The LWW value for "this device holds no record under that name at all".
  ///
  /// Strictly BELOW [SyncLocalStore.unorderableMs] on purpose. A record whose
  /// own stamp is unreadable compares at `unorderableMs`, and it still has to
  /// win against an empty slot — otherwise a row imported from a backup with a
  /// malformed timestamp would be skipped by every device that has never seen
  /// it, i.e. never arrive anywhere. Collapsing the two sentinels onto one
  /// value is what would do that.
  static const int _noLocalRecordMs = -1;

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
    if (!force && await keys.readKey() == null) {
      // No local key yet ⇒ we are about to MINT. Two guards decide whether that
      // is safe; both only ever turn a mint into a defer, never the reverse.
      if (await bridge.zoneHasRecords()) {
        // Real records already exist under a key still in flight — minting would
        // orphan every one of them, permanently, on every device. Defer and
        // wait for the iCloud Keychain to deliver that key.
        logger.info(
          '[CloudKit] Sync enable deferred: the zone already holds records but '
          'this device has no E2E key yet (waiting for iCloud Keychain). '
          'Refusing to mint a second key.',
        );
        return const SyncResult(keyPending: true);
      }
      // The zone is empty of data — but the check above is a READ and cannot be
      // atomic with the mint below, so two devices enabling on the same empty
      // zone in one window both reach here and both mint (the empty-zone race
      // that split a real user's key). Close it with a server-side atomic claim:
      // only the device that creates the singleton owner sentinel may mint; the
      // loser defers and adopts the winner's key via the iCloud Keychain.
      //
      // Fail-open: a null answer (no native support / inconclusive error) falls
      // straight through to the mint, exactly as before this guard existed, so
      // it can never regress — it only ADDS a defer on a definitive loss.
      final wonClaim = await bridge.tryClaimFirstMint(localOwner);
      if (wonClaim == false) {
        logger.info(
          '[CloudKit] Sync enable deferred: another device won the first-mint '
          'claim on the empty zone (waiting for its key via iCloud Keychain). '
          'Refusing to mint a second key.',
        );
        return const SyncResult(keyPending: true);
      }
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
      // Forwarded, not defaulted: enable() runs the FIRST push of the user's
      // entire history, which is the single most likely push to be rate-limited
      // and the exact scenario the original bug report described. Dropping
      // these here would restore the false success one level up.
      pushFailed: r.pushFailed,
      pushConflicted: r.pushConflicted,
      pullIncomplete: r.pullIncomplete,
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

    // Has this device's clock reached a record parked as implausibly-future?
    // Those parks carry the record's own stamp as the moment they become worth
    // retrying (see [SyncLocalStore.parkFutureSkew]), so a peer whose clock ran
    // a week fast heals a week later without the user doing anything. CloudKit
    // will not replay a record the token has already passed, so — exactly as on
    // key rotation and schema growth above — one full re-fetch is the only way
    // to get it back.
    //
    // Gated on the clock and not run unconditionally: dropping the token every
    // sync is precisely the unbounded re-download that parking these records
    // exists to stop, so an un-park that fires repeatedly would reintroduce the
    // bug through the recovery path. A park that is not yet due matches
    // nothing and costs one small query.
    final revived = await store.clearImplausibleFutureParks(clock().toUtc());
    if (revived > 0) {
      logger.info(
        '[CloudKit] The local clock has caught up with $revived record(s) '
        'parked as implausibly-future — re-fetching the zone to retry them.',
      );
      await store.setChangeToken(null);
    }

    // Pull BEFORE push: a newer remote record overwrites the local copy and
    // clears its dirty flag, so a stale local edit is never pushed over it. With
    // the native savePolicy of `.allKeys` (overwrite), this ordering is what
    // enforces last-write-wins — pushing first could clobber a newer cloud
    // record. It also gives a freshly-enabled second device the canonical data
    // before it uploads its own.
    final pull = await _pull(key);
    final push = await _push(key);
    final result = SyncResult(
      pushed: push.pushed,
      pushFailed: push.failed,
      pushConflicted: push.conflicted,
      applied: pull.applied,
      skipped: pull.skipped,
      undecryptable: pull.undecryptable,
      pullIncomplete: pull.heldToken,
    );
    // ONLY stamp when the sync actually moved everything it attempted.
    //
    // This used to be unconditional, one line after the push, which made "Last
    // synced: just now" survivable alongside a push in which every single
    // record had failed. Both apps render this value verbatim, so an
    // unconditional stamp is not a cosmetic inaccuracy — it is the app telling
    // the user their data is safe in iCloud when it is sitting in a local
    // table and has never left the device.
    if (result.fullySynced) {
      await store.setLastFullSync(_nowIso());
    } else {
      logger.error(
        '[CloudKit] Sync did NOT fully complete — "last synced" left unchanged',
        'incomplete-sync',
        null,
        {
          'pushed': push.pushed,
          'pushFailed': push.failed,
          'pushConflicted': push.conflicted,
          'pullIncomplete': pull.heldToken,
        },
      );
    }
    return result;
  }

  Future<_PushOutcome> _push(Uint8List key) async {
    final entries = await store.dirtyEntries();
    if (entries.isEmpty) return const _PushOutcome(0, 0, 0);

    final records = <CloudRecord>[];
    // Avatars whose file we could not read while one is still configured. They
    // are push FAILURES, not deletions — see the avatar branch below.
    var lostAvatars = 0;
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
        if (rec != null) {
          records.add(rec);
        } else if (avatarStore != null) {
          // With a store wired, the only way to get null is a CONFIGURED avatar
          // whose file could not be read (see [_encodeAvatar] — no avatar at all
          // yields a tombstone, and readable bytes yield a record).
          //
          // Nothing is pushed, so the zone keeps the good copy and every other
          // device keeps its image. The record stays dirty and is counted as a
          // push failure, so the sync does NOT stamp "last synced" and both apps
          // report the device as not fully synced. Losing a file quietly, and
          // then claiming to be up to date, is how this went unnoticed.
          lostAvatars++;
          await store.markError(
            e.recordName,
            SyncLocalStore.avatarFileMissingReason,
          );
          logger.error(
            '[CloudKit] The local avatar file is missing but an avatar is still '
            'configured — refusing to push a tombstone that would delete it '
            'everywhere. Re-select the image to republish it.',
            SyncLocalStore.avatarFileMissingReason,
            null,
            {'recordName': e.recordName},
          );
        }
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
    var failed = 0;
    var conflicted = 0;
    failed += lostAvatars;
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
      failed += outcome.errors.length;
      conflicted += outcome.conflicts.length;
    }
    return _PushOutcome(pushed, failed, conflicted);
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

  Future<_PullOutcome> _pull(Uint8List key) async {
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
    final nowMs = clock().toUtc().millisecondsSinceEpoch;
    for (final rec in all) {
      if (rec.recordName == kKeyOwnerSentinelRecordName) {
        // The empty-zone first-mint arbitration sentinel (see
        // [CloudKitBridge.tryClaimFirstMint]) is bookkeeping, never a data row.
        // Skip it so it is neither applied nor quarantined as an unknown table;
        // the change token still advances past it.
        skipped++;
        continue;
      }
      // Compared against `nowMs + bound`, never as `updatedAtMs - nowMs`.
      // `updatedAtMs` is an arbitrary int64 off the wire, so the subtraction
      // wraps for a maximally-negative one and reports a huge POSITIVE skew —
      // which would park an ancient record with a retry time of "now", un-park
      // it on the next sync, re-fetch the zone, and re-park it: the unbounded
      // re-download rebuilt through the recovery path. The additions cannot
      // overflow because both bounds are small constants.
      if (rec.updatedAtMs > nowMs + _maxDeferrableSkewMs) {
        // Not skew — the authoring clock is wrong, or the value is corrupt.
        // Deferring here defers FOREVER (see [_maxDeferrableSkewMs]), so PARK
        // instead, on exactly the terms the undecryptable and unknown-table
        // branches use: record why, let the token advance so the rest of the
        // zone keeps syncing, and leave the record itself untouched in the
        // cloud. It is not dropped — it stays counted in
        // SyncDiagnostics.parkedByReason, and the park expires by itself once
        // this device's clock passes the stamp.
        await _parkImplausibleFuture(rec, nowMs);
        skipped++;
        continue;
      }
      if (rec.updatedAtMs > nowMs + _maxFutureSkewMs) {
        // Plausible clock skew: another device is a little ahead of ours.
        // DEFER — hold the token so the record is re-fetched rather than
        // applied with a stamp that would beat every later local edit. Bounded
        // by construction: `now` reaches this stamp within a day.
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
    return _PullOutcome(
      applied: applied,
      skipped: skipped,
      undecryptable: undecryptable,
      heldToken: holdToken,
    );
  }

  /// Park a record stamped beyond any plausible clock error, so the change
  /// token can advance past it WITHOUT the record being silently dropped.
  ///
  /// The park is bounded, not permanent: it carries the record's own stamp as
  /// the moment it becomes worth retrying, and [syncNow] revives it — with one
  /// full re-fetch — as soon as this device's clock passes that. A device that
  /// received rows from a peer whose clock was a week fast therefore heals a
  /// week later on its own.
  ///
  /// A stamp in the year 2999 never comes due, and that outcome is stated
  /// plainly rather than dressed up: the record stays parked, stays counted in
  /// [SyncDiagnostics.parkedByReason] with a reason that names the cause, and
  /// stays intact in the cloud and on the device that wrote it. What it no
  /// longer does is pin this device's change token for the rest of its life.
  Future<void> _parkImplausibleFuture(CloudRecord rec, int nowMs) async {
    // The skew test runs BEFORE _applyRemote's prefix validation, so the row id
    // has to be parsed here. A name without the "<table>:" prefix is malformed
    // on top of being skewed; park it under the whole name rather than skip it
    // unrecorded — `row_id` is bookkeeping for a record that has no local row
    // either way, and an unrecorded skip is the silent drop this branch exists
    // to avoid.
    final prefix = '${rec.tableName}:';
    final rowId = rec.recordName.startsWith(prefix)
        ? rec.recordName.substring(prefix.length)
        : rec.recordName;
    // `updatedAtMs` is an arbitrary int on the wire and DateTime rejects
    // anything past ~±275760 years, so a corrupt value would throw out of
    // `_iso` and take the whole pull down with it — trading a pinned token for
    // a sync that cannot run at all. Clamp: a stamp above the ceiling is never
    // coming due, which is exactly what the clamped value also says.
    final retryMs = rec.updatedAtMs.clamp(nowMs, _maxDateTimeMs);
    await store.parkFutureSkew(
      rec.recordName,
      rec.tableName,
      rowId,
      _iso(retryMs),
    );
    logger.error(
      '[CloudKit] Parked a record stamped implausibly far in the future — the '
      'authoring clock is wrong, not merely ahead of ours.',
      'implausible-future-timestamp',
      null,
      // Both endpoints rather than their difference: the subtraction wraps for
      // an extreme wire value and a wrapped number in a crash report is worse
      // than no number.
      {
        'recordName': rec.recordName,
        'tableName': rec.tableName,
        'updatedAtMs': rec.updatedAtMs,
        'nowMs': nowMs,
      },
    );
  }

  /// The largest epoch-ms `DateTime` accepts (±275760 years). See
  /// [_parkImplausibleFuture].
  static const int _maxDateTimeMs = 8640000000000000;

  /// Builds the avatar CloudRecord for push: plaintext bytes from the app's
  /// avatar store, sealed with the sync key, staged to a temp file the native
  /// bridge wraps as a CKAsset. A missing avatar (file gone / never set)
  /// degrades to a tombstone — same semantics as a vanished row.
  Future<CloudRecord?> _encodeAvatar(SyncStateEntry e, Uint8List key) async {
    final files = avatarStore;
    if (files == null) return null; // avatar sync not wired on this app
    final bytes = await files.readAvatarBytes();
    if (bytes == null) {
      // No bytes for two very different reasons, and only ONE of them is a
      // deletion.
      //
      // The user removing their avatar must propagate, or it reappears on the
      // next sync from the other device. But an avatar that is still CONFIGURED
      // and merely unreadable means we lost track of our own file — and a
      // tombstone would then delete the good copy from the zone and from every
      // other device, irrecoverably, while the sync reported success.
      //
      // This is the reported bug: `avatar_url` holds an absolute path rooted at
      // the app container, iOS regenerates that container's UUID across
      // reinstalls, and `markAllDirty` re-queues the avatar on nothing more than
      // `avatar_url` being non-empty.
      if (await files.hasAvatarConfigured()) {
        return null; // handled by _push — reported, never replicated
      }
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
    final localMs = local == null ? _noLocalRecordMs : _ms(local.updatedAt);
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
      // markPullError, not markError: this record may have no `sync_state` row
      // at all (the LWW read above found none), and markError's bare UPDATE
      // would match nothing and discard the reason — leaving a device that
      // holds its change token forever while reporting a clean sync.
      await store.markPullError(
        rec.recordName,
        rec.tableName,
        rowId,
        e.toString(),
      );
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
      //
      // markPullError for the same reason as the row path: a device that has
      // never held this avatar has no `sync_state` row for it, so markError's
      // bare UPDATE would write nothing at all.
      await store.markPullError(
        rec.recordName,
        rec.tableName,
        rec.recordName
            .substring(PrivateDbSchema.avatarRecordTable.length + 1),
        e.toString(),
      );
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

  /// The fallback is [SyncLocalStore.unorderableMs], not a literal, and that is
  /// load-bearing: this function produces the value that goes ON THE WIRE, and
  /// [SyncLocalStore] compares its own copy of it against that wire value when
  /// two rows contest a natural key. If the two ever answer differently for an
  /// unreadable stamp, the tie stops being a tie and both devices delete their
  /// own row — see the constant's doc.
  int _ms(String iso) =>
      DateTime.tryParse(iso)?.millisecondsSinceEpoch ??
          SyncLocalStore.unorderableMs;
  String _iso(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
  String _nowIso() => clock().toUtc().toIso8601String();
}
