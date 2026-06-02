# Evolve Desktop Status

Audit date: 2026-06-02.

The Flutter desktop client is self-contained inside this directory. It requires
the production Supabase backend at bootstrap and does not contain runtime mock
repositories or seeded dashboard data.

## Status legend

| Status | Meaning |
| --- | --- |
| `Local` | Device-local preference, encrypted cache or platform behavior. Never demo data. |
| `Cloud` | Connected to the production Supabase contract. |
| `Surface` | Desktop UX exists but the production adapter is intentionally disabled. |
| `Platform gate` | Requires a native implementation or product decision per desktop OS. |

## Cloud-backed features

| Feature | Status | Notes |
| --- | --- | --- |
| Email/password auth and password reset | `Cloud` | Uses Supabase Auth. |
| Habits and daily logs | `Cloud` | Uses `goals` and `goal_logs`. |
| Mood and energy check-in | `Cloud` | Uses `daily_moods`. |
| Lifetime, annual, quarterly, monthly and weekly goals | `Cloud` | Uses `long_term_goals`. |
| Goal categories | `Cloud` | Uses `macro_goal_categories`. |
| Dashboard and statistics | `Cloud` | Derived from synchronized records and available RPCs. |
| Profile and consent | `Local` + `Cloud` | Uses encrypted local state and `profiles`. |
| Retryable offline mutations | `Local` + `Cloud` | Queued in encrypted storage and replayed on refresh. |
| JSON export | `Local` + `Cloud` | Exports synchronized user records and preferences. |
| Delete account | `Cloud` | Uses authenticated `delete_user_account`. |

## Platform features

| Feature | Status | Notes |
| --- | --- | --- |
| Notifications | `Local` + `Platform gate` | macOS schedules recurring notifications; Windows and Linux retain platform limits. |
| Biometric lock | `Local` + `Platform gate` | Active on macOS and Windows. |
| RevenueCat purchases | `Cloud` + `Platform gate` | Active on macOS; Windows and Linux require a commercial channel decision. |
| AI Coach | `Surface` | Simulated answers were removed. Enable only with a secure backend adapter. |

## Production schema notes

Anonymous zero-row Data API probes against the configured project
`raxizttlmsofixqyanwc` passed on 2026-06-02 for:

- `profiles`
- `goals`
- `goal_logs`
- `long_term_goals`
- `daily_moods`
- `macro_goal_categories`

This confirms that the required Data API tables are exposed. It does not replace
a schema pull, migration reconciliation or RLS audit. For new Supabase tables,
verify Data API exposure grants explicitly:
<https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically>.

## Release blockers

1. Pull and version the applied Supabase schema and audit RLS.
2. Add authenticated backend integration coverage.
3. Complete desktop OAuth redirects.
4. Validate notifications in signed installers on each operating system.
5. Implement secure AI streaming through a backend adapter.
6. Validate StoreKit products in a signed macOS sandbox build.
7. Validate signed installers on macOS, Windows and Linux.

## Audit evidence

Executed successfully on macOS on 2026-06-02:

- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`
- `flutter build macos --debug`
- `flutter run -d macos --debug`
- Anonymous zero-row Data API probes for the required tables
