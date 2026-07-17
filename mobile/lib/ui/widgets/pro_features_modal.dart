import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/theme.dart';
import '../../core/haptics.dart';
import '../../core/app_logger.dart';
import '../../core/subscription_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/subscription_screen.dart';
import '../../i18n/translations.g.dart';
import '../kit/evolve_sheet.dart';

const String _monthlyProductId = 'com.simo.evolve.pro.monthly';

class ProFeaturesModal extends ConsumerStatefulWidget {
  const ProFeaturesModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ProFeaturesModal(),
    );
  }

  @override
  ConsumerState<ProFeaturesModal> createState() => _ProFeaturesModalState();
}

class _ProFeaturesModalState extends ConsumerState<ProFeaturesModal> {
  /// Only ever holds a localized `StoreProduct.priceString`; null means no
  /// price could be resolved and none may be shown.
  String? _monthlyPrice;

  @override
  void initState() {
    super.initState();
    _loadMonthlyPrice();
  }

  Future<void> _loadMonthlyPrice() async {
    final monthly = (await ref.read(subscriptionServiceProvider).getOfferings())
        ?.current
        ?.monthly;
    if (monthly != null) {
      if (!mounted) return;
      setState(() => _monthlyPrice = monthly.storeProduct.priceString);
      return;
    }

    // The offering may not be published yet; the raw product still carries the
    // storefront-correct price.
    try {
      final products = await Purchases.getProducts([_monthlyProductId]);
      if (products.isEmpty || !mounted) return;
      setState(() => _monthlyPrice = products.first.priceString);
    } catch (e, stack) {
      AppLogger.error('[ProFeaturesModal] Monthly price fetch failed', e, stack);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: context.appColors.border, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const EvolveGrabber(),
          const SizedBox(height: 32),
          
          // Premium Icon Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withValues(alpha: 0.2),
                  Colors.amber.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                )
              ],
            ),
            child: const Icon(
              LucideIcons.sparkles,
              size: 40,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            context.t.common.unlockEvolvePro,
            style: GoogleFonts.inter(
              color: context.appColors.foreground,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t.subscription.takeYourHabitSystemToThe,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: context.appColors.mutedForeground,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          
          // Features List — ordered by what the subscription ACTUALLY unlocks.
          //
          // The coach used to lead this list, from when it was Pro-gated. It is
          // not any more: bring-your-own-key is free, which is the Guideline
          // 3.1.1 fix. Leading a paywall with a feature you can have for nothing
          // is an inaccurate subscription description — Guideline 3.1.2, which
          // this app is already rejected under — so the real gates go first, and
          // the coach goes last saying what Pro genuinely buys for it: no setup.
          _buildFeatureItem(
            context: context,
            icon: LucideIcons.infinity,
            // The gate every free user actually meets, at five habits.
            title: context.t.subscription.unlimitedHabits,
            description: context.t.subscription.createAndTrackAllTheHabits,
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            context: context,
            icon: LucideIcons.cloud,
            title: context.t.subscription.habitSpecificStatistics,
            description: context.t.subscription.keyInsightsToBoostYourProductivity,
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            context: context,
            icon: LucideIcons.trendingUp,
            title: context.t.subscription.advancedGoalMetrics,
            description: context.t.subscription.viewDetailedChartsAndDeepPerformance,
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            context: context,
            icon: LucideIcons.brainCircuit,
            title: context.t.subscription.personalizedAiCoach,
            description: context.t.subscription.advancedTrendAnalysisAndSmartAi,
          ),

          const SizedBox(height: 40),
          
          // CTA Button
          GestureDetector(
            onTap: () {
              ref.hapticMedium();
              Navigator.pop(context); // Close the bottom sheet
              Navigator.push(context, SubscriptionScreen.route()); // Redirect to real subscription flow!
            },
            child: Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.shade400,
                    Colors.amber.shade700,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Center(
                child: Text(
                  _monthlyPrice == null
                      ? context.t.subscription.actions.seePlans
                      : context.t.subscription.getProAtPrice(
                          price: _monthlyPrice!,
                        ),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.t.subscription.maybeLater,
              style: GoogleFonts.inter(
                color: context.appColors.mutedForeground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.appColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appColors.border),
          ),
          child: Icon(icon, size: 20, color: Colors.amber),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: context.appColors.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  color: context.appColors.mutedForeground,
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
