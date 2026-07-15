import 'package:flutter/material.dart';

/// Global navigator key so startup-level error handlers (which run outside any
/// widget's `BuildContext`) can surface UI via the app's navigator. Mirrors
/// mobile's `core/navigator_key.dart`.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
