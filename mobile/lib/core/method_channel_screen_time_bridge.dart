import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/services.dart';

/// Production [ScreenTimeBridge] over a MethodChannel to native Swift
/// (`evolve/screentime`). Marshals the contract only.
///
/// Degrades safely when the native plugin is absent: status is `notDetermined`,
/// `drainSignals` is empty, and mutations no-op — so a build without the
/// DeviceActivity extension (feature flag off, or the Family Controls
/// entitlement not yet approved) can't crash. A native monitor-count overflow is
/// surfaced as [ScreenTimeMonitorLimitException] (Apple's 20-activity cap, D10).
class MethodChannelScreenTimeBridge implements ScreenTimeBridge {
  static const MethodChannel channel = MethodChannel('evolve/screentime');

  const MethodChannelScreenTimeBridge();

  @override
  Future<ScreenTimeAuthorizationStatus> authorizationStatus() async {
    try {
      final raw = await channel.invokeMethod<String>('authorizationStatus');
      return _authFromWire(raw);
    } on MissingPluginException {
      return ScreenTimeAuthorizationStatus.notDetermined;
    }
  }

  @override
  Future<void> requestIndividualAuthorization() async {
    try {
      await channel.invokeMethod<void>('requestIndividualAuthorization');
    } on MissingPluginException {
      // no-op
    }
  }

  @override
  Future<ScreenTimeSelectionResult?> presentActivityPicker({
    String? initialSelectionBlob,
    String? pickerTitle,
    String? doneLabel,
    String? cancelLabel,
  }) async {
    try {
      final raw = await channel.invokeMethod<Map<Object?, Object?>>(
        'presentActivityPicker',
        {
          'selection': initialSelectionBlob,
          'title': pickerTitle,
          'done': doneLabel,
          'cancel': cancelLabel,
        },
      );
      if (raw == null) return null; // cancelled
      final m = Map<String, Object?>.from(raw);
      final blob = m['blob'] as String?;
      if (blob == null) return null;
      return ScreenTimeSelectionResult(
        blob: blob,
        applicationCount: (m['appCount'] as num?)?.toInt() ?? 0,
        categoryCount: (m['categoryCount'] as num?)?.toInt() ?? 0,
      );
    } on MissingPluginException {
      // Picker unavailable (dark build / entitlement absent / pre-iOS 16).
      return null;
    }
  }

  @override
  Future<void> setLocalizedNotificationCopy({
    required String title,
    required String body,
  }) async {
    try {
      await channel.invokeMethod<void>('setLocalizedNotificationCopy', {
        'title': title,
        'body': body,
      });
    } on MissingPluginException {
      // no-op: no extension to read the copy.
    }
  }

  @override
  Future<void> syncMonitoredGoals(List<ScreenTimeGoalSpec> specs) async {
    try {
      await channel.invokeMethod<void>('syncMonitoredGoals', {
        'goals': [
          for (final s in specs)
            {
              'goalId': s.goalId,
              'thresholdMinutes': s.thresholdMinutes,
              'weekdays': s.activeWeekdays.toList()..sort(),
              'mode': s.mode.wireName,
              // Opaque base64 FamilyActivitySelection; null for total-usage.
              'selection': s.selectionBlob,
            },
        ],
      });
    } on MissingPluginException {
      // no-op: nothing is being monitored without the native extension.
    } on PlatformException catch (e) {
      if (e.code == 'monitor_limit') {
        final details = e.details;
        final map = details is Map ? details : const {};
        throw ScreenTimeMonitorLimitException(
          (map['attempted'] as num?)?.toInt() ?? specs.length,
          limit: (map['limit'] as num?)?.toInt() ?? 20,
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<ScreenTimeSignal>> drainSignals() async {
    try {
      final raw =
          await channel.invokeListMethod<Map<Object?, Object?>>('drainSignals');
      if (raw == null) return const [];
      final out = <ScreenTimeSignal>[];
      for (final entry in raw) {
        final m = Map<String, Object?>.from(entry);
        final goalId = m['goalId'] as String?;
        final date = m['date'] as String?;
        final kind = _kindFromWire(m['kind'] as String?);
        if (goalId == null || date == null || kind == null) continue; // skip malformed
        out.add(ScreenTimeSignal(goalId: goalId, day: _parseDate(date), kind: kind));
      }
      return out;
    } on MissingPluginException {
      return const [];
    }
  }

  static ScreenTimeAuthorizationStatus _authFromWire(String? s) => switch (s) {
        'approved' => ScreenTimeAuthorizationStatus.approved,
        'denied' => ScreenTimeAuthorizationStatus.denied,
        _ => ScreenTimeAuthorizationStatus.notDetermined,
      };

  static ScreenTimeSignalKind? _kindFromWire(String? s) => switch (s) {
        'reachedThreshold' => ScreenTimeSignalKind.reachedThreshold,
        'stayedUnder' => ScreenTimeSignalKind.stayedUnder,
        _ => null,
      };

  static DateTime _parseDate(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}
