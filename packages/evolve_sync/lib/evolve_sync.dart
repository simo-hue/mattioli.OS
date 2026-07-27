/// Shared E2E-encrypted CloudKit sync core for the Evolve apps.
///
/// See `pubspec.yaml` for the ownership split: everything wire-format- or
/// merge-critical lives here; keychain access, platform wiring and UI live in
/// each app. Test doubles (the in-memory CloudKit fake) are exported separately
/// from `package:evolve_sync/testing.dart` so they never ship in app code.
library;

export 'src/avatar_path.dart';
export 'src/cloudkit_bridge.dart';
export 'src/cloudkit_bridge_method_channel.dart';
export 'src/cloudkit_private_sync_service.dart';
export 'src/migrating_sync_secret_store.dart';
export 'src/private_db_open_failure.dart';
export 'src/private_db_schema.dart';
export 'src/private_sync_service.dart';
export 'src/settings_codec.dart';
export 'src/sync_avatar_store.dart';
export 'src/sync_crypto.dart';
export 'src/sync_diagnostics.dart';
export 'src/sync_engine.dart';
export 'src/synced_settings_store.dart';
export 'src/sync_key_store.dart';
export 'src/sync_local_store.dart';
export 'src/sync_logger.dart';
export 'src/sync_write_debouncer.dart';
