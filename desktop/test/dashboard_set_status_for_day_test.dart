// DashboardController.setHabitStatusForDay and recomputeStreaksForHabits —
// the two writes behind the day-detail dialog's Save on a day older than
// yesterday. `toggleHabitForDay` advances a cycle from wherever the row is; a
// batch of staged rows must land each one exactly as staged, so this path takes
// the destination. Driven over a recording repository, no database.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/calendar_days.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every status write with the status the repository LANDED on, so a
/// test can assert the destination and not only the argument.
class _RecordingRepository extends DashboardRepository {
  _RecordingRepository(this._snapshot);

  DashboardSnapshot _snapshot;
  final List<({String habitId, String date, String? landed})> statusWrites =
      [];
  final List<Set<String>> recomputes = [];

  @override
  DashboardSnapshot load() => _snapshot;

  /// Kept, like the real local cache: the controller's background refresh
  /// reloads from here, and a no-op save would hand the seed back over the
  /// optimistic state the test just observed.
  @override
  Future<void> save(DashboardSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<String?> setHabitStatus({
    required String habitId,
    required DateTime date,
    required String? currentStatus,
  }) async {
    final landed = await super.setHabitStatus(
      habitId: habitId,
      date: date,
      currentStatus: currentStatus,
    );
    statusWrites.add(
      (habitId: habitId, date: dashboardDateKey(date), landed: landed),
    );
    return landed;
  }

  @override
  Future<void> recomputeStreaks(Set<String> habitIds) async {
    recomputes.add(habitIds);
  }
}

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final oldDay = shiftDays(today, -10);
  final oldKey = dashboardDateKey(oldDay);

  DashboardHabit habit({VerificationRule? rule, int streak = 0}) =>
      DashboardHabit(
        id: 'walk',
        title: 'Passeggiata',
        color: EvolveColors.primaryStrong,
        streak: streak,
        weeklyProgress: const [false, false, false, false, false, false, false],
        state: HabitState.pending,
        startDate: DateTime(2020, 1, 1),
        verificationRule: rule,
      );

  DashboardSnapshot snapshot({
    DashboardHabit? habit,
    Map<String, Map<String, String>> logs = const {},
  }) =>
      DashboardSnapshot(
        habits: [?habit],
        goals: const [],
        trend: const [],
        checkIn: const DailyCheckIn(),
        habitLogs: logs,
      );

  (ProviderContainer, _RecordingRepository) build(DashboardSnapshot seed) {
    final repo = _RecordingRepository(seed);
    final container = ProviderContainer(
      overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return (container, repo);
  }

  test('writes the given status directly, not the next one in the cycle',
      () async {
    final (c, repo) = build(snapshot(
      habit: habit(),
      logs: {
        oldKey: {'walk': 'done'},
      },
    ));
    final controller = c.read(dashboardControllerProvider.notifier);

    expect(await controller.setHabitStatusForDay('walk', oldDay, 'missed'),
        isTrue);

    expect(c.read(dashboardControllerProvider).habitStatusFor('walk', oldDay),
        'missed');
    expect(repo.statusWrites, hasLength(1));
    expect(repo.statusWrites.single.date, oldKey);
    expect(repo.statusWrites.single.landed, 'missed',
        reason: 'the repository must land on the staged status itself, '
            'through the same cycle-advancing write a tap uses');
  });

  test('a null status clears the row', () async {
    final (c, repo) = build(snapshot(
      habit: habit(),
      logs: {
        oldKey: {'walk': 'missed'},
      },
    ));
    final controller = c.read(dashboardControllerProvider.notifier);

    expect(await controller.setHabitStatusForDay('walk', oldDay, null), isTrue);

    expect(c.read(dashboardControllerProvider).habitStatusFor('walk', oldDay),
        isNull);
    expect(repo.statusWrites.single.landed, isNull);
  });

  test('a row already at the status is a true no-op', () async {
    final (c, repo) = build(snapshot(
      habit: habit(),
      logs: {
        oldKey: {'walk': 'done'},
      },
    ));
    final controller = c.read(dashboardControllerProvider.notifier);

    expect(await controller.setHabitStatusForDay('walk', oldDay, 'done'),
        isFalse);
    expect(repo.statusWrites, isEmpty);
  });

  test('a verified habit is refused: its verdict is owned by the iPhone',
      () async {
    const rule = VerificationRule(
      provider: VerificationProvider.healthKit,
      metricKey: 'steps',
      comparator: VerificationComparator.atLeast,
      threshold: 8000,
      unit: VerificationUnit.count,
    );
    final (c, repo) = build(snapshot(habit: habit(rule: rule)));
    final controller = c.read(dashboardControllerProvider.notifier);

    expect(await controller.setHabitStatusForDay('walk', oldDay, 'done'),
        isFalse);
    expect(repo.statusWrites, isEmpty);
    expect(c.read(dashboardControllerProvider).habitStatusFor('walk', oldDay),
        isNull);
  });

  test('the headline streak is recomputed as of today, whatever day changed',
      () async {
    // Today and yesterday done, the day before missing: a run of 2. Filling
    // the gap makes it 3 — and the STREAK column must say so at once.
    final dayBefore = shiftDays(today, -2);
    final (c, _) = build(snapshot(
      habit: habit(streak: 2),
      logs: {
        dashboardDateKey(today): {'walk': 'done'},
        dashboardDateKey(shiftDays(today, -1)): {'walk': 'done'},
      },
    ));
    final controller = c.read(dashboardControllerProvider.notifier);

    await controller.setHabitStatusForDay('walk', dayBefore, 'done');

    expect(c.read(dashboardControllerProvider).habits.single.streak, 3);
  });

  test('recomputeStreaksForHabits hands the changed habits to the repository '
      'and skips an empty set', () async {
    final (c, repo) = build(snapshot(habit: habit()));
    final controller = c.read(dashboardControllerProvider.notifier);

    await controller.recomputeStreaksForHabits(const {});
    expect(repo.recomputes, isEmpty);

    await controller.recomputeStreaksForHabits({'walk'});
    expect(repo.recomputes, [
      {'walk'},
    ]);
  });

  test('setHabitStatusTo inverts the cycle exactly once per destination', () {
    // The base repository lands on the destination by feeding its predecessor
    // to the cycle-advancing write. Pin all three so no destination can drift.
    expect(DashboardRepository.nextManualStatus(null), 'done');
    expect(DashboardRepository.nextManualStatus('done'), 'missed');
    expect(DashboardRepository.nextManualStatus('missed'), isNull);
  });
}
