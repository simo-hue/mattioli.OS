import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/core/rtl.dart';
import 'package:evolve_desktop/shared/widgets/evolve_color_picker.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
import 'package:evolve_desktop/shared/widgets/popover.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The Settings row vocabulary.
///
/// Every row is one horizontal band: an optional leading icon chip, a label
/// with an optional help line beneath it, and exactly one control aligned to
/// the right-hand column.
///
/// Two rules the old private versions of these widgets broke, and the reason
/// this file exists:
///
/// * **Help text is an editorial decision, not a property of the widget
///   class.** `detail` used to be a required `String` on the switch, action,
///   info and colour rows and *absent entirely* from the select and time rows
///   — so obvious switches carried filler while "Language", "Default calendar
///   view" and both reminder times could not explain themselves at all. It is
///   now an optional `String?` everywhere.
/// * **A control that cannot be used says so.** Nothing here could render as
///   disabled, so Pro-gated and session-gated rows looked identical to live
///   ones and revealed the gate only on tap. [SettingsRowState] dims the whole
///   row and puts the reason in the help slot.

/// Whether a row can be used right now, and why not when it cannot.
///
/// `disabled` dims the row and takes it out of the hit-testing tree; the
/// [reason] replaces the row's help text, so the explanation lands where the
/// user is already looking instead of arriving as a toast after a dead tap.
///
/// Capability that can never exist on this machine (Touch ID on Linux, iCloud
/// sync off macOS) should not be disabled — it should not be rendered at all. A
/// permanently impossible control is noise, not information.
class SettingsRowState {
  const SettingsRowState.enabled() : reason = null, _disabled = false;
  const SettingsRowState.disabled(String this.reason) : _disabled = true;

  final String? reason;
  final bool _disabled;

  bool get isDisabled => _disabled;
}

/// One settings group as a single titled card: a sentence-case label sits
/// inside an [EvolvePanel] (radius 20) above its rows, which render as flat
/// list tiles separated by hairline dividers — the macOS grouped-settings look
/// in the Evolve skin.
///
/// [footnote] carries the things that belong to the group rather than to any
/// one row: scope disclosure ("These settings also apply on your iPhone."), the
/// end-to-end-encryption statement, platform notes and billing terms. Before it
/// existed all of that was either pushed into an individual row's help text or
/// floated outside the card as a third container idiom.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    this.title,
    required this.children,
    this.footnote,
  });

  final String? title;
  final List<Widget> children;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final label = title;
    final note = footnote;
    return EvolvePanel(
      padding: EdgeInsets.zero,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 6),
              // Sentence case, and the weight raised so the card's organising
              // label outranks the row subtitles inside it. It used to render
              // at 13/w500 muted@0.8 against 15/w700 row titles, which made the
              // group heading the weakest text in its own card.
              child: Text(
                label,
                style: TextStyle(
                  color: context.evolveColors.foreground.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            )
          else
            const SizedBox(height: 8),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SettingsRowHairline(),
            children[i],
          ],
          if (note != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 4),
              child: Text(
                note,
                style: TextStyle(
                  color: context.evolveColors.muted.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// 1px divider between the flat rows of a group card, inset to the card's own
/// 16px content padding.
///
/// It used to hard-code a 68px indent (16 padding + 36 icon chip + 16 gap) so
/// it would clear the leading chip. Ordinary preference rows no longer carry a
/// chip — forty identical accent squares per pane is noise, and macOS Settings
/// does not do it — so the indent that assumed one now just looks like a
/// mistake.
class SettingsRowHairline extends StatelessWidget {
  const SettingsRowHairline({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsetsDirectional.only(start: 16, end: 16),
      color: context.evolveColors.border.withValues(alpha: 0.35),
    );
  }
}

TextStyle settingsRowTitleStyle(BuildContext context) => TextStyle(
  color: context.evolveColors.foreground,
  fontSize: 15,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
);

TextStyle settingsRowSubtitleStyle(BuildContext context) => TextStyle(
  color: context.evolveColors.muted.withValues(alpha: 0.8),
  fontSize: 12,
  fontWeight: FontWeight.w500,
);

Widget settingsRowIconChip(BuildContext context, IconData icon) =>
    EvolveIconChip(
      icon: icon,
      color: context.evolveAccent,
      size: 36,
      iconSize: 18,
      outlined: true,
    );

/// Carries the id of the row the sidebar search just jumped to.
///
/// An InheritedWidget rather than a flag threaded through every pane: the
/// highlight is a property of the page, and the row that has to react to it is
/// eight or nine widgets down inside whichever group happens to contain it.
class SettingsHighlight extends InheritedWidget {
  const SettingsHighlight({
    super.key,
    required this.rowId,
    required this.targetKey,
    required super.child,
  });

  /// Null when nothing is highlighted.
  final String? rowId;

  /// Attached to whichever row is currently highlighted, so the page can call
  /// `Scrollable.ensureVisible` on it. A `ValueKey` cannot do this — only a
  /// GlobalKey exposes a `currentContext` — and exactly one row is highlighted
  /// at a time, so there is never a duplicate.
  final GlobalKey targetKey;

  static SettingsHighlight? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsHighlight>();

  @override
  bool updateShouldNotify(SettingsHighlight oldWidget) =>
      oldWidget.rowId != rowId || oldWidget.targetKey != targetKey;
}

/// Tints a row while the sidebar search or the ⌘K palette is pointing at it.
///
/// When highlighted it emits a widget keyed `settings.row.<id>.highlighted`.
/// That marker is the only thing a test can assert on: the accent wash is an
/// `AnimatedContainer` decoration, and rows already contain unrelated
/// `AnimatedContainer`s (`EvolveSelect`'s, for one), so "some container in this
/// row has a non-transparent colour" is true whether the highlight fired or
/// not — a mutation test proved exactly that.
class _SettingsRowHighlight extends StatelessWidget {
  const _SettingsRowHighlight({required this.rowId, required this.child});

  final String rowId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final highlight = SettingsHighlight.of(context);
    final highlighted = highlight?.rowId == rowId;
    final tinted = AnimatedContainer(
      key: highlighted ? highlight!.targetKey : null,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: highlighted
            ? context.evolveAccent.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
    if (!highlighted) return tinted;
    return KeyedSubtree(
      key: ValueKey('settings.row.$rowId.highlighted'),
      child: tinted,
    );
  }
}

/// The shared anatomy of every row in this file.
///
/// Having one scaffold is the point: before it, whether a row could show help
/// text, whether it dimmed when unusable, and how far its hairline was inset
/// were each decided independently per widget, and they had already drifted
/// apart. Anything a row wants to vary goes in [trailing].
class _SettingsRowScaffold extends StatelessWidget {
  const _SettingsRowScaffold({
    this.id,
    required this.label,
    this.detail,
    this.icon,
    this.badge,
    this.trailing,
    this.onTap,
    this.state = const SettingsRowState.enabled(),
    this.destructive = false,
  });

  /// Stable identity, e.g. `'general.theme'`. Supplies both the widget key
  /// tests navigate by and the address the sidebar search jumps to.
  final String? id;
  final String label;
  final String? detail;
  final IconData? icon;
  final Widget? badge;
  final Widget? trailing;
  final VoidCallback? onTap;
  final SettingsRowState state;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final disabled = state.isDisabled;
    // The disabled reason REPLACES the help text rather than joining it: two
    // explanations stacked under one label is how the old gate toasts read,
    // and only one of them is actionable.
    final help = disabled ? state.reason : detail;
    final chip = icon;

    final titleColor = destructive
        ? EvolveColors.destructive
        : context.evolveColors.foreground;

    final title = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: settingsRowTitleStyle(context).copyWith(color: titleColor),
    );

    final tile = ListTile(
      onTap: disabled ? null : onTap,
      enabled: !disabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: chip == null ? null : settingsRowIconChip(context, chip),
      title: badge == null
          ? title
          : Row(
              children: [
                Flexible(child: title),
                const SizedBox(width: 8),
                badge!,
              ],
            ),
      subtitle: help == null
          ? null
          : Text(help, style: settingsRowSubtitleStyle(context)),
      trailing: trailing,
    );

    Widget row = tile;
    if (disabled) {
      // Dim label, help and control together — a row whose switch still looks
      // live while its label greys out reads as a rendering bug, not a gate.
      row = IgnorePointer(child: Opacity(opacity: 0.45, child: tile));
    }

    final rowId = id;
    if (rowId == null) return row;

    return KeyedSubtree(
      key: SettingsKeys.row(rowId),
      child: _SettingsRowHighlight(rowId: rowId, child: row),
    );
  }
}

/// Full-width filled call to action — the one member of this vocabulary that is
/// allowed to outweigh everything around it.
///
/// It exists for the money step. Buying Evolve Pro was a [SettingsActionRow]:
/// a chevron list row rendered identically to "Replay the guided tour", so the
/// single most consequential control on the page was also the weakest-looking
/// element in its own funnel — and its chevron promised a detail pane while it
/// actually opened a payment sheet.
///
/// [busy] is a real state rather than a swallowed tap. The rows this replaces
/// passed `busy ? () {} : onTap`, which kept the full fill, the hover and the
/// ripple while silently eating every click for the length of a purchase: the
/// button looked live, answered the pointer, and did nothing.
class SettingsPrimaryButton extends StatelessWidget {
  const SettingsPrimaryButton({
    super.key,
    this.id,
    required this.label,
    required this.onPressed,
    this.caption,
    this.icon,
    this.busy = false,
  });

  /// Stable identity, e.g. `'subscription.subscribe'`. Same contract as the
  /// rows: the widget derives its own key, callers never pass one.
  final String? id;

  final String label;

  /// Null renders the disabled fill and takes the button out of the hit-testing
  /// tree. Use it when there is nothing to act on yet — no resolved plan, no
  /// session, an unsupported platform — and say why in [caption].
  final VoidCallback? onPressed;

  /// Small muted line under the button: billing scope, or the reason it is
  /// disabled.
  final String? caption;

  final IconData? icon;

  /// Replaces the label with an on-accent spinner and stops accepting clicks.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final accent = context.evolveAccent;
    final onAccent = Theme.of(context).colorScheme.onPrimary;
    final enabled = onPressed != null && !busy;
    final glyph = icon;
    final note = caption;

    Widget button = SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: accent.withValues(alpha: 0.35),
          disabledForegroundColor: onAccent.withValues(alpha: 0.75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        child: busy
            // The label goes with it, so a price cannot sit under the pointer
            // looking purchasable while the sheet for it is already up. The
            // Semantics wrapper keeps the control named while it does.
            ? Semantics(
                label: label,
                child: SizedBox.square(
                  dimension: 20,
                  child: EvolveSpinner(color: onAccent, radius: 9),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (glyph != null) ...[
                    Icon(glyph, size: 17),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );

    if (note != null) {
      button = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          button,
          const SizedBox(height: 8),
          Text(
            note,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.evolveColors.muted.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    final buttonId = id;
    if (buttonId == null) return button;
    return KeyedSubtree(key: SettingsKeys.row(buttonId), child: button);
  }
}

/// Full-width destructive action styled exactly like the mobile
/// "Go to login" button (destructive .1 fill, .2 border, radius 14), with the
/// row's original detail text kept as a small muted caption underneath.
class SettingsDestructiveButton extends StatelessWidget {
  const SettingsDestructiveButton({
    super.key,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: EvolveColors.destructive.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: EvolveColors.destructive.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: EvolveColors.destructive,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.evolveColors.muted.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    this.id,
    this.icon,
    required this.label,
    this.detail,
    required this.value,
    required this.onChanged,
    this.badge,
    this.state = const SettingsRowState.enabled(),
  });

  final String? id;
  final IconData? icon;
  final String label;
  final String? detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Optional trailing chip after the title (e.g. the PRO badge on
  /// Pro-gated rows).
  final Widget? badge;
  final SettingsRowState state;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowScaffold(
      id: id,
      icon: icon,
      label: label,
      detail: detail,
      badge: badge,
      state: state,
      // The whole row toggles, not just the 34px switch. A pointer target that
      // small is the kind of thing that only ever gets noticed by the person
      // who has to hit it every day.
      onTap: () => onChanged(!value),
      trailing: EvolveSwitch(value: value, onChanged: onChanged),
    );
  }
}

/// Settings row wrapping an [EvolveSelect]. [value] and the options' values are
/// canonical CODES, never the rendered labels: [EvolveSelect] matches [value]
/// against the option values, so a localized label must not be the identity —
/// it would stop matching as soon as the UI language changes.
class SettingsSelectRow<T> extends StatelessWidget {
  const SettingsSelectRow({
    super.key,
    this.id,
    this.icon,
    required this.label,
    this.detail,
    required this.value,
    required this.options,
    required this.onChanged,
    this.state = const SettingsRowState.enabled(),
  });

  final String? id;
  final IconData? icon;
  final String label;
  final String? detail;
  final T value;
  final List<EvolveSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final SettingsRowState state;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowScaffold(
      id: id,
      icon: icon,
      label: label,
      detail: detail,
      state: state,
      trailing: EvolveSelect<T>(
        value: value,
        options: options,
        onChanged: onChanged,
      ),
    );
  }
}

class SettingsTimeRow extends StatelessWidget {
  const SettingsTimeRow({
    super.key,
    this.id,
    this.icon,
    required this.label,
    this.detail,
    required this.value,
    required this.use24hFormat,
    required this.onChanged,
    this.state = const SettingsRowState.enabled(),
  });

  final String? id;
  final IconData? icon;
  final String label;
  final String? detail;
  final String value;
  final bool use24hFormat;
  final ValueChanged<String> onChanged;
  final SettingsRowState state;

  @override
  Widget build(BuildContext context) {
    final parts = value.split(':');
    return _SettingsRowScaffold(
      id: id,
      icon: icon,
      label: label,
      detail: detail,
      state: state,
      trailing: EvolveTimePicker(
        value: TimeOfDay(
          hour: int.tryParse(parts.first) ?? 9,
          minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
        ),
        use24hFormat: use24hFormat,
        onChanged: (selected) => onChanged(
          '${selected.hour.toString().padLeft(2, '0')}:'
          '${selected.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }
}

class SettingsColorRow extends StatelessWidget {
  const SettingsColorRow({
    super.key,
    this.id,
    required this.icon,
    required this.label,
    required this.detail,
    required this.selected,
    required this.onChanged,
    this.customLocked = false,
    this.onCustomLocked,
  });

  final String? id;
  final IconData icon;
  final String label;
  final String detail;
  final Color selected;
  final ValueChanged<Color> onChanged;

  /// When true, the custom-color swatch is a Pro feature (mobile parity): it
  /// shows a lock and invokes [onCustomLocked] instead of opening the picker.
  final bool customLocked;
  final VoidCallback? onCustomLocked;

  @override
  Widget build(BuildContext context) {
    // RAW values, deliberately NOT mapped through `_visibleAccent` here. The
    // whole list used to be mapped before this loop, so `onChanged(color)`
    // below handed over the MAPPED colour: in a light theme, tapping the
    // leftmost "white" swatch stored and synced `#09090B` — a near-black the
    // user never chose — to every device. Mapping is a PAINT concern and now
    // happens per-swatch, one line above the widget that paints it.
    //
    // The first entry is the seed itself rather than a parallel literal, so it
    // cannot drift from what a fresh profile actually holds.
    final colors = [
      DesktopAppearanceController.defaultAccent,
      const Color(0xFFEAB308),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF97316),
    ];
    // Same highlight/identity treatment as _SettingsRowScaffold; this row has
    // its own layout (a swatch strip, not a single trailing control) so it
    // cannot share the scaffold.
    final rowId = id;
    Widget wrap(Widget child) {
      if (rowId == null) return child;
      return KeyedSubtree(
        key: SettingsKeys.row(rowId),
        child: _SettingsRowHighlight(rowId: rowId, child: child),
      );
    }

    return wrap(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            settingsRowIconChip(context, icon),
            const SizedBox(width: 16),
            Expanded(
              child: SettingsRowCopy(label: label, detail: detail),
            ),
            SizedBox(
              width: 220,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in colors)
                    // `color` is the stored identity — tooltip, equality and what
                    // gets published. `display` is pixels only.
                    Builder(
                      builder: (context) {
                        final display = _visibleAccent(context, color);
                        final isSelected = selected == color;
                        return Tooltip(
                          message: t.settingsPage.useAccent(hex: _toHex(color)),
                          child: InkWell(
                            onTap: () => onChanged(color),
                            customBorder: const CircleBorder(),
                            child: SettingsSwatch(
                              color: display,
                              isSelected: isSelected,
                              child: isSelected
                                  ? Icon(
                                      LucideIcons.check,
                                      size: 12,
                                      color: _checkColor(display),
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  Tooltip(
                    message: t.settingsPage.customColor,
                    child: InkWell(
                      onTap: customLocked
                          ? onCustomLocked
                          : () =>
                                _showFullColorPicker(context, colors.toList()),
                      customBorder: const CircleBorder(),
                      child: SettingsSwatch(
                        color: context.evolveColors.panelRaised,
                        isSelected: false,
                        outlined: true,
                        child: Icon(
                          customLocked ? LucideIcons.lock : LucideIcons.plus,
                          size: 14,
                          color: context.evolveColors.foreground,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullColorPicker(BuildContext context, List<Color> colors) {
    showPopover(
      context: context,
      targetAlignment: Alignment.bottomCenter,
      popoverAlignment: Alignment.topCenter,
      offset: const Offset(0, 8),
      builder: (context) {
        return EvolveColorPickerContent(
          initialColor: selected,
          onColorChanged: onChanged,
        );
      },
    );
  }

  /// Paint-time substitution ONLY — never what gets stored or compared.
  ///
  /// Keyed off [DesktopAppearanceController.defaultAccent] rather than a
  /// repeated hex literal: the two were independent constants and drifted, so
  /// the substitution silently stopped firing for the seed white and the page
  /// painted an invisible swatch on a light background.
  Color _visibleAccent(BuildContext context, Color color) {
    if (Theme.of(context).brightness == Brightness.light &&
        color.toARGB32() ==
            DesktopAppearanceController.defaultAccent.toARGB32()) {
      return const Color(0xFF09090B);
    }
    return color;
  }

  Color _checkColor(Color color) =>
      color.computeLuminance() > 0.45 ? const Color(0xFF09090B) : Colors.white;

  String _toHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';
}

/// 24px color swatch circle; the selected one gets a foreground ring and a
/// soft tint glow (mobile color-picker recipe).
class SettingsSwatch extends StatelessWidget {
  const SettingsSwatch({
    super.key,
    required this.color,
    required this.isSelected,
    this.outlined = false,
    this.child,
  });

  final Color color;
  final bool isSelected;
  final bool outlined;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: isSelected
            ? Border.all(color: context.evolveColors.foreground, width: 2)
            : outlined
            ? Border.all(color: context.evolveColors.border)
            : null,
        boxShadow: isSelected
            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
            : null,
      ),
      child: child == null ? null : Center(child: child),
    );
  }
}

/// A row that opens something: a modal ([external] false, chevron) or a
/// destination outside the app ([external] true, external-link glyph).
///
/// The chevron used to be unconditional, so every one of these promised a
/// detail pane and delivered a modal dialog or a jump to System Settings.
class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    super.key,
    this.id,
    this.icon,
    required this.title,
    this.detail,
    required this.onTap,
    this.state = const SettingsRowState.enabled(),
    this.external = false,
    this.destructive = false,
    this.busy = false,
  });

  final String? id;
  final IconData? icon;
  final String title;
  final String? detail;
  final VoidCallback onTap;
  final SettingsRowState state;
  final bool external;
  final bool destructive;

  /// Shows a spinner and stops accepting taps. The old rows passed
  /// `busy ? () {} : onTap`, which kept full styling, hover and ripple while
  /// silently swallowing clicks during a purchase or a restore.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tint = destructive
        ? EvolveColors.destructive
        : context.evolveColors.muted;
    return _SettingsRowScaffold(
      id: id,
      icon: icon,
      label: title,
      detail: detail,
      destructive: destructive,
      state: busy ? SettingsRowState.disabled(detail ?? title) : state,
      onTap: onTap,
      trailing: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: EvolveSpinner(radius: 8),
            )
          : external
          ? Icon(LucideIcons.externalLink, size: 16, color: tint)
          : DirectionalIcon(
              LucideIcons.chevronRight,
              LucideIcons.chevronLeft,
              size: 18,
              color: tint,
            ),
    );
  }
}

/// A label with an editable value in the control column.
///
/// This is the row type that lets a modal be deleted: personal information was
/// a dialog because there was no way to edit a string in place. It commits on
/// blur and on Enter — never on every keystroke, which would write a partial
/// name to the synced profile with every character typed.
class SettingsTextRow extends StatefulWidget {
  const SettingsTextRow({
    super.key,
    this.id,
    this.icon,
    required this.label,
    this.detail,
    required this.controller,
    required this.onCommit,
    this.hintText,
    this.obscure = false,
    this.fieldWidth = 240,
    this.state = const SettingsRowState.enabled(),
  });

  final String? id;
  final IconData? icon;
  final String label;
  final String? detail;
  final TextEditingController controller;

  /// Called once the user is done editing — blur or Enter, not per keystroke.
  final ValueChanged<String> onCommit;

  final String? hintText;
  final bool obscure;
  final double fieldWidth;
  final SettingsRowState state;

  @override
  State<SettingsTextRow> createState() => _SettingsTextRowState();
}

class _SettingsTextRowState extends State<SettingsTextRow> {
  final FocusNode _focus = FocusNode();

  /// Whether the text has changed since the last commit.
  ///
  /// Pressing Enter fires `onSubmitted` AND drops focus, so without this one
  /// edit committed twice — two writes and, on a synced field, two round trips
  /// per keystroke-session. Only an actual change commits.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() => _dirty = true;

  void _onFocusChange() {
    if (!_focus.hasFocus) _commit(widget.controller.text);
  }

  void _commit(String value) {
    if (!_dirty) return;
    _dirty = false;
    widget.onCommit(value);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsRowScaffold(
      id: widget.id,
      icon: widget.icon,
      label: widget.label,
      detail: widget.detail,
      state: widget.state,
      trailing: SizedBox(
        width: widget.fieldWidth,
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          obscureText: widget.obscure,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: context.evolveColors.foreground,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
          onSubmitted: _commit,
        ),
      ),
    );
  }
}

/// A label with a date picker in the control column.
class SettingsDateRow extends StatelessWidget {
  const SettingsDateRow({
    super.key,
    this.id,
    this.icon,
    required this.label,
    this.detail,
    required this.value,
    required this.onChanged,
    this.hint,
    this.firstDate,
    this.lastDate,
    this.state = const SettingsRowState.enabled(),
  });

  final String? id;
  final IconData? icon;
  final String label;
  final String? detail;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? hint;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final SettingsRowState state;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowScaffold(
      id: id,
      icon: icon,
      label: label,
      detail: detail,
      state: state,
      trailing: SizedBox(
        width: 240,
        // No `label:` — the row already has one, and EvolveDateField would
        // render a second copy above the field.
        child: EvolveDateField(
          value: value,
          hint: hint,
          firstDate: firstDate,
          lastDate: lastDate,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// A read-only label/value pair.
///
/// The value sits in the trailing control column, right-aligned — not in the
/// subtitle slot, where it rendered in exactly the same 12px muted style as the
/// help text of the row above it and made static disclosure indistinguishable
/// from explanation. That also frees [detail] for genuine help text.
class SettingsInfoRow extends StatelessWidget {
  const SettingsInfoRow({
    super.key,
    this.id,
    this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  final String? id;
  final IconData? icon;
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowScaffold(
      id: id,
      icon: icon,
      label: label,
      detail: detail,
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: context.evolveColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// A read-only status with its own action button — "Notification permission:
/// Allowed / Ask…", "Server: Connected / Start".
///
/// Splitting the status from the action is what lets a revoke row stay on
/// screen after it has been used. The AI Coach consent row used to erase itself
/// the moment consent was withdrawn, so there was no way to see that sharing
/// was off, or to turn it back on.
class SettingsStatusRow extends StatelessWidget {
  const SettingsStatusRow({
    super.key,
    this.id,
    this.icon,
    required this.label,
    this.detail,
    required this.status,
    this.actionLabel,
    this.onAction,
    this.destructiveAction = false,
    this.state = const SettingsRowState.enabled(),
  });

  final String? id;
  final IconData? icon;
  final String label;
  final String? detail;
  final String status;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool destructiveAction;
  final SettingsRowState state;

  @override
  Widget build(BuildContext context) {
    final action = actionLabel;
    return _SettingsRowScaffold(
      id: id,
      icon: icon,
      label: label,
      detail: detail,
      state: state,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status,
            style: TextStyle(
              color: context.evolveColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: destructiveAction
                    ? EvolveColors.destructive
                    : null,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(action),
            ),
          ],
        ],
      ),
    );
  }
}

/// An inline banner inside a group card, for a condition the user has to see
/// before the rows beneath it make sense.
///
/// The iCloud key-split remedy used to be an ordinary action row sitting two
/// below "Sync now" and looking identical to it — for the single most
/// cross-device-destructive action on the page. iOS already promotes it to a
/// card; this is that card.
class SettingsWarningRow extends StatelessWidget {
  const SettingsWarningRow({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.destructive = true,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tint = destructive ? EvolveColors.destructive : context.evolveAccent;
    final action = actionLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tint.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.triangleAlert, size: 15, color: tint),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: tint,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      color: context.evolveColors.foreground.withValues(
                        alpha: 0.85,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 10),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: tint),
                child: Text(action),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsRowCopy extends StatelessWidget {
  const SettingsRowCopy({super.key, required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: settingsRowTitleStyle(context)),
        const SizedBox(height: 3),
        Text(detail, style: settingsRowSubtitleStyle(context)),
      ],
    );
  }
}
