import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'private-mode dashboard loads its rows without an explicit refresh',
    () async {
      final repository = _LazyPrivateDashboardRepository();
      final container = ProviderContainer(
        overrides: [dashboardRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      // Mirrors what the shell does on launch: it only ever watches the
      // provider. Nothing calls refresh() on a normal private-mode open.
      expect(container.read(dashboardControllerProvider).habits, isEmpty);

      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(dashboardControllerProvider).habits.single.title,
        'Meditazione',
      );
      expect(repository.refreshCount, 1);
    },
  );
}

/// Stands in for `_PrivateRepositoryProxy`: [load] is empty until the async
/// [refresh] has resolved the owner ID and built the real repository, and
/// [isCloudBacked] stays false because the private DB is not cloud-backed.
class _LazyPrivateDashboardRepository extends DashboardRepository {
  int refreshCount = 0;
  DashboardSnapshot? _inner;

  @override
  DashboardSnapshot load() => _inner ?? DashboardSnapshot.empty;

  @override
  Future<DashboardSnapshot> refresh() async {
    refreshCount++;
    return _inner = DashboardSnapshot(
      habits: const [
        DashboardHabit(
          id: 'meditation',
          title: 'Meditazione',
          color: EvolveColors.primaryStrong,
          streak: 3,
          weeklyProgress: [true, true, true, false, false, false, false],
          state: HabitState.pending,
        ),
      ],
      goals: const [],
      trend: const [],
      checkIn: const DailyCheckIn(),
    );
  }

  @override
  Future<void> save(DashboardSnapshot snapshot) async {
    _inner = snapshot;
  }
}
