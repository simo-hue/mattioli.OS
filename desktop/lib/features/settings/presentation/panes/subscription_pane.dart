import 'dart:async';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/settings/presentation/pro_features_modal.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_pane_scaffold.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_row_kit.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:evolve_legal/evolve_legal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class _PlatformNote extends StatelessWidget {
  const _PlatformNote({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      glowColor: EvolveColors.violet,
      child: Row(
        children: [
          const EvolveIconChip(
            icon: LucideIcons.monitor,
            color: EvolveColors.violet,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: SettingsRowCopy(label: title, detail: detail),
          ),
        ],
      ),
    );
  }
}

/// Product identifiers for the plan-label switch in the "already Pro" details
/// panel. Kept in sync with [DesktopSubscriptionController.proProductIds].
const _kMonthlyProductId = 'com.simo.evolve.pro.monthly';
const _kYearlyProductId = 'com.simo.evolve.pro.yearly';

/// Whole-percent saving of the annual plan against twelve months of the monthly
/// plan, or null when there is no honest saving to claim.
///
/// Computed from live store prices rather than stated as a constant: Apple's
/// price tiers are not linear across currencies, so a fixed "Save 40%" claim is
/// wrong in most storefronts. Returns null when either price is unusable or the
/// annual plan is not actually cheaper, so the UI falls back to a neutral line.
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

/// Opens the subscription purchase surface as a modal dialog — the SAME plans,
/// pricing, purchase, restore and compliance the Settings → Subscription section
/// renders, presented directly so a locked feature (e.g. the AI Coach) sends the
/// user straight to plans instead of deep-linking through Settings. This is the
/// desktop counterpart of the mobile SubscriptionScreen step of the paywall
/// funnel; the feature pitch is omitted because the Pro-features dialog that
/// opened this already made it.
Future<void> showPaywallDialog(BuildContext context) {
  return showEvolveDialog<void>(
    context: context,
    builder: (dialogContext) => EvolveDialog(
      maxWidth: 560,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        child: SettingsSubscriptionPane(
          showFeaturePitch: false,
          // A successful purchase should return the user to the feature they
          // were trying to unlock, so close this modal once Pro is active.
          onProActivated: () => Navigator.of(dialogContext).maybePop(),
        ),
      ),
    ),
  );
}

class SettingsSubscriptionPane extends ConsumerStatefulWidget {
  const SettingsSubscriptionPane({
    super.key,
    this.showFeaturePitch = true,
    this.onProActivated,
  });

  /// When false, the upsell panel + feature list at the top are omitted — used by
  /// [showPaywallDialog], where the preceding Pro-features dialog already pitched
  /// them and repeating would be redundant.
  final bool showFeaturePitch;

  /// Invoked after the user dismisses the purchase-success dialog. Set by
  /// [showPaywallDialog] to close the modal; null in the Settings section, where
  /// the surface should stay put and flip to the "already Pro" panel in place.
  final VoidCallback? onProActivated;

  @override
  ConsumerState<SettingsSubscriptionPane> createState() =>
      _SettingsSubscriptionPaneState();
}

class _SettingsSubscriptionPaneState
    extends ConsumerState<SettingsSubscriptionPane> {
  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(desktopSubscriptionControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsHeading(section: SettingsSection.subscription),
        const SizedBox(height: 20),
        // A subscribed user gets the status + details panel; everyone else gets
        // the purchase surface. Mirrors the mobile paywall's two states.
        if (subscription.isPro)
          ..._proView(context, subscription)
        else
          ..._purchaseView(context, subscription),
      ],
    );
  }

  // ------------------------------------------------------------------ Purchase

  List<Widget> _purchaseView(
    BuildContext context,
    DesktopSubscriptionState subscription,
  ) {
    final busy = subscription.isLoading;
    final plan = ref.watch(desktopSelectedPlanProvider);
    return [
      if (widget.showFeaturePitch) ...[
        _featurePitch(context),
        const SizedBox(height: 24),
        EvolveSectionLabel(t.proModal.featuresHeader, withRule: false),
        const SizedBox(height: 12),
        for (final feature in proFeatures()) ...[
          ProFeatureRow(feature: feature),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 6),
      ],
      _PlatformNote(
        title: subscription.isSupportedPlatform
            ? t.settingsPage.billingAppleTitle
            : t.settingsPage.commercialChannelRequired,
        detail: subscription.isSupportedPlatform
            ? subscription.isConfigured
                  ? t.settingsPage.billingAppleDetail
                  : t.settingsPage.billingUnavailableDetail
            : t.settingsPage.billingPlatformUnsupported,
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _PlanCard(
              key: SettingsKeys.row('subscription.planMonthly'),
              title: t.settingsPage.planMonthly,
              // Never fall back to the plan NAME here: that renders the title
              // twice where Guideline 3.1.2 requires the price per period. The
              // product resolves from the Offering or the direct-product fetch.
              price: subscription.monthlyProduct?.priceString,
              selected: plan == DesktopPlan.monthly,
              onTap: () => ref
                  .read(desktopSelectedPlanProvider.notifier)
                  .select(DesktopPlan.monthly),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _PlanCard(
              key: SettingsKeys.row('subscription.planAnnual'),
              title: t.settingsPage.planAnnual,
              price: subscription.yearlyProduct?.priceString,
              // Honest per-month + saving from live store prices, or the neutral
              // "best value" line when no price resolved — never an invented %.
              detail: _annualSubtitle(subscription) ?? t.settingsPage.bestValue,
              selected: plan == DesktopPlan.yearly,
              onTap: () => ref
                  .read(desktopSelectedPlanProvider.notifier)
                  .select(DesktopPlan.yearly),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      // The money step, as the loudest thing on the surface rather than the
      // quietest. It was a chevron row rendered identically to "Replay the
      // guided tour", two rows below the plan cards, naming neither the plan
      // the user had picked nor what it would cost — so the confirmation of
      // what you were about to buy lived only in a tint on a card above it.
      SettingsPrimaryButton(
        id: 'subscription.subscribe',
        icon: LucideIcons.sparkles,
        label: _subscribeLabel(subscription, plan),
        caption: t.settingsPage.activateEvolveProStart,
        busy: busy,
        onPressed: () => unawaited(_activate()),
      ),
      const SizedBox(height: 18),
      const _ComplianceLinks(),
      const SizedBox(height: 24),
      SettingsColumn(
        groups: [
          SettingsGroup(
            title: t.settingsPage.planManagement,
            children: [_restoreRow(busy)],
          ),
        ],
      ),
    ];
  }

  /// Names the plan being bought and what it costs.
  ///
  /// Falls back to the plan alone when no store price has resolved: a CTA is
  /// the last place to invent a figure, and the card beside it already says
  /// "Price unavailable".
  String _subscribeLabel(
    DesktopSubscriptionState subscription,
    DesktopPlan plan,
  ) {
    final planName = switch (plan) {
      DesktopPlan.monthly => t.settingsPage.planMonthly,
      DesktopPlan.yearly => t.settingsPage.planAnnual,
    };
    final price = subscription.productFor(plan)?.priceString;
    return price == null
        ? t.settingsPage.subscribeCtaNoPrice(plan: planName)
        : t.settingsPage.subscribeCta(plan: planName, price: price);
  }

  /// The ONE restore row, rendered by both states.
  ///
  /// It stays visible after subscribing on purpose: a Pro user whose
  /// entitlement has desynced (new Mac, reinstall, a purchase made on the
  /// iPhone) has no other way back, which is the gap the iPhone still has —
  /// it renders restore only in the non-Pro branch. Defined once so the two
  /// states cannot drift, and so neither can grow a second copy.
  Widget _restoreRow(bool busy) {
    return SettingsActionRow(
      id: 'subscription.restore',
      icon: LucideIcons.refreshCw,
      title: t.settingsPage.restorePurchases,
      detail: t.settingsPage.restorePurchasesDetail,
      busy: busy,
      onTap: () => unawaited(_restore()),
    );
  }

  Widget _featurePitch(BuildContext context) {
    return EvolvePanel(
      padding: const EdgeInsets.all(20),
      radius: 20,
      glowColor: proAccent,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: proAccent.withValues(alpha: 0.1),
                border: Border.all(color: proAccent.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                LucideIcons.sparkles,
                size: 26,
                color: proAccent,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              t.settingsPage.proUpsellTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.evolveColors.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.settingsPage.proUpsellSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.evolveColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Annual-plan subtitle carrying the two things Guideline 3.1.2 wants beyond
  /// the headline price: the price per month and a saving that is actually true.
  /// Both come from the store at runtime, never from constants — Apple's price
  /// tiers aren't linear across currencies, so a hardcoded "save X%" is false
  /// abroad. Returns null when no store price resolved, so the caller shows the
  /// neutral "best value" line instead of inventing a figure.
  String? _annualSubtitle(DesktopSubscriptionState subscription) {
    final yearly = subscription.yearlyProduct;
    final perMonth = yearly?.pricePerMonthString;
    if (yearly == null || perMonth == null) return null;
    final monthly = subscription.monthlyProduct;
    final percent = monthly == null
        ? null
        : annualSavingPercent(
            monthlyPrice: monthly.price,
            yearlyPrice: yearly.price,
          );
    if (percent == null) return t.settingsPage.perMonth(price: perMonth);
    return t.settingsPage.perMonthWithSavings(
      price: perMonth,
      percent: percent,
    );
  }

  // ---------------------------------------------------------------- Already Pro

  List<Widget> _proView(
    BuildContext context,
    DesktopSubscriptionState subscription,
  ) {
    final details = ref
        .read(desktopSubscriptionControllerProvider.notifier)
        .proDetails();
    return [
      EvolvePanel(
        padding: const EdgeInsets.all(20),
        radius: 20,
        glowColor: EvolveColors.success,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EvolveColors.success.withValues(alpha: 0.1),
                  border: Border.all(
                    color: EvolveColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  LucideIcons.shieldCheck,
                  size: 26,
                  color: EvolveColors.success,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                t.settingsPage.youArePro,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.evolveColors.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t.settingsPage.proThankYou,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.evolveColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      SettingsColumn(
        groups: [
          SettingsGroup(
            title: t.settingsPage.detailsHeader,
            children: _detailRows(context, details),
          ),
          SettingsGroup(
            title: t.settingsPage.planManagement,
            children: [
              SettingsActionRow(
                id: 'subscription.manage',
                icon: LucideIcons.creditCard,
                title: t.settingsPage.manageSubscription,
                detail: t.settingsPage.manageSubscriptionDetail,
                external: true,
                onTap: () => unawaited(_manage()),
              ),
              _restoreRow(subscription.isLoading),
            ],
          ),
        ],
      ),
    ];
  }

  List<Widget> _detailRows(BuildContext context, DesktopProDetails? details) {
    final planLabel = switch (details?.productIdentifier) {
      _kMonthlyProductId =>
        '${t.settingsPage.proName} ${t.settingsPage.planMonthly}',
      _kYearlyProductId =>
        '${t.settingsPage.proName} ${t.settingsPage.planAnnual}',
      _ => t.settingsPage.proActiveName,
    };
    final expiration = details?.expiration;
    final dateFormat = DateFormat(
      'dd MMMM yyyy',
      LocaleSettings.currentLocale.languageCode,
    );
    return [
      SettingsInfoRow(
        icon: LucideIcons.sparkles,
        label: t.settingsPage.planLabel,
        value: planLabel,
      ),
      SettingsInfoRow(
        icon: LucideIcons.circleCheck,
        label: t.settingsPage.statusLabel,
        value: t.settingsPage.statusActive,
      ),
      if (expiration != null)
        SettingsInfoRow(
          icon: LucideIcons.calendar,
          label: (details?.willRenew ?? false)
              ? t.settingsPage.nextRenewal
              : t.settingsPage.expiresOn,
          value: dateFormat.format(expiration),
        ),
      if (details?.isAppStorePayment ?? false)
        SettingsInfoRow(
          icon: LucideIcons.creditCard,
          label: t.settingsPage.paymentMethod,
          value: t.settingsPage.paymentMethodValue,
        ),
    ];
  }

  // -------------------------------------------------------------------- Actions

  Future<void> _activate() async {
    final controller = ref.read(desktopSubscriptionControllerProvider.notifier);
    final plan = ref.read(desktopSelectedPlanProvider);
    var package = ref
        .read(desktopSubscriptionControllerProvider)
        .packageFor(plan);

    // Prices may be showing via the direct-product fallback while no Offering is
    // published — but a purchase needs a Package. Retry the offering load once,
    // then purchase if one materialised; otherwise surface the failure.
    if (package == null) {
      await controller.refresh();
      package = ref
          .read(desktopSubscriptionControllerProvider)
          .packageFor(plan);
      if (package == null) {
        if (mounted) {
          showEvolveToast(
            context,
            message: t.subscriptionCtrl.loadOffersFailed,
            kind: EvolveToastKind.error,
          );
        }
        return;
      }
    }

    final result = await controller.purchase(package);
    if (!mounted) return;
    switch (result.status) {
      case DesktopPurchaseStatus.activated:
        _showProSuccessDialog();
        break;
      case DesktopPurchaseStatus.cancelled:
        break;
      case DesktopPurchaseStatus.pending:
        showEvolveToast(
          context,
          message: result.message ?? t.subscriptionCtrl.paymentPending,
        );
        break;
      case DesktopPurchaseStatus.registeredNotActive:
        showEvolveToast(
          context,
          message: t.subscriptionCtrl.purchaseRegisteredNotActive,
        );
        break;
      case DesktopPurchaseStatus.failed:
        showEvolveToast(
          context,
          message: result.message ?? t.subscriptionCtrl.purchaseFailedMessage,
          kind: EvolveToastKind.error,
        );
        break;
    }
  }

  Future<void> _restore() async {
    final result = await ref
        .read(desktopSubscriptionControllerProvider.notifier)
        .restore();
    if (!mounted) return;
    switch (result.status) {
      case DesktopRestoreStatus.restored:
        showEvolveToast(
          context,
          message: t.subscriptionCtrl.purchasesRestored,
          kind: EvolveToastKind.success,
        );
        break;
      case DesktopRestoreStatus.noActiveSub:
        showEvolveToast(
          context,
          message: t.subscriptionCtrl.noActiveSubscription,
        );
        break;
      case DesktopRestoreStatus.cancelled:
        break;
      case DesktopRestoreStatus.failed:
        showEvolveToast(
          context,
          message: result.message ?? t.subscriptionCtrl.restoreFailedMessage,
          kind: EvolveToastKind.error,
        );
        break;
    }
  }

  Future<void> _manage() async {
    final ok = await ref
        .read(desktopSubscriptionControllerProvider.notifier)
        .manageSubscription();
    if (!ok && mounted) {
      showEvolveToast(
        context,
        message: t.subscriptionCtrl.cantOpenApple,
        kind: EvolveToastKind.error,
      );
    }
  }

  void _showProSuccessDialog() {
    showEvolveDialog<void>(
      context: context,
      builder: (dialogContext) => EvolveDialog(
        maxWidth: 420,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: proAccent.withValues(alpha: 0.1),
                  border: Border.all(color: proAccent.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  size: 34,
                  color: proAccent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t.settingsPage.proWelcomeTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.evolveColors.foreground,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t.settingsPage.proActiveMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.evolveColors.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
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
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    // In the modal paywall this closes it so the user lands back
                    // on the unlocked feature; in the Settings section it's null
                    // and the surface flips to the "already Pro" panel in place.
                    widget.onProActivated?.call();
                  },
                  child: Text(t.settingsPage.proStartJourney),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Guideline 3.1.2 disclosures for the purchase surface: the auto-renewal
/// statement plus functional links to the Privacy Policy and the EULA. Same
/// copy and same targets as the mobile paywall.
class _ComplianceLinks extends StatelessWidget {
  const _ComplianceLinks();

  @override
  Widget build(BuildContext context) {
    // Privacy follows the app's language; the EULA is Apple's, which Apple
    // hosts and localises itself.
    final privacyPolicy = LegalUrls.privacy(
      LocaleSettings.currentLocale.languageCode,
    );
    return Column(
      children: [
        Text(
          t.settingsPage.renewalDisclaimer,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.evolveColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegalLink(label: t.settingsPage.privacyPolicy, url: privacyPolicy),
            Text(
              '  •  ',
              style: TextStyle(color: context.evolveColors.muted, fontSize: 12),
            ),
            _LegalLink(
              label: t.settingsPage.termsEula,
              url: LegalUrls.appleEula,
            ),
          ],
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.url});

  final String label;
  final Uri url;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () =>
            unawaited(launchUrl(url, mode: LaunchMode.externalApplication)),
        child: Text(
          label,
          style: TextStyle(
            color: context.evolveAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: context.evolveAccent,
          ),
        ),
      ),
    );
  }
}

/// One of the two plan choices.
///
/// Selection used to be carried by an accent tint and an accent border and
/// nothing else — on a card whose price is already painted in that same
/// accent. Colour alone is a weak signal for the one control that decides what
/// the user is charged, it is no signal at all to anyone who cannot separate
/// the two hues, and it never reached the accessibility tree: both cards
/// announced identically. There is now a radio indicator that fills and
/// carries a checkmark, and a `selected` flag a screen reader can read.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final String title;

  /// Localized store price, or null when the offering has not resolved. Never
  /// substitute the plan name: the price slot must read as a price or as an
  /// explicit absence of one.
  final String? price;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // MergeSemantics so the card announces as ONE choice — "Annual, €29.99,
    // selected" — rather than as three unrelated strings next to a button.
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: selected
                  ? context.evolveAccent.withValues(alpha: 0.08)
                  : context.evolveColors.panel.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? context.evolveAccent
                    : context.evolveColors.border.withValues(alpha: 0.5),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: context.evolveAccent.withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PlanRadio(selected: selected),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  price ?? t.settingsPage.priceUnavailable,
                  style: price == null
                      ? TextStyle(
                          color: context.evolveColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )
                      : TextStyle(
                          color: context.evolveAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 5),
                  Text(detail!, style: settingsRowSubtitleStyle(context)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The plan card's selection indicator: a radio ring that fills with the accent
/// and carries a checkmark when chosen. Shape and glyph both change, so the
/// state survives being read in greyscale.
class _PlanRadio extends StatelessWidget {
  const _PlanRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = context.evolveAccent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? accent : Colors.transparent,
        border: Border.all(
          color: selected ? accent : context.evolveColors.border,
          width: selected ? 1 : 1.5,
        ),
      ),
      child: selected
          ? Icon(
              LucideIcons.check,
              size: 13,
              color: Theme.of(context).colorScheme.onPrimary,
            )
          : null,
    );
  }
}
