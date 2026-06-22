# 🌍 Localization Migration Plan — `mobile/` (Evolve)

> Replaces the legacy runtime `translate()` shim with a professional, type-safe **slang** localization layer. This doc is the spec; work it phase-by-phase, keeping `main` shippable at every step. Pairs with `IOS_AUDIT.md` finding **`I18N-1`**.

## Decisions (resolved via design review)

| # | Decision | Choice |
|---|---|---|
| 1 | Framework | **slang** (type-safe, nested, context-free `t`) |
| 2 | Key architecture | **Semantic, nested, English-named** (`t.settings.appearance.darkMode`) |
| 3 | Source / fallback locale | **English** (`base_locale: en`, `fallback_strategy: base_locale`) |
| 4 | Locale scope | Ship **EN / IT / ES / DE** now; **defer Arabic + the RTL pass** (data kept) |
| 5 | Plurals | **Surgical** — first-class capability + convert only genuine count-*sentences* |
| 6 | Workflow | **In-repo slang JSON**; English authored; **AI-translate** IT/ES/DE with review |
| 7 | Existing copy | **Preserve + fill** — never overwrite the original human Italian; AI only for new/missing |
| 8 | Mechanics | **Phased-by-feature**, scripted from the crosswalk; `main` always green |
| 9 | Safety / formatting / access | `base_locale` fallback + `slang analyze` CI gate + pseudolocale · locale-aware `NumberFormat`/`DateFormat` · global `t` + `TranslationProvider` bridged to `settings.language` |

## Current state (measured)

- **771 keys** per locale (5 locales: en/it/es/de/ar), fully populated; Arabic is real Arabic script.
- Legacy `translate()` shim: **641** Italian-string `case`s in `lib/core/localization.dart`, used at **675** call sites across **38** UI files.
- The shim returns the raw key (Italian) on a miss → **silent Italian leak** to every other language. This is the core defect we're removing.
- Underlying system today is Flutter `gen_l10n` (`l10n.yaml` → `AppLocalizations`); slang replaces it.

## Architecture (target)

- One nested JSON tree per locale: `lib/i18n/<locale>.i18n.json`. English is the base; gaps fall back to English.
- Access via the global `t` (e.g. `t.settings.appearance.darkMode`), no `BuildContext` required. `TranslationProvider` wraps the app for locale-change rebuilds.
- Locale is driven by the existing `settings.language` preference, bridged to slang's `LocaleSettings`.

---

## Phase 0 — Bootstrap ✅ (landed; purely additive, `main` stays green)

The new system is installed **alongside** the untouched old one — no call sites changed, no behavior change yet.

Delivered in this phase:
- `tool/arb_to_slang.py` — the **crosswalk engine**. Lossless ARB → slang-JSON converter (drops `@meta`, keeps `{placeholders}`, preserves order, verifies cross-locale key parity). Re-runnable and deterministic.
- `lib/i18n/{en,it,es,de}.i18n.json` — generated, **771 keys each, parity verified, all parse**. (Flat 1:1 names for now; semantic nesting happens per-feature below.) **Arabic is excluded from slang input** (deferred) — its source is preserved at `lib/l10n/app_ar.arb`.
- `slang.yaml` — slang config (English base, `base_locale` fallback, brace interpolation, Flutter integration, global `t`).
- `pubspec.yaml` — added `slang`, `slang_flutter`, `slang_build_runner` (⚠️ versions need `flutter pub get` to resolve — see `TO_SIMO_DO.md`).
- `.gitignore` — ignores the generated `lib/i18n/translations.g.dart`.

### ▶️ Immediate next step (requires the Flutter SDK — can't run in this env)
```bash
cd mobile
flutter pub get          # resolves slang versions; if it errors:
                         # flutter pub add slang slang_flutter dev:slang_build_runner
dart run slang           # generates lib/i18n/translations.g.dart  → `t` becomes available
flutter analyze          # must stay green
```

### Integration micro-step ✅ done (slang wired in; old system still serves every screen)
Implemented in `lib/main.dart` (plus `app_settings_screen.dart` + the converter for the Arabic defer):

1. Imported `i18n/translations.g.dart`; wrapped the app in `TranslationProvider` (inside the existing `ProviderScope`).
2. **Locale source of truth = slang**: `MaterialApp.locale = TranslationProvider.of(context).flutterLocale`, `supportedLocales = AppLocaleUtils.supportedLocales`. Initial locale is set from `pref_language` before the first frame (in `main()`), and a `ref.listen` on `settings.language` calls `LocaleSettings.setLocale(...)` for private-mode async loads and runtime changes. `_appLocaleFor()` maps the app preference → `AppLocale` ("system" → device locale; unsupported/legacy `ar` → base `en`).
3. **Defer Arabic** ✅: excluded from slang input (`tool/arb_to_slang.py` `LOCALES`) and removed from the language picker, so `AppLocaleUtils.supportedLocales` is the 4 LTR locales. Source preserved at `lib/l10n/app_ar.arb`.
4. Kept the `flutter_localizations` delegates (`AppLocalizations.localizationsDelegates`) for built-in widget strings during the migration.

> Net effect: `t.*` works app-wide; every existing screen still renders via the old `context.l10n` system. The only user-visible change is that Arabic is no longer offered (it was already shipping with broken RTL). **Verify with `dart run slang && flutter analyze`.**

---

## Phases 1..N — Migrate one namespace per PR (the repeatable recipe)

Suggested order (smallest/safest first): `common` → `settings` → `auth` → `consent` → `privacy` → `notifications` → `habits` → `macroGoals` → `mood` → `stats` → `ai` → `subscription`.

For each feature namespace — migrate only **screen-exclusive** keys; keys shared with other screens go to `common` and are migrated in that phase:
1. **Restructure JSON** — move that feature's exclusive keys in all 4 `*.i18n.json` files from the flat root into the nested namespace, renaming to semantic English (`modalitaScura` → `settings: { appearance: { darkMode } }`). Scripted from an `oldKey → newPath` map (built from the shim `case`s + `@key.description`) — never hand-typed.
2. **Rewrite call sites** — replace that screen's `context.l10n.translate('…')` **and** `context.l10n.<oldGetter>` with `context.t.<newPath>` (scripted find/replace from the same map). Shared atoms stay on `context.l10n` until the `common` phase.
3. **Leave the shim/ARBs intact** — shim/ARB deletion is **deferred to the final demolition** (a `case` is only dead once *every* screen is migrated). Migrated exclusive keys become dead shim cases, swept wholesale at the end. This keeps each phase small and prevents breaking other screens.
4. **Verify** — `dart run slang` + `flutter analyze` + `flutter test` green; smoke-test the screen. Small, reviewable PR.

**Progress:**
- ✅ **`settings`** — 24 call sites → `context.t.settings.*` (`sections`/`appearance`/`calendar`/`experience`/`units`/`language`/`confirmDialog`); fixed the untranslated `PROSSIMAMENTE` → `settings.comingSoon`. Guard added to `tool/arb_to_slang.py` (bootstrap converter refuses to re-run once namespaces are nested).
- ✅ **`common`** — 69 call sites across 22 files → `context.t.common.*` (`actions`, `status.error`, `calendarView`); unblocks the shared atoms used everywhere. Scoped to generic UI vocabulary (the 12 strings used in ≥3 files); domain/count words deferred to their phases.
- ✅ **`auth`** — auth screen (12 sites) → `context.t.auth.*`, **and fixed audit `I18N-2`**: `auth_provider.dart`'s 21 hardcoded-Italian error literals → `t.auth.errors.*` (global `t`, no `BuildContext` in a provider), with 8 newly-translated error messages. The localized keys mostly already existed; the provider just never used them. Established the **global `t`** pattern for non-widget code.
- ✅ **`profile`** — account cluster (`profile_screen` + `personal_info_screen`) → `context.t.profile.*` / `profile.personalInfo.*`; fixed an untranslated `Vai al login` → `profile.goToLogin`.
- ✅ **`notifications`** + **`privacy`** — the two settings sub-screens. `notifications` (7 keys); `privacy` (45 keys, many multi-line dialog strings) + 8 more untranslated latent bugs fixed.
- ✅ **Straggler sweep** — completed `settings` (3), `auth` (10), `profile` (7) multi-line literals that the old single-line scan had missed. Those screens are now fully migrated except genuinely-shared atoms (→ `common`).
- ✅ **`consent`** — `consent_screen` (6 keys, 7 sites) → `context.t.consent.*`; reused `t.auth.readPrivacyPolicy`.
- ✅ **`subscription`** — paywall (`subscription_screen`, 59 keys: `errors`/`features`/`plans`/`status`/`actions` + titles, 73 sites). `localeName` getter left on shim (dynamic).
- ✅ **`ai`** — `ai_chat_screen` (33 keys incl. 20 `ai.suggestions.*` chips, 36 sites) + 3 new latent-bug keys (private-mode AI consent). 12 dynamic `translate(var)` calls left on shim.

- ✅ **`macroGoals`** — cluster (`macro_goals_screen` + 4 widgets, 104 sites): 73 literals (auto English keys) + 12 getters → `t.macroGoals.*`/`types.*`. Fixed `quarterNumber` positional→named arg.
- 🟡 **`statistics`** (partial) — cluster (`statistics_screen` + 10 widgets, 139 sites): 96 existing-key literals + 11 getters + 6 single-param method getters → `t.statistics.*`. **Deferred (next):** 33 untranslated `MISSING` strings (incl. day names — need EN/IT/ES/DE authored), the 2 three-param correlation methods (`habit{Positive,Negative}CorrelationDescription` — manual named-arg conversion), and ~9 dynamic `translate(var)` calls.

**Toolchain note:** `flutter`/`dart` are now available at `/opt/homebrew/bin`; verification (`dart run slang && flutter analyze && flutter test`) is run after **every** phase — all green so far (35 tests).

### Auto-migration learnings (for the remaining clusters)
- Use the **multi-line + trailing-comma** regex for scoping.
- **Placeholder methods**: gen_l10n uses positional args, slang uses **named** — convert call sites (`(arg)`→`(param: arg)`); multi-param ones need manual conversion (regex can't safely split args).
- **Namespace name must not collide** with an existing flat key (e.g. `stats` flat key existed → used `statistics`).
- After migrating a file, **remove a now-unused `core/localization.dart` import**.
- Pull values from the untouched **ARB** when a flat slang key was already moved by an earlier phase (cross-namespace keys like `goalTypeAnnual`).

### 🎯 Milestone — ALL static strings migrated
`grep "context.l10n.translate(\s*'"` → **0**. Every static literal + getter across the app is now type-safe `context.t.*` / global `t.*` (15 namespaces: common, settings, auth, profile, notifications, privacy, consent, subscription, ai, macroGoals, statistics, habits — plus the providers). Reusable migrator at `tool/migrate_cluster.py`. ~30 latent untranslated bugs fixed along the way (incl. day names, AI/private-mode consent, subscription/privacy dialogs). All phases verified green (35 tests).

### Remaining before final demolition
1. **78 dynamic `context.l10n.translate(<var>)`** calls (macro_goals_screen 22, dashboard 20, ai_chat 12, statistics 10, …): the arg is computed at runtime, so it can't be a static key. **Refactor each** to resolve the dynamic value through slang (e.g. map a status/day/category value → a `t.*` lookup), or keep a tiny typed helper.
2. **12 `context.l10n.localeName` / `language`** (return the runtime locale name) → replace with `LocaleSettings.currentLocale.languageCode` / a localized language-name map.
3. **Then demolition**: delete `translate()`, `AppLocalizationsCompatibility`, `lib/core/localization.dart` legacy bits, `lib/l10n/app_*.arb`, the `gen_l10n` `generated/` output, and the `l10n.yaml`/`generate:` wiring. Gate: `grep "l10n.translate(" lib` → 0.

### Follow-ups (separate)
Surgical **plurals** (`giorni`/counts), locale-aware **NumberFormat/DateFormat**, **CI gate** (`slang analyze` + pseudolocale), and re-enabling **Arabic** after the RTL pass.

> **⚠️ Multi-line scan gap (found & fixed in Phase 5):** the per-phase scan originally matched only single-line `translate('…')`, skipping multi-line `translate(\n '…',\n)`. **Always use the multi-line + optional-trailing-comma regex** `translate\(\s*'…'\s*,?\s*\)` for scoping. Earlier-screen stragglers have been swept.
>
> **Dynamic `translate(var)` / special keys** (e.g. `translate('language')` returning the runtime locale name) can't map to static `t.*` keys — they must be refactored (or kept via a small helper) **before** the final-demolition `grep translate( == 0` gate passes.

## Final phase — Demolition
- Delete `translate()`, the `AppLocalizationsCompatibility` extension, the `l10n` getter shim, `lib/core/localization.dart`'s legacy bits, `lib/l10n/app_*.arb`, the `generated/` gen_l10n output, and the `gen_l10n` wiring in `l10n.yaml` / `pubspec` (`generate: true`).
- Confirm `grep -rn "l10n.translate(" lib` returns **zero**.

## Follow-up PRs (after the structural migration)
- **Surgical plurals** — convert genuine count-*sentences* (notification bodies, AI/streak/"X of Y" copy) to slang plurals across EN/IT/ES/DE; type the `int` placeholders (`count`, `completed`, `total`). Leave number+label stat cards as-is.
- **Locale-aware formatting** — route the ~23 raw percent/`toStringAsFixed` spots and dates through `intl` `NumberFormat`/`DateFormat` bound to the active locale; keep the 24h setting.
- **CI gate** — run `dart run slang analyze` (fail on missing keys, report unused) + `flutter analyze` + `flutter test` in CI; enable slang's **pseudolocale** for dev/QA.

## Translation workflow (steady state)
- English (`en.i18n.json`) is authored by hand; it is the source of truth.
- New/missing IT/ES/DE values are AI-translated **from English** and reviewed. Existing human copy (esp. Italian voice in notifications/AI prompts) is **preserved**, never round-tripped.
- `slang analyze` keeps locales in lockstep.

## ⏸ Deferred (tracked, not forgotten)
**Arabic + RTL.** Re-enable `ar` only after an RTL pass: physical `Alignment.centerLeft/Right` → `AlignmentDirectional.*Start/End`, `EdgeInsets.only(left/right)` → `EdgeInsetsDirectional.only(start/end)` (~16 files), mirror the 17 Lucide directional icons under RTL, fix 8 `Positioned`, then VoiceOver/visual QA in Arabic. `app_ar.arb` stays on disk (slang input excludes it); re-enabling = add `ar` to `tool/arb_to_slang.py` `LOCALES`, regenerate, restore the picker option, then the RTL work.

## ✅ Definition of done
`grep "l10n.translate(" lib` → 0 · shim + `gen_l10n` deleted · `slang analyze` green (no missing keys; gaps fall back to English) · pseudolocale clean · existing IT/ES/DE copy preserved · semantic nested keys throughout · app compiles, tests pass, and ships at every phase.
