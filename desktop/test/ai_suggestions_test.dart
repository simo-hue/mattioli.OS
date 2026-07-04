// Item 5 — AI Coach suggested prompts. Tests the pure selection logic
// (time-of-day + context switches + deterministic rotation).
import 'package:evolve_desktop/features/ai_coach/presentation/ai_coach_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.it));

  List<String> build({
    int hour = 9,
    bool shareGoals = false,
    bool shareHabits = true,
    bool hasActiveGoals = true,
    int todayDone = 1,
    int todayTotal = 3,
    int messageCount = 0,
  }) => buildAiSuggestions(
    hour: hour,
    shareGoals: shareGoals,
    shareHabits: shareHabits,
    hasActiveGoals: hasActiveGoals,
    todayDone: todayDone,
    todayTotal: todayTotal,
    messageCount: messageCount,
  );

  test('returns up to four unique suggestions', () {
    final s = build();
    expect(s.length, 4);
    expect(s.toSet().length, s.length); // no duplicates
  });

  test('morning + habits-only surfaces morning + habit prompts', () {
    final s = build(hour: 9, shareGoals: false, shareHabits: true);
    expect(s.first, t.ai.suggestions.morningBoost); // offset 0
    expect(s, contains(t.ai.suggestions.consistencyStatus));
  });

  test('evening + goals-only surfaces evening + goal prompts', () {
    final s = build(hour: 21, shareGoals: true, shareHabits: false);
    expect(s, contains(t.ai.suggestions.prepareTomorrow));
    expect(s, contains(t.ai.suggestions.analyzeActiveGoals));
    expect(s.length, 4);
    expect(s.toSet().length, 4);
  });

  test('messageCount rotates the selection deterministically', () {
    final a = build(messageCount: 0);
    final b = build(messageCount: 1);
    expect(a, isNot(equals(b)));
    // Stable for the same inputs.
    expect(build(messageCount: 0), equals(a));
  });

  test('no switches falls back to generic discipline prompts', () {
    final s = build(hour: 20, shareGoals: false, shareHabits: false);
    expect(s.length, 4);
    expect(s.toSet().length, 4);
    expect(
      s.any(
        (x) => [
          t.ai.suggestions.disciplineAdvice,
          t.ai.suggestions.createNewHabit,
        ].contains(x),
      ),
      isTrue,
    );
  });
}
