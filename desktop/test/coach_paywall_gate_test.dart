// Verifies the Pro-gate floor inside NavigationController: no user navigation
// vector can land on the AI Coach while it is paywalled (account mode, no Pro),
// including the back/forward history stacks — which are the vectors no
// call-site check could ever cover, since a Coach entry recorded in Private
// mode outlives the mode that allowed it.
//
// The tour is exempt on purpose: its final segment IS the Coach page.
import 'package:evolve_desktop/features/ai_coach/application/coach_controllers.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flips the gate mid-test, standing in for a data-mode switch or an
/// entitlement lapse without dragging in Supabase/RevenueCat.
class _GatedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final _gated = NotifierProvider<_GatedNotifier, bool>(_GatedNotifier.new);

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      coachNeedsPaywallProvider.overrideWith((ref) => ref.watch(_gated)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  NavigationController navOf(ProviderContainer c) =>
      c.read(navigationControllerProvider.notifier);

  void setGated(ProviderContainer c, bool value) =>
      c.read(_gated.notifier).set(value);

  test('select refuses the Coach while it is paywalled', () {
    final c = _container();
    setGated(c, true);

    navOf(c).select(DesktopSection.coach);
    expect(c.read(navigationControllerProvider), DesktopSection.overview);
  });

  test('select allows the Coach once the paywall lifts', () {
    final c = _container();

    navOf(c).select(DesktopSection.coach);
    expect(c.read(navigationControllerProvider), DesktopSection.coach);
  });

  test('a refused Coach select does not disturb the history', () {
    final c = _container();
    final nav = navOf(c);

    nav.select(DesktopSection.habits);
    setGated(c, true);
    nav.select(DesktopSection.coach);

    nav.back();
    expect(c.read(navigationControllerProvider), DesktopSection.overview);
    expect(nav.canGoBack, isFalse);
  });

  test('forward skips a Coach entry that became gated', () {
    final c = _container();
    final nav = navOf(c);

    // Private mode: the coach is free, so it lands in the history…
    nav.select(DesktopSection.coach);
    nav.back();
    expect(c.read(navigationControllerProvider), DesktopSection.overview);
    expect(nav.canGoForward, isTrue);

    // …then the user switches to a free account. ⌘] must not resurrect it.
    setGated(c, true);
    expect(nav.canGoForward, isFalse);
    nav.forward();
    expect(c.read(navigationControllerProvider), DesktopSection.overview);
  });

  test('back skips a gated Coach entry and lands on the next allowed one', () {
    final c = _container();
    final nav = navOf(c);

    nav.select(DesktopSection.habits);
    nav.select(DesktopSection.coach); // free while ungated
    nav.select(DesktopSection.goals);
    expect(c.read(navigationControllerProvider), DesktopSection.goals);

    setGated(c, true);
    nav.back();
    expect(c.read(navigationControllerProvider), DesktopSection.habits);
  });

  test('back reports nothing to return to when every entry is gated', () {
    final c = _container();
    final nav = navOf(c);

    // Start ON the coach with an empty history, as the eviction guard finds it.
    nav.select(DesktopSection.coach);
    setGated(c, true);
    nav.select(DesktopSection.overview); // the eviction hop
    expect(c.read(navigationControllerProvider), DesktopSection.overview);

    // The hop pushed Coach onto the history; going back must not re-enter it.
    expect(nav.canGoBack, isFalse);
    nav.back();
    expect(c.read(navigationControllerProvider), DesktopSection.overview);
  });

  test('selectForTour still reaches the Coach while it is paywalled', () {
    final c = _container();
    setGated(c, true);

    navOf(c).selectForTour(DesktopSection.coach);
    expect(c.read(navigationControllerProvider), DesktopSection.coach);
  });

  test('non-Coach navigation is unaffected by the gate', () {
    final c = _container();
    final nav = navOf(c);
    setGated(c, true);

    nav.select(DesktopSection.habits);
    nav.select(DesktopSection.insights);
    expect(c.read(navigationControllerProvider), DesktopSection.insights);
    nav.back();
    expect(c.read(navigationControllerProvider), DesktopSection.habits);
    nav.forward();
    expect(c.read(navigationControllerProvider), DesktopSection.insights);
  });
}
