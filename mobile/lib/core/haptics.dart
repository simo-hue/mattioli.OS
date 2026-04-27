import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../providers/settings_provider.dart';

class AppHaptics {
  static void lightImpact(WidgetRef ref) => _trigger(ref, HapticFeedback.lightImpact);
  static void mediumImpact(WidgetRef ref) => _trigger(ref, HapticFeedback.mediumImpact);
  static void heavyImpact(WidgetRef ref) => _trigger(ref, HapticFeedback.heavyImpact);
  static void selectionClick(WidgetRef ref) => _trigger(ref, HapticFeedback.selectionClick);
  static void vibrate(WidgetRef ref) => _trigger(ref, HapticFeedback.vibrate);

  // More descriptive premium haptics
  static void success(WidgetRef ref) => _trigger(ref, HapticFeedback.mediumImpact);
  static void error(WidgetRef ref) => _trigger(ref, HapticFeedback.heavyImpact);
  static void action(WidgetRef ref) {
    if (Platform.isIOS) {
      // On iOS selectionClick is subtle, mediumImpact is more perceivable
      _trigger(ref, HapticFeedback.mediumImpact);
    } else {
      _trigger(ref, HapticFeedback.lightImpact);
    }
  }

  static void _trigger(WidgetRef ref, Future<void> Function() hapticFn) {
    final enabled = ref.read(settingsProvider).hapticFeedback;
    if (enabled) {
      hapticFn();
    }
  }

  // Support for non-widget contexts if needed
  static void lightImpactWithFlag(bool enabled) {
    if (enabled) HapticFeedback.lightImpact();
  }
  
  static void mediumImpactWithFlag(bool enabled) {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void selectionClickWithFlag(bool enabled) {
    if (enabled) HapticFeedback.selectionClick();
  }
}

// Extension to make it even easier to use from ConsumerWidget
extension HapticExtension on WidgetRef {
  void hapticLight() => AppHaptics.lightImpact(this);
  void hapticMedium() => AppHaptics.mediumImpact(this);
  void hapticHeavy() => AppHaptics.heavyImpact(this);
  void hapticSelection() => AppHaptics.selectionClick(this);
  void hapticVibrate() => AppHaptics.vibrate(this);
  
  // Premium semantic aliases
  void hapticSuccess() => AppHaptics.success(this);
  void hapticError() => AppHaptics.error(this);
  void hapticAction() => AppHaptics.action(this);
}
