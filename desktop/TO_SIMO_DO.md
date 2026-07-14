# TO_SIMO_DO

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