import 'package:flutter/material.dart';

Future<T?> showPopover<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Alignment targetAlignment = Alignment.bottomCenter,
  Alignment popoverAlignment = Alignment.topCenter,
  Offset offset = Offset.zero,
}) {
  final renderBox = context.findRenderObject() as RenderBox;
  final targetRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;

  return Navigator.of(context).push(
    _PopoverRoute<T>(
      targetRect: targetRect,
      builder: builder,
      targetAlignment: targetAlignment,
      popoverAlignment: popoverAlignment,
      offset: offset,
    ),
  );
}

class _PopoverRoute<T> extends PopupRoute<T> {
  _PopoverRoute({
    required this.targetRect,
    required this.builder,
    this.targetAlignment = Alignment.bottomCenter,
    this.popoverAlignment = Alignment.topCenter,
    this.offset = Offset.zero,
  });

  final Rect targetRect;
  final WidgetBuilder builder;
  final Alignment targetAlignment;
  final Alignment popoverAlignment;
  final Offset offset;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Close Popover';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _PopoverLayout(
      targetRect: targetRect,
      targetAlignment: targetAlignment,
      popoverAlignment: popoverAlignment,
      offset: offset,
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          alignment: popoverAlignment.resolve(Directionality.of(context)),
          child: builder(context),
        ),
      ),
    );
  }
}

class _PopoverLayout extends StatelessWidget {
  const _PopoverLayout({
    required this.targetRect,
    required this.targetAlignment,
    required this.popoverAlignment,
    required this.child,
    this.offset = Offset.zero,
  });

  final Rect targetRect;
  final Alignment targetAlignment;
  final Alignment popoverAlignment;
  final Widget child;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return CustomSingleChildLayout(
      delegate: _PopoverLayoutDelegate(
        targetRect: targetRect,
        targetAlignment: targetAlignment,
        popoverAlignment: popoverAlignment,
        offset: offset,
      ),
      child: child,
    );
  }
}

class _PopoverLayoutDelegate extends SingleChildLayoutDelegate {
  _PopoverLayoutDelegate({
    required this.targetRect,
    required this.targetAlignment,
    required this.popoverAlignment,
    required this.offset,
  });

  final Rect targetRect;
  final Alignment targetAlignment;
  final Alignment popoverAlignment;
  final Offset offset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Calculate the anchor point on the target rect based on alignment
    final targetPoint = targetAlignment.alongSize(targetRect.size) +
        targetRect.topLeft +
        offset;

    // Calculate the corresponding anchor point on the popover based on alignment
    final popoverAnchor = popoverAlignment.alongSize(childSize);

    // Position the popover so its anchor matches the target anchor
    var position = targetPoint - popoverAnchor;

    // Keep within screen bounds (with a 16px margin)
    const margin = 16.0;
    if (position.dx < margin) position = Offset(margin, position.dy);
    if (position.dx + childSize.width > size.width - margin) {
      position = Offset(size.width - childSize.width - margin, position.dy);
    }
    if (position.dy < margin) position = Offset(position.dx, margin);
    if (position.dy + childSize.height > size.height - margin) {
      position = Offset(position.dx, size.height - childSize.height - margin);
    }

    return position;
  }

  @override
  bool shouldRelayout(covariant _PopoverLayoutDelegate oldDelegate) {
    return targetRect != oldDelegate.targetRect ||
        targetAlignment != oldDelegate.targetAlignment ||
        popoverAlignment != oldDelegate.popoverAlignment ||
        offset != oldDelegate.offset;
  }
}
