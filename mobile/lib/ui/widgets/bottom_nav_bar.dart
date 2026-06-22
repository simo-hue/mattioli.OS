import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/haptics.dart';
import '../../i18n/translations.g.dart';

class AppBottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<GlobalKey>? navKeys;
  final bool navigationEnabled;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.navKeys,
    this.navigationEnabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final items = [
      _NavItem(
        icon: LucideIcons.activity,
        label: context.t.habits.statistics,
      ),
      _NavItem(icon: LucideIcons.house, label: context.t.habits.home),
      _NavItem(
        icon: LucideIcons.chartPie,
        label: context.t.common.goals,
      ),
    ];

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (!navigationEnabled) return;
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0) {
            // Swipe right -> Previous page
            if (currentIndex > 0) {
              onTap(currentIndex - 1);
            }
          } else if (details.primaryVelocity! < 0) {
            // Swipe left -> Next page
            if (currentIndex < items.length - 1) {
              onTap(currentIndex + 1);
            }
          }
        }
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              width: double.infinity,
              height: 68,
              decoration: BoxDecoration(
                color: context.appColors.card.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: context.appColors.border.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha:
                          context.appColors.background.computeLuminance() > 0.5
                          ? 0.1
                          : 0.3,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / items.length;

                  return Stack(
                    children: [
                      // Bottom "Accent" Bar
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutQuart,
                        left: itemWidth * currentIndex + (itemWidth * 0.15),
                        bottom: 0,
                        child: Container(
                          width: itemWidth * 0.7,
                          height: 3,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(100),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 1,
                                offset: const Offset(0, -1),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Nav Items
                      SizedBox(
                        height: 68,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(items.length, (index) {
                            final item = items[index];
                            final isActive = currentIndex == index;
                            return _NavBarItem(
                              key: navKeys?[index],
                              icon: item.icon,
                              label: item.label,
                              isActive: isActive,
                              onTap: navigationEnabled
                                  ? () {
                                      ref.hapticSelection();
                                      onTap(index);
                                    }
                                  : null,
                            );
                          }),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavBarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final enabled = onTap != null;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: !enabled ? 0.35 : (isActive ? 1.0 : 0.4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                transform: Matrix4.translationValues(
                  0.0,
                  isActive ? -4.0 : 0.0,
                  0.0,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isActive
                      ? primaryColor
                      : context.appColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive
                      ? primaryColor
                      : context.appColors.mutedForeground,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
