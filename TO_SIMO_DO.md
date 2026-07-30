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
has carried since 2026-05-19), which removes the `objective_c` native code asset that
made every universal Release archive warn about `objective_c1.framework`.

**Done on the mac mini already** — `flutter clean && flutter pub get && pod install` ran
clean. `pod install` reporting *"3 dependencies from the Podfile and 5 total pods"* (i.e.
unchanged, no `path_provider_foundation` pod) is CORRECT, not a failure: this project
integrates plugins through **Swift Package Manager**, not CocoaPods. 14 of the 17 macOS
plugins ship a `Package.swift` — `path_provider_foundation` 2.5.1 among them — and only
`sign_in_with_apple` and `sqflite_sqlcipher` are CocoaPods-only. So `Podfile.lock` is
correctly untouched and there is nothing to commit there. (An earlier version of this
note wrongly said to expect a new pod; that was generalised from mobile's iOS setup,
which really is CocoaPods.)

Also ignore the three *"CocoaPods did not set the base configuration … your project
already has a custom config set"* warnings. They are stock Flutter-macOS-template
behaviour and pre-date this change: `Runner/Configs/Release.xcconfig` includes
`Flutter/Flutter-Release.xcconfig`, whose **first line** is
`#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"` — which
is exactly the second remedy CocoaPods offers. CocoaPods just cannot see a *transitive*
include, so it warns on every run. Nothing to fix.

**Still to do:**

- [ ] Archive and confirm the *"different framework names for different architectures …
      objective_c1.framework"* warning is gone from the log.
- [ ] If Xcode instead fails with *no such module 'path_provider_foundation'*, the SPM
      package did not regenerate. Check with:
      `cat desktop/macos/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift`
      — it must list `path_provider_foundation`. If it does not, re-run `flutter pub get`
      from `desktop/`, or `flutter build macos --release` once, before archiving.
- [ ] Smoke-test the app once after installing: path_provider now goes through the
      platform channel instead of FFI, so a broken integration would show up as a failure
      to resolve the Application Support directory (the private DB path) at first launch.

---

## iOS edge-swipe-back on settings pages (2026-07-30)

No code action needed — this is on-device QA only. There is no Xcode on this machine
(`/Library/Developer/CommandLineTools` only), so the change was verified by analyzer +
669 widget/unit tests and a mutation test, but never rendered on a device.

The fix: *Profile → Privacy & Security* had no swipe-back because its route was a raw
`PageRouteBuilder`. All nine settings routes now go through one `evolveRoute()` helper.

- [ ] On a real iPhone, open **Profile → Privacy & Security** and swipe from the left
      edge. It must now pop back to Profile. This is the reported bug.
- [ ] From that page, tap into **iCloud Sync** and swipe back too — that screen was
      always fine, but it is the flow you hit the bug in, so confirm the whole chain.
- [ ] Sanity-check the other seven still work (Personal Info, Subscription, App
      Settings, Notifications, App Logs, AI Chat, Profile itself from the dashboard
      avatar). They were migrated to the shared helper, so a mistake there would show
      up as a *lost* gesture on a page that used to have one.
- [ ] **Look at the transition on Privacy & Security.** It changed: it used to be a
      flat 400ms `easeOutCubic` slide with a static page behind it, and is now the
      native iOS slide with parallax and an edge shadow — i.e. identical to its
      siblings. That was the agreed intent, but it is a visible change and you should
      confirm you like it.
- [ ] **Arabic / RTL run.** The old hand-rolled transition always slid in from the
      right, even in Arabic; the native one mirrors. Switch the app to Arabic and
      confirm the page enters from the **left** and the swipe-back gesture lives on
      the **right** edge. There is a test pinning this, but it has never been seen on
      a device.
