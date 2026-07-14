// Verifies the navigation lock that seals all user navigation vectors during
// the guided tour: select/back/forward become no-ops, selectForTour bypasses
// the lock, and unlocking restores normal navigation.
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NavigationController navOf(ProviderContainer c) =>
      c.read(navigationControllerProvider.notifier);

  test('while locked, select/back/forward are no-ops', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final nav = navOf(c);

    nav.select(DesktopSection.habits); // establishes history
    expect(c.read(navigationControllerProvider), DesktopSection.habits);

    nav.setLocked(true);
    expect(nav.isLocked, isTrue);

    nav.select(DesktopSection.goals);
    expect(c.read(navigationControllerProvider), DesktopSection.habits);
    nav.back();
    expect(c.read(navigationControllerProvider), DesktopSection.habits);
    nav.forward();
    expect(c.read(navigationControllerProvider), DesktopSection.habits);
  });

  test('selectForTour bypasses the lock', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final nav = navOf(c);
    nav.setLocked(true);

    nav.selectForTour(DesktopSection.coach);
    expect(c.read(navigationControllerProvider), DesktopSection.coach);
  });

  test('unlocking restores user navigation', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final nav = navOf(c);

    nav.setLocked(true);
    nav.select(DesktopSection.goals);
    expect(c.read(navigationControllerProvider), DesktopSection.overview);

    nav.setLocked(false);
    nav.select(DesktopSection.goals);
    expect(c.read(navigationControllerProvider), DesktopSection.goals);
  });

  test('selectForTour does not pollute the back history', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final nav = navOf(c);

    // Drive the whole tour path via selectForTour...
    nav.setLocked(true);
    nav.selectForTour(DesktopSection.habits);
    nav.selectForTour(DesktopSection.insights);
    nav.setLocked(false);

    // ...and there should be nothing to go back to afterwards.
    expect(nav.canGoBack, isFalse);
  });
}
