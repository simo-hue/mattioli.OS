import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';

/// iOS grouped-list section header.
///
/// Replaces the recurring 10–12px UPPERCASE letter-spaced micro-labels: this is
/// ~13px, muted, left-aligned, and renders the title *as given* (no forced
/// `.toUpperCase()`). An optional [trailing] hosts an affordance such as "Edit".
class EvolveSectionHeader extends StatelessWidget {
  const EvolveSectionHeader(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 8),
    this.trailing,
  });

  final String title;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: colors.mutedForeground,
        letterSpacing: -0.1,
      ),
    );
    return Padding(
      padding: padding,
      child: trailing == null
          ? text
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Flexible(child: text), trailing!],
            ),
    );
  }
}
