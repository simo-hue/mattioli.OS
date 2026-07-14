import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-shot, page-level commands the ⌘K palette can hand to the Goals page when
/// it can't act on its own (the target UI is private to that page). Distinct
/// from a period jump — see `GoalNavTarget` — because these carry no period.
enum GoalsPageCommand { openCategoryManager }

/// Holds a pending [GoalsPageCommand], or null. The palette [set]s one and
/// navigates to Goals; the page [consume]s it once on arrival (or immediately,
/// if already open, via a `ref.listen`). Consume-once so it never replays.
class GoalsPageCommandNotifier extends Notifier<GoalsPageCommand?> {
  @override
  GoalsPageCommand? build() => null;

  void set(GoalsPageCommand command) => state = command;

  GoalsPageCommand? consume() {
    final current = state;
    state = null;
    return current;
  }
}

final goalsPageCommandProvider =
    NotifierProvider<GoalsPageCommandNotifier, GoalsPageCommand?>(
      GoalsPageCommandNotifier.new,
    );
