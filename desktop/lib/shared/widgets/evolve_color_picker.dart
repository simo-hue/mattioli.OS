import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class EvolveColorPickerContent extends StatefulWidget {
  const EvolveColorPickerContent({
    required this.initialColor,
    required this.onColorChanged,
    super.key,
  });

  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  @override
  State<EvolveColorPickerContent> createState() => _EvolveColorPickerContentState();
}

class _EvolveColorPickerContentState extends State<EvolveColorPickerContent> {
  late Color _currentColor;
  bool _isHexMode = true;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
  }

  void _handleColorChange(Color color) {
    setState(() => _currentColor = color);
    widget.onColorChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColorPicker(
              pickerColor: _currentColor,
              onColorChanged: _handleColorChange,
              enableAlpha: false,
              displayThumbColor: true,
              labelTypes: const [], 
              pickerAreaHeightPercent: 0.6,
              colorPickerWidth: 248,
              hexInputBar: false,
              portraitOnly: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _isHexMode = !_isHexMode),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isHexMode ? 'HEX' : 'RGB',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.swap_vert,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _isHexMode
                      ? _HexColorInput(
                          color: _currentColor,
                          onColorChanged: _handleColorChange,
                        )
                      : _RgbColorInput(
                          color: _currentColor,
                          onColorChanged: _handleColorChange,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  t.common.actions.pick,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _HexColorInput extends StatefulWidget {
  const _HexColorInput({
    required this.color,
    required this.onColorChanged,
  });

  final Color color;
  final ValueChanged<Color> onColorChanged;

  @override
  State<_HexColorInput> createState() => _HexColorInputState();
}

class _HexColorInputState extends State<_HexColorInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _colorToHex(widget.color));
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _updateColorFromText(_controller.text);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _HexColorInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color && !_focusNode.hasFocus) {
      _controller.text = _colorToHex(widget.color);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
  }

  void _updateColorFromText(String text) {
    final hex = text.replaceAll('#', '');
    if (hex.length == 6) {
      final val = int.tryParse('FF$hex', radix: 16);
      if (val != null) {
        widget.onColorChanged(Color(val));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
          ),
        ),
        style: const TextStyle(fontSize: 13),
        inputFormatters: [
          LengthLimitingTextInputFormatter(6),
          FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
        ],
        onSubmitted: _updateColorFromText,
      ),
    );
  }
}

class _RgbColorInput extends StatefulWidget {
  const _RgbColorInput({
    required this.color,
    required this.onColorChanged,
  });

  final Color color;
  final ValueChanged<Color> onColorChanged;

  @override
  State<_RgbColorInput> createState() => _RgbColorInputState();
}

class _RgbColorInputState extends State<_RgbColorInput> {
  late TextEditingController _rController;
  late TextEditingController _gController;
  late TextEditingController _bController;
  late FocusNode _rFocus;
  late FocusNode _gFocus;
  late FocusNode _bFocus;

  @override
  void initState() {
    super.initState();
    _rController = TextEditingController(text: widget.color.r.toInt().toString());
    _gController = TextEditingController(text: widget.color.g.toInt().toString());
    _bController = TextEditingController(text: widget.color.b.toInt().toString());

    _rFocus = FocusNode()..addListener(_onFocusChange);
    _gFocus = FocusNode()..addListener(_onFocusChange);
    _bFocus = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_rFocus.hasFocus && !_gFocus.hasFocus && !_bFocus.hasFocus) {
      _updateColor();
    }
  }

  @override
  void didUpdateWidget(covariant _RgbColorInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color && 
        !_rFocus.hasFocus && !_gFocus.hasFocus && !_bFocus.hasFocus) {
      _rController.text = widget.color.r.toInt().toString();
      _gController.text = widget.color.g.toInt().toString();
      _bController.text = widget.color.b.toInt().toString();
    }
  }

  @override
  void dispose() {
    _rController.dispose();
    _gController.dispose();
    _bController.dispose();
    _rFocus.dispose();
    _gFocus.dispose();
    _bFocus.dispose();
    super.dispose();
  }

  void _updateColor([String? _]) {
    final r = int.tryParse(_rController.text) ?? 0;
    final g = int.tryParse(_gController.text) ?? 0;
    final b = int.tryParse(_bController.text) ?? 0;
    
    final validR = r.clamp(0, 255);
    final validG = g.clamp(0, 255);
    final validB = b.clamp(0, 255);

    widget.onColorChanged(Color.fromARGB(255, validR, validG, validB));
  }

  Widget _buildField(TextEditingController controller, FocusNode focusNode) {
    return Expanded(
      child: SizedBox(
        height: 32,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          style: const TextStyle(fontSize: 13),
          keyboardType: TextInputType.number,
          inputFormatters: [
            LengthLimitingTextInputFormatter(3),
            FilteringTextInputFormatter.digitsOnly,
          ],
          onSubmitted: _updateColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildField(_rController, _rFocus),
        const SizedBox(width: 4),
        _buildField(_gController, _gFocus),
        const SizedBox(width: 4),
        _buildField(_bController, _bFocus),
      ],
    );
  }
}
