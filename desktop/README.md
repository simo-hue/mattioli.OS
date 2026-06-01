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

`DashboardRepository` is the boundary for data access. The current
`InMemoryDashboardRepository` keeps the native desktop baseline runnable while
the Supabase adapter is implemented. UI code must not depend directly on
Supabase or on demo data.

## Supabase integration gate

The desktop client must not bind to the live backend until the repository has a
single canonical schema. The current SQL artifacts expose contract drift:

- `mobile/mobile_schema.sql` constrains `daily_moods.mood_score` and
  `energy_score` to `1..5`, while the mobile UI saves values on a `0..10`
  scale.
- The root `schema.sql` and `mobile/mobile_schema.sql` do not describe the same
  `long_term_goals` columns.

Before implementing `SupabaseDashboardRepository`, pull the applied production
schema, reconcile these differences through a reviewed migration, and verify
the existing mobile client against the canonical contract. Desktop
credentials must use a Supabase publishable key supplied at build time; never
embed a service-role or secret key in the client.

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
