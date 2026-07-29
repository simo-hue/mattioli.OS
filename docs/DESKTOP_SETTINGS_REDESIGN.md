# macOS Settings — analysis and redesign proposal

**Date:** 2026-07-28
**Status:** Proposal. No code changed.
**Scope:** `desktop/lib/features/settings/presentation/settings_page.dart` (4,671 lines) measured against the iOS settings surface (`mobile/lib/ui/screens/{profile,app_settings,notification_settings,privacy_settings,personal_info,subscription,icloud_sync,app_logs}_screen.dart`).

**Method:** 351 controls inventoried across both platforms, a 70-row parity matrix, 8 suspected dead controls put through adversarial verification (7 confirmed, 1 refuted), and 23 HIG/UX findings. Every claim below was traced to a consumer by grep, not inferred from a label.

---

## 1. Why the page feels wrong

Not because it is ugly. Because **the panes are not named after anything**, and because **a sixth of its controls are inert**.

iOS is a navigation hub — Profile with three headers (`Account & settings`, `Help`, `System`) pushing into six leaf screens, zero controls at the top level. Every screen answers one question. macOS is one page with a six-item rail where every control is inline, and the rail's taxonomy was never designed: `Application` is a container word, not a domain, and `Privacy` is seven unrelated concerns.

Three structural facts drive almost everything else:

1. **The rail is not a sidebar.** `SettingsPage` calls `DesktopPage` without `pinned: true`, so the header, the 225 px rail and the content pane all live in one `SingleChildScrollView`. On the Privacy and Application panes the destinations scroll off the top. A sidebar that scrolls away is not a sidebar.
2. **Every `_ActionRow` shows a chevron and opens a modal.** Settings has no second navigation level at all. The AI Coach pane is the extreme case: three rows, one of which launches a 1,335-line dialog containing the entire feature.
3. **The two-column grid breaks reading order.** `_GroupGrid` packs greedily by `children.length`, so Application's groups of 1, 6 and 4 rows render as left = card 1 + card 3, right = card 2. It also measures the *whole panel* including the rail against the 1280 px breakpoint, so cards actually go 2-up at ~1030 px of usable width.

---

## 2. Controls that do nothing

Verified by exhaustive grep across `desktop/lib`, `mobile/lib` and `packages/`. Each of these persists to SharedPreferences, dual-writes a `profiles` column, is a member of `PrivateDbSchema.syncedSettingKeys`, and genuinely reaches the iPhone — **where nothing reads it either.**

| Row | Key | Reality |
|---|---|---|
| AI Suggestions (PRO-badged) | `pref_ai_suggestions` | No consumer on either platform. `toggleAi` on mobile is called only from tests. The row is the page's *only* `EvolveProBadge` — so the Pro signal is attached to the one control that does nothing. |
| Milestones | `pref_milestones` | No celebration UI exists in either app. Defaults **on**, so it ships looking already-working. |
| Deep Work Insights | `pref_deep_work_insights` | No focus-session feature exists anywhere, while the copy promises "advanced analysis of your focus sessions". |
| AI Insights (notification) | `notif_ai_insights` | [`DesktopNotificationService.sync()`](../desktop/lib/features/settings/data/desktop_notification_service.dart) has no parameter, branch or notification id for it; the iOS consumer is an empty placeholder. |
| Weekly Reports (notification) | `notif_weekly_reports` | No weekly scheduling exists on either platform — `_scheduleWeekly` serves only day-restricted habit reminders. |
| *(no row anywhere)* | `notif_goal_deadlines` | Has a SQL column, a place in `syncedSettingKeys`, full read/write plumbing on both apps, an entry in the iOS data export — and no control and no consumer. |

iOS shows none of these five. They exist only in `AppSettings`. **The macOS page surfaced internal model fields as user-facing switches.**

Two more, found by the fleet and confirmed:

- **Update avatar** (`:653`) — in account mode `_pickAvatar` only does `setState(() => _profileImage = File(image.path))`. Never uploaded, never written to `profiles`, never restored at init. The avatar reverts on the next rebuild. The row is also *hidden* in Private mode, which is the one mode where the picker actually persists.
- **Email** in the Personal Information dialog (`:4466`) — a labelled `hintText` with no controller. It renders as an empty focusable box; the address is invisible until you click into it. `_save` sends only `{full_name, date_of_birth}`.

And a live defaults conflict: desktop initialises `_aiInsights`/`_weeklyReport` to `true` (`:358`), mobile reads them as `?? false`. Whichever device writes first silently flips the other.

> One claim was **refuted**: the subscription "Status → Active" row was flagged as a meaningless label. It is a read-only `_InfoRow` with no `onTap` — a disclosure, not a control. It stays.

---

## 3. Copy that leaks the implementation

`Supabase` appears in four user-facing strings, `Sentry` in one. `Data repository — "Supabase with encrypted cache"` is shipped as an info row. `Biometric lock — "Available with the native adapter on macOS and Windows; not supported on Linux."` describes a build matrix, not an effect. The sync diagnostics dialog shows a raw per-table monospace dump.

Two labels are actively wrong: **"Habit reminders"** only ever gated the id-0 morning brief (per-habit reminders keep firing from an unconditional loop), and **"Review initial consent"** reads as informational for an action that revokes terms acceptance, flips `MaterialApp.home` and tears down the shell — with no confirmation.

---

## 4. Misfiled, missing, unreachable

| | |
|---|---|
| **Focus mode** | Filed under Application › "AI & SYSTEM"; it is the master switch for the entire Notifications pane. iOS puts it first in Notifications. |
| **App logs** | Last row of "Calendar, experience and language". iOS gives it a top-level `SYSTEM` row. Its own doc comment refers to a "Settings → System" section that does not exist. |
| **Accent colour** | Sits in the *next* card from Theme, while "Appearance and visuals" contains a single row. |
| **Restore defaults** | `_resetSettingsToDefaults` exists and is thorough — reachable only by pressing the red **"Delete account and data"** button and picking the third option in the dialog. |
| **Privacy Policy / Terms** | Live only inside `_ComplianceLinks`, whose one call site is the Pro purchase surface — which is filtered out entirely in Private mode. A Private-mode user cannot reach the privacy policy from Settings. |
| **Search** | None. ~40 controls across 6 panes, and ⌘K indexes only the section as a whole. |
| **Private mode** | No way to enter it from macOS Settings; iOS offers it in Profile › System. |
| **App version** | Nowhere. iOS shows it. |
| **`const VerticalDivider(width: 1)`** (`:556`) | Paints nothing — loose cross-axis constraints from `CrossAxisAlignment.start` resolve it to 1×0 logical pixels. |
| **`subscriptionSettingsRequestProvider`** | A dead deep link. No producer anywhere in `desktop/lib` or `desktop/test`. |

**Rail labels disagree with pane headings in four of six cases:** Application → "Appearance and application", Privacy → "Privacy and security", Subscription → "Evolve Pro", and AI Coach is the only label sourced from a different i18n namespace.

**Nothing in the row vocabulary can render as disabled.** Pro-gated rows look identical to free ones and reveal the gate only on tap. Session-gated rows look enabled and answer a tap with a toast. `_SelectRow` and `_TimeRow` cannot carry help text at all, while `_SwitchRow`/`_ActionRow`/`_InfoRow`/`_ColorRow` take a *non-nullable* `detail` — so whether a control can explain itself is decided by its widget class, not by whether it needs explaining.

---

## 5. Proposed information architecture

**Eight panes, each answering one question a Mac user would actually ask**, behind a real fixed source list with search.

```
You      ── Account            Who you're signed in as, and where your data lives
         └─ Subscription       What Evolve Pro includes and how to change it

App      ── General            How Evolve looks and reads
         ├─ Notifications      Everything that can interrupt you
         └─ AI Coach           Which engine answers you and what it may see

Data     ── Data & Backup      Where your data is copied, how you get it in and out
         └─ Privacy & Security What Evolve can see and who else can open it

         ── Advanced           Expert and diagnostic surface

                               [ About: Evolve 1.1.2 (20) ]  ← docked footer
```

### Account
- **Profile** — profile card (avatar with a Change photo… / Remove photo menu), **Full name** and **Date of birth** as inline fields in *both* modes (today Private-mode users can never edit them), **Email** as a read-only right-aligned value.
- **Sign-in** — Change password…, Sign out *(ordinary styling; it is reversible)*, Sign in to an Evolve account… *(Private mode; was the red "Go to Login")*.
- **Data storage** — one row replacing the duplicated `Account` + `Data repository` pair: *"This Mac only, encrypted"* / *"Your Evolve account"*. Plus Reset consent choices….
- Footer: **Delete account…** — now naming the single thing it does, because content erasure moved to Data & Backup.

### General
- **Appearance** — Theme (Light / Dark / **Match system**), Accent colour *beside it at last*.
- **Language & formats** — Language, Default calendar view, 24-hour time. Group footnote: *"These settings also apply on your iPhone."* — the first cross-device disclosure anywhere in macOS Settings.
- **Getting started** — Replay the guided tour….

### Notifications
- **Focus** — Focus mode, moved here from Application. It is the master switch for this pane.
- **Daily reminders** — **Morning brief** *(renamed from "Habit reminders", which it never controlled)* + time, Evening review + time. Times **always render and disable** rather than appearing and disappearing, so the pane stops changing height under the cursor. An inline `_WarningRow` — *"Focus mode is on — these reminders are paused."* — appears while Focus mode is on.
- **Delivery** — one permission status row (Allowed / Not allowed / Not asked yet) replacing the standalone "Request notification permissions" dead end.

### AI Coach
`CoachSettingsDialog` is **dissolved into the pane**. Engine cards, key form, local-server status/address/model and the data-sharing status row become the pane body. The dialog is deleted; its four entry points navigate to the pane instead. System prompt and temperature move to Advanced.

### Data & Backup *(new)*
- **iCloud sync** — the switch with a live status subtitle, Sync now (disabled *with a reason*), a persistent end-to-end-encryption footnote (iPhone parity — today that copy is readable only inside the enable dialog), and the key-split remedy **promoted to a destructive warning banner** instead of sitting two rows below "Sync now" looking identical to it. In account mode the group collapses to an "Account sync" info row, so **the pane exists in both modes** and `SyncOffBanner` finally has a deep-link target that never disappears.
- **Backups** — Export a backup… / Import a backup….
- Footer: **Erase habits and goals… / Erase all data on this Mac…** — a first-class row, no longer the hidden third option inside a delete-account dialog.

### Privacy & Security
Narrowed to what a user would actually call privacy: **Require Touch ID to open Evolve**, **Send crash reports**, **Open Privacy & Security in System Settings…**, and **Privacy Policy / Terms of Use** — available in *both* data modes.

### Advanced
AI Coach tuning (system prompt, temperature with working clamps), Diagnostics (App logs…, Sync report… with a plain-language summary above the raw dump, Copy diagnostics), and **Restore default settings…** — separated from content deletion, with a confirmation that states what it does *not* touch.

---

## 6. Row specification

**Anatomy.** One horizontal band: `[optional 36px icon chip] · label (15/w700) with an optional detail line 3px beneath (12/w500, muted@0.8) · flexible gap · exactly one control in a fixed right-hand column.`

**Leading chips are dropped from ordinary preference rows.** Forty identical accent-tinted squares per pane is the single loudest non-native tell, and macOS Settings does not do it. Chips stay only where the icon carries information: engine rows, status rows, external-link rows, destructive rows, warning banners. `_RowHairline` then stops hard-coding its 68 px indent and insets to the card's 16 px padding.

**Labels.** Sentence case, no trailing colon, wrapping to two lines before ellipsising. A label names the effect on the user's world, never the mechanism or the vendor. State settings take a noun phrase ("Morning brief", "App lock"); anything that opens a dialog or leaves the app takes a verb phrase with an ellipsis ("Change password…", "Export a backup…").

**Values.** Read-only values are **right-aligned in the control column**, not in the subtitle slot. This one change stops `_InfoRow` reading as a caption typographically identical to the help text of the row above it — and frees the subtitle slot for real explanation.

**Subtitles.** `detail` becomes `String?` on *every* row type. Its presence is an editorial decision per row, never a property of the widget class. Use it when the label under-specifies the effect, when the setting reaches another device, or to carry a disabled reason. Drop it when the label is self-evident.

**Controls.** Exactly one per row, right-aligned. A chevron means one thing only — it opens a modal. External destinations get an external-link glyph. Nothing is a chevron merely because it is a list row.

**Disabled and gated.** A row that cannot be used dims across label, icon and control, goes non-interactive, and states why in the detail slot. Pro-gated rows dim and offer an explicit Upgrade affordance rather than turning the whole hit area into a paywall trigger. Capability that can never exist on this machine (Touch ID on Linux, iCloud sync off macOS) **hides** rather than dims.

**Destructive.** Weight correlates with consequence, not position. "Go to Login" loses its red fill (it is a reversible mode switch that deletes nothing) while genuinely destructive rows — Rebuild iCloud sync from this Mac…, Remove key…, Restore default settings… — get a destructive-tinted variant inside a normal card.

### New row types
`_TextRow` (inline field committing on blur/Enter — this single type is what lets two modals be deleted), `_StatusActionRow` (label · right-aligned status · trailing button), `_WarningRow` (inline banner inside a card), `_StepperRow`, `_PrimaryButton` (full-width filled — so the money step stops being the weakest-looking element in the funnel), plus a `footnote` slot on `_SettingsGroup` and genuine busy states on action rows.

### Shell changes
Fixed full-height rail (`pinned: true`) with a real trailing border replacing the zero-height divider; destinations grouped You / App / Data / Advanced with separators; **search field pinned at the top of the rail (⌘F) filtering rows across every pane**; About footer docked at the bottom; content pane gets its own scroll controller that resets on pane change; `_GroupGrid` deleted in favour of one column capped at ~700 px; `_SettingsHeading` deleted (the selected rail item *is* the pane title — today every pane renders ~90 px of duplicate chrome before the first control).

---

## 7. Implementation plan

Ordered so nothing is unsafely reorderable. **Step 1 is a hard prerequisite** for the renames, search and ⌘K row addressing.

| # | Step | Effort | Files |
|---|---|---|---|
| 1 | **Row identity first.** Stable `Key`s + `Semantics(selected:, button:)` on every destination and row, no label or position changes. Migrate the nine label-tapping tests to Keys. | M | `settings_page.dart` (`:2785`, `:3163-3518`); 9 test files |
| 2 | Pure extraction, no behaviour change: row kit + section enum out of the monolith. | M | → `widgets/settings_row_kit.dart`, `settings_section.dart` |
| 3 | **The pivot** — hoist ~20 State fields and the persistence helpers into a Riverpod `SettingsFormController` so panes can live in separate files. | L | new `application/settings_form_controller.dart` |
| 4 | Split each pane into its own file, still rendering today's IA. | L | → `panes/*.dart`, `dialogs/*.dart` |
| 5 | Shell rebuild: pinned rail, real border, grouped destinations, About footer, own scroll controller, single column. | M | `settings_page.dart` (`:526-590`), `desktop_page.dart` |
| 6 | Extend the row vocabulary to §6. | M | `settings_row_kit.dart`, `evolve_controls.dart`, `evolve_panel.dart` |
| 7 | IA move 1 — General + Notifications; **delete the five dead rows (UI only — keep every pref key and column)**. | M | `panes/{general,notifications,advanced}_pane.dart` |
| 8 | IA move 2 — Account: inline personal info, delete `_PersonalInfoDialog`, merge the two mode rows, fix the Pro badge in Private mode. | L | `panes/account_pane.dart`, `auth_controller.dart` |
| 9 | IA move 3 — Data & Backup: new pane, promoted key-split banner, Erase split out of the delete-account dialog, retarget `SyncOffBanner`. | L | `panes/data_backup_pane.dart`, `sync_off_banner.dart` |
| 10 | IA move 4 — Privacy & Security: narrow the pane, hide the biometric row on Linux, add the legal links. | M | `panes/privacy_pane.dart`, `desktop_biometric_controller.dart` |
| 11 | IA move 5 — AI Coach: dissolve `CoachSettingsDialog`, retarget its four entry points, delete the file. | L | `panes/ai_coach_pane.dart` |
| 12 | Subscription pane: `_PrimaryButton` CTA, real busy states, radio + checkmark + Semantics on plan cards. | M | `panes/subscription_pane.dart` |
| 13 | Advanced pane, with `_resetSettingsToDefaults` rescoped so it no longer touches habits, goals or the biometric lock. | M | `panes/advanced_pane.dart` |
| 14 | Navigation state: one `settingsSectionRequestProvider`, last-visited pane, delete the dead subscription flag. | S | `navigation_controller.dart` |
| 15 | Search + ⌘K row indexing off the step-1 registry. | M | new `widgets/settings_search.dart`, `command_palette.dart` |
| 16 | One localisation pass across 22 locales: renames, vendor scrub, sentence-case group titles, orphan-key deletion. | L | `desktop/lib/i18n/*` |

---

## 8. Risks

- **The rail is the test contract.** At least nine widget tests navigate by tapping a destination's literal label. Step 1 exists to break that dependency before any rename lands.
- **The five dead toggles are a UI removal, not a migration.** Their pref keys and their columns in `PrivateDbSchema.syncedSettingKeys`, `desktop_private_db.dart` and `migrations/20260623_add_profiles.sql` must stay — the iPhone still reads, writes and syncs them, and existing synced rows depend on the schema.
- **Inline name/DOB editing in Private mode activates code paths never reachable from desktop Settings** (`updatePrivateProfile` → `DesktopPrivateDb.updateProfileFields` → `notifyWrite`). Verify the write, the after-write sync trigger and the iPhone round trip before shipping.
- **Account-mode avatar has no upload path at all.** No Supabase Storage call exists anywhere in `desktop/lib`, and the shell reads a `user_metadata.avatar_url` the app never writes. Either implement the upload or scope the avatar menu honestly to Private mode.
- **Focus mode's cross-device sentence is currently false in account mode** — `profileColumn` is null there (`:927`), so it syncs only in Private mode. This is the one setting where a wrong claim means silently silencing the user's phone.
- **24-hour time is near-cosmetic on macOS today** — it reaches only the two reminder pickers and the "Last synced" label, while iOS applies it app-wide via `MediaQuery.alwaysUse24HourFormat`. Either make it app-wide deliberately or say what it actually does.
- **The biometric disabled state needs a capability probe that does not exist.** `unlock()` deliberately fails **open** when nothing is enrolled — so the switch can read ON while protecting nothing.
- **Splitting "Reset data" changes blast radius in both directions.** The content path must stop calling `setEnabled(false)` on the biometric lock at `:2249` — a silent security downgrade the old confirmation never mentioned.
- **Renaming "Habit reminders" → "Morning brief" diverges from the iPhone label for the same synced key.** The label is wrong on both platforms; ship the Mac rename with a tracked follow-up on iOS.
- **Single-column layout loses density on wide displays.** Cap content at ~700 px and verify the longest panes (AI Coach in Private mode with a local engine; Data & Backup during a key split).
- **Copy changes touch 22 locales.** Batch renames, vendor scrub, sentence-case titles and orphan-key deletion into one localisation pass.

---

## 9. Parity defects found in passing

Not part of the redesign, but surfaced by the audit and worth tracking separately:

- **Accent palette:** macOS renders all 7 presets; the iOS swatch grid calls `.take(3)`. Emerald, Violet, Pink and Orange are pickable on the Mac, sync to the iPhone, render there, and **cannot be re-selected there**.
- **Theme:** macOS offers a 3-option select including `system`; iOS offers a 2-state switch that *always* writes an explicit `dark`/`light`, so one tap on the phone destroys "follow system" for both devices.
- **Pro badge in Private mode:** iOS masks it (`isPro && !isPrivateMode`); macOS passes `desktopIsProProvider` raw, and that provider hard-returns `true` in Private mode — so every Private-mode Mac shows a gold PRO pill.
- **Export copy:** macOS reports export *failure* under the title "Export complete" (`:1366`). iOS's subtitle claims "JSON / CSV Format" but neither branch ever emits CSV.
- **Sync now:** iOS disables the row when sync is off/unavailable/busy; macOS renders a fully tappable chevron and then silently returns early.
- **Tutorial reset:** macOS resets one tour via an *unsuffixed* `tour_completed` pref shared across data modes; iOS resets three flags under mode-suffixed keys.
- **Pro feature lists disagree:** macOS pitches "Habit-Specific Statistics" + "Advanced Goal Metrics"; iOS pitches "Advanced Statistics" + "Unlimited Goals".
- **Restore purchases:** macOS renders it in both states; iOS only in the non-Pro branch, leaving a Pro user with a desynced entitlement no affordance.

## 10. Deliberately not done

- **"Use Private mode on this Mac"** — wireable via `enterPrivateMode()`, but it hands a new entry point to the SQLCipher key-guard and recovery flow. Deferred until that path has on-device QA.
- **A goal-deadlines row** — the plumbing exists but no consumer does. Adding a control would create a sixth dead toggle rather than removing five.
- **Haptic feedback, Apple Health, Screen Time, the three habit-verification notifications, Cancel Subscription** — iOS-only for platform reasons. Permission rows that can never be granted are worse than their absence.
