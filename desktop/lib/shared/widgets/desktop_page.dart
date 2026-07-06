import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:flutter/material.dart';

/// Fluid page scaffold. No max-width cap: content stretches edge to edge
/// inside fixed 28px gutters, and width is absorbed by adaptive grids inside
/// the pages (see LAYOUT_SPEC): charts/tables/calendars grow, tap targets
/// don't.
///
/// Two modes:
/// - default: the page scrolls as a document (dashboards).
/// - [pinned]: the page fills the viewport exactly with no page scroll;
///   [child] receives the remaining height and hosts its own internal
///   scrollables (workspace surfaces: habits, AI coach).
class DesktopPage extends StatelessWidget {
  const DesktopPage({
    required this.child,
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    this.pinned = false,
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final bool pinned;

  Widget _header(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title!, style: Theme.of(context).textTheme.displaySmall),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.evolveColors.muted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (pinned) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              _header(context),
              const SizedBox(height: 20),
            ],
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scrollbar(
      child: SingleChildScrollView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              _header(context),
              const SizedBox(height: 24),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class PageActionButton extends StatelessWidget {
  const PageActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: primary
              ? context.evolveAccent
              : context.evolveColors.panel.withValues(alpha: 0.4),
          foregroundColor: primary
              ? Theme.of(context).colorScheme.onPrimary
              : context.evolveColors.foreground,
          side: BorderSide(
            color: primary
                ? context.evolveAccent
                : context.evolveColors.border.withValues(alpha: 0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }
}
