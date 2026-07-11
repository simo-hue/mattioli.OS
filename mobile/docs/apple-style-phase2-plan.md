# Apple-Style UI — Phase 2 Roadmap (mobile)

**Started:** 2026-07-11 · **Approach:** Primitive-first, full coherence (user-approved).

Phase 1 (done, committed) migrated 4 surfaces onto `lib/ui/kit/` (`showEvolveSheet`,
`showEvolveFormSheet`, `EvolveListSection`/`EvolveListRow`, `EvolveColorSwatchGrid`,
`CupertinoAlertDialog`). Phase 2 extends that kit across the rest of the app.

A 4-cluster read-only audit found ~40 un-Apple surfaces that collapse into **~6 missing
primitives** + cheap per-surface swaps. Build the primitives once, then migrate in
leverage order. Verify `dart analyze` clean + `flutter test` (144) between every batch.

---

## Primitive layer — BUILT ✅ (Task #7)

All in `lib/ui/kit/`, matching kit idioms (Inter, `context.appColors`, gated `ref.haptic*`,
Flutter 3.44 `activeTrackColor`). Barrel: `evolve_kit.dart`.

| File | Exports |
|---|---|
| `evolve_dialog.dart` | `showEvolveConfirm({isDestructive, ref})` → `Future<bool>`, `showEvolveAlert()` (single dismiss). Wraps `CupertinoAlertDialog` in a `CupertinoTheme` with the **app** brightness. |
| `evolve_button.dart` | `EvolveButton(label, onPressed, icon?, style, expand, loading)`; `EvolveButtonStyle{filled,tinted,destructive,plain}`. Luminance-contrast text; CupertinoButton press-fade. |
| `evolve_switch.dart` | `EvolveSwitch`, `EvolveSwitchRow(leading?, title, subtitle?, value, onChanged)`. `CupertinoSwitch` + gated haptic. |
| `evolve_segmented_control.dart` | `EvolveSegmentedControl<T>(groupValue, segments: Map<T,String>, onValueChanged, expand)`. Wraps `CupertinoSlidingSegmentedControl`, equal-width when `expand`. |
| `evolve_section_header.dart` | `EvolveSectionHeader(title, padding?, trailing?)`. 13px muted, no forced uppercase. |
| `evolve_toast.dart` | `showEvolveToast(context, message, icon?, kind, duration)`; `EvolveToastKind{neutral,success,error}`. Root-overlay fading capsule. |

Deferred optional primitives (Task #16, build if a site needs them): `EvolveSpinner`
(CupertinoActivityIndicator), `EvolveTextField`, `EvolveStatTile`.

---

## Migration batches (leverage order)

### Task #8 — Dialogs → `showEvolveConfirm` / `showEvolveAlert` (~13)
- [ ] `subscription_screen.dart:1185` cancel (destructive), `:1069` success, `:1220` Material warning icon
- [ ] `subscription_alert_modal.dart:58` result alert
- [ ] `ai_chat_screen.dart:320` consent, `:594` delete-chat (destructive)
- [ ] `app_logs_screen.dart:141` clear (destructive)
- [ ] `profile_screen.dart:101` logout (destructive)
- [ ] `icloud_sync_screen.dart:91` disclosure
- [ ] `privacy_settings_screen.dart:1449` confirm/delete/reset, `:1084`/`:1150` import completed/failed
- [ ] `habit_management_modal.dart:202` delete-habit (destructive) — also gate haptic `:276`
- [ ] `day_details_modal.dart:191` edit-lock → `showEvolveAlert` + gated warning haptic
- [ ] `goal_item_widget.dart:186` goal delete (destructive)

### Task #9 — Segmented pills → `EvolveSegmentedControl` (5)
- [ ] `view_tab_bar.dart:22` Month/Week/Year/Life
- [ ] `statistics_screen.dart:603` Info/Trend/Alert/Abitudini/Mood
- [ ] `macro_goals_screen.dart:711` My Goals / Performance
- [ ] `global_mood_tab_widget.dart:139` time range (+ gate haptic `:152`)
- [ ] `global_trend_tab_widget.dart:454` timeframe (+ gate haptic `:467`)

### Task #10 — CTAs → `EvolveButton` (~8)
- [ ] `daily_check_in_modal.dart:158` Enter/Update
- [ ] `habit_management_modal.dart:566`/`:644` save/actions
- [ ] `day_details_modal.dart:121` empty CTA
- [ ] `dashboard_screen.dart:1132` empty add-habit, `:1362` name-prompt, `:927` app-locked retry
- [ ] `statistics_screen.dart:367` + goals tutorial coach-marks

### Task #11 — Material `Switch` → `EvolveSwitchRow` (4 files)
- [ ] `app_settings_screen.dart:419` dark mode / haptics / 24h (helper `:306`)
- [ ] `notification_settings_screen.dart:344` habit reminders / evening review (helper `:250`)
- [ ] `privacy_settings_screen.dart` biometric / crash-report (helper `:350`)
- [ ] `icloud_sync_screen.dart` sync toggle (helper `:314`)
- [ ] `consent_screen.dart:219` terms Checkbox (+ `:256` Material check icon)

### Task #12 — Micro-labels → `EvolveSectionHeader` (10+)
- [ ] `profile_screen.dart:430`/`:489`/`:526`; `app_settings_screen.dart:276`; `privacy_settings_screen.dart:249`; `notification_settings_screen.dart:164`
- [ ] `habit_management_modal.dart:409`/`:455`/`:471` HABIT NAME / COLOR / REMINDER
- [ ] `macro_goals_screen.dart:1228` Completed/Failed dividers + picker sheet headers
- [ ] `protocollo_panel.dart:42` PROTOCOLLO (+ gate haptic `:231`)

### Task #13 — SnackBars → `showEvolveToast` (~15)
- [ ] `personal_info_screen.dart:90`/`:134`/`:153`
- [ ] `privacy_settings_screen.dart:894`/`:1592`/`:1617`/`:1628`/`:1647`/`:1658`
- [ ] `auth_screen.dart:86`/`:111`/`:128`/`:156`
- [ ] `consent_screen.dart:58`/`:72`; `ai_chat_screen.dart:290`/`:955`; `app_logs_screen.dart:113`/`:770`
- [ ] `day_details_modal.dart:191` (if not already an alert); `dashboard_screen.dart:1243`

### Task #14 — Sheets → `showEvolveSheet` / `showEvolveFormSheet` (~15)
- [ ] `app_settings_screen.dart:146` default-view, `:814` language, `:511` accent chrome, `:594` full-color → `showEvolveColorPicker`
- [ ] `notification_settings_screen.dart:359` time picker; `personal_info_screen.dart:342` date picker
- [ ] `privacy_settings_screen.dart:1240` delete/reset chooser, `:459` change-password editor
- [ ] `macro_goals_screen.dart:793` type picker; `global_habits_tab_widget.dart:201` sort-by; `macro_goals_stats_view.dart:413` year picker
- [ ] `goal_item_widget.dart:109` edit rename → `showEvolveFormSheet`
- [ ] `daily_check_in_modal.dart:13`, `day_details_modal.dart:29`, `habit_management_modal.dart:21`, `error_modal.dart:28`, `pro_features_modal.dart:14`, `app_logs_screen.dart:679`, `ai_chat_screen.dart:59` settings

### Task #15 — Lists → `EvolveListSection` / `EvolveListRow` (~7)
- [ ] `profile_screen.dart:629` option rows; `privacy_settings_screen.dart:95`/`:137`/`:209` main list
- [ ] `app_settings_screen.dart:291`/`:436`/`:496` cards/action rows; `notification_settings_screen.dart:179` cards
- [ ] `icloud_sync_screen.dart:265` card; `subscription_screen.dart:920` active-details rows; `:429` feature list + `pro_features_modal.dart` features

### Task #16 — Optional primitives + cross-cutting cleanup + final verify
- [ ] `EvolveSpinner`: `subscription_screen.dart:334`/`:375` amber CircularProgressIndicator
- [ ] Optional `EvolveTextField` (personal_info, privacy change-pw, auth, habit name) / `EvolveStatTile` (KPI captions)
- Correctness bugs (fix in-place, even in files not otherwise restyled):
  - [ ] **Ungated `HapticFeedback.*` → `ref.haptic*`**: `add_goal_bar.dart:51`/`:85`, `global_habits_tab_widget.dart:266`, `macro_goals_stats_view.dart:479`/`:532`, `yearly_view_widget.dart:30`/`:38`, plus any left after batches 8–15
  - [ ] **Static `AppColors.*` → `context.appColors.*`**: `day_details_modal.dart` (many), `notification_settings_screen.dart:334`, `privacy_settings_screen.dart:341`/`:434`, `icloud_sync_screen.dart:450`
  - [ ] **i18n**: hardcoded Italian `subscription_screen.dart:446`/`:460`; hardcoded `'Close'` `privacy_settings_screen.dart:1189`
  - [ ] **Font**: `GoogleFonts.outfit` → Inter at `privacy_settings_screen.dart:937`
  - [ ] **Material icons → Lucide/Cupertino**: `Icons.close`/`chevron_*`/`lock_outline`/`person_outline`/`warning_amber` across day_details, weekly/yearly views, dashboard, subscription
- [ ] Final `flutter analyze` (expect only the 18 pre-existing infos in untouched files) + `flutter test` (144) + prepend DOCUMENTATION.md entry

---

## Deliberately left bespoke (audit "checked & clean")
`bottom_nav_bar.dart` (custom glass pill nav), `life_view_widget.dart` / `habit_calendar_widget.dart`
(CustomPaint charts), goal status glyph, colored `GoalLogCard` status rows, branded auth/consent
CTAs, subscription hero/gradient CTAs. Do **not** force the kit onto these.

## Current status
- **Task #7 done** — primitives + this doc. Kit analyzes clean.
- **Task #8 done** — dialog migrations. Migrated goal delete, habit delete, day-lock (→toast),
  profile logout, app-logs clear, AI consent + delete-chat, iCloud disclosure, subscription cancel,
  privacy confirm-helper + import completed/failed. Fixed ungated haptics + `dart:ui` cleanups + the
  hardcoded `'Close'` i18n bug en route. Extended `showEvolveAlert` with a rich `content:` slot.
  **Deliberately left bespoke** (brand hero/gradient): subscription success celebration,
  `subscription_alert_modal`. Full `flutter analyze` = 16 issues (all pre-existing, down from 18);
  `flutter test` = 144 passing.
- **Task #9 done** — 5 segmented pills → EvolveSegmentedControl (+2 ungated haptics fixed).
- **Task #10 done** — primary CTAs → EvolveButton (check-in, day-details, habit editor pair, dashboard empty/app-locked). Added `secondary` style + `haptic` param. Deferred (bespoke/branded): habit-modal gold upgrade CTA, dashboard welcome/name-prompt, one-time tutorial coach-marks.
- **Task #11 done** — 4 settings Material switches → EvolveSwitch. Deliberately skipped: consent legal-terms Checkbox.
- **Task #12 done** — section headers → EvolveSectionHeader (privacy/notification/app_settings helpers, profile ×3, habit-modal HABIT NAME/COLOR/REMINDER). Left branded protocollo header (ungated haptic deferred to #16).
- Verify after each batch: analyze = only pre-existing privacy RadioListTile+unawaited infos (down from baseline 18 → 16); tests green (144).
- **Task #13 done** — 20 Material SnackBars → showEvolveToast (personal_info, privacy, auth, ai_chat, app_logs, consent). Extended showEvolveAlert with a rich `content:` slot. All faithful (incl. auth conditional success/error kind).
- **Task #14 IN PROGRESS** — selection sheets DONE: default-view, language, planning-type, sort-by, year-picker (Pro-lock preserved) → showEvolveSheet + EvolveListSection/EvolveListRow. Deleted dead `_buildViewOption`/`_buildLanguageOption`. Bonus: killed the type-picker `.toUpperCase()`.
  - **REMAINING T14 (not started):** app_settings accent-picker chrome (`_showAccentColorPicker`, the sole remaining showModalBottomSheet there ~line 502 — complex validated/Pro flow); notification time picker; personal_info date picker; privacy delete/reset chooser + change-password editor; `goal_item` edit-rename → showEvolveFormSheet; sheet-CHROME swaps for daily_check_in / day_details / habit_modal / error_modal / pro_features (hand-rolled grabber+header → showEvolveSheet); app_logs detail sheet; ai_chat settings dialog (custom pill toggles → EvolveSwitch + form sheet).
- **Task #15 (not started)** — settings lists → EvolveListSection/Row (profile hub, privacy/app_settings/notification/icloud cards, subscription active-details + feature lists).
- **Task #16 (not started)** — EvolveSpinner (paywall CircularProgressIndicator); optional EvolveTextField/EvolveStatTile; cross-cutting cleanup: remaining ungated haptics (protocollo tile :231, add_goal_bar, yearly_view — some need ConsumerStatefulWidget conversion), static `AppColors.*` → `context.appColors.*` (day_details + settings), i18n (subscription Italian literals, verify none remain), font (privacy `GoogleFonts.outfit`→inter), Material icons → Lucide/Cupertino, app_settings default-view trailing `.toUpperCase()`. Final analyze + test + DOCUMENTATION.md.

## Verification state (as of checkpoint)
- Full `flutter analyze` = **16 issues, ALL pre-existing** (privacy RadioListTile ×4, privacy unawaited, pulsing_sync_animation prefer_final, + a few in untouched gen/animation files) — down from baseline 18.
- `flutter test` = **144 passing** at every batch gate (T7→T14-partial).
- **~50 surfaces migrated across tasks 7 → 14-partial.** Deliberately-preserved bespoke/brand surfaces are listed above under each task. Checkpointed here so the primitive layer can be visually QA'd before the riskier chrome/editor/list remainder (which all build on those primitives).

## Resume instructions
Read this file, then continue at **REMAINING T14** above. Kit primitives all exist in `lib/ui/kit/` (see the primitive table). Reference patterns: `category_picker_sheet.dart` (selection sheet), `statistics_screen._showGoalSelector` (Pro-lock sheet). The brace-matcher helper for large-method replacement is at `<scratchpad>/replace_method.py` (paren-matches params then body brace; sig must be unique).
