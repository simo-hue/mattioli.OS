import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The pill every search affordance on desktop wears.
///
/// There are two of them — the shell's ⌘K trigger in the top bar and the
/// filter field at the top of the Settings rail — and they are the same
/// promise to the user, so they have to be the same object to the eye. They
/// were not: the trigger was a 38px radius-12 pill and the field was a 30px
/// radius-8 box with different alphas, both spelled out inline in their own
/// files. This holds the numbers once so the next tweak cannot land on only
/// one of them.
///
/// It draws the box, the leading icon and the trailing slot; what sits in the
/// middle is the caller's — a [Text] label for the button, a live [TextField]
/// for the field.
abstract final class EvolveSearchChrome {
  /// Matches the shell top bar; the Settings rail follows it.
  static const double height = 38;
  static const double radius = 12;

  static const double iconSize = 15;

  /// Between the icon and the content, and again before the trailing slot.
  static const double gap = 8;

  static const EdgeInsetsGeometry padding = EdgeInsets.symmetric(
    horizontal: 12,
  );

  /// The hint/label style. The editable field reuses it for typed text with
  /// the foreground colour, so the caret does not shift as the user types.
  static TextStyle labelStyle(BuildContext context) => TextStyle(
    color: context.evolveColors.muted,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  /// The `⌘ K` / `⌘ F` badge style.
  static TextStyle badgeStyle(BuildContext context) => TextStyle(
    color: context.evolveColors.subtle,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  /// [focused] swaps the border for the accent colour — the field is typed
  /// into and has to say where the caret went, which the button never needs.
  static BoxDecoration decoration(BuildContext context, {bool focused = false}) {
    final colors = context.evolveColors;
    return BoxDecoration(
      color: colors.panel.withValues(alpha: focused ? 0.6 : 0.4),
      border: Border.all(
        color: focused
            ? context.evolveAccent.withValues(alpha: 0.85)
            : colors.border.withValues(alpha: 0.5),
      ),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// The pill itself: box, leading search icon, [child], optional [trailing].
  static Widget wrap(
    BuildContext context, {
    required Widget child,
    Widget? trailing,
    bool focused = false,
  }) {
    return Container(
      height: height,
      padding: padding,
      decoration: decoration(context, focused: focused),
      child: Row(
        children: [
          Icon(
            LucideIcons.search,
            size: iconSize,
            color: context.evolveColors.muted,
          ),
          const SizedBox(width: gap),
          Expanded(child: child),
          if (trailing != null) ...[const SizedBox(width: gap), trailing],
        ],
      ),
    );
  }

  /// A `⌘ K`-style keyboard hint for the trailing slot.
  static Widget badge(BuildContext context, String label) =>
      Text(label, style: badgeStyle(context));
}
