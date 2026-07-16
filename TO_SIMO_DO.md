# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] Update for the habits to decide the day of the week to decide when it should be completed and obviously when it should appear on the day's pop up calendar view. The desktop UI element is already in place but from mobile is totally missing
- [ ] In the habits protocol tab view I want to see only the current habits and not also the past ones
- [ ] MacOS app doesn't have the log in phase, I want to have the same logic of the mobile iOS app as it's professional and complete
- [ ] Cloud mode for AI, in both mobile and desktop implementation, we need to implement the fact that they need to insert their API Keys, we can also give a possibility to add two of them so they can have a back up in case the first one is not working ( if you think it does make sense )
- [ ] For the desktop implementation what has been done with ollama is outstanding and I want to replicate the same thing also with LMStudio so the major local LLM providers are supported
- [ ] Curor of AI Coach Response
- [ ] From mobile implementation, in the settings the "App logs" field has to few bottom margin from the button "Go to login", I want you to increase it.
- [ ] mobile animation between lateral scroll on the goals page? Improve it


## Auto-Verified Habits — Xcode setup (feature is dark behind `VerificationConfig.enabled`)

Native code is written but UNVERIFIED (no iOS SDK on the dev machine — compile in Xcode).
The app-side bridges now live INSIDE `mobile/ios/Runner/AppDelegate.swift` (like
CloudKitSyncBridge), so **no files need adding to the Runner target**. Steps:

- [ ] Runner target → Signing & Capabilities: add **HealthKit** + **Family Controls** capabilities.
- [ ] Add `NSHealthShareUsageDescription` to the Runner Info.plist (read-only; specific text).
- [ ] Create the **DeviceActivityMonitor** app-extension target (iOS 16+); add ONLY
      `mobile/ios/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` to it
      (it's self-contained). Its Info.plist: `NSExtensionPointIdentifier =
      com.apple.deviceactivity.monitor-extension`, `NSExtensionPrincipalClass =
      $(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension`. Enable Family Controls on it too.
- [ ] Create an **App Group** and add it to BOTH Runner + the extension. Set its id in TWO
      places (must match): `VerificationAppGroup.suiteName` in `AppDelegate.swift` and
      `AppGroup.suiteName` in the extension (currently `group.com.simo.evolve.verification`).

### Auto-Verified Habits — deferred Dart follow-ups CLOSED (2026-07-14): on-device QA

- [ ] **Still deferred (intentionally, Screen Time only)**: `syncMonitoredGoals` diffing —
      not needed until `screenTimeEnabled` flips; the streak-tail cross-pass recompute is
      documented as acceptable (single-day, writes apply ascending).

## Private-mode locked-DB recovery + iCloud onboarding — on-device QA (desktop + mobile)
Built + `flutter analyze`-clean + unit-tested here, but no Xcode/CloudKit on this Mac. The dead-end where
"continue privately" showed "Operazione non riuscita" is replaced by a recovery gate. To unblock the Mac Mini
you can now just enter Private mode → **Reset & start fresh** on the recovery screen (dev data is disposable),
OR delete `~/Library/Containers/com.simo.evolve/.../evolve_private_v2.db*`. Then verify on a real device:
- [ ] **Sync OFF, locked DB** → the recovery screen appears ("Can't unlock private data"), **Reset & start
      fresh** works (fresh empty DB, no crash), **Back to sign in** returns to the login page (not stranded).
- [ ] **Sync ON, locked DB** (enable iCloud sync on another device first, then lock/rotate signing) → the gate
      **auto-resets + re-pulls from iCloud** and shows the "restored from iCloud" toast — data is back, no prompt.
- [ ] **Onboarding prompt**: first time entering Private mode on an iCloud-signed-in device with sync OFF, the
      one-time "enable iCloud sync?" (E2E disclosure) prompt shows; **Not now** = stays off; **Enable** turns sync
      on. It must NOT reappear on later entries, and must NOT show when iCloud is signed out (offer later instead).
- [ ] **Startup path**: with `active_data_mode = private` persisted and a locked DB, cold-launch routes through
      the gate (not a broken empty dashboard).
- [ ] **Coherence**: confirm desktop and mobile behave identically for all of the above.
- [ ] **Signing (prevention)**: keep the `Apple Development` cert/team `8528AN28A3` present on BOTH Macs so
      `flutter run` never falls back to ad-hoc (`CODE_SIGN_IDENTITY = "-"`), which is what orphans the key.

### Follow-up fix (2026-07-15): recovery-screen crash via automatic sync — RE-VERIFY on-device
The **Back to sign in** / recovery-screen flows above were crashing on a locked DB: the automatic iCloud-sync
lifecycle (`DesktopSyncLifecycle`, which wraps the recovery screen) fired `syncNow()` on window refocus / its
15-min timer / launch and let `PrivateDatabaseLockedException` escape unhandled (`_sync()` now try/catches it).
Fixed + Dart-verified here; confirm on the actual different Mac (the one that showed the crash):
- [ ] With a locked DB, sit on the recovery screen, click away and back to the window (triggers refocus sync),
      then click **Back to sign in** → it must reach the login page with **no crash** in the `flutter run` console.

## iCloud sync hardening (2026-07-15) — on-device QA + deferred native follow-ups
All Dart changes are `flutter analyze`-clean and unit-tested here (evolve_sync 78 green, mobile 230 green),
but no Xcode/CloudKit on this machine. The reported crash (`Using "ref" … unmounted`) was already fixed in
shipped source; this pass hardened the whole sync surface. Verify on real devices:

### On-device QA (mobile)
- [ ] **Toggle sync off while a sync is in flight, then immediately pop the iCloud Sync screen** (edge-swipe
      back) → no crash in the console (the `_refresh`/haptic ref-after-dispose class).
- [ ] **Two devices, an edit that can't apply**: force a transient apply failure (e.g. airplane-mode flap
      mid-pull) → the record is NOT lost; a later sync re-fetches and applies it (change token was held).
- [ ] **Locked-DB auto-recovery, DEFERRED enable**: enable sync on device A, then on a freshly-restored device B
      whose E2E key has synced but the canonical-owner Keychain item has NOT yet → recovery must show
      "waiting for iCloud key" (NOT a false "restored from iCloud" over an empty DB), and the real data must
      come back on a later retry once the owner propagates. The locked cache must be preserved (`.recovery-bak`),
      not destroyed.
- [ ] **Locked-DB auto-recovery, iCloud unavailable in the gap** → "can't unlock" recovery screen, data intact.
- [ ] **SyncOffBanner**: enable iCloud sync from the banner action → returning to the dashboard, the red
      "data lives only on this device" banner is GONE immediately (no app restart needed).

### Deferred native follow-ups (need an Xcode/device build — OPTIONAL hardening, not blockers)
These are in `mobile/ios/Runner/AppDelegate.swift` AND the line-for-line `desktop/macos/Runner/AppDelegate.swift`.
The Dart change-token-hold fix already prevents the *data loss* from the first two; these are defense-in-depth:
- [ ] **CKAsset temp-file lifetime** (`encodeFromRecord`, ~line 302): `asset.fileURL.path` is a CloudKit-owned
      temp path that can be purged after the fetch op is released. Copy the asset into an app-controlled file
      synchronously before returning it to Dart (and have the Dart avatar store delete that copy after reading).
- [ ] **Per-record fetch `.failure`** (`fetchChanges` `recordWasChangedBlock`, ~line 257): currently a per-record
      failure is silently dropped. At minimum `os_log` it so the drop is observable.
- [ ] **Honor CKError backoff** (`flutterError`, ~line 331): pass `(error as? CKError)?.retryAfterSeconds` in
      `FlutterError.details` and have the Dart service defer the next sync by that interval, so a rate-limit
      isn't immediately re-hit. Optionally add a small bounded native retry for transient CKErrors.

## FIX (2026-07-15 11:30) — desktop RELEASE grey screen in Private mode — VERIFY on Mac Mini
Real production ship-blocker, fixed in `desktop/lib/core/app_bootstrap.dart` (one line:
`on AssertionError` → `catch (_)` in `supabaseClientProvider`). Root cause: Private mode skips
`Supabase.initialize()`, and in a RELEASE build `Supabase.instance.client` throws
`LateInitializationError` (not `AssertionError`, because release strips asserts), which the old
narrow catch let escape → the app root crashed to a grey window for every Private-mode release user.

- [ ] **Get the fix onto the Mac Mini** (the edit is in the `/Users/simone.mattioli` working copy).
      If the Mini's repo isn't git-synced with it, apply the one-liner directly:
      in `desktop/lib/core/app_bootstrap.dart`, change `} on AssertionError {` to `} catch (_) {`.
- [ ] **Verify the grey screen is gone**: `flutter build macos --release --dart-define-from-file=.env`
      then `open build/macos/Build/Products/Release/Evolve.app` → it must now RENDER into Private mode
      (the recovery/home screen), not a blank grey window.
- [ ] **Then settle the keychain question (now unblocked)**: with the release build rendering, add a
      habit, Cmd-Q, and `open` the SAME .app again with NO rebuild → the habit must persist. If it does,
      the SQLCipher key is stable for a shipped binary (the every-launch lockout was only the
      `flutter run` re-signing loop). Signing was already verified correct (Apple Development, team
      8528AN28A3, keychain groups resolve WITH the prefix, provisioning profile embedded).
- [ ] If you want the dev `flutter run` loop to stop nagging with the reset screen, ask for the
      debug-only auto-reset (kDebugMode + macOS) — zero effect on release.

## Desktop test suite (2026-07-15) — run WITH the Supabase defines
Fixed the last hanging desktop test (`icloud_sync_card_test` "delete private data" — was a
loading-spinner `pumpAndSettle` hang; now verifies the card's contract with bounded pumps, no
product code change). The full desktop suite is **311/311 green** — but you must run it the same
way you run the app, or one intentional security guard (`desktop_supabase_config_security_test`,
which asserts the Supabase config is present via build-time defines) reports a false failure:
- [ ] Run desktop tests as: `cd desktop && flutter test --dart-define-from-file=.env`
      (a bare `flutter test` "fails" only that config-presence guard — by design, not a bug).
      Make sure CI passes the same defines.

## Desktop goal-editor crash fix (2026-07-15) — on-device QA
Fixed a crash where editing an already-inserted goal threw `Bad state: No element` and blanked
the editor dialog (empty/unmatched category picker → `categories.first` on an empty list). Verified
by analyze + full suite (317/317) but the GUI can't run here. On the Mac Mini:
- [ ] With **no saved goal categories**, create a goal, then reopen it via edit → the editor must
      open normally (title + category picker populated with the goal's own category), NOT crash to
      a blank/grey dialog. Saving must keep the goal's category intact.
- [ ] Sanity check the normal path too: with several saved categories, editing a goal still shows
      its current category pre-selected and lets you switch it.

## Desktop recovery-hardening — mirrored from mobile (2026-07-15) — on-device QA
The desktop macOS locked-DB auto-recovery now behaves IDENTICALLY to the hardened mobile app:
stash-and-restore instead of destroy-before-confirm, `enable()`'s result is captured (no false
"restored from iCloud" over an empty DB), honest waiting/needs-choice states, `_open` publish-after-init
+ generation guard, and the fire-and-forget onboarding try/catch guard. Verified: analyze clean + full
desktop suite **317/317** (with the Supabase defines) + a desktop-vs-mobile adversarial parity review.
No Xcode/CloudKit here, so confirm the real flows on the Mac Mini:
- [ ] **Locked DB + sync ON, canonical owner not yet propagated** (enable defers) → the recovery screen
      shows "waiting for iCloud key" and the LOCAL data is preserved (a `.recovery-bak` set exists, not
      deleted); a later retry recovers the real data — NOT a "restored from iCloud" notice over empty data.
- [ ] **Locked DB + iCloud unavailable** → "can't unlock" recovery screen, data intact (stash restored).
- [ ] **Locked DB + full auto-recover works** → "restored from iCloud" notice, data back, `.recovery-bak` gone.
- [ ] **Coherence** — confirm desktop and mobile behave identically across all of the above.

## Desktop pre-release parity fixes (2026-07-15) — on-device QA
Audit found + fixed 5 desktop-vs-mobile gaps (analyze clean, 317/317). Confirm the two with real UX on the Mac Mini:
- [ ] **Cloud-mode "Replace" restore (#1, was CRITICAL)**: in Supabase mode, restore a backup with "Replace"
      selected → data replaces correctly AND (sanity) killing the app mid-import no longer leaves the account
      empty (upserts now run before any prune).
- [ ] **Sync-off banner (#2)**: enter Private mode with iCloud sync OFF → the red "your data lives only on this
      device" banner shows on the dashboard; tapping its action opens Settings → Privacy (iCloud sync); enabling
      sync clears the banner immediately; dismiss hides it for the session.
- [ ] **Delete private data (#3)**: with a transient iCloud/keychain hiccup, "delete private data" still wipes
      the LOCAL data (not just a "failed" toast).
- [ ] **Global error boundary (#4)**: a forced error shows a friendly localized dialog (no raw stack) in a
      release build, not Flutter's grey box.

---

# 🚨 PRE-APP-STORE AUDIT (2026-07-16) — MANUAL ACTIONS REQUIRED

Deep multi-agent audit of `desktop/` + `mobile/` (23 dimensions, 87 candidate findings,
83 confirmed after adversarial verification, 4 refuted). Blockers + high-severity issues
fixed across 3 waves; every fix independently reviewed. **The items below are things ONLY
YOU can do — the code is inert or wrong until they are done.**

## ⛔ BLOCKING — do these BEFORE you submit, in this order

- [ ] **`REVENUECAT_WEBHOOK_SECRET` — FAIL-CLOSED, will break Pro sync if skipped.**
      The webhook previously accepted **unauthenticated** calls: anyone on the internet could
      grant or revoke Pro on any account. It is now fail-closed, so with the secret unset it
      returns 500 to EVERY request **including real RevenueCat ones**, and Pro entitlements
      silently stop syncing to `profiles.is_pro`. Steps:
      1. Generate a high-entropy secret.
      2. `supabase secrets set REVENUECAT_WEBHOOK_SECRET=<value>`
      3. RevenueCat dashboard → webhook → Authorization header = **exactly** `Bearer <value>`
         (the code compares the full header string, `Bearer ` prefix included).
      4. Smoke-test after deploy: a wrong/absent header must 401; a real event must land.

- [ ] **Run the two new migrations** (fix a live privilege-escalation hole — any authenticated
      user could self-grant Pro by writing `is_pro=true` to their own `profiles` row):
      - `migrations/20260716_pin_profiles_entitlement_columns.sql`
      - `migrations/20260716_close_legacy_table_rls.sql`
      Both are additive and safe to run on the existing DB. `mobile/mobile_schema.sql` and
      `public/schema.sql` were also fixed so a FRESH provision is secure by default.

- [ ] **Deploy + configure `supabase/functions/revoke-apple-token`** (App Store Guideline
      5.1.1(v): a Sign in with Apple app MUST revoke the Apple token on account deletion —
      reviewers explicitly test this). **Until this is deployed AND configured, the mobile
      deletion flow is WORSE than before**: the user gets an Apple credential sheet, then a red
      error toast (the account still deletes — fail-safe by design — but it looks broken).
      1. Apple Developer → Certificates, IDs & Profiles → Keys → create a key with
         **Sign in with Apple** enabled. The `.p8` downloads **ONCE ONLY**.
      2. `supabase functions deploy revoke-apple-token`
      3. `supabase secrets set` all four (nothing is hardcoded; nothing ships in the binary):
         - `APPLE_TEAM_ID` — 10-char Team ID (Membership)
         - `APPLE_KEY_ID` — 10-char Key ID of that SIWA key
         - `APPLE_PRIVATE_KEY` — full `.p8` contents, BEGIN/END lines included (literal `\n` ok)
         - `APPLE_CLIENT_ID` — **the iOS bundle id `com.simo.evolve`, NOT the Service ID**
           (mobile uses native SIWA, so the authorizationCode is bound to the bundle id; a
           Service ID here makes Apple reject with `invalid_client`). **Confirm the bundle id.**
      4. Do **NOT** add a `[functions.revoke-apple-token]` block to `supabase/config.toml` —
         edge functions default to `verify_jwt = true`, which is what this function needs.
         Setting `verify_jwt = false` would let anyone revoke anyone's Apple grant.
      - NOTE: this function has **never been executed** (`deno` is not installed on this Mac).
        The ES256/djwt signing + Apple `/auth/token` exchange are reasoned from docs only.
        **Test it on a throwaway account before relying on it.**

- [ ] **Export compliance (BIS)** — you chose "declare true + claim the 5D992.c exemption".
      `ITSAppUsesNonExemptEncryption` is now `true` on **both** platforms (the app bundles
      SQLCipher + custom AES-GCM E2E, which fits none of Apple's listed exemptions).
      You must file the **annual self-classification report to BIS**. After you have it, add
      `ITSEncryptionExportComplianceCode` to both Info.plists to stop App Store Connect asking
      the questionnaire on every single build.

## ⚠️ RESIDUAL RISK YOU ACCEPTED (stated once, your call — but know it before you submit)

- [ ] **HealthKit values still sync to iCloud/CloudKit.** You chose "keep values in Private/E2E
      mode only, never Supabase". The Supabase upload path is now closed (BOTH paths — the goal
      upload *and* a second one via backup import that the first fix missed). **But Apple's
      HealthKit terms prohibit storing HealthKit data in iCloud _regardless of encryption_.**
      This is a real, not theoretical, rejection risk, and the HealthKit + CloudKit entitlement
      pair is visible in your entitlements file. If you want it fully compliant, the fix is to
      recompute verdicts on-device and sync nothing health-derived. Your call — flagging it once.

## 📱 ON-DEVICE QA — I could NOT verify any of this (no Xcode on this Mac)

- [ ] **macOS RELEASE build sign-in (was THE top blocker).** `Release.entitlements` was missing
      `com.apple.security.network.server`, so the sandbox blocked the loopback OAuth callback
      bind — **every Google/Apple sign-in was dead in the shipped build only** (it works under
      `flutter run`, which is why it was never caught). Fixed, but **structurally unverifiable
      here**: entitlements are not embedded in an unsigned local build. **Do a real signed
      archive and actually sign in with Google AND Apple.** This is the single highest-value
      thing to test.
- [ ] **Private mode data survives a relaunch (was a catastrophic data-loss blocker).**
      `desktop/lib/main.dart:24` called `FlutterSecureStorage.setMockInitialValues({})`
      **unconditionally in production**, replacing the Keychain with an in-memory map — so the
      SQLCipher key, the Supabase session AND the E2E sync secret were destroyed on every quit.
      Removed entirely. ⚠️ **This line was probably YOUR local dev workaround** (unsigned macOS
      builds can't reach the Keychain). If your local `flutter run` now fails on Keychain access,
      that is expected — tell me and I'll add a debug-only, release-impossible escape hatch.
      Verify: Private mode → add data → quit → reopen → **data still there, no reset prompt.**
- [ ] **Private mode shows data on launch** (was: empty dashboard/habits/goals every launch until
      manual Refresh — data was intact on disk, the app just looked wiped).
- [ ] **HealthKit permission sheet is in the user's language.** `NSHealthShareUsageDescription`
      was Italian-only and missing from all 5 `InfoPlist.strings` — every non-Italian user, and
      the reviewer, saw an Italian prompt. Now localized (en/it/es/de/ar). Check on a non-Italian device.
- [ ] **iPhone-only.** `TARGETED_DEVICE_FAMILY` is now `"1"` (was `"1,2"` — iPad, which the
      portrait-locked UI was never designed for). Confirm iPad is gone from App Store Connect.
- [ ] **Paywall prices** now come from real StoreKit products (they were hardcoded `€4,99`/`€29,99`
      — every non-Eurozone user saw the WRONG currency and amount). Check a non-EUR storefront.
      When products can't load, the UI now says "Unavailable" rather than inventing a price.
- [ ] **Account deletion** (mobile + desktop) end-to-end on a throwaway account.
- [ ] **CloudKit sync across two devices** — the sync engine changed materially (batching,
      lost-write guard, forward-compat, poison-pill quarantine). Test iPhone ↔ Mac both ways.

## 📋 App Store Connect — privacy labels

- [ ] **ADD "Other User Content"** → Linked to user, not tracking, purpose App Functionality
      (goal/habit titles + descriptions go to Supabase; titles + your first name go to openrouter.ai).
- [ ] **Do NOT declare Health/Fitness** — correct now that no health measurement reaches Supabase.
      If the label currently claims health collection, remove it.
      (`PrivacyInfo.xcprivacy` was updated to match — keep the two consistent.)

## 🔑 BYOK AI Coach (your decision: "the user must insert his own API Key")

Implemented on **both** platforms. The key now lives in the **Keychain** (`flutter_secure_storage`,
never SharedPreferences), is never logged/sent to Sentry/included in any export, and is never
rendered back into the UI. No key can be compiled into a build any more: desktop's
`String.fromEnvironment('OPENROUTER_API_KEY')` is gone and the live `cloud_coach_backend`
takes an injected, Keychain-backed key. A 401/403 surfaces a localized "check your API key"
message. With no key, the Coach shows a localized setup card (never a dead button — Guideline 2.1).
New `ai.apiKey` i18n block (16 keys × 5 locales × both apps).

- [ ] **🚨 ROTATE YOUR OPENROUTER KEY — the code fix cannot undo this.** Any desktop bundle you
      already built or distributed with `--dart-define=OPENROUTER_API_KEY=sk-or-v1-…` **still
      carries that key, extractable from the binary**. The fix guarantees no FUTURE build can
      embed one; it cannot un-ship a past one. Rotate at openrouter.ai and treat the old key as
      compromised.
- [ ] **Delete your local `mobile/lib/core/openrouter_config.dart`.** It is gitignored (so no
      reviewer ever sees it) and now has **ZERO importers** — it cannot reach a binary — but on
      your machine it may still hold a real key. On this machine it held only the placeholder.
      The tracked `.example` was deleted, so a fresh clone builds with no OpenRouter config at all.
- [ ] **Product change to be aware of**: the AI Coach now requires every user to supply their own
      OpenRouter account + key. (The audit's original suggested fix was a server-side proxy, which
      would keep the Coach working out-of-the-box — BYOK is the stricter remediation you chose.)
      Desktop still has the keyless local Ollama/LM Studio backend as a fallback; mobile does not.
- [ ] **Dual-key backup** (your "if you think it does make sense" musing): **not built** — I
      recommend against it. A second key on the same provider fails identically for the realistic
      outages (OpenRouter down, or account out of credit); it only helps if one key is revoked
      while another on the same account lives, which is already covered by a clear localized error.
      It would cost a failover state machine + doubled settings UI + doubled i18n right before
      submission. If you want real redundancy later, the higher-value version is a second
      *provider* (or a local model on mobile), not a second key. Say the word and I'll add it.
- [ ] **On-device QA**: the real Keychain round-trip is only exercised via mocks here. Verify
      entering/replacing/clearing a key on both platforms, and that a bad key shows the localized
      error rather than failing silently.

## 📄 Stale docs now contradicting the code (low priority, not fixed — out of the audit's scope)
- [ ] `desktop/FEATURE_PARITY.md:40`, `DOCUMENTATION.md:1086`, `apple/TO_SIMO_DO.md:14` all still
      describe the removed build-time `OPENROUTER_API_KEY` flow.

## 🧮 Deferred owner decision — historical streak data
- [ ] The DST streak bug (`Duration` day-walking skipped the spring-forward day) is fixed on BOTH
      platforms, so **no new corruption**. But `goal_logs.streak` rows already written across past
      transitions keep their wrong values: `best_streak` is a stored `math.max` that only ratchets
      upward, so a fabricated record streak can never self-heal. A one-off `recomputeStreaksForGoals`
      backfill is the only cure — but it would visibly LOWER some users' "best streak" with no
      explanation. That is a product/trust call, not an engineering one. Doing nothing is defensible.

## 🔎 New-code review (2026-07-16, follow-up) — one item is YOURS to decide

After committing the fixes, I audited the code the fix-waves themselves wrote (the two edge
functions, the migrations, BYOK) — since that code never went through the original audit. The
revoke-apple-token function and mobile BYOK came back CLEAN. Six smaller issues surfaced; I'm
fixing the four that are in-scope. This one is web-adjacent, so I left it for you:

- [ ] **`public/schema.sql` is served on the public internet.** It sits in the Vite `public/`
      dir, so `vite build` copies it into `dist/` and `.github/workflows/deploy.yml` publishes it to
      GitHub Pages — it's fetchable at `https://simo-hue.github.io/mattioli.OS/schema.sql` (robots
      `Allow: /`). It's a full DB schema dump (table/column names + RLS policy definitions) of the
      SAME Supabase backend the mobile/desktop apps use. No secrets or data rows — it's information
      disclosure, LOW severity, and the same content is already public in your source repo. But a
      DB DDL dump has no reason to be a shipped static web asset. You told me to leave the web app
      alone, so I did not touch it. Fix when convenient: remove `schema.sql` from `public/` (the
      root-level `schema.sql` copy is not served and can stay). The `schema.sql` at the repo root
      and in `public/` are not identical — the public one is actually a staler subset.

## ✅ Webhook out-of-order guard — now IMPLEMENTED (adds one migration to your list)

The deferred item from the new-code review is done in code (independently reviewed GOOD, all
ordering cases traced). It makes the RevenueCat webhook reject stale/reordered redeliveries (an
EXPIRATION redelivered after a RENEWAL can no longer wrongly revoke a paying user).

- [ ] **Apply the new migration** `migrations/20260716_add_revenuecat_event_timestamp.sql`
      (alongside the other two 2026-07-16 migrations). It adds a nullable
      `profiles.revenuecat_event_timestamp_ms` column and pins it (only the service-role webhook
      may write it — a user who could set it would be able to freeze their own `is_pro=true`).
- **Deploy order does NOT matter.** The webhook is deploy-order-safe: if you deploy the function
      before applying the migration, it silently behaves as it did before (idempotency only) and
      starts enforcing ordering automatically once the column exists — no redeploy needed.
- Still no runnable test harness here (no `deno`/`tsc`), so the webhook change is verified by
      review + static inspection, not execution — worth a staging check of a reordered event if you
      have one, but it degrades safely either way.

## 🍏 PREVIOUS APP REVIEW REJECTION (Submission 4a3fcd37, macOS v1.0(1), July 15 2026)

Two guidelines were cited. The CODE side of both is now addressed & verified, but each has a
MANUAL App Store Connect half that code cannot do. **Do NOT resubmit without the manual steps.**

### Guideline 3.1.2(c) — subscription disclosures
CODE (verified in the current desktop paywall, Settings → Evolve Pro): plan titles (Monthly/Annual),
length, real StoreKit price (`storeProduct.priceString`, never the plan name), auto-renewal
disclaimer, functional Privacy Policy link (https://simo-hue.github.io/evolve/privacy.html — confirmed
live, 200), functional Terms/EULA link (Apple standard EULA), Restore Purchases, Manage Subscription.
Mobile paywall has the same. **This half is done.**

- [ ] **MANUAL (required — the code fix alone does NOT clear this):** in App Store Connect, add the
      **Terms of Use (EULA) link to the App Description** (or the custom-EULA field), and the
      **Privacy Policy URL to the Privacy Policy field**. The reviewer explicitly required the links
      in the *metadata*, not just the app. Use the same two URLs the app uses.

### Guideline 2.1(b) — "cannot locate the In-App Purchases"
Most likely CODE cause is now fixed: macOS OAuth sign-in was DEAD in release builds (the missing
`com.apple.security.network.server` entitlement), and the paywall sits behind the login gate in
Supabase mode — so the reviewer couldn't sign in → couldn't reach Settings → couldn't find the IAP.
That entitlement is now present, and the paywall loads real products (public RevenueCat key committed,
`isConfigured` = true). **But 2.1(b) is mostly manual/config + a required reply:**

- [ ] **Accept the Paid Apps Agreement** (App Store Connect → Business). IAP will not function at all
      until the Account Holder accepts it — a prime suspect for "cannot locate the IAP."
- [ ] **Confirm the IAP products are submitted & in a review-ready state** and configured for the
      Apple sandbox (the monthly + yearly subscriptions).
- [ ] **Reply to the reviewer with the navigation steps**, e.g.: "Launch app → complete onboarding →
      sign in → open **Settings** → **Evolve Pro** section → the Monthly/Annual plans and prices are
      shown there, with Restore Purchases." Put this in the App Review Information → Notes field too.
- [ ] Provide a **screen recording** of the paywall (the reviewer asked for one to confirm).

## 🖥️ Local `flutter run` DB reset — explained + smoothed (2026-07-16)

The "DB Error 26 / file is not a database → reset in Private mode on launch" you saw is a
**local-dev signing artifact, NOT a release bug**: the SQLCipher key is stored in the Keychain
scoped to `$(AppIdentifierPrefix)com.simo.evolve`, and an unsigned/ad-hoc `flutter run` has an
unstable Team ID prefix, so the key written one run isn't found the next → the old DB can't be
decrypted → recovery resets it. A signed/notarized/App Store build has a stable Team ID, so the
key persists and this does NOT happen.

Two things landed to make dev smooth + recovery robust (both green, independently reviewed):
- **Debug-only escape hatch**: in DEBUG builds only, the Private-mode device-local secrets (SQLCipher
  key + owner UUID) now persist in a file (`<AppSupport>/dev_device_local_secrets.json`) so your
  `flutter run` stops resetting the DB every launch. Gated on `kDebugMode` → **impossible in release**
  (the branch is compiled out; release uses the real Keychain, byte-for-byte unchanged).
  ⚠️ Heads-up: that dev file holds the DB key in **plaintext**. It's outside the repo, debug-only,
  and never created by a release build — but delete it if you ever want a clean dev slate.
- **Recovery hardening**: the "Reset & start fresh" reset+reopen now runs under the sync engine's
  exclusion lock, so the auto CloudKit sync can't be mid-open while the file is deleted/recreated —
  fixing the `out of memory` on `BEGIN EXCLUSIVE` + double-reset you saw in the log.

- [ ] **STILL VERIFY on a SIGNED build** (unchanged from before): the whole point is that a properly
      signed build persists the key. Do a signed/notarized (or TestFlight) build → Private mode →
      add data → quit → reopen → **data still there, no reset**. If it DOES reset on a signed build,
      your Xcode signing Team / provisioning for the keychain-access-group is misconfigured — tell me.
