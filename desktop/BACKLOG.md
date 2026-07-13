# Evolve Desktop — Feature-Parity Backlog

Remaining desktop work to reach parity with the mobile app (`mobile/`, package
`mattioli_os`, the **source of truth**). Produced from a deep three-lens scan
(data/private-mode correctness, feature parity, UI/controller logic) after the
localization + RTL sweep. Implement **one item at a time**, fully verified,
following the per-item workflow and conventions below.

> References are anchored on **symbols** (function / widget / class names), not
> line numbers — line numbers drift as files change. `grep` for the symbol to
> locate it. Desktop paths are under `desktop/lib/…`; mobile paths under
> `mobile/lib/…`.

---

## Baseline to preserve (run from `desktop/`)
- `flutter test` → **`+74 -1`**. The one expected failure is
  `desktop_supabase_config_security_test` (environmental — needs a `--dart-define`
  Supabase config; fails identically on unmodified code). Must stay `+74 -1` or
  better after every item.
- `flutter analyze lib` → **0 errors** (a few pre-existing warnings/infos are OK;
  don't add new ones).

## Conventions (mandatory)
1. **Localization.** The app is fully localized in **en/it/es/de/ar** via `slang`.
   Every new user-facing string is a `t.*` key in ALL 5 `lib/i18n/*.i18n.json`
   files — never a literal. Reuse mobile's value where the string exists on mobile
   (grep `mobile/lib/i18n/it.i18n.json` for the Italian, copy that key's value from
   all 5 mobile JSONs). Run `dart run slang` after editing any JSON. A `t.*` value
   can't sit in a `const` widget — drop the outer `const`.
2. **Tests assert Italian copy** and pin the slang locale to `it` in `setUp`
   (`test/widget_test.dart`, `test/dashboard_controller_test.dart`,
   `test/evolve_dialog_test.dart`). Keep new `it` values / finders consistent.
3. **RTL.** New nav/disclosure icons → `directionalIcon`/`DirectionalIcon`
   (`lib/core/rtl.dart`); asymmetric horizontal insets/alignments →
   `EdgeInsetsDirectional`/`AlignmentDirectional`.
4. **Mirror mobile behavior**; do not destabilize the private-mode vs cloud-mode
   branching or the encrypted-DB schema.
5. **Commits:** one focused commit per item; **no** `Co-Authored-By: Claude` / AI
   co-author / "Generated with" trailer.
6. **Docs:** append a dated entry to `DOCUMENTATION.md` per item; only touch
   `TO_SIMO_DO.md` for a real manual action (env var/key/migration).

## Per-item workflow
Read mobile ref → 3–5 line plan → implement minimal cohesive change → localize
(5 locales, `dart run slang`) → `dart format` → `flutter analyze lib` (fix new
errors) → `flutter test` (stay `+74 -1`, add tests where useful) → commit →
`DOCUMENTATION.md` entry → next item.

---

## Already done this pass (do NOT redo)
- Full localization (all screens/dialogs/controllers/services, 5 locales) + Arabic RTL (`lib/core/rtl.dart`, `test/localization_rtl_test.dart`).
- Goals: weekly-goal week-of-month math; tutorial fake-goal no longer tappable; Pro-cap on the Goals page; reschedule shown for active/completed non-lifetime goals; dead goal-editor horizon dropdown removed.
- AI Coach: double-send guard + streaming try/catch/finally (errors surface, `_isTyping` always resets).
- Dashboard: daily check-in dialog seeds today's saved mood/energy; optimistic habit streak uses shared `computeStreak`.
- Private DB: `setHabitLogFromNotification` signed streak (done/missed); `applyImport` skips malformed rows + dedupes categories by `(user_id,name)`.
- `PrivateDashboardRepository`: streak via `computeStreak`; upsert-by-key instead of `INSERT OR REPLACE` (sync-tombstone fix).
- **Statistics screen rebuilt** — mood-correlation engine ported (`computeMoodCorrelations`/`MoodCorrelation` in `private_analytics.dart`); real analytics providers wired into Alerts/Info + per-habit Overview/Improvement/Performance/Mood tabs; Global-Trend timeframe selector; critical-day token localized.
- **Notifications & reminders** — Windows daily recurrence; reschedule on habit add/edit/delete; reminder time-picker (read-only, clearable, 24h `HH:mm`).

---

## Backlog (priority order)

### 1. Cloud backup export/import round-trip  — *data integrity, high value*
The **cloud-mode** export is not round-trippable and import is disabled in cloud mode. (The **private-mode** export/import path is already fine.)
- Desktop: `_exportData` cloud branch in `features/settings/presentation/settings_page.dart` emits a bespoke `evolve-desktop-supabase-cache` snapshot (reduced fields, **no profile, no macro-goal categories**). The importer `DesktopBackupImportService.parseZipPreview`/`_processData` (`core/desktop_backup_import_service.dart`) only parses the web `backup.json` ZIP schema → desktop's own export can't be re-imported. Import is also gated to private-only (the import handler constructs the service with a `null` Supabase client; `_executeCloudImport` exists but is unreachable).
- Mobile ref: export in `mobile/lib/ui/screens/privacy_settings_screen.dart` (profile + full settings + habits + macro-goals + categories + moods); import works in both modes.
- **Do:** make the cloud export emit the importer's schema (incl. profile + categories, hsl colors) — or extend the parser to accept the desktop shape — so there is ONE authoritative round-trippable format; and enable import in cloud mode (pass the real Supabase client to `_executeCloudImport`).
- **Done when:** a cloud export re-imports cleanly (categories + goals + moods + profile preserved) and import works in cloud mode; add a round-trip test.

### 2. Pro upsell modal + paywall value-proposition  — *revenue*
Locked features dead-end with a bare SnackBar; the paywall has working price/Activate/Restore/Manage plumbing but **no feature list, no upsell header, no success UX**.
- Desktop gate points: goal-cap SnackBar in `features/dashboard/presentation/dashboard_page.dart` (`_FocusGoalsPanel`), macro-stats year gate in `features/goals/presentation/goals_stats_view.dart`, Goals-page quick-add cap in `features/goals/presentation/goals_page.dart` (`_submitQuickGoal`); paywall UI in `settings_page.dart` (subscription section).
- Mobile ref: `mobile/lib/ui/widgets/pro_features_modal.dart` + `mobile/lib/ui/screens/subscription_screen.dart` (upsell header, 4-item feature list, best-value badge, success celebration).
- **Do:** port the modal as a desktop dialog; route all gate points to it (deep-link to Settings → Subscription); add the paywall feature list + styled success/result UX.
- **Done when:** hitting any Pro gate opens the modal with the pitch and a path to purchase; paywall shows the value proposition + success state.

### 3. Dashboard + Statistics onboarding tours  — *onboarding*
Only the goals coach-mark tour was ported. Dashboard shows a plain welcome dialog then `setTutorialSeen(true)`; Statistics has no tour; `statsTutorialProvider` (`core/tutorial_provider.dart`) is dead.
- Desktop pattern to reuse: `_buildGoalsTutorialOverlay`/`_buildGoalsTutorialSteps` (scrim + geometry refresh) in `features/goals/presentation/goals_page.dart`. Dashboard entry: `DashboardPage._showWelcomeScreen`. 
- Mobile ref: dashboard tour in `mobile/lib/ui/screens/dashboard_screen.dart`, stats tour in `mobile/lib/ui/screens/statistics_screen.dart` (`tutorial_coach_mark`).
- **Do:** build a dashboard tour and a stats tour with the goals scrim-overlay pattern; wire `statsTutorialProvider`; keep the Settings "reset tutorial" hook resetting all three flags.
- **Done when:** first run of the dashboard and stats screens shows step-by-step coach marks; reset re-arms them.

### 4. App Logs viewer  — *diagnostics*
Missing entirely on desktop (`AppLogger` exists but has no viewer UI).
- Mobile ref: `mobile/lib/ui/screens/app_logs_screen.dart` (filter/search/detail/copy/share/clear), entered from `profile_screen.dart`.
- **Do:** port it as a desktop page/dialog; add a Settings **System** row to open it.
- **Done when:** logs are viewable/filterable/copyable from Settings.

### 5. AI Coach context + suggested prompts  — *quality*
- **Multi-turn memory:** `AiCoachPage._sendMessage` sends only user turns (`_messages.where((m) => m.isUser)`), stripping every assistant reply → follow-ups lose context; it also omits the user name + completed-goals count from the context prompt. Mobile sends the full history (`mobile/lib/ui/screens/ai_chat_screen.dart`) and injects name + active/completed-goal counts + today's completion. **Do:** send the full `_messages` history and enrich the context prompt.
- **Suggested prompts:** desktop has no suggestion chips; mobile has dynamic ones (`ai_chat_screen.dart`, keys under `t.ai.suggestions.*` — already localized). **Do:** port a suggestions row above the input.

### 6. Habit UX  — *interaction parity*
- **Drag-to-reorder habits:** model already has `displayOrder`; no reorder UI or `reorder` controller method. Mobile: `mobile/lib/ui/widgets/habit_management_modal.dart` (`SliverReorderableList` + persist). **Do:** add reorder UI in `features/habits/presentation/habits_page.dart` + a controller method that persists order (cloud + private repos).
- **Inline category management in the add-goal picker:** `features/goals/presentation/goals_page.dart` uses a bare `PopupMenuButton` (default + existing only); archive has no confirmation/linked-count warning. Mobile: `add_goal_bar.dart` → `category_picker_sheet.dart` (create/edit/archive + linked-goal-count warnings, auto-select new). **Do:** replace the popup with a richer picker.

### 7. Statistics & data polish
- **Global Habits tab:** read-only, no sort, no real per-habit rate/best/worst — `_GlobalHabits` in `features/statistics/presentation/statistics_page.dart`. Mobile: `global_habits_tab_widget.dart` (sortable list w/ rate/best/worst + drill-in). **Do:** make it a sortable list backed by `habitStatsRpcProvider`.
- **Yearly heatmap:** collapses missed vs untracked (`_HabitCalendar`/yearly-grid mapping in `statistics_page.dart`); lost red-miss + completed/missed/rate summary. Mobile: `habit_calendario_tab_widget.dart`. **Do:** distinguish missed vs untracked + add the summary.
- **Life view DOB in private mode:** `_LifeCalendar` in `features/habits/presentation/habits_page.dart` reads DOB only from Supabase `userMetadata` → private mode always defaults to 2003. **Do:** in private mode read DOB from the encrypted private profile.
- **Dashboard-home habit row** shows a binary checkbox with no "missed" state (`_HabitRow` in `dashboard_page.dart`) — consider surfacing missed like mobile.

### 8. Cleanup / smaller fixes
- **Reset-to-defaults inconsistency:** `settings_page.dart` "reset to defaults" sets AI insights + weekly reports to **false**, but the initial state defaults them **true**. Make reset match the initial defaults (both ON).
- **Daily check-in emoji feedback** per slider (mobile `daily_check_in_modal.dart`).
- **Full color picker** (`flutter_colorpicker`) in create-habit/goal + category editor instead of preset swatches only.
- **Day-details dialog:** add a per-habit streak badge and an "editable only today/yesterday" hint (`_DayDetailsDialog` in `habits_page.dart`).
- **Import HSL→hex parser** should not silently default unknown colors to blue — `_hslToHex`/`_processData` in `core/desktop_backup_import_service.dart`; pass through valid `#hex` and map named tokens.
- **FK-pragma convergence:** desktop sets `PRAGMA foreign_keys = ON` at schema level (`core/private_db_schema.dart` `onConfigure`); mobile sets it at open time. Make them consistent and document which (affects import strictness parity).
- **`_GoalItem` keying:** give each `_GoalItem` a `ValueKey(goal.id)` in `goals_page.dart` so its 2-second pending-state timer follows identity across re-sorts (avoids flipping the wrong goal).
- **Notification actions in cloud mode:** `DesktopNotificationService._handleHabitAction` only writes in private mode — implement (or hide the actions in) cloud mode.
- **Deprecated `value:` vs `initialValue:`** on `DropdownButtonFormField` — standardize across `create_goal_dialog.dart`, `goals_page.dart`, `habits_page.dart`.
- **Consent screen:** desktop omits a notification-permission card and a Terms-of-Service link that mobile shows; desktop password min is 8 vs mobile 6 (align if desired — product decision).

---

## Out of scope (do NOT implement)
- ~~**Phase-2 iCloud/CloudKit sync** — deferred by decision (macOS reuses the iOS CloudKit container; Windows/Linux stay local-only; needs Apple provisioning). Tracked on the mobile `fix/icloud-sync-privacy-bugs` branch, not here.~~ _(Superseded 2026-07-13: **DONE** — implemented and user-facing on macOS Private mode: Settings → Privacy iCloud sync card (enable toggle + Sync now + status/last-synced), backed by `CloudKitPrivateSyncService` (`core/desktop_private_sync_service.dart`, macOS-only) and `desktop_sync_lifecycle.dart`. macOS still reuses the iOS CloudKit container `iCloud.com.simo.evolve`; Windows/Linux stay local-only via a NoOp sync service.)_
