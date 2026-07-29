import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_search.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The filter field at the top of the Settings sidebar.
class EvolveSearchField extends StatelessWidget {
  const EvolveSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.focusNode,
    this.clearTooltip,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final String? clearTooltip;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return Container(
          height: 30,
          padding: const EdgeInsetsDirectional.only(start: 9, end: 4),
          decoration: BoxDecoration(
            color: colors.panel.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.search,
                size: 13,
                color: colors.muted.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: TextField(
                  key: const Key('settings.searchField'),
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: colors.foreground,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: colors.muted.withValues(alpha: 0.7),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (value.text.isNotEmpty)
                Tooltip(
                  message: clearTooltip ?? '',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(LucideIcons.x, size: 13, color: colors.muted),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One hit in the sidebar result list.
///
/// It names the pane the setting lives in as well as the setting itself —
/// without that, the list answers "where is it?" with a row that looks
/// identical to the one already on screen, and the user learns nothing about
/// where to find it next time.
class SettingsSearchResult extends StatelessWidget {
  const SettingsSearchResult({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final SettingsSearchEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          hoverColor: colors.panel.withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    entry.section.icon,
                    size: 13,
                    color: colors.muted.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.label(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        entry.section.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: colors.muted.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
