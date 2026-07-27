# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] settings in desktop implementation is really weird and not intuitive as it is in the mobile app
- [ ] what happens if I modify manually an automatic habits?
- [ ] Different habits & goals types, not only checkboxes like status,progress bar
- [ ] 

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
## Auto-verified habits — D10 forward-only rule-edit freezing (2026-07-23)

Editing a verification rule (e.g. a step-goal threshold) previously re-derived the
whole 7-day backfill window under the new value — silently rewriting recent
history. This change adds `goals.verify_effective_from` (the day the current rule
took effect) so reconcile never rewrites days before an edit. Nullable/additive;
existing habits are unaffected until their rule is next edited.

### Manual action required (Supabase)
- [ ] **Apply the migration `migrations/20260723_add_goal_verify_effective_from.sql`
      to the production Supabase database.** It is a single additive, nullable
      `ALTER TABLE public.goals ADD COLUMN IF NOT EXISTS verify_effective_from date`
      (+ a column comment). No RLS change, no data backfill, backwards-compatible —
      account-mode clients that predate it keep working (the column reads NULL →
      the client falls back to `start_date`). The SQLCipher/CloudKit side ships it
      automatically as `PrivateDbSchema` **v7**.

---

## Compound verifiable habits — OR/AND (2026-07-23)

Combine 2–3 HealthKit conditions into one auto-verified habit ("10k steps OR
30 min exercise"). HealthKit-only for v1; the storage model is provider-general
so cross-provider is later-additive. Verification stays iOS-only; desktop/web
carry the data. **The feature ships DARK** behind
`VerificationConfig.compoundVerificationEnabled = false`.

### Manual actions
- [ ] **Apply the Supabase migration `migrations/20260723_add_goal_verify_conditions.sql`**
      to production — a single additive, nullable `ALTER TABLE public.goals ADD
      COLUMN IF NOT EXISTS verify_conditions text` (+ comment). No RLS change,
      backwards-compatible. `TEXT` (not jsonb) on purpose: the client stores the
      same opaque JSON string on both backends; a jsonb column would double-encode
      it via PostgREST. The SQLCipher/CloudKit side ships it as `PrivateDbSchema` **v8**.
- [ ] **Native Arabic review** of the new `verification.compound.*` strings in
      `mobile/lib/i18n/ar.i18n.json` (anyOfThese / allOfThese / anyHelper /
      allHelper / addCondition / addSheetTitle / add) — machine MSA, same caveat
      as the earlier verification copy.
- [ ] **On-device QA, then flip the flag.** Set `compoundVerificationEnabled = true`
      (needs `healthKitEnabled`, already on) and verify on a device: create a
      "steps OR exercise" habit, confirm the Any/All toggle + "+ Add condition"
      (Pro-gated) work, that a compound day resolves to a single done/missed, and
      that editing a condition re-freezes history from today (D10). Desktop shows
      the compound read-only (no editing of the rule there).

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

Two fixes in the reminder path (subagent-implemented, orchestrator-verified).

### Manual actions
- [ ] **Native Arabic review** of the new limit-reminder strings: mobile
      `notifications.limitReminderMessage{1,2,3}` in `mobile/lib/i18n/ar.i18n.json`
      and desktop `notif.limitReminderBody` in `desktop/lib/i18n/ar.i18n.json` —
      machine MSA.
- [ ] **On-device QA (with the targets flag on)**: a habit with a LIMIT target
      shows restraint-framed reminder copy ("Staying within your limit today?"),
      NOT the motivational "do it!" copy.
- [ ] **NOTE — a LIVE bug was fixed and ships NOW (not behind a flag)**: a
      notification "Done"/"Skip" on an auto-verified (HealthKit) habit used to be
      silently reverted by the next foreground reconcile; it now records the D9
      manual-freeze so it sticks. Worth a quick confirm on-device that tapping
      "Done" from a notification on a verified habit persists after backgrounding
      and reopening the app.

## Cumulative numeric macro goals (feature #6) — foundation (2026-07-24)

Storage/domain/import foundation done + tested (subagent, orchestrator-verified).
Dark behind `MacroTargetsConfig.enabled` / `DesktopMacroTargetsConfig.enabled`.
long_term_goals gained: target_amount, target_unit, progress_amount, linked_goal_id
(FK → goals(id) ON DELETE SET NULL). Private schema v10.

### Manual actions
- [ ] **Apply the new Supabase migration** `migrations/20260724_add_macro_goal_targets.sql`
      (additive `ADD COLUMN IF NOT EXISTS` on long_term_goals + the FK). Apply it
      alongside the other queued migrations (schema v9 targets + verify_*).
- [ ] **RELEASE NOTE**: private schema is now at **v10** (was v9 after the habit-
      targets work, v6 on main). A device upgrading from main runs v7→v8→v9→v10 in
      one open; onDowngrade still throws, so v10 must reach iOS and macOS together.
- [ ] **Pre-existing test flakiness surfaced**: `desktop/test/evolve_controls_test.dart`
      intermittently fails 2–3 tap/render tests on full-suite runs (passes on retry
      and in isolation) — borderline pumpAndSettle timing under parallel load, NOT
      caused by the feature work. Worth a separate hardening pass (add explicit
      pumps / bump settle timeouts in that file).

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

## Cumulative numeric macro goals (feature #6) — UI COMPLETE (2026-07-24)

Feature #6 is now complete end-to-end on both apps (create/edit numeric target +
link-a-habit picker + progress bar + cloud delete-snapshot), dark behind
`MacroTargetsConfig.enabled` / `DesktopMacroTargetsConfig.enabled`. Independently
verified: mobile 567, desktop 588 green.

### Manual actions
- [ ] **DEPLOY ORDER (important):** apply `migrations/20260724_add_macro_goal_targets.sql`
      to production BEFORE flipping `MacroTargetsConfig` / `DesktopMacroTargetsConfig`
      on. The macro-goal Supabase UPDATE force-write is gated behind the flag on
      purpose, so while dark it never sends the numeric columns — but the moment
      the flag is on, an edit writes `target_amount`/`target_unit`/`progress_amount`/
      `linked_goal_id`, which fail unless the migration has added those columns.
- [ ] **Native Arabic review** of the new `macroTargets.*` strings (sectionTitle,
      none, amountLabel, linkLabel, manual, unitCount, reached) in
      `mobile/lib/i18n/ar.i18n.json` and `desktop/lib/i18n/ar.i18n.json` — machine MSA.
- [ ] **On-device QA (flags on)**: create a macro goal with a numeric target
      ("run 500 km this year"); link a running habit; log habit progress and watch
      the macro-goal progress bar accumulate; delete the linked habit and confirm
      the accumulated value is snapshotted (not zeroed).

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

## Pre-merge review — GO_WITH_FIXES → fixed; go-live checklist (2026-07-24)

An adversarial pre-merge review found 2 blocking deploy-order defects (both in
desktop dashboard_repository.dart, both now FIXED + re-verified green): the
goal_progress SELECT is now isolated (degrades to [] pre-migration), and the
updateHabit target force-write is now flag-gated (mobile made consistent). The
remaining confirmed findings are LOW / dark-gated — fix opportunistically, none
block the merge, but review before flipping the flags live:

- [ ] `reconcileManualTargets` runs on app resume UNGATED (`mobile/lib/main.dart`
      ~478). Harmless in a pure-dark fleet, but during a STAGED rollout a target
      authored on a flag-on device round-trips to a still-dark device whose resume
      sweep then writes 'done' verdicts / can overwrite a manual past-day toggle.
      Semantically correct + re-syncs; no data loss. Consider gating it behind
      TargetsConfig.enabled once you decide the rollout strategy.
- [ ] Habit delete does `snapshotLinkedMacroGoals` then `delete('goals')` as TWO
      awaits, not one `db.transaction` (`mobile/lib/core/private_local_database.dart`
      ~492, `desktop/.../private_dashboard_repository.dart` ~167). A process kill in
      the tiny window leaves a macro goal snapshotted+unlinked while its habit
      survives. Recoverable; trivial fix = wrap each pair in a transaction.
- [ ] PRIVATE/CloudKit: a two-device create-then-delete race can leave a macro
      goal's `linked_goal_id` dangling at a deleted habit (sync apply runs with
      `PRAGMA foreign_keys=OFF`, so ON DELETE SET NULL never fires on the PULLING
      device; only the originating device's snapshot un-links). Account mode
      self-heals via the real Postgres FK. Only matters once the flag is live.
- [ ] Desktop account-mode delete-snapshot derives the frozen total from the
      IN-MEMORY dashboard snapshot (`dashboard_repository.dart` deleteHabit) rather
      than a live Supabase SUM like mobile — a stale desktop snapshot could freeze
      a partial value. Single-device flows are fine.
- [ ] (cosmetic) `reminderBody` rotation math changed to `seed.abs() % len`, so a
      habit whose title.hashCode is negative gets a different (still valid)
      motivational reminder line than before. No functional impact.
