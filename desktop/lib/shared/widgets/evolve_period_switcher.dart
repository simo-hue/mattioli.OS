import 'package:flutter/material.dart';

/// A directional slide + cross-fade played whenever [periodKey] changes, so
/// period navigation (arrow keys OR the ‹ › buttons) is always visibly
/// reflected — a user who mis-clicks a nav button still sees the content move
/// and understands something changed.
///
/// [direction] is the last navigation direction (+1 = forward in time / next,
/// -1 = back / previous, 0 = neutral, e.g. a direct jump or a mode switch) and
/// controls which way the content drifts in. It is RTL-aware: under a
/// right-to-left layout the timeline runs leftwards, so the drift is mirrored.
/// This mirrors the shell's page transition for a coherent feel.
///
/// Wrap the *content* that changes with the period (a calendar grid, a goal
/// board) — not the controls that drive it — and feed a [periodKey] that is
/// equal for equal periods (a record or a formatted string works well).
class EvolvePeriodSwitcher extends StatelessWidget {
  const EvolvePeriodSwitcher({
    super.key,
    required this.periodKey,
    required this.direction,
    required this.child,
    this.duration = const Duration(milliseconds: 280),
    this.expand = false,
  });

  /// Identity of the currently shown period. When it changes, the transition
  /// plays. Use a value with structural equality (a record, or a string).
  final Object periodKey;

  /// Last navigation direction: +1 next, -1 previous, 0 neutral.
  final int direction;

  final Widget child;
  final Duration duration;

  /// When true the switcher fills its parent and stacks children with
  /// [StackFit.expand] — use inside [Expanded] / pinned layouts (the calendar).
  /// When false it sizes to the current child and top-aligns the outgoing one —
  /// use in document / scroll layouts (the goal board).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final sign = direction.sign.toDouble() * (isRtl ? -1.0 : 1.0);
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: expand ? _expandLayout : _flowLayout,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(sign * 0.08, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(periodKey), child: child),
    );
  }

  /// Fills the parent (for [Expanded]/pinned hosts).
  static Widget _expandLayout(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [...previousChildren, ?currentChild],
    );
  }

  /// Sizes to the current child and top-anchors both so a shorter/taller
  /// neighbour doesn't jump vertically mid-transition in a scroll layout.
  static Widget _flowLayout(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) {
    return Stack(
      alignment: AlignmentDirectional.topStart,
      children: [...previousChildren, ?currentChild],
    );
  }
}
