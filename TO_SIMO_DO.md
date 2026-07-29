# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] 
- [ ] Macro goals still need a numeric target + progress bar (status already cycles active/completed/failed). Habits are DONE — the Checkbox / Number / Automatic picker and quantitative targets are live; MacroTargetsConfig.enabled is still false on both apps.

---

# TO DOUBLE CHECK:

- [ ]

## Arabic device QA — auto-verified habit line (2026-07-29)

Only a real Arabic-locale device can settle these two. Set the app to العربية, open a
day with an auto-verified habit, and look at the line under the habit name.

- [ ] **Does `≥` render mirrored (looking like `≤`)?** U+2264/U+2265 are
  `Bidi_Mirrored=Yes`, and in an RTL run a conforming shaper (HarfBuzz, which Flutter
  uses) may flip the glyph. It is Unicode-correct, but `≥` (goal) and `≤` (limit) mean
  OPPOSITE things here, so a reader who scans math symbols Latin-first could read the
  rule backwards. If it does mirror and you dislike it, the fix is a locale-owned
  summary pattern using the words already in the file — `على الأقل` / `على الأكثر`,
  which in Arabic follow the quantity: `التمرين: 30 دقيقة على الأقل`. That costs a new
  pattern key per locale and is much longer, so decide from what you actually see.
- [ ] **Does 11pt SF Arabic clip dots or diacritics** in that single-line row? Arabic
  reads smaller than Latin at the same point size; may need +1pt or an explicit line
  height for `ar`.

## Arabic grammar defects found while reviewing (pre-existing, NOT from this change)

These are shipped bugs an Arabic native-speaker review surfaced. Numbers do not agree
with their unit words: Arabic needs the dual for 2 and the plural for 3–10, and the
`units` tokens are all singular. Concrete, reachable cases:

- [ ] `sleepHours` default **8** renders `≥ 8 ساعة` — must be `8 ساعات`. Typical sleep
  goals (6–9) sit entirely inside the broken band, so this is the DEFAULT state of a
  shipped template.
- [ ] `mindfulMinutes` default **10** renders `≥ 10 دقيقة` — must be `10 دقائق`.
- [ ] `activeEnergy` (`سعرة`) breaks the same way for 2–10.
- [ ] `screenTime.selectionSummary` (`"{count} محدد"`) has both the agreement bug and a
  gender bug — apps/categories are non-human plurals, so `محددة`.
- [ ] Unit/label stutter, all locales, worst in Arabic: the summary appends a unit to a
  label that already names it — `≥ 30 دقيقة دقائق التمرين`, `≥ 8 ساعة ساعات النوم`.
  English has it too (`≥ 30 min Exercise minutes`); Arabic repeats the same root twice.
- [ ] Three different verbs for "tap" across `ar.i18n.json` (`انقر` ×6, `اضغط` ×1,
  `المس` ×0) and none is the Apple-iOS-Arabic `المس`. `a11y.toggleHint` currently tells
  iPhone users to double-*click*. Wants one sweep, not per-string edits.
- [ ] `CouldNotVerifyChip` hardcodes ASCII `'?'`; Arabic is `؟` (U+061F).

Cheapest fix for the agreement family, if you want it: make the Arabic unit tokens
invariant abbreviations (`د`, `س`) the way `كم` already is — abbreviations don't
inflect. The thorough fix is slang plural categories for `ar`, which means
`verificationUnitSuffix` has to take the count.

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

## Settings state hoist + pane split (2026-07-28)

- **Two timing nuances the widget suite cannot see.** The form state now lives in a keep-alive Riverpod controller rather than a per-mount `State`, which changes two things on a real machine: (1) the synced read-back applies one microtask after `initState` instead of inside it, so there is at most one frame of pre-hydration values when Settings opens; (2) the controller survives closing Settings, so re-opening re-arms the hydration latch and re-reads the appearance instead of rebuilding from SharedPreferences. Open Settings, change a preference on the iPhone, then close and re-open Settings on the Mac and confirm the Mac shows the iPhone's value.
- **Pre-existing, not introduced:** `settings_page.dart` `_deletePrivateData` opens its loading dialog after an `await` with no `mounted` check. If the page is disposed while the confirm dialog is open, it uses a defunct context. Worth fixing, but it is not a regression from this work.

## Sync + data flow hoist (2026-07-28)

- **Account-mode avatar is now inert by design.** The profile picture is tappable in Private mode only, because account mode has no upload path anywhere in `desktop/lib` (no Supabase Storage call exists). If you want it back, the upload needs building first — the affordance was live but silently discarded every pick.


## Screen Time on-device test checklist (2026-07-28)

Code audit of the Screen Time verification stack found 5 blockers to fix **before**
installing a test build (see the session report). These are the tests only a real
iPhone can settle, ordered by how much they change:

- **T1 — does re-registering reset the day's counter?** (Now also the acceptance test for the monitoring diff: with the diff in place an unchanged goal should NOT be re-registered at all, so its counter should survive a relaunch. Verify via `screen_time_monitor_specs` in the App Group — an unchanged goal must still have an entry after a sync that touched a different goal.)
  Original steps: Register a 5-min limit, burn 6 min so the threshold fires, force-quit, relaunch, background→foreground (this forces `stopMonitoring()` + re-register), burn 6 more min. *If the counter restarts at zero*, every app launch forgives the day's accumulated usage and `atMost` habits become unreachable — the whole sync strategy has to change from "stop everything and re-add" to a diff against `DeviceActivityCenter().activities`. Highest-value test.
- **T2 — does `stopMonitoring()` deliver `intervalDidEnd`?** With monitoring live mid-day, edit a threshold so the sync runs, then check the App Group buffer (`group.com.simo.evolve.verification`, key `pending_screen_time_signals`) for any `stayedUnder` row. **Assert on the row's `y`/`m`/`d` fields, not on "today"** — signals are now dated by the interval they describe, so a stop-induced row would carry neither today nor yesterday but be dropped entirely by the mid-day guard. Seeing *no* row is the pass. Seeing one means the guard's window needs widening.
  Also test the **23:55–23:59 band specifically**: edit a threshold in that window. If `stopMonitoring()` raises `intervalDidEnd`, a sync there is classified as "today's interval closing" and banks a spurious *pass* for today — the one five-minute hole the mid-day drop guard cannot cover.
- **T3 — what does the appex actually link?** After archiving: `otool -L …/PlugIns/DeviceActivityMonitorExtension.appex/DeviceActivityMonitorExtension`. Expect system frameworks only. Any `@rpath/Flutter.framework` or `@rpath/SQLCipher.framework` confirms the extension is inheriting the app's Pods xcconfig and will likely be jetsammed at its 6 MB cap.
- **T4 — midnight attribution.** PRECONDITION: after the first sync, confirm the App Group key `screen_time_monitor_thresholds` actually holds `{goalId: minutes}`. Without it the extension takes the no-correction fallback and this test proves nothing. Then cross a limit at ~23:58 with the app closed and check which day the verdict lands on — it should be the day you crossed it, not the fresh one. A late `reachedThreshold` stamped on the fresh day is made *unflippable* by the permanence guard.
- **T4b — DST fall-back.** Set the date to a DST fall-back Sunday, register a 150-minute limit and burn usage across the repeated 01:00–02:00 hour. The crossing must land on that day. This is the case where wall-clock arithmetic silently mis-dates and only elapsed-time arithmetic is correct.
- **T5 — web-only picks.** In the picker select only websites and tap Done. Currently the app reports that as "empty" and refuses to save, even though native monitoring does handle web domains.
- **T6 — concurrent appends.** With 2+ Screen Time habits, check the App Group buffer after 23:59: expect one entry per goal. Missing entries confirm the unsynchronised read-modify-write race.
- **T7 — revoke and return.** Revoke Screen Time for Evolve in iOS Settings, reopen the app, and note where the FamilyControls toggle actually lives and what `authorizationStatus` reports. The in-app "Open Settings" button currently opens Settings › Evolve, not the Screen Time pane its own copy describes.
- **T9 — power-off overnight replay.** Let the phone die before 23:59 (charge to ~5% in the evening) and boot it in the morning. Does DeviceActivity replay the missed `intervalDidEnd`? If it does, that delivery is hours late but is a *genuine* report of yesterday — and the extension currently DROPS anything more than four hours after midnight. A replayed row appearing in the buffer means `lateDeliveryWindowMinutes` is discarding real passes and must be widened.
- **T10 — spring-forward.** Set the date to a spring-forward Sunday and let 23:59 pass. The App Group buffer must gain a `stayedUnder` row. This is the mirror of T4b: the day is 23 hours long, and any logic that measures the interval end in *elapsed* rather than *wall-clock* minutes silently drops every goal's pass that day.

- **T8 — notification permission.** The extension's real-time "limit reached" push is the feature's headline output, but the habit-editor path never requests notification permission. Confirm whether you get the banner without first visiting Settings › Screen Time.

- **Settings search bar — eyeball it on device.** The rail filter now wears the same pill as the ⌘K bar (38px tall, radius 12), which is 8px taller than before. Check on a real display that (a) the double outline inside the field is gone, (b) the new `⌘ F` badge does not crowd the "Search settings" hint at the 236px rail width in the longest locale — German and Portuguese are the ones to look at, and (c) the accent focus ring reads as focus rather than as an error state on a light accent. No macOS build was possible here (no Xcode).

## HealthKit measurement leak fix (2026-07-28)

- **Audit existing Supabase accounts for already-leaked measurements.** The code fix stops FUTURE uploads, but any account that received a Private-mode restore under the old logic may already hold real Apple Health quantities in `goal_logs.value` — specifically for habits whose HealthKit rule was removed, or that were converted to a compound (multi-condition) habit before the restore. A later restore now clears them (the strip writes an explicit `null`, not an omitted key), and `applyAutoVerdict` clears them on the next verdict for goals still verified — but neither happens on its own. If you want them gone now, run a one-off cleanup against `goal_logs`: null `value` for every row whose goal is not verified by `screentime`. Worth doing before the App Store submission, given Guideline 5.1.x and the HealthKit data-use rules.
