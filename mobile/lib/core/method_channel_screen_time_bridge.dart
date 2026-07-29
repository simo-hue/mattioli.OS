import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_logger.dart';

/// Production [ScreenTimeBridge] over a MethodChannel to native Swift
/// (`evolve/screentime`).
///
/// Mostly marshalling, but it also owns the decode policy for drained signals —
/// recency plausibility, per-row containment and aggregated drop telemetry —
/// because the native drain is destructive and this is the last place a bad row
/// can be isolated before it costs the whole batch.
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
    // Declared OUTSIDE the try so a failure part-way through the batch can still
    // return what was decoded before it. The drain is destructive; rows already
    // read are the only copy that will ever exist.
    final out = <ScreenTimeSignal>[];
    var dropped = 0;
    try {
      // `invokeListMethod` would give a LAZY `CastList`, whose element type check
      // fires during ITERATION — outside the per-row guard below, so a single
      // non-map element would discard every good row decoded before it. Take the
      // list untyped and let the per-row decode do the rejecting.
      final raw = await channel.invokeMethod<List<Object?>>('drainSignals');
      if (raw == null) return const [];
      for (final entry in raw) {
        // Per-row containment. The native drain is DESTRUCTIVE and
        // DeviceActivity has no re-query API, so anything that escapes this loop
        // loses the whole batch permanently. The App Group is read untyped on
        // the native side (`as? [[String: Any]]`), so `Object?` is the only real
        // contract and a cast is a live throw. One bad row costs only itself.
        try {
          if (entry is! Map) {
            dropped++;
            continue;
          }
          final m = Map<String, Object?>.from(entry);
          final goalId = m['goalId'];
          final day = _dayFrom(m);
          final kind = _kindFromWire(m['kind']);
          if (goalId is! String || day == null || kind == null) {
            dropped++;
            if (kDebugMode) {
              debugPrint('[Verification] dropped an unreadable signal: $m');
            }
            continue;
          }
          out.add(ScreenTimeSignal(goalId: goalId, day: day, kind: kind));
        } catch (e) {
          dropped++;
          if (kDebugMode) {
            debugPrint('[Verification] dropped a malformed signal row: $e');
          }
        }
      }
      return out;
    } on MissingPluginException {
      return const [];
    } catch (e, stack) {
      // The reply shape itself was unreadable. Return what was decoded BEFORE
      // the failure rather than `const []`: those rows are already gone from the
      // App Group and this is the only chance to act on them.
      AppLogger.error('[Verification] drainSignals decode failed', e, stack);
      return out;
    } finally {
      // Aggregated, not per row. `AppLogger.warning` captures a Sentry EVENT in
      // release, and the drop count is unbounded — an app left closed for months
      // presents one buffered interval row per goal per day, every one of them
      // beyond the recency window. One event per drain, never one per row.
      //
      // Wrapped, because a `finally` is the one place an exception REPLACES the
      // pending return and propagates out of the whole try statement. An
      // unguarded throw here would escape past this function's own catch and
      // destroy the surviving rows — the exact failure this function is built to
      // prevent, reintroduced by the telemetry that watches for it, at the one
      // moment it is guaranteed to fire (something already went wrong).
      if (dropped > 0) {
        try {
          AppLogger.warning(
            '[Verification] dropped $dropped of ${dropped + out.length} '
            'Screen Time signals examined as unreadable',
          );
        } catch (_) {
          // Telemetry must never cost data.
        }
      }
    }
  }

  static ScreenTimeAuthorizationStatus _authFromWire(String? s) => switch (s) {
        'approved' => ScreenTimeAuthorizationStatus.approved,
        'denied' => ScreenTimeAuthorizationStatus.denied,
        _ => ScreenTimeAuthorizationStatus.notDetermined,
      };

  static ScreenTimeSignalKind? _kindFromWire(Object? s) => switch (s) {
        'reachedThreshold' => ScreenTimeSignalKind.reachedThreshold,
        'stayedUnder' => ScreenTimeSignalKind.stayedUnder,
        _ => null,
      };

  /// The day a drained signal is for, or null if the row does not carry a
  /// readable one.
  ///
  /// Prefers the `y`/`m`/`d` integer components the extension writes: those have
  /// no calendar, locale or era left in them, so they cannot be misread. Falls
  /// back to the legacy `date` string, which an extension binary from before the
  /// components existed may still have left in the App Group buffer across an
  /// app update — the bundle updates atomically, the buffer does not.
  static DateTime? _dayFrom(Map<String, Object?> m) {
    final y = (m['y'] as num?)?.toInt();
    final mo = (m['m'] as num?)?.toInt();
    final d = (m['d'] as num?)?.toInt();
    if (y != null && mo != null && d != null) return _day(y, mo, d);
    return _parseDateKey(m['date']);
  }

  /// Parses a legacy `yyyy-MM-dd` day key. Total on purpose — see the per-row
  /// containment in [drainSignals].
  static DateTime? _parseDateKey(Object? s) {
    if (s is! String) return null;
    final p = s.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return _day(y, m, d);
  }

  /// Validates a (year, month, day) triple into a real, plausible signal day.
  ///
  /// The plausibility check is by PROXIMITY, not magnitude. A non-Gregorian day
  /// key parses as perfectly good integers, and no fixed year range separates
  /// them from real ones — Ethiopic renders 2026 as **2018**, which any
  /// "sane-looking year" bound would wave through, filing the signal eight years
  /// in the past. What actually characterises a real signal is that it is
  /// recent: the extension stamps the day it fires, and the buffer only holds
  /// what has accumulated since the app was last opened. Anything outside a
  /// generous recency window is corrupt, whatever its year looks like.
  static DateTime? _day(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final parsed = DateTime(y, m, d);
    // Reject a rolled-over date (2026-02-31 → 2026-03-03) rather than silently
    // filing the signal on the wrong day.
    if (parsed.year != y || parsed.month != m || parsed.day != d) return null;
    final now = DateTime.now();
    // Component arithmetic, not `Duration`: a `Duration` day is a fixed 24h, so
    // adding it to a local midnight lands at 23:00 or 01:00 across a DST change.
    // Same reason `VerificationService._nextDay` avoids it.
    final floor = DateTime(now.year, now.month, now.day - 400);
    final ceiling = DateTime(now.year, now.month, now.day + 2);
    // Generous on the past side (an app left unopened accumulates one interval
    // signal per goal per day), tight on the future side — only a wake just past
    // midnight, or a timezone shift of at most 26 hours, can legitimately land
    // ahead of today.
    if (parsed.isBefore(floor) || parsed.isAfter(ceiling)) return null;
    return parsed;
  }
}
