import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum DesktopSection {
  overview,
  habits,
  insights,
  goals,
  coach,
  settings;

  String get label => switch (this) {
    overview => t.nav.overview,
    habits => t.nav.habits,
    insights => t.nav.insights,
    goals => t.nav.goals,
    coach => t.nav.coach,
    settings => t.nav.settings,
  };

  String get shortcut => switch (this) {
    overview => '⌘1',
    habits => '⌘2',
    insights => '⌘3',
    goals => '⌘4',
    coach => '⌘5',
    settings => '⌘,',
  };

  IconData get icon => switch (this) {
    overview => LucideIcons.house,
    habits => LucideIcons.listTodo,
    insights => LucideIcons.activity,
    goals => LucideIcons.chartPie,
    coach => LucideIcons.sparkles,
    settings => LucideIcons.settings,
  };
}

/// Direction of the most recent section change, used by the shell to drive the
/// slide direction of the section transition (and to mirror mobile's
/// swipe-back gesture on macOS).
enum NavDirection { forward, back }

/// One-shot request to open the Settings page directly on its Privacy
/// (iCloud-sync) section. The data-loss `SyncOffBanner` calls [request] before
/// navigating to Settings; `SettingsPage` reads the flag on mount, jumps to the
/// Privacy section, then [consume]s it so a later manual visit still opens on
/// Profile.
class PrivacySettingsRequest extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;

  void consume() => state = false;
}

final privacySettingsRequestProvider =
    NotifierProvider<PrivacySettingsRequest, bool>(PrivacySettingsRequest.new);

final navigationControllerProvider =
    NotifierProvider<NavigationController, DesktopSection>(
      NavigationController.new,
    );

class NavigationController extends Notifier<DesktopSection> {
  /// Sections previously visited, oldest first. [back] pops the last entry.
  /// Kept modest in size so a long session of sidebar hopping can't grow it
  /// without bound.
  final List<DesktopSection> _history = <DesktopSection>[];

  /// Sections ahead of the current one (the forward-stack), filled by [back]
  /// and consumed by [forward]. Any fresh [select] clears it — standard
  /// browser back/forward semantics.
  final List<DesktopSection> _forward = <DesktopSection>[];
  static const int _maxHistory = 50;

  NavDirection _lastDirection = NavDirection.forward;

  /// While locked (the guided tour is running), every user-initiated navigation
  /// vector — [select], [back], [forward] — is a no-op. The tour engine moves
  /// between pages via [selectForTour], which bypasses the lock. This is the
  /// single choke point that seals sidebar taps, ⌘1–5/⌘,, ⌘[/], the trackpad
  /// swipe, and the command palette all at once, since they all route here.
  bool _locked = false;

  @override
  DesktopSection build() => DesktopSection.overview;

  /// Whether navigation is currently locked by the guided tour.
  bool get isLocked => _locked;

  /// Engage or release the tour navigation lock. Called by the tour controller.
  void setLocked(bool value) => _locked = value;

  /// Direction of the most recent navigation (forward = a newly selected
  /// section, back = returned to a previously visited one).
  NavDirection get lastDirection => _lastDirection;

  /// Whether there is a previously visited section to return to. Drives whether
  /// the two-finger swipe / ⌘[ back gesture does anything.
  bool get canGoBack => _history.isNotEmpty;

  /// Whether there is a backed-out-of section to re-enter. Drives whether the
  /// two-finger swipe-left / ⌘] forward gesture does anything.
  bool get canGoForward => _forward.isNotEmpty;

  /// Navigate to [section], recording the current one so it can be returned to
  /// with [back]. Selecting the already-current section is a no-op.
  void select(DesktopSection section) {
    if (_locked) return;
    if (section == state) return;
    _history.add(state);
    if (_history.length > _maxHistory) {
      _history.removeAt(0);
    }
    _forward.clear();
    _lastDirection = NavDirection.forward;
    state = section;
  }

  /// Privileged navigation used by the guided tour to move between segment
  /// pages. Bypasses the lock and deliberately does NOT touch the back/forward
  /// history, so the tour's page hops don't pollute the user's navigation
  /// stack once the tour ends.
  void selectForTour(DesktopSection section) {
    if (section == state) return;
    _lastDirection = NavDirection.forward;
    state = section;
  }

  /// Return to the most recently visited section, if any. Mirrors the mobile
  /// swipe-back gesture — bound on macOS to ⌘[ and the two-finger trackpad
  /// swipe. No-op at the root of the history.
  void back() {
    if (_locked) return;
    if (_history.isEmpty) return;
    _forward.add(state);
    _lastDirection = NavDirection.back;
    state = _history.removeLast();
  }

  /// Re-enter the section most recently left via [back], if any, pushing the
  /// current one back onto the history. Bound on macOS to ⌘] and the
  /// two-finger trackpad swipe-left. No-op when there is nothing ahead.
  void forward() {
    if (_locked) return;
    if (_forward.isEmpty) return;
    _history.add(state);
    _lastDirection = NavDirection.forward;
    state = _forward.removeLast();
  }
}

/// One-shot request to open the Settings page directly on its Subscription
/// section. Handled similarly to PrivacySettingsRequest.
class SubscriptionSettingsRequest extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;

  void consume() => state = false;
}

final subscriptionSettingsRequestProvider =
    NotifierProvider<SubscriptionSettingsRequest, bool>(SubscriptionSettingsRequest.new);
