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

Supply the frontend key at build time. Do not commit it and never use a
service-role or secret key in a desktop binary.

```bash
flutter run -d macos \
  --dart-define=EVOLVE_SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=EVOLVE_SUPABASE_PUBLISHABLE_KEY=YOUR_FRONTEND_KEY
```

Without these define values the app intentionally starts in local preview mode.

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

## Verify

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build macos --debug
```

## Desktop conventions

- Minimum supported window size: `960 x 640`.
- Default window size: `1440 x 900`.
- Sidebar navigation shortcuts: `Cmd+1` through `Cmd+5`.
- Settings shortcut: `Cmd+,`.
- Command palette: `Cmd+K` on macOS or `Ctrl+K` on Windows and Linux.
