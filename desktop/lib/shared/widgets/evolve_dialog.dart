import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';

Future<T?> showEvolveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: isDark ? 0.76 : 0.42),
    builder: builder,
  );
}

class EvolveDialog extends StatelessWidget {
  const EvolveDialog({
    required this.child,
    super.key,
    this.maxWidth = 520,
    this.alignment,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      alignment: alignment,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  context.evolveAccent.withValues(
                    alpha: isDark ? 0.055 : 0.035,
                  ),
                  colors.panelRaised,
                ),
                colors.panel,
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.borderStrong.withValues(
                alpha: isDark ? 0.78 : 0.64,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.52 : 0.16),
                blurRadius: 42,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: context.evolveAccent.withValues(alpha: 0.045),
                blurRadius: 28,
                spreadRadius: -8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: child,
          ),
        ),
      ),
    );
  }
}

class EvolveAlertDialog extends StatelessWidget {
  const EvolveAlertDialog({
    required this.title,
    super.key,
    this.content,
    this.actions = const [],
    this.icon,
    this.iconColor,
    this.subtitle,
    this.maxWidth = 520,
    this.alignment,
  });

  final Widget title;
  final Widget? content;
  final List<Widget> actions;
  final IconData? icon;
  final Color? iconColor;
  final String? subtitle;
  final double maxWidth;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    return EvolveDialog(
      maxWidth: maxWidth,
      alignment: alignment,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EvolveDialogHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: iconColor,
          ),
          if (content != null)
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
                child: content,
              ),
            ),
          if (actions.isNotEmpty) EvolveDialogActions(children: actions),
        ],
      ),
    );
  }
}

class EvolveDialogHeader extends StatelessWidget {
  const EvolveDialogHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.showCloseButton = true,
  });

  final Widget title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? context.evolveAccent;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 20, 14, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: effectiveIconColor.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(icon, color: effectiveIconColor, size: 20),
            ),
            const SizedBox(width: 13),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.headlineSmall,
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (showCloseButton) ...[
            const SizedBox(width: 10),
            IconButton(
              tooltip: t.habitsPage.close,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 19),
              style: IconButton.styleFrom(
                foregroundColor: context.evolveColors.muted,
                backgroundColor: context.evolveColors.panelSoft,
                minimumSize: const Size.square(34),
                maximumSize: const Size.square(34),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EvolveDialogActions extends StatelessWidget {
  const EvolveDialogActions({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.evolveColors.panelRaised.withValues(alpha: 0.56),
        border: Border(top: BorderSide(color: context.evolveColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: children,
          ),
        ),
      ),
    );
  }
}
