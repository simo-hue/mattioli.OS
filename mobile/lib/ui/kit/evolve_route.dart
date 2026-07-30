import 'package:flutter/material.dart';

/// How this app pushes a full-screen destination.
///
/// Exists so the iOS edge-swipe-back gesture is a property of the *helper*
/// rather than of a comment every screen has to remember to copy.
///
/// [MaterialPageRoute] is not an arbitrary pick. It resolves its transition
/// through the ambient [PageTransitionsTheme], which maps
/// `TargetPlatform.iOS` to [CupertinoPageTransitionsBuilder] — and that builder
/// is what installs Flutter's back-gesture detector along the leading screen
/// edge. A route that does not go through that builder (a raw
/// [PageRouteBuilder] with a hand-written `transitionsBuilder`, for instance)
/// silently has **no** swipe-back at all, because the gesture lives in the
/// transition, not in the route.
///
/// Two things follow from that, both of which used to be hand-rolled wrong:
///
///  * **RTL is free.** [CupertinoPageTransition] threads `Directionality` into
///    its `SlideTransition`, and the gesture detector is positioned with
///    `PositionedDirectional`. So in Arabic the page enters from the left and
///    the drag area sits on the right edge, with no per-screen work. A
///    hand-written `Tween(begin: Offset(1, 0))` cannot do this.
///  * **Android stays native.** The same theme maps `TargetPlatform.android` to
///    its own builder, so Android keeps the Material transition rather than
///    inheriting an iOS look.
///
/// Pass [fullscreenDialog] for a screen that should deliberately *not* be
/// swipe-dismissible — an iOS-style modal editor presented from the bottom.
/// That is the only legitimate reason to opt out, and making it a named flag
/// here keeps it from being a reason to reach for [PageRouteBuilder] again.
Route<T> evolveRoute<T>(
  WidgetBuilder builder, {
  bool fullscreenDialog = false,
}) {
  return MaterialPageRoute<T>(
    builder: builder,
    fullscreenDialog: fullscreenDialog,
  );
}
