import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: LucideIcons.house, label: 'Home'),
      _NavItem(icon: LucideIcons.chartBar, label: 'Statistiche'),
      _NavItem(icon: LucideIcons.chartPie, label: 'Obiettivi'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32), // More centered floating
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Stronger blur for Apple look
          child: Container(
            height: 84, // Increased height to prevent clipping
            decoration: BoxDecoration(
              color: const Color(0xCC0A0A0A), // More premium dark glass
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5, // Thinner, more precise border
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isActive = currentIndex == index;
                return _NavBarItem(
                  icon: item.icon,
                  label: item.label,
                  isActive: isActive,
                  onTap: () {
                    HapticFeedback.selectionClick(); // Different haptic for Apple feel
                    onTap(index);
                  },
                );
              }),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 4), // Top margin for balance
            AnimatedScale(
              scale: isActive ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: isActive ? 40 : 0,
                    height: isActive ? 40 : 0,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Icon(
                    icon,
                    size: 22,
                    color: isActive ? primaryColor : AppColors.mutedForeground.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: GoogleFonts.inter( // Using Inter for cleaner look
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? primaryColor : AppColors.mutedForeground.withValues(alpha: 0.5),
                letterSpacing: -0.1,
              ),
              child: Text(label),
            ),
            const SizedBox(height: 6),
            // Subtly animated dot indicator with enough space
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              width: isActive ? 3 : 0,
              height: isActive ? 3 : 0,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  if (isActive)
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2), // Bottom safety margin
          ],
        ),
      ),
    );

  }
}
