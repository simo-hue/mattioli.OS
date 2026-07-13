import 'package:flutter/foundation.dart';
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
    // Haptics are purely cosmetic and must never crash the app. Reading a
    // provider through `ref` after the owning widget has been disposed — e.g.
    // a haptic fired from a `finally` block once the user popped the screen —
    // throws "Bad state: Using ref ... unmounted". Swallow it here so no call
    // site can turn a missing buzz into a fatal exception. Call sites should
    // still guard with `if (mounted)` where possible; this is the backstop.
    try {
      final enabled = ref.read(settingsProvider).hapticFeedback;
      if (enabled) {
        hapticFn();
      }
    } catch (e) {
      // Debug-only: surface the misuse during development, stay silent (and
      // out of Sentry) in release builds.
      if (kDebugMode) {
        debugPrint('[AppHaptics] Skipped haptic: ref unavailable '
            '(widget disposed?): $e');
      }
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
