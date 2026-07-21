import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the Habits tab on the statistics page shows every habit or only
/// ones currently inside their active date range (mirrors mobile's
/// `statsHabitFilter` setting and `Goal.isActiveOn`).
enum StatsHabitFilter {
  active,
  all;

  bool get isAll => this == StatsHabitFilter.all;
}

/// Persists and exposes the Habits-tab active/all filter.
///
/// Reads the saved value from [SharedPreferences] on build and writes back on
/// every change, so the choice survives app restarts like it does on mobile.
class StatsHabitFilterNotifier extends Notifier<StatsHabitFilter> {
  static const _key = 'stats_habit_filter';

  @override
  StatsHabitFilter build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs?.getString(_key);
    return raw == StatsHabitFilter.all.name
        ? StatsHabitFilter.all
        : StatsHabitFilter.active;
  }

  Future<void> setFilter(StatsHabitFilter filter) async {
    if (state == filter) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setString(_key, filter.name);
    state = filter;
  }
}

final statsHabitFilterProvider =
    NotifierProvider<StatsHabitFilterNotifier, StatsHabitFilter>(
      StatsHabitFilterNotifier.new,
    );
