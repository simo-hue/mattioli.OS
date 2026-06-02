# Evolve Desktop

Native Flutter desktop client for Evolve. The application is self-contained
inside this directory and uses the production Supabase backend directly.

## Supported targets

- macOS
- Windows
- Linux

## Architecture

```text
lib/
  app/                  application setup and theme
  core/                 desktop backend and platform configuration
  features/
    dashboard/          domain models, repository boundary and presentation
    habits/             desktop habit management UI
    statistics/         desktop analytics UI
    goals/              desktop long-term goals UI
    ai_coach/           AI Coach availability surface
    settings/           desktop preferences UI
    shell/              navigation and keyboard shortcuts
  shared/widgets/       reusable desktop components
```

`DashboardRepository` is the boundary for data access. Runtime builds always
use `SupabaseDashboardRepository` with the production `goals`, `goal_logs`,
`daily_moods`, `long_term_goals` and `profiles` contract. Auth sessions and the
dashboard cache use the platform credential store through
`flutter_secure_storage`. Retryable mutations are queued per user in encrypted
storage and replayed before the next cloud refresh. Test-only fakes live under
`test/` and are never compiled into the application.

## Backend configuration

The desktop client configuration lives under `lib/core/`:

- `desktop_supabase_config.dart`
- `desktop_revenuecat_config.dart`
- `desktop_sentry_service.dart`

The checked-in defaults are public client values. Never add a Supabase
`service_role` key or another server secret to the desktop binary. Build-time
overrides remain available through `--dart-define`.

## Run locally

```bash
flutter pub get
flutter run -d macos
```

## Verify

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build macos --debug
```

## macOS signing

The release entitlement enables Keychain Sharing for encrypted session
storage. A release build requires an Apple development or distribution
certificate:

```bash
flutter build macos --release
```

## Desktop conventions

- Minimum supported window size: `960 x 640`.
- Default window size: `1440 x 900`.
- Sidebar navigation shortcuts: `Cmd+1` through `Cmd+5`.
- Settings shortcut: `Cmd+,`.
- Command palette: `Cmd+K` on macOS or `Ctrl+K` on Windows and Linux.
