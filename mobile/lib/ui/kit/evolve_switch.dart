import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';

/// iOS toggle with a gated selection haptic. The app previously had zero
/// `CupertinoSwitch`; this is the single wrapper for all of them so the accent
/// track colour and haptic stay consistent.
class EvolveSwitch extends ConsumerWidget {
  const EvolveSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    return CupertinoSwitch(
      value: value,
      activeTrackColor: accent,
      onChanged: onChanged == null
          ? null
          : (v) {
              ref.hapticSelection();
              onChanged!(v);
            },
    );
  }
}

/// A full settings row (optional leading icon tile + title + optional subtitle +
/// [EvolveSwitch]) sized to sit inside an `EvolveListSection`.
class EvolveSwitchRow extends ConsumerWidget {
  const EvolveSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.leading,
    this.subtitle,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? leading;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: colors.foreground,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          EvolveSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
