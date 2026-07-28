# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] what happens if I modify manually an automatic habits?
- [ ] Macro goals still need a numeric target + progress bar (status already cycles active/completed/failed). Habits are DONE — the Checkbox / Number / Automatic picker and quantitative targets are live; MacroTargetsConfig.enabled is still false on both apps.

---

# TO DOUBLE CHECK:

- [ ]

## prompt to run 2
/grill-me We are working on the flutter implementation, so both desktop and mobile. And as we have connected the screen time option for the auto-verifiable habits, I want you to ask this question as obviously I set a timer of 10 minutes for example on a specific app but what I was thinking about as it's obviously true at the beginning of the day. The problem is that how is handled the fact that the number obviously increases during the day? Is the habits checked every time? Or whenever it gets it first state then it's fixed and never checked again?


---

```bash
flutter run -d macos --dart-define-from-file=.env
flutter build macos --release --dart-define-from-file=.env
```

```bash
flutter build ipa --release
```

---

## PHASE 5 — RELEASE RUNBOOK (2026-07-27) — everything left is on your Xcode Mac

Pre-flight done here, nothing outstanding on my side:
- All six CI surfaces green; `flutter analyze --fatal-infos --fatal-warnings` clean.
- The **v6→v11 chain now has a real test** (`packages/evolve_sync/test/private_db_schema_v6_to_v11_chain_test.dart`):
  a realistic v6 database with 40 logs, a v6 HealthKit rule, macro goals and moods,
  upgraded through all five legs in ONE open. Asserts no row is lost, the v6 rule
  survives, every synced table keeps its dirty/tombstone triggers, and re-running is a
  no-op. It does NOT prove the encrypted half — SQLCipher is orthogonal, and only a
  device settles it. That is step 3.
- All 6 Supabase migrations applied (you did the 6th on 2026-07-27).

### Versions — DECIDED 2026-07-27
Both apps ship `com.simo.evolve`, i.e. ONE App Store record under Universal Purchase,
so users see a single product and the marketing version must match. Both are now
**1.2.0** (a feature release: class picker + quantitative targets + compound).
Build numbers stay on independent per-platform tracks because App Store Connect
requires each to exceed the last upload for THAT platform: **mobile 1.2.0+41**,
**desktop 1.2.0+25**.

### Ordered steps (Mac)
1. [ ] `git pull` — main is at the Phase 0 fixes + this runbook.
2. [ ] Build BOTH from the SAME commit:
       `cd mobile && flutter build ipa --release`
       `cd desktop && flutter build macos --release --dart-define-from-file=.env`
3. [ ] **Install over EXISTING v6 data — do not wipe first.** The whole point is to watch
       the chain run on a real encrypted file. On first launch of each app, read the
       console for:
       `[PrivateDB] open: stored user_version=6, code PrivateDbSchema.version=11`
       If it says anything else, STOP and send me the line.
4. [ ] Run the QA script in `HABIT_CLASSES_PLAN.md` §6 **and §6a** (§6a is new — it covers
       the Phase 0 regressions, and item 1 is the one that matters most: a limit habit's
       recorded breach surviving a sync + two iPhone resumes).
4a.[ ] **Habit day-dots (new, desktop only).** On Overview › "Protocollo di oggi" AND
       Abitudini › Protocollo, the 7 marks are now the 6 days BEFORE today plus today —
       today is always the last one, haloed. Check on the Mac:
       - the last mark fills the moment you check a habit off today, and empties again
         when you un-check it (no refresh, no app restart);
       - a day you marked SKIPPED shows red, not grey;
       - hovering any mark names its day and outcome ("22 luglio · Completata"), and the
         last one says "Oggi · …";
       - **clicking a mark does nothing** — only the checkbox/row toggles the day;
       - a Number habit's last mark fills when you reach the target; a LIMIT habit's last
         mark stays grey until the day closes (by design — the ring shows the live number).
5. [ ] Release iOS + macOS together. **No rollback**: `onDowngrade` throws by design, so a
       device that reaches v11 cannot open a pre-v11 build ever again.

### Hazards, unchanged
- Never publish a pre-v11 build after this ships.
- Cross-DEVICE version skew is safe (sync preserves unknown columns); cross-BUILD
  downgrade on one device is not.

## Schema snapshot + CI (2026-07-27) — COMPLETE

Weekly quota closed permanently (rationale in `HABIT_CLASSES_PLAN.md` §2a),
schema drift fixed, CI widened to desktop + all 4 packages, drift guard extended.
`migrations/20260727_complete_bootstrap_chain.sql` applied to Supabase by Simone
on 2026-07-27. No outstanding manual actions for this workstream.

## Quantitative targets — mobile UI (LIVE since 2026-07-24; QA still owed)

The mobile UI is LIVE: `TargetsConfig.enabled` (mobile/lib/core/
targets_config.dart) and `DesktopTargetsConfig.enabled` are both true. They were
flipped BEFORE the on-device QA below, which is therefore still owed — and the
release build must carry schema v11 + the Supabase migrations applied.

### Manual actions
- [ ] **On-device QA (needs the Xcode Mac + a device).** The flag is already
      `true`, so verify on a device: create a "80 push-ups,
      +20" count habit and a "≤1 coffee" limit habit; the create sheet's Target
      chips work; the amount and Step fields accept TYPED numbers and the "Each +
      adds N" hint tracks what you type; -/+ moves by the step you set; the
      day-details card shows a ring + "40 / 80"
      and tapping opens the entry sheet; the −/+ stepper updates the ring live;
      a count habit turns green at 80; a limit habit shows amber while under and
      resolves to done at day-end (leave it overnight or use the sweep); VoiceOver
      announces the stepper value and the +/- actions.
- [ ] **Native Arabic review** of the new `targets.*` strings in
      `mobile/lib/i18n/ar.i18n.json` AND `desktop/lib/i18n/ar.i18n.json`
      (sectionTitle, none, atLeast/atMostLabel, presets.*.label/description,
      units.*, entry.*) — machine MSA, same caveat as the earlier
      verification/compound copy.
      **Extended 2026-07-27** by the amount/step fields: `stepLabel`, `stepHint`,
      `rangeError`, `stepPositiveError`, `stepExceedsWarning`,
      `notDivisibleWarning(+NoBelow)`, `tooManyTapsWarning`, `confirmTitle`,
      `confirmAdjust`, `confirmSaveAnyway`, plus desktop `habitsPage.titleRequired`.
      13 keys × 5 locales × 2 apps, all machine-translated.
- [ ] **DEFERRED, your call whether to fund now**: (a) a live start/stop TIMER for
      duration targets (v1 uses a +/- minute stepper); (b) showing the progress
      ring/fraction on the 5 read-only surfaces (month calendar, weekly radar,
      yearly grid, stats heatmap, AI-coach prompt) — today they show an in-progress
      target day as a plain pending day (correct, just not detailed).

## Quantitative targets — notifications (2026-07-24)

## Cumulative numeric macro goals (feature #6) — foundation (2026-07-24)

### Deferred feature work (the macro-goal feature is NOT user-visible until these land)
- [ ] **UI (the bulk of remaining work)**: create/edit a numeric macro-goal target
      (amount + unit) + an optional "link a habit" picker + a progress bar, on both
      apps, gated by the flags. Mobile: `macro_goals_screen.dart` + `ui/widgets/macro_goals/`.
      Desktop: `create_goal_dialog.dart` + goals presentation. Will add the 5-locale
      i18n keys (+ Arabic native review).
- [ ] **Cloud-mode delete-snapshot**: in account mode, deleting a linked habit
      un-links the macro goal (ON DELETE SET NULL) but does NOT snapshot the
      accumulated derived value into progress_amount — implement a client
      fetch-sum-before-delete in `goal_provider.dart` (mobile) / `dashboard_controller.dart`
      (desktop) / cloud repo. (Private mode already snapshots.)
- [ ] **When the UI ships**: force-write the numeric columns on the Supabase UPDATE
      path (like the habit `target` column) so editing can actively CLEAR a target
      or break a link (today's conditional emit can't clear an omitted column).
- [ ] `get_macro_goals_stats` RPC + Dart twins unchanged (correct as-is — numeric
      completion flows through `status`); reflecting numeric progress in stats is a
      future enhancement, not a fix.

## Pre-existing test flakes surfaced during verification (NOT feature bugs)
Both are now closed, and NEITHER was a flaky test. Worth remembering before filing the
next one: "passes in isolation, fails in the suite" is also what an unguarded async tail
looks like — and, as it turns out, what a shared BUILD DIRECTORY looks like.
- [x] `desktop/test/evolve_controls_test.dart` — **the diagnosis was wrong; the test is
      fine.** It passes 6/6 in isolation and passes under 24-way CPU saturation in 3
      seconds, and it could not have been "borderline pumpAndSettle timing" in the first
      place: `flutter_test` drives a FAKE clock, so `pumpAndSettle` cannot run out of time
      because the machine is busy. The real cause is that `flutter test` rebuilds native
      code assets into the package's SHARED `build/native_assets/<os>/` on every
      invocation, so two concurrent runs against the same package delete each other's
      `objective_c.dylib` mid-build. Reproduced deliberately: one run dies with
      `install_name_tool: can't open file … objective_c.dylib`, the other with a flutter
      TOOL CRASH (`FileSystemException: Deletion failed`). The damage lands on whichever
      test file happened to be compiling, which is why the culprit looked random and why
      it was mistaken for a timing problem in whichever file it hit.
      **Fix: `tool/flutter-test.sh`** — serialises test runs per package (different
      packages still run in parallel). Use it instead of a bare `flutter test`:
      ```bash
      tool/flutter-test.sh desktop
      ```
      It also supplies the dummy `--dart-define`s the desktop/mobile suites need, so
      `desktop_supabase_config_security_test` stops failing "by design".
      This bites any time two runs overlap — two terminals, an IDE runner, a watch task,
      or several agents testing in one working tree. `FLUTTER_BUILD_DIR` does NOT help; it
      does not relocate `build/native_assets`.
---

## PRIVATE-MODE LOCKOUT (2026-07-27) — ROOT-CAUSED AND FIXED

**Cause found, and it was not a lost Keychain key.** A DEBUG build and a RELEASE build of
`com.simo.evolve` share one macOS sandbox container — so one encrypted database — but read the
SQLCipher key from two different stores (a plaintext dev file under `kDebugMode` vs the
Keychain). You had both running at 14:31; the debug build took the recovery path, renamed the
database aside and re-keyed it, which is why the other process then failed every write for 33
minutes and why the release build could never open it again. Proof: the database you sent
decrypts with the key in `dev_device_local_secrets.json`, and its owner id is byte-identical to
that file's. Full detail in `DOCUMENTATION.md`.

**Your data was never at risk on that Mac**: `sync_state` showed 0 dirty rows and a completed
full sync at 14:58, so everything was already in CloudKit.

### What changed (both apps)
No code path deletes the private database any more — a reset RENAMES it to
`<db>.locked-<timestamp>` and keeps one copy. Every open failure is classified, and only genuine
corruption may offer a destructive action. A database from a newer build is its own state with
no reset button. The reset now asks for confirmation and tells you the size. Debug builds use
`evolve_private_v2.dev.db` and `app_logs.dev.json`, so this collision cannot recur.

### Manual actions (Xcode Mac)
- [ ] **Delete the stale dev database on the MacBook Pro before testing again.** It is keyed by
      the old shared filename and nothing will migrate it — this is intentional:
      `rm -f ~/Library/Containers/com.simo.evolve/Data/Library/Application\ Support/com.simo.evolve/evolve_private_v2.db*`
      Only do this after confirming the iPhone still holds your data (it does, per the sync
      state above). Your real data comes back from iCloud on the next enable.
- [ ] **Never run a debug build and a TestFlight/Release build against each other again** — the
      per-flavour filename now prevents the damage, but a debug run still uses the Development
      CloudKit environment, which is why the Mac looked near-empty after the re-pull.
- [ ] **On-device QA before shipping 1.2.0** (the host tests cannot exercise real SQLCipher):
      1. Install over EXISTING data; confirm `[PrivateDB] open: stored user_version=…` appears.
      2. Force the wrong-key state (rename `.keyfp` aside, or run the old dev DB) and confirm
         you get "Your data is safe — but this copy of the app can't unlock it" with NO reset
         button, and that "Copy diagnostics" yields `EVOLVE-DB-KEY`.
      3. Install the PREVIOUS TestFlight build over 1.2.0 data and confirm you get "This
         database is from a newer version" with NO reset button (this is the one that is
         guaranteed to happen to a real tester).
      4. Confirm the reset dialog states a size and that after resetting a
         `evolve_private_v2.db.locked-*` file still exists in the container.
- [ ] **Arabic native review** of the 9 new `privateRecovery.*` keys in both apps
      (`undecryptableTitle/Message`, `schemaTooNewTitle/Message`, `copyDiagnostics`,
      `diagnosticsCopied`, `resetConfirmTitle/Body/BodySized`) — machine-translated MSA, same
      caveat as the earlier batches.

### Known gaps, deliberately deferred (fast-follow, not release-blocking)
- [ ] **No Settings screen surfaces the retained `.locked-*` copy.** The file is kept and can be
      removed programmatically (`deleteLockedAsideCopy()`), and the reset dialog tells the user
      it is kept — but there is no UI to view or delete it later. Worth adding to Settings ›
      Privacy on both apps.
- [ ] **Mobile has no "Copy diagnostics" button** (the strings are translated but unused) and no
      diagnostic code on its recovery screen. Desktop has both.
- [ ] **`runResilient()` on desktop has no callers** — the moved-file recovery currently fires
      only from the periodic sync (`desktop_sync_lifecycle`), not from user-initiated writes.
      The right choke point is `DashboardController._syncRemote`.
- [ ] **Neither recovery gate has a widget test.** The policy is tested (`allowsReset`, on both
      apps) but not the rendering, so "which buttons appear in which state" is unpinned.
- [ ] `error.png` (your screenshot) is untracked at the repo root — delete or move it when you
      next tidy up; I left it alone since it is yours.

---

## 2026-07-28 — App Store metadata: "Wealth Compass" copy purged from 22 locales

**BLOCKING: review this metadata before the next `fastlane deliver`.** The changes are
uncommitted on purpose.

### What was wrong
22 of the 39 locale folders under `mobile/metadata/` shipped the marketing copy of a
**completely different app** — "Wealth Compass", a personal-finance / net-worth dashboard.
Both `description.txt` and `keywords.txt` were affected, in exactly the same 22 locales:

`ar-SA, ca, cs, en-US, es-ES, fi, hi, hr, hu, ja, ms, nl-NL, no, pl, pt-BR, ro, ru, th, tr, uk, zh-Hans, zh-Hant`

`name.txt` ("Evolve: Habits & Goals Tracker"), `subtitle.txt`, `promotional_text.txt` and
`release_notes.txt` were **not** contaminated in any locale, and
`desktop/macos/fastlane/metadata/**` was **entirely clean** (all 38 locales) — nothing was
touched there.

### What I changed
Rewrote `description.txt` + `keywords.txt` for those 22 locales (44 files), each written in
the locale's own language, grounded in the actual app: Week/Month/Year/Life dashboard views,
per-habit frequency/colour/reminder, actionable notifications, streaks, Apple Health and
Screen Time auto-verification with any/all compound conditions, weekly→lifetime macro goals
with numeric targets, correlation and mood/energy statistics, AI Coach, Private mode vs
account mode, optional end-to-end-encrypted iCloud sync, offline use, biometric lock,
export/import/delete. All within App Store limits (description ≤4000, keywords ≤100 incl.
commas) — verified programmatically; largest is `ro` at 3929 chars.

### Things you must verify before shipping
- [ ] **Pricing.** Every rewritten description now states Evolve Pro as an auto-renewing
      subscription at **EUR 4.99 / month or EUR 49.99 / year**, plus "the equivalent price in
      your local currency is shown in the app before you confirm". Confirm this matches
      App Store Connect + RevenueCat before submitting. This was previously absent everywhere,
      and Apple requires the price and renewal terms in the description for auto-renewables.
- [ ] **Native-speaker review.** All 22 are my translations, not a translator's. Arabic, Hindi,
      Thai, Malay, Croatian and Ukrainian are the ones I'd get read most urgently.
- [ ] **Free-tier caps.** The code today enforces 5 habits and 100 goals on the free plan
      (`habit_management_modal.dart:383`, `macro_goals/add_goal_bar.dart:56`). I deliberately
      wrote "the free plan limits how many habits and goals you can keep at once" without
      numbers so the copy doesn't go stale — say the word if you'd rather state 5 and 100.

### Pre-existing issues I found but did NOT change (out of the bug's scope)
- [ ] **The 17 "clean" locales still carry the OLD Evolve description**
      (`da, de-DE, el, en-AU, en-CA, en-GB, es-MX, fr-CA, fr-FR, he, id, it, ko, pt-PT, sk, sv, vi`).
      That copy predates several shipped features: it never mentions Private mode, the AI Coach,
      Apple Health / Screen Time auto-verification, iCloud sync, or the subscription price, and
      it describes cloud sync as if Supabase + Apple Sign-In were the only data model. Not wrong,
      but incomplete — and it now diverges from the 22 I rewrote. `en-US` vs `en-GB`/`en-AU`/
      `en-CA` is the most visible mismatch. Worth porting the new copy across all 39.
- [ ] **`subtitle.txt` is the English string "Build Routines & Grow Daily" in all 39 locales**,
      including ar-SA, ja, ru, th, zh-Hans. Never localised.
- [ ] **`promotional_text.txt` is empty in 38 of 39 locales** — only `it` has content.
- [ ] **`release_notes.txt` is still English** in 14 locales (`ca, cs, en-*, fi, hi, hr, hu, ms,
      nl-NL, no, pl, ro, th, tr, uk`), and `zh-Hant/release_notes.txt` contains **Simplified**
      Chinese ("安全增强和错误修复。") rather than Traditional.
- [ ] **`desktop/macos/fastlane/metadata/` has no `it` locale** while `mobile/metadata/` does,
      and every desktop `description.txt` is a single 90–310 char sentence. If desktop and
      mobile share the one App Store record (id6770482363), decide which tree is authoritative
      before `deliver` runs against either.

## Desktop AI Coach paywall gate (2026-07-28) — on-device QA on the Mac mini

Code + tests are done and green here (analyze clean, desktop 663/663), but nothing below
can be verified without Xcode. Run these in a **release-ish build signed into a FREE account**
(account mode, no Evolve Pro), then repeat the starred ones as a Pro user.

- [ ] **The reported bug.** Overview → tap the "AI Chat" tile → the Pro-features modal opens
      and you stay on Overview. Previously it walked straight into the Coach page.
- [ ] **⌘K palette.** Open the palette, type "coach" (or "ai" / "chat"), hit Enter → palette
      closes, Pro modal opens, no navigation. This was a second leak, not the one you reported.
- [ ] **Sidebar + ⌘5** still behave exactly as before (modal, no navigation) — they were the
      two that already worked, and they now go through the same shared helper.
- [ ] **⌘] cannot resurrect the Coach.** In Private mode open the Coach → ⌘[ → Settings →
      switch to your account (free) → press ⌘] and two-finger swipe-left. Neither should land
      on the Coach. This is the vector no call-site check could close.
- [ ] **The eviction guard has NO automated test** — please exercise it. Sit on the Coach page
      as a Pro user and let / make the entitlement drop (RevenueCat sandbox expiry, or sign out
      and back in as free): you should be moved to Overview silently, with no dialog, and ⌘[
      must not take you back to the Coach.
- [ ] ***The tour finale, on a fresh install of a free account.*** Highest-risk change. Delete
      the app's prefs so the tour runs, walk it to the end, press "Fine" on the Coach segment:
      the app should land on Overview FIRST and show the completion dialog there. Watch for any
      flicker of the Coach page sliding out behind the dialog — that is precisely what the
      reorder is meant to prevent, and it is the ordinary path for every new free signup.
- [ ] ***As a Pro user***, confirm the Coach is still reachable from all four entry points and
      that the tour finale looks right for you too.

### Noted, deliberately NOT changed (pre-existing, outside the bug)
- [ ] On **Windows/Linux** a signed-in free user gets the Pro upsell for the Coach with no way
      to purchase (the paywall is informative off macOS). The sidebar already behaved this way;
      the fix just makes the other three doors consistent with it. Decide separately whether
      those platforms should pitch Pro at all.

## macOS Settings redesign — phase 1 (2026-07-28)

- **On-device QA required.** There is no Xcode on this machine, so the redesigned Settings page has never been built or run — only widget-tested. Please walk all eight panes in both data modes (Account and Private) and check: the rail stays fixed while a long pane scrolls, the pane scroll resets when you switch destinations, the rail/pane divider actually paints, and the single 720px-capped column looks right on your display.
- **Confirm nothing you use disappeared.** Five rows were deleted as verified no-ops (AI Suggestions, Milestones, Deep Work Insights, AI Insights, Weekly Reports). Their preference keys and synced columns are untouched, so your iPhone is unaffected — but if any of them ever *did* something you relied on, say so and I will restore the row.
- **Account-mode avatar still has no upload path.** No Supabase Storage call exists anywhere in `desktop/lib`, and the shell reads a `user_metadata.avatar_url` the app never writes. The broken "Update avatar" row is gone; the underlying feature needs implementing (or the avatar menu should be scoped honestly to Private mode).
- **`package_info_plus` needed for the About footer.** The proposal's version/build footer at the bottom of the rail is not implemented — adding the dependency touches the macOS Podfile and I cannot build to verify it. Add it when you are at a machine that can compile.

## AI Coach dialog dissolution (2026-07-28)

- **Check the four retargeted entry points on device.** The chat header's engine chip, the coach page's first-run nudge, its offline banner and the Settings row all now navigate to Settings › AI Coach instead of opening a modal. The tests drive the provider, not those widgets, so the wiring from each real button is unverified.
- **Confirm the engine panel looks right inside a settings card.** It was designed for a 560px dialog and now renders in a 720px-capped pane column; the local-server rows and model picker in particular are worth a look in Private mode.

## Personal info inlining (2026-07-28)

- **Verify the Private-mode profile write end to end.** Editing your name or date of birth in Private mode now calls `privateProfileProvider.updateProfile` → `DesktopPrivateDb.updateProfileFields` → `notifyWrite`. That path was fully implemented but unreachable from desktop Settings until now, so it has never actually run here. Change your name on the Mac in Private mode and confirm it reaches the iPhone.
