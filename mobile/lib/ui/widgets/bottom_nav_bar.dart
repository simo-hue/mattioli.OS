import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/haptics.dart';

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
    final items = [
      _NavItem(icon: LucideIcons.house, label: 'Home'),
      _NavItem(icon: LucideIcons.activity, label: 'Statistiche'),
      _NavItem(icon: LucideIcons.chartPie, label: 'Obiettivi'),
    ];

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          height: 64 + bottomPadding, // Slimmer height
          decoration: BoxDecoration(
            color: const Color(0xCC050505), // Deeper black glass
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
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
                    ref.hapticSelection();
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
            const SizedBox(height: 4),
            AnimatedScale(
              scale: isActive ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isActive)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  Icon(
                    icon,
                    size: 20, // Slightly smaller icon
                    color: isActive ? primaryColor : AppColors.mutedForeground.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? primaryColor : AppColors.mutedForeground.withValues(alpha: 0.4),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}
