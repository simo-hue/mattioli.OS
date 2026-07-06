# iCloud Sync on macOS — Implementation Plan

Created: 2026-07-06
Status: Approved design (grill-me interview), pre-implementation
Scope: Flutter desktop app (`desktop/`, macOS only) + coordinated mobile 1.0.10 changes (`mobile/`) + new shared package (`packages/evolve_sync/`). Companion to `mobile/ICLOUD_SYNC_PLAN.md` and `mobile/ICLOUD_SYNC_PRIVACY_BUGS.md` — the wire format, invariants, and accepted limitations defined there apply verbatim here.

> Goal: a Mac in Private Mode joins the exact same CloudKit dataset the iPhone
> already syncs — same container (`iCloud.com.simo.evolve`), same `PrivateZone`,
> same `PrivateRecord` type, same AES-256-GCM payload format, same LWW/tombstone
> semantics — so all of a user's Apple devices converge on one private dataset.

---

## 1. Locked decisions (design interview, 2026-07-06)

| # | Decision | Rationale / cost accepted |
| --- | --- | --- |
| 1 | **E2E key transport = shared keychain access group** `$(AppIdentifierPrefix)com.simo.evolve.sync` in BOTH apps' entitlements; sync key + canonical owner live there (`synchronizable: true`). Mobile 1.0.10 migrates the existing items (read legacy no-group item → rewrite into group → delete legacy; idempotent). | iCloud Keychain syncs across *devices*, not *apps* — without this the Mac can never decrypt. Keeps bundle IDs separate; `keycheck` record already guards key mismatch during the transition. Cost: coordinated mobile release. |
| 2 | **Distribution = Mac App Store.** | Sandbox already enabled (MAS requires it); RevenueCat/StoreKit already integrated; TestFlight for Mac = Production-environment QA channel. Note: universal purchase is impossible (bundle IDs differ: `com.simo.evolve` vs `com.simo.evolve.evolveDesktop`) → separate MAS product. |
| 3 | **Engine lives in a shared package** `packages/evolve_sync/` (path dep in both apps): SyncEngine, SyncCrypto, SyncLocalStore, CloudKitBridge contract + MethodChannel impl, synced-tables/local-only-columns config, write debouncer, FakeCloudKitBridge + engine tests. Key store, schema DDL, service wiring, UI stay per-app. | Wire format and LWW invariants cannot drift between platforms (the worst failure mode is silent cross-device corruption). Mobile diff is mechanical import re-pointing riding the 1.0.10 release it needs anyway. |
| 4 | **Desktop triggers = full set:** launch + window-refocus (AppLifecycleListener) + debounced after-write (~3 s, hooked at the `DesktopPrivateDb` write boundary, which also covers notification-action check-ins) + periodic pull (~15 min; no push in v1, so this is how an idle-open Mac learns of iPhone edits) + manual Sync Now. **Mobile backports the after-write debounce in 1.0.10** (its own documented open refinement; debouncer ships in the package). | A Mac window stays open for days; resume-only triggers would strand edits. |
| 5 | **Avatar syncs now, on both platforms** (encrypted `CKAsset`, record `avatar:<owner>`). Engine populates the asset path; both Swift bridges wrap/unwrap CKAsset temp files; apply re-localizes the image into `private_profile/` and rewrites the local-only `avatar_url`. Avatar record is dirty-marked explicitly (no DB trigger covers it); LWW via its `sync_state` row. | User chose full "all private data syncs" coherence over the defer-recommendation. FakeCloudKitBridge gains asset support so it stays unit-testable. |
| 6 | **UI = an "iCloud Sync" card in the Settings → Privacy section** (above export/import/delete): enable toggle → first-enable disclosure dialog (E2E · your iCloud · keychain-off forfeits data), status line (syncing / idle / no-account / waiting-for-keychain / error), last-synced timestamp, Sync Now button. Strings ported from mobile in all 5 locales (en/it/es/de/ar). | Matches mobile's IA (sync lives under privacy); zero navigation changes. |
| 7 | **Delete private data = full sync reset, mobile-parity** (queue `pending_zone_wipe` → wipe local incl. `sync_state`, preserving the queued wipe → delete zone + keycheck when online → remove key/owner from the shared keychain group → sync off). Disclosure inherits the documented "delete on each device" limitation (#11). | Locked from mobile's docs, not re-decided. |
| 8 | **Gating:** sync runs only when `mode == private && Platform.isMacOS`; `NoOpPrivateSyncService` on Windows/Linux scaffolds and in Supabase mode. | Mirror of the Android pattern. |
| 9 | **Sequencing: Mac release gated on mobile 1.0.10 being live.** Build everything now; submit 1.0.10 when 1.0.9 clears review; submit the Mac app only after 1.0.10 ships. QA in two passes: Xcode-run iOS + Xcode-run Mac (both Development env) first, then TestFlight iOS + TestFlight Mac (both Production env) as the release gate. Desktop's `waitingForKeychain` copy hints "make sure the iPhone app is up to date". | App Store builds hit the **Production** CloudKit environment; Xcode-run builds hit **Development** — mixed pairs never see each other's records. |

Determined defaults (not re-asked): debounce ≈3 s; periodic ≈15 min; keychain item names stay `private_sync_key_v1` / `private_sync_owner_v1` (desktop must use the same names — they are the same items); Dart access-group constant is the full string `8528AN28A3.com.simo.evolve.sync`; engine gets an injected logger (no app_logger dependency in the package); quit-mid-sync is safe by design (`sync_state` stays dirty, next launch resumes).

---

## 2. Work breakdown (each phase: implement → test → commit)

| Phase | Deliverable | Verified by |
| --- | --- | --- |
| **P0 — package extraction** | `packages/evolve_sync/` scaffold; move engine/crypto/local-store/bridge-contract/MethodChannel-impl/fake from `mobile/lib/core/`; re-point mobile imports; move engine tests into the package | package + mobile suites green, `flutter analyze` clean on both |
| **P1 — shared keychain group (mobile)** | `SecureStorageUtils` synced storage gains `groupId`; one-time legacy-item migration in the key-store read path; `Runner.entitlements` gains the group | key-store tests incl. migration idempotency |
| **P2 — avatar CKAsset (shared engine)** | avatar record encode/decode, explicit dirty-marking API, apply-side re-localization hook, FakeCloudKitBridge asset support | engine avatar round-trip/LWW/tombstone tests |
| **P3 — after-write debounce** | debouncer in the package; mobile wiring at the private write methods (loop-safe, per mobile plan §remaining) | debounce coalescing tests; mobile suite green |
| **P4 — desktop Dart integration** | `DesktopSyncKeyStore` (fss 10 `MacOsOptions`, shared group), sync service (Riverpod 3), `adoptOwner` on `DesktopPrivateDb`, prefs enabled-store, all triggers from decision #4, provider refresh after pull (dashboard + analytics), avatar write-path dirty-marking | ported service/engine-integration tests over FFI |
| **P5 — desktop native** | Swift `CloudKitSyncBridge` port registered in `MainFlutterWindow` (single registration path — avoids the mobile bug-#3 class); CKAsset both directions; `DebugProfile.entitlements` + `Release.entitlements` gain iCloud container + CloudKit service + keychain group | best-effort `swiftc -typecheck` here; compile + device QA delegated via TO_SIMO_DO |
| **P6 — desktop UI** | Privacy-section card, first-enable + delete disclosures, strings ×5 locales (ported from mobile), delete flow → full-reset semantics (mirrors mobile fixes #6/#7) | widget tests; full desktop suite |
| **P7 — hardening + handoff** | full 3-suite pass, DOCUMENTATION.md, TO_SIMO_DO QA matrix | all suites + analyze green on mobile, desktop, package |

## 3. Manual prerequisites (owner: Simo — will be tracked in TO_SIMO_DO.md)

1. Xcode: add **iCloud (CloudKit) capability + container `iCloud.com.simo.evolve`** and the **keychain access group** to the *desktop* target; add the keychain access group to the *mobile* target; regenerate provisioning.
2. CloudKit Console: verify `PrivateRecord` exists in **Production** and **promote the new `asset` field** before either release ships.
3. App Store Connect: create the separate Mac app product (universal purchase not possible); privacy answers mirror iOS ("data syncs to the user's iCloud, no third-party servers").
4. Two-pass, two-device QA matrix (Development pair first, TestFlight/Production pair as release gate): fresh Mac pulls all; both-had-data merge; offline edits converge; edit-vs-delete; avatar round-trip; delete-doesn't-resurrect; keychain-off warning; old-iOS + new-Mac shows waiting-with-update-hint.

## 3b. Implementation status — 2026-07-06

All code-side phases are done; what remains is Simone's manual Apple setup +
device QA (§3, tracked in TO_SIMO_DO.md).

| Phase | Status | Commit |
| --- | --- | --- |
| P0 — packages/evolve_sync extraction | ✅ | `4e59eb4`→`refactor(sync)` |
| P1 — shared keychain group + migration | ✅ | `feat(sync): shared keychain access group` |
| P2 — avatar CKAsset in the shared engine | ✅ | `feat(sync): avatar CKAsset sync` |
| P3 — after-write debounce + mobile wiring | ✅ | `feat(sync): after-write debounced sync trigger` |
| P4 — desktop Dart integration | ✅ | `feat(desktop): full Dart-side iCloud sync integration` |
| P5 — desktop Swift bridge + entitlements (typechecked; compile pending Xcode) | ✅ | `feat(desktop): native CloudKit bridge` |
| P6 — desktop settings card + full-reset delete + l10n ×5 | ✅ | `feat(desktop): iCloud Sync settings card` |
| P7 — docs + TO_SIMO_DO handoff; mobile bumped to 1.0.10+14 | ✅ | this commit |

Suites at handoff: package 73/73 · mobile 144/144 · desktop 94/94; `flutter
analyze` at baseline on all three. Two latent desktop bugs fixed en route
(profile `avatar_path`→`avatar_url` column, category-archive `updated_at`).

## 4. Risks carried forward

- **Cross-schema-version apply (#10)** is now cross-*platform*: never add a column to a synced table in one app's release without the other's (the shared package makes the config single-source, but store DDL is still per-app).
- **Old iOS (≤1.0.9) + new Mac:** key stays in the legacy group → Mac sits in `waitingForKeychain` (with update hint) until the iPhone updates. Accepted transitional state; `keycheck` prevents divergence.
- **macOS sandbox temp files for CKAsset** (upload staging + download location) need device verification — flagged in the QA matrix.
- All accepted limitations from `mobile/ICLOUD_SYNC_PRIVACY_BUGS.md` (#10, #11, identity-edge) apply unchanged.
