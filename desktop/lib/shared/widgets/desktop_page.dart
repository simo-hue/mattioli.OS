import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:flutter/material.dart';

class DesktopPage extends StatelessWidget {
  const DesktopPage({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 34),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
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
              : context.evolveColors.panelRaised,
          foregroundColor: primary
              ? Theme.of(context).colorScheme.onPrimary
              : context.evolveColors.foreground,
          side: BorderSide(
            color: primary
                ? context.evolveAccent
                : context.evolveColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
      ),
    );
  }
}
