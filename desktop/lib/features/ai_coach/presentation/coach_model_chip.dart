import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../application/coach_controllers.dart';
import '../domain/coach_backend.dart';
import '../domain/coach_config.dart';
import 'coach_settings_dialog.dart';

/// Header state-selector: a professional pill naming the active engine + model
/// with a live status dot, that opens the full "AI coach engine" popup on tap.
///
/// This used to open a bespoke quick-switch menu of its own. That menu could
/// only ever show the ONE local server the config currently pointed at, so
/// switching Ollama ↔ LM Studio still meant a trip through the dialog — the very
/// asymmetry this redesign removes. The dialog's engine cards are now the single
/// switch surface, so the selector's whole job is to report state and open it.
class CoachModelChip extends ConsumerWidget {
  const CoachModelChip({super.key});

  /// The label for [backend] — which is the EFFECTIVE engine, not necessarily
  /// the persisted one. A Private-mode user with Standard stored is on BYOK, and
  /// a chip reading "Evolve AI" would name an engine that is not answering them.
  static String activeLabel(CoachConfig config, CoachBackendKind backend) {
    switch (backend) {
      case CoachBackendKind.local:
        final model = config.localModel;
        return (model == null || model.isEmpty)
            ? t.coachSettings.activeLocalNoModel
            : t.coachSettings.activeLocal(model: model);
      case CoachBackendKind.standard:
        return t.coachSettings.activeStandard(model: kStandardCoachModel);
      case CoachBackendKind.cloud:
        return t.coachSettings.activeCloud(model: config.cloudModel);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(coachConfigProvider);
    final backend = ref.watch(effectiveCoachBackendProvider);
    final label = activeLabel(config, backend);

    return _SelectorButton(
      label: label,
      statusColor: _statusColor(context, ref, config, backend),
      onTap: () => showCoachSettingsDialog(context),
    );
  }

  /// The dot's colour: green when the active engine can answer right now, amber
  /// when it needs a one-off setup step (sign in, subscribe, add a key), red when
  /// it's picked but unreachable, and muted while the probe is still resolving.
  /// Reuses the same providers the popup's cards read, so the two never disagree.
  Color _statusColor(
    BuildContext context,
    WidgetRef ref,
    CoachConfig config,
    CoachBackendKind backend,
  ) {
    switch (backend) {
      case CoachBackendKind.local:
        final reachable = ref
            .watch(coachLocalReachableProvider(config.localBaseUrl))
            .asData
            ?.value;
        if (reachable == null) return context.evolveColors.muted;
        return reachable ? EvolveColors.success : EvolveColors.destructive;
      case CoachBackendKind.cloud:
        final hasKey = ref.watch(coachApiKeyProvider).asData?.value != null;
        return hasKey ? EvolveColors.success : EvolveColors.amber;
      case CoachBackendKind.standard:
        return switch (ref.watch(standardCoachStatusProvider)) {
          StandardCoachStatus.ready => EvolveColors.success,
          StandardCoachStatus.needsPro ||
          StandardCoachStatus.needsSignIn => EvolveColors.amber,
          _ => EvolveColors.destructive,
        };
    }
  }
}

class _SelectorButton extends StatefulWidget {
  const _SelectorButton({
    required this.label,
    required this.statusColor,
    required this.onTap,
  });

  final String label;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  State<_SelectorButton> createState() => _SelectorButtonState();
}

class _SelectorButtonState extends State<_SelectorButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 40,
            constraints: const BoxConstraints(maxWidth: 230),
            padding: const EdgeInsetsDirectional.only(start: 12, end: 10),
            decoration: BoxDecoration(
              color: colors.panel.withValues(alpha: _hovered ? 0.55 : 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovered
                    ? colors.borderStrong
                    : colors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusDot(color: widget.statusColor),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  LucideIcons.chevronDown,
                  size: 13,
                  color: _hovered ? colors.foreground : colors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small filled dot with a matching soft halo — reads as a status light
/// rather than a bullet, without the weight of a full pill in the header.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: color.withValues(alpha: 0.25), width: 3),
      ),
    );
  }
}
