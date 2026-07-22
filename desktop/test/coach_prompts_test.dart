// AI Coach starter prompts — pure, data-personalized selection.
// Salience tier (weak habit / slipping week / streak) leads; an evergreen tail
// (build-a-goal / level-up / discover) fills the rest and rotates for freshness.
import 'package:evolve_desktop/features/ai_coach/domain/coach_prompts.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));
  final cp = t.ai.coachPrompts;

  test('weakest habit leads and carries the real name + numbers', () {
    final prompts = buildCoachPrompts(
      const CoachPromptFacts(
        shareHabits: true,
        weakestHabit: (title: 'Meditation', done: 2, scheduled: 5),
        habitCount: 3,
      ),
    );
    expect(prompts.first.label, cp.diagnoseWeakestHabit.label);
    expect(prompts.first.payload, contains('Meditation'));
    expect(prompts.first.payload, contains('2/5'));
    expect(prompts.length, lessThanOrEqualTo(4));
  });

  test('momentum picks the down vs up variant by direction', () {
    final down = buildCoachPrompts(
      const CoachPromptFacts(
        shareHabits: true,
        habitCount: 2,
        momentum: (thisPct: 40, lastPct: 70),
      ),
    );
    final downPrompt = down.firstWhere(
      (p) => p.label == cp.weeklyReviewDown.label,
    );
    expect(downPrompt.payload, contains('40'));
    expect(downPrompt.payload, contains('70'));

    final up = buildCoachPrompts(
      const CoachPromptFacts(
        shareHabits: true,
        habitCount: 2,
        momentum: (thisPct: 80, lastPct: 60),
      ),
    );
    expect(up.any((p) => p.label == cp.weeklyReviewUp.label), isTrue);
    expect(up.any((p) => p.label == cp.weeklyReviewDown.label), isFalse);
  });

  test('caps at four, never duplicates, salience tier first', () {
    final prompts = buildCoachPrompts(
      const CoachPromptFacts(
        shareHabits: true,
        shareGoals: true,
        weakestHabit: (title: 'Run', done: 1, scheduled: 4),
        momentum: (thisPct: 50, lastPct: 80),
        bestStreak: (title: 'Read', days: 12),
        topGoalTitle: 'Ship v2',
        habitCount: 4,
        activeGoalCount: 2,
      ),
    );
    expect(prompts.length, 4);
    expect(prompts.map((p) => p.payload).toSet().length, 4);
    expect(prompts[0].label, cp.diagnoseWeakestHabit.label);
    expect(prompts[1].label, cp.weeklyReviewDown.label);
    expect(prompts[2].label, cp.protectStreak.label);
  });

  test('empty state offers the first-step + discovery prompts', () {
    final prompts = buildCoachPrompts(const CoachPromptFacts(isEmpty: true));
    final labels = prompts.map((p) => p.label);
    expect(labels, contains(cp.firstStep.label));
    expect(labels, contains(cp.whatCanYouHelp.label));
  });

  test('discovery prompt is always present so the strip is never empty', () {
    final prompts = buildCoachPrompts(const CoachPromptFacts());
    expect(prompts, isNotEmpty);
    expect(prompts.map((p) => p.label), contains(cp.whatCanYouHelp.label));
  });

  test('rotation reorders the evergreen tail deterministically', () {
    CoachPromptFacts facts(int r) => CoachPromptFacts(
      shareGoals: true,
      topGoalTitle: 'Ship v2',
      activeGoalCount: 1,
      rotation: r,
    );
    final a = buildCoachPrompts(facts(0)).map((p) => p.label).toList();
    final b = buildCoachPrompts(facts(1)).map((p) => p.label).toList();
    expect(a, isNot(equals(b)));
    // Stable for the same rotation.
    expect(buildCoachPrompts(facts(0)).map((p) => p.label).toList(), equals(a));
  });

  test('goal prompts require goals to be shared', () {
    final hidden = buildCoachPrompts(
      const CoachPromptFacts(
        shareGoals: false,
        topGoalTitle: 'Ship v2',
        activeGoalCount: 1,
      ),
    );
    expect(hidden.any((p) => p.label == cp.goalOnTrack.label), isFalse);
    expect(hidden.any((p) => p.label == cp.designHabitForGoal.label), isFalse);
  });

  test('align-habits prompt needs both goals and ≥2 habits shared', () {
    final prompts = buildCoachPrompts(
      const CoachPromptFacts(
        shareGoals: true,
        shareHabits: true,
        topGoalTitle: 'Ship v2',
        activeGoalCount: 1,
        habitCount: 3,
      ),
    );
    expect(prompts.any((p) => p.label == cp.alignHabitsToGoal.label), isTrue);
  });
}
