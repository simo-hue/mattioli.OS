import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's source of "now".
///
/// The default IS `DateTime.now` — every production call site behaves exactly as
/// it did when it called `DateTime.now()` directly, so overriding nothing
/// changes nothing. The seam exists for tests.
///
/// Why it is needed: [DashboardController.build] fires an unawaited
/// `refresh()`, whose tail fires an unawaited `reconcileManualTargets()`. That
/// sweep resolves every CLOSED day, so it needs a clock — but a test cannot pass
/// one to a call it never makes. Before this provider existed, the sweep read
/// the real wall clock while the test's own calls used an injected date, and the
/// two agreed only on the day the test was written. `dashboard_target_progress_
/// test.dart` was written on 2026-07-24 and began failing on 2026-07-25.
///
/// Override it in tests:
/// ```dart
/// ProviderContainer(overrides: [clockProvider.overrideWithValue(() => fixed)]);
/// ```
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
