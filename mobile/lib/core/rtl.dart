import 'package:flutter/widgets.dart';

/// RTL helpers for the Arabic (and any future right-to-left) locale.
///
/// Layout mirroring is handled structurally by Flutter when widgets use the
/// *Directional variants (`EdgeInsetsDirectional`, `AlignmentDirectional`,
/// `PositionedDirectional`). Glyph-based icons, however, are not mirrored
/// automatically — a `chevronLeft` "back" affordance still points left under
/// RTL unless we swap it. [directionalIcon] makes that swap explicit at the
/// call site. See LOCALIZATION_PLAN.md ("Arabic + RTL").

/// True when the nearest [Directionality] lays out right-to-left.
bool isRtl(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl;

/// Returns the direction-appropriate icon: [ltr] normally, or its mirror [rtl]
/// under a right-to-left [Directionality]. Pass the LTR-oriented icon first so
/// navigation/disclosure chevrons and arrows point the correct way in Arabic.
/// Use this where an `IconData` is needed directly (e.g. an `icon:` argument).
IconData directionalIcon(BuildContext context, IconData ltr, IconData rtl) =>
    isRtl(context) ? rtl : ltr;

/// An [Icon] that mirrors itself for right-to-left locales: renders [ltr]
/// normally and [rtl] under an RTL [Directionality]. Reads direction from its
/// own context, so it works in `const` call sites where no `context` is in
/// scope. Use for navigation/disclosure chevrons and arrows.
class DirectionalIcon extends StatelessWidget {
  final IconData ltr;
  final IconData rtl;
  final Color? color;
  final double? size;

  const DirectionalIcon(
    this.ltr,
    this.rtl, {
    this.color,
    this.size,
    super.key,
  });

  @override
  Widget build(BuildContext context) =>
      Icon(isRtl(context) ? rtl : ltr, color: color, size: size);
}
