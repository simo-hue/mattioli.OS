import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/rtl.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Evolve form controls — the desktop kit's macOS-feeling replacements for the
/// stock Material controls (Switch, DropdownButton, showTimePicker,
/// showDatePicker, RadioListTile). Every screen must use these instead of the
/// Material defaults so the app reads native on macOS in both themes.
///
/// All widgets here:
/// - theme exclusively through [EvolvePalette] / `context.evolveAccent`,
/// - use Lucide icons only,
/// - are direction-safe (RTL) via the *Directional layout primitives and
///   [DirectionalIcon] for asymmetric glyphs,
/// - show pointer cursors and subtle hover states (desktop pointer polish).

// ---------------------------------------------------------------------------
// EvolveSwitch
// ---------------------------------------------------------------------------

/// macOS-style toggle: pill track that fills [EvolveColors.success] when on
/// (matching the app's previous switch accent), with a white thumb that slides
/// between the directional edges. Sized for desktop density (40x24 — roughly
/// the mobile toggle at 0.8 scale). Pass a null [onChanged] to disable.
class EvolveSwitch extends StatefulWidget {
  const EvolveSwitch({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const double trackWidth = 40;
  static const double trackHeight = 24;

  @override
  State<EvolveSwitch> createState() => _EvolveSwitchState();
}

class _EvolveSwitchState extends State<EvolveSwitch> {
  bool _hovered = false;

  bool get _enabled => widget.onChanged != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final offTrack = isDark ? colors.panelSoft : colors.border;
    final onTrack = EvolveColors.success;
    final track = widget.value ? onTrack : offTrack;

    return Semantics(
      container: true,
      toggled: widget.value,
      enabled: _enabled,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _enabled ? () => widget.onChanged!(!widget.value) : null,
          child: Opacity(
            opacity: _enabled ? 1 : 0.45,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: EvolveSwitch.trackWidth,
              height: EvolveSwitch.trackHeight,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _hovered && _enabled
                    ? Color.alphaBlend(
                        colors.foreground.withValues(alpha: 0.05),
                        track,
                      )
                    : track,
                borderRadius: BorderRadius.circular(
                  EvolveSwitch.trackHeight / 2,
                ),
                border: Border.all(
                  color: colors.borderStrong.withValues(
                    alpha: widget.value ? 0.0 : (isDark ? 0.55 : 0.35),
                  ),
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: widget.value
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EvolveMenu — the popup primitive behind EvolveSelect and any "menu button"
// ---------------------------------------------------------------------------

/// Evolve-styled popup menu anchored to a custom trigger. Wraps [MenuAnchor]
/// (so outside-tap dismissal, positioning and focus behave natively) but kills
/// all Material menu chrome: the surface is a raised panel with the kit's
/// border, radius and shadow, and items are [EvolveMenuItem]s.
class EvolveMenu extends StatelessWidget {
  const EvolveMenu({
    required this.triggerBuilder,
    required this.children,
    super.key,
    this.tooltip,
    this.minWidth,
  });

  /// Builds the always-visible trigger. Call `controller.open()` /
  /// `controller.close()` from the trigger's tap handler.
  final Widget Function(BuildContext context, MenuController controller)
  triggerBuilder;

  /// Menu surface children — usually [EvolveMenuItem]s and
  /// [EvolveMenuDivider]s.
  final List<Widget> children;

  final String? tooltip;

  /// Minimum width of the popup surface (used by [EvolveSelect] to match the
  /// trigger width).
  final double? minWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.panelRaised),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: isDark ? 0.5 : 0.22),
        ),
        elevation: const WidgetStatePropertyAll(14),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: colors.borderStrong.withValues(alpha: isDark ? 0.6 : 0.5),
            ),
          ),
        ),
      ),
      alignmentOffset: const Offset(0, 4),
      consumeOutsideTap: true,
      menuChildren: [
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth ?? 0),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
      builder: (context, controller, _) {
        final trigger = triggerBuilder(context, controller);
        if (tooltip == null) return trigger;
        return Tooltip(message: tooltip!, child: trigger);
      },
    );
  }
}

/// One row of an [EvolveMenu]: hover highlight, optional leading widget,
/// label, and a trailing check when [selected]. Closes the menu, then runs
/// [onTap] (after the close, like PopupMenuItem.onTap did).
class EvolveMenuItem extends StatefulWidget {
  const EvolveMenuItem({
    required this.label,
    required this.onTap,
    super.key,
    this.leading,
    this.selected = false,
    this.accent = false,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? leading;
  final bool selected;

  /// Tint the label with the accent color (for "create…" style actions).
  final bool accent;

  @override
  State<EvolveMenuItem> createState() => _EvolveMenuItemState();
}

class _EvolveMenuItemState extends State<EvolveMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final labelColor = widget.accent
        ? context.evolveAccent
        : colors.foreground;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          MenuController.maybeOf(context)?.close();
          // Fire after the close (PopupMenuItem.onTap parity) so handlers can
          // push dialogs without racing the closing overlay.
          WidgetsBinding.instance.addPostFrameCallback((_) => widget.onTap());
        },
        child: Container(
          height: 34,
          padding: const EdgeInsetsDirectional.only(start: 10, end: 10),
          decoration: BoxDecoration(
            // Foreground-alpha hover reads in BOTH themes (panelSoft is nearly
            // invisible against panelRaised in light mode).
            color: _hovered
                ? colors.foreground.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 9),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w600,
                    letterSpacing: -0.1,
                    color: labelColor,
                  ),
                ),
              ),
              if (widget.selected) ...[
                const SizedBox(width: 12),
                Icon(LucideIcons.check, size: 14, color: context.evolveAccent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Hairline separator between [EvolveMenuItem]s.
class EvolveMenuDivider extends StatelessWidget {
  const EvolveMenuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      color: context.evolveColors.border.withValues(alpha: 0.6),
    );
  }
}

// ---------------------------------------------------------------------------
// EvolveSelect
// ---------------------------------------------------------------------------

/// One choice of an [EvolveSelect].
class EvolveSelectOption<T> {
  const EvolveSelectOption({
    required this.value,
    required this.label,
    this.leading,
  });

  final T value;
  final String label;

  /// Optional small leading widget (color dot, icon) shown in the menu row
  /// and in the closed trigger.
  final Widget? leading;
}

/// macOS pop-up-button style select: a bordered trigger showing the current
/// value with a chevrons-up-down glyph, opening an [EvolveMenu] of options
/// with the selected one checked. Replaces every Material DropdownButton.
///
/// Shape variants:
/// - default: filled trigger (panel tint, border, radius 12) — toolbars/rows;
/// - [fillColor] to match surrounding fields (forms use background 50%);
/// - [filled] false: naked trigger (text + chevron only) for use inside an
///   existing panel row;
/// - [expand] true: trigger stretches to the available width and the menu
///   matches at least the trigger width.
class EvolveSelect<T> extends StatefulWidget {
  const EvolveSelect({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
    this.label,
    this.filled = true,
    this.expand = false,
    this.height,
    this.fillColor,
    this.textStyle,
    this.tooltip,
  });

  final T? value;
  final List<EvolveSelectOption<T>> options;

  /// Null disables the control.
  final ValueChanged<T>? onChanged;

  /// Optional uppercase micro-label rendered above the trigger (the kit's
  /// field-label recipe).
  final String? label;

  final bool filled;
  final bool expand;
  final double? height;
  final Color? fillColor;
  final TextStyle? textStyle;
  final String? tooltip;

  @override
  State<EvolveSelect<T>> createState() => _EvolveSelectState<T>();
}

class _EvolveSelectState<T> extends State<EvolveSelect<T>> {
  bool _hovered = false;
  final GlobalKey _triggerKey = GlobalKey();
  double? _menuMinWidth;

  bool get _enabled => widget.onChanged != null && widget.options.isNotEmpty;

  EvolveSelectOption<T>? get _selected {
    for (final option in widget.options) {
      if (option.value == widget.value) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final selected = _selected;
    final style =
        widget.textStyle ??
        TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: colors.foreground,
        );

    final control = EvolveMenu(
      tooltip: widget.tooltip,
      minWidth: widget.expand ? _menuMinWidth : null,
      triggerBuilder: (context, controller) {
        return MouseRegion(
          cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: !_enabled
                ? null
                : () {
                    if (controller.isOpen) {
                      controller.close();
                      return;
                    }
                    final box =
                        _triggerKey.currentContext?.findRenderObject()
                            as RenderBox?;
                    setState(() => _menuMinWidth = box?.size.width);
                    controller.open();
                  },
            child: Opacity(
              opacity: _enabled ? 1 : 0.5,
              child: AnimatedContainer(
                key: _triggerKey,
                duration: const Duration(milliseconds: 150),
                height: widget.height ?? (widget.filled ? 34 : null),
                padding: widget.filled
                    ? const EdgeInsetsDirectional.only(start: 12, end: 8)
                    : EdgeInsets.zero,
                decoration: widget.filled
                    ? BoxDecoration(
                        color:
                            widget.fillColor ??
                            colors.panel.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _hovered && _enabled
                              ? colors.borderStrong
                              : colors.border.withValues(alpha: 0.9),
                        ),
                      )
                    : null,
                child: Row(
                  mainAxisSize: widget.expand
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  children: [
                    if (selected?.leading != null) ...[
                      selected!.leading!,
                      const SizedBox(width: 8),
                    ],
                    widget.expand
                        ? Expanded(child: _triggerLabel(selected, style))
                        : Flexible(child: _triggerLabel(selected, style)),
                    const SizedBox(width: 7),
                    Icon(
                      LucideIcons.chevronsUpDown,
                      size: 13,
                      color: _hovered && _enabled
                          ? colors.foreground
                          : colors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      children: [
        for (final option in widget.options)
          EvolveMenuItem(
            label: option.label,
            leading: option.leading,
            selected: option.value == widget.value,
            onTap: () {
              if (option.value != widget.value) {
                widget.onChanged?.call(option.value);
              }
            },
          ),
      ],
    );

    if (widget.label == null) return control;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        EvolveFieldLabel(widget.label!),
        const SizedBox(height: 8),
        control,
      ],
    );
  }

  Widget _triggerLabel(EvolveSelectOption<T>? selected, TextStyle style) {
    return Text(
      selected?.label ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// Uppercase micro-label above a form field ("HABIT NAME" on mobile) — the
/// shared version of the per-dialog `_FieldLabel` recipe.
class EvolveFieldLabel extends StatelessWidget {
  const EvolveFieldLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: context.evolveColors.muted,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EvolveProBadge
// ---------------------------------------------------------------------------

/// Tiny amber "PRO" chip marking Pro-gated rows — the mobile app's badge
/// (amber tint fill + border, 9pt black-weight caps) in the desktop kit.
class EvolveProBadge extends StatelessWidget {
  const EvolveProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: EvolveColors.amber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: EvolveColors.amber.withValues(alpha: 0.4)),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          color: EvolveColors.amber,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EvolveRadioRow
// ---------------------------------------------------------------------------

/// Apple-style exclusive choice row: a bordered card with a radio dot, title
/// and caption. The selected row gets an accent ring and tint. Replaces
/// RadioListTile groups.
class EvolveRadioRow<T> extends StatefulWidget {
  const EvolveRadioRow({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    super.key,
    this.subtitle,
  });

  final T value;
  final T groupValue;
  final ValueChanged<T>? onChanged;
  final String title;
  final String? subtitle;

  bool get _selected => value == groupValue;

  @override
  State<EvolveRadioRow<T>> createState() => _EvolveRadioRowState<T>();
}

class _EvolveRadioRowState<T> extends State<EvolveRadioRow<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final accent = context.evolveAccent;
    final selected = widget._selected;
    final enabled = widget.onChanged != null;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => widget.onChanged!(widget.value) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.06)
                  : (_hovered && enabled
                        ? colors.foreground.withValues(alpha: 0.04)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.55)
                    : colors.border.withValues(alpha: _hovered ? 1 : 0.7),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? accent : colors.panel,
                      border: Border.all(
                        color: selected ? accent : colors.borderStrong,
                        width: 1.4,
                      ),
                    ),
                    child: selected
                        ? Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                          color: colors.foreground,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            color: colors.muted.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
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

// ---------------------------------------------------------------------------
// EvolveTimePicker
// ---------------------------------------------------------------------------

/// Compact time control: a bordered trigger showing the formatted time that
/// opens the Evolve time dialog (hour/minute steppers with direct text entry,
/// AM/PM segmented control in 12-hour mode). Replaces showTimePicker.
class EvolveTimePicker extends StatefulWidget {
  const EvolveTimePicker({
    required this.value,
    required this.onChanged,
    super.key,
    this.use24hFormat = true,
  });

  final TimeOfDay value;
  final ValueChanged<TimeOfDay>? onChanged;
  final bool use24hFormat;

  @override
  State<EvolveTimePicker> createState() => _EvolveTimePickerState();
}

class _EvolveTimePickerState extends State<EvolveTimePicker> {
  bool _hovered = false;

  bool get _enabled => widget.onChanged != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final label = MaterialLocalizations.of(context).formatTimeOfDay(
      widget.value,
      alwaysUse24HourFormat: widget.use24hFormat,
    );
    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: !_enabled
            ? null
            : () async {
                final picked = await showEvolveTimePicker(
                  context: context,
                  initialTime: widget.value,
                  use24hFormat: widget.use24hFormat,
                );
                if (picked != null) widget.onChanged!(picked);
              },
        child: Opacity(
          opacity: _enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 34,
            padding: const EdgeInsetsDirectional.only(start: 11, end: 12),
            decoration: BoxDecoration(
              color: colors.panel.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovered && _enabled
                    ? colors.borderStrong
                    : colors.border.withValues(alpha: 0.9),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.clock,
                  size: 14,
                  color: _hovered && _enabled
                      ? colors.foreground
                      : colors.muted,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    color: colors.foreground,
                    fontFeatures: const [FontFeature.tabularFigures()],
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

/// Evolve-styled replacement for showTimePicker: an [EvolveAlertDialog] with
/// hour and minute stepper fields (chevron buttons + direct typing) and an
/// AM/PM toggle when [use24hFormat] is false. Resolves to the picked
/// [TimeOfDay], or null when cancelled.
Future<TimeOfDay?> showEvolveTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  bool use24hFormat = true,
}) {
  return showEvolveDialog<TimeOfDay>(
    context: context,
    builder: (context) => _EvolveTimePickerDialog(
      initialTime: initialTime,
      use24hFormat: use24hFormat,
    ),
  );
}

class _EvolveTimePickerDialog extends StatefulWidget {
  const _EvolveTimePickerDialog({
    required this.initialTime,
    required this.use24hFormat,
  });

  final TimeOfDay initialTime;
  final bool use24hFormat;

  @override
  State<_EvolveTimePickerDialog> createState() =>
      _EvolveTimePickerDialogState();
}

class _EvolveTimePickerDialogState extends State<_EvolveTimePickerDialog> {
  late int _hour = widget.initialTime.hour; // always 0-23 internally
  late int _minute = widget.initialTime.minute;

  bool get _isPm => _hour >= 12;

  int get _displayHour =>
      widget.use24hFormat ? _hour : ((_hour + 11) % 12) + 1;

  void _setDisplayHour(int value) {
    if (widget.use24hFormat) {
      _hour = value.clamp(0, 23);
      return;
    }
    final normalized = ((value - 1) % 12 + 12) % 12 + 1; // 1-12
    _hour = (normalized % 12) + (_isPm ? 12 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final colors = context.evolveColors;
    return EvolveAlertDialog(
      maxWidth: 340,
      icon: LucideIcons.clock,
      title: Text(localizations.timePickerDialHelpText),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          // The HH:MM cluster is always laid out left-to-right — clock
          // readings do not mirror under RTL (Material's picker does the
          // same for its digit cluster).
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _TimeStepperField(
                  value: _displayHour,
                  digits: 2,
                  onStep: (delta) => setState(() {
                    _hour = (_hour + delta) % 24;
                    if (_hour < 0) _hour += 24;
                  }),
                  onSubmitted: (value) =>
                      setState(() => _setDisplayHour(value)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: colors.muted,
                    ),
                  ),
                ),
                _TimeStepperField(
                  value: _minute,
                  digits: 2,
                  onStep: (delta) => setState(() {
                    _minute = (_minute + delta) % 60;
                    if (_minute < 0) _minute += 60;
                  }),
                  onSubmitted: (value) =>
                      setState(() => _minute = value.clamp(0, 59)),
                ),
                if (!widget.use24hFormat) ...[
                  const SizedBox(width: 14),
                  _MeridiemToggle(
                    isPm: _isPm,
                    onChanged: (pm) => setState(() {
                      if (pm && !_isPm) _hour += 12;
                      if (!pm && _isPm) _hour -= 12;
                    }),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            TimeOfDay(hour: _hour, minute: _minute),
          ),
          child: Text(localizations.okButtonLabel),
        ),
      ],
    );
  }
}

/// One stepper column of the time dialog: chevron-up, a 2-digit text field,
/// chevron-down. Typing is clamped/normalized by the parent [onSubmitted].
class _TimeStepperField extends StatefulWidget {
  const _TimeStepperField({
    required this.value,
    required this.digits,
    required this.onStep,
    required this.onSubmitted,
  });

  final int value;
  final int digits;
  final ValueChanged<int> onStep;
  final ValueChanged<int> onSubmitted;

  @override
  State<_TimeStepperField> createState() => _TimeStepperFieldState();
}

class _TimeStepperFieldState extends State<_TimeStepperField> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.value),
  );
  final FocusNode _focusNode = FocusNode();

  String _format(int value) => value.toString().padLeft(widget.digits, '0');

  @override
  void initState() {
    super.initState();
    // Commit typed input when focus leaves the field, and re-render the
    // canonical zero-padded value.
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_TimeStepperField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text);
    if (parsed != null) widget.onSubmitted(parsed);
    _controller.text = _format(widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    if (!_focusNode.hasFocus) _controller.text = _format(widget.value);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperChevron(icon: LucideIcons.chevronUp, onTap: () {
          _focusNode.unfocus();
          widget.onStep(1);
        }),
        const SizedBox(height: 6),
        SizedBox(
          width: 62,
          height: 46,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: widget.digits,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _commit(),
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: colors.foreground,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: const InputDecoration(
              counterText: '',
              contentPadding: EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _StepperChevron(icon: LucideIcons.chevronDown, onTap: () {
          _focusNode.unfocus();
          widget.onStep(-1);
        }),
      ],
    );
  }
}

/// Small hover-highlighted chevron button used by the time steppers.
class _StepperChevron extends StatefulWidget {
  const _StepperChevron({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_StepperChevron> createState() => _StepperChevronState();
}

class _StepperChevronState extends State<_StepperChevron> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 34,
          height: 22,
          decoration: BoxDecoration(
            color: _hovered
                ? colors.foreground.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: colors.border.withValues(alpha: _hovered ? 1 : 0.6),
            ),
          ),
          child: Icon(
            widget.icon,
            size: 13,
            color: _hovered ? colors.foreground : colors.muted,
          ),
        ),
      ),
    );
  }
}

/// AM/PM toggle for the 12-hour time dialog — two stacked pills in the
/// segmented-control visual language. Labels come from
/// [MaterialLocalizations], so they localize with the app.
class _MeridiemToggle extends StatelessWidget {
  const _MeridiemToggle({required this.isPm, required this.onChanged});

  final bool isPm;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final colors = context.evolveColors;
    final accent = context.evolveAccent;
    final onAccent = Theme.of(context).colorScheme.onPrimary;

    Widget segment(String label, bool pm) {
      final selected = pm == isPm;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!selected) onChanged(pm);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            width: 46,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? onAccent : colors.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(localizations.anteMeridiemAbbreviation, false),
          const SizedBox(height: 3),
          segment(localizations.postMeridiemAbbreviation, true),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EvolveDatePicker
// ---------------------------------------------------------------------------

/// Field-shaped date control: renders like the app's text fields (floating
/// label, fill, radius 12) but opens the Evolve calendar dialog instead of a
/// keyboard. A trailing X clears the value when [onChanged] accepts null.
/// Replaces free-typed date fields and showDatePicker.
class EvolveDateField extends StatelessWidget {
  const EvolveDateField({
    required this.value,
    required this.onChanged,
    super.key,
    this.label,
    this.hint,
    this.firstDate,
    this.lastDate,
    this.clearable = true,
  });

  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final String? label;
  final String? hint;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool clearable;

  bool get _enabled => onChanged != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final localizations = MaterialLocalizations.of(context);
    final text = value == null ? null : localizations.formatMediumDate(value!);

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: !_enabled
            ? null
            : () async {
                final picked = await showEvolveDatePicker(
                  context: context,
                  initialDate: value,
                  firstDate: firstDate,
                  lastDate: lastDate,
                );
                if (picked != null) onChanged!(picked);
              },
        child: InputDecorator(
          isEmpty: value == null,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            suffixIcon: value != null && clearable && _enabled
                ? IconButton(
                    tooltip: localizations.deleteButtonTooltip,
                    icon: const Icon(LucideIcons.x, size: 15),
                    color: colors.muted,
                    onPressed: () => onChanged!(null),
                  )
                : Icon(
                    LucideIcons.calendar,
                    size: 16,
                    color: colors.muted,
                  ),
          ),
          child: text == null
              ? null
              : Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: colors.foreground),
                ),
        ),
      ),
    );
  }
}

/// Evolve-styled replacement for showDatePicker: a compact calendar popover
/// dialog (month grid, chevron month/year navigation, accent-pill selection).
/// Tapping a day resolves immediately — no OK step, like a macOS popover.
Future<DateTime?> showEvolveDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showEvolveDialog<DateTime>(
    context: context,
    builder: (context) => EvolveDialog(
      maxWidth: 332,
      child: _EvolveCalendar(
        initialDate: initialDate ?? DateTime.now(),
        selectedDate: initialDate,
        firstDate: firstDate ?? DateTime(1900),
        lastDate: lastDate ?? DateTime(2100, 12, 31),
      ),
    ),
  );
}

class _EvolveCalendar extends StatefulWidget {
  const _EvolveCalendar({
    required this.initialDate,
    required this.selectedDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime? selectedDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_EvolveCalendar> createState() => _EvolveCalendarState();
}

class _EvolveCalendarState extends State<_EvolveCalendar> {
  late DateTime _visibleMonth = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
  );

  static bool _sameDay(DateTime a, DateTime? b) =>
      b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  bool _inRange(DateTime day) =>
      !day.isBefore(
        DateTime(widget.firstDate.year, widget.firstDate.month,
            widget.firstDate.day),
      ) &&
      !day.isAfter(
        DateTime(
            widget.lastDate.year, widget.lastDate.month, widget.lastDate.day),
      );

  void _shiftMonth(int months) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + months,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final colors = context.evolveColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EvolveDialogHeader(
          title: Text(localizations.datePickerHelpText),
          icon: LucideIcons.calendar,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _CalendarNavButton(
                    icon: directionalIcon(
                      context,
                      LucideIcons.chevronsLeft,
                      LucideIcons.chevronsRight,
                    ),
                    tooltip: localizations.previousPageTooltip,
                    onTap: () => _shiftMonth(-12),
                  ),
                  const SizedBox(width: 4),
                  _CalendarNavButton(
                    icon: directionalIcon(
                      context,
                      LucideIcons.chevronLeft,
                      LucideIcons.chevronRight,
                    ),
                    tooltip: localizations.previousMonthTooltip,
                    onTap: () => _shiftMonth(-1),
                  ),
                  Expanded(
                    child: Text(
                      localizations.formatMonthYear(_visibleMonth),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  _CalendarNavButton(
                    icon: directionalIcon(
                      context,
                      LucideIcons.chevronRight,
                      LucideIcons.chevronLeft,
                    ),
                    tooltip: localizations.nextMonthTooltip,
                    onTap: () => _shiftMonth(1),
                  ),
                  const SizedBox(width: 4),
                  _CalendarNavButton(
                    icon: directionalIcon(
                      context,
                      LucideIcons.chevronsRight,
                      LucideIcons.chevronsLeft,
                    ),
                    tooltip: localizations.nextPageTooltip,
                    onTap: () => _shiftMonth(12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _weekdayHeader(localizations, colors),
              const SizedBox(height: 4),
              ..._weekRows(localizations, colors),
            ],
          ),
        ),
      ],
    );
  }

  Widget _weekdayHeader(
    MaterialLocalizations localizations,
    EvolvePalette colors,
  ) {
    final firstDayIndex = localizations.firstDayOfWeekIndex;
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                localizations.narrowWeekdays[(firstDayIndex + i) % 7],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: colors.subtle,
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _weekRows(
    MaterialLocalizations localizations,
    EvolvePalette colors,
  ) {
    final firstDayIndex = localizations.firstDayOfWeekIndex;
    final firstOfMonth = _visibleMonth;
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    // DateTime.weekday: Mon=1..Sun=7; MaterialLocalizations first-day index:
    // Sun=0..Sat=6. Leading blanks = offset of day 1 inside the week row.
    final leading = (firstOfMonth.weekday % 7 - firstDayIndex + 7) % 7;

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(
          date: DateTime(_visibleMonth.year, _visibleMonth.month, day),
          selected: _sameDay(
            DateTime(_visibleMonth.year, _visibleMonth.month, day),
            widget.selectedDate,
          ),
          enabled: _inRange(
            DateTime(_visibleMonth.year, _visibleMonth.month, day),
          ),
        ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return [
      for (var row = 0; row < cells.length ~/ 7; row++)
        Row(
          children: [
            for (var col = 0; col < 7; col++)
              Expanded(child: cells[row * 7 + col]),
          ],
        ),
    ];
  }
}

/// 28px square hover button for the calendar header (the kit's
/// EvolveSquareIconButton recipe at popover density).
class _CalendarNavButton extends StatefulWidget {
  const _CalendarNavButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<_CalendarNavButton> createState() => _CalendarNavButtonState();
}

class _CalendarNavButtonState extends State<_CalendarNavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered
                ? Color.alphaBlend(
                    colors.foreground.withValues(alpha: 0.06),
                    colors.panel,
                  )
                : colors.panel,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _hovered
                  ? colors.borderStrong
                  : colors.border,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 14,
            color: _hovered ? colors.foreground : colors.muted,
          ),
        ),
      ),
    );
    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}

class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.enabled,
  });

  final DateTime date;
  final bool selected;
  final bool enabled;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final accent = context.evolveAccent;
    final now = DateTime.now();
    final isToday = widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;

    final Color textColor;
    if (!widget.enabled) {
      textColor = colors.subtle.withValues(alpha: 0.45);
    } else if (widget.selected) {
      textColor = Theme.of(context).colorScheme.onPrimary;
    } else {
      textColor = colors.foreground;
    }

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled
            ? () => Navigator.pop(context, widget.date)
            : null,
        child: Container(
          height: 34,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: widget.selected
                ? accent
                : (_hovered && widget.enabled
                      ? colors.foreground.withValues(alpha: 0.07)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(9),
            border: isToday && !widget.selected
                ? Border.all(color: accent.withValues(alpha: 0.55))
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '${widget.date.day}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: widget.selected || isToday
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: textColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
