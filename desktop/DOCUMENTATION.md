# Evolve Desktop - Documentation

## [2026-07-03]: Privacy Mode Implementation
*Details*: Implemented a "Privacy Mode" for the macOS desktop application to allow users to use the app entirely offline and anonymously, mirroring the iOS mobile app's privacy features. This mode stores all user data locally without syncing to Supabase.
*Tech Notes*:
- **Local Database**: Integrated `sqflite_sqlcipher` for encrypted local SQLite storage.
- **Repository Abstraction**: Created `PrivateDashboardRepository` and a proxy repository to dynamically switch between Supabase and local storage based on the active mode (`activeDesktopDataModeProvider`).
- **Data Identification**: Used `uuid` v4 for generating IDs locally in Private Mode, mimicking Supabase's UUIDs.
- **Sentry Integration**: Added a privacy boundary that forcibly disables Sentry crash reporting when Private Mode is active.
- **Authentication**: Added a "Continua in modalità privata" button to the authentication screen that bypasses Supabase login.
- **Settings**: Adapted the settings page to hide cloud-only features (e.g., password change, subscription) when in Private Mode, replacing them with local data deletion options.
