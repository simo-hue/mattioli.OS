# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] Today's protocol da MacOS i pallini degli habits devono essere riguardanti la settimana scorsa ( 6 giorni precedenti a quello corrente in modo tale da poter vedere il proprio contributo nell'ultimo pallino disponibile, il giorno corrente )
- [ ] settings in desktop implementation is really weird and not intuitive as it is in the mobile app
- [ ] what happens if I modify manually an automatic habits?
- [ ] Macro goals still need a numeric target + progress bar (status already cycles active/completed/failed). Habits are DONE — the Checkbox / Number / Automatic picker and quantitative targets are live; MacroTargetsConfig.enabled is still false on both apps.
- [ ] While trying the macOS version in testflight everything was working as expected until when I quit the app with Command + Q and then I reopened it. The error was the fact that the local mode ( privacy mode ) need to be resetted to carry on as the db could not be encrypted even though before ( 30 seconds before ) it was working perfectly and it was also synchronized with iCloud.

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

### DECISION NEEDED FROM YOU (before building)
- [ ] **Version numbers.** `mobile` is `1.1.5+40`, `desktop` is `1.1.6+24`. The plan calls
      for a *simultaneous* release; tell me whether you want them aligned (and to what)
      or left independent, and I'll bump them. I did not guess — with Universal Purchase
      on a shared bundle id this is your call, not a mechanical one.

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
      chips + amount stepper work; the day-details card shows a ring + "40 / 80"
      and tapping opens the entry sheet; the −/+ stepper updates the ring live;
      a count habit turns green at 80; a limit habit shows amber while under and
      resolves to done at day-end (leave it overnight or use the sweep); VoiceOver
      announces the stepper value and the +/- actions.
- [ ] **Native Arabic review** of the new `targets.*` strings in
      `mobile/lib/i18n/ar.i18n.json` (sectionTitle, none, atLeast/atMostLabel,
      presets.*.label/description, units.*, entry.*) — machine MSA, same caveat as
      the earlier verification/compound copy.
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
Two desktop test files intermittently fail under full-suite PARALLEL load and pass
in isolation / on retry — independently confirmed as pre-existing, unrelated to the
targets/macro-goal work:
- [ ] `desktop/test/evolve_controls_test.dart` — borderline pumpAndSettle timing on
      a few tap/render tests.
- [ ] `desktop/test/subscription_entitlement_scope_test.dart` — a `purchases_flutter`
      `MissingPluginException(setLogLevel)` platform-channel artifact under parallel
      load (last touched by commit e87db2e, unrelated).
      Worth a separate hardening pass (explicit pumps / channel mock / --concurrency).