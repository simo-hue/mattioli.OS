import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../core/app_logger.dart';
import '../../core/haptics.dart';
import '../../core/targets_config.dart';
import '../../core/verification_config.dart';
import '../../core/verification_providers.dart';
import 'compound_conditions_field.dart';
import 'target_field.dart';
import 'target_ring.dart';
import 'verification_rule_field.dart';
import '../../core/time_formatting.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../providers/settings_provider.dart';
import '../screens/subscription_screen.dart';
import '../../i18n/translations.g.dart';
import '../kit/evolve_color_picker.dart';
import '../kit/evolve_dialog.dart';
import '../kit/evolve_button.dart';
import '../kit/evolve_section_header.dart';
import '../kit/evolve_sheet.dart';
import '../kit/evolve_spinner.dart';
import '../kit/evolve_toast.dart';
import '../kit/evolve_segmented_control.dart';
import '../kit/evolve_weekday_selector.dart';

/// The single tracking class a habit belongs to. Mutually exclusive — a habit
/// is exactly one of these, never a manual number AND an auto-verified rule at
/// once. [checkbox] is a plain done/not-done habit; [number] carries a
/// quantitative target; [automatic] carries a verification rule.
enum HabitTrackingMode { checkbox, number, automatic }

/// Localized label for a tracking-mode segment.
String _trackingModeLabel(Translations t, HabitTrackingMode mode) =>
    switch (mode) {
      HabitTrackingMode.checkbox => t.targets.trackingMode.checkbox,
      HabitTrackingMode.number => t.targets.trackingMode.number,
      HabitTrackingMode.automatic => t.targets.trackingMode.automatic,
    };

/// Read-only indicator shown in place of the tracking-mode picker when the
/// habit's true class is disabled by a local feature flag — a habit synced from
/// a device where that class is enabled. Mirrors desktop's locked Automatic row:
/// the class is displayed but not editable, so no tappable segment exists to
/// silently clear the synced target or verification rule on save.
class _LockedClassRow extends StatelessWidget {
  const _LockedClassRow({required this.mode});

  final HabitTrackingMode mode;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = context.t;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: colors.mutedForeground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _trackingModeLabel(t, mode),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.targets.trackingMode.locked,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HabitManagementModal extends ConsumerStatefulWidget {
  const HabitManagementModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HabitManagementModal(),
    );
  }

  @override
  ConsumerState<HabitManagementModal> createState() =>
      _HabitManagementModalState();
}

class _HabitManagementModalState extends ConsumerState<HabitManagementModal> {
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Color _selectedColor;
  Goal? _editingHabit;
  String? _reminderTime;
  VerificationRule? _verificationRule;

  /// Compound verifiable habit (Q1–Q5): the 2nd/3rd conditions and how they
  /// combine. Empty ⇒ an ordinary single-metric habit. Only meaningful when
  /// [_verificationRule] is a HealthKit rule and compound is enabled.
  List<VerificationRule> _additionalConditions = [];
  VerificationJoin _verificationJoin = VerificationJoin.or;

  /// Quantitative target (count / duration / limit), or null for a plain
  /// checkbox habit. Only surfaced when [TargetsConfig.enabled].
  HabitTarget? _target;

  /// The mutually-exclusive tracking class the form is currently editing. Kept
  /// in lock-step with [_target] / [_verificationRule]: choosing a class clears
  /// the others' state (see [_onTrackingModeChanged]), so the two fields can
  /// never both be set. Derived from the persisted state on edit; Checkbox on a
  /// fresh form.
  late HabitTrackingMode _trackingMode;

  /// Weekly-schedule selection (ISO 1=Mon…7=Sun). Defaults to every day; an
  /// all-7 selection is persisted as `null` (every-day) via
  /// [Goal.canonicalFrequencyDays]. Never empty — the picker enforces ≥1 day.
  List<int> _selectedDays = const [1, 2, 3, 4, 5, 6, 7];
  static const List<int> _everyDay = [1, 2, 3, 4, 5, 6, 7];

  /// Draft Mode-A (`screen_time_apps`) selection, held transiently until save
  /// (the create-flow goalId isn't final until then). Persisted device-local,
  /// keyed by the FINAL goalId — never part of Goal.
  ScreenTimeSelectionEntry? _appsSelection;

  /// Inline error for the verification block (20-activity cap / missing
  /// selection), separate from the name field's [_nameError].
  String? _verifyError;

  /// Inline validation message for the name field (null = valid). Drives the red
  /// border + helper text.
  String? _nameError;

  /// True while the name still holds a template-derived default (so switching
  /// the metric can update it, but a name the user typed is never overwritten).
  bool _nameAutoFilled = false;

  /// True while a save is in flight. The form is only reset once the write
  /// returns, so without this both entry points (the button and the name
  /// field's keyboard Done action) can re-enter `_onSave` on the still-filled
  /// controller and mint a second habit with a fresh id.
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedColor = kEvolveDefaultPalette[0];
    // A fresh form has neither a target nor a rule → the Checkbox class.
    _trackingMode = HabitTrackingMode.checkbox;
  }

  /// The tracking classes offered, in display order. Checkbox is always
  /// available; Number and Automatic appear only when their feature flag is on.
  /// When only Checkbox is enabled the picker is hidden entirely — the form
  /// keeps its unchanged plain-habit layout.
  List<HabitTrackingMode> get _enabledModes => [
        HabitTrackingMode.checkbox,
        if (TargetsConfig.enabled) HabitTrackingMode.number,
        if (VerificationConfig.enabled) HabitTrackingMode.automatic,
      ];

  /// Classifies a habit's persisted state into its mutually-exclusive tracking
  /// class: a verification rule wins over a target, which wins over a plain
  /// checkbox (mutual exclusion means at most one is ever set).
  static HabitTrackingMode _modeFor({
    required VerificationRule? verificationRule,
    required HabitTarget? target,
  }) {
    if (verificationRule != null) return HabitTrackingMode.automatic;
    if (target != null) return HabitTrackingMode.number;
    return HabitTrackingMode.checkbox;
  }

  /// Switching tracking class is mutually exclusive: clear the OTHER classes'
  /// state and seed a sensible default for the chosen one, so the form never
  /// carries a half-set number AND rule at once.
  void _onTrackingModeChanged(HabitTrackingMode mode) {
    setState(() {
      _trackingMode = mode;
      switch (mode) {
        case HabitTrackingMode.checkbox:
          // A plain habit: neither a number nor a rule.
          _target = null;
          _verificationRule = null;
          _additionalConditions = [];
          _verificationJoin = VerificationJoin.or;
          _appsSelection = null;
          _verifyError = null;
        case HabitTrackingMode.number:
          // A manual number: drop any verification and seed a count target so
          // the field is never empty (the picker's Checkbox segment IS "none").
          _verificationRule = null;
          _additionalConditions = [];
          _verificationJoin = VerificationJoin.or;
          _appsSelection = null;
          _verifyError = null;
          _target ??= TargetPresetCatalog.countDaily.targetWith();
        case HabitTrackingMode.automatic:
          // An auto-verified rule: drop the number and seed the first available
          // template so the rule field renders usable — it hides when null.
          _target = null;
          if (_verificationRule == null) {
            final tpls = _availableTemplates;
            if (tpls.isNotEmpty) {
              _verificationRule =
                  tpls.first.ruleWith(tpls.first.defaultThreshold);
              // Offer the metric's label as a default name, matching the old
              // inline Auto-verify switch (which routed through
              // VerificationRuleField.onChanged) — the seed path bypasses that
              // handler, so replicate its auto-fill here. Only while the name is
              // empty or still an untouched auto-fill, so a typed name survives.
              if (_nameController.text.trim().isEmpty || _nameAutoFilled) {
                _nameController.text = verificationTemplateLabel(
                    context.t, _verificationRule!.metricKey);
                _nameAutoFilled = true;
                _nameError = null;
              }
            }
          }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Default to accent color if not editing
    if (_editingHabit == null) {
      _selectedColor = Theme.of(context).colorScheme.primary;
    }
  }

  Future<void> _onSave() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();
    // Required-field validation: show an inline red-bordered error instead of a
    // silent no-op. (Auto-verified habits pre-fill the name from their metric,
    // so they rarely reach this.)
    if (name.isEmpty) {
      ref.hapticMedium();
      setState(() => _nameError = context.t.habits.nameRequired);
      // Reveal the name field (it may be scrolled above the Add button) so the
      // red error is actually seen.
      if (_scrollController.hasClients) {
        unawaited(_scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ));
      }
      return;
    }

    // Quantitative targets: blocking issues stop the save with the reason
    // already visible inline under the fields; warnings are legal but odd, so
    // they get one confirmation rather than passing silently. The sheet only
    // appears when something is genuinely off — a normal habit never sees it.
    final target = _target;
    if (target != null && TargetsConfig.enabled) {
      final preset = TargetPresetCatalog.forTarget(target);
      if (preset != null) {
        final issues = validateHabitTarget(
          preset: preset,
          amount: target.amount,
          step: target.step,
        );
        if (issues.any((i) => i.isBlocking)) {
          ref.hapticMedium();
          return;
        }
        // Only ASK about warnings the user is actually introducing. A habit
        // whose target legitimately warns — and whose warning was accepted once
        // — must not re-prompt on every later rename, recolour or schedule
        // tweak. Full equality on purpose, not scoring-meaning: the divisibility
        // and tap-count warnings depend on `step`, so a step-only edit CAN
        // change which warnings apply and does deserve a fresh prompt.
        final targetUnchanged = _editingHabit?.target == target;
        if (issues.isNotEmpty && !targetUnchanged) {
          final unit = targetUnitShortLabel(context.t, target.unit);
          final proceed = await showEvolveConfirm(
            context: context,
            ref: ref,
            title: context.t.targets.confirmTitle,
            message: [
              for (final issue in issues)
                targetIssueMessage(context.t, issue,
                    amount: target.amount, unit: unit),
            ].join('\n\n'),
            cancelLabel: context.t.targets.confirmAdjust,
            confirmLabel: context.t.targets.confirmSaveAnyway,
          );
          if (!mounted || !proceed) return;
        }
      }
    }

    final isEditing = _editingHabit != null;
    final successMessage = isEditing
        ? context.t.habits.habitUpdated
        : context.t.habits.habitAdded;

    // Screen Time guards — run for create AND manual→screen-time edits.
    final savingScreenTime = _verificationRule?.isScreenTime ?? false;
    if (savingScreenTime) {
      // Mode A can't verify without a picked selection.
      if (_isAppsRule && _appsSelection == null) {
        ref.hapticMedium();
        setState(() => _verifyError =
            context.t.verification.screenTime.needsSelectionNote);
        return;
      }
      // Apple caps DeviceActivity at 20 simultaneous activities (D10). Count the
      // existing screen-time goals, excluding the one being edited.
      final existingScreenTime = ref
          .read(goalsProvider)
          .where((g) =>
              g.verificationRule?.isScreenTime == true &&
              g.id != _editingHabit?.id)
          .length;
      if (existingScreenTime >= 20) {
        ref.hapticMedium();
        setState(() => _verifyError =
            context.t.verification.screenTime.tooManyMonitors);
        return;
      }
    }

    // HealthKit guards — trigger the proactive prompt if not already shown.
    // If the user rejects the prompt, they can fix it later in Settings, as Apple HealthKit
    // doesn't let apps know if permission was denied.
    if (_showGrantHealthAccess) {
      await _grantHealthAccess();
      if (!mounted) return;
    }

    if (!isEditing) {
      final settings = ref.read(settingsProvider);
      final isPro = settings.isPro;
      final currentHabitsCount = ref.read(goalsProvider).length;

      if (!isPro && currentHabitsCount >= 5) {
        FocusScope.of(context).unfocus();
        ref.hapticHeavy();
        Navigator.pop(context); // Close the habit management sheet
        unawaited(
          Navigator.push(
            context,
            SubscriptionScreen.route(),
          ),
        ); // Redirect to payment!
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _verifyError = null;
    });
    final bool ok;
    Goal? createdGoal;
    try {
      // All-7 collapses to null (every-day) — the canonical shared encoding.
      final frequencyDays = Goal.canonicalFrequencyDays(_selectedDays);
      // A compound habit needs a HealthKit primary and ≥1 extra condition (Q2).
      // Otherwise persist as an ordinary single rule (or manual).
      final hasCompound = _verificationRule != null &&
          _verificationRule!.isHealthKit &&
          _additionalConditions.isNotEmpty;
      // A target this build can't decode (a newer-client target) reads as
      // _target == null and classifies as Checkbox — NOT the locked row, since
      // Checkbox is always enabled. Passing clearTarget:true on an unrelated edit
      // (rename/schedule) would wipe its rawTargetBlob and strip the newer
      // client's target for good, defeating the forward-compat guard. Preserve
      // the blob unless the user actually moved off a target (set a real target,
      // or switched to Automatic).
      final keepsUnreadableTarget = isEditing &&
          _target == null &&
          _verificationRule == null &&
          hasUnreadableTarget(_editingHabit!.rawTargetBlob);
      if (isEditing) {
        final updated = _editingHabit!.copyWith(
          title: name,
          color: _selectedColor,
          reminderTime: _reminderTime,
          clearReminderTime: _reminderTime == null,
          frequencyDays: frequencyDays,
          clearFrequency: frequencyDays == null,
          verificationRule: _verificationRule,
          clearVerificationRule: _verificationRule == null,
          additionalConditions: hasCompound ? _additionalConditions : null,
          clearAdditionalConditions: !hasCompound,
          verificationJoin: hasCompound ? _verificationJoin : null,
          clearVerificationJoin: !hasCompound,
          target: _target,
          clearTarget: _target == null && !keepsUnreadableTarget,
        );
        ok = await ref.read(goalsProvider.notifier).updateHabit(updated);
      } else {
        final newHabit = Goal(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: name,
          description: '',
          icon: 'circle',
          color: _selectedColor,
          frequencyDays: frequencyDays,
          startDate: DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
          reminderTime: _reminderTime,
          verificationRule: _verificationRule,
          additionalConditions: hasCompound ? _additionalConditions : null,
          verificationJoin: hasCompound ? _verificationJoin : null,
          target: _target,
        );
        // addHabit returns the PERSISTED goal (its id is the server UUID in
        // cloud mode, not the throwaway temp id above).
        createdGoal = await ref.read(goalsProvider.notifier).addHabit(newHabit);
        ok = createdGoal != null;
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      } else {
        _isSaving = false;
      }
    }

    // On failure the provider already surfaced its own error modal + rolled the
    // optimistic add back, so we neither reset the form nor confirm success.
    if (!ok || !mounted) return;

    // Commit / clean up the Mode-A selection now the FINAL goalId is known.
    // Keying by the persisted id (not the create-time temp id) is what makes a
    // Mode-A habit actually verifiable in cloud mode.
    if (VerificationConfig.screenTimeEnabled) {
      final goalId = isEditing ? _editingHabit!.id : createdGoal!.id;
      final selections = ref.read(screenTimeSelectionsProvider.notifier);
      final sel = _appsSelection;
      if (_isAppsRule && sel != null) {
        await selections.setSelection(goalId, sel);
      } else if (isEditing) {
        // Rule switched away from screen_time_apps (or cleared) → drop the blob.
        await selections.remove(goalId);
      }
    }

    if (!mounted) return; // selection writes above are async gaps

    _nameController.clear();
    setState(() {
      _editingHabit = null;
      _selectedColor = kEvolveDefaultPalette[0];
      _reminderTime = null;
      _selectedDays = _everyDay;
      _verificationRule = null;
      _additionalConditions = [];
      _verificationJoin = VerificationJoin.or;
      _target = null;
      _appsSelection = null;
      _verifyError = null;
      _nameError = null;
      _nameAutoFilled = false;
      _trackingMode = HabitTrackingMode.checkbox;
    });
    ref.hapticMedium();
    showEvolveToast(
      context,
      message: successMessage,
      kind: EvolveToastKind.success,
    );
  }

  void _onEdit(Goal habit) {
    setState(() {
      _editingHabit = habit;
      _nameController.text = habit.title;
      _selectedColor = habit.color;
      _reminderTime = habit.reminderTime;
      // null/empty frequencyDays means "every day" → all chips selected.
      final freq = habit.frequencyDays;
      _selectedDays = (freq == null || freq.isEmpty)
          ? _everyDay
          : (List<int>.from(freq)..sort());
      _verificationRule = habit.verificationRule;
      _additionalConditions =
          List<VerificationRule>.from(habit.additionalConditions ?? const []);
      _verificationJoin = habit.verificationJoin ?? VerificationJoin.or;
      _target = habit.target;
      // Mode A: rehydrate the picked selection from the device-local store. If
      // it isn't resolvable here (e.g. synced from another device), leave it
      // null so the habit reads as couldn't-verify until re-picked — never a
      // silent pass.
      _appsSelection = habit.verificationRule?.metricKey == 'screen_time_apps'
          ? ref.read(screenTimeSelectionsProvider)[habit.id]
          : null;
      _verifyError = null;
      _nameError = null;
      _nameAutoFilled = false; // the loaded title is the user's real name
      // Pick the class from what the habit actually carries (rule → automatic,
      // target → number, else checkbox).
      _trackingMode = _modeFor(
        verificationRule: habit.verificationRule,
        target: habit.target,
      );
    });
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  /// The verification templates to offer — only those whose provider/mode is
  /// enabled. Screen Time is gated per template so Mode A (`screen_time_apps`)
  /// can ship live while Mode B (`screen_time_total`) stays dark.
  List<VerificationTemplate> get _availableTemplates => [
        for (final t in VerificationCatalog.all)
          if (_templateEnabled(t)) t,
      ];

  bool _templateEnabled(VerificationTemplate t) {
    if (t.isHealthKit) return VerificationConfig.healthKitEnabled;
    return switch (t.key) {
      'screen_time_apps' => VerificationConfig.screenTimeAppsEnabled,
      'screen_time_total' => VerificationConfig.screenTimeTotalEnabled,
      _ => false,
    };
  }

  /// Whether the current draft rule is the Mode-A (picked-apps) template.
  bool get _isAppsRule => _verificationRule?.metricKey == 'screen_time_apps';

  /// Whether the current draft rule is ANY Screen Time template (Mode A or B).
  bool get _isScreenTimeRule => _verificationRule?.isScreenTime ?? false;

  /// Presents the native FamilyActivityPicker (Mode A). Requests FamilyControls
  /// authorization first (the picker needs it to render), stores the returned
  /// selection in the transient draft, and rejects an empty pick (it can't be
  /// monitored, so it must not masquerade as "watch everything").
  Future<void> _pickAppsAndCategories() async {
    final tr = context.t; // capture before async gaps
    final bridge = ref.read(screenTimeBridgeProvider);
    ref.hapticMedium();
    var status = await bridge.authorizationStatus();
    if (status != ScreenTimeAuthorizationStatus.approved) {
      // `denied` means the user actively declined or iOS revoked the
      // authorization. Re-requesting on `denied` throws a PlatformException
      // (FamilyControls only allows one `.individual` holder per device). Direct
      // the user to iOS Settings instead of re-requesting and catching the
      // exception.
      if (status == ScreenTimeAuthorizationStatus.denied) {
        AppLogger.warning('[ScreenTime] authorization denied — directing to Settings');
        if (!mounted) return;
        setState(() =>
            _verifyError = tr.verification.screenTime.statusNotAuthorized);
        return;
      }
      // `notDetermined` — first-time prompt. Safe to request.
      try {
        await bridge.requestIndividualAuthorization();
      } on PlatformException catch (e) {
        // FamilyControls grants individual authorization to only ONE app per
        // device at a time (and also throws on denial). Surface a friendly
        // inline message instead of an unhandled exception — a review device may
        // already hold the slot, and a crash here reads as a Screen Time (2.1)
        // failure.
        AppLogger.warning('[ScreenTime] authorization request failed: ${e.message}');
        if (!mounted) return;
        setState(() =>
            _verifyError = tr.verification.screenTime.authorizationUnavailable);
        return;
      }
      ref.invalidate(screenTimeAuthStatusProvider);
      // The request can return without granting (declined / still
      // notDetermined); don't try to present the picker (it would fail) — ask
      // the user to enable access first.
      status = await bridge.authorizationStatus();
      if (!mounted) return;
      if (status != ScreenTimeAuthorizationStatus.approved) {
        setState(() =>
            _verifyError = tr.verification.screenTime.authorizationUnavailable);
        return;
      }
    }
    final result = await bridge.presentActivityPicker(
      initialSelectionBlob: _appsSelection?.blob,
      pickerTitle: tr.verification.screenTime.chooseApps,
      doneLabel: tr.common.actions.done,
      cancelLabel: tr.common.actions.cancel,
    );
    if (!mounted || result == null) return; // cancelled / unavailable
    if (result.isEmpty) {
      setState(() {
        _appsSelection = null;
        _verifyError = tr.verification.screenTime.selectionEmpty;
      });
      return;
    }
    setState(() {
      _appsSelection = ScreenTimeSelectionEntry(
        blob: result.blob,
        applicationCount: result.applicationCount,
        categoryCount: result.categoryCount,
      );
      _verifyError = null;
    });
  }

  Future<void> _grantHealthAccess() async {
    final rule = _verificationRule;
    if (rule == null || !rule.isHealthKit) return;
    final typeId = rule.template?.healthKitTypeIdentifier ?? rule.metricKey;
    ref.hapticMedium();
    await ref.read(healthKitBridgeProvider).requestAuthorization({typeId});
    // iOS can't report read-grant, so treat "prompt shown" as done: remember it
    // so the button disappears for this metric from now on.
    await ref
        .read(healthAuthRequestedTypesProvider.notifier)
        .markRequested(typeId);
  }

  /// Whether to show the proactive "Grant Health access" button: only for a
  /// HealthKit rule whose metric hasn't been requested yet.
  bool get _showGrantHealthAccess {
    final rule = _verificationRule;
    if (rule == null || !rule.isHealthKit) return false;
    final typeId = rule.template?.healthKitTypeIdentifier ?? rule.metricKey;
    return !ref.watch(healthAuthRequestedTypesProvider).contains(typeId);
  }

  void _showCupertinoTimePicker() {
    final settings = ref.read(settingsProvider);
    final use24hFormat = settings.timeFormat24h;

    TimeOfDay initialTime = const TimeOfDay(hour: 9, minute: 0);
    if (_reminderTime != null) {
      initialTime = AppTimeFormatting.parseTimeOfDay(_reminderTime!);
    }

    final now = DateTime.now();
    DateTime initialDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      initialTime.hour,
      initialTime.minute,
    );

    showEvolveFormSheet<void>(
      context: context,
      title: context.t.habits.reminder,
      leading: EvolveTextAction(
        label: context.t.common.actions.cancel,
        onPressed: () => Navigator.pop(context),
      ),
      trailing: EvolveTextAction(
        label: context.t.common.actions.confirm,
        emphasized: true,
        onPressed: () {
          final timeStr = AppTimeFormatting.serializeDateTime(
            initialDateTime,
          );
          setState(() => _reminderTime = timeStr);
          Navigator.pop(context);
        },
      ),
      builder: (sheetContext) => SizedBox(
        height: 216,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          initialDateTime: initialDateTime,
          use24hFormat: use24hFormat,
          onDateTimeChanged: (DateTime newDateTime) {
            initialDateTime = newDateTime;
          },
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(Goal habit) async {
    final confirmed = await showEvolveConfirm(
      context: context,
      title: context.t.habits.deleteHabit,
      message: '${context.t.habits.areYouSureYouWantTo} "${habit.title}"?',
      confirmLabel: context.t.common.actions.delete,
      isDestructive: true,
      ref: ref,
    );
    if (confirmed) {
      unawaited(ref.read(goalsProvider.notifier).deleteHabit(habit.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final habits = ref.watch(goalsProvider).where((g) => g.isActiveOn(now)).toList();
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final settings = ref.watch(settingsProvider);
    final isPro = settings.isPro;
    final currentHabitsCount = habits.length;
    // A habit's true class isn't offered here when it was authored on a device
    // where that class's flag is on but is off on this build (a mixed-version
    // fleet). Show it as a LOCKED read-only row rather than a mislabelled picker,
    // so tapping a fallback segment can't silently clear the synced target/rule —
    // mirroring desktop's locked Automatic row. activeMode then falls back to
    // Checkbox purely so the by-mode field guards render nothing editable; the
    // synced _target/_verificationRule stay in state and round-trip on save.
    final classLocked = !_enabledModes.contains(_trackingMode);
    final activeMode =
        classLocked ? HabitTrackingMode.checkbox : _trackingMode;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 20),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const EvolveGrabber(),
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    Text(
                      context.t.habits.manageHabits,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.appColors.foreground,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        LucideIcons.x,
                        color: context.appColors.mutedForeground,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                Text(
                  context.t.habits.dragToReorder,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: context.appColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),

                // Add/Edit Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.appColors.card.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.appColors.border,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: context.appColors.border.withValues(
                                alpha: 0.3,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.plus,
                              size: 14,
                              color: context.appColors.foreground,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _editingHabit != null
                                ? context.t.habits.editHabit
                                : context.t.habits.addHabit,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: context.appColors.foreground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      EvolveSectionHeader(
                        context.t.habits.habitName,
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        textInputAction: TextInputAction.done,
                        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                        onChanged: (_) {
                          // The user is now the author of the name; stop
                          // auto-updating it from the metric, and clear any
                          // pending validation error as they type.
                          _nameAutoFilled = false;
                          if (_nameError != null) {
                            setState(() => _nameError = null);
                          }
                        },
                        onSubmitted: (_) => unawaited(_onSave()),
                        style: TextStyle(
                          color: context.appColors.foreground,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: context.t.habits.eGDrinkWaterRead,
                          hintStyle: TextStyle(
                            color: context.appColors.mutedForeground.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          filled: true,
                          fillColor: context.appColors.background.withValues(
                            alpha: 0.5,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          // Inline validation: a red rounded border + message
                          // when the name is missing.
                          errorText: _nameError,
                          errorStyle: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.appColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.error,
                              width: 1.5,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.error,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      EvolveSectionHeader(
                        context.t.habits.color,
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 10),
                      EvolveColorSwatchGrid(
                        selected: _selectedColor,
                        onChanged: (color) =>
                            setState(() => _selectedColor = color),
                      ),
                      const SizedBox(height: 16),
                      EvolveSectionHeader(
                        context.t.habits.weeklyFrequency,
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 10),
                      EvolveWeekdaySelector(
                        selectedDays: _selectedDays,
                        onChanged: (days) =>
                            setState(() => _selectedDays = days),
                      ),
                      const SizedBox(height: 16),
                      EvolveSectionHeader(
                        context.t.habits.reminder,
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _showCupertinoTimePicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: context.appColors.background.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.appColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _reminderTime != null
                                    ? AppTimeFormatting.formatStoredTime(
                                        _reminderTime!,
                                        use24hFormat: settings.timeFormat24h,
                                      )
                                    : context.t.common.none,
                                style: TextStyle(
                                  color: _reminderTime != null
                                      ? context.appColors.foreground
                                      : context.appColors.mutedForeground,
                                  fontSize: 15,
                                ),
                              ),
                              if (_reminderTime != null)
                                IconButton(
                                  icon: Icon(
                                    LucideIcons.x,
                                    size: 16,
                                    color: context.appColors.mutedForeground,
                                  ),
                                  onPressed: () =>
                                      setState(() => _reminderTime = null),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                )
                              else
                                Icon(
                                  LucideIcons.bell,
                                  size: 16,
                                  color: context.appColors.mutedForeground,
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Tracking-mode picker: a habit is exactly one class — a
                      // plain Checkbox, a manual Number, or an Automatic
                      // (auto-verified) rule. Mutually exclusive, so choosing one
                      // clears the others. Shown only when more than one class is
                      // enabled; with just Checkbox there is nothing to pick, so
                      // the plain-habit layout is unchanged. A synced habit whose
                      // class is disabled here shows a LOCKED read-only row instead
                      // — no tappable segment, so its target/rule can't be wiped.
                      if (classLocked) ...[
                        const SizedBox(height: 16),
                        EvolveSectionHeader(
                          context.t.targets.trackingMode.title,
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 10),
                        _LockedClassRow(mode: _trackingMode),
                      ] else if (_enabledModes.length > 1) ...[
                        const SizedBox(height: 16),
                        EvolveSectionHeader(
                          context.t.targets.trackingMode.title,
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 10),
                        EvolveSegmentedControl<HabitTrackingMode>(
                          groupValue: activeMode,
                          segments: {
                            for (final m in _enabledModes)
                              m: _trackingModeLabel(context.t, m),
                          },
                          onValueChanged: _onTrackingModeChanged,
                        ),
                      ],
                      // Number class — a quantitative target (count / duration /
                      // limit). No "Simple" chip: the picker's Checkbox segment
                      // already is the no-target choice, so Number always carries
                      // a numeric preset.
                      if (activeMode == HabitTrackingMode.number &&
                          TargetsConfig.enabled) ...[
                        const SizedBox(height: 16),
                        TargetField(
                          target: _target,
                          showNone: false,
                          onChanged: (t) => setState(() => _target = t),
                        ),
                      ],
                      // Automatic class — an auto-verified rule (D5) plus its
                      // compound conditions and provider-authorization
                      // affordances. Rendered only when the feature is enabled;
                      // dark otherwise.
                      if (activeMode == HabitTrackingMode.automatic &&
                          VerificationConfig.enabled) ...[
                        const SizedBox(height: 16),
                        VerificationRuleField(
                          rule: _verificationRule,
                          templates: _availableTemplates,
                          showSwitch: false,
                          onChanged: (r) {
                            final prevKey = _verificationRule?.metricKey;
                            setState(() {
                              _verificationRule = r;
                              // A stale selection must not leak onto a different
                              // metric (or a cleared rule).
                              if (r?.metricKey != 'screen_time_apps') {
                                _appsSelection = null;
                              }
                              // Compound conditions need a HealthKit primary (Q2):
                              // drop them if the rule is cleared or becomes Screen
                              // Time, and de-dupe if the new metric now collides
                              // with an existing condition.
                              if (r == null || !r.isHealthKit) {
                                _additionalConditions = [];
                                _verificationJoin = VerificationJoin.or;
                              } else {
                                _additionalConditions = _additionalConditions
                                    .where((c) => c.metricKey != r.metricKey)
                                    .toList();
                              }
                              _verifyError = null;
                              // Offer the metric's label as a default name when
                              // the metric changes — but only while the field is
                              // empty or still holds an untouched auto-fill, so a
                              // name the user typed is never overwritten.
                              if (r != null && r.metricKey != prevKey) {
                                if (_nameController.text.trim().isEmpty ||
                                    _nameAutoFilled) {
                                  _nameController.text =
                                      verificationTemplateLabel(
                                          context.t, r.metricKey);
                                  _nameAutoFilled = true;
                                  _nameError = null;
                                }
                              }
                            });
                          },
                        ),
                        // Compound verifiable habits (Q1–Q5): combine 2–3
                        // HealthKit conditions with OR/AND. Only for a HealthKit
                        // primary rule; gated behind the dark-launch flag, and the
                        // "+ Add condition" affordance is Pro-gated inside.
                        if (VerificationConfig.compoundVerificationEnabled &&
                            _verificationRule != null &&
                            _verificationRule!.isHealthKit)
                          CompoundConditionsField(
                            primaryRule: _verificationRule!,
                            additionalConditions: _additionalConditions,
                            join: _verificationJoin,
                            isPro: isPro,
                            onConditionsChanged: (c) =>
                                setState(() => _additionalConditions = c),
                            onJoinChanged: (j) =>
                                setState(() => _verificationJoin = j),
                            onNeedPro: () {
                              FocusScope.of(context).unfocus();
                              Navigator.push(
                                  context, SubscriptionScreen.route());
                            },
                          ),
                        // Proactive "grant Health access" affordance (D9) for
                        // HealthKit rules — requests read access up front instead
                        // of waiting to infer denial from couldn't-verify days.
                        // Hidden once this metric's permission has been requested.
                        if (_showGrantHealthAccess) ...[
                          const SizedBox(height: 8),
                          EvolveButton(
                            label: context.t.verification.grantHealthAccess,
                            style: EvolveButtonStyle.secondary,
                            onPressed: _grantHealthAccess,
                          ),
                        ],
                        // Screen Time authorization status badge — shown for
                        // all Screen Time templates so the user sees upfront
                        // whether they can proceed.
                        if (_isScreenTimeRule) ...[
                          const SizedBox(height: 10),
                          _ScreenTimeAuthBadge(
                            status: ref.watch(screenTimeAuthStatusProvider),
                          ),
                        ],
                        // Mode A — pick which apps/categories this habit limits.
                        // A selection is required for the habit to verify.
                        if (_isAppsRule) ...[
                          const SizedBox(height: 8),
                          EvolveButton(
                            label: _appsSelection == null
                                ? context.t.verification.screenTime.chooseApps
                                : context
                                    .t.verification.screenTime.changeSelection,
                            style: EvolveButtonStyle.secondary,
                            onPressed: _pickAppsAndCategories,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _appsSelection == null
                                ? context
                                    .t.verification.screenTime.needsSelectionNote
                                : context.t.verification.screenTime
                                    .selectionSummary(
                                    count: _appsSelection!.totalCount,
                                  ),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appColors.mutedForeground,
                            ),
                          ),
                        ],
                        if (_verifyError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _verifyError!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                      if (_editingHabit != null)
                        Row(
                          children: [
                            Expanded(
                              child: EvolveButton(
                                label: context.t.common.actions.cancel,
                                style: EvolveButtonStyle.secondary,
                                onPressed: () => setState(() {
                                  _editingHabit = null;
                                  _nameController.clear();
                                  _reminderTime = null;
                                  _selectedDays = _everyDay;
                                  _verificationRule = null;
                                  _additionalConditions = [];
                                  _verificationJoin = VerificationJoin.or;
                                  _target = null;
                                  _appsSelection = null;
                                  _verifyError = null;
                                  _nameError = null;
                                  _nameAutoFilled = false;
                                  _trackingMode = HabitTrackingMode.checkbox;
                                }),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: EvolveButton(
                                label: context.t.habits.update,
                                loading: _isSaving,
                                onPressed: _onSave,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        if (!isPro && currentHabitsCount >= 5) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFEAB308,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFFEAB308,
                                ).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.lock,
                                  color: Color(0xFFEAB308),
                                  size: 16,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    context.t.habits.freeSlotsFullBanner(
                                      used: currentHabitsCount,
                                      limit: 5,
                                    ),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0xFFEAB308),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              // Tap is swallowed rather than disabled while the
                              // save is in flight so the button keeps its filled
                              // accent under the spinner, as EvolveButton does
                              // for its own `loading` state.
                              if (_isSaving) return;
                              if (!isPro && currentHabitsCount >= 5) {
                                ref.hapticHeavy();
                                Navigator.pop(
                                  context,
                                ); // Close the habit management sheet
                                Navigator.push(
                                  context,
                                  SubscriptionScreen.route(),
                                ); // Redirect to payment!
                              } else {
                                _onSave();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  (!isPro && currentHabitsCount >= 5)
                                  ? const Color(0xFFEAB308)
                                  : Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  (!isPro && currentHabitsCount >= 5)
                                  ? Colors.black
                                  : (_selectedColor.computeLuminance() > 0.5
                                        ? Colors.black
                                        : Colors.white),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isSaving
                                ? EvolveSpinner(
                                    color:
                                        Theme.of(context).colorScheme.primary
                                                    .computeLuminance() >
                                                0.5
                                            ? Colors.black
                                            : Colors.white,
                                    radius: 10,
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (!isPro && currentHabitsCount >= 5) ...[
                                        const Icon(
                                          LucideIcons.sparkles,
                                          size: 16,
                                          color: Colors.black,
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        (!isPro && currentHabitsCount >= 5)
                                            ? context.t.common.unlockEvolvePro
                                            : context.t.habits.addHabit,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w700,
                                          color:
                                              (!isPro && currentHabitsCount >= 5)
                                                  ? Colors.black
                                                  : (Theme.of(context)
                                                                  .colorScheme
                                                                  .primary
                                                                  .computeLuminance() >
                                                              0.5
                                                          ? Colors.black
                                                          : Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Habits List Section Header
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    context.t.common.habits,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          SliverReorderableList(
            itemCount: habits.length,
            onReorderItem: (oldIndex, newIndex) {
              ref.read(goalsProvider.notifier).reorder(oldIndex, newIndex);
              ref.hapticLight();
            },
            itemBuilder: (context, index) {
              final habit = habits[index];
              return _HabitListItem(
                key: ValueKey(habit.id),
                index: index,
                habit: habit,
                onEdit: () => _onEdit(habit),
                onDelete: () => unawaited(_showDeleteConfirmation(habit)),
              );
            },
          ),
          // Extra space at bottom
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _HabitListItem extends StatelessWidget {
  final int index;
  final Goal habit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HabitListItem({
    super.key,
    required this.index,
    required this.habit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Icon(
                LucideIcons.gripVertical,
                size: 16,
                color: context.appColors.mutedForeground,
              ),
            ),
          ),

          const SizedBox(width: 12),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: habit.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: habit.color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  habit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Auto-verified habits carry their indicator on a quiet second
                // line (plain icon + muted text, no pill) so the name keeps the
                // full row-1 width instead of collapsing into it. Shares
                // [VerificationLine] with the day card, so the rule a habit is
                // measured against is worded identically wherever it appears.
                if (habit.isVerified) ...[
                  const SizedBox(height: 2),
                  VerificationLine(
                    conditions: habit.verificationConditions,
                    join: habit.verificationJoin,
                    habitTitle: habit.title,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: Icon(
              LucideIcons.pencil,
              size: 16,
              color: context.appColors.mutedForeground,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              LucideIcons.trash2,
              size: 16,
              color: AppColors.destructive,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline authorization status badge for Screen Time habits — renders a compact
/// container with ✅ "on" or ⚠️ "needs to be enabled" plus an action button
/// that opens iOS Settings for recovery. Watches [screenTimeAuthStatusProvider]
/// reactively so it updates when the user returns from Settings.
class _ScreenTimeAuthBadge extends StatelessWidget {
  const _ScreenTimeAuthBadge({required this.status});

  final AsyncValue<ScreenTimeAuthorizationStatus> status;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tr = context.t.verification.screenTime;

    return status.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (s) {
        final isApproved = s == ScreenTimeAuthorizationStatus.approved;

        final badgeColor = isApproved
            ? AppColors.success.withValues(alpha: 0.12)
            : const Color(0xFFEAB308).withValues(alpha: 0.12);
        final borderColor = isApproved
            ? AppColors.success.withValues(alpha: 0.3)
            : const Color(0xFFEAB308).withValues(alpha: 0.3);
        final iconColor = isApproved
            ? AppColors.success
            : const Color(0xFFEAB308);
        final icon = isApproved
            ? LucideIcons.shieldCheck
            : LucideIcons.shieldAlert;
        final label = isApproved
            ? tr.statusAuthorized
            : tr.statusNotAuthorized;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: colors.foreground,
                  ),
                ),
              ),
              if (!isApproved) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => openAppSettings(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.foreground.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tr.openSettings,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
