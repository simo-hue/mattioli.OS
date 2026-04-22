import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class AppHaptics {
  static void lightImpact(WidgetRef ref) => lightImpactWithFlag(ref.read(settingsProvider).hapticFeedback);
  static void mediumImpact(WidgetRef ref) => mediumImpactWithFlag(ref.read(settingsProvider).hapticFeedback);
  static void heavyImpact(WidgetRef ref) => heavyImpactWithFlag(ref.read(settingsProvider).hapticFeedback);
  static void selectionClick(WidgetRef ref) => selectionClickWithFlag(ref.read(settingsProvider).hapticFeedback);
  static void vibrate(WidgetRef ref) => vibrateWithFlag(ref.read(settingsProvider).hapticFeedback);

  static void lightImpactWithFlag(bool enabled) {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void mediumImpactWithFlag(bool enabled) {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void heavyImpactWithFlag(bool enabled) {
    if (enabled) HapticFeedback.heavyImpact();
  }

  static void selectionClickWithFlag(bool enabled) {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void vibrateWithFlag(bool enabled) {
    if (enabled) HapticFeedback.vibrate();
  }
}

// Extension to make it even easier to use from ConsumerWidget
extension HapticExtension on WidgetRef {
  void hapticLight() => AppHaptics.lightImpact(this);
  void hapticMedium() => AppHaptics.mediumImpact(this);
  void hapticHeavy() => AppHaptics.heavyImpact(this);
  void hapticSelection() => AppHaptics.selectionClick(this);
  void hapticVibrate() => AppHaptics.vibrate(this);
}
