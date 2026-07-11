import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';

/// Apple-style ("Evolve") sheet + grouped-inset list kit.
///
/// Shared primitives used by the Select-Habit, Choose-category and colour
/// surfaces so they all read as one iOS-native design language. Built on
/// Material scaffolding (no stock Cupertino widgets) and the existing
/// `context.appColors` theme — cross-platform, no `Platform.isIOS` gating.
///
/// Naming mirrors the desktop kit (`desktop/lib/shared/widgets`).

const double _kSheetRadius = 24;
const double _kTileSize = 30;
const double _kTileRadius = 8;

/// Drag handle shown at the top of every Evolve sheet.
class EvolveGrabber extends StatelessWidget {
  const EvolveGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 5,
      margin: const EdgeInsets.only(top: 8, bottom: 6),
      decoration: BoxDecoration(
        color: context.appColors.border,
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }
}

/// Centered bold sheet title for selection sheets (no action buttons).
class EvolveSheetTitle extends StatelessWidget {
  const EvolveSheetTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: context.appColors.foreground,
        ),
      ),
    );
  }
}

/// Nav-style header (Cancel / title / Done) for editor & colour sheets.
class EvolveSheetNavHeader extends StatelessWidget {
  const EvolveSheetNavHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.appColors.foreground,
              ),
            ),
          ),
          if (leading != null)
            Align(alignment: Alignment.centerLeft, child: leading),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
  }
}

/// Text action button for a sheet header (Cancel = muted, Done = accent).
class EvolveTextAction extends StatelessWidget {
  const EvolveTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      onPressed: onPressed,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
          color: emphasized
              ? Theme.of(context).colorScheme.primary
              : colors.mutedForeground,
        ),
      ),
    );
  }
}

/// Presents a draggable selection sheet: grabber + centered [title] + a
/// scrollable body whose children come from [itemsBuilder].
Future<T?> showEvolveSheet<T>({
  required BuildContext context,
  required String title,
  required List<Widget> Function(BuildContext context) itemsBuilder,
  double initialChildSize = 0.6,
  double minChildSize = 0.4,
  double maxChildSize = 0.92,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: false,
        builder: (context, scrollController) {
          final colors = context.appColors;
          return Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_kSheetRadius),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EvolveGrabber(),
                EvolveSheetTitle(title),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: itemsBuilder(context),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Presents a keyboard-aware form/editor sheet with a Cancel/title/Done header.
Future<T?> showEvolveFormSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  Widget? leading,
  Widget? trailing,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final colors = sheetContext.appColors;
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(_kSheetRadius),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EvolveGrabber(),
                EvolveSheetNavHeader(
                  title: title,
                  leading: leading,
                  trailing: trailing,
                ),
                Flexible(child: builder(sheetContext)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Grouped-inset container: rounded card with hairline separators between rows.
class EvolveListSection extends StatelessWidget {
  const EvolveListSection({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Container(height: 0.5, color: colors.border),
          ),
        );
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: colors.cardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// Leading rounded-square icon tile (SF-symbol-style).
class EvolveIconTile extends StatelessWidget {
  const EvolveIconTile({super.key, required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kTileSize,
      height: _kTileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(_kTileRadius),
      ),
      child: Icon(icon, size: 16, color: tint),
    );
  }
}

/// Leading rounded-square tile containing a colour dot (habit/goal rows).
class EvolveColorDotTile extends StatelessWidget {
  const EvolveColorDotTile({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kTileSize,
      height: _kTileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(_kTileRadius),
      ),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// A single grouped-inset row. A [ConsumerWidget] so it fires *gated* selection
/// haptics on tap without the caller wiring a `ref`.
///
/// Trailing precedence: explicit [trailing] > accent checkmark when [selected]
/// > chevron when [showChevron] > nothing.
class EvolveListRow extends ConsumerWidget {
  const EvolveListRow({
    super.key,
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.selected = false,
    this.showChevron = false,
    this.titleColor,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool selected;
  final bool showChevron;
  final Color? titleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final accent = Theme.of(context).colorScheme.primary;

    Widget? resolvedTrailing = trailing;
    if (resolvedTrailing == null && selected) {
      resolvedTrailing = Icon(CupertinoIcons.check_mark, size: 20, color: accent);
    } else if (resolvedTrailing == null && showChevron) {
      resolvedTrailing = Icon(
        CupertinoIcons.chevron_right,
        size: 16,
        color: colors.mutedForeground,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.hapticSelection();
          onTap();
        },
        splashColor: Colors.transparent,
        highlightColor: colors.border.withValues(alpha: 0.4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: titleColor ?? colors.foreground,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (resolvedTrailing != null) ...[
                const SizedBox(width: 8),
                resolvedTrailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
