# TO_SIMO_DO


## Manual Actions Required

## macOS visual QA — deep coherence polish (2026-07-12)
This Mac has no Xcode, so the changes below were **code-verified** (`flutter analyze` clean of new issues; 144 pass / 1 pre-existing fail) but still need an on-device look on the Xcode machine (`flutter run -d macos`). All are pure presentation — no logic/data changes. Check each in **both light and dark** themes:

- [ ] **Statistics** — the positive/completed greens (30-day grid "done" cells + legend, "Positive correlations" heading + value, high-mood & mood bars + their legend dots) now use the app success token instead of a one-off emerald; confirm they read as the same green used elsewhere and still pair correctly with the rose/amber siblings.
- [ ] **Dashboard** — the Protocollo quick-action tiles' leading icon chip (now `EvolveIconChip`); confirm size/tint match the metric-card chips in the same view.
- [ ] **Habits → day-detail dialog** — each habit's completion row is now the kit check-square (fills the habit color + check-mark when done, dimmed when the date isn't editable) with title + status caption + flame/streak badge; confirm tapping still toggles the day and nothing looks like the old Material checkbox.
- [ ] **Goals stats → year selector** — the year dropdown trigger now matches the other `EvolveSelect` pop-ups (34px tall, radius 12, up/down chevrons, muted calendar); confirm the Pro-gated year picker still opens and locks non-Pro years.
- [ ] **Settings → App logs** — the severity chip is now the shared `StatusPill`; the expanded "Additional context" label is now sentence-case (`EvolveFieldLabel`); confirm both render.
- [ ] **Settings → Biometric error** — the error message text now uses the destructive token (was Material `redAccent`).
- [ ] **Dashboard → "New goal" dialog** — the Category field is now a dropdown of your saved categories (color dot each) + a "New category" row that reveals an inline text field; confirm picking an existing category AND creating a new one both save correctly, and that a fresh account with no categories still shows a plain text field.

