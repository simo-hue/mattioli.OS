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
import '../application/local_server_start_controller.dart';
import '../domain/coach_backend.dart';
import '../domain/coach_config.dart';
import '../domain/local_server_target.dart';
import 'start_local_server_button.dart';

/// Opens the reusable coach-engine configuration dialog (engine cards, local
/// server, model discovery, system prompt, temperature). Used from both the chat
/// header and the Settings page.
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

  /// Whether the custom-server fields (free-form base URL + manual model) are
  /// revealed. Named products hide the URL entirely — their card IS the URL — so
  /// this is true only when the user asked for a custom endpoint, or a previously
  /// saved custom URL is already active.
  bool _customExpanded = false;

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
    // A saved custom endpoint (one that matches no named preset) opens straight
    // into its editable fields rather than looking like an unselected picker.
    _customExpanded =
        config.backend == CoachBackendKind.local &&
        LocalServerPreset.match(config.localBaseUrl) ==
            LocalServerPreset.custom;
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
    if (_customExpanded) _commitBaseUrl();
    _commitSystemPrompt();
  }

  /// Switch to a named local product in one tap: point the local endpoint at its
  /// URL and make local the active backend. The remembered model for that URL
  /// follows automatically (per-product memory), and discovery re-runs because
  /// the model provider is keyed by base URL.
  void _selectLocalProduct(LocalServerPreset preset) {
    _baseUrl.text = preset.baseUrl;
    _controller.useLocalServer(preset.baseUrl);
    setState(() => _customExpanded = false);
  }

  void _useCustomServer() {
    _controller.setBackend(CoachBackendKind.local);
    setState(() => _customExpanded = true);
    _baseUrlFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(coachConfigProvider);
    // What will actually serve — not what is persisted. In Private mode a stored
    // Standard choice resolves to BYOK, and the dialog must show the engine the
    // user can act on rather than one that can only fail.
    final backend = ref.watch(effectiveCoachBackendProvider);
    final standardStatus = ref.watch(standardCoachStatusProvider);
    // Private mode keeps no account, so Standard is not a choice there. Its
    // absence is what flips the dialog from the single managed engine to the
    // BYOK + local engine cards.
    final offerStandard =
        standardStatus != StandardCoachStatus.unavailablePrivate;

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
          if (offerStandard)
            _StandardEngine(status: standardStatus)
          else
            _PrivateEngines(
              config: config,
              backend: backend,
              customExpanded: _customExpanded,
              baseUrlController: _baseUrl,
              baseUrlFocus: _baseUrlFocus,
              manualModelController: _manualModel,
              onSelectCloud: () {
                _controller.setBackend(CoachBackendKind.cloud);
                setState(() => _customExpanded = false);
              },
              onSelectProduct: _selectLocalProduct,
              onUseCustomServer: _useCustomServer,
              onCommitBaseUrl: _commitBaseUrl,
            ),
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

/// Account-mode engine: a single Evolve AI card carrying its subscription status,
/// plus the note that says where BYOK/local live (Private mode). No key field, no
/// URL, no model picker — that absence is the Guideline 3.1.1 shape: the purchase
/// is the only unlock, and there is nothing here to configure.
class _StandardEngine extends StatelessWidget {
  const _StandardEngine({required this.status});

  final StandardCoachStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final (statusColor, statusLabel) = _standardStatusChip(status);
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
        _EngineCard(
          icon: LucideIcons.sparkles,
          iconColor: EvolveColors.violet,
          name: t.coachSettings.backendStandard,
          subtitle: kStandardCoachModel,
          selected: true,
          statusColor: statusColor,
          statusLabel: statusLabel,
          onTap: null,
        ),
        if (note != null) ...[
          const SizedBox(height: 12),
          _WarningNote(text: note),
        ],
        const SizedBox(height: 12),
        Text(
          t.coachSettings.accountModeNote,
          style: TextStyle(
            color: colors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// The (colour, label) chip for an Evolve AI status: green when it can answer,
/// amber for a one-off fix the user owns (sign in / subscribe), red for a state
/// they cannot.
(Color, String) _standardStatusChip(StandardCoachStatus status) =>
    switch (status) {
      StandardCoachStatus.ready => (
        EvolveColors.success,
        t.coachSettings.standardStatusReady,
      ),
      StandardCoachStatus.needsPro => (
        EvolveColors.amber,
        t.coachSettings.standardStatusNeedsPro,
      ),
      StandardCoachStatus.needsSignIn => (
        EvolveColors.amber,
        t.coachSettings.standardStatusNeedsSignIn,
      ),
      StandardCoachStatus.unavailablePrivate ||
      StandardCoachStatus.unavailableUnconfigured => (
        EvolveColors.destructive,
        t.coachSettings.standardStatusUnavailable,
      ),
    };

/// Private-mode engines: the OpenRouter (BYOK) card, the two local product cards
/// with live status, a custom-server link, and the detail panel for whichever
/// engine is active. This is the whole point of the redesign — Ollama and
/// LM Studio are first-class, one-tap picks here, not options buried behind a
/// preset dropdown.
class _PrivateEngines extends ConsumerWidget {
  const _PrivateEngines({
    required this.config,
    required this.backend,
    required this.customExpanded,
    required this.baseUrlController,
    required this.baseUrlFocus,
    required this.manualModelController,
    required this.onSelectCloud,
    required this.onSelectProduct,
    required this.onUseCustomServer,
    required this.onCommitBaseUrl,
  });

  final CoachConfig config;
  final CoachBackendKind backend;
  final bool customExpanded;
  final TextEditingController baseUrlController;
  final FocusNode baseUrlFocus;
  final TextEditingController manualModelController;
  final VoidCallback onSelectCloud;
  final ValueChanged<LocalServerPreset> onSelectProduct;
  final VoidCallback onUseCustomServer;
  final VoidCallback onCommitBaseUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.evolveColors;
    final isLocal = backend == CoachBackendKind.local;
    final activePreset = LocalServerPreset.match(config.localBaseUrl);
    final hasKey = ref.watch(coachApiKeyProvider).asData?.value != null;

    // Both products are probed, so both cards show their own live/off state — the
    // detail no longer decides which single server we may look at.
    final ollamaReachable = ref
        .watch(coachLocalReachableProvider(LocalServerPreset.ollama.baseUrl))
        .asData
        ?.value;
    final lmStudioReachable = ref
        .watch(coachLocalReachableProvider(LocalServerPreset.lmStudio.baseUrl))
        .asData
        ?.value;

    final (ollamaColor, ollamaLabel) = _localStatusChip(context, ollamaReachable);
    final (lmColor, lmLabel) = _localStatusChip(context, lmStudioReachable);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EngineCard(
          icon: LucideIcons.cloud,
          iconColor: EvolveColors.cyan,
          name: t.coachSettings.engineOpenRouter,
          subtitle: t.coachSettings.engineOpenRouterHint,
          selected: backend == CoachBackendKind.cloud,
          statusColor: hasKey ? EvolveColors.success : EvolveColors.amber,
          statusLabel: hasKey
              ? t.ai.apiKey.statusSet
              : t.ai.apiKey.statusMissing,
          onTap: onSelectCloud,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(LucideIcons.monitor, size: 14, color: colors.muted),
            const SizedBox(width: 7),
            Text(
              t.coachSettings.localGroupLabel,
              style: TextStyle(
                color: colors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _EngineCard(
                icon: LucideIcons.cpu,
                iconColor: EvolveColors.violet,
                name: t.coachSettings.presetOllama,
                selected:
                    isLocal &&
                    !customExpanded &&
                    activePreset == LocalServerPreset.ollama,
                statusColor: ollamaColor,
                statusLabel: ollamaLabel,
                onTap: () => onSelectProduct(LocalServerPreset.ollama),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _EngineCard(
                icon: LucideIcons.cpu,
                iconColor: EvolveColors.violet,
                name: t.coachSettings.presetLmStudio,
                selected:
                    isLocal &&
                    !customExpanded &&
                    activePreset == LocalServerPreset.lmStudio,
                statusColor: lmColor,
                statusLabel: lmLabel,
                onTap: () => onSelectProduct(LocalServerPreset.lmStudio),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _CustomServerLink(
            active: isLocal && customExpanded,
            onTap: onUseCustomServer,
          ),
        ),
        if (backend == CoachBackendKind.cloud) ...[
          const SizedBox(height: 16),
          const _CloudApiKeySection(),
        ],
        if (isLocal) ...[
          const SizedBox(height: 16),
          _LocalDetail(
            config: config,
            customExpanded: customExpanded,
            baseUrlController: baseUrlController,
            baseUrlFocus: baseUrlFocus,
            manualModelController: manualModelController,
            onCommitBaseUrl: onCommitBaseUrl,
          ),
        ],
      ],
    );
  }
}

/// The (colour, label) chip for a local product card: green "Live" when its port
/// answers, muted "Off" when it doesn't, muted "Checking…" while the probe runs.
(Color, String) _localStatusChip(BuildContext context, bool? reachable) {
  if (reachable == null) {
    return (context.evolveColors.muted, t.coachSettings.statusChecking);
  }
  return reachable
      ? (EvolveColors.success, t.coachSettings.cardLive)
      : (context.evolveColors.muted, t.coachSettings.cardOff);
}

/// A selectable engine card: icon, name, optional subtitle, and a status
/// dot+label. Selection is a 2px accent ring (and a check) — deliberately
/// independent of the status dot, because a card can be the active engine while
/// its server is off.
class _EngineCard extends StatefulWidget {
  const _EngineCard({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.selected,
    required this.statusColor,
    required this.statusLabel,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String name;
  final String? subtitle;
  final bool selected;
  final Color statusColor;
  final String statusLabel;

  /// Null renders a non-interactive card (the account-mode Evolve AI card, which
  /// is the only engine and so nothing to switch to).
  final VoidCallback? onTap;

  @override
  State<_EngineCard> createState() => _EngineCardState();
}

class _EngineCardState extends State<_EngineCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final accent = context.evolveAccent;
    final interactive = widget.onTap != null;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.selected
            ? accent.withValues(alpha: 0.06)
            : colors.panel.withValues(alpha: _hovered ? 0.5 : 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.selected
              ? accent
              : (_hovered ? colors.borderStrong : colors.border),
          width: widget.selected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 20, color: widget.iconColor),
              const Spacer(),
              if (widget.selected)
                Icon(LucideIcons.circleCheck, size: 17, color: accent),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              widget.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.statusColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.statusLabel,
                style: TextStyle(
                  color: widget.statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!interactive) return content;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );
  }
}

/// The "Use a custom server…" affordance below the product cards — reveals the
/// free-form base-URL + manual-model fields for llama.cpp, Jan, or a LAN box.
class _CustomServerLink extends StatelessWidget {
  const _CustomServerLink({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final color = active ? context.evolveAccent : colors.muted;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? LucideIcons.chevronDown : LucideIcons.chevronRight,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            t.coachSettings.useCustomServer,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
              label: hasKey ? t.ai.apiKey.statusSet : t.ai.apiKey.statusMissing,
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

/// Detail panel for the active local product: product name + live status, an
/// in-place Start button when the server is down, the free-form base URL only
/// when the custom path is open, and model discovery (auto-list with a manual
/// fallback).
class _LocalDetail extends ConsumerWidget {
  const _LocalDetail({
    required this.config,
    required this.customExpanded,
    required this.baseUrlController,
    required this.baseUrlFocus,
    required this.manualModelController,
    required this.onCommitBaseUrl,
  });

  final CoachConfig config;
  final bool customExpanded;
  final TextEditingController baseUrlController;
  final FocusNode baseUrlFocus;
  final TextEditingController manualModelController;
  final VoidCallback onCommitBaseUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.evolveColors;
    final preset = LocalServerPreset.match(config.localBaseUrl);
    final target = LocalServerTarget.forPreset(preset);
    final isRemote = !config.localIsPrivate;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  target.displayName,
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
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
          _LocalServerStartRow(config: config, target: target),
          if (customExpanded) ...[
            const SizedBox(height: 14),
            EvolveFieldLabel(t.coachSettings.baseUrlLabel),
            const SizedBox(height: 8),
            TextField(
              controller: baseUrlController,
              focusNode: baseUrlFocus,
              style: TextStyle(color: colors.foreground, fontSize: 13),
              decoration: InputDecoration(hintText: target.baseUrlHint),
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
          ],
          const SizedBox(height: 16),
          _ModelPickerRow(
            config: config,
            target: target,
            manualModelController: manualModelController,
          ),
        ],
      ),
    );
  }
}

/// In-dialog "Start {app}" affordance — shown below the status pill only when
/// the configured local server is unreachable, with a soft hint on a failed or
/// inconclusive launch.
class _LocalServerStartRow extends ConsumerWidget {
  const _LocalServerStartRow({required this.config, required this.target});

  final CoachConfig config;
  final LocalServerTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reachable = ref
        .watch(coachLocalReachableProvider(config.localBaseUrl))
        .asData
        ?.value;
    if (reachable == null) return const SizedBox.shrink();
    if (!shouldOfferLocalServerStart(
      backend: config.backend,
      target: target,
      reachable: reachable,
      launcherSupported: ref.watch(localLauncherSupportedProvider),
    )) {
      return const SizedBox.shrink();
    }
    // The timeout hint is per-product on purpose: "check the menu-bar icon" and
    // "turn on Developer → Start Server" are different instructions, not one
    // sentence with the app's name swapped in.
    final hint = switch (ref.watch(localServerStartControllerProvider)) {
      LocalServerStartStatus.timedOut =>
        target.serverIsOptIn
            ? t.coachSettings.lmStudioStartTimeout
            : t.coachSettings.ollamaStartTimeout,
      LocalServerStartStatus.serverNotEnabled =>
        target.serverIsOptIn
            ? t.coachSettings.lmStudioServerOffBody
            : t.coachSettings.ollamaServerOffBody,
      LocalServerStartStatus.failed => t.coachSettings.localServerStartFailed(
        app: target.displayName,
      ),
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StartLocalServerButton(target: target),
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
/// id field when it doesn't, always with a refresh affordance. When exactly one
/// model is discovered and this product has none remembered, it is auto-selected
/// so a one-tap product switch lands ready to chat.
class _ModelPickerRow extends ConsumerWidget {
  const _ModelPickerRow({
    required this.config,
    required this.target,
    required this.manualModelController,
  });

  final CoachConfig config;
  final LocalServerTarget target;
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
            target: target,
          ),
          data: (list) {
            if (list.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    // An empty list means something specific on LM Studio, and
                    // the generic "type one manually" is actively misleading
                    // there: `GET /v1/models` lists only LOADED models when
                    // Just-In-Time loading is off, and with JIT off a
                    // hand-typed id won't be loaded either — so the user would
                    // get "model not found" for a model sitting on their disk.
                    // Name the toggle instead.
                    target.serverIsOptIn
                        ? t.coachSettings.lmStudioNoModelsJit
                        : t.coachSettings.noModelsFound,
                    style: TextStyle(color: colors.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  _ManualModelField(
                    controller: manualModelController,
                    currentModel: config.localModel,
                    target: target,
                  ),
                ],
              );
            }
            final current = config.localModel;
            final hasCurrent = current != null && current.trim().isNotEmpty;
            // Zero-choice case: a single model and nothing remembered here yet →
            // adopt it after this frame so a one-tap switch is ready to chat.
            // Guarded on a re-read so a pick made in the meantime always wins.
            if (!hasCurrent && list.length == 1) {
              final only = list.first.id;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final stored = ref.read(coachConfigProvider).localModel;
                if (stored == null || stored.trim().isEmpty) {
                  ref.read(coachConfigProvider.notifier).setLocalModel(only);
                }
              });
            }
            // Keep a hand-typed model selectable even if the server didn't list
            // it, so switching the base URL never strands the current pick.
            final options = effectiveLocalModelOptions(list, current);
            return EvolveSelect<String>(
              expand: true,
              value: hasCurrent ? current : null,
              options: [
                for (final model in options)
                  EvolveSelectOption(
                    value: model.id,
                    label: model.displayLabel,
                  ),
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
  const _ManualModelField({
    required this.controller,
    required this.currentModel,
    required this.target,
  });

  final TextEditingController controller;
  final String? currentModel;

  /// Supplies the example id. Ollama's `llama3.1:8b` and LM Studio's
  /// publisher-prefixed repo ids look nothing alike, and this field is exactly
  /// where a stuck user lands — so the wrong example is worse than none.
  final LocalServerTarget target;

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
                  hintText: currentModel ?? target.modelHint,
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
              Expanded(
                child: EvolveFieldLabel(t.coachSettings.systemPromptLabel),
              ),
              _ResetSystemPrompt(controller: systemPromptController),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: systemPromptController,
            minLines: 2,
            maxLines: 4,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 13,
              height: 1.4,
            ),
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
  const _MiniIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

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
