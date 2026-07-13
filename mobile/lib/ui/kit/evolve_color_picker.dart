import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../i18n/translations.g.dart';
import 'evolve_sheet.dart';

/// Shared curated palette — mirrors the desktop kit
/// (`desktop/lib/shared/widgets/color_picker_dialog.dart`) so a colour chosen
/// on either platform comes from the same set.
const List<Color> kEvolveDefaultPalette = [
  Color(0xFFEF4444), // red
  Color(0xFFEAB308), // gold
  Color(0xFF22C55E), // green
  Color(0xFF06B6D4), // cyan
  Color(0xFF3B82F6), // blue
  Color(0xFFA855F7), // purple
];

/// Ring/badge colour used to mark Pro-locked swatches (accent picker).
const Color kEvolveProLockColor = Color(0xFFEAB308);

/// Opens the custom-colour spectrum sheet (the "escape hatch" behind the
/// swatch grid). Returns the picked colour, or `null` if cancelled.
///
/// Signature mirrors the desktop `showEvolveColorPicker`.
Future<Color?> showEvolveColorPicker(
  BuildContext context,
  Color initial, {
  String? title,
}) {
  Color working = initial;
  return showEvolveFormSheet<Color>(
    context: context,
    title: title ?? context.t.settings.appearance.customColor,
    leading: EvolveTextAction(
      label: context.t.common.actions.cancel,
      onPressed: () => Navigator.pop(context),
    ),
    trailing: EvolveTextAction(
      label: context.t.common.actions.confirm,
      emphasized: true,
      onPressed: () => Navigator.pop(context, working),
    ),
    builder: (sheetContext) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Material(
          color: Colors.transparent,
          child: ColorPicker(
            pickerColor: working,
            onColorChanged: (color) => working = color,
            pickerAreaHeightPercent: 0.7,
            enableAlpha: false,
            displayThumbColor: true,
            labelTypes: const [],
          ),
        ),
      );
    },
  );
}

/// Apple-style swatch grid: solid colour circles with an accent checkmark on the
/// selected one, plus a trailing "Custom" cell that opens [showEvolveColorPicker]
/// for arbitrary colours (so no capability is lost vs. a spectrum picker).
///
/// [isLocked]/[onLockedTap] let a site gate cells behind Pro (the accent picker)
/// while keeping the same look everywhere else.
class EvolveColorSwatchGrid extends ConsumerWidget {
  const EvolveColorSwatchGrid({
    super.key,
    required this.selected,
    required this.onChanged,
    this.palette = kEvolveDefaultPalette,
    this.showCustom = true,
    this.isLocked,
    this.onLockedTap,
    this.onCustomTap,
    this.customLocked = false,
    this.lockRingColor = kEvolveProLockColor,
    this.customTitle,
  });

  final Color selected;
  final ValueChanged<Color> onChanged;
  final List<Color> palette;
  final bool showCustom;
  final bool Function(Color color)? isLocked;
  final ValueChanged<Color>? onLockedTap;

  /// Overrides the default custom-cell behaviour (which opens
  /// [showEvolveColorPicker]). The accent picker uses this for its own
  /// Pro-gated + validated flow.
  final VoidCallback? onCustomTap;

  /// Renders the custom cell as Pro-locked (lock badge + gold ring).
  final bool customLocked;
  final Color lockRingColor;
  final String? customTitle;

  static const double _swatch = 36;

  static bool _sameColor(Color a, Color b) => a.toARGB32() == b.toARGB32();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onPalette = palette.any((c) => _sameColor(c, selected));
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final color in palette)
          _SwatchCell(
            color: color,
            selected: _sameColor(color, selected),
            locked: isLocked?.call(color) ?? false,
            lockRingColor: lockRingColor,
            size: _swatch,
            onTap: () {
              if (isLocked?.call(color) ?? false) {
                onLockedTap?.call(color);
              } else {
                ref.hapticSelection();
                onChanged(color);
              }
            },
          ),
        if (showCustom)
          _CustomCell(
            size: _swatch,
            locked: customLocked,
            lockRingColor: lockRingColor,
            // When the current colour is off-palette we render it inside the
            // Custom cell so a previously-chosen custom colour is never lost.
            currentColor: onPalette ? null : selected,
            onTap: onCustomTap ??
                () async {
                  final picked = await showEvolveColorPicker(
                    context,
                    selected,
                    title: customTitle,
                  );
                  if (picked != null && context.mounted) {
                    ref.hapticSelection();
                    onChanged(picked);
                  }
                },
          ),
      ],
    );
  }
}

class _SwatchCell extends StatelessWidget {
  const _SwatchCell({
    required this.color,
    required this.selected,
    required this.locked,
    required this.lockRingColor,
    required this.size,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final bool locked;
  final Color lockRingColor;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Contrast against the swatch itself so the ring/check stay legible on
    // both pale (gold/cyan) and dark colours, in either theme.
    final bool isLight = color.computeLuminance() > 0.6;
    final Color contrast = isLight ? Colors.black : Colors.white;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: locked ? 0.45 : 1),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? contrast.withValues(alpha: isLight ? 0.35 : 0.95)
                : (locked
                      ? lockRingColor.withValues(alpha: 0.7)
                      : Colors.transparent),
            width: 2,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: locked
            ? Icon(
                CupertinoIcons.lock_fill,
                size: 14,
                color: contrast.withValues(alpha: 0.9),
              )
            : (selected
                  ? Icon(CupertinoIcons.check_mark, size: 16, color: contrast)
                  : null),
      ),
    );
  }
}

class _CustomCell extends StatelessWidget {
  const _CustomCell({
    required this.size,
    required this.currentColor,
    required this.onTap,
    this.locked = false,
    this.lockRingColor = kEvolveProLockColor,
  });

  final double size;
  final Color? currentColor;
  final VoidCallback onTap;
  final bool locked;
  final Color lockRingColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bool showColor = currentColor != null && !locked;
    final bool isLight = showColor && currentColor!.computeLuminance() > 0.6;
    final Color contrast = isLight ? Colors.black : Colors.white;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: showColor
              ? currentColor!
              : colors.muted.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: locked
                ? lockRingColor.withValues(alpha: 0.7)
                : (showColor
                      ? contrast.withValues(alpha: isLight ? 0.35 : 0.95)
                      : colors.border),
            width: 2,
          ),
        ),
        child: Icon(
          locked
              ? CupertinoIcons.lock_fill
              : (showColor ? CupertinoIcons.check_mark : CupertinoIcons.add),
          size: locked ? 14 : 16,
          color: locked
              ? lockRingColor
              : (showColor ? contrast : colors.mutedForeground),
        ),
      ),
    );
  }
}
