import 'package:evolve_verification/evolve_verification.dart';

/// Which direction a target is satisfied in.
///
/// Deliberately an ALIAS of [VerificationComparator], not a new enum: the two
/// concepts are the same concept. `atLeast` is "reach 80 push-ups" and equally
/// "reach 10 000 steps"; `atMost` is "stay under 1 coffee" and equally "stay
/// under 30 minutes of Instagram". A second enum with the same `gte`/`lte` wire
/// names would drift the first time one of them gained a value, and a rule and
/// a target would silently disagree about what `lte` means.
typedef TargetDirection = VerificationComparator;

/// The physical unit a target is measured in — an alias of [VerificationUnit]
/// for the same anti-drift reason as [TargetDirection].
typedef TargetUnit = VerificationUnit;

/// How a period's samples combine into the number compared against the target —
/// an alias of [VerificationAggregation]. `sum` adds quantities (reps, minutes,
/// kilometres); `count` counts qualifying events (workouts, sessions).
typedef TargetAggregation = VerificationAggregation;

/// Which side supplies a target's progress number.
///
/// This is the axis that makes a manually-counted habit and an auto-verified
/// one the same kind of object. The [wireName]s of the two measured sources are
/// EXACTLY [VerificationProvider]'s, so [targetFillSourceForProvider] is a
/// straight pass-through and a future provider needs no mapping table.
enum TargetFillSource {
  /// The user supplies the number by tapping / timing / typing.
  manual,

  /// HealthKit supplies it (iOS only — macOS never measures).
  healthKit,

  /// A Screen Time DeviceActivity monitor supplies it (iOS only).
  screenTime;

  String get wireName => switch (this) {
        TargetFillSource.manual => 'manual',
        TargetFillSource.healthKit => 'healthkit',
        TargetFillSource.screenTime => 'screentime',
      };

  static TargetFillSource? fromWire(String? value) => switch (value) {
        'manual' => TargetFillSource.manual,
        'healthkit' => TargetFillSource.healthKit,
        'screentime' => TargetFillSource.screenTime,
        _ => null,
      };

  /// Whether the number comes from a device sensor rather than the user.
  ///
  /// This is the predicate the privacy rule hangs off: a measured quantity is
  /// an Apple-health-derived measurement and must never be uploaded to
  /// Supabase, while a number the user typed is ordinary user content. Today
  /// that decision is made by guessing through the goal
  /// (`goal?.verificationRule?.isHealthKit ?? true`), which defaults an
  /// unresolvable goal to "health" and strips values it should keep. Storing
  /// the source ON the progress row makes the rule a fact rather than a guess.
  bool get isMeasured => this != TargetFillSource.manual;
}

/// Maps a verification provider onto the equivalent fill source. Total by
/// construction — the wire vocabularies are shared.
TargetFillSource targetFillSourceForProvider(VerificationProvider provider) =>
    switch (provider) {
      VerificationProvider.healthKit => TargetFillSource.healthKit,
      VerificationProvider.screenTime => TargetFillSource.screenTime,
    };

/// The window a target's progress accumulates over before resetting.
///
/// Only [day] is offered by the v1 preset catalog. [week] and [month] are
/// declared — and fully handled by [daysInPeriod] / [periodIsOver] / the codec —
/// so that "4 gym sessions per week" is an additive follow-up (one preset entry,
/// one accumulation query) rather than a model change. Nothing in this package
/// assumes a day.
enum TargetPeriod {
  day,
  week,
  month;

  String get wireName => name;

  static TargetPeriod? fromWire(String? value) {
    for (final p in TargetPeriod.values) {
      if (p.name == value) return p;
    }
    return null;
  }
}

/// The input affordance a target is entered through.
///
/// NOT derivable from [TargetUnit]: minutes can legitimately be entered with a
/// stepper ("+5 min" after a walk) or run down by a live timer, and the choice
/// changes the whole detail UI. Keeping it explicit means a future affordance
/// (a slider, a numeric keypad, a "log a set" sheet) is one enum value.
enum TargetInput {
  /// Discrete taps of [HabitTarget.step] — reps, sets, glasses, cigarettes.
  stepper,

  /// A start/stop stopwatch that adds elapsed time.
  timer;

  String get wireName => name;

  static TargetInput? fromWire(String? value) {
    for (final i in TargetInput.values) {
      if (i.name == value) return i;
    }
    return null;
  }
}

/// The calendar days whose progress accumulates into the period containing
/// [anchor], in ascending order.
///
/// Pure and timezone-naive by design: the caller passes local dates and gets
/// local dates back. [weekStartsOnMonday] threads the user's existing
/// `pref_start_week_on_monday` setting through rather than assuming ISO weeks,
/// because the app already lets the user choose and a period boundary that
/// disagrees with the calendar they are looking at is indefensible.
List<DateTime> daysInPeriod(
  TargetPeriod period,
  DateTime anchor, {
  bool weekStartsOnMonday = true,
}) {
  final day = DateTime(anchor.year, anchor.month, anchor.day);
  switch (period) {
    case TargetPeriod.day:
      return [day];
    case TargetPeriod.week:
      // DateTime.weekday is 1=Mon..7=Sun. Offset back to the configured first
      // day, then take seven consecutive days.
      final offset =
          weekStartsOnMonday ? day.weekday - 1 : day.weekday % DateTime.daysPerWeek;
      final start = day.subtract(Duration(days: offset));
      return [
        for (var i = 0; i < DateTime.daysPerWeek; i++)
          DateTime(start.year, start.month, start.day + i),
      ];
    case TargetPeriod.month:
      // Day 0 of the NEXT month is the last day of this one — the standard
      // trick that stays correct across leap years without a table.
      final lastDay = DateTime(day.year, day.month + 1, 0).day;
      return [
        for (var i = 1; i <= lastDay; i++) DateTime(day.year, day.month, i),
      ];
  }
}

/// Whether the period containing [anchor] has finished, as of [now].
///
/// This is the switch between "not there YET" and "did not make it": an
/// unfinished period is [TargetOutcome.pending], a finished one resolves. It is
/// also what stops a limit habit from being declared a success at breakfast —
/// staying under a daily cap is only knowable once the day is over, which is
/// exactly how the shipped auto-verified `atMost` path already behaves.
bool periodIsOver(TargetPeriod period, DateTime anchor, DateTime now) {
  final days = daysInPeriod(period, anchor);
  final last = days.last;
  final today = DateTime(now.year, now.month, now.day);
  return today.isAfter(last);
}
