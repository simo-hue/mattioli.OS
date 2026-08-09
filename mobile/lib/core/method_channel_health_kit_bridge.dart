import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Production [HealthKitBridge] over a MethodChannel to native Swift
/// (`evolve/healthkit`). It marshals the contract only — all reconcile/verdict
/// logic stays in Dart (`VerificationService`).
///
/// Degrades **safely** when the native plugin is absent (feature flag off, or a
/// Screen-Time-only build): reads return null/false and mutations no-op, so a
/// missing plugin can never crash the app or fabricate a verdict. A null
/// [dailyQuantity] is exactly what routes a day to couldn't-verify/pending.
///
/// The day is passed as an explicit local `[startMs, endMs)` epoch-millisecond
/// window (computed with DST-safe calendar math) so the native `HKStatisticsQuery`
/// predicate is unambiguous across the channel.
class MethodChannelHealthKitBridge implements HealthKitBridge {
  static const MethodChannel channel = MethodChannel('evolve/healthkit');

  const MethodChannelHealthKitBridge();

  /// The Apple identifier whose measurement window is a NIGHT, not a calendar
  /// day.
  ///
  /// The whole rule lives on THIS side: native does nothing sleep-specific, and
  /// its predicate is an unchanged `.strictStartDate`. Only [windowFor] knows
  /// sleep is different.
  static const String sleepTypeId = 'sleepAnalysis';

  /// The hour a "sleep day" begins, on the PREVIOUS calendar day.
  ///
  /// The sleep window is a full 24 hours — `[D-1 18:00, D 18:00)` — not a
  /// truncated night. That is what makes it safe under the native side's
  /// unchanged `.strictStartDate` predicate: every sample falls in exactly ONE
  /// window, so nothing is double-counted across adjacent days and, critically,
  /// nothing is truncated by a window edge. A shorter window (say closing at
  /// noon) would clip a 05:00→14:00 sleep down to 7 hours and score a false
  /// `missed` against a "sleep ≥ 8h" rule — an under-count reported as a
  /// measurement, which invariant 3 forbids.
  ///
  /// 18:00 is the boundary because it is the one hour of the day almost nobody
  /// starts a sleep: an evening onset (22:00) lands in the NEXT day's window,
  /// which is the day the sleeper wakes, and an afternoon nap or a late-morning
  /// lie-in stays with the day it happened on.
  static const int _sleepDayStartsAtHour = 18;

  /// The local `[start, end)` window a day's measurement is read over.
  ///
  /// A calendar day for every metric EXCEPT sleep. Sleep is attributed to the
  /// day you WAKE, which a midnight-to-midnight window gets wrong for everyone
  /// who falls asleep before midnight: the native predicate is
  /// `.strictStartDate`, so the sample is filed under the day it STARTED, and
  /// last night's sleep landed on yesterday while today read empty until you
  /// slept past midnight. A "sleep ≥ 8h" habit therefore never resolved on the
  /// day it was actually met, and an AND compound containing it could not
  /// complete at all.
  ///
  /// Shifting the boundary from midnight to 18:00 fixes that entirely on the
  /// Dart side: a 23:00 onset now starts inside the window of the day it ends
  /// on. The native query needs no change, and deliberately did not get one —
  /// switching sleep to overlap semantics plus per-sample clipping was tried and
  /// reverted, because clipping reports a truncated union AS a measurement,
  /// which is exactly the false `missed` described above.
  ///
  /// Built with `DateTime(y, m, d ± n)` rather than `Duration`, like every other
  /// day walk in this codebase: a `Duration` day is a fixed 24 hours and drifts
  /// off the intended wall-clock hour across a DST transition.
  ///
  /// Known and accepted: a sleep that BEGINS before 18:00 (a shift worker going
  /// to bed at 17:00) is attributed to the previous day. It is counted in full
  /// and counted once — wrong day, never a wrong number.
  @visibleForTesting
  static (DateTime start, DateTime end) windowFor(
    String typeIdentifier,
    DateTime day,
  ) =>
      typeIdentifier == sleepTypeId
          ? (
              DateTime(
                  day.year, day.month, day.day - 1, _sleepDayStartsAtHour),
              DateTime(day.year, day.month, day.day, _sleepDayStartsAtHour),
            )
          : (
              DateTime(day.year, day.month, day.day),
              DateTime(day.year, day.month, day.day + 1),
            );

  @override
  Future<bool> isHealthDataAvailable() async {
    try {
      final v = await channel.invokeMethod<bool>('isHealthDataAvailable');
      return v ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> requestAuthorization(Set<String> typeIdentifiers) async {
    try {
      await channel.invokeMethod<void>('requestAuthorization', {
        'types': typeIdentifiers.toList(),
      });
    } on MissingPluginException {
      // no-op: authorization simply hasn't been granted.
    }
  }

  @override
  Future<double?> dailyQuantity({
    required String typeIdentifier,
    required VerificationAggregation aggregation,
    required DateTime day,
  }) async {
    try {
      final (start, end) = windowFor(typeIdentifier, day);
      final v = await channel.invokeMethod('dailyQuantity', {
        'type': typeIdentifier,
        'aggregation': aggregation.wireName,
        'startMs': start.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
      });
      // Coerce int/double NSNumber → double; null (no data / can't determine)
      // passes straight through.
      return (v as num?)?.toDouble();
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> hasRecentData({
    required String typeIdentifier,
    required int withinDays,
  }) async {
    try {
      final v = await channel.invokeMethod<bool>('hasRecentData', {
        'type': typeIdentifier,
        'withinDays': withinDays,
      });
      return v ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}
