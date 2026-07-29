import 'dart:async';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/ai_coach/application/coach_consent_controller.dart';
import 'package:evolve_desktop/features/ai_coach/presentation/coach_settings_panels.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_pane_scaffold.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_row_kit.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// AI Coach: the engine configuration itself, inline, plus what the coach is
/// allowed to see.
class SettingsAiCoachPane extends ConsumerWidget {
  const SettingsAiCoachPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasConsent =
        ref.watch(hasAnyCoachConsentProvider).asData?.value ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsHeading(section: SettingsSection.aiCoach),
        const SizedBox(height: 20),
        SettingsColumn(
          groups: [
            // The engine configuration IS the pane now. There is no launcher
            // row and no modal: CoachSettingsDialog held the whole feature —
            // engine cards, API key, local server address, model picker — two
            // levels down behind a chevron, which is why none of it was
            // discoverable.
            SettingsGroup(
              title: t.coachSettings.groupEngine,
              children: const [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: CoachEnginePanel(),
                ),
              ],
            ),
            SettingsGroup(
              title: t.coachSettings.groupPrivacy,
              children: [
                // Withdrawing consent must be as easy as giving it (GDPR Art.
                // 7(3) — Simone is the named controller), and Guideline 5.1.2
                // expects the same.
                //
                // Always rendered, both states. It used to appear ONLY while a
                // consent existed, so the row erased itself the moment it was
                // used: there was no way to see that sharing was off, and no
                // way back. Splitting the status from the action is what lets
                // it stay.
                SettingsStatusRow(
                  id: 'coach.dataSharing',
                  label: t.ai.consent.rowTitle,
                  status: hasConsent
                      ? t.ai.consent.statusGranted
                      : t.ai.consent.consentStatusRevoked,
                  actionLabel: hasConsent
                      ? t.ai.consent.consentStopSharing
                      : null,
                  destructiveAction: true,
                  onAction: hasConsent
                      ? () => unawaited(_revokeCoachConsent(context, ref))
                      : null,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _revokeCoachConsent(BuildContext context, WidgetRef ref) async {
    final confirmed = await showEvolveDialog<bool>(
      context: context,
      builder: (dialogContext) => EvolveAlertDialog(
        icon: LucideIcons.triangleAlert,
        iconColor: EvolveColors.destructive,
        title: Text(t.ai.consent.revokeTitle),
        content: Text(
          t.ai.consent.revokeBody,
          style: TextStyle(
            color: dialogContext.evolveColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.common.actions.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.ai.consent.revokeAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(coachConsentStoreProvider).revokeAll();
    ref.invalidate(hasAnyCoachConsentProvider);
  }
}
