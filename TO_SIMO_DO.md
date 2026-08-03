# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] 
- [ ] Macro goals still need a numeric target + progress bar (status already cycles active/completed/failed). Habits are DONE — the Checkbox / Number / Automatic picker and quantitative targets are live; MacroTargetsConfig.enabled is still false on both apps.

---

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
## macOS build: `objective_c1.framework` warning fix (2026-07-30)

`desktop/pubspec.yaml` now pins `path_provider_foundation: 2.5.1` (same override mobile
has carried since 2026-05-19). That swaps path_provider back from the FFI implementation
to the normal Darwin **plugin**, so the macOS Pods project gains a pod it does not have
yet. `flutter pub get` already regenerated
`desktop/macos/Flutter/GeneratedPluginRegistrant.swift` with `import path_provider_foundation`,
but `desktop/macos/Podfile.lock` could not be regenerated here (this Mac has no CocoaPods
and no Xcode).
## macOS App Store resubmission — blocking manual steps (2026-07-30)

The repo side of the 3.1.2(c) / 2.1(b) remediation is done (39 locales carry the
EULA link, macOS review notes exist, the Fastfile no longer targets the wrong
platform). These remain, and all of them are App Store Connect actions only you
can take. Order matters.

1. **VERIFY THE DEMO ACCOUNT FIRST — everything else is wasted if this fails.**
   Launch Evolve on the Mac, sign in with `wowtesting@gmail.com` /
   `TestForMePls1.` in **Account mode** (do NOT click "Continue privately on
   this Mac"). macOS sign-in goes through **Supabase** email/password. If that
   account is an Apple *StoreKit sandbox* tester rather than a real Supabase
   user, it does not exist in the auth database, the reviewer cannot get in, and
   the app gets rejected for the third time on the same root cause. If it fails,
   create a real Supabase account and update
   `desktop/macos/fastlane/metadata/review_information/demo_user.txt`,
   `demo_password.txt` and `notes.txt`.

2. **While signed in, confirm the paywall renders prices.** Settings (⌘,) →
   Subscription. Both cards must show a real currency figure, NOT "Price
   unavailable". Prices only resolve when signed in
   (`desktop_subscription_controller.dart:514`), so this is also the screen your
   3.1.2 screen recording has to show.

3. ~~**Rename the macOS version in App Store Connect: 1.0.0 → 1.2.1.**~~
   **RESOLVED 2026-07-30 (`0e8ac85`), the other way round:** `desktop/pubspec.yaml`
   is now `1.0.0+27`, matching the ASC version page. Nothing to rename.

4. **Push the metadata**, from `desktop/macos`:
   `fastlane mac metadata`
   This is the new metadata-only lane. Then check in App Store Connect that the
   **Italian** description shows the EULA link — Italian is the locale ASC
   actually serves for this app, and it is the one the reviewer read.

5. ~~**Upload build 1.2.1 (26)**~~ — superseded: build 26 was the one rejected.
   Ship **1.0.0 (27)**; see the 2026-08-02 section at the end of this file.

6. **Set the App Review Information fields** if fastlane did not: tick
   "Sign-in required" and confirm the username/password fields are populated.
   The red badge on **App Review** in the sidebar must clear.

7. **Reply in the Resolution Center** with the screen recording Apple asked for
   (3.1.2(c)): launch → Account mode sign-in → ⌘, → Subscription, showing plan
   titles, 1 month / 1 year, live prices, and both legal links opening.

8. **Do NOT add the subscriptions to the version page** — there is no "In-App
   Purchases and Subscriptions" section on it, because both products are already
   **Approved** and shared with the live iOS app through Universal Purchase
   (`com.simo.evolve`). 2.1(b) fired because the reviewer could not reach the
   purchase screen, not because anything is unsubmitted.

### Separately: a pre-existing iOS metadata bug found during this work

`mobile/ios/fastlane/metadata/{ca,el,fr-CA,fr-FR}/description.txt` are **over
Apple's 4000-character limit** (4011 / 4092 / 4180 / 4180). Those four locales
cannot upload as they stand — a `deliver` run for iOS will fail or truncate on
them. The macOS copies are already trimmed; the iOS originals are untouched
because that is a separate submission. Worth fixing before the next iOS push.

## macOS description accuracy audit — FIXED 2026-07-30 (residuals below)

An adversarial audit of every description claim against `desktop/lib` found two
claims with **no implementing code on macOS at all**, both inherited from the
iOS description. Both are now **removed from all 39 locales**:

- *"Apple-Style Customization: Configure your milestones visually"* — milestones
  are a hardcoded `const List<int> kStreakMilestones`
  (`desktop/lib/features/statistics/data/analytics_extra.dart:816`); there is no
  editor to open.
- *"Sub-Goal Breakdown"* — zero occurrences of subGoal / subtask / parentGoal /
  checkpoint anywhere in `desktop/lib`. No model, no field, no UI.

Seven further overstatements were corrected in the **nine locales the desktop UI
actually speaks** (it, en-US/GB/AU/CA, es-ES/MX, de-DE, ar-SA): Life View no
longer asserts a unit (the grid is months — `habits_page.dart:1982` —
while the copy said weeks); "in real time" is dropped from cloud sync (there is
no Supabase Realtime; account mode is pull-on-build + push-on-write); the
command palette no longer claims habit jumps (`command_palette.dart:514`
discards the habit identity and navigates to the section); arrow-key paging is
scoped to Habits and Goals; "settings window" became "settings organized in
panes" (it is an in-shell page, not an NSWindow); the per-habit calendar claim
is scoped to yearly; and the correlation example no longer implies Apple Health
data the Mac cannot author.

### Residual, accepted for this submission

The **30 locales the app's UI does not speak** keep the inherited iOS wording for
those seven overstatements — they were not machine-edited in languages neither
reviewer nor author can proofread, which is a worse risk than the overstatement.
Note that "Life View ... weeks" actually matches what the app itself displays:
the tab is labelled `lifeWeeks` = "Weeks of your journey"
(`desktop/lib/i18n/en.i18n.json`) even though the grid is months. Fix the app
string and the 30 locales together, after approval.

### Real in-app bugs found during the audit — worth fixing before review

1. **The Pro modal makes a false claim on the purchase surface.** `aiCoachDesc`
   ends "Prefer your own OpenRouter account? That's free too." BYOK is
   **Private-mode only** (`coach_config.dart:343-356`), and this string renders
   on the paywall itself (`subscription_pane.dart:150-155`) — the exact screen
   under appeal for Guideline 3.1.2. Highest priority of the three.
2. **Life View shows a stranger's life by default.** `_LifeCalendar` falls back
   to `DateTime(2003)` when no date of birth is set (`habits_page.dart:1980`), so
   a reviewer who never opens Settings > Account sees a populated grid that is
   not theirs. An empty state would be correct.
3. **`lifeWeeks` label vs months grid** — see above; the app contradicts itself.

---
- **Reinstall path can reach Supabase + RevenueCat pre-consent.** The Keychain
  session survives app deletion; `has_completed_consent` (NSUserDefaults) does
  not. So delete-and-reinstall = live session, consent unanswered, and the token
  refresh / `profiles` read / `Purchases.configure` fire behind the gate. Sentry
  is gated; these are not. Same shape as the bug that got you rejected.

### Found while reviewing this work — NOT fixed, not in scope

- **macOS fetches `goal_logs` and `goal_progress` unpaginated**
  (`desktop/.../dashboard_repository.dart`, plain `.select().eq(user_id)` with no
  `.range()`). Mobile paginates both *because* PostgREST's `db-max-rows` silently
  truncates. On a large history the Mac now sees a truncated map, reads real days
  as untouched, and auto-fail writes `missed` over a real `done` — and this is
  the one configuration where the two devices genuinely oscillate, since the
  iPhone re-derives `done` from the row it can see and writes it back. This
  matters more now than it did last week.
- ~~`progressStale` is not persisted to the desktop cache~~ **FIXED 2026-08-02**
  — it now round-trips, and an absent key reads as `true` (a cache written before
  the key existed cannot prove its progress map was healthy).

### From the adversarial review round (2026-08-02)

- ~~The same DST bug family is still live in the ANALYTICS layer.~~ **DONE
  2026-08-02** — swept across both apps with before/after numbers; see the
  DOCUMENTATION.md entry. 21 call sites converted, 0 divergences remaining
  against a UTC oracle across 8 timezones.
- **Reminder scheduling was examined and deliberately NOT changed.**
  `_nextInstanceOfTime` / `_nextInstanceOnWeekday` in both apps step with
  `Duration(days: 1)`, but on `tz.TZDateTime` (the `timezone` package), not Dart
  `DateTime` — different semantics — and the schedules carry
  `matchDateTimeComponents`, so the OS re-matches the wall-clock time on every
  occurrence and only the SEED could be an hour off, on a transition day. It
  changes when notifications fire, which I cannot verify without a device, so it
  stays as-is. Worth a look when you next have a device in hand.
- **`_saveLocal()` runs once per applied change inside the desktop sweep.**
  Returning from a 45-day absence with 5 quantitative habits is ~225 full-snapshot
  JSON encodes + keychain writes and 225 round trips in one foreground. Hoisting
  it out of the loop cuts it by ~N×45 at no correctness cost, but it adds an
  early-return path (the loop can bail on `_disposed` or a mid-sweep
  `progressStale`), so I did not add it late in the session.
- **Nothing proves the two week calendars actually call `weekDaysFor`.** The
  helper is well tested; reverting a single call site inside
  `habits_page.dart` / `weekly_view_widget.dart` back to a `Duration` would be
  invisible to CI. Both widgets are private, so this needs a widget test that
  pumps the page.
- **CI cannot exercise the DST tests.** They assert zone-independent invariants,
  so they pass in UTC no matter what. Add a `TZ=Europe/Rome` leg if you want the
  guard to be automatic.
- **Account mode is untested on mobile.** No test runs `HabitLogsNotifier` or
  `HabitProgressNotifier` with a Supabase session, so the cache-seed / sync-fail
  combinations that `loadIsTrustworthy` exists to distinguish are covered only as
  a pure function, not end to end.
