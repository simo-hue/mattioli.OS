import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../application/coach_controllers.dart';
import '../domain/coach_backend.dart';
import '../domain/coach_config.dart';
import 'coach_settings_dialog.dart';

/// Header pill showing the active coach engine + model. Tapping it opens a
/// one-tap switcher of the remote engines + discovered Local models, plus an
/// entry into the full server settings. Honors the "decide the model in the
/// chat" requirement.
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
    final controller = ref.read(coachConfigProvider.notifier);
    final backend = ref.watch(effectiveCoachBackendProvider);
    final isLocal = backend == CoachBackendKind.local;
    final offerStandard =
        ref.watch(standardCoachStatusProvider) !=
        StandardCoachStatus.unavailablePrivate;
    final label = activeLabel(config, backend);

    // Discovered local models (empty until/unless the server answers).
    final localModels = ref
        .watch(coachLocalModelsProvider(config.localBaseUrl))
        .maybeWhen(data: (list) => list, orElse: () => const <CoachModel>[]);

    return EvolveMenu(
      minWidth: 260,
      tooltip: label,
      triggerBuilder: (context, menu) => _ChipButton(
        label: label,
        isLocal: isLocal,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
      ),
      children: [
        if (offerStandard)
          EvolveMenuItem(
            label: t.coachSettings.standardSection,
            leading: const Icon(
              LucideIcons.sparkles,
              size: 15,
              color: EvolveColors.violet,
            ),
            selected: backend == CoachBackendKind.standard,
            onTap: () => controller.setBackend(CoachBackendKind.standard),
          ),
        EvolveMenuItem(
          label: t.coachSettings.cloudSection,
          leading: const Icon(LucideIcons.cloud, size: 15, color: EvolveColors.cyan),
          selected: backend == CoachBackendKind.cloud,
          onTap: () => controller.setBackend(CoachBackendKind.cloud),
        ),
        if (localModels.isNotEmpty) ...[
          const EvolveMenuDivider(),
          for (final model in localModels)
            EvolveMenuItem(
              label: model.displayLabel,
              leading: const Icon(
                LucideIcons.cpu,
                size: 15,
                color: EvolveColors.violet,
              ),
              selected: isLocal && config.localModel == model.id,
              onTap: () async {
                await controller.setLocalModel(model.id);
                await controller.setBackend(CoachBackendKind.local);
              },
            ),
        ],
        const EvolveMenuDivider(),
        EvolveMenuItem(
          label: t.coachSettings.serverSettings,
          leading: Icon(
            LucideIcons.slidersHorizontal,
            size: 15,
            color: context.evolveAccent,
          ),
          accent: true,
          onTap: () => showCoachSettingsDialog(context),
        ),
      ],
    );
  }
}

class _ChipButton extends StatefulWidget {
  const _ChipButton({
    required this.label,
    required this.isLocal,
    required this.onTap,
  });

  final String label;
  final bool isLocal;
  final VoidCallback onTap;

  @override
  State<_ChipButton> createState() => _ChipButtonState();
}

class _ChipButtonState extends State<_ChipButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final accent = widget.isLocal ? EvolveColors.violet : EvolveColors.cyan;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          constraints: const BoxConstraints(maxWidth: 220),
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
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                ),
              ),
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
                LucideIcons.chevronsUpDown,
                size: 13,
                color: _hovered ? colors.foreground : colors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
