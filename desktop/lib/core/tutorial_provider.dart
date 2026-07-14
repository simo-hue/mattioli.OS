import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ordered segments of the guided product tour. Each maps to the desktop
/// [DesktopSection] whose page renders that segment's coach-mark steps. The
/// order here IS the tour order: Overview → Habits → Insights → Goals → Coach.
enum TourSegment { overview, habits, insights, goals, coach }

extension TourSegmentX on TourSegment {
  /// The section whose page owns this segment's spotlight steps.
  DesktopSection get section => switch (this) {
    TourSegment.overview => DesktopSection.overview,
    TourSegment.habits => DesktopSection.habits,
    TourSegment.insights => DesktopSection.insights,
    TourSegment.goals => DesktopSection.goals,
    TourSegment.coach => DesktopSection.coach,
  };

  /// The last segment ends the whole tour (Coach), rather than advancing.
  bool get isLast => this == TourSegment.coach;
}

/// Immutable snapshot of the tour's progress.
///
/// [completed] is the single, global, show-once flag. [active] means the tour
/// is running right now (navigation is locked). [segmentIndex] is the resume
/// pointer persisted across launches so a force-quit resumes at the start of
/// the incomplete segment rather than restarting from Overview.
class TourState {
  const TourState({
    required this.completed,
    required this.active,
    required this.segmentIndex,
  });

  const TourState.initial()
    : completed = false,
      active = false,
      segmentIndex = 0;

  final bool completed;
  final bool active;
  final int segmentIndex;

  TourSegment get segment =>
      TourSegment.values[segmentIndex.clamp(0, TourSegment.values.length - 1)];

  /// First-launch onboarding should kick in when the tour has never been
  /// completed and isn't already running.
  bool get shouldOnboard => !completed && !active;

  /// True while the tour is running and this [segment] is the active one — the
  /// gate each page uses to decide whether to render its overlay.
  bool isSegmentActive(TourSegment s) => active && segment == s;

  TourState copyWith({bool? completed, bool? active, int? segmentIndex}) =>
      TourState(
        completed: completed ?? this.completed,
        active: active ?? this.active,
        segmentIndex: segmentIndex ?? this.segmentIndex,
      );
}

/// The single source of truth for the continuous product tour: owns the segment
/// sequence, the persisted completion flag + resume pointer, and drives the
/// navigation lock and cross-page hand-offs. Pages render the shared
/// [CoachTutorialOverlay]; on a segment's last step they call [advance] (or
/// [complete] on Coach), and this controller moves to the next page.
class TourController extends Notifier<TourState> {
  static const _completedKey = 'tour_completed';
  static const _segmentKey = 'tour_segment_index';

  /// Legacy per-page flags from the old three-tour implementation. They are
  /// deleted on first run of the unified tour (mode-suffixed variants too) so
  /// every existing install sees the new, complete tour exactly once.
  static const _legacyKeyPrefixes = <String>[
    'has_seen_tutorial',
    'has_seen_goals_tutorial',
    'has_seen_stats_tutorial',
  ];

  @override
  TourState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs == null) return const TourState.initial();
    _purgeLegacyKeys(prefs);
    final completed = prefs.getBool(_completedKey) ?? false;
    final segmentIndex = (prefs.getInt(_segmentKey) ?? 0).clamp(
      0,
      TourSegment.values.length - 1,
    );
    return TourState(
      completed: completed,
      active: false,
      segmentIndex: segmentIndex,
    );
  }

  void _purgeLegacyKeys(SharedPreferences prefs) {
    for (final key in prefs.getKeys().toList()) {
      final isLegacy = _legacyKeyPrefixes.any(
        (prefix) => key == prefix || key.startsWith('${prefix}_'),
      );
      if (isLegacy) prefs.remove(key);
    }
  }

  NavigationController get _nav =>
      ref.read(navigationControllerProvider.notifier);

  /// Begin (or resume) the tour: lock navigation and jump to the current
  /// segment's page. Called after the welcome dialog on first launch, or
  /// directly when resuming an interrupted run.
  void activate() {
    if (state.active) return;
    _nav.setLocked(true);
    state = state.copyWith(active: true);
    _nav.selectForTour(state.segment.section);
  }

  /// Advance from the just-finished segment to the next one, driving the
  /// navigation to that page. No-op on the final segment — Coach calls
  /// [complete] instead.
  Future<void> advance() async {
    if (!state.active || state.segment.isLast) return;
    final nextIndex = state.segmentIndex + 1;
    state = state.copyWith(segmentIndex: nextIndex);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setInt(_segmentKey, nextIndex);
    _nav.selectForTour(state.segment.section);
  }

  /// Finish the whole tour: persist completion, rewind the pointer, and unlock
  /// navigation. The caller (Coach page) shows the completion dialog and
  /// returns the user to Overview.
  Future<void> complete() async {
    state = const TourState(completed: true, active: false, segmentIndex: 0);
    _nav.setLocked(false);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setBool(_completedKey, true);
    await prefs?.setInt(_segmentKey, 0);
  }

  /// Reset for a replay from Settings: clear completion and rewind to Overview.
  /// The caller navigates to Overview and re-runs the welcome dialog +
  /// [activate].
  Future<void> resetForReplay() async {
    state = const TourState(completed: false, active: false, segmentIndex: 0);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setBool(_completedKey, false);
    await prefs?.setInt(_segmentKey, 0);
  }
}

final tourControllerProvider = NotifierProvider<TourController, TourState>(
  TourController.new,
);
