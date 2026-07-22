import 'package:mattioli_os/i18n/translations.g.dart';

/// A single AI-coach starter prompt.
///
/// [label] is the short, tappable chip text (carries a leading emoji); [payload]
/// is the message actually sent to the model — a data-personalized question
/// engineered to elicit an actionable answer. The two are deliberately
/// decoupled: the chip stays scannable while the payload can carry real numbers
/// and ask for the shape of answer the user benefits from. Kept in lock-step
/// with the desktop copy (`desktop/lib/features/ai_coach/domain/coach_prompts.dart`).
class CoachPrompt {
  const CoachPrompt({required this.label, required this.payload});

  final String label;
  final String payload;
}

/// Pre-computed, locale-independent facts that [buildCoachPrompts] selects from.
///
/// Built in the presentation layer from live providers (habits, macro goals,
/// habit logs) and the user's share toggles, so the selection itself stays a
/// pure, unit-testable function of its inputs.
class CoachPromptFacts {
  const CoachPromptFacts({
    this.weakestHabit,
    this.momentum,
    this.bestStreak,
    this.topGoalTitle,
    this.habitCount = 0,
    this.activeGoalCount = 0,
    this.shareHabits = false,
    this.shareGoals = false,
    this.allGreen = false,
    this.isEmpty = false,
    this.rotation = 0,
  });

  /// The scheduled habit with the lowest completion so far this week, present
  /// only when it has at least one miss. `done`/`scheduled` count the days
  /// elapsed this week (Monday..today).
  final ({String title, int done, int scheduled})? weakestHabit;

  /// This- vs last-week habit completion as whole percentages, present only
  /// when there is enough history to make the comparison meaningful.
  final ({int thisPct, int lastPct})? momentum;

  /// The habit carrying the longest current positive streak, present only when
  /// it is long enough to be worth protecting.
  final ({String title, int days})? bestStreak;

  /// An active goal title, used by the build/connect prompts. Null when goals
  /// aren't shared or none are active.
  final String? topGoalTitle;

  final int habitCount;
  final int activeGoalCount;
  final bool shareHabits;
  final bool shareGoals;

  /// Every scheduled habit is done this week — nothing to diagnose.
  final bool allGreen;

  /// The user has no active goals and no habits at all (brand-new).
  final bool isEmpty;

  /// Rotates the evergreen tail so repeated opens vary (typically the message
  /// count). The salience tier is never rotated.
  final int rotation;
}

/// Selects up to four data-personalized coach prompts.
///
/// A fixed **salience tier** comes first — the user's most pressing thing
/// (a weak habit, a slipping week, a streak at risk), always in priority order.
/// An **evergreen tail** (build/connect a goal, level up, discover) fills any
/// remaining slots and is rotated by [CoachPromptFacts.rotation] so the strip
/// stays fresh and never empty. Pure and deterministic given the facts and the
/// active locale.
List<CoachPrompt> buildCoachPrompts(CoachPromptFacts f) {
  final cp = t.ai.coachPrompts;
  final ranked = <CoachPrompt>[];

  // ---- Salience tier: surface the user's most pressing thing first. ----
  final w = f.weakestHabit;
  if (w != null) {
    ranked.add(
      CoachPrompt(
        label: cp.diagnoseWeakestHabit.label,
        payload: cp.diagnoseWeakestHabit.payload(
          habit: w.title,
          done: w.done,
          scheduled: w.scheduled,
        ),
      ),
    );
  }
  final m = f.momentum;
  if (m != null) {
    final down = m.thisPct < m.lastPct;
    ranked.add(
      CoachPrompt(
        label: down ? cp.weeklyReviewDown.label : cp.weeklyReviewUp.label,
        payload: down
            ? cp.weeklyReviewDown.payload(
                thisPct: m.thisPct,
                lastPct: m.lastPct,
              )
            : cp.weeklyReviewUp.payload(thisPct: m.thisPct, lastPct: m.lastPct),
      ),
    );
  }
  final s = f.bestStreak;
  if (s != null) {
    ranked.add(
      CoachPrompt(
        label: cp.protectStreak.label,
        payload: cp.protectStreak.payload(habit: s.title, days: s.days),
      ),
    );
  }

  // ---- Evergreen tail: build/connect + discovery, rotated for freshness. ----
  final tail = <CoachPrompt>[];
  final goal = f.topGoalTitle;
  if (f.shareGoals && goal != null) {
    tail.add(
      CoachPrompt(
        label: cp.goalOnTrack.label,
        payload: cp.goalOnTrack.payload(goal: goal),
      ),
    );
    if (f.shareHabits && f.habitCount >= 2) {
      tail.add(
        CoachPrompt(
          label: cp.alignHabitsToGoal.label,
          payload: cp.alignHabitsToGoal.payload(goal: goal),
        ),
      );
    }
    tail.add(
      CoachPrompt(
        label: cp.designHabitForGoal.label,
        payload: cp.designHabitForGoal.payload(goal: goal),
      ),
    );
  }
  if (f.allGreen) {
    tail.add(
      CoachPrompt(label: cp.raiseTheBar.label, payload: cp.raiseTheBar.payload),
    );
  }
  if (f.isEmpty) {
    tail.add(
      CoachPrompt(label: cp.firstStep.label, payload: cp.firstStep.payload),
    );
  }
  // Always eligible, so the strip is never empty and a new user always has
  // something useful to tap.
  tail.add(
    CoachPrompt(
      label: cp.whatCanYouHelp.label,
      payload: cp.whatCanYouHelp.payload,
    ),
  );

  if (tail.isNotEmpty) {
    final offset = f.rotation % tail.length;
    for (var i = 0; i < tail.length; i++) {
      ranked.add(tail[(offset + i) % tail.length]);
    }
  }

  // De-dupe by payload and cap at four — the strip shows the four most salient.
  final seen = <String>{};
  final out = <CoachPrompt>[];
  for (final p in ranked) {
    if (seen.add(p.payload)) out.add(p);
    if (out.length == 4) break;
  }
  return out;
}
