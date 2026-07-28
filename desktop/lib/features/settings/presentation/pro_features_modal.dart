import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/subscription_pane.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The premium accent used across the Pro upsell surfaces (mirrors the
/// mobile pro-gold token, EvolveColors.amber).
const proAccent = EvolveColors.amber;

/// A single Pro feature (icon + localized title/description).
class ProFeature {
  const ProFeature(this.icon, this.title, this.description);
  final IconData icon;
  final String title;
  final String description;
}

/// The four Pro features, localized. Shared by the upsell modal and the paywall
/// feature list so the pitch stays in sync.
///
/// Ordered by what the subscription ACTUALLY unlocks. In account mode the AI
/// Coach is Pro-gated (a signed-in user cannot bring their own key — that path
/// lives in Private mode), so it is a genuine Pro unlock and an accurate paywall
/// line (Guideline 3.1.2). The habit/stats gates still lead because they are the
/// ones a free user meets first; the coach follows, saying what Pro buys it: no
/// setup, no key.
List<ProFeature> proFeatures() => [
  ProFeature(
    LucideIcons.infinity,
    // The gate every free user actually meets, at five habits.
    t.proModal.unlimitedTitle,
    t.proModal.unlimitedDesc,
  ),
  ProFeature(LucideIcons.cloud, t.proModal.statsTitle, t.proModal.statsDesc),
  ProFeature(
    LucideIcons.trendingUp,
    t.proModal.metricsTitle,
    t.proModal.metricsDesc,
  ),
  ProFeature(
    LucideIcons.brainCircuit,
    t.proModal.aiCoachTitle,
    t.proModal.aiCoachDesc,
  ),
];

/// Opens the Pro upsell dialog. Called from every locked-feature gate; its CTA
/// opens the paywall dialog ([showPaywallDialog]) directly — the plans + purchase
/// surface, which renders the correct per-platform state (purchase on macOS,
/// informative on Windows/Linux).
Future<void> showProFeaturesDialog(BuildContext context, WidgetRef ref) {
  // `ref` is accepted for call-site symmetry with the many gates that invoke
  // this; the dialog no longer needs it now that its CTA opens the paywall
  // dialog directly.
  return showEvolveDialog<void>(
    context: context,
    builder: (dialogContext) => const _ProFeaturesDialog(),
  );
}

class _ProFeaturesDialog extends StatelessWidget {
  const _ProFeaturesDialog();

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
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: proAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  showPaywallDialog(context);
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
        color: proAccent.withValues(alpha: 0.1),
        border: Border.all(color: proAccent.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: proAccent.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: proAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: proAccent.withValues(alpha: 0.3)),
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
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                feature.description,
                style: TextStyle(
                  color: colors.muted.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
