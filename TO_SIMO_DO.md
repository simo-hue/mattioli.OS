# TO_SIMO_DO.md

- [ ] Widget for iPhone & MacOS
- [ ] statistiche per obiettivi stile counter come vengono gestite ( sono binarie: failed or succeded oppure si tiene conto anche di quanto vicino ci sono arrivato a raggiungerle? )
- [ ] Ci deve essere anche da desktop nella pagina dei goals la specifica informazione delle date esatte dei periodi ad esempio per la settimana numero Z ( da giorno X a Y ), ma la stessa cosa anche per gli obiettivi trimestrali
- [ ] **Macro goals need a numeric target + progress bar.** `MacroTargetsConfig.enabled` is
  still `false` on **both** apps — the feature is not user-visible until:
  - UI: create/edit numeric target (amount + unit) + optional "link a habit" picker +
    progress bar, both apps, behind the flags (+ 5-locale i18n, Arabic native review)
  - Cloud-mode delete-snapshot: fetch-sum-before-delete so deleting a linked habit keeps the
    accumulated value (Private mode already snapshots)
  - Force-write the numeric columns on the Supabase UPDATE path so editing can *clear* a
    target or break a link
---

Manual actions only — things code cannot do. Anything fixed is deleted from here;
history lives in `DOCUMENTATION.md`.

```bash
flutter run -d macos --dart-define-from-file=.env
flutter build macos --release --dart-define-from-file=.env
flutter build ipa --release
```

---

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