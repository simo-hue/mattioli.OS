import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/app_logger.dart';
import '../../core/haptics.dart';
import '../../core/notifications.dart';
import '../../core/theme.dart';
import '../../core/verification_providers.dart';
import '../../i18n/translations.g.dart';
import '../kit/evolve_toast.dart';

/// The Screen Time disclosure + opt-in, opened from Settings.
///
/// This exists for Guideline 2.1: "Does the app include any Screen Time
/// functionality? If so, identify the steps to navigate to it." So this surface
/// is reachable in two taps from launch, never hides, and does not depend on the
/// user having created a single habit — the thing to point a screen recording
/// at: launch, Settings, Screen Time.
///
/// Unlike HealthKit reads, FamilyControls authorization IS directly queryable
/// (D9), so this honestly renders notDetermined / denied / approved rather than
/// guessing. It is ONLY the app-wide `.individual` authorization + notification
/// opt-in; picking which apps a habit limits (Mode A) happens per-goal in the
/// habit editor, keyed by goalId — not here.
class ScreenTimeForm extends ConsumerWidget {
  const ScreenTimeForm({super.key});

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    ref.hapticMedium();
    try {
      await ref.read(screenTimeBridgeProvider).requestIndividualAuthorization();
    } on PlatformException catch (e) {
      // FamilyControls grants individual authorization to only ONE app per
      // device at a time (and also throws on denial). Fail gracefully with a
      // toast rather than an unhandled exception — this is the exact 2.1 opt-in
      // surface a reviewer taps, and their device may already hold the slot.
      AppLogger.warning('[ScreenTime] authorization request failed: ${e.message}');
      if (context.mounted) {
        showEvolveToast(
          context,
          message: context.t.verification.screenTime.authorizationUnavailable,
          kind: EvolveToastKind.error,
        );
      }
      return;
    }
    // Verdicts — including the extension's "limit reached" alert — arrive as
    // local notifications, so bundle the notification prompt into this opt-in.
    await NotificationService().requestPermissions();
    ref.invalidate(screenTimeAuthStatusProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final t = context.t.screenTime;
    final status = ref.watch(screenTimeAuthStatusProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.worksWith,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          _Notice(icon: LucideIcons.lock, text: t.privacyNote),
          const SizedBox(height: 20),
          status.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => _EnableButton(onPressed: () => _enable(context, ref)),
            data: (s) => switch (s) {
              ScreenTimeAuthorizationStatus.approved =>
                _Notice(icon: LucideIcons.check, text: t.enabledNote),
              ScreenTimeAuthorizationStatus.denied =>
                _Notice(icon: LucideIcons.info, text: t.deniedNote),
              ScreenTimeAuthorizationStatus.notDetermined => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.permissionNote,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        height: 1.45,
                        color: colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _EnableButton(onPressed: () => _enable(context, ref)),
                  ],
                ),
            },
          ),
          const SizedBox(height: 12),
          Text(
            t.manageHint,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.45,
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnableButton extends StatelessWidget {
  const _EnableButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        child: Text(context.t.screenTime.optIn),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: colors.mutedForeground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.4,
                color: colors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
