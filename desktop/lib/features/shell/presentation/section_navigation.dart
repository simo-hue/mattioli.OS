import 'package:evolve_desktop/features/ai_coach/application/coach_controllers.dart';
import 'package:evolve_desktop/features/settings/presentation/pro_features_modal.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether [section] is gated behind Evolve Pro for the current data mode and
/// entitlement, i.e. tapping its entry point must present the upsell instead of
/// navigating.
///
/// Today the AI Coach is the only gated section: it is Pro-only in account mode
/// and free in Private mode, where BYOK and Local are the self-served paths
/// (see [coachNeedsPaywallProvider]).
///
/// Deliberately `ref.read`, not `ref.watch`: nothing on screen changes with the
/// flag — it only picks a branch when a control is activated — and reading at
/// activation time is strictly fresher than a bool captured in a closure during
/// build. That also lets callbacks call this directly.
bool sectionNeedsPaywall(WidgetRef ref, DesktopSection section) =>
    section == DesktopSection.coach && ref.read(coachNeedsPaywallProvider);

/// The single door every user-initiated section jump goes through: navigate to
/// [section], or present the Pro upsell when it is gated.
///
/// Sidebar, ⌘1–⌘5, the Overview quick-action tiles and the ⌘K palette all route
/// here, so a newly-added entry point is gated by construction rather than by
/// remembering to copy the check. `NavigationController` enforces the same rule
/// independently, so a call site that skips this helper degrades to a no-op
/// instead of a leak.
///
/// The ⌘K palette is the one caller that cannot use this directly: it must pop
/// its own route before presenting a dialog, and by then its [WidgetRef] is
/// dead. It calls [sectionNeedsPaywall] while the ref is still alive instead.
void openSection(
  BuildContext context,
  WidgetRef ref,
  DesktopSection section,
) {
  if (sectionNeedsPaywall(ref, section)) {
    showProFeaturesDialog(context, ref);
    return;
  }
  ref.read(navigationControllerProvider.notifier).select(section);
}
