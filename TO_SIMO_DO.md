# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] settings in desktop implementation is really weird and not intuitive as it is in the mobile app
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

### Manual actions
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

### Manual actions (Xcode Mac)
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
