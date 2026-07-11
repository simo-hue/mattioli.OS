import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';

/// Semantic kinds for [showEvolveToast] (drives the leading icon + tint).
enum EvolveToastKind { neutral, success, error }

/// Shows a transient, self-dismissing iOS-style banner.
///
/// iOS has no native "toast"; apps use a floating capsule that fades in near the
/// bottom. This replaces Material `SnackBar` feedback. Inserted into the root
/// overlay so it also floats above any open sheet.
void showEvolveToast(
  BuildContext context, {
  required String message,
  IconData? icon,
  EvolveToastKind kind = EvolveToastKind.neutral,
  Duration duration = const Duration(seconds: 2),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late OverlayEntry entry;
  var removed = false;
  entry = OverlayEntry(
    builder: (_) => _EvolveToast(
      message: message,
      icon: icon,
      kind: kind,
      duration: duration,
      // The toast can end either by its own dwell finishing or by the route
      // tree being torn down early. Guard so the entry is removed exactly once
      // and never on an already-removed entry.
      onDismissed: () {
        if (removed) return;
        removed = true;
        entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _EvolveToast extends StatefulWidget {
  const _EvolveToast({
    required this.message,
    required this.icon,
    required this.kind,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final IconData? icon;
  final EvolveToastKind kind;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_EvolveToast> createState() => _EvolveToastState();
}

class _EvolveToastState extends State<_EvolveToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _show();
  }

  Future<void> _show() async {
    await _controller.forward();
    if (!mounted) return;
    // A cancellable Timer (cancelled in dispose) rather than Future.delayed, so
    // tearing the widget tree down mid-toast never leaves a pending timer whose
    // inherited dependents (Theme/MediaQuery) outlive the route tree.
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Color tint = colors.foreground;
    IconData? resolvedIcon = widget.icon;
    switch (widget.kind) {
      case EvolveToastKind.success:
        tint = colors.success;
        resolvedIcon ??= CupertinoIcons.check_mark_circled_solid;
        break;
      case EvolveToastKind.error:
        tint = colors.destructive;
        resolvedIcon ??= CupertinoIcons.exclamationmark_circle_fill;
        break;
      case EvolveToastKind.neutral:
        break;
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.of(context).padding.bottom + 24,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.cardElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (resolvedIcon != null) ...[
                      Icon(resolvedIcon, size: 18, color: tint),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        widget.message,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
