import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class DashboardRepository {
  DashboardSnapshot load();

  Future<void> save(DashboardSnapshot snapshot);
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => InMemoryDashboardRepository(),
);

class InMemoryDashboardRepository implements DashboardRepository {
  DashboardSnapshot? _snapshot;

  @override
  DashboardSnapshot load() => _snapshot ??= _seedSnapshot;

  @override
  Future<void> save(DashboardSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}

const _seedSnapshot = DashboardSnapshot(
  habits: [
    DashboardHabit(
      id: 'morning-focus',
      title: 'Routine del mattino',
      category: 'Benessere',
      color: EvolveColors.primaryStrong,
      streak: 24,
      weeklyProgress: [true, true, true, true, true, true, false],
      state: HabitState.completed,
    ),
    DashboardHabit(
      id: 'deep-work',
      title: 'Deep work: 90 minuti',
      category: 'Produttivita',
      color: EvolveColors.cyan,
      streak: 12,
      weeklyProgress: [true, true, true, false, true, true, false],
      state: HabitState.completed,
    ),
    DashboardHabit(
      id: 'reading',
      title: 'Leggere 20 pagine',
      category: 'Formazione',
      color: EvolveColors.violet,
      streak: 8,
      weeklyProgress: [true, true, false, true, true, false, false],
      state: HabitState.pending,
    ),
    DashboardHabit(
      id: 'movement',
      title: 'Allenamento funzionale',
      category: 'Salute',
      color: EvolveColors.amber,
      streak: 5,
      weeklyProgress: [true, false, true, true, false, false, false],
      state: HabitState.pending,
    ),
    DashboardHabit(
      id: 'reflection',
      title: 'Journal serale',
      category: 'Mindfulness',
      color: EvolveColors.rose,
      streak: 16,
      weeklyProgress: [true, true, true, true, true, true, false],
      state: HabitState.pending,
    ),
  ],
  goals: [
    DashboardGoal(
      id: 'portfolio',
      title: 'Pubblicare il nuovo portfolio',
      category: 'Lavoro',
      color: EvolveColors.cyan,
      progress: 0.72,
      dueLabel: 'Scade tra 18 giorni',
    ),
    DashboardGoal(
      id: 'half-marathon',
      title: 'Preparare la mezza maratona',
      category: 'Salute',
      color: EvolveColors.primaryStrong,
      progress: 0.58,
      dueLabel: 'Q3 2026',
    ),
    DashboardGoal(
      id: 'spanish',
      title: 'Completare il corso di spagnolo',
      category: 'Formazione',
      color: EvolveColors.violet,
      progress: 0.41,
      dueLabel: 'Obiettivo annuale',
    ),
  ],
  trend: [
    TrendPoint(label: 'Lun', value: 0.58),
    TrendPoint(label: 'Mar', value: 0.66),
    TrendPoint(label: 'Mer', value: 0.62),
    TrendPoint(label: 'Gio', value: 0.76),
    TrendPoint(label: 'Ven', value: 0.71),
    TrendPoint(label: 'Sab', value: 0.84),
    TrendPoint(label: 'Dom', value: 0.79),
  ],
  checkIn: DailyCheckIn(),
);
