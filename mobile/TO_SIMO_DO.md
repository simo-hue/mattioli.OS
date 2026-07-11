# PROSSIME AZIONI MANUALI (SIMO)

Manual / on-device / Apple-account steps that can't be done from code. The
in-code work behind each of these is implemented and committed.

---

# 🔍 APPLE-STYLE VISUAL QA — do on BOTH devices (2026-07-11)

The Apple-style coherence work is code-complete and verified (iOS: `flutter analyze` 16 pre-existing / `flutter test` 144 pass; macOS: `flutter analyze` clean / `flutter test` 144 pass + 1 pre-existing unrelated fail). **Only the on-device visuals need your eyes** — no new deps, env vars, or setup. Do each in **light AND dark**, and iOS additionally with a **non-Pro** account.

## 📱 iOS (the `mobile/` app — run on an iPhone / the iOS Simulator on your Mac)

**A. Dialogs (Cupertino confirm/alert).** Trigger each and confirm native iOS look, correct destructive-red, and that the dialog's light/dark matches the app (not the system): delete a habit, delete a goal, **Logout** (Profile), **iCloud** enable disclosure (Private mode), **cancel subscription**, AI Coach **consent** + **delete chat**, App Logs **clear**, Privacy **reset/delete** confirms + **import completed/failed**.
**B. Segmented controls (sliding thumb, equal width, bold selected):** the home **Month/Week/Year/Life** bar, **Statistics** tabs (Info/Trend/Alert/Abitudini/Mood — the 5-tab one is the tightest; check labels don't clip), **Goals** My-Goals/Performance toggle, **Mood** + **Trend** time-range rows.
**C. Buttons (`EvolveButton`):** daily check-in **Enter/Update**, habit editor **Cancel/Update** pair, day-details + dashboard **empty-state** CTAs, **app-locked retry**. Check press-fade + text contrast on your accent.
**D. Switches (now iOS `CupertinoSwitch` — there were none before):** App Settings **Dark Mode / Haptics / 24h**, Notifications toggles, Privacy **biometric / crash-report**, iCloud **sync**. With haptics ON, confirm the toggle taps buzz; with haptics OFF (Settings), confirm they DON'T (this was a real bug fixed).
**E. Section headers / field labels:** Settings section headers + the habit editor's **Habit name / Color / Reminder** labels — should be clean sentence-case, **not** tiny UPPERCASE.
**F. Toasts (`showEvolveToast`, replaced ~20 SnackBars):** save success (green) / error (red) on Personal Info, Privacy export/import, Auth (email sent / reset), Consent, AI Coach connection error, App Logs copy. Confirm a bottom banner fades in, sits ~2s, fades out, and floats above open sheets.
**G. Sheets (grabber + 17pt centered title + detents + grouped rows):** Statistics **Select Habit**, Goals **Choose Category** (+ its editor + delete), App Settings **Default view / Language / Accent**, **planning-type**, **Sort by**, **Year** picker (Pro-locks!), **change-password** (2-step: verify → new), Privacy **delete/reset** chooser, the **time/date** pickers (Notifications, Personal Info, habit Reminder), and the **daily check-in / day-details / habit / error / pro-features** sheet grabbers.
**H. Lists:** Settings cards + Profile rows — grouped-inset with hairline dividers (not floating bordered boxes).
**I. Spinner + color:** the amber Subscription/paywall spinner (now iOS-style); day-details renders correctly in **light** mode (was a theme bug).
**J. Pro-gating (log in NON-Pro):** accent-color **custom** lock, habit **5/5** limit CTA, Goals Pro-locks, **Year picker** locked years → Pro modal.

## 🖥️ macOS (the `desktop/` app — `flutter run -d macos --dart-define-from-file=.env`)

Full detail lives in **`desktop/TO_SIMO_DO.md`** ("Apple-style coherence pass — visual QA, 2026-07-11"). Summary, in light + dark:
1. **Toasts** (new bottom-center banner, replaced 9 SnackBars): Settings import **error** (red), gate/log-copy (neutral), Goals category create/archive/edit failures (red), Auth messages, AI Coach stream error — each fades in/out, floats above dialogs.
2. **Spinners** (`EvolveSpinner`, 10 sites): Statistics/Goals-stats/Auth/Consent/shell-sync/Settings loading + Save-password + create-habit/goal Add buttons — sizing matches the old footprints.
3. **Goals-stats Year picker**: now a centered Evolve **dialog** (was a mobile bottom-sheet) — All-years/year selection, accent check, and non-Pro lock → Pro dialog all still work.
4. **Biometric** lock/fingerprint glyphs → Lucide (were Material).
5. **De-capped labels** (matches the iOS de-cap): section/field/stat labels are now sentence-case — **except** the home **PROTOCOLLO** strip + Auth **OR** divider stay uppercase (same as iOS).