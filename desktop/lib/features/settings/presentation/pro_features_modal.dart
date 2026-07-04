import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The premium accent used across the Pro upsell surfaces (mirrors mobile).
const proAccent = Color(0xFFF59E0B); // amber 500

/// A single Pro feature (icon + localized title/description).
class ProFeature {
  const ProFeature(this.icon, this.title, this.description);
  final IconData icon;
  final String title;
  final String description;
}

/// The four Pro features, localized. Shared by the upsell modal and the paywall
/// feature list so the pitch stays in sync.
List<ProFeature> proFeatures() => [
  ProFeature(
    LucideIcons.brainCircuit,
    t.proModal.aiCoachTitle,
    t.proModal.aiCoachDesc,
  ),
  ProFeature(LucideIcons.cloud, t.proModal.statsTitle, t.proModal.statsDesc),
  ProFeature(
    LucideIcons.trendingUp,
    t.proModal.metricsTitle,
    t.proModal.metricsDesc,
  ),
  ProFeature(
    LucideIcons.infinity,
    t.proModal.unlimitedTitle,
    t.proModal.unlimitedDesc,
  ),
];

/// Opens the Pro upsell dialog. Called from every locked-feature gate; its CTA
/// deep-links to Settings → Subscription (which renders the correct per-platform
/// state — purchase on macOS, informative on Windows/Linux).
Future<void> showProFeaturesDialog(BuildContext context, WidgetRef ref) {
  return showEvolveDialog<void>(
    context: context,
    builder: (dialogContext) => _ProFeaturesDialog(ref: ref),
  );
}

class _ProFeaturesDialog extends StatelessWidget {
  const _ProFeaturesDialog({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    return EvolveDialog(
      maxWidth: 460,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProSparkleBadge(),
            const SizedBox(height: 20),
            Text(
              t.proModal.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.foreground,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t.proModal.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            for (final feature in proFeatures()) ...[
              ProFeatureRow(feature: feature),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: proAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  ref
                      .read(navigationControllerProvider.notifier)
                      .select(DesktopSection.settings);
                },
                child: Text(t.proModal.viewPlans),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                t.proModal.maybeLater,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProSparkleBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            proAccent.withValues(alpha: 0.2),
            proAccent.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: proAccent.withValues(alpha: 0.3), width: 2),
      ),
      child: const Icon(LucideIcons.sparkles, size: 36, color: proAccent),
    );
  }
}

/// A single feature row (icon tile + title/description). Reused by the upsell
/// dialog and the Settings paywall.
class ProFeatureRow extends StatelessWidget {
  const ProFeatureRow({required this.feature, super.key});

  final ProFeature feature;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.panelSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Icon(feature.icon, size: 18, color: proAccent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feature.title,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                feature.description,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
