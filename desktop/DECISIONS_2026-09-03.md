# Desktop — findings that need your decision

_From the 2026-09-03 deep scan (16 finders → per-finding adversarial verification → second
skeptic pass on the serious ones → dedup). 63 defects survived; 52 were mechanical and have been
fixed. These 3 could not be: each changes what a screen shows or offers. Nothing below has been
touched._

Baseline at the time of writing: `flutter analyze` clean, 851 tests green / 1 failing
(`desktop_supabase_config_security_test`, the documented environmental failure).

| # | Severity | Area | One line | Cost of the small option |
|---|---|---|---|---|
| [D1](#d1) | medium | AI Coach | "Run the coach 100% privately?" is offered where accepting it does nothing | 1 line |
| [D2](#d2) | medium | Habits calendar | ~~Inert check square on a quantitative habit, and no past-day entry at all~~ **Resolved 2026-09-12** — see the note under D2 | 1 line |
| [D3](#d3) | low | Shared widgets | Crop dialog's confirm button is hardcoded English | 1 line |

---

<a id="d1"></a>
## D1 · The local-coach banner makes a privacy claim account mode cannot honour · medium

`features/ai_coach/presentation/ai_coach_page.dart:1824-1825` shows the "Run the coach 100%
privately?" banner whenever a local server is detected. Its action calls `useLocalServer()`
(`:1892-1896`), which only persists `coach_backend = 'local'`, then dismisses the banner
permanently.

But every send reads `effectiveCoachBackendProvider`, and `domain/coach_config.dart:341-355`
returns `standard` **unconditionally in account mode**. So an account-mode Pro subscriber with
Ollama running accepts the offer and their next message still goes to the Supabase Edge Function →
OpenRouter / Google AI Studio. The banner hides only when the *effective* backend is already
local, which in account mode never happens.

The banner's own comment claims the offer is "as true a win for a subscriber as for someone paying
OpenRouter directly" — that stopped being true when `effectiveCoachBackend` was made standard-only
for account mode. The settings pane already tells the truth: `coach_settings_panels.dart:128-130`
carries an `accountModeNote` reading "Those are available in Private mode".

**Mitigating:** the send path still runs the standard-disclosure consent gate
(`ai_coach_page.dart:251-262`), so nothing leaves the machine unconsented. The defect is the false
claim and the inert control, not an actual leak.

**Decide:** hide the banner outside private mode — `return SizedBox.shrink()` when
`!ref.watch(activeDesktopDataModeProvider).isPrivate`, matching what the settings pane already says
— **or** relax `effectiveCoachBackend` so an account-mode subscriber can genuinely run local.

> This is on the axis (naming who receives personal data) that got the app rejected twice, which
> is why it is ranked above its blast radius. The one-line hide is the safe answer for a
> resubmission; the second option is a real capability change.

---

<a id="d2"></a>
## D2 · The day-detail dialog shows a live-looking square that silently does nothing · medium

> **Resolved 2026-09-12**, by the first option: the day dialog now routes a quantitative habit's control
> to `TargetEntryDialog` with the real date, on quick-log days and in the new Edit mode for older
> days, and draws it as the Protocol table's ring. Verified habits stay read-only on every day, drawn
> disabled, as PARITY_AUDIT #28 accepted. See `DOCUMENTATION.md` for the change.

`features/habits/presentation/habits_page.dart:2169-2191` — `_DayDetailsDialog` applies no target
filter, and `_DayHabitRow` dims its square only when `onToggle == null`. So a user with "at most 1
coffee" clicks yesterday in the habits calendar and gets an enabled-looking, hoverable square.
Clicking it reaches `dashboard_controller.dart:112-122`, hits the early return for
`target?.isUserEnterable`, logs, and returns. No verdict, no dialog, no toast, no disabled styling.

There is no other route: both `TargetEntryDialog.show` call sites pass `date: today`. **Desktop
cannot enter or correct a manual target's number for a past day at all** — while the same dialog
renders the "today and yesterday" edit hint.

The desktop protocol table gets this right (`habits_page.dart:707-753` swaps the square for a ring
wired to `TargetEntryDialog`), and mobile routes the tap properly
(`mobile/lib/ui/widgets/day_details_modal.dart:284-300`).

**Decide:** route the tap to the existing `TargetEntryDialog` with `date: date` — mobile's
behaviour, and the desktop protocol table's — **or** pass `onToggle: null` so the square renders in
its existing disabled style.

> Only the first closes the capability gap; both change what the dialog does.
>
> Note the same dialog is equally inert for **auto-verified** habits, which `PARITY_AUDIT.md` #28
> consciously accepted. If you pick the disabled-style option, the two cases become consistent.

---

<a id="d3"></a>
## D3 · The avatar crop dialog's confirm button is hardcoded English · low

`shared/widgets/evolve_image_crop_dialog.dart:67` — the sheet has a localized title (`:46`) and a
localized Cancel (`:58`), and the only button that commits reads `Crop`. An Italian, Spanish or
German user uploading a profile picture sees one English word; the `ar` build shows a Latin word
inside an RTL dialog.

It is the only hardcoded Latin string in `desktop/lib/shared/widgets`, and no `crop` key exists in
the slang catalogue.

**Decide:** reuse an existing key — `t.settingsPage.confirm`, `applyAction` or
`common.actions.save`, all present in all 5 locales — **or** add a dedicated `crop` key.

> The code change is one line either way. It needs your call because the visible English label
> changes, and because reusing a key means the button says "Save"/"Confirm" rather than "Crop".

---

## Also relevant to desktop

Two items in [`mobile/DECISIONS_2026-09-03.md`](../mobile/DECISIONS_2026-09-03.md) have a desktop
half, and whichever way you decide applies to both codebases:

- **M5** — the orphaned-owner self-heal scans five tables and misses `user_settings`.
  Desktop carries the identical list at `core/desktop_private_db.dart:2378-2384`.
- **M6** — private-mode import drops `order_key`. The written trade-off that a fix would revise is
  yours, at `core/desktop_private_db.dart:2126-2133`.
