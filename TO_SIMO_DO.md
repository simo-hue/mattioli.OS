# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] Today's protocol da MacOS i pallini degli habits devono essere riguardanti la settimana scorsa ( 6 giorni precedenti a quello corrente in modo tale da poter vedere il proprio contributo nell'ultimo pallino disponibile, il giorno corrente )
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

## Schema snapshot + CI (2026-07-27) — DONE in code, ONE manual step left

Weekly quota is now a closed decision (permanently deferred — rationale moved to
`HABIT_CLASSES_PLAN.md` §2). The schema drift and the CI gap are fixed in code.

### Manual action
- [ ] **Apply `migrations/20260727_complete_bootstrap_chain.sql` to Supabase.**
      Every statement is guarded (`IF NOT EXISTS`), so on your live project it is
      a **strict no-op** — it exists so a *fresh* project provisions correctly.
      It deliberately does NOT `CREATE OR REPLACE` the live `handle_new_user()`:
      replacing a live SECURITY DEFINER function from a reconstructed snapshot is
      how signup breaks. Run it with the other pending migrations, no special
      ordering beyond being last.
      Nothing else here needs you: `schema.sql` is a checked-in snapshot that no
      app reads at runtime, so it cannot affect iOS or macOS behaviour.

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