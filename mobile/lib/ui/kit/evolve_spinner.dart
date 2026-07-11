import 'package:flutter/cupertino.dart';

/// iOS activity indicator. Replaces Material `CircularProgressIndicator` so
/// loading states read native on iOS. Pass [color] to tint it (e.g. the amber
/// paywall spinner); omit for the theme default.
class EvolveSpinner extends StatelessWidget {
  const EvolveSpinner({super.key, this.color, this.radius = 12});

  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CupertinoActivityIndicator(color: color, radius: radius);
  }
}
