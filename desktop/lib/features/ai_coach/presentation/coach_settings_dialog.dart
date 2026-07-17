import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../application/coach_controllers.dart';
import '../application/ollama_start_controller.dart';
import '../domain/coach_backend.dart';
import '../domain/coach_config.dart';
import 'start_ollama_button.dart';

/// Opens the reusable coach-engine configuration dialog (backend, local server,
/// model discovery, system prompt, temperature). Used from both the chat header
/// and the Settings page.
Future<void> showCoachSettingsDialog(BuildContext context) {
  return showEvolveDialog<void>(
    context: context,
    builder: (_) => const CoachSettingsDialog(),
  );
}

class CoachSettingsDialog extends ConsumerStatefulWidget {
  const CoachSettingsDialog({super.key});

  @override
  ConsumerState<CoachSettingsDialog> createState() =>
      _CoachSettingsDialogState();
}

class _CoachSettingsDialogState extends ConsumerState<CoachSettingsDialog> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _manualModel;
  late final TextEditingController _systemPrompt;
  final FocusNode _baseUrlFocus = FocusNode();
  bool _advancedOpen = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(coachConfigProvider);
    _baseUrl = TextEditingController(text: config.localBaseUrl);
    _manualModel = TextEditingController();
    _systemPrompt = TextEditingController(
      text: config.systemPromptOverride ?? '',
    );
    _advancedOpen = config.systemPromptOverride != null;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _manualModel.dispose();
    _systemPrompt.dispose();
    _baseUrlFocus.dispose();
    super.dispose();
  }

  CoachConfigController get _controller =>
      ref.read(coachConfigProvider.notifier);

  void _commitBaseUrl() {
    final normalized = normalizeBaseUrl(_baseUrl.text);
    if (normalized != ref.read(coachConfigProvider).localBaseUrl) {
      _controller.setLocalBaseUrl(normalized);
    }
    // Reflect the canonical form back into the field.
    _baseUrl.text = normalized;
  }

  void _commitSystemPrompt() =>
      _controller.setSystemPromptOverride(_systemPrompt.text);

  /// Persists every pending field so NO close path (Save, header X, barrier
  /// tap) can drop an edit — the fields also commit live/on-blur, this is the
  /// belt-and-suspenders sweep for the Save button.
  void _commitAll() {
    _commitBaseUrl();
    _commitSystemPrompt();
  }

  void _applyPreset(LocalServerPreset preset) {
    if (preset == LocalServerPreset.custom) {
      // "Custom" isn't a URL — move focus to the field so the user can type.
      _baseUrlFocus.requestFocus();
      return;
    }
    _baseUrl.text = preset.baseUrl;
    _controller.setLocalBaseUrl(preset.baseUrl);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(coachConfigProvider);
    // What will actually serve — not what is persisted. In Private mode a stored
    // Standard choice resolves to BYOK, and the dialog must show the section the
    // user can act on rather than one that can only fail.
    final backend = ref.watch(effectiveCoachBackendProvider);
    final standardStatus = ref.watch(standardCoachStatusProvider);
    // Private mode keeps no account, so Standard is not a choice there — offering
    // it would be offering a mode that cannot answer. The note in its place
    // explains why and points at the two engines that do work.
    final offerStandard =
        standardStatus != StandardCoachStatus.unavailablePrivate;
    final colors = context.evolveColors;

    return EvolveAlertDialog(
      maxWidth: 560,
      icon: LucideIcons.sparkles,
      iconColor: EvolveColors.violet,
      title: Text(t.coachSettings.title),
      subtitle: t.coachSettings.subtitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EvolveSegmentedControl<CoachBackendKind>(
            segments: {
              if (offerStandard)
                CoachBackendKind.standard: t.coachSettings.backendStandard,
              CoachBackendKind.cloud: t.coachSettings.backendCloud,
              CoachBackendKind.local: t.coachSettings.backendLocal,
            },
            selected: backend,
            onSelected: _controller.setBackend,
          ),
          const SizedBox(height: 12),
          Text(
            switch (backend) {
              CoachBackendKind.local => t.coachSettings.localDesc,
              CoachBackendKind.standard => t.coachSettings.standardDesc,
              CoachBackendKind.cloud => t.coachSettings.cloudDesc,
            },
            style: TextStyle(
              color: colors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          if (!offerStandard) ...[
            const SizedBox(height: 12),
            _WarningNote(text: t.coachSettings.standardPrivateNote),
          ],
          if (backend == CoachBackendKind.standard) ...[
            const SizedBox(height: 18),
            _StandardSection(status: standardStatus),
          ],
          if (backend == CoachBackendKind.cloud) ...[
            const SizedBox(height: 18),
            const _CloudApiKeySection(),
          ],
          if (backend == CoachBackendKind.local) ...[
            const SizedBox(height: 18),
            _LocalServerSection(
              config: config,
              baseUrlController: _baseUrl,
              baseUrlFocus: _baseUrlFocus,
              manualModelController: _manualModel,
              onCommitBaseUrl: _commitBaseUrl,
              onApplyPreset: _applyPreset,
            ),
          ],
          const SizedBox(height: 18),
          _AdvancedSection(
            open: _advancedOpen,
            onToggle: () => setState(() => _advancedOpen = !_advancedOpen),
            systemPromptController: _systemPrompt,
            onCommitSystemPrompt: _commitSystemPrompt,
            temperature: config.temperature,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () {
            _commitAll();
            Navigator.pop(context);
          },
          child: Text(t.coachSettings.save),
        ),
      ],
    );
  }
}

/// Standard block: what the Evolve Pro subscription buys, and — when it cannot
/// serve — which of the two free engines to use instead.
///
/// Deliberately has no key field, no URL, and no model picker. That absence is
/// the point: Guideline 3.1.1 rejected the app because paid functionality was
/// enabled by a key the user pasted. Here the purchase is the only unlock, and
/// there is nothing to configure.
class _StandardSection extends StatelessWidget {
  const _StandardSection({required this.status});

  final StandardCoachStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final ready = status == StandardCoachStatus.ready;

    final (label, pillColor, icon) = switch (status) {
      StandardCoachStatus.ready => (
        t.coachSettings.standardStatusReady,
        EvolveColors.success,
        LucideIcons.circleCheck,
      ),
      StandardCoachStatus.needsPro => (
        t.coachSettings.standardStatusNeedsPro,
        EvolveColors.amber,
        LucideIcons.sparkles,
      ),
      StandardCoachStatus.needsSignIn => (
        t.coachSettings.standardStatusNeedsSignIn,
        EvolveColors.amber,
        LucideIcons.logIn,
      ),
      StandardCoachStatus.unavailablePrivate ||
      StandardCoachStatus.unavailableUnconfigured => (
        t.coachSettings.standardStatusUnavailable,
        EvolveColors.destructive,
        LucideIcons.circleX,
      ),
    };

    final note = switch (status) {
      StandardCoachStatus.ready => null,
      StandardCoachStatus.needsPro => t.coachSettings.standardNeedsProNote,
      StandardCoachStatus.needsSignIn =>
        t.coachSettings.standardNeedsSignInNote,
      StandardCoachStatus.unavailablePrivate =>
        t.coachSettings.standardPrivateNote,
      StandardCoachStatus.unavailableUnconfigured =>
        t.coachSettings.standardUnavailableNote,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: EvolveFieldLabel(t.coachSettings.standardSection),
            ),
            StatusPill(label: label, color: pillColor, icon: icon),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          // The one model the proxy runs. The server pins it; this only says so.
          t.coachSettings.activeStandard(model: kStandardCoachModel),
          style: TextStyle(
            color: ready ? colors.foreground : colors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 12),
          _WarningNote(text: note),
        ],
      ],
    );
  }
}

/// BYOK block: the user's own OpenRouter key — a free alternative to the
/// subscription, not a second unlock on top of it.
///
/// A stored key is NEVER rendered back into the field — the pill reports that
/// one exists, and saving simply overwrites it. That keeps the secret off the
/// screen (and out of any screenshot) while still letting the user replace it.
class _CloudApiKeySection extends ConsumerStatefulWidget {
  const _CloudApiKeySection();

  @override
  ConsumerState<_CloudApiKeySection> createState() =>
      _CloudApiKeySectionState();
}

class _CloudApiKeySectionState extends ConsumerState<_CloudApiKeySection> {
  final TextEditingController _field = TextEditingController();
  bool _busy = false;
  bool _saveFailed = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _field.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _saveFailed = false;
    });
    final saved = await ref
        .read(coachApiKeyProvider.notifier)
        .save(_field.text);
    if (!mounted) return;
    if (saved) _field.clear();
    setState(() {
      _busy = false;
      _saveFailed = !saved;
    });
  }

  Future<void> _remove() async {
    final confirmed = await showEvolveDialog<bool>(
      context: context,
      builder: (context) => EvolveAlertDialog(
        icon: LucideIcons.triangleAlert,
        iconColor: EvolveColors.destructive,
        title: Text(t.ai.apiKey.removeConfirmTitle),
        content: Text(
          t.ai.apiKey.removeConfirmBody,
          style: TextStyle(
            color: context.evolveColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.actions.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.ai.apiKey.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(coachApiKeyProvider.notifier).clear();
    if (!mounted) return;
    setState(() => _saveFailed = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final hasKey = ref.watch(coachApiKeyProvider).asData?.value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: EvolveFieldLabel(t.ai.apiKey.fieldLabel)),
            StatusPill(
              label: hasKey
                  ? t.ai.apiKey.statusSet
                  : t.ai.apiKey.statusMissing,
              color: hasKey ? EvolveColors.success : EvolveColors.amber,
              icon: hasKey ? LucideIcons.circleCheck : LucideIcons.keyRound,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          t.ai.apiKey.description,
          style: TextStyle(
            color: colors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
        if (!hasKey) ...[
          const SizedBox(height: 12),
          _WarningNote(text: t.coachSettings.cloudKeyMissing),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _field,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                style: TextStyle(color: colors.foreground, fontSize: 13),
                decoration: InputDecoration(hintText: t.ai.apiKey.hint),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(t.ai.apiKey.save),
            ),
          ],
        ),
        if (_saveFailed) ...[
          const SizedBox(height: 10),
          _WarningNote(text: t.ai.apiKey.saveFailed),
        ],
        if (hasKey)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _remove,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                t.ai.apiKey.remove,
                style: const TextStyle(
                  color: EvolveColors.destructive,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Amber inline warning note (missing cloud key, etc.).
class _WarningNote extends StatelessWidget {
  const _WarningNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: EvolveColors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: EvolveColors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.triangleAlert,
            size: 15,
            color: EvolveColors.amber,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: EvolveColors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Local-server block: preset, base URL, live status + remote badge, and model
/// discovery (auto-list with a manual fallback).
class _LocalServerSection extends ConsumerWidget {
  const _LocalServerSection({
    required this.config,
    required this.baseUrlController,
    required this.baseUrlFocus,
    required this.manualModelController,
    required this.onCommitBaseUrl,
    required this.onApplyPreset,
  });

  final CoachConfig config;
  final TextEditingController baseUrlController;
  final FocusNode baseUrlFocus;
  final TextEditingController manualModelController;
  final VoidCallback onCommitBaseUrl;
  final ValueChanged<LocalServerPreset> onApplyPreset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.evolveColors;
    final preset = LocalServerPreset.match(config.localBaseUrl);
    final isRemote = !config.localIsPrivate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: EvolveSelect<LocalServerPreset>(
                label: t.coachSettings.presetLabel,
                expand: true,
                value: preset,
                options: [
                  EvolveSelectOption(
                    value: LocalServerPreset.ollama,
                    label: t.coachSettings.presetOllama,
                  ),
                  EvolveSelectOption(
                    value: LocalServerPreset.lmStudio,
                    label: t.coachSettings.presetLmStudio,
                  ),
                  EvolveSelectOption(
                    value: LocalServerPreset.custom,
                    label: t.coachSettings.presetCustom,
                  ),
                ],
                onChanged: onApplyPreset,
              ),
            ),
            const SizedBox(width: 12),
            if (isRemote) ...[
              StatusPill(
                label: t.coachSettings.remoteBadge,
                color: EvolveColors.amber,
                icon: LucideIcons.globe,
              ),
              const SizedBox(width: 8),
            ],
            _ReachabilityPill(baseUrl: config.localBaseUrl),
          ],
        ),
        _OllamaStartRow(config: config, preset: preset),
        const SizedBox(height: 14),
        EvolveFieldLabel(t.coachSettings.baseUrlLabel),
        const SizedBox(height: 8),
        TextField(
          controller: baseUrlController,
          focusNode: baseUrlFocus,
          style: TextStyle(color: colors.foreground, fontSize: 13),
          decoration: InputDecoration(hintText: t.coachSettings.baseUrlHint),
          onSubmitted: (_) => onCommitBaseUrl(),
          onTapOutside: (_) {
            FocusManager.instance.primaryFocus?.unfocus();
            onCommitBaseUrl();
          },
        ),
        if (isRemote) ...[
          const SizedBox(height: 10),
          _WarningNote(text: t.coachSettings.remoteWarning),
        ],
        const SizedBox(height: 16),
        _ModelPickerRow(
          config: config,
          manualModelController: manualModelController,
        ),
      ],
    );
  }
}

/// In-dialog "Start Ollama" affordance — shown below the status pill only when
/// the local Ollama server is unreachable, with a soft hint on timeout.
class _OllamaStartRow extends ConsumerWidget {
  const _OllamaStartRow({required this.config, required this.preset});

  final CoachConfig config;
  final LocalServerPreset preset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reachable = ref
        .watch(coachLocalReachableProvider(config.localBaseUrl))
        .asData
        ?.value;
    if (reachable == null) return const SizedBox.shrink();
    if (!shouldOfferOllamaStart(
      backend: config.backend,
      preset: preset,
      reachable: reachable,
    )) {
      return const SizedBox.shrink();
    }
    final hint = switch (ref.watch(ollamaStartControllerProvider)) {
      OllamaStartStatus.timedOut => t.coachSettings.ollamaStartTimeout,
      OllamaStartStatus.failed => t.coachSettings.ollamaStartFailed,
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StartOllamaButton(),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint,
              style: TextStyle(
                color: context.evolveColors.muted,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Connected / Offline / Checking pill, driven by the reachability probe.
class _ReachabilityPill extends ConsumerWidget {
  const _ReachabilityPill({required this.baseUrl});

  final String baseUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reachable = ref.watch(coachLocalReachableProvider(baseUrl));
    return reachable.when(
      loading: () => StatusPill(
        label: t.coachSettings.statusChecking,
        color: context.evolveColors.muted,
        icon: LucideIcons.loader,
      ),
      error: (_, _) => StatusPill(
        label: t.coachSettings.statusOffline,
        color: EvolveColors.destructive,
        icon: LucideIcons.circleX,
      ),
      data: (ok) => ok
          ? StatusPill(
              label: t.coachSettings.statusConnected,
              color: EvolveColors.success,
              icon: LucideIcons.circleCheck,
            )
          : StatusPill(
              label: t.coachSettings.statusOffline,
              color: EvolveColors.destructive,
              icon: LucideIcons.circleX,
            ),
    );
  }
}

/// Model area: auto-discovered dropdown when the server lists models, a manual
/// id field when it doesn't, always with a refresh affordance.
class _ModelPickerRow extends ConsumerWidget {
  const _ModelPickerRow({
    required this.config,
    required this.manualModelController,
  });

  final CoachConfig config;
  final TextEditingController manualModelController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.evolveColors;
    final models = ref.watch(coachLocalModelsProvider(config.localBaseUrl));

    void refresh() {
      ref.invalidate(coachLocalModelsProvider(config.localBaseUrl));
      ref.invalidate(coachLocalReachableProvider(config.localBaseUrl));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: EvolveFieldLabel(t.coachSettings.modelLabel)),
            _MiniIconButton(
              icon: LucideIcons.refreshCw,
              tooltip: t.coachSettings.refreshModels,
              onTap: refresh,
            ),
          ],
        ),
        const SizedBox(height: 8),
        models.when(
          loading: () => Row(
            children: [
              const EvolveSpinner(radius: 8),
              const SizedBox(width: 10),
              Text(
                t.coachSettings.discovering,
                style: TextStyle(color: colors.muted, fontSize: 12.5),
              ),
            ],
          ),
          error: (_, _) => _ManualModelField(
            controller: manualModelController,
            currentModel: config.localModel,
          ),
          data: (list) {
            if (list.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.coachSettings.noModelsFound,
                    style: TextStyle(color: colors.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  _ManualModelField(
                    controller: manualModelController,
                    currentModel: config.localModel,
                  ),
                ],
              );
            }
            // Keep a hand-typed model selectable even if the server didn't list
            // it, so switching the base URL never strands the current pick.
            final options = effectiveLocalModelOptions(list, config.localModel);
            final current = config.localModel;
            final value = (current != null && current.trim().isNotEmpty)
                ? current
                : null;
            return EvolveSelect<String>(
              expand: true,
              value: value,
              options: [
                for (final model in options)
                  EvolveSelectOption(value: model.id, label: model.displayLabel),
              ],
              onChanged: (id) =>
                  ref.read(coachConfigProvider.notifier).setLocalModel(id),
            );
          },
        ),
      ],
    );
  }
}

class _ManualModelField extends ConsumerWidget {
  const _ManualModelField({required this.controller, required this.currentModel});

  final TextEditingController controller;
  final String? currentModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.evolveColors;
    void commit() {
      final id = controller.text.trim();
      if (id.isEmpty) return;
      ref.read(coachConfigProvider.notifier).setLocalModel(id);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EvolveFieldLabel(t.coachSettings.manualModelLabel),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: TextStyle(color: colors.foreground, fontSize: 13),
                decoration: InputDecoration(
                  hintText: currentModel ?? t.coachSettings.modelHint,
                ),
                onSubmitted: (_) => commit(),
                // Commit on blur too, so an id typed then closed via Save / the
                // header X (which blurs the field) isn't lost.
                onTapOutside: (_) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  commit();
                },
              ),
            ),
            const SizedBox(width: 10),
            _MiniIconButton(
              icon: LucideIcons.check,
              tooltip: t.coachSettings.manualModelAdd,
              onTap: commit,
            ),
          ],
        ),
      ],
    );
  }
}

/// Collapsible advanced block: system-prompt override + temperature stepper.
class _AdvancedSection extends ConsumerWidget {
  const _AdvancedSection({
    required this.open,
    required this.onToggle,
    required this.systemPromptController,
    required this.onCommitSystemPrompt,
    required this.temperature,
  });

  final bool open;
  final VoidCallback onToggle;
  final TextEditingController systemPromptController;
  final VoidCallback onCommitSystemPrompt;
  final double temperature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.evolveColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  open ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                  size: 16,
                  color: colors.muted,
                ),
                const SizedBox(width: 8),
                Text(
                  t.coachSettings.advanced,
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: EvolveFieldLabel(t.coachSettings.systemPromptLabel)),
              _ResetSystemPrompt(controller: systemPromptController),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: systemPromptController,
            minLines: 2,
            maxLines: 4,
            style: TextStyle(color: colors.foreground, fontSize: 13, height: 1.4),
            decoration: InputDecoration(
              hintText: t.coachSettings.systemPromptHint,
            ),
            // A multiline field's onSubmitted never fires (Enter inserts a
            // newline), so commit on blur — this is what survives closing the
            // dialog via the header X or the barrier instead of Save.
            onTapOutside: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              onCommitSystemPrompt();
            },
          ),
          const SizedBox(height: 16),
          _TemperatureRow(temperature: temperature),
        ],
      ],
    );
  }
}

class _ResetSystemPrompt extends ConsumerWidget {
  const _ResetSystemPrompt({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () {
        controller.clear();
        ref.read(coachConfigProvider.notifier).setSystemPromptOverride(null);
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        t.coachSettings.systemPromptReset,
        style: TextStyle(color: context.evolveColors.muted, fontSize: 12),
      ),
    );
  }
}

class _TemperatureRow extends ConsumerWidget {
  const _TemperatureRow({required this.temperature});

  final double temperature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.evolveColors;
    // Round to one decimal so repeated stepping doesn't drift (0.7+0.1 = 0.7999…).
    void step(double delta) => ref
        .read(coachConfigProvider.notifier)
        .setTemperature(((temperature + delta) * 10).roundToDouble() / 10);

    return Row(
      children: [
        Expanded(child: EvolveFieldLabel(t.coachSettings.temperatureLabel)),
        _MiniIconButton(
          icon: LucideIcons.minus,
          tooltip: t.coachSettings.temperatureLower,
          onTap: () => step(-0.1),
        ),
        SizedBox(
          width: 44,
          child: Text(
            temperature.toStringAsFixed(1),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _MiniIconButton(
          icon: LucideIcons.plus,
          tooltip: t.coachSettings.temperatureRaise,
          onTap: () => step(0.1),
        ),
      ],
    );
  }
}

/// 30px bordered square icon button — a compact sibling of EvolveSquareIconButton
/// used inside dialog rows.
class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return EvolveSquareIconButton(
      icon: icon,
      onTap: onTap,
      tooltip: tooltip,
      size: 32,
      iconSize: 15,
    );
  }
}
