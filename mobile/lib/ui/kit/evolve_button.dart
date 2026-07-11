import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';

/// Visual variants for [EvolveButton].
enum EvolveButtonStyle { filled, tinted, secondary, destructive, plain }

/// Which gated haptic fires on tap (respects the user's haptics setting).
enum EvolveButtonHaptic { none, selection, medium, success }

/// iOS-style primary action button with a gated tap haptic and the native
/// press-fade (via [CupertinoButton]).
///
/// Unifies the app's two hand-rolled CTA patterns — Material `ElevatedButton`
/// and `GestureDetector` + `Container`. Text colour is chosen for contrast
/// against the (theme-driven) accent so it stays legible on any accent colour.
class EvolveButton extends ConsumerWidget {
  const EvolveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = EvolveButtonStyle.filled,
    this.haptic = EvolveButtonHaptic.selection,
    this.expand = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final EvolveButtonStyle style;
  final EvolveButtonHaptic haptic;
  final bool expand;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final accent = Theme.of(context).colorScheme.primary;

    final Color? background = switch (style) {
      EvolveButtonStyle.filled => accent,
      EvolveButtonStyle.destructive => colors.destructive,
      EvolveButtonStyle.tinted => accent.withValues(alpha: 0.14),
      EvolveButtonStyle.secondary => colors.muted,
      EvolveButtonStyle.plain => null,
    };
    final Color foreground = switch (style) {
      EvolveButtonStyle.filled =>
        accent.computeLuminance() > 0.6 ? Colors.black : Colors.white,
      EvolveButtonStyle.destructive =>
        colors.destructive.computeLuminance() > 0.6
            ? Colors.black
            : Colors.white,
      EvolveButtonStyle.tinted => accent,
      EvolveButtonStyle.secondary => colors.foreground,
      EvolveButtonStyle.plain => accent,
    };
    final Color disabledColor = switch (style) {
      EvolveButtonStyle.plain => Colors.transparent,
      EvolveButtonStyle.tinted => accent.withValues(alpha: 0.06),
      _ => colors.muted,
    };

    final Widget child = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CupertinoActivityIndicator(color: foreground, radius: 10),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
            ],
          );

    final button = CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      borderRadius: BorderRadius.circular(14),
      color: background,
      disabledColor: disabledColor,
      // While loading we keep `onPressed` non-null so the button stays filled
      // (accent) with a spinner, but swallow the tap.
      onPressed: onPressed == null
          ? null
          : () {
              if (loading) return;
              switch (haptic) {
                case EvolveButtonHaptic.none:
                  break;
                case EvolveButtonHaptic.selection:
                  ref.hapticSelection();
                  break;
                case EvolveButtonHaptic.medium:
                  ref.hapticMedium();
                  break;
                case EvolveButtonHaptic.success:
                  ref.hapticSuccess();
                  break;
              }
              onPressed!();
            },
      child: child,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
