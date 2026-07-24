import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/widgets/target_entry_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_private_data_store.dart';

/// A fake that actually PERSISTS progress/logs, so the provider's async
/// `_loadFromPrivateStore` (scheduled when the widget first watches it) returns
/// the written value instead of empty — otherwise a late reload would wipe the
/// optimistic increment mid-test.
class _StatefulStore extends FakePrivateDataStore {
  final Map<String, Map<String, double>> _progress = {};
  final Map<String, Map<String, String>> _logs = {};

  @override
  Future<Map<String, Map<String, double>>> loadHabitProgress() async => {
        for (final e in _progress.entries) e.key: Map.of(e.value),
      };

  @override
  Future<void> setHabitProgress({
    required String goalId,
    required String date,
    required double amount,
    String source = 'manual',
  }) async {
    (_progress[date] ??= {})[goalId] = amount;
  }

  @override
  Future<void> deleteHabitProgress({
    required String goalId,
    required String date,
  }) async {
    _progress[date]?.remove(goalId);
  }

  @override
  Future<Map<String, Map<String, String>>> loadHabitLogs() async => {
        for (final e in _logs.entries) e.key: Map.of(e.value),
      };

  @override
  Future<void> setHabitLog({
    required String goalId,
    required String date,
    required String status,
    int streak = 0,
    double? value,
  }) async {
    (_logs[date] ??= {})[goalId] = status;
  }

  @override
  Future<void> deleteHabitLog({
    required String goalId,
    required String date,
  }) async {
    _logs[date]?.remove(goalId);
  }
}

Goal _habit(HabitTarget target) => Goal(
      id: 'g1',
      title: 'Push-ups',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 7, 1),
      target: target,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Widget> app(Goal habit, DateTime date) async {
    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        privateLocalDatabaseProvider.overrideWith((ref) => _StatefulStore()),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
        initialProgressProvider.overrideWithValue('{}'),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.lightTheme(null),
          home: Scaffold(
            body: TargetEntrySheet(
              habit: habit,
              target: habit.target!,
              date: date,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the + button increments progress by the target step',
      (tester) async {
    final target =
        TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 20);
    await tester.pumpWidget(await app(_habit(target), DateTime.now()));
    await tester.pumpAndSettle();

    // Starts at 0.
    expect(find.text('0'), findsOneWidget);

    // Tap the emphasised + button (the second/last big step button).
    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();
    expect(find.text('20'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();
    expect(find.text('40'), findsOneWidget);
  });

  testWidgets('the − button is disabled at zero and re-enabled after a step',
      (tester) async {
    final target = TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 20);
    await tester.pumpWidget(await app(_habit(target), DateTime.now()));
    await tester.pumpAndSettle();

    // At zero, decrementing does nothing (button disabled → stays 0).
    await tester.tap(find.byIcon(LucideIcons.minus), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);

    // Step up then back down to zero.
    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();
    expect(find.text('20'), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.minus));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('exposes increment/decrement accessibility actions', (tester) async {
    final target = TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 20);
    await tester.pumpWidget(await app(_habit(target), DateTime.now()));
    await tester.pumpAndSettle();

    // The stepper carries real increase/decrease actions + a spoken value — the
    // affordance the day-card (excludeSemantics: true) cannot provide.
    var foundIncrease = false;
    var foundDecrease = false;
    void visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (data.hasAction(SemanticsAction.increase)) foundIncrease = true;
      if (data.hasAction(SemanticsAction.decrease)) foundDecrease = true;
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
    expect(foundIncrease, isTrue);
    expect(foundDecrease, isTrue);
  });
}
