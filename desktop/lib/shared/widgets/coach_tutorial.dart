import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:flutter/material.dart';

/// One step of a coach-mark tour: an optional [targetKey] to spotlight plus the
/// copy shown in the step card.
class CoachStep {
  const CoachStep({
    this.targetKey,
    required this.title,
    required this.description,
  });

  final GlobalKey? targetKey;
  final String title;
  final String description;
}

/// A reusable coach-mark overlay (dimming scrim + spotlight cut-out + step card)
/// that mirrors the goals onboarding tour. The host owns the [steps], the
/// current [index], and the target [GlobalKey]s; this widget renders one step,
/// recomputes the spotlight geometry after layout/resize, and drives the
/// Back / Next / Finish buttons.
///
/// Place it as the last child of a [Stack] over the page content so the target
/// keys resolve in the same coordinate space.
class CoachTutorialOverlay extends StatefulWidget {
  const CoachTutorialOverlay({
    required this.steps,
    required this.index,
    required this.onIndexChanged,
    required this.onFinish,
    required this.backLabel,
    required this.nextLabel,
    required this.finishLabel,
    super.key,
  });

  final List<CoachStep> steps;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onFinish;
  final String backLabel;
  final String nextLabel;
  final String finishLabel;

  @override
  State<CoachTutorialOverlay> createState() => _CoachTutorialOverlayState();
}

class _CoachTutorialOverlayState extends State<CoachTutorialOverlay> {
  final GlobalKey _overlayKey = GlobalKey();
  bool _isRefreshing = false;

  // Geometry-refresh attempts for the current step. Bounded so a target that
  // never lays out (unmounted / zero-size) can't pin a CPU with a per-frame
  // setState loop; after the cap we fall back to a target-less (full-scrim)
  // step. Reset whenever the step changes or its rect resolves.
  int _refreshAttempts = 0;
  static const _maxRefreshAttempts = 12;

  // The step index whose target we've already scrolled into view (once each).
  int _ensuredIndex = -1;

  @override
  void didUpdateWidget(covariant CoachTutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _refreshAttempts = 0;
  }

  /// Brings an off-screen target into view (once per step) so its spotlight
  /// cut-out lands inside the viewport instead of drawing a full opaque scrim.
  void _ensureTargetVisible(int index, GlobalKey? targetKey) {
    if (_ensuredIndex == index) return;
    final targetContext = targetKey?.currentContext;
    if (targetContext == null) return; // not mounted yet — retry next build
    _ensuredIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // No-op when the target has no Scrollable ancestor.
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      if (mounted) setState(() {});
    });
  }

  Rect? _targetRect(GlobalKey? targetKey) {
    final overlayContext = _overlayKey.currentContext;
    final targetContext = targetKey?.currentContext;
    if (overlayContext == null || targetContext == null) return null;

    final overlayObject = overlayContext.findRenderObject();
    final targetObject = targetContext.findRenderObject();
    if (overlayObject is! RenderBox ||
        targetObject is! RenderBox ||
        !overlayObject.attached ||
        !targetObject.attached ||
        !targetObject.hasSize) {
      return null;
    }

    final targetSize = targetObject.size;
    if (targetSize.width <= 1 || targetSize.height <= 1) return null;

    final targetOffset = targetObject.localToGlobal(
      Offset.zero,
      ancestor: overlayObject,
    );
    return targetOffset & targetSize;
  }

  void _scheduleGeometryRefresh() {
    if (_isRefreshing || _refreshAttempts >= _maxRefreshAttempts) return;
    _isRefreshing = true;
    _refreshAttempts++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isRefreshing = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    if (steps.isEmpty) return const SizedBox.shrink();
    final index = widget.index.clamp(0, steps.length - 1).toInt();
    final step = steps[index];
    _ensureTargetVisible(index, step.targetKey);
    final targetRect = _targetRect(step.targetKey);

    if (step.targetKey != null && targetRect == null) {
      _scheduleGeometryRefresh();
    } else {
      _refreshAttempts = 0; // resolved (or no target) — stop retrying
    }

    return Positioned.fill(
      child: Material(
        key: _overlayKey,
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final overlaySize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final showCardAtTop =
                targetRect != null &&
                targetRect.center.dy > overlaySize.height * 0.52;

            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _CoachScrimPainter(targetRect)),
                ),
                if (targetRect != null)
                  Positioned.fromRect(
                    rect: targetRect.inflate(8),
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.evolveAccent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                Align(
                  alignment: showCardAtTop
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 40,
                    ),
                    child: _CoachCard(
                      title: step.title,
                      description: step.description,
                      isFirst: index == 0,
                      isLast: index == steps.length - 1,
                      backLabel: widget.backLabel,
                      nextLabel: widget.nextLabel,
                      finishLabel: widget.finishLabel,
                      onBack: () => widget.onIndexChanged(index - 1),
                      onNext: () {
                        if (index == steps.length - 1) {
                          widget.onFinish();
                        } else {
                          widget.onIndexChanged(index + 1);
                        }
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.title,
    required this.description,
    required this.isFirst,
    required this.isLast,
    required this.backLabel,
    required this.nextLabel,
    required this.finishLabel,
    required this.onBack,
    required this.onNext,
  });

  final String title;
  final String description;
  final bool isFirst;
  final bool isLast;
  final String backLabel;
  final String nextLabel;
  final String finishLabel;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.panelRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: colors.muted,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isFirst)
                    TextButton(onPressed: onBack, child: Text(backLabel))
                  else
                    const SizedBox.shrink(),
                  FilledButton(
                    onPressed: onNext,
                    child: Text(isLast ? finishLabel : nextLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachScrimPainter extends CustomPainter {
  const _CoachScrimPainter(this.targetRect);

  final Rect? targetRect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayBounds = Offset.zero & size;
    final scrimPaint = Paint()..color = Colors.black.withValues(alpha: 0.82);
    final target = targetRect;

    if (target == null) {
      canvas.drawRect(overlayBounds, scrimPaint);
      return;
    }

    final highlightedRect = target.inflate(10).intersect(overlayBounds);
    if (highlightedRect.isEmpty) {
      canvas.drawRect(overlayBounds, scrimPaint);
      return;
    }

    final overlayPath = Path()..addRect(overlayBounds);
    final highlightPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(highlightedRect, const Radius.circular(16)),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, overlayPath, highlightPath),
      scrimPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CoachScrimPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
