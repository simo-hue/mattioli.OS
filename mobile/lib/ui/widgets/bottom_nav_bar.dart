import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/haptics.dart';
import '../../core/localization.dart';

class AppBottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    final items = [
      _NavItem(icon: LucideIcons.activity, label: context.l10n.translate('Statistiche')),
      _NavItem(icon: LucideIcons.house, label: context.l10n.translate('Home')),
      _NavItem(icon: LucideIcons.chartPie, label: context.l10n.translate('Obiettivi')),
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: double.infinity,
          height: 68 + bottomPadding,
          decoration: BoxDecoration(
            color: const Color(0xCC050505),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / items.length;
                
                return Stack(
                  children: [
                    // The "Drop" Indicator
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutQuart,
                      left: itemWidth * currentIndex + (itemWidth / 2) - 20,
                      bottom: 0,
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(100)),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.5),
                              blurRadius: 15,
                              spreadRadius: 2,
                              offset: const Offset(0, -2),
                            ),
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 8,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Nav Items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(items.length, (index) {
                        final item = items[index];
                        final isActive = currentIndex == index;
                        return _NavBarItem(
                          icon: item.icon,
                          label: item.label,
                          isActive: isActive,
                          onTap: () {
                            ref.hapticSelection();
                            onTap(index);
                          },
                        );
                      }),
                    ),
                  ],
                );
              },
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
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isActive ? 1.0 : 0.4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                transform: Matrix4.identity()
                  ..translate(0.0, isActive ? -4.0 : 0.0),
                child: Icon(
                  icon,
                  size: 22,
                  color: isActive ? primaryColor : AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? primaryColor : AppColors.mutedForeground,
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
