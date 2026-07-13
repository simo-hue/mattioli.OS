# 📱 iOS / Flutter Implementation Audit — `mobile/`

> **Purpose**: A deep, exhaustive audit of the `mobile/` (iOS) app to drive a future "make it professional" fix-it iteration. Every finding has a **location**, a **why it matters**, and a **recommended fix**. Work top-down by severity.
>
> **Audit date**: 2026-06-22 · **Scope**: `mobile/lib` (35,405 LOC Dart), `mobile/ios` native, `mobile/test`, `pubspec.yaml`, build config.
> **App**: "Evolve" (`mattioli_os`, bundle `com.simo.evolve`, v1.1.1+16). Flutter + Riverpod + Supabase + RevenueCat + Sentry, with an encrypted offline **Private Mode** (SQLCipher).

## How to read this

- **Severity**: `P0` blocker/correctness/compliance · `P1` high (ship-quality) · `P2` medium (professionalism) · `P3` low/polish.
- **[VERIFY]** = needs a runtime/device check to confirm impact (I read the code, but couldn't execute it).
- Each item has a stable ID (e.g. `SEC-1`) so the fix-it iteration can reference them in commits/PRs.
- The committed `analyze.txt` / `analysis.txt` are **stale** (they flag APIs the code has already migrated, e.g. `MaterialStateProperty` in `theme.dart`, and a `GoogleSignIn` error at line numbers that no longer match). **Do not trust them — re-run `flutter analyze` fresh.** See `TOOL-1`.

---

## 0. Executive summary

The app is **substantially more mature than a hobby project**: it has a clean Riverpod architecture, an offline-first cache, a genuinely well-engineered encrypted Private Mode (SQLCipher + secure-random key + iOS backup exclusion via a method channel), a solid theme system (`ThemeExtension`, light/dark, Google Fonts), and a competent RevenueCat integration (restore + customer center + paywall). Credit where due — see **§14 Positives**.

But several things stand between it and "professional, App-Store-grade":

1. **Localization is built on a 641-case runtime `translate()` shim keyed by Italian strings** that silently leaks Italian to every other language on any miss. This is the single biggest quality/maintainability problem (`I18N-1`). _(Superseded 2026-07-13: the `translate()` shim was removed — localization now uses the `slang` package with source locales in `lib/i18n/*.i18n.json` (ar/de/en/es/it) and ~1011 `t.` accessor call sites.)_
2. **Streak calculation is incorrect** for historical edits and uses confused negative-streak math (`DATA-1`).
3. **Optimistic writes never roll back on failure**, so the UI and DB silently diverge (`DATA-2`).
4. **Background notification actions (Done/Skip) almost certainly fail when the app is terminated** — the headline "act from the notification" feature (`NOTIF-1`).
5. **No app-level iOS Privacy Manifest** (`PrivacyInfo.xcprivacy`) — an App Store review requirement since 2024 (`IOS-1`).
6. **The OpenRouter API key is embedded in the app binary** — extractable, abusable, billable to you (`SEC-1`).
7. **Accessibility is effectively absent** — zero `Semantics`/`semanticLabel` in 35K LOC (`A11Y-1`).
8. **Testing is ~2% of the codebase** and the core logic (auth, sync, streaks, private DB) is untested (`TEST-1`).

Counts from the scan: **94** TODO/FIXME, **25** empty/swallowed catches, **113** `as` casts, **23** force-unwraps (`!`), **675** `l10n.translate(...)` call sites _(Superseded 2026-07-13: no `l10n.translate(...)` call sites remain; this metric referred to the removed shim — the only `.translate(` uses left in lib are `Transform.translate`)_, **0** `Semantics` widgets, **0** explicit Dynamic-Type handling.

---

## 1. Security & Privacy

### `SEC-1` — OpenRouter API key shipped inside the app binary · **P1**
**Where**: `lib/core/openrouter_service.dart:63` & `:139` (`'Authorization': 'Bearer ${OpenRouterConfig.apiKey}'`), `lib/core/openrouter_config.dart`.
**Why**: A bearer key compiled into a mobile app is trivially extractable from the IPA. Anyone can pull it and spend **your** OpenRouter credits, and you can't rotate it without an app update. This is the classic "LLM key in the client" anti-pattern. Note your **web** app deliberately avoids this (it uses local Ollama) and `BACKEND_ARCHITECTURE.md` even prescribes Edge Functions for AI — mobile diverges from your own design.
**Fix**: Proxy LLM calls through a Supabase Edge Function (authenticated by the user's JWT). The function holds the key server-side, enforces per-user rate limits, and lets you swap models/providers without shipping. Remove the key from the client entirely.

### `SEC-2` — `revenuecat_config.dart` is committed to git (with a real key); the other configs aren't · **P2**
**Where**: `lib/core/revenuecat_config.dart` is tracked (`git ls-files`) and contains `apiKey = 'appl_goBFEcuJEbZZeifRFXecOGHFmhN'`. By contrast `supabase_config.dart`, `openrouter_config.dart`, `sentry_config.dart` are correctly `.gitignore`d with `.example` templates.
**Why**: RevenueCat *public* SDK keys (`appl_`) are designed to live in the binary, so this isn't a true secret leak — but it's an **inconsistency** (no `.example`, not ignored) and it bakes the key into history. If the repo is public, it's avoidable noise.
**Fix**: Treat it like the others — add `revenuecat_config.dart.example`, gitignore the real file, inject via `--dart-define` or keep the public key but document that it's intentionally public. Pick one pattern and apply it to all four config files.

### `SEC-3` — Sentry `tracesSampleRate = 1.0` (100%) in production · **P2**
**Where**: `lib/core/sentry_config.dart` (`tracesSampleRate = 1.0`), applied in `lib/main.dart:184`.
**Why**: 100% performance-trace sampling is wasteful and will burn your Sentry quota fast at any real user volume.
**Fix**: Drop to `~0.1–0.2` for production; keep `1.0` only for a dev/staging environment. Also set `options.release`/`options.dist` so issues group by build.

### `SEC-4` — Error reporting silently dies after switching out of Private Mode at runtime · **P2**
**Where**: `lib/main.dart:180` only calls `SentryFlutter.init(...)` at startup when `!startsInPrivateMode`. `lib/providers/auth_provider.dart:314 returnToLoginFromPrivateMode()` re-initializes Supabase but **not** Sentry.
**Why**: A user who starts in Private Mode (Sentry never initialized) and later returns to a normal account gets **no crash reporting for the rest of that session** — `Sentry.captureException` becomes a silent no-op. You'll be blind to a class of post-transition errors.
**Fix**: Initialize Sentry lazily/idempotently when leaving Private Mode (respecting consent), or gate all `AppLogger` Sentry calls behind an "is Sentry initialized" check and (re)init on mode transition.

### `SEC-5` — Keychain items use `.first_unlock` (iCloud-migratable) rather than `.first_unlock_this_device` · **P2**
**Where**: `lib/core/secure_storage_utils.dart:9` — `IOSOptions(accessibility: KeychainAccessibility.first_unlock)`.
**Why**: `first_unlock` (without `_this_device`) lets the Supabase session token **and the Private Mode DB encryption key** be backed up / synced to other devices via iCloud Keychain. For an app whose selling point is "own your data / privacy," non-migratable storage of the local-DB key is the safer default.
**Fix**: Use `KeychainAccessibility.first_unlock_this_device` for the Private-Mode DB password and owner id at minimum (`private_mode_db_password_v1`, `private_mode_owner_id_v1`). Consider it for the auth session too.

### `SEC-6` — Duplicate-key recovery can wipe **all** secure storage (including the Private DB key) · **P2 [VERIFY]**
**Where**: `lib/core/secure_storage_utils.dart:62` (`storage.deleteAll()` when `clearAllOnDuplicateFailure`), reached from `lib/core/secure_local_storage.dart:44 persistSession(...)`.
**Why**: On a duplicate-keychain failure during session persistence, the fallback calls `deleteAll()`, which also deletes `private_mode_db_password_v1`. If that happens while Private Mode data exists, the SQLCipher DB becomes **permanently undecryptable → total local data loss**.
**Fix**: Never `deleteAll()`. Scope recovery to the single offending key (delete-then-rewrite just that key). If a nuclear option is truly needed, exclude the private-mode keys from it.

### `SEC-7` — Global error UI prints the raw exception to the user · **P2**
**Where**: `lib/main.dart:129` (`Text(details.exception.toString())`) in `ErrorWidget.builder`; `lib/main.dart:162` passes `error.toString()` as `details` to `ErrorModal`.
**Why**: Showing raw exception text (and stack-ish detail) to end users looks unfinished and can leak internal identifiers/SQL/URLs. ErrorModals across the data layer also surface `e.toString()` (`goal_provider.dart:159,208,239,514`).
**Fix**: Show a friendly, localized message; tuck raw details behind a "developer details" expander that only renders in debug (`kDebugMode`), and always send the real error to Sentry.

### `SEC-8` — `debugPrint` of raw error objects runs in release and may log PII · **P3**
**Where**: `lib/core/app_logger.dart:37,63,85` always `debugPrint(...)`; `lib/providers/auth_provider.dart:118 debugPrint('[Auth] Event: $event')`; many `debugPrint` in `notifications.dart`.
**Why**: `debugPrint` is **not** stripped in release. The *message* is sanitized via `PrivacyUtils`, but the appended raw `$error` is not, so Supabase errors containing emails/ids can hit the device console/log stream.
**Fix**: Guard console logging with `if (kDebugMode)`, and sanitize or omit the raw error in release.

---

## 2. iOS Native & App Store Compliance

### `IOS-1` — Missing app-level Privacy Manifest (`PrivacyInfo.xcprivacy`) · **P1**
**Where**: `ios/Runner/` has no `PrivacyInfo.xcprivacy` (only the bundled Pods ship their own).
**Why**: Since 2024 Apple requires the **app** to declare "required reason" API usage and data-collection types. You use `shared_preferences` (UserDefaults API), file timestamp APIs (Private DB backup-exclusion), `image_picker`, Sentry, RevenueCat — several trigger required-reason declarations. Missing/incorrect manifests cause **App Store review rejection** (ITMS-91053).
**Fix**: Add `ios/Runner/PrivacyInfo.xcprivacy` declaring accessed-API reasons (e.g. `NSPrivacyAccessedAPICategoryUserDefaults` → `CA92.1`, file-timestamp → `C617.1`) and your data-collection types (identifiers, purchases, diagnostics) to match the App Store privacy nutrition labels.

### `IOS-2` — Deployment target is iOS 13.0 · **P3**
**Where**: `ios/Podfile` (`platform :ios, '13.0'`), `ios/Runner.xcodeproj/project.pbxproj` (`IPHONEOS_DEPLOYMENT_TARGET = 13.0`).
**Why**: iOS 13 (2019) is a very low floor for a 2026 release; it constrains APIs and forces compatibility shims, and several deps are happier at 14/15. Most of your install base is 16+.
**Fix**: Bump to iOS 14 or 15 (confirm against `pod install` and plugin minimums) unless you have data showing meaningful iOS-13 usage.

### `IOS-3` — Deprecated `CODE_SIGN_IDENTITY = "iPhone Developer"` · **P3**
**Where**: `project.pbxproj:502,630,689`.
**Why**: "iPhone Developer" is the legacy identity name; modern Xcode uses "Apple Development". Harmless today but flags as outdated.
**Fix**: Set to "Apple Development" (or rely on automatic signing).

### `IOS-4` — Portrait-only + `UIRequiresFullScreen` disables iPad multitasking · **P3 (product decision)**
**Where**: `ios/Runner/Info.plist:54,89,91` (`LSRequiresIPhoneOS`, `UIRequiresFullScreen`, only `UIInterfaceOrientationPortrait`); reinforced by `SystemChrome.setPreferredOrientations([portraitUp])` in `lib/main.dart:32`.
**Why**: Fine as an intentional "vertical lock," but it means no Split View/Slide Over on iPad and no landscape anywhere. If iPad is a target, reviewers and users notice.
**Fix**: Confirm this is intended. If iPad matters, support more orientations and drop `UIRequiresFullScreen`.

### `IOS-5` — `LSApplicationQueriesSchemes` only lists `https` · **P3 [VERIFY]**
**Where**: `ios/Runner/Info.plist:50`.
**Why**: With `url_launcher` you typically also need `mailto`/`tel` (or specific app schemes) declared to *query* them via `canLaunchUrl`. `https` alone is unusual; `canLaunchUrl` for mail/tel may return false.
**Fix**: Verify which schemes `url_launcher` actually probes and declare them; otherwise remove the stray entry.

---

## 3. Build, Tooling & Dependencies

### `TOOL-1` — Stale, committed analyzer outputs are misleading · **P2**
**Where**: `mobile/analyze.txt`, `mobile/analysis.txt` (tracked). `analyze.txt` reports a `GoogleSignIn` **compile error** at `auth_provider.dart:186/191` and `MaterialStateProperty` deprecations in `theme.dart` — but the current code has refactored past both (Google Sign-In now at `:331`, theme uses `WidgetStateProperty`).
**Why**: A committed file that says "30 issues / compile error" but doesn't match HEAD will mislead the next engineer (and any reviewer).
**Fix**: Delete both from the repo; never commit analyzer dumps. Re-run `flutter analyze` fresh and fix what's actually there. (See also `HYG-1`.)

### `TOOL-2` — `google_sign_in` pinned to the v6 API; v7 is a breaking rewrite · **P2 [VERIFY]**
**Where**: `pubspec.yaml:53` (`google_sign_in: ^6.2.1`); usage `lib/providers/auth_provider.dart:331-343` (`GoogleSignIn(clientId:, serverClientId:)`, `.signIn()`, `googleUser.authentication` → `accessToken`/`idToken`).
**Why**: The stale `analyze.txt` shows a prior failed attempt to move to v7 (where `GoogleSignIn()` and `.signIn()` were removed in favor of `GoogleSignIn.instance` + `authenticate()`). You're stuck on the old major, which `analysis.txt` confirms (`6.3.0`, with `7.2.0` available). This is latent breakage waiting for the next `pub upgrade`.
**Fix**: Decide deliberately — stay pinned with a comment explaining why, or migrate to v7 and the new auth flow. Don't leave it ambiguous.

### `TOOL-3` — `flutter_markdown` is discontinued · **P2**
**Where**: `pubspec.yaml:62` (`flutter_markdown: ^0.7.7+1`). Used by the AI chat rendering.
**Why**: The Flutter team retired `flutter_markdown`; it won't get fixes. AI Coach output rendering depends on it.
**Fix**: Migrate to a maintained successor (e.g. `markdown_widget` or the community `flutter_markdown_plus`).

### `TOOL-4` — 24 outdated dependencies; some majors behind · **P3**
**Where**: `analysis.txt` lists 24; notably `fl_chart 0.69 → 1.2` (major), `sign_in_with_apple 7 → 8`, `analyzer`, `intl`, etc.
**Why**: Charts and auth are core; drifting majors compound upgrade pain and miss bug/security fixes.
**Fix**: Schedule a dependency-bump pass; do `fl_chart` and `sign_in_with_apple` deliberately (test charts + Apple login after).

### `TOOL-5` — Only the default `flutter_lints`; no project lint hardening · **P2**
**Where**: `analysis_options.yaml` just `include: package:flutter_lints/flutter.yaml`, no extra rules, no `errors:` escalation.
**Why**: The default set is permissive — it won't catch `unawaited_futures`, missing `await`, `always_declare_return_types`, `prefer_const_constructors`, `use_build_context_synchronously` strictness, etc. Several findings here (swallowed catches, context-across-async) would be lint-surfaced.
**Fix**: Adopt `flutter_lints` + a stricter overlay (or `very_good_analysis`), escalate a few to `error` (e.g. `use_build_context_synchronously`), and wire `flutter analyze` into CI as a gate.

### `TOOL-6` — Undocumented `dependency_overrides` · **P3**
**Where**: `pubspec.yaml:82` (`path_provider_foundation: 2.5.1`).
**Why**: A pinned override is usually a bug workaround; with no comment, nobody knows if it's still needed.
**Fix**: Add a comment with the reason + a link, and re-test removing it on the next upgrade.

### `TOOL-7` — Placeholder project description · **P3**
_(Superseded 2026-07-13: resolved — `pubspec.yaml:2` now has a real description: "Evolve — build better habits and reach your goals, with a privacy-first encrypted offline mode.")_
**Where**: `pubspec.yaml:2` (`description: "A new Flutter project."`).
**Fix**: Replace with a real description (cosmetic but it's the kind of thing reviewers notice).

---

## 4. Localization & Internationalization

### `I18N-1` — The whole UI is localized through a 641-case `translate()` shim keyed by Italian strings · **P1**
_(Superseded 2026-07-13: this entire finding describes a removed architecture — `lib/core/localization.dart` no longer exists, the `translate()` switch shim is gone, and the app now uses `slang`-generated getters. The coexisting gen_l10n + shim problem no longer applies.)_
**Where**: `lib/core/localization.dart` (1,300 LOC; `String translate(String key) { switch(key) {...} return key; }`), called **675** times across `lib/ui`. Default branch `return key;` (line ~end of switch).
**Why**: This is the dominant maintainability problem.
- Italian literals are the de-facto source keys scattered across every screen (`context.l10n.translate('Salva')`).
- **Any** string not in the 641-case switch **falls back to raw Italian for all languages** (en/de/es/ar users see Italian). There's no compile-time safety — a typo silently ships Italian.
- You're maintaining the translation **twice**: an ARB entry *and* a switch case *and* the literal at the call site. The two systems (proper `gen_l10n` getters like `l10n.notificationActionDone`, and this shim) coexist inconsistently.
**Fix**: Migrate call sites to real ARB keys (`context.l10n.salva`) and delete `translate()` + the `AppLocalizationsCompatibility` extension. This can be mechanical (the switch already maps each Italian string → its getter, so it's a find/replace table). Add an ARB lint/CI check for missing keys.

### `I18N-2` — Auth error messages are hardcoded Italian · **P2**
_(Superseded 2026-07-13: `_mapAuthError` (now at `auth_provider.dart:522`) returns localized slang keys — `t.auth.errors.invalidCredentials`, `.emailNotConfirmed`, `.accountExists`, `.passwordMinSix`, `.rateLimited`, `.signupsDisabled`, `.generic` — not hardcoded Italian.)_
**Where**: `lib/providers/auth_provider.dart:521 _mapAuthError(...)` returns Italian strings; also `'Errore di rete. Riprova.'` at `:210/:251/:275/:485/:513`, `'Accesso non riuscito...'` `:195`, `'Impossibile avviare la modalità privata.'` `:309`.
**Why**: Login/signup/reset is the first screen a non-Italian user hits, and the errors are Italian-only.
**Fix**: Route these through ARB keys; map Supabase error codes → localized messages.

### `I18N-3` — Global error modal & `ErrorWidget` are Italian-only · **P2**
_(Superseded 2026-07-13: none of these Italian literals ('Ops! Qualcosa è andato storto.', 'Si è verificato un errore', long Italian body) exist in `lib/main.dart` anymore — they were removed in the slang migration.)_
**Where**: `lib/main.dart:124` (`'Ops! Qualcosa è andato storto.'`), `:159` (`'Si è verificato un errore'`), `:161` (long Italian body).
**Fix**: Localize (and see `SEC-7` for hiding raw details).

### `I18N-4` — Hardcoded Italian fallbacks in notifications · **P3**
**Where**: `lib/core/notifications.dart:123` (`'Abitudine'` snooze fallback title). Brand prefix `'Evolve • ...'` hardcoded in 19 spots (acceptable as a brand, but the title fragments around it are localized inconsistently).
**Fix**: Localize the fallback; keep the brand token as a constant.

---

## 5. Accessibility

### `A11Y-1` — No accessibility semantics anywhere · **P1**
**Where**: **0** `Semantics`/`semanticLabel`/`excludeSemantics` across `lib` (grep). Icon-only `IconButton`s, the custom-painted **HexHeatmap/yearly grid**, `fl_chart` charts, and color-coded status cells have no screen-reader labels.
**Why**: VoiceOver users get unlabeled/ambiguous controls and completely opaque data visualizations. This is both a professionalism gap and, for some markets, a legal/accessibility-guideline concern. Apple also increasingly highlights accessibility in featuring.
**Fix**: Add `Semantics(label: ...)` to icon-only buttons and status toggles; provide a textual summary/`semanticsLabel` for charts and the heatmap (e.g. "Monday: 80% complete"); audit with VoiceOver + the Accessibility Inspector.

### `A11Y-2` — No Dynamic Type / large-text consideration · **P2 [VERIFY]**
**Where**: **0** references to `textScaler`/`TextScaler`/`MediaQuery.textScalerOf`; many fixed `fontSize:` in `theme.dart` and inline.
**Why**: With fixed sizes and dense custom layouts, large accessibility text sizes likely overflow/clip. Worth testing at 200% text.
**Fix**: Test at large Dynamic Type; ensure layouts wrap/scroll; avoid clamping text scale unless deliberate.

### `A11Y-3` — Light-mode muted text contrast is borderline · **P3 [VERIFY]**
**Where**: `lib/core/theme.dart` — `lightMutedForeground = #64748B` (Slate 500) on `#FFFFFF`/`#F9FAFB` for `bodyMedium/Small/labelSmall`.
**Why**: Slate-500 on white is ~4.5:1 only at larger sizes; at 10–13px it can fail WCAG AA.
**Fix**: Darken muted text one step (Slate 600) for small sizes, or verify with a contrast checker.

---

## 6. Data Correctness & Business Logic

### `DATA-1` — Streak calculation is incorrect for historical edits and uses confused negative math · **P1**
**Where**: `lib/providers/goal_provider.dart:415-453` (`cycleStatus`).
**Why**:
- It fetches the streak basis via `order('date', descending).limit(1)` — the **chronologically latest** log overall, not the day *before* the date being toggled. Editing a **past** day computes `prevStreak` from a future log; the `date.difference(lastDate).inDays == 1` check then almost always resets to 0.
- Negative-streak logic (`newStreak = prevStreak > 0 ? -1 : prevStreak - 1`, and `prevStreak >= 0 ? prevStreak + 1 : 1`) is hard to reason about and produces inconsistent values.
- Private mode passes `streak` through but the same conceptual model is shaky (`private_local_database.dart:setHabitLog`).
**Why it matters**: Streaks are a core motivational feature; wrong streaks erode trust in the whole app.
**Fix**: Compute streaks deterministically from the full ordered log history for that goal (respecting `frequency_days`), ideally in one place (a pure function) shared by cloud + private, rather than incrementally from "the last row." Add unit tests (`TEST-1`).

### `DATA-2` — Optimistic writes never roll back on failure → UI/DB divergence · **P1**
**Where**: `lib/providers/goal_provider.dart` — `addHabit` (`:104`), `updateHabit` (`:165`), `deleteHabit` (`:214`), `cycleStatus` (`:392`). Each sets `state`/cache first, then on Supabase error only shows an `ErrorModal` — no revert.
**Why**: If the network write fails, the UI keeps the change and the secure cache persists it, but the DB doesn't have it. `deleteHabit` is worst: the habit vanishes locally but survives server-side, so it **reappears on next sync**; a failed `addHabit` leaves a ghost goal with a temp id in cache. State silently drifts from the backend.
**Fix**: Snapshot prior state, apply optimistically, and **revert on error** (the web app's `useGoals` does exactly this with `onError` rollback — mirror that). Consider a small mutation queue for offline replay (the desktop app already does this).

### `DATA-3` — App calls many Supabase RPCs/views that aren't in the committed migrations · **P1 [VERIFY]**
**Where**: `lib/providers/goal_provider.dart` calls `get_habit_analytics` (`:559`), `get_global_trend` (`:609`), `get_critical_habits` (`:628`), `get_best_habits` (`:649`), `get_habit_performance_by_day` (`:672`), `get_habit_alerts` (`:690`), `get_habit_yearly_grid` (`:714`), `get_habit_correlations` (`:738`), and `.from('habit_stats')` (`:542`). The repo's `migrations/` only defines `get_all_habit_correlations`, `get_global_critical_day`, `get_macro_goals_stats`, `check_and_fail_expired_goals`.
**Why**: The live database depends on objects that aren't version-controlled. A fresh/staging Supabase project built from `migrations/` + `schema.sql` would **break statistics** in cloud mode. This is schema drift / undocumented backend coupling.
**Fix**: Export every RPC/view the app calls into `migrations/`; add a test or checklist that the app's RPC names all exist in source. Treat the DB as code.

### `DATA-4` — Private-mode statistics are partially stubbed (parity gap vs cloud) · **P2**
**Where**: `lib/core/private_local_database.dart` — `habitAnalytics` returns `avg_recovery_days: 0` (`:732`), `habitAlerts` returns `broken_streaks: []` (`:858`), `macroGoalsStats` returns empty `monthly_trend`/`yearly_comparison` (`:961`).
**Why**: Statistics screens show zeros/empties in Private Mode that are populated in cloud mode — inconsistent product experience for the privacy-focused users you're courting.
**Fix**: Implement the missing aggregations in Dart, or clearly label them as "not available offline" in the UI rather than showing misleading zeros.

### `DATA-5` — Private macro-goal `color` dropped; `week_number` CHECK differs from cloud · **P2**
**Where**: `lib/core/private_local_database.dart` — `upsertMacroGoal` (`:424`) omits `color` from the insert map (and `_macroGoalFromRow` `:1001` doesn't read it), though the table has a `color` column. The `long_term_goals` CHECK is `week_number BETWEEN 1 AND 6` (`:214`) whereas `schema.sql` allows 1–53.
**Why**: Macro-goal colors silently vanish in Private Mode; and a weekly goal with `week_number > 6` would hit a `CHECK` violation locally that wouldn't occur in cloud — a latent insert crash + a data-model inconsistency between the two backends.
**Fix**: Persist/read `color`; reconcile `week_number` semantics (decide week-of-month vs ISO week and make both backends agree).

### `DATA-6` — Full-table log fetch with no pagination or date window · **P2**
**Where**: `lib/providers/goal_provider.dart:367` (`select('id, goal_id, date, status').eq('user_id', ...)` — all logs). The code comment even admits "potremmo scaricare solo gli ultimi X giorni."
**Why**: Every login/sync pulls the user's entire log history into memory. For multi-year users this grows unbounded and slows startup.
**Fix**: Window the sync (e.g. last N months for the dashboard) and lazy-load older ranges for the yearly heatmap, or paginate. (The web app has the same smell — consider fixing the contract once.)

---

## 7. Error Handling & Resilience

### `ERR-1` — `int.parse` on stored time strings without validation · **P2**
**Where**: `lib/core/notifications.dart:246-247`, `:277-278`, `:308-309` (`int.parse(parts[0])`, `int.parse(parts[1])` on `'HH:mm'`).
**Why**: A malformed/empty stored reminder time (corrupt prefs, partial migration, "9:0", "") throws and aborts scheduling unhandled.
**Fix**: Parse defensively (`int.tryParse`, validate ranges, fall back to defaults), or store times as structured ints.

### `ERR-2` — `ensureSupabaseInitialized` uses an exception as control flow · **P3**
**Where**: `lib/providers/auth_provider.dart:21-32` — `try { Supabase.instance.client; } catch(_) { initialize... }`.
**Why**: Relying on "accessing the client throws if not initialized" is fragile (behavior could change across SDK versions) and noisy.
**Fix**: Track an explicit `bool _supabaseInitialized` (or a Completer) and branch on it.

### `ERR-3` — Empty/swallowed catches · **P3**
**Where**: 25 total; e.g. `lib/core/secure_local_storage.dart:21,38,60,76` (`catch (_) {}`), `lib/providers/shared_prefs_provider.dart:30`, `lib/ui/screens/subscription_screen.dart:610`.
**Why**: Silent failures hide real problems (especially around secure storage and purchases).
**Fix**: At minimum log via `AppLogger`; only truly ignore where you can justify it in a comment.

---

## 8. Notifications

### `NOTIF-1` — Background notification actions (Done/Skip) almost certainly fail when the app is terminated · **P1 [VERIFY]**
**Where**: `lib/core/notifications.dart:404 notificationTapBackground` (the `@pragma('vm:entry-point')` isolate) → `_onNotificationResponse` → `_markHabitAsDone:129` / `_skipHabit:199`. In that background isolate, Supabase is re-initialized at `:430` **without** `SecureLocalStorage`, so it has no persisted session → `Supabase.instance.client.auth.currentUser` is `null` → both handlers hit `if (user == null) return;` and silently do nothing.
**Why**: "Mark a habit done straight from the notification" is a headline convenience feature; in the terminated-app case (the most common one for a reminder) it no-ops in cloud mode. Private mode may work (it writes to the local DB), making the bug inconsistent and hard to spot.
**Fix**: Initialize Supabase in the background isolate **with** `SecureLocalStorage` so the session is available; verify on a physical device with the app terminated. Add a fallback that queues the action and replays on next foreground.

### `NOTIF-2` — iOS notification actions aren't marked foreground; DB writes from a background action are unreliable · **P2 [VERIFY]**
**Where**: `lib/core/notifications.dart:62-73` — `DarwinNotificationAction.plain('action_done'/...)` with no `.foreground` option.
**Why**: On iOS, a non-foreground action gives the app very little background execution time; an async network write may not complete. Combined with `NOTIF-1`, the Done/Skip path is doubly fragile.
**Fix**: Either mark the action `foreground` (bring the app forward to complete the write) or perform the write through a reliable background mechanism; test on device.

### `NOTIF-3` — Notification permission requested at app init (poor iOS timing) · **P2**
**Where**: `lib/core/notifications.dart:81-87` — `DarwinInitializationSettings(requestAlert/Badge/SoundPermission: true)` runs inside `init()`, called from `main.dart` startup.
**Why**: iOS strongly prefers a **contextual** permission prompt (after the user opts into reminders). Asking at first launch lowers grant rates and reads as pushy; there's already a separate `requestPermissions()` you could call at the right moment.
**Fix**: Initialize with the request flags `false`, and call `requestPermissions()` when the user enables a reminder (with a pre-permission explainer).

### `NOTIF-4` — iOS 64 pending-notification cap not handled · **P3 [VERIFY]**
**Where**: per-habit scheduling in `scheduleHabitReminder` (`:301`) plus daily/evening (`:244`,`:275`).
**Why**: iOS keeps only 64 pending local notifications; a power user with many habit reminders could silently lose some.
**Fix**: Budget/limit scheduled notifications; prefer repeating schedules over many one-offs; surface a cap in the UI.

---

## 9. Subscriptions / IAP

### `SUB-1` — "Generic entitlement" fallback grants Pro for *any* active entitlement · **P3**
**Where**: `lib/core/subscription_service.dart:325-335 evaluateProAccess` (final loop, `usedGenericEntitlementFallback: true`).
**Why**: Deliberately fail-open to avoid blocking paying users — reasonable — but if the RevenueCat project ever has an unrelated entitlement, users could get Pro unexpectedly. It's logged, not alerted.
**Fix**: Keep the fallback but consider gating it to a known set, and turn the warning into a Sentry alert so you notice misconfig.

### `SUB-2` — Global mutable static state + never-removed CustomerInfo listener · **P2**
**Where**: `lib/core/subscription_service.dart:53-55` (`static _configuredUserUuid/_configurationFuture/_customerInfoListenerRegistered`) and `:359 addCustomerInfoUpdateListener` with no removal.
**Why**: Statics survive hot reload, user switches, and tests; the listener is added once and never removed (minor leak, and it captures `_ref`). User-account switching (logout→login as someone else) can leave stale config.
**Fix**: Move state into the provider instance; remove the listener on dispose; reset config on user change.

*(Positive: restore-purchases, customer center, and conditional paywall are all implemented — good Apple-compliance posture. Keep `restorePurchases` prominent in the paywall UI.)*

---

## 10. AI / OpenRouter

*(Primary issue is `SEC-1` — key in client.)*

### `AI-1` — Non-streaming `generateResponse` has no request timeout · **P3**
**Where**: `lib/core/openrouter_service.dart:60 http.post(...)` (no `.timeout`), vs the streaming path which does timeout.
**Fix**: Add a `.timeout(...)` consistent with the streaming path.

### `AI-2` — Connectivity precheck via `InternetAddress.lookup('openrouter.ai')` is fragile · **P3**
**Where**: `lib/core/openrouter_service.dart:104`.
**Why**: DNS lookups can be blocked on some networks/VPNs and add latency; a failed lookup yields a misleading "no internet" message.
**Fix**: Drop the precheck and rely on the request timeout + error handling, or use `connectivity_plus`.

### `AI-3` — Unguarded nested JSON access · **P3**
**Where**: `lib/core/openrouter_service.dart:74` (`data['choices'][0]['message']['content']`) and `:181` (`['choices'][0]['delta']['content']`).
**Why**: An error-shaped or empty response throws; it's caught, but the user-facing message is generic.
**Fix**: Null-check the path and surface provider error messages where available.

---

## 11. Performance

### `PERF-1` — Full-table syncs · **P2** — see `DATA-6`.

### `PERF-2` — O(n²) correlation computation in Private Mode · **P3**
**Where**: `lib/core/private_local_database.dart:916 allHabitCorrelations` loops every goal × every other goal × every log day.
**Why**: For many goals/long histories this gets slow on-device.
**Fix**: Compute co-occurrence in a single pass over logs; cache results.

### `PERF-3` — Very large widget files (rebuild scope + maintainability) · **P2/P3**
**Where**: `macro_goals_stats_view.dart` (2,227), `dashboard_screen.dart` (1,597), `subscription_screen.dart` (1,459), `info_tab_widget.dart` (1,396), `global_alerts_tab_widget.dart` (1,321), `app_settings_screen.dart` (1,309).
**Why**: Monolithic `build` methods rebuild large trees on small state changes and are hard to test/maintain.
**Fix**: Extract sub-widgets (`const` where possible), use `select()` to scope Riverpod rebuilds, and split files by responsibility.

---

## 12. Testing

### `TEST-1` — ~2% test coverage; core logic untested; `widget_test` is a no-op · **P1**
**Where**: `test/` = 699 LOC total vs 35,405 LOC app. `test/widget_test.dart` only asserts `const EvolveApp() is EvolveApp` — it never pumps the widget. Existing tests cover tutorials, time formatting, mood-chart windowing, macro-goal calendar, subscription service, user profile. **No** tests for: auth flows, `goal_provider` sync/optimistic logic, **streak math** (`DATA-1`), the Private DB, notifications, OpenRouter parsing.
**Why**: The buggiest, highest-risk code (streaks, sync, mode-switching) has no safety net, so the fix-it iteration can't refactor confidently.
**Fix**: Add unit tests for the streak function and `goal_provider` (mock Supabase), Private DB CRUD/round-trip tests, and a real `widget_test` that pumps `EvolveApp` with an overridden `ProviderScope`. Gate CI on `flutter test` + `flutter analyze`.

---

## 13. Repo Hygiene & Code Cleanliness

### `HYG-1` — Committed junk/scratch files · **P3**
**Where**: `mobile/analyze.txt`, `mobile/analysis.txt`, `mobile/app_info.txt`, `mobile/scratch/` (stray `AndroidManifest.xml`, `build.gradle.kts`), `mobile/apple_response/` (screenshots + `text.txt`).
**Fix**: Remove them (or move docs to `docs/`); they're noise in a "professional" repo. (`analyze.txt`/`analysis.txt` are also actively misleading — `TOOL-1`.)

### `HYG-2` — Lint-flagged dead code / unused imports / deprecated members · **P3**
**Where**: from a fresh analyze you'll see unused imports (`goal_provider.dart:4`, `macro_goals_provider.dart:4`, `view_tab_bar.dart`, `yearly_view_widget.dart`, `global_alerts_tab_widget.dart`), unused locals (`personal_info_screen.dart`, `habit_calendar_widget.dart:381`, several `primaryColor`), `Color.value` deprecations (`goal.dart`, `settings_provider.dart`), and `curly_braces_in_flow_control_structures` (`macro_goals_provider.dart:207`). (Line numbers per the stale dumps — re-verify.)
**Fix**: `dart fix --apply`, then clean the rest by hand; enforce via `TOOL-5`.

### `HYG-3` — 94 TODO/FIXME markers · **P3**
**Where**: across `lib`.
**Fix**: Triage into issues; delete stale ones. A professional codebase doesn't carry 94 floating TODOs.

---

## 14. UX Professionalism

### `UX-1` — No "Follow System" theme option · **P2**
**Where**: `lib/main.dart:272` — `themeMode: settings.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light` (no `ThemeMode.system`). The Private DB schema even allows `theme_mode IN ('dark','light','system')`, so the data model supports it but the app doesn't wire it.
**Why**: Respecting the OS appearance is a baseline expectation on iOS.
**Fix**: Add a System option and map it to `ThemeMode.system`.

### `UX-2` — Raw error text in user-facing surfaces · **P2** — see `SEC-7`.

### `UX-3` — Two overlapping "privacy" concepts with confusing names · **P3**
**Where**: `PrivacyContext`/`privacyModeProvider` (`goal_provider.dart:809`) = on-screen blur/redact; `AppDataMode.private` (`data_mode.dart`) = the encrypted local-only backend. Both read as "private mode."
**Why**: Future maintainers (and you) will conflate them.
**Fix**: Rename the blur feature (e.g. "Discreet/Blur Mode") to disambiguate from the local-data "Private Mode."

---

## Appendix A — Suggested fix order (by leverage)

1. **Compliance & correctness first**: `IOS-1` (privacy manifest), `DATA-1` (streaks), `DATA-2` (rollback), `NOTIF-1` (bg actions), `DATA-3` (RPCs into migrations).
2. **Security**: `SEC-1` (proxy the LLM key), `SEC-6` (no `deleteAll`), `SEC-5` (`_this_device`), `SEC-4` (Sentry re-init).
3. **The big maintainability win**: `I18N-1` (kill the `translate()` shim) — unblocks `I18N-2/3/4`.
4. **Accessibility**: `A11Y-1` then `A11Y-2`.
5. **Safety net**: `TEST-1` + `TOOL-5` (lints) + `TOOL-1`/`HYG-1` (clean the repo) — do this *alongside* the above so refactors are guarded.
6. **Polish**: `UX-1`, `TOOL-2/3/4`, `PERF-*`, remaining `HYG-*`.

## Appendix B — Positives (keep / don't regress)

- **Private Mode engineering**: SQLCipher with a 48-byte secure-random key in the Keychain, FK constraints, sensible indexes, iOS backup-exclusion via the `evolve/private_storage` method channel, and `is_pro`-forced local entitlement. Genuinely solid.
- **Theme system**: `ThemeExtension` with full light/dark tokens, Google Fonts Inter, already migrated to `WidgetStateProperty`/`withValues` (so the analyzer dumps are stale, not the code).
- **Offline-first** secure cache with SharedPreferences→Keychain migration at startup.
- **RevenueCat**: restore purchases, customer center, conditional paywall, fail-open entitlement check — good store-compliance instincts.
- **Centralized `AppLogger`** with PII sanitization and a Private-Mode "external reporting disabled" kill-switch.
- **GoRouter** auth/consent redirect flow driven by a `refreshListenable` — reactive and clean.

---

*Generated by a static read-through of the `mobile/` tree. Items tagged **[VERIFY]** need a device/runtime check to confirm severity before fixing.*
