/// Pure-Dart core for auto-verified habits on the Evolve apps.
///
/// The reconcile/verdict engine and the verification template catalog live
/// here so the meaning of "done / missed / couldn't-verify" is identical on
/// every platform. The native HealthKit + Screen Time bridges are implemented
/// per-app (iOS `mobile/`); this package only owns their contracts. Test
/// doubles are exported separately from `package:evolve_verification/testing.dart`
/// so they never ship in app code.
library;

export 'src/day_verdict.dart';
export 'src/health_kit_bridge.dart';
export 'src/health_measurement_privacy.dart';
export 'src/screen_time_bridge.dart';
export 'src/verification_conditions.dart';
export 'src/verification_controller.dart';
export 'src/verification_log_writer.dart';
export 'src/verification_provider.dart';
export 'src/verification_rule.dart';
export 'src/verification_service.dart';
export 'src/verification_state_store.dart';
export 'src/verification_template.dart';
