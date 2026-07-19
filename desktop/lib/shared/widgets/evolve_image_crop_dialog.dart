import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:crop_image/crop_image.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';

class EvolveImageCropDialog extends StatefulWidget {
  const EvolveImageCropDialog({
    super.key,
    required this.image,
  });

  final ImageProvider image;

  @override
  State<EvolveImageCropDialog> createState() => _EvolveImageCropDialogState();
}

class _EvolveImageCropDialogState extends State<EvolveImageCropDialog> {
  final controller = CropController(
    aspectRatio: 1.0,
    defaultCrop: const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95),
  );
  
  bool _isProcessing = false;

  Future<void> _cropImage() async {
    setState(() => _isProcessing = true);
    try {
      final ui.Image bitmap = await controller.croppedBitmap();
      final ByteData? data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? bytes = data?.buffer.asUint8List();
      if (mounted) {
        Navigator.of(context).pop(bytes);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EvolveAlertDialog(
      maxWidth: 600,
      title: Text(t.settingsPage.updateAvatar),
      content: SizedBox(
        height: 400,
        width: 500,
        child: CropImage(
          image: Image(image: widget.image),
          controller: controller,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: Text(t.settingsPage.cancel),
        ),
        FilledButton(
          onPressed: _isProcessing ? null : _cropImage,
          child: _isProcessing 
              ? const SizedBox(
                  width: 16, height: 16, 
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crop'),
        ),
      ],
    );
  }
}
