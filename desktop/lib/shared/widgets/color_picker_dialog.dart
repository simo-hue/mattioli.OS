import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The rainbow ring shown on the "custom color" swatch.
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

/// Opens a full color picker dialog, returning the chosen color (or null on
/// cancel). Reused by the create-habit / create-goal / category-editor dialogs.
Future<Color?> showEvolveColorPicker(BuildContext context, Color initial) {
  var color = initial;
  return showEvolveDialog<Color>(
    context: context,
    builder: (context) => EvolveAlertDialog(
      icon: LucideIcons.palette,
      title: Text(t.form.color),
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: color,
          onColorChanged: (value) => color = value,
          enableAlpha: false,
          labelTypes: const [],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.common.actions.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, color),
          child: Text(t.common.actions.save),
        ),
      ],
    ),
  );
}

/// A swatch that opens the full color picker. Highlighted when the current
/// selection is a custom color (i.e. not one of the presets).
class CustomColorSwatch extends StatelessWidget {
  const CustomColorSwatch({
    required this.isSelected,
    required this.onPicked,
    required this.initial,
    this.size = 28,
    super.key,
  });

  final bool isSelected;
  final Color initial;
  final ValueChanged<Color> onPicked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final picked = await showEvolveColorPicker(context, initial);
          if (picked != null) onPicked(picked);
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: _customSwatchGradient,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
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
