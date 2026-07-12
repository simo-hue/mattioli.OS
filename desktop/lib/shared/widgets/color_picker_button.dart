import 'package:evolve_desktop/shared/widgets/evolve_color_picker.dart';
import 'package:evolve_desktop/shared/widgets/popover.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _customSwatchGradient = SweepGradient(
  colors: [
    Color(0xFFEF4444),
    Color(0xFFEAB308),
    Color(0xFF22C55E),
    Color(0xFF06B6D4),
    Color(0xFF3B82F6),
    Color(0xFFA855F7),
    Color(0xFFEF4444),
  ],
);

class ColorPickerButton extends StatelessWidget {
  const ColorPickerButton({
    required this.color,
    required this.onColorChanged,
    required this.presetColors,
    this.size = 28,
    super.key,
  });

  final Color color;
  final ValueChanged<Color> onColorChanged;
  final List<Color> presetColors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final preset in presetColors)
          GestureDetector(
            onTap: () => onColorChanged(preset),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: preset,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color == preset
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: color == preset
                      ? [
                          BoxShadow(
                            color: preset.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        _CustomColorSwatch(
          isSelected: !presetColors.contains(color),
          initial: color,
          size: size,
          onOpenPicker: (context) {
            showPopover(
              context: context,
              targetAlignment: Alignment.bottomCenter,
              popoverAlignment: Alignment.topCenter,
              offset: const Offset(0, 8),
              builder: (context) {
                return EvolveColorPickerContent(
                  initialColor: color,
                  onColorChanged: onColorChanged,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _CustomColorSwatch extends StatelessWidget {
  const _CustomColorSwatch({
    required this.isSelected,
    required this.onOpenPicker,
    required this.initial,
    required this.size,
  });

  final bool isSelected;
  final Color initial;
  final void Function(BuildContext) onOpenPicker;
  final double size;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onOpenPicker(context),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: _customSwatchGradient,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: initial.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Icon(LucideIcons.plus, size: size * 0.5, color: Colors.white),
        ),
      ),
    );
  }
}
