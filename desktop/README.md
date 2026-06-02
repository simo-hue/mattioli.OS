# Evolve Desktop

Native Flutter desktop client for Evolve. This application is intentionally
separate from `../mobile` and from the existing web MVP in the repository root.

## Supported targets

- macOS
- Windows
- Linux

## Architecture

The client follows a feature-first structure:

```text
lib/
  app/                  application setup and theme
  features/
    dashboard/          domain models, repository boundary and presentation
    habits/             desktop habit management UI
    statistics/         desktop analytics UI
    goals/              desktop long-term goals UI
    ai_coach/           desktop conversational UI
    settings/           local desktop preferences UI
    shell/              navigation and keyboard shortcuts
  shared/widgets/       reusable desktop components
```

`DashboardRepository` is the boundary for data access.
`InMemoryDashboardRepository` keeps preview and tests runnable without
credentials. A configured build uses `SupabaseDashboardRepository` with the
same `goals`, `goal_logs`, `daily_moods`, `long_term_goals` and `profiles`
contract as the mobile application. Auth sessions and the dashboard cache use
the platform credential store through `flutter_secure_storage`. Retryable
dashboard mutations are queued per user in the same encrypted store and replayed
before the next cloud refresh.

The detailed mobile-to-desktop audit lives in
[`FEATURE_PARITY.md`](FEATURE_PARITY.md). It is the source of truth for local
preview coverage, cloud integration gates and per-platform adaptations.

## Supabase configuration

The mobile production configs are the only source of truth. Do not use the root
web `.env`, duplicate credentials under `desktop`, or embed a service-role or
secret key in a desktop binary.

```bash
dart run tool/flutter_with_mobile_supabase.dart run -d macos
```

The launcher reads `../mobile/lib/core/supabase_config.dart`,
`../mobile/lib/core/revenuecat_config.dart` and
`../mobile/lib/core/sentry_config.dart`. It forwards only the mobile frontend
Supabase key and the public client configuration required by RevenueCat and
Sentry as compile-time desktop defines. Without the Supabase define values the
app intentionally starts in local preview mode.

The adapter is implemented, but publishing still requires a schema pull,
migration reconciliation and RLS audit. The applied Supabase project exposes
columns and RPCs that are ahead of the checked-in SQL artifacts. See
[`FEATURE_PARITY.md`](FEATURE_PARITY.md) for the verified mismatches.

## macOS signing

The release entitlement enables Keychain Sharing for encrypted session
storage. A release build therefore requires an Apple development or
distribution certificate:

```bash
flutter build macos --release
```

Unsigned local release builds fail intentionally once Keychain Sharing is
enabled. Debug preview builds remain ad-hoc buildable.

## Run locally

```bash
flutter pub get
flutter run -d macos
```

Use `dart run tool/flutter_with_mobile_supabase.dart run -d macos` when testing
the shared production backend.

## Verify

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build macos --debug
```

The desktop theme matches the mobile client: dark mode defaults to a
black-and-white palette, while the appearance settings apply the selected
contrast color immediately. Theme mode and accent color reuse the mobile
preference keys and synchronize through the shared Supabase profile.

The desktop settings menu mirrors the mobile profile surfaces: personal
information, local avatar selection, appearance, calendar view, language,
24-hour format, tutorial reset, reminders, biometric lock, password update,
Sentry consent, JSON export, reset/delete data and macOS RevenueCat purchase
management. Platform-specific adaptations and release prerequisites are listed
in [`FEATURE_PARITY.md`](FEATURE_PARITY.md).

## Desktop conventions

- Minimum supported window size: `960 x 640`.
- Default window size: `1440 x 900`.
- Sidebar navigation shortcuts: `Cmd+1` through `Cmd+5`.
- Settings shortcut: `Cmd+,`.
- Command palette: `Cmd+K` on macOS or `Ctrl+K` on Windows and Linux.
