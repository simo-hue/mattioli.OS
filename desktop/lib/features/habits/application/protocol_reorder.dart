import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';

/// Reconcile a drag on the Protocol tab's *active-only* rows with the full,
/// unfiltered habit list.
///
/// The Habits › Protocol tab renders only habits that are active on a given day
/// ([DashboardHabit.isActiveOn]), so the `oldIndex`/`newIndex` a
/// [ReorderableListView] reports are positions in that filtered subset — not in
/// the complete list the controller persists. This rebuilds the whole list so
/// the active habits take their new relative order while every hidden
/// (inactive) habit stays pinned to its original slot.
///
/// A plain index-based reorder on the full list can't preserve that: its
/// remove-then-insert would drag inactive habits sitting between two active
/// rows along with the move. Here the active slots are refilled in place, so an
/// inactive habit wedged between two reordered active ones never shifts.
///
/// [oldIndex]/[newIndex] follow the same convention as the desktop
/// `onReorderItem` callback: `newIndex` is already the final target position
/// (0..activeCount-1), not the pre-removal index. Returns the input list
/// unchanged (same identity) when the move is out of range or a no-op, so
/// callers can skip persisting.
List<DashboardHabit> reorderActiveHabits({
  required List<DashboardHabit> full,
  required DateTime on,
  required int oldIndex,
  required int newIndex,
}) {
  // Positions of the active (visible) habits within the full list, in order.
  final activePositions = [
    for (var i = 0; i < full.length; i++)
      if (full[i].isActiveOn(on)) i,
  ];

  if (oldIndex < 0 || oldIndex >= activePositions.length) return full;
  final target = newIndex.clamp(0, activePositions.length - 1);
  if (oldIndex == target) return full;

  // New order of just the visible habits after the drag.
  final visible = [for (final p in activePositions) full[p]];
  final moved = visible.removeAt(oldIndex);
  visible.insert(target, moved);

  // Refill the active slots of the full list in the new order; inactive habits
  // keep their exact positions.
  final rebuilt = List<DashboardHabit>.from(full);
  for (var k = 0; k < activePositions.length; k++) {
    rebuilt[activePositions[k]] = visible[k];
  }
  return rebuilt;
}
