import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The four generic dialogs the Settings flows share.
///
/// They were `_SettingsPageState` methods, which is a large part of why every
/// flow that needed one had to live on that class too. Each takes the
/// BuildContext explicitly — the same context the page passed implicitly.

/// A yes/no confirmation. Returns false when dismissed, so a cancelled dialog
/// is never mistaken for an approval.
Future<bool> confirmSettingsAction(
  BuildContext context, {
  required String title,
  required String message,
  bool destructive = false,
  String? confirmLabel,
}) async {
  return await showEvolveDialog<bool>(
        context: context,
        builder: (context) => EvolveAlertDialog(
          icon: destructive
              ? LucideIcons.triangleAlert
              : LucideIcons.circleCheck,
          iconColor: destructive ? EvolveColors.destructive : null,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.settingsPage.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: EvolveColors.destructive,
                    )
                  : null,
              child: Text(confirmLabel ?? t.settingsPage.confirm),
            ),
          ],
        ),
      ) ??
      false;
}

void showSettingsGate(BuildContext context, String title, String detail) {
  showEvolveToast(context, message: '$title: $detail');
}

void showSettingsLoadingDialog(BuildContext context, String message) {
  showEvolveDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => EvolveDialog(
      maxWidth: 280,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 28,
              child: EvolveSpinner(radius: 14),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ctx.evolveColors.foreground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showSettingsResultDialog(
  BuildContext context,
  String title,
  String detail,
) {
  showEvolveDialog<void>(
    context: context,
    builder: (ctx) => EvolveAlertDialog(
      icon: LucideIcons.info,
      title: Text(title),
      content: Text(detail),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.notifications.actionDone),
        ),
      ],
    ),
  );
}
