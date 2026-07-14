import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A small, read-only badge marking a habit whose completion is verified
/// automatically from the user's iPhone (HealthKit / Screen Time).
///
/// macOS has no verification engine, so on desktop this is purely informational:
/// a habit synced with a `verificationRule` would otherwise look pixel-identical
/// to a manual one. The badge explains why it behaves differently (mirrors
/// mobile's `VerificationBadge`, minus the interactive verify states). Gate the
/// caller on `habit.verificationRule != null`.
class VerifiedHabitBadge extends StatelessWidget {
  const VerifiedHabitBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    return Tooltip(
      message: t.settingsPage.verified,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colors.panelRaised,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.shieldCheck, size: 11, color: context.evolveAccent),
            const SizedBox(width: 3),
            Text(
              t.settingsPage.verified,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
