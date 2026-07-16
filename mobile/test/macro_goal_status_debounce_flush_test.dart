import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/macro_goal.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/macro_goal_categories_provider.dart';
import 'package:mattioli_os/providers/macro_goals_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/widgets/macro_goals/goal_item_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records `updateStatus` calls instead of touching Supabase / the private DB.
class _RecordingMacroGoalsNotifier extends MacroGoalsNotifier {
  _RecordingMacroGoalsNotifier(this._initialGoals);

  final List<MacroGoal> _initialGoals;
  final List<({String id, GoalStatus status})> calls = [];

  @override
  MacroGoalsState build() => MacroGoalsState(goals: _initialGoals);

  @override
  Future<void> updateStatus(String id, GoalStatus status) async {
    calls.add((id: id, status: status));
  }
}

class _EmptyCategoriesNotifier extends MacroGoalCategoriesNotifier {
  @override
  Future<List<GoalCategory>> build() async => const [];
}

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isLoggedIn: false);
}

final _goal = MacroGoal(
  id: 'goal-1',
  title: 'Ship the release',
  status: GoalStatus.active,
  type: GoalType.weekly,
  createdAt: DateTime.utc(2026, 1, 1),
);

Future<_RecordingMacroGoalsNotifier> _pumpGoalItem(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final notifier = _RecordingMacroGoalsNotifier([_goal]);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
        macroGoalsProvider.overrideWith(() => notifier),
        macroGoalCategoriesProvider.overrideWith(_EmptyCategoriesNotifier.new),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(body: GoalItemWidget(goal: _goal)),
        ),
      ),
    ),
  );
  await tester.pump();
  return notifier;
}

void main() {
  testWidgets(
    'status tap is flushed when the item is disposed inside the debounce window',
    (tester) async {
      final notifier = await _pumpGoalItem(tester);

      await tester.tap(find.text('Ship the release'));
      await tester.pump();
      expect(
        notifier.calls,
        isEmpty,
        reason: 'the write is debounced, not immediate',
      );

      // Item leaves the filtered list well inside the 800ms window (period
      // arrows / swipe), so its State is disposed before the timer fires.
      await tester.pumpWidget(const SizedBox.shrink());

      expect(notifier.calls, [(id: 'goal-1', status: GoalStatus.completed)]);
    },
  );

  testWidgets('a tap that has already been persisted is not written twice', (
    tester,
  ) async {
    final notifier = await _pumpGoalItem(tester);

    await tester.tap(find.text('Ship the release'));
    await tester.pump(const Duration(milliseconds: 900));
    expect(notifier.calls, [(id: 'goal-1', status: GoalStatus.completed)]);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(
      notifier.calls,
      hasLength(1),
      reason: 'dispose must not re-fire an already-flushed timer',
    );
  });

  testWidgets('disposing without a pending tap writes nothing', (tester) async {
    final notifier = await _pumpGoalItem(tester);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(notifier.calls, isEmpty);
  });
}
