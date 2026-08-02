import 'package:evolve_legal/evolve_legal.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/auth/application/consent_controller.dart';
import 'package:evolve_desktop/features/settings/data/desktop_notification_service.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class DesktopConsentPage extends ConsumerStatefulWidget {
  const DesktopConsentPage({super.key});

  @override
  ConsumerState<DesktopConsentPage> createState() => _DesktopConsentPageState();
}

class _DesktopConsentPageState extends ConsumerState<DesktopConsentPage> {
  bool _acceptedTerms = false;

  /// Opt-IN, not opt-out. A pre-armed switch collects no consent — it collects
  /// inattention — and it uploads to a third party either way, which is what
  /// Guideline 5.1.2 asks us not to do (macOS 1.0.0(26) rejection, 2026-08-01).
  bool _sentryConsent = false;
  bool _notificationsAllowed = false;
  bool _isSaving = false;

  TextStyle get _rowTitleStyle => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: context.evolveColors.foreground,
  );

  TextStyle get _rowSubtitleStyle => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: context.evolveColors.muted.withValues(alpha: 0.8),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final accent = context.evolveAccent;

    // The card is height-bounded and scrolls INTERNALLY, so Continue is pinned
    // to the bottom of the panel and is on screen at any window size in any of
    // the five languages. The whole card used to scroll as one piece, which put
    // the only way forward below the fold once the disclosure was added — and a
    // reviewer who cannot find Continue files a bug, not an approval.
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: EvolvePanel(
              padding: const EdgeInsets.all(28),
              radius: 20,
              glowColor: accent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EvolveIconChip(
                        icon: LucideIcons.shieldCheck,
                        color: accent,
                        size: 44,
                        iconSize: 21,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.consent.onboardingTitle,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t.consentPage.subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                                color: colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The disclosure sits ABOVE the checkbox on purpose: the
                          // guideline asks that the upload be made clear *and then*
                          // consented to, so the user reads what leaves the Mac before
                          // the control that agrees to it.
                          const _UploadDisclosure(),
                          const SizedBox(height: 14),
                          _ConsentRow(
                            child: CheckboxListTile(
                              contentPadding:
                                  const EdgeInsetsDirectional.fromSTEB(
                                    16,
                                    6,
                                    12,
                                    6,
                                  ),
                              value: _acceptedTerms,
                              onChanged: (value) => setState(
                                () => _acceptedTerms = value ?? false,
                              ),
                              title: Text(
                                t.consentPage.acceptTerms,
                                style: _rowTitleStyle,
                              ),
                              subtitle: Text(
                                t.consentPage.termsSubtitle,
                                style: _rowSubtitleStyle,
                              ),
                            ),
                          ),
                          _ConsentRow(
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsetsDirectional.fromSTEB(
                                    16,
                                    6,
                                    12,
                                    6,
                                  ),
                              // Whole-row toggle (SwitchListTile parity).
                              onTap: () => setState(
                                () => _sentryConsent = !_sentryConsent,
                              ),
                              title: Text(
                                t.consentPage.crashDiagnostics,
                                style: _rowTitleStyle,
                              ),
                              subtitle: Text(
                                t.consentPage.crashSubtitle,
                                style: _rowSubtitleStyle,
                              ),
                              trailing: EvolveSwitch(
                                value: _sentryConsent,
                                onChanged: (value) =>
                                    setState(() => _sentryConsent = value),
                              ),
                            ),
                          ),
                          _ConsentRow(
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsetsDirectional.fromSTEB(
                                    12,
                                    6,
                                    12,
                                    6,
                                  ),
                              leading: EvolveIconChip(
                                icon: LucideIcons.bell,
                                color: accent,
                                size: 36,
                                iconSize: 17,
                                outlined: true,
                              ),
                              title: Text(
                                t.consentPage.notificationsTitle,
                                style: _rowTitleStyle,
                              ),
                              subtitle: Text(
                                t.consentPage.notificationsSubtitle,
                                style: _rowSubtitleStyle,
                              ),
                              trailing: _notificationsAllowed
                                  ? StatusPill(
                                      label: t.consentPage.notificationsEnabled,
                                      color: EvolveColors.success,
                                      icon: LucideIcons.check,
                                    )
                                  : TextButton(
                                      onPressed: _isSaving
                                          ? null
                                          : _requestNotifications,
                                      child: Text(
                                        t.consentPage.enableNotifications,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Pinned, not scrolled: a Terms link the reviewer has to
                  // scroll to find is how the 3.1.2(c) rejection happened once
                  // already. Both documents stay visible next to Continue.
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: _openTerms,
                        style: TextButton.styleFrom(
                          foregroundColor: colors.muted,
                        ),
                        icon: const Icon(LucideIcons.externalLink, size: 14),
                        label: Text(t.consentPage.openTerms),
                      ),
                      TextButton.icon(
                        onPressed: _openPrivacyPolicy,
                        style: TextButton.styleFrom(
                          foregroundColor: colors.muted,
                        ),
                        icon: const Icon(LucideIcons.externalLink, size: 14),
                        label: Text(t.consentPage.openPrivacy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _acceptedTerms && !_isSaving
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: FilledButton(
                      onPressed: _acceptedTerms && !_isSaving
                          ? _continue
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? SizedBox.square(
                              dimension: 18,
                              child: EvolveSpinner(
                                radius: 9,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : Text(
                              t.consent.continueButton,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestNotifications() async {
    final granted = await DesktopNotificationService.instance
        .requestPermissions();
    if (mounted) setState(() => _notificationsAllowed = granted);
  }

  /// The site publishes each language from its own directory, so legal links
  /// follow the app's language.
  String get _lang => LocaleSettings.currentLocale.languageCode;

  /// Opened the privacy policy, on the premise that "the app's single legal page
  /// covers terms + privacy". That premise was never true: terms.html has been
  /// live on the site all along, and a "Terms of Service" link that opens the
  /// privacy policy is not a functional Terms link (Guideline 3.1.2).
  Future<void> _openTerms() async {
    await launchUrl(
      LegalUrls.terms(_lang),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openPrivacyPolicy() async {
    await launchUrl(
      LegalUrls.privacy(_lang),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _continue() async {
    setState(() => _isSaving = true);
    await ref
        .read(desktopConsentControllerProvider.notifier)
        .setConsent(
          acceptedTerms: _acceptedTerms,
          sentryConsent: _sentryConsent,
          completed: true,
        );
    if (mounted) setState(() => _isSaving = false);
  }
}

/// The pre-consent disclosure required by App Store Guideline 5.1.2: personal
/// data may not be uploaded to a server until the user has been told, in the
/// app, that it will be — and has agreed.
///
/// It names the recipient in each case rather than saying "third parties", and
/// it states the negative too (contacts, calendar, photos, camera, microphone,
/// location are never touched). The negative is not padding: the rejection
/// arrived on Apple's Contacts template, and the app has never held a
/// `NSContactsUsageDescription` key or an address-book entitlement to explain
/// itself with. Saying so on screen is the only place a user — or a reviewer —
/// can read it without taking our word for it in a reply.
class _UploadDisclosure extends StatelessWidget {
  const _UploadDisclosure();

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final accent = context.evolveAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.consentPage.uploadTitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 10),
          _DisclosureBullet(
            icon: LucideIcons.cloudUpload,
            color: accent,
            title: t.consentPage.uploadAccountTitle,
            body: t.consentPage.uploadAccountBody,
          ),
          _DisclosureBullet(
            icon: LucideIcons.laptop,
            color: EvolveColors.success,
            title: t.consentPage.uploadPrivateTitle,
            body: t.consentPage.uploadPrivateBody,
          ),
          _DisclosureBullet(
            icon: LucideIcons.eyeOff,
            color: colors.muted,
            title: t.consentPage.uploadNeverTitle,
            body: t.consentPage.uploadNeverBody,
          ),
        ],
      ),
    );
  }
}

/// One disclosure line: bold lead-in, then the detail, on the same flowing
/// paragraph.
///
/// Stacked title-over-body would read as well but costs ~50pt a bullet, and the
/// consent card has to stay inside the default 1440x900 window — a Continue
/// button below the fold is how a reviewer decides the app is broken.
class _DisclosureBullet extends StatelessWidget {
  const _DisclosureBullet({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;

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
                      color: colors.foreground,
                    ),
                  ),
                  const TextSpan(text: ' — '),
                  TextSpan(text: body),
                ],
              ),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: colors.muted.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Translucent sub-card wrapper for a consent row (mobile settings-row look:
/// panel .4 fill, half-strength border, radius 14). The inner transparent
/// [Material] keeps tile ink splashes visible and clipped to the radius.
class _ConsentRow extends StatelessWidget {
  const _ConsentRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.evolveColors.panel.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.evolveColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
