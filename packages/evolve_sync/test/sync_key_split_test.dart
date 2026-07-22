// Regression tests for the two-key split that silently destroyed a real user's
// sync: the Mac enabled before the iPhone's E2E key had propagated through the
// iCloud Keychain, minted a SECOND key, and from then on neither device could
// decrypt the other's records. The zone held ~6238 permanently-unreadable
// records, the iPhone's change token was pinned at null forever, and every sync
// reported success while applying nothing.
//
// Two independent defects, tested separately:
//   1. enable() minted a key without ever asking whether the zone was already
//      populated  → the guard.
//   2. a decrypt failure was classified as TRANSIENT, so it held the change
//      token and rewound it on every sync, forever → the quarantine.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:evolve_sync/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// In-memory [SyncSecretStore]; one instance == one device's keychain view.
/// Two devices sharing an instance models a propagated iCloud Keychain; two
/// separate instances model the propagation gap that caused the incident.
class _FakeSecrets implements SyncSecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const now = '2026-07-20T00:00:00.000Z';

  Future<Database> openDb() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: PrivateDbSchema.version,
          onConfigure: PrivateDbSchema.onConfigure,
          onCreate: PrivateDbSchema.onCreate,
          onUpgrade: PrivateDbSchema.onUpgrade,
          singleInstance: false,
        ),
      );

  Future<SyncLocalStore> seedDevice(String owner, {int macroGoals = 0}) async {
    final db = await openDb();
    await db.insert(
      'profiles',
      {'id': owner, 'created_at': now, 'updated_at': now},
    );
    for (var i = 0; i < macroGoals; i++) {
      await db.insert('long_term_goals', {
        'id': '$owner-g$i',
        'user_id': owner,
        'title': 'goal $i',
        'status': 'active',
        'type': 'annual',
        'year': 2026,
        'created_at': now,
        'updated_at': now,
      });
    }
    return SyncLocalStore(db);
  }

  SyncEngine engineFor(SyncLocalStore store, FakeCloudKitBridge bridge) =>
      SyncEngine(store: store, bridge: bridge, crypto: SyncCrypto());

  group('key-mint guard', () {
    test('a second device with no key does NOT mint one into a populated zone',
        () async {
      final bridge = FakeCloudKitBridge();

      // Device A (the iPhone): first to enable, so it legitimately mints and
      // uploads its history.
      final a = await seedDevice('owner-a', macroGoals: 5);
      final aKeys = SyncKeyStore(_FakeSecrets());
      final aResult =
          await engineFor(a, bridge).enable(keys: aKeys, localOwner: 'owner-a');
      expect(aResult.ran, isTrue);
      expect(bridge.records, isNotEmpty, reason: 'A uploaded its data');

      // Device B (the Mac): enables while its keychain is still EMPTY — the
      // iCloud Keychain has not delivered A's key yet. This is the exact
      // production race.
      final b = await seedDevice('owner-b');
      final bSecrets = _FakeSecrets();
      final bResult = await engineFor(b, bridge)
          .enable(keys: SyncKeyStore(bSecrets), localOwner: 'owner-b');

      expect(bResult.keyPending, isTrue,
          reason: 'B must DEFER, not mint a rival key');
      expect(bResult.ran, isFalse);
      expect(bSecrets.values[SyncKeyStore.keyKey], isNull,
          reason: 'no key may be written — that write is the unrecoverable act');
    });

    test('a deferred enable touches nothing at all', () async {
      final bridge = FakeCloudKitBridge();
      final a = await seedDevice('owner-a', macroGoals: 3);
      final aKeys = SyncKeyStore(_FakeSecrets());
      await engineFor(a, bridge).enable(keys: aKeys, localOwner: 'owner-a');
      final zoneBefore = Map.of(bridge.records);

      final b = await seedDevice('owner-b', macroGoals: 2);
      final bSecrets = _FakeSecrets();
      // B's own rows are already dirty from their insert triggers; what matters
      // is that enable() adds nothing on top (no markAllDirty, no reKeyOwner).
      final pendingBefore = (await b.diagnostics()).totalPending;

      await engineFor(b, bridge)
          .enable(keys: SyncKeyStore(bSecrets), localOwner: 'owner-b');

      // No upload, no owner published, no local re-key.
      expect(bridge.records.length, zoneBefore.length,
          reason: 'nothing may reach the zone under a rival key');
      expect(bSecrets.values[SyncKeyStore.ownerKey], isNull);
      expect((await b.diagnostics()).totalPending, pendingBefore,
          reason: 'a deferred enable must not re-mark the whole database');
    });

    test('once the key propagates, the same device enables and converges',
        () async {
      final bridge = FakeCloudKitBridge();
      final shared = _FakeSecrets();

      final a = await seedDevice('owner-a', macroGoals: 4);
      await engineFor(a, bridge)
          .enable(keys: SyncKeyStore(shared), localOwner: 'owner-a');

      // B now sees the SAME keychain — iCloud Keychain has delivered the key.
      final b = await seedDevice('owner-b');
      final bResult = await engineFor(b, bridge)
          .enable(keys: SyncKeyStore(shared), localOwner: 'owner-b');

      expect(bResult.keyPending, isFalse);
      expect(bResult.ran, isTrue);
      final bDiag = await b.diagnostics();
      expect(bDiag.localRowsByTable['long_term_goals'], 4,
          reason: "B decrypted and applied A's goals");
      expect(bDiag.totalParked, 0);
    });

    test('a genuinely-first device on an empty zone still mints', () async {
      final bridge = FakeCloudKitBridge();
      final a = await seedDevice('owner-a', macroGoals: 2);
      final secrets = _FakeSecrets();

      final r = await engineFor(a, bridge)
          .enable(keys: SyncKeyStore(secrets), localOwner: 'owner-a');

      expect(r.ran, isTrue);
      expect(r.keyPending, isFalse);
      expect(secrets.values[SyncKeyStore.keyKey], isNotNull);
      expect(bridge.zoneHasRecordsCalls, greaterThan(0),
          reason: 'the guard must actually consult the zone');
    });
  });

  group('empty-zone first-mint race', () {
    test('B defers on the claim ALONE, before any data exists', () async {
      // The race the zoneHasRecords guard is blind to: device A has CLAIMED the
      // empty zone but not yet uploaded anything, so zoneHasRecords is still
      // false. Only the server-side atomic claim can stop B minting a rival key
      // in this window — which is exactly the window that split a real user.
      final bridge = FakeCloudKitBridge();

      // A wins the claim first (modelled directly — this is A's enable() claim).
      expect(await bridge.tryClaimFirstMint('owner-a'), isTrue);
      expect(await bridge.zoneHasRecords(), isFalse,
          reason: 'the sentinel alone is not "records" — the data guard is blind');

      final b = await seedDevice('owner-b', macroGoals: 2);
      final bSecrets = _FakeSecrets();
      final bResult = await engineFor(b, bridge)
          .enable(keys: SyncKeyStore(bSecrets), localOwner: 'owner-b');

      expect(bResult.keyPending, isTrue,
          reason: 'B must defer on the claim, before any data exists');
      expect(bResult.ran, isFalse);
      expect(bSecrets.values[SyncKeyStore.keyKey], isNull,
          reason: 'the rival-key write is the unrecoverable act');
    });

    test('two devices racing to enable converge on exactly one key', () async {
      final bridge = FakeCloudKitBridge();
      // Separate keychains == the iCloud Keychain has propagated nothing yet.
      final aSecrets = _FakeSecrets();
      final bSecrets = _FakeSecrets();
      final a = await seedDevice('owner-a', macroGoals: 2);
      final b = await seedDevice('owner-b', macroGoals: 2);

      final aResult = await engineFor(a, bridge)
          .enable(keys: SyncKeyStore(aSecrets), localOwner: 'owner-a');
      final bResult = await engineFor(b, bridge)
          .enable(keys: SyncKeyStore(bSecrets), localOwner: 'owner-b');

      expect(aResult.ran, isTrue, reason: 'the claim winner mints and uploads');
      expect(aSecrets.values[SyncKeyStore.keyKey], isNotNull);
      expect(bResult.ran, isFalse);
      expect(bResult.keyPending, isTrue);
      expect(bSecrets.values[SyncKeyStore.keyKey], isNull,
          reason: 'exactly one E2E key may exist across the two devices');
    });

    test('the claim is idempotent — a crash before minting still re-mints',
        () async {
      // A device that WON the claim but died before persisting its key (readKey
      // still null, zone still empty of data) must be able to re-mint on the
      // next enable, never defer against its OWN sentinel forever.
      final bridge = FakeCloudKitBridge();
      await bridge.tryClaimFirstMint('owner-a'); // the prior, crashed attempt

      final a = await seedDevice('owner-a', macroGoals: 1);
      final secrets = _FakeSecrets();
      final r = await engineFor(a, bridge)
          .enable(keys: SyncKeyStore(secrets), localOwner: 'owner-a');

      expect(r.ran, isTrue);
      expect(r.keyPending, isFalse);
      expect(secrets.values[SyncKeyStore.keyKey], isNotNull,
          reason: 'the same owner re-claims and mints; it never dead-locks');
    });

    test('fail-open: with no native claim support a first device still mints',
        () async {
      // The guard must never REGRESS enable(): a bridge that predates the claim
      // (a null answer) behaves exactly as before — the genuinely-first device
      // mints on an empty zone.
      final bridge = FakeCloudKitBridge()..supportsFirstMintClaim = false;
      final a = await seedDevice('owner-a', macroGoals: 2);
      final secrets = _FakeSecrets();

      final r = await engineFor(a, bridge)
          .enable(keys: SyncKeyStore(secrets), localOwner: 'owner-a');

      expect(r.ran, isTrue);
      expect(r.keyPending, isFalse);
      expect(secrets.values[SyncKeyStore.keyKey], isNotNull);
      expect(bridge.tryClaimFirstMintCalls, greaterThan(0),
          reason: 'the guard consulted the claim, then fell open on the null');
    });

    test('the first-mint sentinel is skipped by a peer, never quarantined',
        () async {
      // The sentinel rides in the zone like any record; a device that pulls the
      // zone must SKIP it, not park it as an unknown table.
      final bridge = FakeCloudKitBridge();
      final shared = _FakeSecrets();

      final a = await seedDevice('owner-a', macroGoals: 3);
      await engineFor(a, bridge)
          .enable(keys: SyncKeyStore(shared), localOwner: 'owner-a');
      expect(bridge.records.containsKey(kKeyOwnerSentinelRecordName), isTrue,
          reason: 'the sentinel is really a record in the zone');

      final b = await seedDevice('owner-b');
      final r = await engineFor(b, bridge)
          .enable(keys: SyncKeyStore(shared), localOwner: 'owner-b');

      final diag = await b.diagnostics();
      expect(diag.totalParked, 0, reason: 'the sentinel must not be quarantined');
      expect(diag.localRowsByTable['long_term_goals'], 3);
      expect(r.undecryptable, 0);
    });
  });

  group('undecryptable records', () {
    test('are quarantined and let the change token advance — not held forever',
        () async {
      final bridge = FakeCloudKitBridge();

      // Device A uploads under key A.
      final a = await seedDevice('owner-a', macroGoals: 3);
      await engineFor(a, bridge)
          .enable(keys: SyncKeyStore(_FakeSecrets()), localOwner: 'owner-a');

      // Device B holds an unrelated key and pulls A's zone.
      final b = await seedDevice('owner-b');
      final bEngine = engineFor(b, bridge);
      final rivalKey = SyncCrypto().generateKey();
      final r = await bEngine.syncNow(rivalKey);

      expect(r.undecryptable, greaterThan(0),
          reason: 'the mismatch must be COUNTED, not silently swallowed');
      expect(r.applied, 0);

      final diag = await b.diagnostics();
      expect(diag.totalParked, greaterThan(0),
          reason: 'parked with a reason, so the UI can explain the failure');
      expect(diag.parkedByReason.keys.join(), contains('different sync key'));

      // THE regression: the token must have advanced. Holding it is what
      // pinned the real iPhone at `change token: none` and made every sync
      // re-download and re-discard the entire zone.
      expect(diag.hasChangeToken, isTrue,
          reason: 'an undecryptable record is PERMANENT — holding the token '
              'livelocks the device forever');
      // B still uploads its OWN rows, sealed with its own key — which is
      // precisely how the real Mac put 2 records into the zone that the iPhone
      // could not read. The guard prevents reaching this state; it cannot
      // un-poison a zone already in it.
      expect(r.pushed, greaterThan(0));
    });

    test('a second sync does not re-report the same records', () async {
      final bridge = FakeCloudKitBridge();
      final a = await seedDevice('owner-a', macroGoals: 3);
      await engineFor(a, bridge)
          .enable(keys: SyncKeyStore(_FakeSecrets()), localOwner: 'owner-a');

      final b = await seedDevice('owner-b');
      final bEngine = engineFor(b, bridge);
      final rivalKey = SyncCrypto().generateKey();

      final first = await bEngine.syncNow(rivalKey);
      final second = await bEngine.syncNow(rivalKey);

      expect(first.undecryptable, greaterThan(0));
      // Token advanced, so the delta fetch returns nothing the second time —
      // the device stops burning bandwidth on records it can never read.
      expect(second.undecryptable, 0,
          reason: 'the token advanced past the unreadable records');
    });

    test('the correct key arriving later recovers every parked record',
        () async {
      // The property that makes advancing the token safe. Without the
      // fingerprint-triggered re-fetch, advancing past an undecryptable record
      // would lose it permanently — CloudKit never re-delivers a record the
      // token has passed unless it is edited again.
      final bridge = FakeCloudKitBridge();
      final shared = _FakeSecrets();

      final a = await seedDevice('owner-a', macroGoals: 6);
      await engineFor(a, bridge)
          .enable(keys: SyncKeyStore(shared), localOwner: 'owner-a');
      final realKey = await SyncKeyStore(shared).readKey();

      // B syncs on the WRONG key first: everything parks, token advances.
      final b = await seedDevice('owner-b');
      final bEngine = engineFor(b, bridge);
      await bEngine.syncNow(SyncCrypto().generateKey());
      final parked = await b.diagnostics();
      expect(parked.totalParked, greaterThan(0));
      expect(parked.localRowsByTable['long_term_goals'], 0);
      expect(parked.hasChangeToken, isTrue);

      // The real key finally arrives through the iCloud Keychain.
      final recovered = await bEngine.syncNow(realKey!);

      expect(recovered.applied, greaterThan(0),
          reason: 'the key change must force a full re-fetch');
      final after = await b.diagnostics();
      expect(after.localRowsByTable['long_term_goals'], 6,
          reason: 'every goal recovered, none lost to the advanced token');
      expect(after.totalParked, 0, reason: 'parks cleared once readable');
    });

    test('a device with the RIGHT key is unaffected by the change', () async {
      final bridge = FakeCloudKitBridge();
      final shared = _FakeSecrets();

      final a = await seedDevice('owner-a', macroGoals: 3);
      await engineFor(a, bridge)
          .enable(keys: SyncKeyStore(shared), localOwner: 'owner-a');

      final b = await seedDevice('owner-b');
      final r = await engineFor(b, bridge)
          .enable(keys: SyncKeyStore(shared), localOwner: 'owner-b');

      expect(r.undecryptable, 0);
      final diag = await b.diagnostics();
      expect(diag.localRowsByTable['long_term_goals'], 3);
    });
  });
}
