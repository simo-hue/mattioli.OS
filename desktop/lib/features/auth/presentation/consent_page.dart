import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/auth/application/consent_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class DesktopConsentPage extends ConsumerStatefulWidget {
  const DesktopConsentPage({super.key});

  @override
  ConsumerState<DesktopConsentPage> createState() => _DesktopConsentPageState();
}

class _DesktopConsentPageState extends ConsumerState<DesktopConsentPage> {
  bool _acceptedTerms = false;
  bool _sentryConsent = true;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: EvolvePanel(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 42,
                    color: context.evolveAccent,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t.consent.onboardingTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.consentPage.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _acceptedTerms,
                    onChanged: (value) =>
                        setState(() => _acceptedTerms = value ?? false),
                    title: Text(t.consentPage.acceptTerms),
                    subtitle: Text(t.consentPage.termsSubtitle),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _sentryConsent,
                    onChanged: (value) =>
                        setState(() => _sentryConsent = value),
                    title: Text(t.consentPage.crashDiagnostics),
                    subtitle: Text(t.consentPage.crashSubtitle),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _openPrivacyPolicy,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text(t.consentPage.openPrivacy),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton(
                      onPressed: _acceptedTerms && !_isSaving
                          ? _continue
                          : null,
                      child: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(t.consent.continueButton),
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
