import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:flutter/material.dart';

class EvolvePanel extends StatelessWidget {
  const EvolvePanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.radius = 16,
    this.glowColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  /// Optional accent tint painted as a faint radial glow in the top-end
  /// corner, matching the mobile action tiles.
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? context.evolveColors.panel.withValues(alpha: 0.4),
        border: Border.all(
          color: context.evolveColors.border.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // A transparent Material sits in front of the panel fill so any
      // ListTile-family children (ListTile, Checkbox/Switch/RadioListTile)
      // paint their ink splashes and selected backgrounds on a visible
      // surface instead of behind the DecoratedBox color.
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (glowColor != null)
              PositionedDirectional(
                top: -20,
                end: -20,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        glowColor!.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Tiny uppercase letter-spaced label that introduces a section, with the
/// mobile app's fading hairline running to the trailing edge
/// ("PROTOCOLLO ————").
class EvolveSectionLabel extends StatelessWidget {
  const EvolveSectionLabel(this.label, {super.key, this.withRule = true});

  final String label;
  final bool withRule;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.evolveColors.muted.withValues(alpha: 0.8),
        letterSpacing: -0.1,
      ),
    );
    if (!withRule) return text;
    return Row(
      children: [
        text,
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.evolveColors.border.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small tinted rounded-square icon container used as the leading element of
/// cards and rows (mobile's icon chip).
class EvolveIconChip extends StatelessWidget {
  const EvolveIconChip({
    required this.icon,
    required this.color,
    super.key,
    this.size = 34,
    this.iconSize = 17,
    this.outlined = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  /// Outlined variant used by settings rows: card fill + border, icon in
  /// [color] instead of a tinted fill.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: outlined
          ? BoxDecoration(
              color: context.evolveColors.panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.evolveColors.border),
            )
          : BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

/// The mobile app's signature segmented control: translucent track with a
/// white (accent) pill on the active segment and black-on-white label.
class EvolveSegmentedControl<T> extends StatelessWidget {
  const EvolveSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onSelected,
    super.key,
    this.height = 40,
  });

  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final accent = context.evolveAccent;
    final onAccent = Theme.of(context).colorScheme.onPrimary;
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.evolveColors.panel.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.evolveColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          for (final entry in segments.entries)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (entry.key != selected) onSelected(entry.key);
                },
                behavior: HitTestBehavior.opaque,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: entry.key == selected
                          ? accent
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: entry.key == selected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: entry.key == selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        letterSpacing: -0.2,
                        color: entry.key == selected
                            ? onAccent
                            : context.evolveColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 36x36 bordered square button (calendar chevrons, small icon actions).
class EvolveSquareIconButton extends StatelessWidget {
  const EvolveSquareIconButton({
    required this.icon,
    required this.onTap,
    super.key,
    this.tooltip,
    this.size = 36,
    this.iconSize = 18,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: context.evolveColors.panel,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.evolveColors.border),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: onTap == null
                ? context.evolveColors.subtle
                : context.evolveColors.foreground,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.evolveAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: effectiveColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
