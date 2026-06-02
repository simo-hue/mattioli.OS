# Evolve Desktop Feature Parity

Audit date: 2026-06-02.

This document compares the Flutter iPhone client in `../mobile` with the native
Flutter desktop client. The desktop application remains runnable with an
in-memory preview repository when build-time Supabase values are omitted. A
configured build now uses the shared mobile backend through an authenticated,
offline-capable adapter. This is not yet a production-readiness claim.

`../mobile/lib/core/supabase_config.dart` is the only valid backend
configuration source for the desktop client. The root web `.env` targets a
different legacy Supabase project and must not be reused for native builds.
Use `dart run tool/flutter_with_mobile_supabase.dart run -d macos` so desktop
receives the mobile production URL and frontend key without duplicating them.

## Status legend

| Status | Meaning |
| --- | --- |
| `Local` | Usable in the desktop preview with local repository state. |
| `Cloud` | Connected to the shared Supabase contract in a configured build. |
| `Surface` | Desktop UX is present but the production adapter is intentionally disabled. |
| `Cloud gate` | Requires the canonical Supabase schema, RLS verification and repository adapter. |
| `Platform gate` | Requires a native implementation or commercial decision per desktop OS. |
| `Desktop adaptation` | Mobile interaction has an intentional desktop equivalent. |

## Dashboard and habits

| Mobile feature | Desktop status | Notes |
| --- | --- | --- |
| Daily protocol list and completion toggle | `Local` + `Cloud` | Shared controller writes date-indexed `goal_logs`; retryable offline mutations are queued per user in encrypted storage. |
| Daily mood and energy check-in | `Local` + `Cloud` | Desktop and mobile UI now both use the `0..10` scale. |
| Habit creation, editing and deletion | `Local` + `Cloud` | Writes the shared `goals` table. |
| Habit reminder time | `Local` + `Platform gate` | Preference is editable; native scheduler is not wired. |
| Day detail modal | `Local` + `Cloud` | Uses selected-date logs, the mobile today/yesterday edit guard and `done -> missed -> empty` cycle. |
| Month calendar | `Local` + `Cloud` | Historical density derives from date-indexed logs, active date ranges and per-habit colored indicators. |
| Week calendar | `Local` + `Cloud` | Values derive from date-indexed logs. |
| Year calendar | `Local` + `Cloud` | Weekly density bars derive from date-indexed logs. |
| Life calendar | `Local` + `Cloud` | Uses Auth profile birth date and the mobile 85-year monthly projection, with fallback matching iOS. |
| Protocol quick actions | `Desktop adaptation` | First-class sidebar sections replace the mobile panel shortcuts. |
| Dashboard tutorial | `Surface` | Tutorial reset entry is exposed in settings; walkthrough persistence is pending. |
| Haptic feedback | `Desktop adaptation` | Marked mobile-only for mouse and keyboard workflows. |

## Long-term goals

| Mobile feature | Desktop status | Notes |
| --- | --- | --- |
| Lifetime, annual, quarterly, monthly and weekly goals | `Local` + `Cloud` | All `GoalType` values map to `long_term_goals`. |
| Active, completed and failed states | `Local` + `Cloud` | Reschedule keeps failed history and creates the following period like mobile. |
| Period navigation and type filtering | `Local` + `Cloud` | Desktop reproduces the five mobile horizon tabs, hierarchical period selectors and logical week rollover. |
| Goal creation and deletion | `Local` + `Cloud` | Repository-backed CRUD. |
| Goal categories | `Local` + `Cloud` | Defaults plus synchronized custom category creation, editing and archive UI. Archived categories remain resolvable for historical goals. |
| Goal statistics overview | `Local` + `Cloud` | Local KPI and type distribution with `get_macro_goals_stats` enrichment when authenticated. |
| Advanced goal analytics | `Cloud` + `Surface` | Shared RPC adapter is active; the richer mobile chart set is not fully reproduced on desktop. |
| Evolve Pro limit and year-level gating | `Surface` | Pro badges and plan UI exist; entitlement provider is not wired. |
| Goals tutorial | `Surface` | Tutorial state persistence remains pending. |

## Statistics

| Mobile feature | Desktop status | Notes |
| --- | --- | --- |
| Global info KPI, correlations and activity heatmap | `Local` + `Cloud` | Derived from synchronized date-indexed logs. |
| Global trend and temporal comparison | `Local` + `Cloud` | Uses `get_global_trend` when authenticated with synchronized-log fallback. |
| Global alerts | `Local` + `Cloud` | Uses active goals and weakest recent habit. |
| Habit ranking | `Local` + `Cloud` | Derived from synchronized logs with preview fallback. |
| Global mood analysis | `Local` + `Cloud` | Derived from synchronized `daily_moods`. |
| Single habit overview | `Local` + `Cloud` | Uses synchronized logs. |
| Single habit annual calendar | `Local` + `Cloud` | Uses `get_habit_yearly_grid` with synchronized-log fallback. |
| Weekday performance | `Local` + `Cloud` | Uses `get_habit_performance_by_day` with local fallback. |
| Improvement alerts | `Local` + `Cloud` | Uses `get_habit_alerts`, synchronized streaks and local fallback. |
| Habit mood resilience | `Local` + `Cloud` | Uses shared `0..10` mood and energy values. |
| Pro access to granular analytics | `Surface` | Requires entitlement provider. |

## AI Coach

| Mobile feature | Desktop status | Notes |
| --- | --- | --- |
| Conversation view | `Local` | Desktop chat layout is usable. |
| New and clear conversation | `Local` | Desktop actions are implemented. |
| Habit and goal context toggles | `Local` | Context preference is explicit. |
| Prompt shortcuts | `Local` | Desktop quick prompts are implemented. |
| Copy assistant response | `Local` | Copies to the system clipboard. |
| Typing indicator | `Local` | Used while preview response is prepared. |
| Markdown assistant rendering | `Surface` | Add renderer with streaming adapter. |
| OpenRouter streaming | `Surface` | Must be provided by a secure adapter; no client key is embedded. |
| Evolve Pro gate | `Surface` | Requires entitlement provider. |

## Account, consent and settings

| Mobile feature | Desktop status | Notes |
| --- | --- | --- |
| Email/password login and signup | `Cloud` | Supabase Auth gate is active in configured builds. |
| Forgot password | `Cloud` | Sends Supabase password-reset email. |
| Apple and Google sign-in | `Surface` + `Platform gate` | Desktop OAuth redirects and provider configuration must be verified. |
| Consent onboarding | `Local` + `Cloud` | Persisted locally and synchronized to `profiles` when authenticated. |
| Realtime session handling and secure storage | `Cloud` + `Platform gate` | Auth stream is active. Credential-store adapter is implemented; macOS release requires signed Keychain Sharing entitlement. |
| Personal information and avatar | `Cloud` + `Surface` | Name and birth date update Auth metadata and `profiles`; avatar upload remains gated. |
| Theme and accent color | `Local` + `Cloud` | Matches the mobile monochrome default, applies dark/light palettes and selected contrast colors at runtime, persists the canonical mobile preference keys and synchronizes the profile. |
| Default calendar view | `Local` + `Cloud` | Persisted, profile-synchronized and applied when opening habits. |
| Language selection | `Local` + `Cloud` + `Surface` | Persisted and profile-synchronized; desktop localization bundles remain to wire. |
| 24-hour time format | `Local` + `Cloud` | Persisted and profile-synchronized. |
| Crash reporting consent | `Local` + `Cloud` + `Surface` | Persisted and profile-synchronized; Sentry initialization remains to wire. |
| Tutorial reset | `Surface` | Entry point exists; persistence remains to wire. |

## Notifications, privacy and subscription

| Mobile feature | Desktop status | Notes |
| --- | --- | --- |
| Morning brief and evening review | `Local` + `Cloud` + `Platform gate` | Preferences and times persist and sync; native scheduling remains to implement. |
| Habit, goal, AI and weekly notifications | `Local` + `Cloud` + `Platform gate` | Preferences persist and sync; scheduler remains platform-specific. |
| Biometric lock | `Surface` + `Platform gate` | Planned for macOS and Windows; Linux is explicitly unsupported. |
| Change password | `Cloud` | Re-authenticates with the current password before updating Supabase Auth. |
| Export data | `Local` + `Cloud` | JSON export copies the synchronized desktop cache; full privacy export remains gated. |
| Reset data and delete account | `Surface` + `Cloud gate` | Disabled until reviewed destructive RPC and re-auth are available. |
| Monthly and annual subscription plans | `Surface` + `Platform gate` | `purchases_flutter` supports macOS; Windows and Linux need a separate channel. |
| Restore purchases and customer center | `Surface` + `Platform gate` | Desktop actions are visible but disabled. RevenueCat `purchases_ui_flutter` is mobile-only, so macOS needs native desktop UX. |

## Canonical schema blockers

Anonymous zero-row Data API probes against the mobile project
`raxizttlmsofixqyanwc` passed on 2026-06-02 for the tables and columns
currently used by the mobile client. This confirms that the applied backend is
ahead of the repository SQL. It does not replace a schema pull or RLS audit.

Do not connect the desktop client to production until the applied schema is
pulled, reviewed and made reproducible through migrations. The checked-in SQL
still has these contract mismatches:

1. `../mobile/mobile_schema.sql` constrains `daily_moods.mood_score` and
   `energy_score` to `1..5`, while the mobile UI stores values on a `0..10`
   scale and analytics code compares values against `40` and `60`.
2. Root `../schema.sql` models `long_term_goals` with `is_completed`; mobile
   code and `../mobile/mobile_schema.sql` use `status`, temporal fields and
   category fields.
3. Mobile `goal_provider.dart` reads and writes `goal_logs.streak`, but the
   versioned base schemas do not define that column.
4. Mobile category providers use `macro_goal_categories`; the versioned base
   schemas do not provide one complete canonical definition.
5. Mobile models include category references, profile fields and reminder
   behavior that are present in the applied API but absent from the checked-in
   base schema.
6. Most RPCs consumed by `../mobile/lib/providers/goal_provider.dart` exist in
   the applied API but do not have versioned migrations in this repository.

The desktop adapter is now implemented behind repository interfaces without
coupling widgets to Supabase. The next backend step remains a production schema
pull, migration reconciliation, RLS audit and regression verification of the
existing iPhone client.

For new Supabase tables, verify Data API exposure grants explicitly. Supabase
stopped exposing newly created public tables automatically for new projects and
projects that opt into the updated behavior:
<https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically>.

## Production-readiness verdict

The native desktop preview is buildable but is not production-ready and does
not yet have mobile feature parity. Release blockers:

1. Pull and version the applied Supabase schema, audit RLS and add backend
   regression coverage for both clients.
2. Complete the richer desktop visualizations for the remaining advanced RPC
   analytics and add authenticated integration coverage.
3. Complete avatar upload, desktop OAuth redirects and entitlement state.
4. Add Sentry initialization, native notification
   adapters and per-platform permission flows.
5. Implement secure AI streaming through a backend adapter. Do not embed the
   OpenRouter secret in desktop binaries.
6. Implement macOS subscription flows and make an explicit product decision
   for Windows and Linux.
7. Validate signed installers and release builds on macOS, Windows and Linux.

## Fix applied during audit

The macOS sandbox now declares `com.apple.security.network.client` in debug and
release entitlements. The release entitlement also enables Keychain Sharing
for secure auth persistence. Signed Apple builds are required for release.

## Audit evidence

Executed successfully on macOS on 2026-06-02:

- `dart format --output=none --set-exit-if-changed lib test tool`
- `flutter analyze`
- `flutter test`: 24 tests passed
- `flutter build macos --debug`
- `dart run tool/flutter_with_mobile_supabase.dart build macos --debug`
- `dart run tool/flutter_with_mobile_supabase.dart run -d macos --debug`:
  Supabase initialization completed against the mobile production project
- `dart run tool/flutter_with_mobile_supabase.dart build macos --release`:
  correctly blocked on this host until an Apple development or distribution
  signing certificate is configured for the Keychain Sharing entitlement
- `flutter build windows`: not executable on a macOS host; requires Windows CI
- `flutter build linux`: not executable on a macOS host; requires Linux CI
- Anonymous zero-row Data API probes for mobile tables and required columns
- Anonymous probes for the 10 RPCs consumed by desktop statistics
- Unauthenticated empty-payload RevenueCat webhook probe, which returned
  `401 Unauthorized`
- `supabase status`: local schema verification remains blocked because Docker
  is not running on this host

## Platform references

- `local_auth` supports macOS and Windows, not Linux. Windows Hello does not
  support forcing `biometricOnly`.
- `flutter_local_notifications` supports macOS, Windows and Linux, but Linux
  has no scheduled/pending notification support and Windows has no repeating
  notification support.
- `share_plus` supports file sharing on macOS and Windows, but not Linux.
- `purchases_flutter` exposes Android, iOS, macOS and web, not Windows or
  Linux. `purchases_ui_flutter` exposes Android and iOS only.

- `local_auth`: <https://pub.dev/packages/local_auth>
- `flutter_local_notifications`: <https://pub.dev/packages/flutter_local_notifications>
- `share_plus`: <https://pub.dev/packages/share_plus>
- `purchases_flutter`: <https://pub.dev/packages/purchases_flutter>
- `purchases_ui_flutter`: <https://pub.dev/packages/purchases_ui_flutter>
- RevenueCat Flutter SDK: <https://www.revenuecat.com/docs/getting-started/installation/flutter>
