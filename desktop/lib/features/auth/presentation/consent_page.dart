import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/auth/application/consent_controller.dart';
import 'package:evolve_desktop/features/settings/data/desktop_notification_service.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
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
  bool _sentryConsent = true;
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

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: EvolvePanel(
              padding: const EdgeInsets.all(28),
              radius: 20,
              glowColor: accent,
              child: Column(
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
                  _ConsentRow(
                    child: CheckboxListTile(
                      contentPadding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        6,
                        12,
                        6,
                      ),
                      value: _acceptedTerms,
                      onChanged: (value) =>
                          setState(() => _acceptedTerms = value ?? false),
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
                    child: SwitchListTile(
                      contentPadding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        6,
                        12,
                        6,
                      ),
                      value: _sentryConsent,
                      onChanged: (value) =>
                          setState(() => _sentryConsent = value),
                      title: Text(
                        t.consentPage.crashDiagnostics,
                        style: _rowTitleStyle,
                      ),
                      subtitle: Text(
                        t.consentPage.crashSubtitle,
                        style: _rowSubtitleStyle,
                      ),
                    ),
                  ),
                  _ConsentRow(
                    child: ListTile(
                      contentPadding: const EdgeInsetsDirectional.fromSTEB(
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
                              child: Text(t.consentPage.enableNotifications),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
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

  Future<void> _openTerms() async {
    // The app's single legal page covers terms + privacy (mirrors mobile).
    await launchUrl(
      Uri.parse('https://simo-hue.github.io/evolve/privacy.html'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openPrivacyPolicy() async {
    await launchUrl(
      Uri.parse('https://simo-hue.github.io/evolve/privacy.html'),
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
