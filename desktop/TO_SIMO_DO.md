# TO_SIMO_DO


## Manual Actions Required

## Parity Tranches 2–4 — on-device QA on the Xcode machine (2026-07-14)
Code-verified (analyze 0 errors, `flutter test` 214 pass / 1 pre-existing fail).
(The earlier AI-coach compile blocker resolved itself — the concurrent session
fixed the ai_coach errors + `tutorialProvider` references; app compiles again.)
Smoke-test the new behaviors on device (`flutter run -d macos`):
- [ ] **Notifications** — set a per-goal reminder, then turn OFF 'Habit
      Reminders' in Settings: the per-goal reminder must STILL fire (only the
      09:00 Morning Brief should stop). Tap **Snooze** on a habit notification →
      it re-fires ~10 min later. With no notification permission yet, setting a
      reminder from the habit editor should trigger the macOS permission prompt.
- [ ] **Biometric lock** — enable it, unlock, then hide/minimize the app (or
      Mission Control) and return: it must re-prompt (walk-away re-lock). Cold
      start auto-prompts (no manual Unlock click). On a Mac with no Touch ID it
      must NOT lock you out (fails open).
- [ ] **Pro gates** (cloud mode, non-Pro account) — creating a 6th habit shows
      the paywall; switching Statistics to a specific habit shows the paywall.
      Confirm Private mode is unaffected (always Pro).
- [ ] **Privacy** — Settings → App logs: warnings/info with an email or token no
      longer show it raw (redacted).
- [ ] **Avatar** — pick a new avatar of the SAME file type twice; the header +
      settings avatar must update immediately (no stale photo).
- [ ] **Accent color (#29)** — as a non-Pro cloud account, the custom '+' accent
      swatch shows a lock and opens the paywall; presets still work. Private mode
      is unaffected (always Pro).
- [ ] **Verified badge (#25)** — a habit created/verified on the iPhone
      (verify rule set) shows the "Verified" shield badge next to its title on
      both the dashboard and Habits pages. **Visual pass wanted**: confirm the
      badge size/placement/copy read well; refine if needed.
- [ ] **Import profile (#12)** — a MERGE import must NOT change your current
      theme/language/name; a REPLACE (full restore) still applies the backup's.

## Unblock the corrupted private DB — one-time reset on the Mac mini (2026-07-14)
`flutter run -d macos` crash-loops with `DB Error: 26 "file is not a database"` on
`evolve_private_v2.db`. Root cause: a Keychain read-miss made the (now-fixed)
desktop key logic mint+persist a NEW SQLCipher key, orphaning the existing file.
The code fix prevents recurrence but CANNOT recover the already-orphaned file
(the original key was overwritten in the Keychain and is gone).

Do this on the Mac mini (`/Users/simo`), app quit first:
- [ ] Quit the running app (`q` in the `flutter run` terminal).
- [ ] Delete the unreadable DB + its WAL/SHM sidecars:
      `rm -f ~/Library/Containers/com.simo.evolve/Data/Library/Application\ Support/com.simo.evolve/evolve_private_v2.db*`
      (This discards the local private data — which is already undecryptable, so
      nothing readable is lost. Owner id + Keychain entries are kept.)
- [ ] Re-run `flutter run -d macos --dart-define-from-file=.env`; a fresh empty
      encrypted DB is created with the current key and the crash is gone.
- [ ] (Optional, only if you want to attempt recovery first) Check whether the
      old key still exists before deleting:
      `security find-generic-password -a evolve_private_db_key -g` — if it prints
      no password, the key is gone and recovery is impossible; proceed with the delete.

## Verify Private-mode secret-storage parity port — on Xcode machine (2026-07-14)
Native + Dart change (device-local keychain pin, dup-item recovery, **backup
exclusion**). Code-verified here (analyze 0-new, Swift typecheck clean, tests
189/2-pre-existing) but the native backup-exclusion can only be confirmed on
device. After the DB reset above, `flutter run -d macos --dart-define-from-file=.env`:
- [ ] App boots cleanly (error-26 crash gone; a fresh `evolve_private_v2.db` is created).
- [ ] The private data dir is flagged backup-excluded. Check either:
      `mdls -name com_apple_backup_excludeItem ~/Library/Containers/com.simo.evolve/Data/Library/Application\ Support/com.simo.evolve`
      (or `xattr -l` on the dir) — should show the exclusion set; and the marker
      file `.private_mode_local_only` should exist in that dir.
- [ ] No `[Warning] [DesktopPrivateDb] backup exclusion failed` in **Settings → App logs**
      (would mean the native `evolve/private_storage` channel didn't register).
- [ ] Sanity: sign-in, private-mode data, and iCloud sync still work (the owner id
      now reads from the `first_unlock_this_device` tier — confirm it's stable across
      relaunch, i.e. you're not treated as a new owner).

## macOS visual QA — deep coherence polish (2026-07-12)
This Mac has no Xcode, so the changes below were **code-verified** (`flutter analyze` clean of new issues; 144 pass / 1 pre-existing fail) but still need an on-device look on the Xcode machine (`flutter run -d macos`). All are pure presentation — no logic/data changes. Check each in **both light and dark** themes:

- [ ] **Statistics** — the positive/completed greens (30-day grid "done" cells + legend, "Positive correlations" heading + value, high-mood & mood bars + their legend dots) now use the app success token instead of a one-off emerald; confirm they read as the same green used elsewhere and still pair correctly with the rose/amber siblings.
- [ ] **Dashboard** — the Protocollo quick-action tiles' leading icon chip (now `EvolveIconChip`); confirm size/tint match the metric-card chips in the same view.
- [ ] **Habits → day-detail dialog** — each habit's completion row is now the kit check-square (fills the habit color + check-mark when done, dimmed when the date isn't editable) with title + status caption + flame/streak badge; confirm tapping still toggles the day and nothing looks like the old Material checkbox.
- [ ] **Goals stats → year selector** — the year dropdown trigger now matches the other `EvolveSelect` pop-ups (34px tall, radius 12, up/down chevrons, muted calendar); confirm the Pro-gated year picker still opens and locks non-Pro years.
- [ ] **Settings → App logs** — the severity chip is now the shared `StatusPill`; the expanded "Additional context" label is now sentence-case (`EvolveFieldLabel`); confirm both render.
- [ ] **Settings → Biometric error** — the error message text now uses the destructive token (was Material `redAccent`).
- [ ] **Dashboard → "New goal" dialog** — the Category field is now a dropdown of your saved categories (color dot each) + a "New category" row that reveals an inline text field; confirm picking an existing category AND creating a new one both save correctly, and that a fresh account with no categories still shows a plain text field.

## Statistics enrichment — on-device QA + translation review (2026-07-14)
No Xcode on this Mac → **code-verified only** (`flutter analyze` clean; full suite 267 pass / 1 pre-existing env fail). Needs `flutter run -d macos` on the Xcode machine. All new content is read-only analytics over existing data (no writes, no new backend). Check in **both light and dark**, and in **both Private and Cloud** data modes (they share the compute):

- [ ] **Info tab** — Momentum ring shows a sane 0–100 with a sensible color band; the lifetime hero tiles (consistency %, total done, perfect days, days tracked) populate; the **365-day contribution heatmap** renders and scrolls horizontally without making the page overflow; the **Keystone** card appears only when there are ≥2 habits with enough signal (and is hidden otherwise, no empty gap).
- [ ] **Trend tab** — Best/Critical **ranked lists** (not single cards); rolling 7/30-day rows with up/down arrows; **weekly-rhythm radar** (renders with real data, shows an empty-state when there are no logs — confirm it does NOT crash on all-zero data); seasonality + weekday/weekend bars.
- [ ] **Alerts tab** — Performance Comparison cards, Bounce-back %, Danger Zone (or their empty states).
- [ ] **Habits tab** — the new **current-streak badge** does not overflow the row on the narrowest window; consistency / medals / distribution / category (only if you actually categorize habits) / **synergy matrix** render; the synergy matrix scrolls horizontally when you have many habits.
- [ ] **Mood tab** — mood/energy **line chart**, Mood-Sensitive + Resilient lists, correlation analysis.
- [ ] **Per-habit → Overview** shows **4** tiles including **Record**.
- [ ] **Translations** — review the 82 new `stats.*` keys in **de / es / ar** (en + it were authored carefully; the other three are best-effort machine translations).

## Per-habit statistics enrichment — on-device QA (2026-07-14)
The per-habit (a specific habit selected) view is **Pro-gated** — sign in as Pro (or toggle the entitlement) to reach it. Code-verified only (no Xcode). `flutter run -d macos`, both light/dark, both data modes:
- [ ] **Overview** — the Momentum ring + 8-tile grid render; the "Ahead of X% of your habits" pill shows only when you have ≥2 habits; tiles show "—" gracefully for a brand-new habit with no data.
- [ ] **Calendar** — gap analysis (avg / longest / since-last), monthly seasonality bars, and This-month-vs-last render below the yearly heatmap; empty states appear for a fresh habit.
- [ ] **Performance** — weekday/weekend split + rolling 7/30-day rows with up/down arrows appear under the weekday bars.
- [ ] **Improvement** — Bounce-back / Consistency / At-risk / Danger-day tiles + the **streak-history bar strip** (confirm it doesn't overflow with a habit that has many short runs) + the schedule-adherence panel.
- [ ] **Mood** — the **next-day mood impact** panel appears only when there's mood data both after dones and after misses; the lift pill is green/red correctly.
- [ ] Sanity: switch between two habits and confirm every panel updates to the selected habit (no stale data), in Private and Cloud modes.

## Goals board — linear layout on-device QA (2026-07-14)
Reworked the Goals page: completed/failed goals no longer go to a right rail — the board is now one linear column at all widths, with the completion ring + period heading + Completed/Failed/Active counts in a header band at the top, and completed/failed goals at the bottom under the `COMPLETED`/`FAILED` dividers. Code-verified only (no Xcode here): `flutter analyze` clean; suite 276 pass / 1 pre-existing env fail; `tour_flow_test` (renders the goals page) passes. Run `flutter run -d macos`, check **both light and dark** and **Private + Cloud** modes:
- [ ] **Header band** — the ring shows the completion %; heading (period title/subtitle) sits beside it; the three counts render on **one line** right-aligned (`COMPLETED n | FAILED n | ACTIVE n`, color-coded, pipe-separated) and stay readable at the **narrowest** window (~960px) without overflowing or clipping — check **German** (longest labels) especially.
- [ ] **Active goals** — render as single-line rows beneath the header hairline; the target-icon chip + title + hover actions (reschedule/edit/delete) look right; hover dimming still works.
- [ ] **Complete a goal** — after the ~2s debounce it drops from the active list down under the green `COMPLETED` divider, shows the green check + strikethrough inline on its row, and the ring/counts update.
- [ ] **Fail a goal** — same, under the red `FAILED` divider with the red X inline.
- [ ] **Wide window** — on a large/maximized window the rows go full-width (edge-to-edge, aligned with the command bar); confirm this reads OK to you (we chose full-width over a capped column — say if you'd prefer it capped/centered).
- [ ] **Empty & mixed states** — no active goals but some completed/failed (active empty-state shows, sections still appear); and a period with zero goals (ring at 0%, empty-add state).
- [ ] **Tour** — the goals step of the product tour still spotlights the first active goal's checkbox.


## Habit-stats audit — manual actions (2026-07-14)
Full analysis + fix status: `docs/HABIT_STATS_AUDIT.md`.
- [ ] **Deploy the SQL migration** `migrations/20260714_fix_get_global_trend_year_all.sql`
      to Supabase (fixes the cloud-mode Trend chart for the **Year** and **All**
      timeframes — they previously dropped empty days/months from the average).
      Review the SQL first; it's a `CREATE OR REPLACE FUNCTION` (WEEK/MONTH branches
      unchanged, only YEAR/ALL fixed). No data migration, safe to re-run.
- [ ] **Rebuild + test the iOS app** — the shared `private_analytics.dart` DST fix
      and the `_calculateRecuperoData` sort fix were applied to `mobile/` and pass
      `flutter analyze` + `mobile/test/private_analytics_test.dart` here, but the
      full iOS app was not built on this Mac. Run `flutter analyze` + `flutter test`
      + a device build for mobile to confirm.
- [ ] **(Optional, web app)** The web client (`src/hooks/useGoals.ts`
      `toggleLogMutation`) never writes `goal_logs.streak`, so the cloud
      `habit_stats` view reports 0/stale streaks for habits last toggled from the
      web. macOS & iOS persist it correctly. Patch the web write path if web-logged
      cloud streaks matter.
- [ ] **On-device QA — Goals arrow-key navigation (desktop).** Logic is covered by
      `test/goals_page_keyboard_test.dart`, but the app can't be run here (no Xcode).
      On the Mac, open Goals and confirm: (1) ←/→ page the timeline for each plan
      (weekly/monthly/quarterly/annual), including month/week rollover; (2) typing
      in the quick-add field, arrows move the caret (don't change the period);
      (3) with a year/month/week or category picker open, arrows don't page behind
      it; (4) arrows are inert during the guided tour and on the Lifetime tab; (5)
      RTL (Arabic locale): ← advances, → rewinds. Optional: mirror the same
      ←/→ paging on the Habits page (it uses the identical `_shiftAnchor(±1)` prev/
      next idiom) for cross-page coherence. [DONE — Habits calendar now has ←/→.]
- [ ] **On-device QA — period-change animation (desktop).** Logic is test-covered,
      but the slide+fade needs a human eye on the Mac (no Xcode here). Check:
      (1) Goals board and Habits calendar visibly slide+fade on every ←/→ AND
      ‹ › click AND dropdown jump — direction matches (next drifts from the
      trailing edge); (2) date picker: day grid slides on ‹ › month nav and the
      dialog height settles smoothly (no snap) between 5↔6-row months; (3) RTL
      (Arabic) mirrors the slide direction; (4) no flicker/jump on the Goals board
      when the goal count differs between periods; (5) marking a goal complete then
      immediately pressing ←/→ still persists the completion (was a silent-loss
      bug, now fixed + regression-tested).
