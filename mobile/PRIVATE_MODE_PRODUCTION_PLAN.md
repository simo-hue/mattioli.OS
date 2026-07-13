# Private Mode Production Plan

Created: 2026-06-17 21:47 CEST

This document defines the production-ready implementation plan for adding a fully private local data mode to the Flutter mobile app while preserving the current Supabase account mode behavior.

## Product Goal

Add a second way to use the app:

- Supabase account mode: current behavior remains unchanged.
- Private mode: user can continue from the login screen without signing in, store all persistent app data locally on the device, unlock all features without subscription gates, and later optionally sync private data with iCloud on Apple platforms.

The private and Supabase data spaces must remain completely separate forever. There must be no automatic migration, import, export, merge, upload, or cross-mode data sharing between them.

## Locked Decisions

- Existing consent/onboarding stays before login/private choice.
- Login screen adds a localized button equivalent to "Continue privately on this iPhone".
- Private mode persists across restarts.
- Saved active mode wins on launch, even if a Supabase session also exists.
- Entering Private mode does not sign out of Supabase.
- Exiting Private mode is non-destructive.
- Deleting private data is the only destructive private-data action.
- One private user/profile exists per app install/device, with one stable local UUID forever.
- Private IDs are generated locally and never reuse Supabase auth or record IDs.
- Private and Supabase settings are separated by active mode.
- Supabase behavior for logged-in users must remain functionally unchanged.
- Android Private mode is local-only forever.
- iCloud sync is Apple-only, off by default, opt-in from settings, and hidden until implemented.
- iCloud sync syncs all private data as one unit.
- iCloud conflicts use last-write-wins with per-record `updated_at`.
- Local private data is encrypted at rest.
- CloudKit payloads are client-side encrypted.
- The CloudKit encryption key is shared through iCloud Keychain.
- When iCloud sync is off, private DB files are excluded from iCloud/iTunes backup.
- Sentry is disabled in Private mode.
- Supabase data calls are disabled in Private mode.
- RevenueCat/StoreKit subscription gating is disabled in Private mode.
- Subscription/paywall UI is hidden in Private mode.
- All app features are available in Private mode.
- AI features in Private mode require explicit opt-in before sending selected private data to an external AI provider.
- AI chat persistence is not required.
- Local schema mirrors production Supabase user-data tables except `ai_insights`.
- `mobile_schema.sql` should be updated to reflect production schema, but not used to change Supabase unless migrations are explicitly run.

## Production Schema To Mirror Locally

The production Supabase schema was introspected on 2026-06-17. Phase 1 local storage mirrors these tables:

- `profiles`
- `goals`
- `goal_logs`
- `long_term_goals`
- `daily_moods`
- `goal_category_settings`
- `macro_goal_categories`

The local Private mode schema excludes:

- `ai_insights`

Important production columns that must be included:

- `profiles.date_of_birth`
- `profiles.morning_brief_time`
- `profiles.evening_review_time`
- `profiles.terms_accepted_at`
- `profiles.sentry_consent`
- `goals.reminder_time`
- `goal_logs.streak`
- `long_term_goals.category_id`
- `macro_goal_categories.archived_at`

Local foreign-key rule:

- Local `profiles.id` is the single private owner UUID.
- Every local `user_id` column points to that local owner.
- Local foreign keys point to local tables, never Supabase `auth.users`.

## Architecture Target

The app needs a data-mode boundary that prevents UI and providers from calling Supabase when Private mode is active.

Core concepts:

- `AppDataMode`: `supabase` or `private`.
- `activeDataModeProvider`: persisted locally and read during startup/router redirects.
- `dataStoreProvider`: returns repositories backed by Supabase or local encrypted SQLite depending on active mode.
- `privateOwnerProvider`: creates/loads the single stable private owner UUID.
- `privateSyncService`: Phase 1 no-op boundary, Phase 2 CloudKit implementation.

Repository boundary:

- `HabitsRepository`
- `HabitLogsRepository`
- `MacroGoalsRepository`
- `MacroGoalCategoriesRepository`
- `DailyMoodsRepository`
- `SettingsRepository`
- `ProfileRepository`
- `StatsRepository`
- `ExportRepository`
- `PrivateDataLifecycleRepository`

Supabase repositories preserve current behavior.

Private repositories use the encrypted local database and must not import `supabase_flutter`.

## Phase 1: Local Private Mode

Phase 1 delivers a production-ready local-only Private mode. iCloud UI remains hidden.

### 1. Dependency And Storage Foundation

Tasks:

- Select and add the local database stack.
- Recommended: Drift + SQLite.
- Add encryption support suitable for iOS and Android.
- Store the private DB encryption key in Keychain/Keystore.
- Ensure private DB files are excluded from iOS backups while iCloud sync is off.
- Create a local database open path distinct from existing Supabase caches.
- Add schema migrations from version 1 onward.
- Add a one-time private owner bootstrap that creates `profiles.id`.
- Add local `updated_at` handling in repository writes.

Acceptance criteria:

- Database opens on iOS and Android.
- Database contents are encrypted at rest.
- One local profile row is created once and reused forever.
- Private DB file path is not shared with Supabase JSON cache keys.
- No Supabase cache is read by Private mode.

### 2. Local Schema

Tasks:

- Implement local `profiles`.
- Implement local `goals`.
- Implement local `goal_logs`.
- Implement local `long_term_goals`.
- Implement local `daily_moods`.
- Implement local `goal_category_settings`.
- Implement local `macro_goal_categories`.
- Add indexes matching production where useful.
- Add local constraints where SQLite/Drift supports them cleanly.
- Add soft archive support for `macro_goal_categories.archived_at`.
- Use text for enum fields such as `long_term_goals.type` and `status`.
- Store date-only fields consistently as ISO `YYYY-MM-DD` or typed date columns depending on Drift implementation.
- Store timestamp fields as UTC ISO or integer milliseconds consistently.

Acceptance criteria:

- Local schema can represent every persistent user-data field used by the current app.
- Local schema excludes `ai_insights`.
- Local IDs are UUIDs.
- Local `goal_logs` unique constraint is equivalent to `(goal_id, date)`.
- Local `daily_moods` unique constraint is equivalent to `(user_id, date)`.
- Local `macro_goal_categories` unique constraint is equivalent to `(user_id, name)`.

### 3. Data Mode And Router

Tasks:

- Add persisted active data mode.
- Router allows app access if either:
  - Supabase mode has a valid Supabase session.
  - Private mode is active.
- Existing onboarding/consent redirect remains first.
- Login screen adds "Continue privately on this iPhone".
- Tapping private button sets active mode to Private and initializes the local owner/profile.
- Supabase login sets active mode to Supabase only after successful login.
- Logout in Supabase mode keeps existing behavior.
- "Go to Login" from Private mode sets active mode away from Private without deleting private data.

Acceptance criteria:

- Existing logged-in Supabase launch behavior is unchanged.
- Private mode opens the app without Supabase auth.
- Restarting the app returns to the saved active mode.
- If a Supabase session exists but active mode is Private, the app opens Private mode.
- If active mode is Supabase, current Supabase session behavior wins.

### 4. Provider And Repository Refactor

Tasks:

- Refactor providers to call repositories instead of directly calling Supabase where Private mode needs parity.
- Preserve public provider APIs where possible to minimize UI churn.
- Keep Supabase implementation behavior unchanged.
- Ensure local write paths update provider state optimistically like the current app.
- Ensure local read paths load data synchronously or with controlled loading states matching current UX.
- Make provider invalidation mode-aware.
- Remove Private mode dependence on existing shared JSON cache keys.

Providers requiring mode-aware behavior:

- `authProvider`
- `settingsProvider`
- `userProfileProvider`
- `goalsProvider`
- `habitLogsProvider`
- `macroGoalsProvider`
- `macroGoalCategoriesProvider`
- `dailyMoodsProvider`
- stats providers in `goal_provider.dart`
- `macroGoalsStatsProvider`
- tutorial providers if mode-specific tutorial state is desired

Acceptance criteria:

- Private mode CRUD works for habits, logs, macro goals, categories, moods, profile, and settings.
- Supabase mode behavior and data remain unchanged.
- Private mode CRUD does not call Supabase.
- Supabase mode still syncs with Supabase as before.

### 5. Settings Separation

Tasks:

- Keep global onboarding/terms completion global.
- Store Private mode settings in local `profiles` and/or local settings mapping.
- Keep Supabase settings backed by current profile/settings flow.
- In Private mode, `isPro` should behave as unlocked locally.
- Hide subscription toggles/prompts where they are purely monetization UI.
- Keep user-controlled app settings available, including:
  - theme mode
  - accent color
  - default calendar view
  - haptics
  - language
  - 24h time
  - notification flags
  - notification times
  - biometric lock
  - AI feature switches, guarded by Private AI consent when external calls are involved

Acceptance criteria:

- Changing settings in Private mode does not alter Supabase account settings.
- Changing Supabase settings does not alter Private mode settings.
- Private mode reports unlocked feature access without RevenueCat.

### 6. Profile And Avatar

Tasks:

- Keep profile screens available in Private mode.
- Store local profile fields:
  - first name/full name as supported by current UI
  - date of birth
  - optional avatar
  - optional email field if the UI requires it, but no account identity is created
- Save private avatar as a local file managed by the app.
- Ensure private avatar file is included in future iCloud sync scope.
- Ensure private avatar file is deleted when private data is deleted.

Acceptance criteria:

- Profile screen works without Supabase user.
- Personal information saves locally.
- Avatar persists across restarts in Private mode.
- No profile write hits Supabase in Private mode.

### 7. Subscription And Pro Gates

Tasks:

- Add a mode-aware entitlement layer.
- In Supabase mode, keep current RevenueCat/StoreKit behavior unchanged.
- In Private mode:
  - skip RevenueCat initialization
  - hide subscription screen entry points
  - hide paywalls
  - hide upgrade prompts
  - hide Pro badges/promotional UI
  - treat all features as available

Acceptance criteria:

- No RevenueCat calls occur in Private mode.
- No subscription UI is visible in Private mode.
- Supabase mode subscription behavior remains unchanged.

### 8. Sentry And Privacy Boundary

Tasks:

- Prevent Sentry initialization or event submission in Private mode.
- Re-check startup flow because Sentry currently initializes before `runApp`.
- Sanitize error handling so Private mode does not send exceptions externally.
- Keep local user-facing error modals/snackbars.
- Do not send analytics/diagnostics in Private mode unless a future separate opt-in is added.

Acceptance criteria:

- Private mode does not send Sentry events.
- Supabase mode keeps current Sentry behavior based on existing consent.

### 9. AI External Send Consent

Tasks:

- Add Private-mode-specific AI external-send consent.
- Before any OpenRouter request using private app context, show clear opt-in copy.
- Store this consent in the local private DB/settings.
- AI screens remain accessible without consent.
- If consent is missing, AI can operate only without private app context or must ask for consent before proceeding.
- Never silently send private goals, habits, moods, profile, or settings to external AI services.

Acceptance criteria:

- Private mode AI cannot send personal app context without explicit consent.
- Once consent is granted, selected context can be sent intentionally.
- Supabase mode AI behavior remains unchanged unless separately improved later.

### 10. Local Statistics And RPC Equivalents

Tasks:

- Replace Supabase RPC/view dependencies with local computations in Private mode.
- Implement local equivalents for:
  - `habitStatsProvider`
  - `habitAnalyticsProvider`
  - `globalCriticalDayProvider`
  - `globalTrendProvider`
  - `criticalHabitsProvider`
  - `bestHabitsProvider`
  - `habitPerformanceProvider`
  - `habitAlertsProvider`
  - `habitYearlyGridProvider`
  - `habitCorrelationsProvider`
  - `allHabitCorrelationsProvider`
  - `macroGoalsStatsProvider`
- Match current UI data shapes exactly.
- Use SQL queries where that improves correctness/performance.
- Use Dart calculations where existing UI logic already expects in-memory maps.

Acceptance criteria:

- Statistics screens work in Private mode with no network.
- Empty states remain professional when there is insufficient data.
- Supabase mode continues using existing RPC/view calls.

### 11. Notifications And Background Actions

Tasks:

- Make notification action handlers mode-aware.
- For Supabase mode, preserve current Supabase writes.
- For Private mode, write notification actions to the local database.
- Ensure background isolates can open the encrypted local DB or route through a safe local write service.
- Schedule habit reminders using active mode data.
- Cancel/reschedule reminders when active mode changes or settings change.

Acceptance criteria:

- Mark done/skip/snooze behavior works in Private mode.
- Notification actions do not call Supabase in Private mode.
- Existing Supabase notification behavior remains unchanged.

### 12. Export, Reset, Delete

Tasks:

- Export only the active data space.
- Supabase mode export keeps current account export behavior, extended only if needed to match current persistent data.
- Private mode export reads local DB only.
- Private data deletion deletes:
  - local DB rows
  - local avatar/files
  - private settings
  - private AI consent
  - future sync metadata/tombstones as applicable
- Exiting Private mode does not delete private data.
- Reset data in Private mode affects only private data.
- Account deletion remains Supabase-only.

Acceptance criteria:

- No export combines Supabase and Private data.
- Deleting private data never deletes Supabase data.
- Deleting Supabase account never deletes private data unless the user explicitly chooses private deletion separately.

### 13. UI Integration

Tasks:

- Add login button with localized copy.
- Add settings/account data-mode controls:
  - Private active: Go to Login, Delete private data.
  - Supabase active: existing account/logout behavior, plus Use private mode on this iPhone.
- Do not show a persistent private status indicator.
- Hide iCloud controls in Phase 1.
- Hide subscription UI in Private mode.
- Keep UI copy precise and privacy-safe.
- Add ARB strings for all new user-facing text in supported locales:
  - English
  - Italian
  - Arabic
  - Spanish
  - German
- Regenerate localization files.

Acceptance criteria:

- No hardcoded user-facing strings for new UI.
- Private mode can be entered before login after onboarding.
- Mode switching is explicit and non-destructive.

### 14. Schema Documentation Update

Tasks:

- Update `mobile_schema.sql` to match production schema verified on 2026-06-17.
- Include:
  - `macro_goal_categories`
  - `long_term_goals.category_id`
  - `goals.reminder_time`
  - `goal_logs.streak`
  - `profiles.date_of_birth`
  - notification time columns
  - production mood score range 0-10
- Clearly mark it as documentation/reference unless migrations are intentionally run.

Acceptance criteria:

- Future agents do not rely on the stale schema.
- Local schema parity decisions are traceable.

### 15. Phase 1 Verification

Minimum verification before Phase 1 is considered complete:

- `flutter analyze`
- `flutter test`
- iOS simulator manual smoke test:
  - onboarding then private entry
  - create habit
  - log habit status
  - create macro goal
  - create/archive category
  - save mood
  - edit profile
  - change settings
  - restart app and confirm Private mode persists
  - switch to login without deleting data
  - switch back to Private mode and confirm data remains
  - delete private data and confirm it does not reappear
- Supabase mode regression smoke test:
  - existing login
  - existing data loads from Supabase
  - CRUD still syncs
  - logout behavior unchanged
  - subscription behavior unchanged
- Privacy smoke test:
  - no Supabase calls from Private CRUD paths
  - no RevenueCat init in Private mode
  - no Sentry submission in Private mode
  - AI personal context requires opt-in

## Phase 2: iCloud Sync

Phase 2 starts only after Phase 1 local Private mode is stable.

### 1. Apple Capabilities

Tasks:

- Add iCloud/CloudKit entitlement to iOS target.
- Add Keychain sharing capability if needed for iCloud Keychain key sharing.
- Create/configure CloudKit container in Apple Developer/App Store Connect.
- Add container identifiers to Xcode entitlements.
- Decide development and production CloudKit environments.
- Keep Android implementation permanently local-only/no-op.

Acceptance criteria:

- iOS builds with iCloud entitlements.
- CloudKit container is available on device.
- Android build is unaffected.

### 2. Native Swift CloudKit Bridge

Tasks:

- Add Dart `PrivateSyncService` interface if not already present from Phase 1.
- Add iOS MethodChannel/EventChannel bridge.
- Implement Swift CloudKit service.
- Implement account status checks:
  - available
  - no iCloud account
  - restricted
  - temporarily unavailable
  - unknown error
- Implement manual "Sync now".
- Implement automatic sync triggers:
  - app foreground
  - after local writes
  - periodic/background opportunities where supported
- Implement status reporting for settings UI.

Acceptance criteria:

- iCloud unavailable never blocks Private mode.
- Settings can show actionable sync status.
- Manual sync can be invoked and reports success/failure.

### 3. Client-Side Encryption

Tasks:

- Generate private sync encryption key.
- Store/share key through iCloud Keychain.
- Encrypt CloudKit payloads before upload.
- Decrypt after download before local apply.
- Keep CloudKit-visible data minimal:
  - record type
  - record ID
  - updated timestamp
  - tombstone status
  - encrypted payload
- Plan key-loss behavior clearly.

Acceptance criteria:

- CloudKit does not receive plaintext goals, moods, profile, settings, or categories.
- Second Apple device can decrypt after iCloud Keychain sync.

### 4. Sync Metadata And Conflict Handling

Tasks:

- Add sync metadata locally:
  - record ID
  - record type
  - local updated_at
  - last synced at
  - dirty flag
  - deleted/tombstone flag
  - sync error
- Use last-write-wins per record.
- Preserve referential integrity during pulls:
  - profiles before child records
  - goals before goal logs
  - categories before macro goals where possible
- Queue offline writes.
- Queue deletions as tombstones.
- If private data is deleted while offline, queue CloudKit deletion/tombstones so data does not reappear later.

Acceptance criteria:

- Edits on two Apple devices converge.
- Latest `updated_at` wins.
- Deleted private data does not come back from CloudKit.
- Sync can resume after offline periods.

### 5. iCloud Settings UI

Tasks:

- Add Private mode settings controls:
  - Enable iCloud Sync
  - Sync now
  - Last synced status
  - iCloud unavailable/error message
- Keep iCloud controls hidden outside Private mode.
- Keep iCloud controls hidden on Android.
- Explain clearly that iCloud sync uses the user's Apple iCloud account and does not use Supabase.
- Turning sync on uploads all private data.
- Turning sync off stops future sync but does not necessarily delete already-synced CloudKit data unless the user chooses delete.

Acceptance criteria:

- User can enable/disable iCloud sync explicitly.
- User can force sync.
- iCloud unavailable shows an error but local mode continues.

### 6. Phase 2 Verification

Minimum verification before Phase 2 is considered complete:

- `flutter analyze`
- `flutter test`
- iOS device build with entitlements.
- Two-device or device/simulator CloudKit sync test.
- iCloud unavailable test.
- Offline edit and later sync test.
- Conflict test with last-write-wins.
- Delete private data and confirm CloudKit deletion/tombstone behavior.
- Confirm Android remains local-only and has no iCloud UI.
- Confirm CloudKit records do not contain plaintext sensitive payloads.

## Automated Test Plan

Automated tests can be expanded after Phase 1 implementation, but production readiness should include:

- Mode router tests.
- Repository selection tests.
- Private CRUD tests against local DB.
- Supabase repository regression tests with mocks/fakes.
- No-Supabase-call tests for Private mode write paths.
- Settings separation tests.
- Private entitlement/unlocked feature tests.
- Export active-mode-only tests.
- Delete private data tests.
- Local stats calculation tests.
- Notification action routing tests where feasible.
- CloudKit sync service unit tests in Phase 2 with a fake native bridge.

## Release Checklist

Before releasing Private mode:

- Supabase account mode regression passed.
- Private mode local data persistence passed.
- Private data encryption verified.
- Private mode network/privacy boundary reviewed.
- Subscription UI hidden in Private mode.
- Sentry disabled in Private mode.
- AI private-data consent implemented.
- Localization complete for all supported locales.
- `DOCUMENTATION.md` updated.
- `TO_SIMO_DO.md` updated only for real manual actions.
- No iCloud UI visible until Phase 2 is actually implemented.
- App Store privacy disclosures reviewed before release because data handling changes.

## Immediate Next Step

Start Phase 1 implementation by introducing the active data mode foundation and local encrypted database layer, before touching feature providers.

_(Superseded 2026-07-13: Phase 1 local Private mode and Phase 2 iCloud/CloudKit sync are both implemented — see `mobile/lib/core/{data_mode,private_local_database,private_data_store,private_sync_service}.dart` and `mobile/lib/ui/screens/icloud_sync_screen.dart`; the shared private DB schema is at v4 in `packages/evolve_sync/lib/src/private_db_schema.dart`.)_
