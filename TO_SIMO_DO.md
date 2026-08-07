# TO_SIMO_DO.md

Manual actions only — things code cannot do. Anything fixed is deleted from here;
history lives in `DOCUMENTATION.md`.

```bash
flutter run -d macos --dart-define-from-file=.env
flutter build macos --release --dart-define-from-file=.env
flutter build ipa --release
```

---

## 1. Blocking now — habit reorder rollout (2026-08-06), in this order

1. [ ] **Apply `migrations/20260806_add_goal_order_key.sql` BEFORE anyone installs the
   build.** Account mode only (Private migrates itself, v11→v12). Reading is safe without
   it; *writing* is not — creating the first habit sends `order_key` and Postgres rejects
   an insert naming a missing column.
2. [ ] **Size the streak damage** (read-only, writes nothing):
   `cd mobile && dart run tool/audit_streaks.dart <export.json> --all`
   Export via Profile → Privacy → **Export Data** (iOS share sheet → save to Mac).
   `[collapsed]` rows = the real corruption; the rest is ordinary staleness. The in-app
   repair fixes both on next launch regardless.
3. [ ] **After BOTH devices are updated**, open Manage habits once, check the order,
   re-drag anything wrong. Expect one settling pass — the two devices' `display_order`
   had already diverged.
4. [ ] **Desktop needs a build** — it shares the v12 schema and reads/writes `order_key`,
   but has never been run on a real machine.
5. ⚠️ **v12 strands older builds** (`onDowngrade` throws, deliberately). You cannot roll a
   device back by reinstalling an older TestFlight / `.app`.

## 2. Blocking — macOS App Store resubmission (2026-07-30)

Repo side is done. These are App Store Connect actions. Order matters. Ship **1.0.0 (27)**.

1. [ ] **Verify the demo account first — everything else is wasted if it fails.** Sign in
   on the Mac with `wowtesting@gmail.com` / `TestForMePls1.` in **Account mode** (not
   "Continue privately"). macOS auth is **Supabase**, not StoreKit sandbox. If it fails,
   create a real Supabase user and update `desktop/macos/fastlane/metadata/review_information/`
   (`demo_user.txt`, `demo_password.txt`, `notes.txt`).
2. [ ] **While signed in, confirm the paywall shows real prices** (⌘, → Subscription).
   Not "Price unavailable" — prices only resolve when signed in. This is also the screen
   the 3.1.2(c) recording must show.
3. [ ] **Push metadata**: `cd desktop/macos && fastlane mac metadata`. Then verify in ASC
   that the **Italian** description carries the EULA link (Italian is what the reviewer reads).
4. [ ] **Set App Review Information** — tick "Sign-in required", populate credentials. The
   red badge on **App Review** must clear.
5. [ ] **Reply in Resolution Center** with the recording: launch → Account sign-in → ⌘, →
   Subscription, showing plan titles, 1 month / 1 year, live prices, both legal links opening.
6. ⚠️ **Do NOT add the subscriptions to the version page.** Both products are Approved and
   shared with iOS via Universal Purchase. 2.1(b) fired because the reviewer couldn't
   *reach* the purchase screen.
7. [ ] **`desktop/macos/Podfile.lock` needs regenerating on a Mac with Xcode + CocoaPods**
   (this machine has neither). `desktop/pubspec.yaml` now pins `path_provider_foundation:
   2.5.1`, which swaps macOS back to the Darwin plugin and adds a pod.

## 3. Device QA — needs a real iPhone / Mac

**Habit drag (2026-08-06)** — nothing below has run on a device.
- [ ] 44pt grip, long-press-anywhere on a row, lift/settle haptics, lift shadow on dark card.
- [ ] Tapping the pencil scrolls to the populated form (now targets the form key, not offset 0).

**Screen Time (2026-07-28)** — ordered by how much they'd change.
- [ ] **T1 (highest value)** Does re-registering reset the day's counter? Register a 5-min
  limit, burn 6 min, force-quit, relaunch, background→foreground, burn 6 more. If it
  restarts at zero, every launch forgives the day and `atMost` habits are unreachable.
  Also: an *unchanged* goal must still have an entry in `screen_time_monitor_specs` after a
  sync that touched a different goal.
- [ ] **T2** Does `stopMonitoring()` deliver `intervalDidEnd`? Edit a threshold mid-day,
  check the App Group buffer (`group.com.simo.evolve.verification`, `pending_screen_time_signals`)
  for a `stayedUnder` row — assert on its `y/m/d`, not "today". **No row = pass.** Test the
  **23:55–23:59** band specifically (the one hole the mid-day guard can't cover).
- [ ] **T3** `otool -L …/PlugIns/DeviceActivityMonitorExtension.appex/…` — system frameworks
  only. Any `@rpath/Flutter.framework` or `SQLCipher` means it'll be jetsammed at 6 MB.
- [ ] **T4** Midnight attribution. Precondition: `screen_time_monitor_thresholds` must hold
  `{goalId: minutes}`. Cross a limit at ~23:58 app-closed; the verdict must land on that day.
- [ ] **T4b / T10** DST fall-back and spring-forward Sundays — crossing must land on the
  right day; the 23-hour day must still produce a `stayedUnder` row.
- [ ] **T5** Web-only picks are reported as "empty" and refused, though native handles domains.
- [ ] **T6** 2+ Screen Time habits: one buffer entry per goal after 23:59 (unsynchronised
  read-modify-write race).
- [ ] **T7** Revoke Screen Time, reopen: where does the toggle live, what does
  `authorizationStatus` report? The in-app button opens Settings › Evolve, not the Screen
  Time pane its copy describes.
- [ ] **T9** Power-off overnight, boot next morning — does DeviceActivity replay the missed
  `intervalDidEnd`? If yes, `lateDeliveryWindowMinutes` is discarding real passes.

**Auto-verified habits (2026-08-04)**
- [ ] **Re-grant Health access for the compound habit** — iOS only prompts for types never
  asked about. Editor → *Grant Health access*, then verify **iOS Settings › Health › Data
  Access & Devices › Evolve** shows EVERY metric on (the only place the truth is visible).
- [ ] Force-quit → relaunch, check YESTERDAY resolves within a second or two.
- [ ] Counter habits need one full day — auto-fail is anchored to the first day the rule
  runs on your device.

**Arabic / accessibility**
- [ ] Does `≥` render mirrored (like `≤`) in RTL? `≥`/`≤` mean opposite things here. If it
  does and you dislike it, the fix is a locale-owned pattern (`على الأقل` / `على الأكثر`).
- [ ] Does 11pt SF Arabic clip dots/diacritics on the habit line? May need +1pt.
- [ ] Release chip at large Dynamic Type in **German and Arabic** — no overflow, "Use
  Salute/Salud/صحتي" stays readable.
- [ ] VoiceOver: the release is a **rotor action** (the card excludes descendant semantics).
  Confirm it's reachable and reads well.

**Other**
- [ ] macOS: switch data mode in Settings, then edit a habit's target and Save (the
  edit-after-rebuild fix). Before it, the dialog closed and the edit vanished.
- [ ] Change a preference on iPhone, close/reopen Settings on Mac — Mac shows iPhone's value.

## 4. Known bugs, verified real, NOT fixed — say the word

- [ ] **macOS fetches `goal_logs` / `goal_progress` unpaginated** (`dashboard_repository.dart:386`,
  no `.range()`). Mobile paginates *because* PostgREST's `db-max-rows` truncates silently.
  On a large history the Mac reads real days as untouched and auto-fail writes `missed` over
  a real `done` — and the two devices genuinely oscillate. **Highest priority here.**
- [ ] **An AND compound with a data-less metric can never complete** (design limit). If one
  condition is a metric your devices don't record, HealthKit returns nothing for "no data"
  and "read denied" alike, and the app refuses to score silence as zero. Either switch that
  habit to **Any of these (OR)** (works today, no code change), or ask me to build the
  diagnostic — `HealthKitBridge.hasRecentData` exists and still has **zero callers**.
- [ ] **Reinstall reaches Supabase + RevenueCat pre-consent.** The Keychain session survives
  deletion; `has_completed_consent` doesn't. Same shape as the bug that got you rejected.
- [ ] **Pro modal makes a false claim on the paywall.** `aiCoachDesc` ends "Prefer your own
  OpenRouter account? That's free too" — BYOK is **Private-mode only**, and this renders on
  the 3.1.2 screen itself.
- [ ] **Life View shows a stranger's life by default** — `_LifeCalendar` falls back to
  `DateTime(2003)` with no DOB set. Should be an empty state.
- [ ] **`lifeWeeks` label vs months grid** — the app contradicts itself. Fix the string and
  the 30 non-UI locales together, after approval.
- [ ] **Arabic grammar family** (pre-existing): numbers don't agree with units — `≥ 8 ساعة`
  must be `8 ساعات`, same for `mindfulMinutes`, `activeEnergy`; `selectionSummary` also has a
  gender bug (`محددة`); unit/label stutter in all locales (`≥ 30 min Exercise minutes`);
  three different verbs for "tap"; `CouldNotVerifyChip` hardcodes ASCII `?` (Arabic `؟`).
  Cheapest fix: make Arabic unit tokens invariant abbreviations (`د`, `س`) like `كم`.
- [ ] **`_saveLocal()` runs once per applied change** in the desktop sweep — ~225 keychain
  writes returning from a 45-day absence. Perf only; hoisting adds an early-return path.
- [ ] **Reminder scheduling DST seed** — deliberately unchanged. `_nextInstanceOfTime` steps
  with `Duration(days: 1)` but on `tz.TZDateTime`, and `matchDateTimeComponents` re-matches
  wall-clock each time, so only the *seed* could be an hour off. Worth a look with a device.
- [ ] **iOS descriptions over Apple's 4000-char limit** for `ca / el / fr-CA / fr-FR`
  (4011–4180). Note: `mobile/ios/fastlane/metadata/` is **not in the repo**, so this can only
  be fixed wherever those files actually live.

## 5. Test / CI gaps

- [ ] **CI runs in UTC**, so the DST tests never exercise a real transition. A `TZ=Europe/Rome`
  leg on one job would make them bite. Say the word.
- [ ] **Nothing proves the two week calendars call `weekDaysFor`** — reverting a call site in
  `habits_page.dart` / `weekly_view_widget.dart` to a `Duration` would be invisible to CI.
  Both widgets are private, so this needs a widget test.
- [ ] **Account mode is untested end-to-end on mobile** — no test runs `HabitLogsNotifier` /
  `HabitProgressNotifier` against a Supabase session.

## 6. Backlog / product

- [ ] Widget for iPhone & macOS
- [ ] Statistiche per obiettivi stile counter: sono binarie (failed/succeeded) o si tiene
  conto di quanto vicino ci sono arrivato?
- [ ] Desktop, pagina goals: mostrare le date esatte dei periodi (settimana Z = da X a Y),
  idem per i trimestrali
- [ ] **Macro goals need a numeric target + progress bar.** `MacroTargetsConfig.enabled` is
  still `false` on **both** apps — the feature is not user-visible until:
  - UI: create/edit numeric target (amount + unit) + optional "link a habit" picker +
    progress bar, both apps, behind the flags (+ 5-locale i18n, Arabic native review)
  - Cloud-mode delete-snapshot: fetch-sum-before-delete so deleting a linked habit keeps the
    accumulated value (Private mode already snapshots)
  - Force-write the numeric columns on the Supabase UPDATE path so editing can *clear* a
    target or break a link
- [ ] **Screen Time question worth grilling:** a 10-minute app limit is obviously true at the
  start of the day. How is the number increasing *during* the day handled — is the habit
  re-checked, or is its first state fixed forever?
