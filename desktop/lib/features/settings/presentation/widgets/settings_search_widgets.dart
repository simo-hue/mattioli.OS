import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_search.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/shared/widgets/evolve_search_chrome.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The filter field at the top of the Settings sidebar.
///
/// It wears [EvolveSearchChrome], the same pill as the shell's ⌘K trigger:
/// both are "type here to find things", and a rail field with its own smaller
/// radius and heavier border read as a different, lesser control.
///
/// The trailing slot advertises ⌘F — the shortcut that focuses this field has
/// existed all along with nothing on screen to reveal it — and hands the slot
/// over to the clear button the moment there is something to clear.
class EvolveSearchField extends StatefulWidget {
  const EvolveSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.focusNode,
    this.clearTooltip,
    this.shortcutHint,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final String? clearTooltip;
  final ValueChanged<String> onChanged;

  /// Keyboard hint shown while the field is empty, e.g. `⌘ F`.
  final String? shortcutHint;

  @override
  State<EvolveSearchField> createState() => _EvolveSearchFieldState();
}

class _EvolveSearchFieldState extends State<EvolveSearchField> {
  /// Owned only when the caller supplies none — the focus ring has to react to
  /// focus whether or not the parent cares about it.
  FocusNode? _ownedFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownedFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(EvolveSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      _ownedFocus?.removeListener(_onFocusChanged);
      _focus.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocusChanged);
    _ownedFocus?.removeListener(_onFocusChanged);
    _ownedFocus?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        return EvolveSearchChrome.wrap(
          context,
          focused: _focus.hasFocus,
          trailing: hasText
              ? Tooltip(
                  message: widget.clearTooltip ?? '',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      widget.controller.clear();
                      widget.onChanged('');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(LucideIcons.x, size: 14, color: colors.muted),
                    ),
                  ),
                )
              : widget.shortcutHint == null
              ? null
              : EvolveSearchChrome.badge(context, widget.shortcutHint!),
          child: TextField(
            key: const Key('settings.searchField'),
            controller: widget.controller,
            focusNode: _focus,
            onChanged: widget.onChanged,
            textAlignVertical: TextAlignVertical.center,
            style: EvolveSearchChrome.labelStyle(
              context,
            ).copyWith(color: colors.foreground),
            decoration: InputDecoration(
              isDense: true,
              // All four, not just `border`. The global InputDecorationTheme
              // sets `enabledBorder`/`focusedBorder` and `filled: true`, and
              // state-specific borders win over `border` — so a lone
              // `border: InputBorder.none` left Flutter painting the theme's
              // radius-12 outlined box *inside* this pill, around the text
              // only. That ghost ring is the double outline users saw.
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
              hintText: widget.hintText,
              hintStyle: EvolveSearchChrome.labelStyle(context),
              contentPadding: EdgeInsets.zero,
            ),
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
