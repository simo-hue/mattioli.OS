import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:evolve_legal/evolve_legal.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../core/app_logger.dart';
import '../../core/rtl.dart';
import 'dart:ui';

import '../../core/theme.dart';
import '../../core/haptics.dart';
import '../../core/subscription_service.dart';
import '../../providers/settings_provider.dart';
import '../widgets/subscription_alert_modal.dart';
import '../../i18n/translations.g.dart';
import '../kit/evolve_dialog.dart';
import '../kit/evolve_spinner.dart';
import '../kit/evolve_toast.dart';

const String _monthlyProductId = 'com.simo.evolve.pro.monthly';
const String _yearlyProductId = 'com.simo.evolve.pro.yearly';

/// Whole-percent saving of the annual plan against twelve months of the monthly
/// plan, or null when there is no honest saving to claim.
///
/// Computed from live StoreKit prices rather than stated as a constant. The old
/// copy said "Save over 40%" in every storefront; Apple's price tiers are not
/// linear across currencies, so that was a fixed claim about a variable number —
/// understated in EUR (the real figure is 50%) and potentially false elsewhere.
///
/// Returns null when either price is unusable or the annual plan is not actually
/// cheaper, so the UI can fall back to a neutral line instead of inventing one.
@visibleForTesting
int? annualSavingPercent({
  required double monthlyPrice,
  required double yearlyPrice,
}) {
  if (monthlyPrice <= 0 || yearlyPrice <= 0) return null;
  final saving = (1 - yearlyPrice / (monthlyPrice * 12)) * 100;
  // Round first: 0.6% would otherwise survive the check and render as "Save 1%".
  final rounded = saving.round();
  if (rounded < 1) return null;
  return rounded;
}

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  static Route route() {
    // MaterialPageRoute so iOS gets the native Cupertino slide + edge-swipe-back
    // gesture for free (Android keeps its native Material transition).
    return MaterialPageRoute(builder: (context) => const SubscriptionScreen());
  }

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  Package? _monthlyPackage;
  Package? _yearlyPackage;
  Package? _selectedPackage;
  CustomerInfo? _customerInfo;

  bool _isLoading = false;
  bool _isFetchingProducts = true;
  String _selectedMockPackage = 'yearly';

  /// Products resolved directly from the store when no Offering is published.
  /// Null means nothing could be resolved and no price may be shown — never
  /// substitute a hardcoded one, it would be wrong in every other storefront.
  StoreProduct? _fallbackMonthlyProduct;
  StoreProduct? _fallbackYearlyProduct;

  /// The store products in play, whichever path resolved them. Everything
  /// price-related reads these so the Offering and direct-fetch paths cannot
  /// drift apart.
  StoreProduct? get _monthlyProduct =>
      _monthlyPackage?.storeProduct ?? _fallbackMonthlyProduct;
  StoreProduct? get _yearlyProduct =>
      _yearlyPackage?.storeProduct ?? _fallbackYearlyProduct;

  /// The site publishes each language from its own directory, so legal links
  /// follow the app's language — an App Review engineer on an English device
  /// must not land in an Italian privacy policy.
  String get _lang => LocaleSettings.currentLocale.languageCode;

  /// Opens one of the paywall's mandatory legal links.
  ///
  /// These were fire-and-forget `launchUrl(...)` calls: the Future was neither
  /// awaited nor checked, so a failure was swallowed and the link did nothing
  /// at all. Guideline 3.1.2 requires *functional* privacy and Terms links, and
  /// a link that silently does nothing is the failure it describes — so surface
  /// it instead.
  Future<void> _openLegalUrl(Uri url) async {
    bool ok = false;
    try {
      ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e, stack) {
      AppLogger.warning('[Subscription] legal link failed: $url', e, stack);
    }
    if (!ok && mounted) {
      showEvolveToast(
        context,
        message: context.t.common.unableToOpenTheLink,
        kind: EvolveToastKind.error,
      );
    }
  }

  /// Subtitle for the annual plan, carrying the two things Guideline 3.1.2 asks
  /// for beyond the headline price: the price per unit, and a saving that is
  /// actually true.
  ///
  /// Both come from StoreKit at runtime, never from constants. Apple's price
  /// tiers are not linear across currencies, so the old hardcoded "Save over
  /// 40%" was only ever checkable in euros (where it is really 50%) and could
  /// be plainly false elsewhere. `pricePerMonthString` is RevenueCat's own
  /// localized per-month figure — dividing and formatting it ourselves would
  /// just reintroduce the currency bug.
  String? _annualSubtitle(BuildContext context) {
    final yearly = _yearlyProduct;
    final perMonth = yearly?.pricePerMonthString;
    // Null for non-subscription products: show nothing rather than guess.
    if (yearly == null || perMonth == null) return null;

    final monthly = _monthlyProduct;
    final t = context.t.subscription.plans;
    final percent = monthly == null
        ? null
        : annualSavingPercent(
            monthlyPrice: monthly.price,
            yearlyPrice: yearly.price,
          );
    if (percent == null) return t.perMonth(price: perMonth);
    return t.perMonthWithSavings(price: perMonth, percent: percent);
  }

  @override
  void initState() {
    super.initState();
    _loadOfferings();
    _loadCustomerInfo();
  }

  /// Loads the real subscription state; the details panel renders only what
  /// this returns and omits any row it cannot resolve.
  Future<void> _loadCustomerInfo() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      if (!mounted) return;
      setState(() => _customerInfo = customerInfo);
    } catch (e, stack) {
      AppLogger.warning('[Subscription] CustomerInfo unavailable', e, stack);
    }
  }

  /// Loads the active offerings from the App Store dynamically via RevenueCat
  Future<void> _loadOfferings() async {
    try {
      final offerings = await ref
          .read(subscriptionServiceProvider)
          .getOfferings();
      if (mounted && offerings != null && offerings.current != null) {
        final current = offerings.current!;
        setState(() {
          _monthlyPackage = current.monthly;
          _yearlyPackage = current.annual;

          // Default selection to Yearly (best value) or Monthly if Yearly is null
          _selectedPackage = _yearlyPackage ?? _monthlyPackage;
          _isFetchingProducts = false;
        });
        return; // Success, live offerings loaded!
      }
    } catch (_) {
      // Quiet fail to try direct products fetch
    }

    // Secondary attempt: Fetch raw products directly from App Store Connect to pull dynamic prices even before Offering is published!
    try {
      final products = await Purchases.getProducts([
        _monthlyProductId,
        _yearlyProductId,
      ]);
      if (products.isNotEmpty && mounted) {
        setState(() {
          for (final product in products) {
            if (product.identifier == _monthlyProductId) {
              _fallbackMonthlyProduct = product;
            } else if (product.identifier == _yearlyProductId) {
              _fallbackYearlyProduct = product;
            }
          }
        });
      }
    } catch (e, stack) {
      AppLogger.error(
        '[Subscription] Secondary product fetch failed',
        e,
        stack,
      );
    }

    if (mounted) {
      setState(() {
        _isFetchingProducts = false;
      });
    }
  }

  /// Restores previous purchases (Apple compliance required)
  Future<void> _restorePurchases() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    ref.hapticMedium();

    try {
      final result = await ref
          .read(subscriptionServiceProvider)
          .restorePurchasesWithResult();
      if (!mounted) return;
      setState(() => _customerInfo = result.customerInfo);

      if (result.isProActive) {
        unawaited(
          SubscriptionAlertModal.show(
            context,
            title: context.t.subscription.status.restored,
            message: context.t.subscription.status.restoredMessage,
            type: SubscriptionAlertType.success,
            ref: ref,
          ),
        );
      } else {
        unawaited(
          SubscriptionAlertModal.show(
            context,
            title: context.t.subscription.errors.noPurchaseTitle,
            message: context.t.subscription.errors.noActiveSubscription,
            type: SubscriptionAlertType.warning,
            ref: ref,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      unawaited(
        SubscriptionAlertModal.show(
          context,
          title: context.t.subscription.errors.restoreFailedTitle,
          message: _restoreErrorMessage(e),
          type: SubscriptionAlertType.error,
          details: e.toString(),
          ref: ref,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Triggers Apple's payment sheet flow
  Future<void> _purchase() async {
    if (_isLoading || _selectedPackage == null) return;

    setState(() => _isLoading = true);
    ref.hapticMedium();

    try {
      final result = await ref
          .read(subscriptionServiceProvider)
          .purchasePackageWithResult(_selectedPackage!);
      if (!mounted) return;
      setState(() => _customerInfo = result.customerInfo);

      if (result.isProActive) {
        _showSuccessDialog(context);
      } else {
        unawaited(
          SubscriptionAlertModal.show(
            context,
            title: context.t.subscription.status.processing,
            message: context.t.subscription.errors.purchaseRegisteredNotActive,
            type: SubscriptionAlertType.warning,
            ref: ref,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      if (_isPurchaseCancelled(e)) {
        return;
      }

      // A deferred/pending transaction has not failed — it is parked awaiting
      // approval and completes through the CustomerInfo listener.
      final isPending = _isPurchasePending(e);

      unawaited(
        SubscriptionAlertModal.show(
          context,
          title: isPending
              ? context.t.subscription.status.processing
              : context.t.subscription.errors.purchaseFailedTitle,
          message: _purchaseErrorMessage(e),
          type: isPending
              ? SubscriptionAlertType.warning
              : SubscriptionAlertType.error,
          details: isPending ? null : e.toString(),
          ref: ref,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isPurchaseCancelled(Object error) {
    if (error is! PlatformException) return false;
    return SubscriptionService.purchasesErrorCode(error) ==
        PurchasesErrorCode.purchaseCancelledError;
  }

  bool _isPurchasePending(Object error) {
    if (error is! PlatformException) return false;
    final errorCode = SubscriptionService.purchasesErrorCode(error);
    return errorCode == PurchasesErrorCode.paymentPendingError ||
        errorCode == PurchasesErrorCode.operationAlreadyInProgressError;
  }

  String _purchaseErrorMessage(Object error) {
    if (error is PlatformException) {
      if (_isPaidAppsAgreementError(error)) {
        return context.t.subscription.errors.paidAppsAgreement;
      }

      final errorCode = SubscriptionService.purchasesErrorCode(error);
      return switch (errorCode) {
        PurchasesErrorCode.productAlreadyPurchasedError =>
          context.t.subscription.errors.alreadyPurchased,
        PurchasesErrorCode.purchaseNotAllowedError =>
          context.t.subscription.errors.purchasesNotAllowed,
        PurchasesErrorCode.productNotAvailableForPurchaseError =>
          context.t.subscription.errors.planUnavailable,
        PurchasesErrorCode.paymentPendingError =>
          context.t.subscription.errors.paymentPending,
        PurchasesErrorCode.networkError ||
        PurchasesErrorCode.offlineConnectionError ||
        PurchasesErrorCode.apiEndpointBlocked =>
          context.t.subscription.errors.connectionUnavailable,
        PurchasesErrorCode.configurationError ||
        PurchasesErrorCode.invalidCredentialsError ||
        PurchasesErrorCode.invalidReceiptError ||
        PurchasesErrorCode.missingReceiptFileError =>
          context.t.subscription.errors.invalidConfig,
        PurchasesErrorCode.receiptAlreadyInUseError ||
        PurchasesErrorCode.receiptInUseByOtherSubscriberError ||
        PurchasesErrorCode.purchaseBelongsToOtherUser =>
          context.t.subscription.errors.linkedToAnotherAccount,
        PurchasesErrorCode.operationAlreadyInProgressError =>
          context.t.subscription.errors.purchaseInProgress,
        _ => context.t.subscription.errors.purchaseFailedMessage,
      };
    }

    return context.t.subscription.errors.purchaseFailedMessage;
  }

  String _restoreErrorMessage(Object error) {
    if (error is PlatformException) {
      if (_isPaidAppsAgreementError(error)) {
        return context.t.subscription.errors.paidAppsAgreement;
      }

      final errorCode = SubscriptionService.purchasesErrorCode(error);
      return switch (errorCode) {
        PurchasesErrorCode.purchaseCancelledError =>
          context.t.subscription.status.restoreCancelled,
        PurchasesErrorCode.networkError ||
        PurchasesErrorCode.offlineConnectionError ||
        PurchasesErrorCode.apiEndpointBlocked =>
          context.t.subscription.errors.connectionUnavailable,
        PurchasesErrorCode.receiptAlreadyInUseError ||
        PurchasesErrorCode.receiptInUseByOtherSubscriberError ||
        PurchasesErrorCode.purchaseBelongsToOtherUser =>
          context.t.subscription.errors.linkedToAnotherAccount,
        PurchasesErrorCode.configurationError ||
        PurchasesErrorCode.invalidCredentialsError ||
        PurchasesErrorCode.invalidReceiptError ||
        PurchasesErrorCode.missingReceiptFileError =>
          context.t.subscription.errors.invalidConfig,
        PurchasesErrorCode.operationAlreadyInProgressError =>
          context.t.subscription.errors.restoreInProgress,
        _ => context.t.subscription.errors.restoreFailedMessage,
      };
    }

    return context.t.subscription.errors.restoreFailedMessage;
  }

  bool _isPaidAppsAgreementError(PlatformException error) {
    final msg = error.message?.toLowerCase() ?? '';
    final details = error.details?.toString().toLowerCase() ?? '';
    return msg.contains('paid apps agreement') ||
        msg.contains('paid applications agreement') ||
        details.contains('paid apps agreement') ||
        details.contains('paid applications agreement');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isPro = settings.isPro;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: context.appColors.background,
          appBar: AppBar(
            backgroundColor: context.appColors.background,
            elevation: 0,
            leading: IconButton(
              icon: DirectionalIcon(
                LucideIcons.chevronLeft,
                LucideIcons.chevronRight,
                color: context.appColors.foreground,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              context.t.common.subscription,
              style: TextStyle(
                color: context.appColors.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            centerTitle: true,
          ),
          body: _isFetchingProducts
              ? const Center(child: EvolveSpinner(color: Colors.amber))
              : RefreshIndicator(
                  color: Colors.amber,
                  backgroundColor: context.appColors.card,
                  onRefresh: () async {
                    setState(() {
                      _isFetchingProducts = true;
                    });
                    await Future.wait([_loadOfferings(), _loadCustomerInfo()]);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isPro) ...[
                          _buildUpsellHeader(context),
                          const SizedBox(height: 32),
                          _buildFeaturesList(context),
                          const SizedBox(height: 40),
                          _buildPlanSelector(context),
                          const SizedBox(height: 24),
                          _buildComplianceLinks(context),
                        ] else ...[
                          _buildProStatusHeader(context),
                          const SizedBox(height: 32),
                          _buildSubscriptionDetails(context),
                          const SizedBox(height: 40),
                          _buildManageActions(context),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(child: EvolveSpinner(color: Colors.amber)),
          ),
      ],
    );
  }

  Widget _buildUpsellHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.withValues(alpha: 0.1),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              LucideIcons.sparkles,
              size: 32,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.t.subscription.upgradeTitle,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.appColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t.subscription.upgradeSubtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: context.appColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t.subscription.featuresHeader,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.appColors.mutedForeground,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        // Ordered by what the subscription ACTUALLY unlocks — see the same note
        // in pro_features_modal.dart. The coach led this list from when it was
        // Pro-gated; bring-your-own-key is now free, so leading with it would
        // sell something you can have for nothing (Guideline 3.1.2). It goes
        // last, describing what Pro genuinely buys for it: no setup.
        _buildFeatureRow(
          context,
          LucideIcons.infinity,
          context.t.subscription.unlimitedHabits,
          context.t.subscription.features.unlimitedHabits,
        ),
        const SizedBox(height: 16),
        _buildFeatureRow(
          context,
          LucideIcons.trendingUp,
          context.t.subscription.features.advancedStats,
          context.t.subscription.features.deepCharts,
        ),
        const SizedBox(height: 16),
        _buildFeatureRow(
          context,
          LucideIcons.target,
          context.t.subscription.features.unlimitedGoals,
          context.t.subscription.features.unlimitedMacroGoals,
        ),
        const SizedBox(height: 16),
        _buildFeatureRow(
          context,
          LucideIcons.brainCircuit,
          context.t.subscription.personalizedAiCoach,
          context.t.subscription.features.smartSuggestions,
        ),
      ],
    );
  }

  Widget _buildFeatureRow(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.appColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appColors.border),
          ),
          child: Icon(icon, size: 18, color: Colors.amber),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.appColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanSelector(BuildContext context) {
    if (_monthlyPackage == null && _yearlyPackage == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t.subscription.choosePlanHeader,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.appColors.mutedForeground,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _buildMockPlanCard(
            context.t.subscription.plans.monthly,
            _fallbackMonthlyProduct?.priceString,
            context.t.subscription.plans.cancelAnytime,
            _selectedMockPackage == 'monthly',
            onTap: () {
              setState(() => _selectedMockPackage = 'monthly');
            },
          ),
          const SizedBox(height: 12),
          _buildMockPlanCard(
            context.t.subscription.plans.annual,
            _fallbackYearlyProduct?.priceString,
            // No claim we cannot substantiate: if the store gave us no
            // per-month figure, fall back to the neutral line rather than
            // asserting a saving.
            _annualSubtitle(context) ??
                context.t.subscription.plans.cancelAnytime,
            _selectedMockPackage == 'yearly',
            isBestValue: true,
            onTap: () {
              setState(() => _selectedMockPackage = 'yearly');
            },
          ),
          if (_fallbackMonthlyProduct == null ||
              _fallbackYearlyProduct == null) ...[
            const SizedBox(height: 12),
            Text(
              context.t.subscription.errors.pricesUnavailable,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: context.appColors.mutedForeground,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () async {
              ref.hapticMedium();
              setState(() => _isLoading = true);
              try {
                // Background attempt to dynamically load real offerings
                final offerings = await ref
                    .read(subscriptionServiceProvider)
                    .getOfferings();
                if (mounted && offerings != null && offerings.current != null) {
                  final current = offerings.current!;
                  final package = _selectedMockPackage == 'monthly'
                      ? current.monthly
                      : current.annual;
                  if (package != null) {
                    setState(() {
                      _monthlyPackage = current.monthly;
                      _yearlyPackage = current.annual;
                      _selectedPackage = package;
                      _isLoading = false;
                      _isFetchingProducts = false;
                    });
                    // Successfully bridged to real StoreKit purchase!
                    await _purchase();
                    return;
                  }
                }
              } catch (_) {}

              if (!context.mounted) return;
              setState(() => _isLoading = false);
              unawaited(
                SubscriptionAlertModal.show(
                  context,
                  title: context.t.subscription.errors.connectionTitle,
                  message: context.t.subscription.errors.serviceUnreachable,
                  type: SubscriptionAlertType.error,
                  ref: ref,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade400, Colors.amber.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  context.t.subscription.actions.activate,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t.subscription.choosePlanHeader,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.appColors.mutedForeground,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (_monthlyPackage != null)
          _buildPlanCard(
            _monthlyPackage!,
            context.t.subscription.plans.monthly,
            context.t.subscription.plans.cancelAnytime,
          ),
        if (_yearlyPackage != null) ...[
          const SizedBox(height: 12),
          _buildPlanCard(
            _yearlyPackage!,
            context.t.subscription.plans.annual,
            _annualSubtitle(context) ??
                context.t.subscription.plans.cancelAnytime,
            isBestValue: true,
          ),
        ],
        const SizedBox(height: 32),
        GestureDetector(
          onTap: _purchase,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade400, Colors.amber.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                context.t.subscription.actions.activate,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(
    Package package,
    String title,
    String subtitle, {
    bool isBestValue = false,
  }) {
    final isSelected = _selectedPackage?.identifier == package.identifier;
    final priceStr = package.storeProduct.priceString;

    return GestureDetector(
      onTap: () {
        ref.hapticLight();
        setState(() {
          _selectedPackage = package;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.amber.withValues(alpha: 0.8)
                : context.appColors.border,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.amber : context.appColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${context.t.subscription.proName} $title',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.appColors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              priceStr,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.appColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays mandatory links for Apple guidelines: EULA & Privacy Policy (Guideline 3.1.2)
  Widget _buildComplianceLinks(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _isLoading ? null : _restorePurchases,
          icon: const Icon(LucideIcons.refreshCcw, size: 16),
          label: Text(context.t.subscription.actions.restore),
          style: TextButton.styleFrom(
            foregroundColor: Colors.amber,
            textStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.t.subscription.renewalDisclaimer,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: context.appColors.mutedForeground,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _openLegalUrl(LegalUrls.privacy(_lang)),
              child: Text(
                context.t.subscription.privacyPolicy,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.amber,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              '  •  ',
              style: TextStyle(color: context.appColors.mutedForeground),
            ),
            GestureDetector(
              onTap: () => _openLegalUrl(LegalUrls.appleEula),
              child: Text(
                context.t.subscription.termsEula,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.amber,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProStatusHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withValues(alpha: 0.1),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              LucideIcons.shieldCheck,
              size: 32,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.t.subscription.youArePro,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.appColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t.subscription.thankYou,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: context.appColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  /// The entitlement that actually grants Pro, or null when RevenueCat could
  /// not be reached or Pro comes from somewhere other than a purchase.
  EntitlementInfo? _activeProEntitlement() {
    final customerInfo = _customerInfo;
    if (customerInfo == null) return null;

    final entitlementId = SubscriptionService.evaluateProAccess(
      customerInfo,
    ).matchedEntitlementId;
    if (entitlementId == null) return null;

    return customerInfo.entitlements.all[entitlementId];
  }

  String _planLabel(BuildContext context, EntitlementInfo? entitlement) {
    return switch (entitlement?.productIdentifier) {
      _monthlyProductId =>
        '${context.t.subscription.proName} ${context.t.subscription.plans.monthly}',
      _yearlyProductId =>
        '${context.t.subscription.proName} ${context.t.subscription.plans.annual}',
      _ => context.t.subscription.proActiveName,
    };
  }

  Widget _buildSubscriptionDetails(BuildContext context) {
    final entitlement = _activeProEntitlement();
    // `expirationDate` is a nullable ISO-8601 string, absent for non-expiring
    // entitlements. Unparseable or absent means the row is omitted, never faked.
    final expiration = entitlement?.expirationDate == null
        ? null
        : DateTime.tryParse(entitlement!.expirationDate!)?.toLocal();
    final isAppStorePurchase =
        entitlement?.store == Store.appStore ||
        entitlement?.store == Store.macAppStore;
    final dateFormat = DateFormat(
      'dd MMMM yyyy',
      LocaleSettings.currentLocale.languageCode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t.subscription.detailsHeader,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.appColors.mutedForeground,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.appColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appColors.border),
          ),
          child: Column(
            children: [
              _buildDetailRow(
                context,
                context.t.subscription.plans.label,
                _planLabel(context, entitlement),
              ),
              const Divider(height: 32),
              _buildDetailRow(
                context,
                context.t.subscription.status.label,
                context.t.subscription.status.active,
                valueColor: Colors.green,
              ),
              if (expiration != null) ...[
                const Divider(height: 32),
                _buildDetailRow(
                  context,
                  entitlement!.willRenew
                      ? context.t.subscription.nextRenewal
                      : context.t.subscription.expiresOn,
                  dateFormat.format(expiration),
                ),
              ],
              if (isAppStorePurchase) ...[
                const Divider(height: 32),
                _buildDetailRow(
                  context,
                  context.t.subscription.paymentMethod,
                  context.t.subscription.paymentMethodValue,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.appColors.mutedForeground,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: valueColor ?? context.appColors.foreground,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildManageActions(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            ref.hapticLight();
            // Opens the official RevenueCat Customer Center directly inside the app
            ref.read(subscriptionServiceProvider).presentCustomerCenter();
          },
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: context.appColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appColors.border),
            ),
            child: Center(
              child: Text(
                context.t.subscription.actions.manage,
                style: TextStyle(
                  color: context.appColors.foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            ref.hapticHeavy();
            _showCancelDialog(context);
          },
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: context.appColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.destructive.withValues(alpha: 0.1),
              ),
            ),
            child: Center(
              child: Text(
                context.t.subscription.actions.cancel,
                style: const TextStyle(
                  color: AppColors.destructive,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSuccessDialog(BuildContext context) {
    ref.hapticHeavy(); // Trigger deep haptic feedback for celebration!

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.appColors.card.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.sparkles,
                    size: 40,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.t.subscription.welcomeTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.appColors.foreground,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.t.subscription.activeFullMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.appColors.mutedForeground,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () {
                    ref.hapticLight();
                    Navigator.pop(dialogContext);
                    Navigator.pop(
                      context,
                    ); // Close the subscription screen to return home!
                  },
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade400, Colors.amber.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        context.t.common.startYourJourney,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showEvolveConfirm(
      context: context,
      title: context.t.subscription.actions.manage,
      message: context.t.subscription.manageDisclaimer,
      confirmLabel: context.t.subscription.continueButton,
      isDestructive: true,
      ref: ref,
    ).then((confirmed) {
      if (confirmed) {
        ref.read(subscriptionServiceProvider).presentCustomerCenter();
      }
    });
  }

  Widget _buildMockPlanCard(
    String title,
    String? priceStr,
    String subtitle,
    bool isSelected, {
    bool isBestValue = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        ref.hapticLight();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.amber.withValues(alpha: 0.8)
                : context.appColors.border,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.amber : context.appColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${context.t.subscription.proName} $title',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.appColors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            // Must stay non-flexible: a flex child is measured against its
            // share of the row's free space instead of its own content, which
            // pulls the price off the right edge and squeezes the title
            // Expanded above to a fixed half of the row. See
            // test/paywall_plan_card_layout_test.dart.
            Text(
              priceStr ?? context.t.subscription.plans.priceUnavailable,
              style: GoogleFonts.inter(
                fontSize: priceStr == null ? 13 : 16,
                fontWeight: priceStr == null
                    ? FontWeight.w600
                    : FontWeight.w800,
                color: priceStr == null
                    ? context.appColors.mutedForeground
                    : context.appColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
