import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the avatar downscale.
///
/// A picked avatar is encrypted here, and decrypted on every device that pulls
/// it, by synchronous pure-Dart AES-GCM on the UI isolate (~1.9 MB/s) — so a
/// multi-MB camera original freezes both this app and the paired iPhone.
/// image_picker's maxWidth/maxHeight/imageQuality cannot bound it: the macOS
/// implementation routes gallery picks to file_selector and silently ignores
/// all three. The bound has to come from this Dart-side re-encode.
Future<Uint8List> pngOfSize(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  // A gradient rather than a flat fill: a solid colour compresses to almost
  // nothing and would hide any size regression.
  final paint = ui.Paint()
    ..shader = ui.Gradient.linear(
      ui.Offset.zero,
      ui.Offset(width.toDouble(), height.toDouble()),
      const <ui.Color>[
        ui.Color(0xFFFF0000),
        ui.Color(0xFF00FF00),
        ui.Color(0xFF0000FF),
      ],
      const <double>[0.0, 0.5, 1.0],
    );
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    paint,
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<ui.Image> decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an oversized image is bounded to the 512px cap', () async {
    final original = await pngOfSize(3024, 4032); // iPhone camera original

    final resized = await downscaleAvatarBytes(original);

    expect(resized, isNot(same(original)));
    final image = await decode(resized);
    addTearDown(image.dispose);
    expect(image.height, kAvatarMaxDimension);
    // Aspect ratio preserved: 3024/4032 * 512 = 384.
    expect(image.width, 384);
  });

  test('a landscape image is capped on its longest edge', () async {
    final original = await pngOfSize(2000, 1000);

    final resized = await downscaleAvatarBytes(original);

    final image = await decode(resized);
    addTearDown(image.dispose);
    expect(image.width, kAvatarMaxDimension);
    expect(image.height, 256);
  });

  test('the re-encode collapses the payload the sync path has to encrypt', () async {
    final original = await pngOfSize(3024, 4032);

    final resized = await downscaleAvatarBytes(original);

    // The point of the fix: bytes that reach the synchronous AES-GCM encrypt.
    // The uncapped original is megabytes; anything near 512x512 is a fraction
    // of that. Asserted as a ratio so the bound holds regardless of encoder.
    expect(resized.length, lessThan(original.length ~/ 4));
  });

  test('an already-small image is passed through untouched', () async {
    final original = await pngOfSize(256, 256);

    final resized = await downscaleAvatarBytes(original);

    // Identity, not just equality: no needless re-encode, and _pickAvatar keys
    // the stored extension off exactly this.
    expect(identical(resized, original), isTrue);
  });

  test('an image exactly at the cap is passed through untouched', () async {
    final original = await pngOfSize(kAvatarMaxDimension, kAvatarMaxDimension);

    final resized = await downscaleAvatarBytes(original);

    expect(identical(resized, original), isTrue);
  });

  test('never returns a payload larger than the one it was given', () async {
    // PNG is lossless, so a naive re-encode can inflate an already-compressed
    // source. Since it is bytes, not pixels, that stall the AES-GCM encrypt,
    // the downscale must never make the payload worse — at any input size.
    for (final dims in const <List<int>>[
      [3024, 4032],
      [1200, 1200],
      [600, 400],
      [513, 513],
      [64, 64],
    ]) {
      final original = await pngOfSize(dims[0], dims[1]);
      final resized = await downscaleAvatarBytes(original);
      expect(
        resized.length,
        lessThanOrEqualTo(original.length),
        reason: 'inflated a ${dims[0]}x${dims[1]} source',
      );
    }
  });

  test('undecodable bytes fall back to the original rather than throwing', () async {
    final garbage = Uint8List.fromList(List<int>.filled(64, 7));

    final resized = await downscaleAvatarBytes(garbage);

    // The downscale is an optimisation, never a gate on setting an avatar.
    expect(identical(resized, garbage), isTrue);
  });
}
