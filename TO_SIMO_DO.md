# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] settings in desktop implementation is really weird and not intuitive as it is in the mobile app
- [ ] what happens if I modify manually an automatic habits?
- [ ] Different habits & goals types, not only checkboxes like status,progress bar
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

## Quantitative habit targets — foundation (2026-07-24)

Habits gain an optional numeric target: count ("80 push-ups in sets of 20"),
duration ("20 minutes"), limit ("at most 1 coffee"). Shipped so far: the shared
`packages/evolve_targets` model + `PrivateDbSchema` **v9** (`goals.target` and the
new synced `goal_progress` table). No UI yet — nothing is user-visible.

### Manual actions
- [ ] **RELEASE ORDER — read before shipping anything.** `main` is at
      `PrivateDbSchema` **v6**. v7 (`verify_effective_from`) and v8
      (`verify_conditions`) are still unmerged on this branch and have never run
      against a real SQLCipher file; v9 now stacks on top, so a device upgrading
      from `main` executes three never-tested migration legs in one open.
      `onDowngrade` **throws** by design, so a build that reaches the iPhone
      before the Mac makes the Mac **refuse to open its private database** — a
      hard break, not a soft degrade. Recommended: ship v7+v8 first as their own
      release (compound flag still dark), confirm a real device opens cleanly,
      then release v9 **to iOS and macOS simultaneously**.
- [ ] **Apply the queued Supabase migrations, in order**:
      1. `migrations/20260723_add_goal_verify_effective_from.sql` (still open)
      2. `migrations/20260723_add_goal_verify_conditions.sql` (still open)
      3. `migrations/20260724_add_goal_targets_and_progress.sql` (new) —
         `goals.target text` + the `goal_progress` table, 4 RLS policies and an
         `updated_at` trigger. All additive and `IF NOT EXISTS`; no RPC changes.
- [ ] **Decide: is WEEKLY QUOTA ("gym 4×/week") in scope for this release?**
      Currently deferred. Nothing in the stack buckets by week — `computeStreak`
      walks days, `frequency_days` is the only schedule input, and no migration
      groups `goal_logs` by week — so a quota needs a second walk unit, a new
      week-grained SQL surface with two Dart mirrors, and it contradicts
      desktop's documented "off-day habits are HIDDEN" invariant. The model
      already round-trips `TargetPeriod.week`, so adding it later is one preset
      entry, not a rewrite.
- [ ] **Known pre-existing drift, NOT fixed here** (deliberately, to keep this
      change reviewable): `schema.sql` still omits `goal_logs.streak` although
      the app upserts it and `habit_stats` reads it, and still declares
      `long_term_goals.is_completed` while `get_macro_goals_stats` filters on
      `status`. Worth a separate cleanup commit.
- [ ] **CI gap that affects this work**: `.github/workflows/mobile-ci.yml` is the
      only workflow and is paths-scoped to `mobile/**`, so a commit touching only
      `migrations/`, `packages/evolve_sync` or `packages/evolve_targets` runs
      **zero** CI — including `mobile/test/schema_drift_test.dart`, the repo's
      only schema guard. Widening the paths filter and adding a `packages` job is
      nearly free and would cover the v9 migration tests.

## Quantitative targets — end-of-day sweep (2026-07-24)

The manual-target resolution sweep now runs on foreground on BOTH platforms
(mobile resume hook, desktop refresh tail). Two product calls to confirm when the
UI ships and this becomes user-visible:

- [ ] **Desktop runs the sweep too — confirm you want this.** A Mac-primary user's
      limit habits ("≤1 coffee") only resolve to "done" if *something* runs the
      end-of-day sweep; without the desktop half they'd look perpetually unlogged
      on a Mac-only setup. It's `DashboardController.reconcileManualTargets` +
      one line in `refresh()` — trivially removable if you'd rather keep
      resolution iOS-only. Recommendation: keep it (matches your full-coherence
      preference; manual targets are local data, not iOS-only device measurements).
- [ ] **Backfill window = 45 days** (`kManualTargetBackfillDays` in
      `packages/evolve_targets/lib/src/target_reconcile.dart`). A user who opens
      the app after a longer gap leaves older quiet limit-days unmaterialised
      (they stay absent rather than retroactively filled "done"). This is the cap
      on the "reopen after weeks away → free streak" effect. Tune the constant if
      45 days feels wrong once you see it on-device.

## Quantitative targets — mobile UI (dark) (2026-07-24)

The mobile UI shipped DARK behind `TargetsConfig.enabled` (mobile/lib/core/
targets_config.dart, currently false). Flip it to true only AFTER the on-device
QA below, and only in a build where schema v9 + the Supabase migrations are live.

### Manual actions
- [ ] **On-device QA (needs the Xcode Mac + a device), then flip the flag.** Set
      `TargetsConfig.enabled = true` and verify on a device: create a "80 push-ups,
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

## Quantitative targets — desktop (macOS) UI (dark) (2026-07-24)

Desktop UI shipped DARK behind `DesktopTargetsConfig.enabled` (desktop/lib/core/
targets_config.dart, currently false). Flip it together with the mobile flag,
only after on-device QA and once schema v9 + the Supabase migrations are live.

### Manual actions / decisions
- [ ] **CONFIRM: desktop allows INCREMENTS, not just display.** My recon
      recommended macOS be read-only for progress (increment on iPhone only) to
      avoid two devices racing a counter under last-write-wins. I built FULL
      PARITY instead (you can +/- a target on the Mac too), because it matches
      your coherence preference and the increment path already existed. The
      tradeoff: if you increment the SAME habit-day on phone AND Mac within a
      ~60s sync window, LWW keeps one device's number (converges, no crash, just
      not the sum). To make desktop read-only instead: gate the `onOpenTarget`
      callbacks in `habits_page.dart` and `dashboard_page.dart` `_HabitRow` to
      null (one line each) — the ring still shows, the click just won't open the
      entry dialog. Tell me if you'd prefer that.
- [ ] **On-device QA (macOS)**: with the flag on, create a count + a limit habit
      via the editor's Target picker; the Protocol and dashboard rows show a ring;
      clicking opens the entry dialog; the +/- buttons AND the ↑/↓ (or +/-) keys
      update the ring live without triggering the ←/→ period paging; a count
      habit turns green at target; a limit habit resolves to done at day-end.
- [ ] **Native Arabic review** of the desktop `targets.*` strings in
      `desktop/lib/i18n/ar.i18n.json` (same set as mobile) — machine MSA.

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