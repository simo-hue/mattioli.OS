import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../i18n/translations.g.dart';

/// iOS-native confirm/alert dialogs.
///
/// Replace the app's hand-rolled `Dialog` + `BackdropFilter` confirms and
/// Material `AlertDialog`s with a single Cupertino look. Both helpers wrap the
/// alert in a [CupertinoTheme] whose brightness is taken from the *app* theme
/// (not the system), so a user who forces dark/light mode gets a matching
/// dialog.

/// A yes/no confirm. Resolves to `true` only if the confirm action was tapped
/// (dismissing via the barrier or Cancel resolves to `false`).
///
/// iOS convention: a destructive action is red and Cancel is the bold default;
/// a non-destructive confirm (e.g. a consent "Accept") is itself the bold
/// default. Pass [ref] to fire a gated commit haptic on confirm.
Future<bool> showEvolveConfirm({
  required BuildContext context,
  required String title,
  String? message,
  String? confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
  WidgetRef? ref,
}) async {
  final brightness = Theme.of(context).brightness;
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoTheme(
      data: CupertinoThemeData(brightness: brightness),
      child: CupertinoAlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w600),
        ),
        content: message == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(message, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
              ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: isDestructive,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel ?? context.t.common.actions.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            isDefaultAction: !isDestructive,
            onPressed: () {
              ref?.hapticMedium();
              Navigator.pop(dialogContext, true);
            },
            child: Text(confirmLabel ?? context.t.common.actions.confirm),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// A single-dismiss informational alert (replaces one-button dialogs and some
/// SnackBar notices). Pass [content] for a rich body (e.g. a summary list);
/// otherwise [message] renders as plain text. [dismissLabel] defaults to the
/// shared "Got it" string.
Future<void> showEvolveAlert({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  String? dismissLabel,
}) {
  final brightness = Theme.of(context).brightness;
  return showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoTheme(
      data: CupertinoThemeData(brightness: brightness),
      child: CupertinoAlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w600),
        ),
        content: content ??
            (message == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(message, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
                  )),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dismissLabel ?? context.t.common.actions.gotIt),
          ),
        ],
      ),
    ),
  );
}
