import 'dart:io';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/tutorial_provider.dart';
import 'package:evolve_desktop/features/ai_coach/application/coach_controllers.dart';
import 'package:evolve_desktop/features/ai_coach/presentation/ai_coach_page.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/application/desktop_profile_controller.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/presentation/dashboard_page.dart';
import 'package:evolve_desktop/features/goals/presentation/goals_page.dart';
import 'package:evolve_desktop/features/habits/presentation/habits_page.dart';
import 'package:evolve_desktop/features/search/presentation/command_palette.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/features/shell/presentation/section_navigation.dart';
import 'package:evolve_desktop/features/statistics/presentation/statistics_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  final _focusNode = FocusNode(debugLabel: 'desktop-shortcuts');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // ── Two-finger trackpad swipe navigation (macOS) ─────────────────────────
  // Trackpad pans arrive as pointer pan-zoom events; we track the cumulative
  // horizontal translation and, once a clearly-horizontal swipe crosses the
  // threshold, move through the visited-section history once per gesture —
  // swipe-right = back, swipe-left = forward.
  static const double _navSwipeThreshold = 48;
  bool _navSwipeConsumed = false;

  void _onTrackpadPanStart(PointerPanZoomStartEvent event) {
    _navSwipeConsumed = false;
  }

  void _onTrackpadPanUpdate(PointerPanZoomUpdateEvent event) {
    if (_navSwipeConsumed) return;
    final dx = event.pan.dx;
    final dy = event.pan.dy;
    // Require a clearly horizontal gesture so it never competes with vertical
    // scrolling inside the page.
    if (dx.abs() <= dy.abs() * 1.5) return;

    final navigation = ref.read(navigationControllerProvider.notifier);
    final section = ref.read(navigationControllerProvider);
    
    // The macro goals page uses two-finger swipes to page through the calendar;
    // do not steal the gesture for shell navigation when on that section.
    // The statistics and habits pages also use horizontal swipes to navigate tabs.
    if (section == DesktopSection.goals || section == DesktopSection.insights || section == DesktopSection.habits) return;

    // In LTR, swiping the content to the right (fingers move right, dx > 0) is
    // "back" and swiping left is "forward"; both flip in RTL.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final backwardDx = isRtl ? -dx : dx;
    if (backwardDx > _navSwipeThreshold && navigation.canGoBack) {
      _navSwipeConsumed = true;
      navigation.back();
    } else if (backwardDx < -_navSwipeThreshold && navigation.canGoForward) {
      _navSwipeConsumed = true;
      navigation.forward();
    }
  }

  void _onTrackpadPanEnd(PointerPanZoomEndEvent event) {
    _navSwipeConsumed = false;
  }

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(navigationControllerProvider);
    final navigation = ref.read(navigationControllerProvider.notifier);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    // While the guided tour runs, navigation is locked (all six vectors route
    // through the controller, which no-ops). Here we also dim + freeze the
    // chrome the page-level tour overlay can't reach (sidebar, top bar) and
    // collapse the page-switch animation so spotlight geometry settles at once.
    final tourActive = ref.watch(tourControllerProvider).active;

    // In account mode the coach is Pro-only; Private mode is free (BYOK/Local
    // are its self-served paths). WATCHED, not read: this is what rebuilds the
    // shell when an entitlement lapses mid-session, which is what lets the
    // eviction guard below notice.
    final needsPaywall = ref.watch(coachNeedsPaywallProvider);

    // Eviction: the doors keep a paywalled user out of the Coach, but they
    // cannot help someone already standing inside it when Pro lapses. Handled
    // here in build rather than with a `ref.listen` so it also survives a shell
    // remount (a fresh listener has no previous value and would never fire).
    // The tour is exempt — its final segment IS the Coach page. Its finale
    // navigates home on its own before congratulating the user, precisely so
    // this guard never has to race the completion dialog.
    if (section == DesktopSection.coach && needsPaywall && !tourActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        navigation.select(DesktopSection.overview);
      });
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () =>
            openSection(context, ref, DesktopSection.overview),
        const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () =>
            openSection(context, ref, DesktopSection.habits),
        const SingleActivator(LogicalKeyboardKey.digit3, meta: true): () =>
            openSection(context, ref, DesktopSection.insights),
        const SingleActivator(LogicalKeyboardKey.digit4, meta: true): () =>
            openSection(context, ref, DesktopSection.goals),
        const SingleActivator(LogicalKeyboardKey.digit5, meta: true): () =>
            openSection(context, ref, DesktopSection.coach),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): () =>
            openSection(context, ref, DesktopSection.settings),
        // ⌘[ / ⌘] — move back / forward through the visited-section history,
        // matching the two-finger trackpad swipe-right / swipe-left.
        const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true):
            navigation.back,
        const SingleActivator(LogicalKeyboardKey.bracketRight, meta: true):
            navigation.forward,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _showCommandPalette,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _showCommandPalette,
      },
      child: Focus(
        autofocus: true,
        focusNode: _focusNode,
        child: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final collapsed = constraints.maxWidth < 1080;
              return Row(
                children: [
                  IgnorePointer(
                    ignoring: tourActive,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: tourActive ? 0.35 : 1,
                      child: _DesktopSidebar(collapsed: collapsed),
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: context.evolveColors.border.withValues(alpha: 0.5),
                  ),
                  Expanded(
                    // Two-finger trackpad swipe (macOS) → back. Scoped to the
                    // content area so the sidebar is intentionally excluded.
                    child: Listener(
                      onPointerPanZoomStart: _onTrackpadPanStart,
                      onPointerPanZoomUpdate: _onTrackpadPanUpdate,
                      onPointerPanZoomEnd: _onTrackpadPanEnd,
                      child: Column(
                        children: [
                          IgnorePointer(
                            ignoring: tourActive,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              opacity: tourActive ? 0.35 : 1,
                              child: _TopBar(onOpenSearch: _showCommandPalette),
                            ),
                          ),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: tourActive
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeOutCubic,
                              // Directional slide + fade: a forward navigation
                              // slides the new section in from the trailing
                              // edge, a back navigation from the leading edge
                              // (RTL-aware).
                              transitionBuilder: (child, animation) {
                                final back =
                                    navigation.lastDirection ==
                                    NavDirection.back;
                                final sign =
                                    (back ? -1.0 : 1.0) * (isRtl ? -1.0 : 1.0);
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: Offset(sign * 0.06, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              // The default layout builder centers children in
                              // a loose Stack, which vertically centers any
                              // page shorter than the viewport. Expand pages to
                              // fill instead so content always starts at the
                              // top.
                              layoutBuilder: (currentChild, previousChildren) =>
                                  Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ...previousChildren,
                                      ?currentChild,
                                    ],
                                  ),
                              child: KeyedSubtree(
                                key: ValueKey(section),
                                child: _pageFor(section),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _pageFor(DesktopSection section) => switch (section) {
    DesktopSection.overview => const DashboardPage(),
    DesktopSection.habits => const HabitsPage(),
    DesktopSection.insights => const StatisticsPage(),
    DesktopSection.goals => const GoalsPage(),
    DesktopSection.coach => const AiCoachPage(),
    DesktopSection.settings => const SettingsPage(),
  };

  Future<void> _showCommandPalette() async {
    // The command palette is a navigation vector; it stays sealed during the
    // guided tour like the sidebar and shortcuts.
    if (ref.read(tourControllerProvider).active) return;
    await showEvolveDialog<void>(
      context: context,
      builder: (context) => const CommandPalette(),
    );
    if (mounted) _focusNode.requestFocus();
  }
}

class _DesktopSidebar extends ConsumerWidget {
  const _DesktopSidebar({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(navigationControllerProvider);
    final width = collapsed ? 76.0 : 232.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      color: context.evolveColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BrandMark(collapsed: collapsed),
          const SizedBox(height: 18),
          for (final section in DesktopSection.values.take(5))
            _SidebarDestination(
              collapsed: collapsed,
              section: section,
              selected: selected == section,
              onTap: () => openSection(context, ref, section),
            ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 11 : 14),
            child: const Divider(),
          ),
          _SidebarDestination(
            collapsed: collapsed,
            section: DesktopSection.settings,
            selected: selected == DesktopSection.settings,
            onTap: () => openSection(context, ref, DesktopSection.settings),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(collapsed ? 18 : 20, 20, 12, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: context.evolveAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.evolveAccent.withValues(alpha: 0.24),
              ),
            ),
            child: Image.asset('assets/images/logo.png'),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Evolve',
                  style: TextStyle(
                    color: context.evolveColors.foreground,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'DESKTOP',
                  style: TextStyle(
                    color: context.evolveAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.collapsed,
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final bool collapsed;
  final DesktopSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Selected destination mirrors the mobile segmented control: a solid
    // accent (white) pill with black-on-white label and a soft drop shadow.
    final onAccent = Theme.of(context).colorScheme.onPrimary;
    final color = selected ? onAccent : context.evolveColors.muted;
    final destination = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 11 : 14,
        vertical: 3,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: selected ? context.evolveAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            hoverColor: selected
                ? Colors.transparent
                : context.evolveColors.panel.withValues(alpha: 0.6),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 15 : 12,
                vertical: 11,
              ),
              child: Row(
                children: [
                  Icon(section.icon, color: color, size: 18),
                  if (!collapsed) ...[
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        section.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          letterSpacing: -0.2,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      section.shortcut,
                      style: TextStyle(
                        color: selected
                            ? onAccent.withValues(alpha: 0.55)
                            : context.evolveColors.subtle,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return collapsed
        ? Tooltip(message: section.label, child: destination)
        : destination;
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.onOpenSearch});

  final VoidCallback onOpenSearch;

  String _greetingWord() {
    final hour = DateTime.now().hour;
    if (hour < 12) return t.dashboard.goodMorning;
    if (hour < 18) return t.dashboard.goodAfternoon;
    return t.dashboard.goodEvening;
  }

  String _firstName(Map<String, dynamic>? metadata, String? email) {
    final fullName = (metadata?['full_name'] as String?)?.trim();
    final name = fullName?.isNotEmpty ?? false
        ? fullName!.split(RegExp(r'\s+')).first
        : email?.split('@').first;
    return name ?? '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardControllerProvider);
    final syncPending = dashboard.errorMessage != null;
    final user = ref.watch(desktopAuthControllerProvider).user;
    final isPrivate = ref.watch(activeDesktopDataModeProvider).isPrivate;
    final privateProfile = ref.watch(privateProfileProvider).value;
    final privateName = isPrivate ? privateProfile?.fullName : null;
    final avatarUrl = isPrivate
        ? privateProfile?.avatarPath
        : user?.userMetadata?['avatar_url'] as String?;
    final isPro = ref.watch(desktopIsProProvider);

    final name = user != null
        ? _firstName(user.userMetadata, user.email)
        : _firstName(
            privateName != null ? {'full_name': privateName} : null,
            null,
          );
    final greeting = name.isEmpty
        ? _greetingWord()
        : '${_greetingWord()}, $name';

    final date = DateTime.now();
    final dateLabel =
        '${t.common.weekdaysLong[date.weekday - 1]}, ${date.day} '
        '${t.common.months[date.month - 1]}';

    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: context.evolveColors.background.withValues(alpha: 0.7),
        border: Border(
          bottom: BorderSide(
            color: context.evolveColors.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.evolveColors.foreground,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: EvolveColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: context.evolveColors.muted,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 240,
              child: InkWell(
                onTap: onOpenSearch,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: context.evolveColors.panel.withValues(alpha: 0.4),
                    border: Border.all(
                      color: context.evolveColors.border.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.search,
                        size: 15,
                        color: context.evolveColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.shell.searchHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.evolveColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '⌘ K',
                        style: TextStyle(
                          color: context.evolveColors.subtle,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (syncPending) ...[
              StatusPill(
                label: t.shell.syncPending,
                color: EvolveColors.amber,
                icon: LucideIcons.cloudOff,
              ),
              const SizedBox(width: 4),
            ],
            IconButton(
              tooltip: t.shell.syncTooltip,
              onPressed: dashboard.isRefreshing
                  ? null
                  : ref.read(dashboardControllerProvider.notifier).refresh,
              icon: dashboard.isRefreshing
                  ? const SizedBox.square(
                      dimension: 15,
                      child: EvolveSpinner(radius: 7.5),
                    )
                  : const Icon(LucideIcons.refreshCw, size: 16),
              style: IconButton.styleFrom(
                foregroundColor: context.evolveColors.muted,
              ),
            ),
            const SizedBox(width: 10),
            _AvatarButton(
              initials: _initials(
                user?.userMetadata ??
                    (privateName != null ? {'full_name': privateName} : null),
                user?.email,
              ),
              avatarUrl: avatarUrl,
              isPrivateMode: isPrivate,
              isPro: isPro,
              onTap: () => ref
                  .read(navigationControllerProvider.notifier)
                  .select(DesktopSection.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.initials,
    this.avatarUrl,
    this.isPrivateMode = false,
    required this.isPro,
    required this.onTap,
  });

  final String initials;
  final String? avatarUrl;
  final bool isPrivateMode;
  final bool isPro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Mobile profile ring: gold for Pro users, faint accent otherwise.
    final ringColor = isPro
        ? EvolveColors.amber
        : context.evolveAccent.withValues(alpha: 0.4);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ringColor, width: 1.5),
          ),
          child: ClipOval(
            child: Container(
              color: context.evolveColors.panel,
              alignment: Alignment.center,
              child: avatarUrl != null
                  ? Image(
                      image: isPrivateMode
                          ? FileImage(File(avatarUrl!))
                          : NetworkImage(avatarUrl!) as ImageProvider,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : Text(
                      initials,
                      style: TextStyle(
                        color: context.evolveColors.foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _initials(Map<String, dynamic>? metadata, String? email) {
  final fullName = (metadata?['full_name'] as String?)?.trim();
  final source = fullName?.isNotEmpty ?? false ? fullName! : email ?? '';
  final parts = source
      .split(RegExp(r'[\s@._-]+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList();
  return parts.isEmpty
      ? '--'
      : parts.map((part) => part[0].toUpperCase()).join();
}
