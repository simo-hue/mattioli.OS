import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:flutter/material.dart';

/// The pane heading, derived from the destination itself.
///
/// It used to take a free-text title and subtitle, and four of the six panes
/// then disagreed with the rail entry that opened them ("Application" opened
/// "Appearance and application"). Taking the [SettingsSection] makes one string
/// the name of the destination in both places, by construction.
class SettingsHeading extends StatelessWidget {
  const SettingsHeading({super.key, required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.label, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text(section.purpose, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

/// The pane body: one column of group cards.
///
/// It replaces `_GroupGrid`, which above a 1280px breakpoint packed the cards
/// into two columns greedily by `children.length`. Three things were wrong with
/// that and only the first was cosmetic. Reading order broke — the Application
/// pane's groups of 1, 6 and 4 rows rendered as left = 1, 3 and right = 2, so
/// the eye met them out of order. Row COUNT is not height, so a 56px switch and
/// a ~90px colour row balanced as equals. And the breakpoint measured
/// `constraints.maxWidth` of the whole panel, rail included, so the cards
/// actually split at ~1030px of usable content width rather than the 1280 the
/// code named. macOS Settings puts one column in a pane; so do we.
class SettingsColumn extends StatelessWidget {
  const SettingsColumn({super.key, required this.groups});

  final List<Widget> groups;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 18),
          groups[i],
        ],
      ],
    );
  }
}
