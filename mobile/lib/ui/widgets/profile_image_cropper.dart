import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_image/crop_image.dart';

class ProfileImageCropper extends StatefulWidget {
  final ImageProvider image;
  
  const ProfileImageCropper({super.key, required this.image});

  @override
  State<ProfileImageCropper> createState() => _ProfileImageCropperState();
}

class _ProfileImageCropperState extends State<ProfileImageCropper> {
  final controller = CropController(
    aspectRatio: 1.0, // 1:1 aspect ratio
    defaultCrop: const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95),
  );

  bool _isProcessing = false;

  Future<void> _cropImage() async {
    setState(() {
      _isProcessing = true;
    });
    try {
      final ui.Image bitmap = await controller.croppedBitmap();
      final ByteData? data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? bytes = data?.buffer.asUint8List();
      if (mounted) {
        Navigator.of(context).pop(bytes);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Crop Image',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_isProcessing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _cropImage,
              child: const Text(
                'Done',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: CropImage(
            image: Image(image: widget.image),
            controller: controller,
          ),
        ),
      ),
    );
  }
}
