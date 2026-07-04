import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/ai_coach/presentation/ai_coach_page.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/presentation/dashboard_page.dart';
import 'package:evolve_desktop/features/goals/presentation/goals_page.dart';
import 'package:evolve_desktop/features/habits/presentation/habits_page.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/features/statistics/presentation/statistics_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(navigationControllerProvider);
    final select = ref.read(navigationControllerProvider.notifier).select;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () =>
            select(DesktopSection.overview),
        const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () =>
            select(DesktopSection.habits),
        const SingleActivator(LogicalKeyboardKey.digit3, meta: true): () =>
            select(DesktopSection.insights),
        const SingleActivator(LogicalKeyboardKey.digit4, meta: true): () =>
            select(DesktopSection.goals),
        const SingleActivator(LogicalKeyboardKey.digit5, meta: true): () =>
            select(DesktopSection.coach),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): () =>
            select(DesktopSection.settings),
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
                  _DesktopSidebar(collapsed: collapsed),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      children: [
                        _TopBar(onOpenSearch: _showCommandPalette),
                        const Divider(height: 1),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: KeyedSubtree(
                              key: ValueKey(section),
                              child: _pageFor(section),
                            ),
                          ),
                        ),
                      ],
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
    await showEvolveDialog<void>(
      context: context,
      builder: (context) => const _CommandPalette(),
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
    final navigation = ref.read(navigationControllerProvider.notifier);
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
              onTap: () => navigation.select(section),
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
            onTap: () => navigation.select(DesktopSection.settings),
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
    final color = selected ? context.evolveAccent : context.evolveColors.muted;
    final destination = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 11 : 14,
        vertical: 3,
      ),
      child: Material(
        color: selected
            ? context.evolveAccent.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 15 : 12,
              vertical: 11,
            ),
            child: Row(
              children: [
                Icon(section.icon, color: color, size: 19),
                if (!collapsed) ...[
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      section.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    section.shortcut,
                    style: TextStyle(
                      color: context.evolveColors.subtle,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardControllerProvider);
    final syncPending = dashboard.errorMessage != null;
    final user = ref.watch(desktopAuthControllerProvider).user;
    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            StatusPill(
              label: syncPending
                  ? t.shell.syncPending
                  : dashboard.isRefreshing
                  ? t.shell.syncing
                  : t.shell.synced,
              color: syncPending ? EvolveColors.amber : context.evolveAccent,
              icon: syncPending
                  ? Icons.cloud_off_outlined
                  : Icons.cloud_done_outlined,
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: t.shell.syncTooltip,
              onPressed: dashboard.isRefreshing
                  ? null
                  : ref.read(dashboardControllerProvider.notifier).refresh,
              icon: dashboard.isRefreshing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 19),
            ),
            const Spacer(),
            SizedBox(
              width: 260,
              child: InkWell(
                onTap: onOpenSearch,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: context.evolveColors.panel,
                    border: Border.all(color: context.evolveColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: context.evolveColors.muted,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.shell.searchHint,
                          style: TextStyle(
                            color: context.evolveColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '⌘ K',
                        style: TextStyle(
                          color: context.evolveColors.subtle,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              Icons.notifications_none_rounded,
              color: context.evolveColors.muted,
              size: 21,
            ),
            const SizedBox(width: 18),
            CircleAvatar(
              radius: 16,
              backgroundColor: context.evolveColors.panelSoft,
              child: Text(
                _initials(user?.userMetadata, user?.email),
                style: TextStyle(
                  color: context.evolveAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
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

class _CommandPalette extends ConsumerWidget {
  const _CommandPalette();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EvolveDialog(
      alignment: const Alignment(0, -0.55),
      maxWidth: 520,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                hintText: t.shell.searchSectionHint,
              ),
            ),
            const SizedBox(height: 10),
            for (final section in DesktopSection.values)
              ListTile(
                dense: true,
                leading: Icon(section.icon, size: 19),
                title: Text(section.label),
                trailing: Text(
                  section.shortcut,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                onTap: () {
                  ref
                      .read(navigationControllerProvider.notifier)
                      .select(section);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}
