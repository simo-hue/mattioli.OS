// Unit tests for the central product-tour controller: segment sequencing,
// completion gating, persistence + resume, replay reset, and legacy-key purge.
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/tutorial_provider.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _containerWith([
  Map<String, Object> seed = const {},
]) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  test('fresh install: inactive, not completed, at segment 0', () async {
    final c = await _containerWith();
    addTearDown(c.dispose);
    final s = c.read(tourControllerProvider);
    expect(s.completed, isFalse);
    expect(s.active, isFalse);
    expect(s.segmentIndex, 0);
    expect(s.shouldOnboard, isTrue);
  });

  test('activate() locks navigation and jumps to Overview', () async {
    final c = await _containerWith();
    addTearDown(c.dispose);
    c.read(tourControllerProvider.notifier).activate();
    expect(c.read(tourControllerProvider).active, isTrue);
    expect(c.read(navigationControllerProvider.notifier).isLocked, isTrue);
    expect(c.read(navigationControllerProvider), DesktopSection.overview);
  });

  test('advance() walks every segment; only Coach.complete() finishes', () async {
    final c = await _containerWith();
    addTearDown(c.dispose);
    final tour = c.read(tourControllerProvider.notifier);
    tour.activate();

    const order = [
      DesktopSection.habits,
      DesktopSection.insights,
      DesktopSection.goals,
      DesktopSection.coach,
    ];
    for (final section in order) {
      await tour.advance();
      expect(c.read(navigationControllerProvider), section);
      expect(c.read(tourControllerProvider).completed, isFalse);
    }

    // On the final (Coach) segment advance() is a no-op — it must not complete.
    await tour.advance();
    expect(c.read(navigationControllerProvider), DesktopSection.coach);
    expect(c.read(tourControllerProvider).completed, isFalse);

    await tour.complete();
    final s = c.read(tourControllerProvider);
    expect(s.completed, isTrue);
    expect(s.active, isFalse);
    expect(c.read(navigationControllerProvider.notifier).isLocked, isFalse);
  });

  test('force-quit mid-tour resumes at the incomplete segment', () async {
    final c = await _containerWith();
    addTearDown(c.dispose);
    final tour = c.read(tourControllerProvider.notifier);
    tour.activate();
    await tour.advance(); // -> Habits (1)
    await tour.advance(); // -> Insights (2)

    // Relaunch: a new container over the same backing prefs.
    final prefs = c.read(sharedPreferencesProvider)!;
    final c2 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c2.dispose);
    final s = c2.read(tourControllerProvider);
    expect(s.completed, isFalse);
    expect(s.active, isFalse);
    expect(s.segmentIndex, 2, reason: 'resumes at the incomplete segment');
    expect(s.segment, TourSegment.insights);
  });

  test('completion persists across relaunch', () async {
    final c = await _containerWith();
    addTearDown(c.dispose);
    final tour = c.read(tourControllerProvider.notifier);
    tour.activate();
    await tour.complete();

    final prefs = c.read(sharedPreferencesProvider)!;
    final c2 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c2.dispose);
    expect(c2.read(tourControllerProvider).completed, isTrue);
    expect(c2.read(tourControllerProvider).shouldOnboard, isFalse);
  });

  test('resetForReplay() clears completion and rewinds to segment 0', () async {
    final c = await _containerWith({
      'tour_completed': true,
      'tour_segment_index': 3,
    });
    addTearDown(c.dispose);
    expect(c.read(tourControllerProvider).completed, isTrue);

    await c.read(tourControllerProvider.notifier).resetForReplay();
    final s = c.read(tourControllerProvider);
    expect(s.completed, isFalse);
    expect(s.segmentIndex, 0);
    expect(s.shouldOnboard, isTrue);
  });

  test('resetForReplay() also clears the per-session startup guard', () async {
    final c = await _containerWith({'tour_completed': true});
    addTearDown(c.dispose);
    // Simulate the dashboard having already handled startup onboarding.
    c.read(startupOnboardingHandledProvider.notifier).set(true);

    await c.read(tourControllerProvider.notifier).resetForReplay();
    expect(
      c.read(startupOnboardingHandledProvider),
      isFalse,
      reason: 'replay must let the dashboard re-run its onboarding flow',
    );
  });

  test('purges legacy per-page tutorial keys on first build', () async {
    final c = await _containerWith({
      'has_seen_tutorial': true,
      'has_seen_goals_tutorial_private': true,
      'has_seen_stats_tutorial': true,
      'active_data_mode': 'private', // unrelated — must be kept
    });
    addTearDown(c.dispose);
    c.read(tourControllerProvider); // build() -> purge
    await Future<void>.delayed(Duration.zero);

    final prefs = c.read(sharedPreferencesProvider)!;
    expect(prefs.getBool('has_seen_tutorial'), isNull);
    expect(prefs.getBool('has_seen_goals_tutorial_private'), isNull);
    expect(prefs.getBool('has_seen_stats_tutorial'), isNull);
    expect(prefs.getString('active_data_mode'), 'private');
  });
}
