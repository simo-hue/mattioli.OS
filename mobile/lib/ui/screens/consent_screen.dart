import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evolve_legal/evolve_legal.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/app_logger.dart';
import '../../core/data_mode.dart';
import '../../core/sentry_service.dart';
import '../../providers/consent_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';
import '../kit/evolve_toast.dart';
import '../../core/haptics.dart';
import '../../i18n/translations.g.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _acceptedTerms = false;

  /// Opt-IN, not opt-out.
  ///
  /// This was `final … = true` with **no control anywhere on the screen**: the
  /// crash-diagnostics card had been removed (note the surviving "Item 1" /
  /// "Item 3" comments below) and the field was left behind, so tapping
  /// Continue enabled third-party telemetry for every user without ever asking
  /// one. Guideline 5.1.2 wants consent *provided*, and an unasked default is
  /// not that — the macOS twin was rejected on the same guideline for the
  /// equivalent defect on 2026-08-01. The card is restored below.
  bool _sentryConsent = false;
  bool _notificationsAllowed = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final status = await Permission.notification.status;
    if (!mounted) return;
    setState(() {
      _notificationsAllowed = status.isGranted;
    });
  }

  Future<void> _requestNotificationPermission() async {
    ref.hapticLight();
    final status = await Permission.notification.request();
    if (!mounted) return;
    setState(() {
      _notificationsAllowed = status.isGranted;
    });
  }

  /// The site publishes each language from its own directory, so legal links
  /// follow the app's language.
  String get _lang => LocaleSettings.currentLocale.languageCode;

  Future<void> _openUrl(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showEvolveToast(context, message: context.t.common.unableToOpenTheLink);
      }
    }
  }

  Future<void> _handleContinue() async {
    if (!_acceptedTerms) {
      ref.hapticHeavy();
      showEvolveToast(context, message: context.t.consent.termsRequired);
      return;
    }

    setState(() => _isLoading = true);
    ref.hapticMedium();

    // Every `ref` read has to happen before `setConsent`. Persisting the consent
    // flips consentProvider, which rebuilds the router and unmounts this screen;
    // a `ref` read after that throws a StateError in release builds too. The one
    // read below that follows an await is the `isLoggedIn` at the end of the
    // adoption block — deliberately, and guarded by `mounted`; the redirect
    // keeps this screen on '/consent' until the flag is written, so nothing has
    // unmounted at that point.
    final consentNotifier = ref.read(consentProvider.notifier);
    final authNotifier = ref.read(authProvider.notifier);
    final isPrivateMode =
        ref.read(activeDataModeProvider) == AppDataMode.private;

    // Bring Supabase up and adopt the device's session BEFORE persisting the
    // consent flag — the order is load-bearing three times over.
    //
    // `main()` refuses to initialise the SDK until this question has been
    // answered (`shouldInitialiseSupabaseAtStartup`), because on a REINSTALL the
    // Keychain session outlives `has_completed_consent`. The user has now
    // answered — this handler is only reachable with the terms accepted — so the
    // session may be picked up. Doing it here rather than after `setConsent`:
    //
    //  1. `isLoggedIn` below is read from the adopted state. Read before, it is
    //     always false on a reinstall and the server-side consent record is
    //     never written at all.
    //  2. `setConsent` rebuilds the router. With the session already adopted the
    //     redirect goes straight to '/'; without it the user is bounced to
    //     '/choose' first and held there for a Keychain read plus a token
    //     refresh — as a stranger, on their own account.
    //  3. That '/choose' detour is a window in which they can tap "Continue
    //     without an account". This ordering closes it rather than racing it.
    if (!isPrivateMode) {
      await authNotifier.adoptSessionAfterConsent();
    }
    if (!mounted) return;

    // AFTER adoption, deliberately. See (1).
    final isLoggedIn = ref.read(authProvider).isLoggedIn;

    // Salva il consenso nel provider
    await consentNotifier.setConsent(
      acceptedTerms: _acceptedTerms,
      sentryConsent: _sentryConsent,
      completed: true,
    );

    // Se l'utente è già loggato, salva il consenso anche nel DB
    if (isLoggedIn) {
      await authNotifier.updateConsentInDb(_acceptedTerms, _sentryConsent);
    }

    // Allinea Sentry alla risposta dell'utente, through the same predicate as
    // cold start so this screen and the next launch can never disagree.
    final sentryEnabled = SentryService.shouldRun(
      hasCompletedConsent: true,
      hasSentryConsent: _sentryConsent,
      isPrivateMode: isPrivateMode,
    );
    // Set both ways, not just on enable: leaving the flag at its startup value
    // means AppLogger keeps calling capture on a declined consent. The SDK is
    // closed so nothing ships, but the gate should state the decision.
    AppLogger.setExternalReportingDisabled(!sentryEnabled);
    await SentryService.setEnabled(sentryEnabled);

    if (!mounted) return;
    setState(() => _isLoading = false);

    // La navigazione verrà gestita automaticamente dal router in main.dart
    // grazie al cambio di stato in consentProvider.
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLightBg = primaryColor.computeLuminance() > 0.5;
    final activeTextColor = isLightBg ? Colors.black : Colors.white;
    final disabledTextColor =
        context.appColors.mutedForeground.computeLuminance() > 0.7
        ? Colors.grey[600]!
        : context.appColors.mutedForeground;
    final buttonTextColor = _acceptedTerms
        ? activeTextColor
        : disabledTextColor;

    return Scaffold(
      backgroundColor: context.appColors.background,
      body: Stack(
        children: [
          // Background Gradient Orbs
          PositionedDirectional(
            top: -100,
            end: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Consent Items. The HEADER SCROLLS WITH THEM, deliberately.
                  //
                  // It used to be a non-flex sibling of this Expanded, so its
                  // height grew linearly with the text scale while the Expanded
                  // absorbed the loss. Past roughly 2.5x Dynamic Type — iOS
                  // accessibility sizes reach ~3.1x — the flex child collapses
                  // to zero and the pinned Continue button below is laid out
                  // past the bottom edge and clipped. There is no other way off
                  // this screen, so that is a lockout, and it is invisible to
                  // any test that pumps at scale 1.0.
                  Expanded(
                    child: ListView(
                      children: [
                        const SizedBox(height: 24),
                        // Header
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.appColors.card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: context.appColors.border,
                                ),
                              ),
                              child: Icon(
                                LucideIcons.shieldCheck,
                                size: 40,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              context.t.consent.onboardingTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Inter', 
                                color: context.appColors.foreground,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.t.consent.onboardingSubtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Inter', 
                                color: context.appColors.mutedForeground,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Item 0: what actually leaves the device.
                        //
                        // Above the acceptance checkbox on purpose: Guideline
                        // 5.1.2 asks that the upload be made clear *and then*
                        // consented to, so the disclosure has to be read before
                        // the control that agrees to it.
                        _buildDisclosureCard(),

                        const SizedBox(height: 16),

                        // Item 1: Terms & Privacy
                        _buildConsentCard(
                          icon: LucideIcons.fileText,
                          title: context.t.consent.termsAndPrivacy,
                          description: context.t.consent.termsDescription,
                          trailing: Checkbox(
                            value: _acceptedTerms,
                            onChanged: (val) {
                              setState(() => _acceptedTerms = val ?? false);
                              ref.hapticLight();
                            },
                            activeColor: primaryColor,
                            checkColor: activeTextColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          // Both documents, because the checkbox accepts both.
                          // This card asked the user to accept Terms it never
                          // linked — you cannot consent to a document you were
                          // not shown (Guideline 3.1.2).
                          links: [
                            TextButton(
                              onPressed: () =>
                                  _openUrl(LegalUrls.privacy(_lang)),
                              child: Text(
                                context.t.auth.readPrivacyPolicy,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _openUrl(LegalUrls.terms(_lang)),
                              child: Text(
                                context.t.auth.termsOfService,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Item 2: Crash diagnostics. Restored — see the note on
                        // [_sentryConsent]. Off unless the user turns it on.
                        _buildConsentCard(
                          icon: LucideIcons.circleAlert,
                          title: context.t.consent.crashDiagnostics,
                          description: context.t.consent.crashDescription,
                          trailing: Switch.adaptive(
                            value: _sentryConsent,
                            onChanged: (val) {
                              setState(() => _sentryConsent = val);
                              ref.hapticLight();
                            },
                            activeTrackColor: primaryColor,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Item 3: Notifications
                        _buildConsentCard(
                          icon: LucideIcons.bell,
                          title: context.t.consent.systemNotifications,
                          description:
                              context.t.consent.notificationsDescription,
                          trailing: _notificationsAllowed
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 24,
                                )
                              : ElevatedButton(
                                  onPressed: _requestNotificationPermission,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    foregroundColor: primaryColor,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    context.t.common.actions.enable,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  // Continue Button
                  //
                  // Semantics + an always-live onTap, both deliberate. As a bare
                  // GestureDetector whose `onTap` went null while the terms were
                  // unaccepted, this node carried NO tap action and no button
                  // role: VoiceOver read the static word "Continue" with no hint
                  // that it was a control, no disabled state, and no way to
                  // learn that a checkbox was blocking it — a dead end on the
                  // only screen the user cannot leave. Same class of defect as
                  // the one found earlier on DataModeChoiceScreen, whose fix
                  // (`Semantics(button:, onTap:, excludeSemantics:)`) this
                  // follows.
                  //
                  // Tapping while unaccepted now runs `_handleContinue`, which
                  // already guards itself and answers with a haptic and the
                  // "you must accept the Terms" toast. Explaining the block
                  // beats swallowing the tap, for every user and not just
                  // VoiceOver ones.
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(
                      button: true,
                      enabled: !_isLoading && _acceptedTerms,
                      label: context.t.consent.continueButton,
                      excludeSemantics: true,
                      onTap: _isLoading ? null : _handleContinue,
                      child: GestureDetector(
                        onTap: _isLoading ? null : _handleContinue,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: _acceptedTerms
                                ? LinearGradient(
                                    colors: [
                                      primaryColor,
                                      primaryColor.withValues(alpha: 0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: _acceptedTerms
                                ? null
                                : context.appColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: _acceptedTerms
                                ? null
                                : Border.all(color: context.appColors.border),
                            boxShadow: _acceptedTerms
                                ? [
                                    BoxShadow(
                                      color: primaryColor.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    context.t.consent.continueButton,
                                    style: TextStyle(
                                      color: buttonTextColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The pre-consent disclosure required by App Store Guideline 5.1.2:
  /// personal data may not be uploaded to a server until the user has been told,
  /// in the app, that it will be — and has agreed.
  ///
  /// Each line names the recipient rather than saying "third parties", and the
  /// last two state the negatives, which on iOS are the ones that matter. This
  /// app really does read protected data (HealthKit, Screen Time), so the
  /// disclosure has to be precise about the boundary rather than deny access:
  /// the measurement is read on-device and only the pass/fail verdict is
  /// uploaded — `goal_provider.dart:1085` nulls a health-derived value before
  /// the Supabase upsert. Contacts, calendar, microphone and location are
  /// genuinely never touched (no matching `NS*UsageDescription` key exists in
  /// `ios/Runner/Info.plist`); camera and photo library are, but only to pick
  /// the profile photo, which the first bullet already declares as uploaded.
  Widget _buildDisclosureCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t.consent.uploadTitle,
            style: TextStyle(fontFamily: 'Inter', 
              color: context.appColors.mutedForeground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          _buildDisclosureBullet(
            icon: LucideIcons.cloudUpload,
            color: Theme.of(context).colorScheme.primary,
            title: context.t.consent.uploadAccountTitle,
            body: context.t.consent.uploadAccountBody,
          ),
          _buildDisclosureBullet(
            icon: LucideIcons.smartphone,
            color: Colors.green,
            title: context.t.consent.uploadPrivateTitle,
            body: context.t.consent.uploadPrivateBody,
          ),
          _buildDisclosureBullet(
            icon: LucideIcons.heartPulse,
            color: Theme.of(context).colorScheme.primary,
            title: context.t.consent.uploadHealthTitle,
            body: context.t.consent.uploadHealthBody,
          ),
          _buildDisclosureBullet(
            icon: LucideIcons.eyeOff,
            color: context.appColors.mutedForeground,
            title: context.t.consent.uploadNeverTitle,
            body: context.t.consent.uploadNeverBody,
          ),
        ],
      ),
    );
  }

  /// One disclosure line: bold lead-in, then the detail, on one flowing
  /// paragraph. Stacked title-over-body reads as well but costs ~50pt a bullet,
  /// and there are four of them on a phone.
  Widget _buildDisclosureBullet({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 10, top: 2),
            child: Icon(icon, size: 15, color: color),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.appColors.foreground,
                    ),
                  ),
                  const TextSpan(text: ' — '),
                  TextSpan(text: body),
                ],
              ),
              style: TextStyle(fontFamily: 'Inter', 
                color: context.appColors.mutedForeground,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCard({
    required IconData icon,
    required String title,
    required String description,
    required Widget trailing,
    List<Widget>? links,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MergeSemantics, so the control inherits the card's title and
          // description as its NAME. Without it the bare Checkbox and Switch
          // are siblings of the text rather than described by it, and VoiceOver
          // announces an unnamed "checkbox"/"switch" — on the screen that gates
          // the whole app, and on the very control Guideline 5.1.2 requires the
          // user to operate knowingly. Scoped to this Row so the legal-link
          // buttons below keep their own separate, tappable nodes.
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.appColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.appColors.border),
                  ),
                  child: ExcludeSemantics(
                    child: Icon(
                      icon,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontFamily: 'Inter', 
                          color: context.appColors.foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(fontFamily: 'Inter', 
                          color: context.appColors.mutedForeground,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing,
              ],
            ),
          ),
          if (links != null) ...[
            const SizedBox(height: 8),
            // Wrap, not Row: two TextButtons side by side overflow this card
            // (164pt in the test font, and on a real device as soon as Dynamic
            // Type is turned up or a language is wordier than English). What
            // gets clipped is the trailing link — the Terms of Service one,
            // i.e. the exact surface Guideline 3.1.2(c) is about. Wrap drops it
            // to a second line instead of cutting it off.
            // The SizedBox is load-bearing: the parent Column is
            // CrossAxisAlignment.start, so Wrap receives LOOSE width
            // constraints, shrink-wraps to its content, and `alignment: end`
            // has no free space to distribute — the links would silently move
            // from right- to left-aligned (mirrored under RTL). Forcing full
            // width restores the end alignment the old Row had.
            SizedBox(
              width: double.infinity,
              child: Wrap(alignment: WrapAlignment.end, children: links),
            ),
          ],
        ],
      ),
    );
  }
}
