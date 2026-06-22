// Privacy regression guard: in Private mode, CRUD must touch ONLY the local
// store and NEVER Supabase.
//
// The whole point of this test is what it deliberately does NOT do: it never
// calls `Supabase.initialize`. So `Supabase.instance` is uninitialised — any
// code path that reached for the Supabase client would throw (AssertionError /
// "You must initialize the supabase instance before calling Supabase.instance").
// We swap the real on-device store for a fake (via the `PrivateDataStore`
// interface) that records writes, then drive each mode-aware provider's CRUD
// entrypoint. Each case asserts two things:
//   1. the operation completes without throwing (no Supabase touched), and
//   2. the fake recorded the expected local write.
// If someone ever lets a Private-mode branch fall through to Supabase, this
// test fails loudly instead of silently leaking private data to the network.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/models/macro_goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/macro_goal_categories_provider.dart';
import 'package:mattioli_os/providers/macro_goals_provider.dart';
import 'package:mattioli_os/providers/mood_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_private_data_store.dart';

Goal _sampleGoal() => Goal(
      id: 'g1',
      title: 'Test Habit',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 6, 23),
    );

MacroGoal _sampleMacroGoal() => MacroGoal(
      id: 'm1',
      title: 'Test Macro Goal',
      status: GoalStatus.active,
      type: GoalType.weekly,
      year: 2026,
      month: 6,
      weekNumber: 3,
      createdAt: DateTime(2026, 6, 23),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, FakePrivateDataStore)> privateContainer() async {
    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final prefs = await SharedPreferences.getInstance();
    final fake = FakePrivateDataStore();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        // The interface extraction is what makes this swap possible.
        privateLocalDatabaseProvider.overrideWith((ref) => fake),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
      ],
    );
    addTearDown(container.dispose);
    return (container, fake);
  }

  // Each mode-aware notifier kicks off an async `_loadFromPrivateStore()` from
  // its build(). Let that settle before driving CRUD so the (legitimate)
  // optimistic state update isn't clobbered by the still-in-flight load — a
  // test ordering artifact, not the behaviour under test.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('Private mode CRUD never calls Supabase', () {
    test('adding a habit writes to the local store only', () async {
      final (container, fake) = await privateContainer();
      container.read(goalsProvider.notifier);
      await settle();

      await expectLater(
        container.read(goalsProvider.notifier).addHabit(_sampleGoal()),
        completes,
      );

      expect(fake.calls, contains('upsertGoal'));
      expect(container.read(goalsProvider), contains(isA<Goal>()));
    });

    test('cycling a habit status writes to the local store only', () async {
      final (container, fake) = await privateContainer();
      // cycleStatus also reads goalsProvider for the streak; settle both.
      container.read(goalsProvider.notifier);
      container.read(habitLogsProvider.notifier);
      await settle();

      // First cycle on an untracked day -> 'done', which persists a log.
      await expectLater(
        container
            .read(habitLogsProvider.notifier)
            .cycleStatus(DateTime(2026, 6, 23), 'g1'),
        completes,
      );

      expect(fake.calls, contains('setHabitLog'));
    });

    test('adding a macro goal writes to the local store only', () async {
      final (container, fake) = await privateContainer();
      container.read(macroGoalsProvider.notifier);
      await settle();

      await expectLater(
        container.read(macroGoalsProvider.notifier).addGoal(_sampleMacroGoal()),
        completes,
      );

      expect(fake.calls, contains('upsertMacroGoal'));
      expect(container.read(macroGoalsProvider).goals, isNotEmpty);
    });

    test('saving a mood writes to the local store only', () async {
      final (container, fake) = await privateContainer();
      container.read(dailyMoodsProvider.notifier);
      await settle();

      await expectLater(
        container
            .read(dailyMoodsProvider.notifier)
            .saveMood(DateTime(2026, 6, 23), 7, 6),
        completes,
      );

      expect(fake.calls, contains('saveMood'));
      expect(container.read(dailyMoodsProvider), isNotEmpty);
    });

    test('adding a macro goal category writes to the local store only',
        () async {
      final (container, fake) = await privateContainer();

      final id = await container
          .read(macroGoalCategoriesProvider.notifier)
          .addCategory('Health', '#FFFFFF');

      expect(id, isNotNull);
      expect(fake.calls, contains('addMacroGoalCategory'));
    });
  });
}
