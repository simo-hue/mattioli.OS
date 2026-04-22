import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/macro_goal.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class MacroGoalsState {
  final List<MacroGoal> goals;

  const MacroGoalsState({required this.goals});

  MacroGoalsState copyWith({List<MacroGoal>? goals}) =>
      MacroGoalsState(goals: goals ?? this.goals);
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MacroGoalsNotifier extends Notifier<MacroGoalsState> {
  @override
  MacroGoalsState build() {
    return MacroGoalsState(goals: _buildMockData());
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  void addGoal(MacroGoal goal) {
    state = state.copyWith(goals: [...state.goals, goal]);
  }

  void updateStatus(String id, GoalStatus status) {
    state = state.copyWith(
      goals: state.goals.map((g) => g.id == id ? g.copyWith(status: status) : g).toList(),
    );
  }

  void updateTitle(String id, String title) {
    state = state.copyWith(
      goals: state.goals.map((g) => g.id == id ? g.copyWith(title: title) : g).toList(),
    );
  }

  void updateCategory(String id, String? categoryKey) {
    state = state.copyWith(
      goals: state.goals.map((g) {
        if (g.id != id) return g;
        return categoryKey == null
            ? g.copyWith(clearCategory: true)
            : g.copyWith(categoryKey: categoryKey);
      }).toList(),
    );
  }

  void deleteGoal(String id) {
    state = state.copyWith(
      goals: state.goals.where((g) => g.id != id).toList(),
    );
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<MacroGoal> getFilteredGoals({
    required GoalType type,
    required int year,
    int? quarter,
    int? month,
    int? weekNumber,
  }) {
    return state.goals.where((g) {
      if (g.type != type) return false;
      if (type == GoalType.lifetime) return true;
      if (g.year != year) return false;
      if (type == GoalType.quarterly && g.quarter != quarter) return false;
      if (type == GoalType.monthly && g.month != month) return false;
      if (type == GoalType.weekly &&
          (g.month != month || g.weekNumber != weekNumber)) return false;
      return true;
    }).toList()
      ..sort(_sortGoals);
  }

  // active first, then completed, then failed; within group sort by createdAt
  int _sortGoals(MacroGoal a, MacroGoal b) {
    int statusOrder(GoalStatus s) {
      switch (s) {
        case GoalStatus.active: return 0;
        case GoalStatus.completed: return 1;
        case GoalStatus.failed: return 2;
      }
    }

    final aOrder = statusOrder(a.status);
    final bOrder = statusOrder(b.status);
    if (aOrder != bOrder) return aOrder.compareTo(bOrder);
    return a.createdAt.compareTo(b.createdAt);
  }

  // ── Mock data ─────────────────────────────────────────────────────────────

  List<MacroGoal> _buildMockData() {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month;

    return [
      // ── Lifetime ──────────────────────────────────────────────────────────
      MacroGoal(
        id: 'lt-1',
        title: 'Costruire una base finanziaria solida',
        status: GoalStatus.active,
        type: GoalType.lifetime,
        categoryKey: 'finanza',
        createdAt: DateTime(y, 1, 1),
      ),
      MacroGoal(
        id: 'lt-2',
        title: 'Imparare 3 lingue straniere',
        status: GoalStatus.active,
        type: GoalType.lifetime,
        categoryKey: 'formazione',
        createdAt: DateTime(y, 1, 2),
      ),
      MacroGoal(
        id: 'lt-3',
        title: 'Correre una maratona',
        status: GoalStatus.completed,
        type: GoalType.lifetime,
        categoryKey: 'salute',
        createdAt: DateTime(y, 1, 3),
      ),

      // ── Annual ────────────────────────────────────────────────────────────
      MacroGoal(
        id: 'an-1',
        title: 'Lanciare la prima app mobile',
        status: GoalStatus.active,
        type: GoalType.annual,
        year: y,
        categoryKey: 'lavoro',
        createdAt: DateTime(y, 1, 1),
      ),
      MacroGoal(
        id: 'an-2',
        title: 'Leggere 24 libri',
        status: GoalStatus.active,
        type: GoalType.annual,
        year: y,
        categoryKey: 'formazione',
        createdAt: DateTime(y, 1, 2),
      ),
      MacroGoal(
        id: 'an-3',
        title: 'Raggiungere i 10.000 iscritti',
        status: GoalStatus.failed,
        type: GoalType.annual,
        year: y,
        categoryKey: 'lavoro',
        createdAt: DateTime(y, 1, 3),
      ),
      MacroGoal(
        id: 'an-4',
        title: 'Risparmiare il 30% dello stipendio',
        status: GoalStatus.completed,
        type: GoalType.annual,
        year: y,
        categoryKey: 'finanza',
        createdAt: DateTime(y, 1, 4),
      ),

      // ── Quarterly (Q2 of current year) ────────────────────────────────────
      MacroGoal(
        id: 'q-1',
        title: 'Completare il corso Flutter avanzato',
        status: GoalStatus.active,
        type: GoalType.quarterly,
        year: y,
        quarter: 2,
        categoryKey: 'formazione',
        createdAt: DateTime(y, 4, 1),
      ),
      MacroGoal(
        id: 'q-2',
        title: 'Perdere 3 kg',
        status: GoalStatus.active,
        type: GoalType.quarterly,
        year: y,
        quarter: 2,
        categoryKey: 'salute',
        createdAt: DateTime(y, 4, 2),
      ),
      MacroGoal(
        id: 'q-3',
        title: 'Trovare 3 nuovi clienti',
        status: GoalStatus.completed,
        type: GoalType.quarterly,
        year: y,
        quarter: 2,
        categoryKey: 'lavoro',
        createdAt: DateTime(y, 4, 3),
      ),

      // ── Monthly (current month) ────────────────────────────────────────────
      MacroGoal(
        id: 'mo-1',
        title: 'Pubblicare 4 articoli sul blog',
        status: GoalStatus.active,
        type: GoalType.monthly,
        year: y,
        month: m,
        categoryKey: 'lavoro',
        createdAt: DateTime(y, m, 1),
      ),
      MacroGoal(
        id: 'mo-2',
        title: 'Meditazione quotidiana per 30 giorni',
        status: GoalStatus.active,
        type: GoalType.monthly,
        year: y,
        month: m,
        categoryKey: 'spirituale',
        createdAt: DateTime(y, m, 2),
      ),
      MacroGoal(
        id: 'mo-3',
        title: 'Organizzare la libreria digitale',
        status: GoalStatus.completed,
        type: GoalType.monthly,
        year: y,
        month: m,
        categoryKey: 'altro',
        createdAt: DateTime(y, m, 3),
      ),
      MacroGoal(
        id: 'mo-4',
        title: 'Iscriversi in palestra',
        status: GoalStatus.failed,
        type: GoalType.monthly,
        year: y,
        month: m,
        categoryKey: 'salute',
        createdAt: DateTime(y, m, 4),
      ),

      // ── Weekly (week 4 of current month) ──────────────────────────────────
      MacroGoal(
        id: 'wk-1',
        title: 'Medico per vaccini e analisi del sangue',
        status: GoalStatus.active,
        type: GoalType.weekly,
        year: y,
        month: m,
        weekNumber: 4,
        categoryKey: 'salute',
        createdAt: DateTime(y, m, 22),
      ),
      MacroGoal(
        id: 'wk-2',
        title: 'Imparare new vocabulary in Arabic',
        status: GoalStatus.active,
        type: GoalType.weekly,
        year: y,
        month: m,
        weekNumber: 4,
        categoryKey: 'formazione',
        createdAt: DateTime(y, m, 22),
      ),
      MacroGoal(
        id: 'wk-3',
        title: 'Fare felpe sul sito Printful',
        status: GoalStatus.failed,
        type: GoalType.weekly,
        year: y,
        month: m,
        weekNumber: 4,
        categoryKey: 'lavoro',
        createdAt: DateTime(y, m, 22),
      ),
      MacroGoal(
        id: 'wk-4',
        title: 'Aver parlato con mia della scelta universitaria',
        status: GoalStatus.completed,
        type: GoalType.weekly,
        year: y,
        month: m,
        weekNumber: 4,
        categoryKey: 'relazioni',
        createdAt: DateTime(y, m, 22),
      ),
      MacroGoal(
        id: 'wk-5',
        title: 'Essere up to date con AI',
        status: GoalStatus.completed,
        type: GoalType.weekly,
        year: y,
        month: m,
        weekNumber: 4,
        categoryKey: 'formazione',
        createdAt: DateTime(y, m, 22),
      ),
    ];
  }
}

final macroGoalsProvider =
    NotifierProvider<MacroGoalsNotifier, MacroGoalsState>(MacroGoalsNotifier.new);

// ─── View state provider ──────────────────────────────────────────────────────

class MacroGoalsViewState {
  final GoalType selectedType;
  final int selectedYear;
  final int selectedQuarter;
  final int selectedMonth;
  final int selectedWeek;

  const MacroGoalsViewState({
    required this.selectedType,
    required this.selectedYear,
    required this.selectedQuarter,
    required this.selectedMonth,
    required this.selectedWeek,
  });

  MacroGoalsViewState copyWith({
    GoalType? selectedType,
    int? selectedYear,
    int? selectedQuarter,
    int? selectedMonth,
    int? selectedWeek,
  }) =>
      MacroGoalsViewState(
        selectedType: selectedType ?? this.selectedType,
        selectedYear: selectedYear ?? this.selectedYear,
        selectedQuarter: selectedQuarter ?? this.selectedQuarter,
        selectedMonth: selectedMonth ?? this.selectedMonth,
        selectedWeek: selectedWeek ?? this.selectedWeek,
      );
}

class MacroGoalsViewNotifier extends Notifier<MacroGoalsViewState> {
  @override
  MacroGoalsViewState build() {
    final now = DateTime.now();
    return MacroGoalsViewState(
      selectedType: GoalType.weekly,
      selectedYear: now.year,
      selectedQuarter: _quarter(now.month),
      selectedMonth: now.month,
      selectedWeek: _logicalWeekOfMonth(now),
    );
  }

  void setType(GoalType t) => state = state.copyWith(selectedType: t);
  void setYear(int y) => state = state.copyWith(selectedYear: y);
  void setQuarter(int q) => state = state.copyWith(selectedQuarter: q);
  void setMonth(int m) => state = state.copyWith(selectedMonth: m, selectedWeek: 1);
  void setWeek(int w) => state = state.copyWith(selectedWeek: w);

  int _quarter(int month) => ((month - 1) ~/ 3) + 1;

  int _logicalWeekOfMonth(DateTime date) {
    final firstOfMonth = DateTime(date.year, date.month, 1);
    final firstWeekday = firstOfMonth.weekday; // 1=Mon, 7=Sun
    final offset = (firstWeekday - 1) % 7;
    return ((date.day + offset - 1) ~/ 7) + 1;
  }

  void nextPeriod() {
    final s = state;
    int y = s.selectedYear;
    int q = s.selectedQuarter;
    int m = s.selectedMonth;
    int w = s.selectedWeek;

    switch (s.selectedType) {
      case GoalType.lifetime:
        break; // No period to step
      case GoalType.annual:
        setYear(y + 1);
        break;
      case GoalType.quarterly:
        if (q < 4) {
          setQuarter(q + 1);
        } else {
          state = s.copyWith(selectedYear: y + 1, selectedQuarter: 1);
        }
        break;
      case GoalType.monthly:
        if (m < 12) {
          setMonth(m + 1);
        } else {
          state = s.copyWith(selectedYear: y + 1, selectedMonth: 1);
        }
        break;
      case GoalType.weekly:
        final maxW = weeksInMonth(y, m);
        if (w < maxW) {
          setWeek(w + 1);
        } else {
          if (m < 12) {
            state = s.copyWith(selectedMonth: m + 1, selectedWeek: 1);
          } else {
            state = s.copyWith(selectedYear: y + 1, selectedMonth: 1, selectedWeek: 1);
          }
        }
        break;
    }
  }

  void prevPeriod() {
    final s = state;
    int y = s.selectedYear;
    int q = s.selectedQuarter;
    int m = s.selectedMonth;
    int w = s.selectedWeek;

    switch (s.selectedType) {
      case GoalType.lifetime:
        break; // No period to step
      case GoalType.annual:
        setYear(y - 1);
        break;
      case GoalType.quarterly:
        if (q > 1) {
          setQuarter(q - 1);
        } else {
          state = s.copyWith(selectedYear: y - 1, selectedQuarter: 4);
        }
        break;
      case GoalType.monthly:
        if (m > 1) {
          setMonth(m - 1);
        } else {
          state = s.copyWith(selectedYear: y - 1, selectedMonth: 12);
        }
        break;
      case GoalType.weekly:
        if (w > 1) {
          setWeek(w - 1);
        } else {
          if (m > 1) {
            final prevMonth = m - 1;
            final maxW = weeksInMonth(y, prevMonth);
            state = s.copyWith(selectedMonth: prevMonth, selectedWeek: maxW);
          } else {
            final maxW = weeksInMonth(y - 1, 12);
            state = s.copyWith(selectedYear: y - 1, selectedMonth: 12, selectedWeek: maxW);
          }
        }
        break;
    }
  }
}

final macroGoalsViewProvider =
    NotifierProvider<MacroGoalsViewNotifier, MacroGoalsViewState>(
        MacroGoalsViewNotifier.new);

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Returns the number of logical weeks (Mon-Sun) in a given month
int weeksInMonth(int year, int month) {
  final firstOfMonth = DateTime(year, month, 1);
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final firstWeekday = firstOfMonth.weekday;
  final offset = (firstWeekday - 1) % 7;
  return ((daysInMonth + offset - 1) ~/ 7) + 1;
}
