import 'package:flutter/cupertino.dart';

/// macOS-style activity indicator. Replaces Material `CircularProgressIndicator`
/// so indeterminate loading states read native on macOS. Pass [color] to tint
/// it (e.g. an on-accent button spinner); omit for the platform default. Use a
/// [radius] to size it (roughly half the old `SizedBox.square` dimension).
class EvolveSpinner extends StatelessWidget {
  const EvolveSpinner({super.key, this.color, this.radius = 12});

  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CupertinoActivityIndicator(color: color, radius: radius);
  }
}
