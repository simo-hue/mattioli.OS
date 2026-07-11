import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';

/// iOS sliding segmented control with a gated selection haptic.
///
/// Replaces the app's hand-rolled `Row` + `GestureDetector` + `AnimatedContainer`
/// pills (view switcher, statistics tabs, goals mode, mood/trend ranges). By
/// default it stretches to fill its parent width with equal-width segments; set
/// [expand] to `false` to hug its content.
class EvolveSegmentedControl<T extends Object> extends ConsumerWidget {
  const EvolveSegmentedControl({
    super.key,
    required this.groupValue,
    required this.segments,
    required this.onValueChanged,
    this.expand = true,
  });

  final T groupValue;

  /// Ordered value→label map; insertion order defines segment order. [groupValue]
  /// must be one of the keys.
  final Map<T, String> segments;
  final ValueChanged<T> onValueChanged;
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    Widget label(T value, {double? width}) {
      final selected = value == groupValue;
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            segments[value]!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? colors.foreground : colors.mutedForeground,
            ),
          ),
        ),
      );
    }

    Widget control({double? segWidth}) {
      return CupertinoSlidingSegmentedControl<T>(
        groupValue: groupValue,
        backgroundColor: colors.muted.withValues(alpha: 0.6),
        thumbColor: colors.cardElevated,
        padding: const EdgeInsets.all(3),
        children: {
          for (final entry in segments.entries)
            entry.key: label(entry.key, width: segWidth),
        },
        onValueChanged: (v) {
          if (v != null && v != groupValue) {
            ref.hapticSelection();
            onValueChanged(v);
          }
        },
      );
    }

    if (!expand) return control();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        if (!available.isFinite) return control();
        // Fill the width with equal-width segments (control padding = 3*2).
        final segWidth = ((available - 6) / segments.length)
            .clamp(0.0, double.infinity);
        return SizedBox(width: available, child: control(segWidth: segWidth));
      },
    );
  }
}
