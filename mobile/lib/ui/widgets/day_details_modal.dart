import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator, CupertinoButton;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/calendar_days.dart';
import '../../core/theme.dart';
import '../../core/targets_config.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../core/streak_utils.dart';
import '../../core/verification_wiring.dart';
import '../../core/haptics.dart';
import 'habit_management_modal.dart';
import 'target_entry_sheet.dart';
import 'target_ring.dart';
import 'verification_rule_field.dart';
import '../../i18n/translations.g.dart';
import '../kit/evolve_dialog.dart';
import '../kit/evolve_toast.dart';
import '../kit/evolve_button.dart';
import '../kit/evolve_sheet.dart';

/// Whether [date] is a QUICK-LOG day — today or yesterday, the two days a tap
/// on a card changes directly. Any older day is changed through the sheet's
/// explicit Edit → Save flow instead, so a stray tap while browsing history
/// cannot rewrite it, while the days the user is actually living in keep the
/// one-tap check-in.
///
/// Evaluated against the clock at CALL time, never at build time: a sheet left
/// open across midnight would otherwise keep offering the quick path for a day
/// that has since aged out of it. Shared by the card's tap and the
/// freeze-release control, so the two cannot disagree about which days take a
/// direct write.
///
/// [shiftDays], not a fixed 24h step: off a 25-hour fall-back day `subtract`
/// lands at 01:00 of yesterday, and yesterday's own midnight is `isBefore` that
/// — so the day after the autumn transition, yesterday silently lost its quick
/// path.
bool _isQuickLogDay(DateTime date) {
  final now = DateTime.now();
  final yesterday = shiftDays(DateTime(now.year, now.month, now.day), -1);
  return !DateTime(date.year, date.month, date.day).isBefore(yesterday);
}

class DayDetailsModal extends ConsumerStatefulWidget {
  final DateTime date;

  const DayDetailsModal({super.key, required this.date});

  @override
  ConsumerState<DayDetailsModal> createState() => _DayDetailsModalState();
}

class _DayDetailsModalState extends ConsumerState<DayDetailsModal> {
  DateTime get date => widget.date;

  /// Edit mode, for a day older than yesterday. Never entered on a quick-log
  /// day, where the cards write directly and there is nothing to stage.
  bool _editing = false;

  /// The rows changed in edit mode, by habit id, each mapped to the status the
  /// row will be SAVED as (null ⇒ no status). A habit is present only while its
  /// staged value differs from what is persisted, so `isNotEmpty` is "dirty"
  /// and cycling a row back to where it started un-stages it.
  final Map<String, String?> _staged = <String, String?>{};

  /// A quantitative habit's staged NUMBER, by habit id — entered through the
  /// entry sheet in draft mode and written on Save like the rows above. Kept
  /// apart from [_staged] because it is a different write: the verdict is
  /// derived from the number, never set by hand.
  final Map<String, double> _stagedProgress = <String, double>{};

  bool _saving = false;

  bool get _dirty => _staged.isNotEmpty || _stagedProgress.isNotEmpty;

  String _logDateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  TargetVerdict _verdictFor(HabitTarget target, double amount) =>
      evaluateTarget(
        target: target,
        progress: amount,
        periodIsOver: periodIsOver(target.period, date, DateTime.now()),
      );

  /// Enters edit mode. A rebuild alone is enough: the cards read [_staged] and
  /// the header swaps the pencil for Save.
  void _startEditing() {
    ref.hapticAction();
    setState(() => _editing = true);
  }

  /// A tap on a card of an older day while NOT editing. It writes nothing and
  /// says why — a card that looks tappable and silently does nothing is the
  /// defect this replaces, not an improvement on it.
  void _explainEdit() {
    ref.hapticMedium();
    showEvolveToast(
      context,
      message: context.t.habits.tapEditToChangeThisDay,
      kind: EvolveToastKind.error,
    );
    // The header decides at build time whether to show the pencil; a sheet
    // that was opened on "yesterday" and crossed midnight has not rebuilt since,
    // so give it the frame it needs to offer the way in it just named.
    setState(() {});
  }

  void _stage(String habitId, String? persisted, String? next) {
    setState(() {
      if (next == persisted) {
        _staged.remove(habitId);
      } else {
        _staged[habitId] = next;
      }
    });
  }

  void _stageProgress(String habitId, double persisted, double amount) {
    setState(() {
      if (amount == persisted) {
        _stagedProgress.remove(habitId);
      } else {
        _stagedProgress[habitId] = amount;
      }
    });
  }

  /// The X, the barrier and the system back gesture. A dirty sheet asks
  /// first: the staged rows are the user's work, and a mis-tap on the X would
  /// throw all of them away. A clean sheet closes at once — the prompt only
  /// ever appears when there is something to lose.
  Future<void> _requestClose() async {
    if (_editing && _dirty) {
      final discard = await showEvolveConfirm(
        context: context,
        title: context.t.habits.discardChangesTitle,
        message: context.t.habits.discardChangesBody,
        confirmLabel: context.t.habits.discard,
        cancelLabel: context.t.habits.keepEditing,
        isDestructive: true,
        ref: ref,
      );
      if (!discard || !mounted) return;
    }
    if (mounted) Navigator.pop(context);
  }

  /// Commits the staged rows. One row at a time, in list order: each write
  /// recomputes its own streak from the running state, and the failure path
  /// needs to know exactly which rows landed.
  ///
  /// A row that fails stops the batch. Its own write path has already rolled
  /// it back and shown the error, so the sheet simply STAYS in edit mode with
  /// that row and everything after it still staged — a retry is one tap, and
  /// nothing the user did is silently dropped. The rows before it are saved and
  /// stay saved; the streak repair below runs for exactly those.
  Future<void> _save(List<Goal> habits) async {
    if (!_dirty || _saving) return;
    setState(() => _saving = true);
    final notifier = ref.read(habitLogsProvider.notifier);
    final saved = <String>{};
    var failed = false;
    for (final entry in _staged.entries.toList()) {
      final ok = await notifier.setStatus(date, entry.key, entry.value);
      if (!ok) {
        failed = true;
        break;
      }
      saved.add(entry.key);
    }
    if (!failed) {
      final dateKey = _logDateKey(date);
      final targets = {
        for (final h in habits)
          if (_stagedProgress.containsKey(h.id) && h.target != null)
            h.id: h.target!,
      };
      for (final entry in _stagedProgress.entries.toList()) {
        final target = targets[entry.key];
        if (target == null) continue;
        // Derives and writes the day's verdict from the number, as a live edit
        // would; the notifier owns its own rollback and error dialog.
        await ref.read(habitProgressProvider.notifier).setProgress(
              dateKey: dateKey,
              goalId: entry.key,
              amount: entry.value,
              target: target,
            );
        saved.add(entry.key);
      }
      _stagedProgress.clear();
    }
    if (saved.isNotEmpty) {
      // The single-day write cannot fix the rows AFTER an edited day; see
      // [HabitLogsNotifier.recomputeStreaksForHabits].
      await notifier.recomputeStreaksForHabits(saved);
      // A manual check-in on a verified habit creates or clears a freeze, and
      // resolving a day clears its "?": refresh both marker sources, as the
      // quick-log tap does.
      if (habits.any((h) => saved.contains(h.id) && h.isVerified)) {
        ref.invalidate(couldNotVerifyDaysProvider);
        ref.invalidate(manuallyResolvedDaysProvider);
      }
    }
    if (!mounted) return;
    setState(() {
      _staged.removeWhere((id, _) => saved.contains(id));
      _saving = false;
      if (!failed) _editing = false;
    });
    if (!failed) {
      ref.hapticSuccess();
      showEvolveToast(
        context,
        message: context.t.habits.changesSaved,
        kind: EvolveToastKind.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(goalsProvider);
    final logs = ref.watch(habitLogsProvider);
    final progress = TargetsConfig.enabled
        ? ref.watch(habitProgressProvider)
        : const {};
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final dayRecord = logs[dateKey] ?? {};
    final dateMidnight = DateTime(date.year, date.month, date.day);
    // Days an auto-verified habit couldn't be verified (drives the "?" state).
    final couldNotVerifyByGoal =
        ref.watch(couldNotVerifyDaysProvider).asData?.value ?? const {};
    // Days the user's own check-in froze against auto verdicts (D9) — drives
    // the "set by you" marker and its release.
    final manuallyResolvedByGoal =
        ref.watch(manuallyResolvedDaysProvider).asData?.value ?? const {};

    // Habits scheduled on this date (active range AND this weekday). Off-day
    // habits are hidden here, not shown-and-uncompletable.
    final activeHabits = habits.where((h) => h.isScheduledOn(date)).toList();

    // Build-time only for the HEADER (pencil vs. nothing); every tap re-asks
    // the clock. See [_isQuickLogDay].
    final quickLog = _isQuickLogDay(date);

    // The day's logs with the staged rows overlaid — a plain card's staged
    // status, a quantitative card's verdict derived from its staged number —
    // so a card previews the streak it will have once saved rather than the
    // one it has now.
    final effectiveDay = Map<String, String>.from(dayRecord);
    void overlay(String habitId, String? status) {
      if (status == null) {
        effectiveDay.remove(habitId);
      } else {
        effectiveDay[habitId] = status;
      }
    }
    for (final entry in _staged.entries) {
      overlay(entry.key, entry.value);
    }
    for (final entry in _stagedProgress.entries) {
      final target = habits
          .where((h) => h.id == entry.key)
          .firstOrNull
          ?.target;
      if (target == null) continue;
      overlay(entry.key, _verdictFor(target, entry.value).logStatus);
    }
    final HabitLogsMap effectiveLogs =
        _dirty ? {...logs, dateKey: effectiveDay} : logs;

    return PopScope(
      canPop: !(_editing && _dirty),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // The barrier or a system back gesture on a dirty sheet: same question
        // as the X.
        _requestClose();
      },
      child: GestureDetector(
        // Drag-to-dismiss on a modal sheet pops UNCONDITIONALLY
        // (bottom_sheet.dart `onClosing` → `Navigator.pop`), bypassing PopScope,
        // so a dirty sheet has to DECLINE the drag rather than intercept it:
        // claiming the vertical drag here keeps it from the route's own
        // detector, and the X remains the way out. Inert otherwise, so the
        // swipe stays available whenever there is nothing to lose.
        onVerticalDragStart: _editing && _dirty ? (_) {} : null,
        child: Container(
          decoration: BoxDecoration(
            color: context.appColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: context.appColors.border, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: EvolveGrabber()),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat.MMMMd(
                            LocaleSettings.currentLocale.languageCode,
                          ).format(date),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: context.appColors.foreground,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          context.t.habits.yourProgressForToday,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: context.appColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The way into a past day, beside the way out. On a quick-log
                  // day the cards already write directly, and on a day with no
                  // scheduled habit there is nothing to enter.
                  if (!quickLog && activeHabits.isNotEmpty)
                    _editing
                        ? _SavePill(
                            label: context.t.common.actions.save,
                            loading: _saving,
                            onPressed: _dirty && !_saving
                                ? () => _save(habits)
                                : null,
                          )
                        : IconButton(
                            tooltip: context.t.habits.editThisDay,
                            onPressed: _startEditing,
                            icon: Icon(
                              LucideIcons.pencil,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                  IconButton(
                    tooltip: context.t.common.actions.cancel,
                    onPressed: _requestClose,
                    icon: Icon(
                      LucideIcons.x,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: activeHabits.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            Icon(
                              LucideIcons.clipboardList,
                              size: 64,
                              color: context.appColors.mutedForeground
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.t.habits.noHabit,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: context.appColors.foreground,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.t.habits.thereAreNoHabitsForThis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: context.appColors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 24),
                            EvolveButton(
                              label: context.t.habits.createHabit,
                              icon: LucideIcons.plus,
                              expand: false,
                              onPressed: () {
                                Navigator.pop(context); // Close details modal
                                HabitManagementModal.show(context);
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: activeHabits.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final habit = activeHabits[index];
                          final persisted = dayRecord[habit.id];
                          final isStaged = _staged.containsKey(habit.id);
                          final stagedAmount = _stagedProgress[habit.id];

                          // A MANUAL quantitative target: the card shows a
                          // progress ring and opens the entry sheet instead of
                          // cycling a checkbox. Deliberately not
                          // `displayTarget` — a projected verification rule is
                          // measured, its value lives in goal_logs.value not
                          // goal_progress, so its ring would read empty; a
                          // verified habit keeps its checkbox + badge here.
                          final target =
                              TargetsConfig.enabled &&
                                  (habit.target?.isUserEnterable ?? false)
                              ? habit.target
                              : null;
                          final persistedAmount =
                              (progress[dateKey]?[habit.id] as double?) ?? 0;
                          final progressAmount =
                              stagedAmount ?? persistedAmount;
                          final TargetVerdict? verdict = target == null
                              ? null
                              : _verdictFor(target, progressAmount);
                          // What the card SHOWS: a staged status while it has
                          // one; for a staged number, the verdict that number
                          // derives; the persisted status otherwise.
                          final status =
                              stagedAmount != null && verdict != null
                                  ? verdict.logStatus
                                  : isStaged
                                      ? _staged[habit.id]
                                      : persisted;
                          // An unresolved auto-verification for this habit-day:
                          // no terminal status yet + a couldn't-verify marker.
                          final couldNotVerify =
                              status == null &&
                              (couldNotVerifyByGoal[habit.id]?.contains(
                                    dateMidnight,
                                  ) ??
                                  false);

                          // Signed streak via the shared, deterministic helper
                          // (same logic as cloud + Private Mode + the web app),
                          // over the staged overlay so an edit previews its
                          // effect.
                          final streak = computeStreak(
                            habitId: habit.id,
                            date: date,
                            logs: effectiveLogs,
                            startDate: habit.startDate,
                            frequencyDays: habit.frequencyDays,
                          );

                          // The user's check-in owns this day, so reconcile
                          // will skip it until they hand it back. Only where
                          // the rule actually governed the day: before its
                          // effective start there was nothing automatic to
                          // take over from, so "hand it back" would name a
                          // sensor that never scored it. Hidden while the row
                          // is staged — the staged value is about to replace
                          // the state the marker describes.
                          final manuallyResolved =
                              habit.isVerified &&
                              !isStaged &&
                              habit.verificationRuleAppliesOn(date) &&
                              (manuallyResolvedByGoal[habit.id]?.contains(
                                    dateMidnight,
                                  ) ??
                                  false);

                          return GoalLogCard(
                            habit: habit,
                            date: date,
                            status: status,
                            streak: streak,
                            couldNotVerify: couldNotVerify,
                            manuallyResolved: manuallyResolved,
                            onRelease: manuallyResolved
                                ? () {
                                    // The SAME quick-log guard the card's own
                                    // tap applies, re-evaluated against the
                                    // clock right now: a sheet left open across
                                    // 00:00 must not keep the direct path for a
                                    // day that has aged out of it — and this
                                    // release DELETES a goal_logs row.
                                    if (!_isQuickLogDay(date)) {
                                      if (!_editing) {
                                        _explainEdit();
                                        return;
                                      }
                                      // Staged like any other change: on Save
                                      // a null status is exactly a release —
                                      // the verdict goes and the freeze with it.
                                      _stage(habit.id, persisted, null);
                                      return;
                                    }
                                    ref.hapticLight();
                                    ref
                                        .read(habitLogsProvider.notifier)
                                        .releaseToAutoVerification(
                                          date,
                                          habit.id,
                                        );
                                    // Both markers are read from the same store
                                    // and both change on release: the freeze
                                    // goes, and a day that was couldn't-verify
                                    // before the user took it over can
                                    // legitimately come back.
                                    ref.invalidate(manuallyResolvedDaysProvider);
                                    ref.invalidate(couldNotVerifyDaysProvider);
                                  }
                                : null,
                            target: target,
                            verdict: verdict,
                            progressAmount: progressAmount,
                            onTap: () {
                              final quickLog = _isQuickLogDay(date);
                              if (!quickLog && !_editing) {
                                _explainEdit();
                                return;
                              }

                              // A user-enterable target opens the progress
                              // entry sheet (increment / timer). On a quick-log
                              // day it commits live; in edit mode it runs in
                              // draft mode and the number is staged with the
                              // rest of the day, written on Save. A measured
                              // target's ring is filled by the verification
                              // pipeline, so it falls through to the normal
                              // resolve/toggle path.
                              if (target != null && target.isUserEnterable) {
                                TargetEntrySheet.show(
                                  context,
                                  habit: habit,
                                  target: target,
                                  date: date,
                                  initialAmount:
                                      quickLog ? null : progressAmount,
                                  onChanged: quickLog
                                      ? null
                                      : (amount) => _stageProgress(
                                            habit.id,
                                            persistedAmount,
                                            amount,
                                          ),
                                );
                                return;
                              }

                              if (!quickLog) {
                                _stage(
                                  habit.id,
                                  persisted,
                                  nextManualStatus(status),
                                );
                                return;
                              }

                              ref
                                  .read(habitLogsProvider.notifier)
                                  .cycleStatus(date, habit.id);
                              // Manually resolving a verified habit clears its
                              // couldn't-verify marker in the store — refresh
                              // the "?" source so a later un-resolve doesn't
                              // resurrect a stale "?" from the cached provider.
                              //
                              // And refresh the freeze source, because THIS
                              // TAP is what creates the freeze. Without it the
                              // "set by you" marker would not appear until
                              // something else happened to invalidate the
                              // provider — so the very feedback that makes the
                              // freeze visible would arrive too late to connect
                              // it to the tap that caused it.
                              if (habit.isVerified) {
                                ref.invalidate(couldNotVerifyDaysProvider);
                                ref.invalidate(manuallyResolvedDaysProvider);
                              }
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// The header's Save, sized to sit beside the X rather than as a full-width
/// CTA: [EvolveButton]'s padding is a screen-bottom action, and two of those
/// in a title row crowd the date out. Greyed until there is something to save,
/// and a spinner — still filled — while the batch is in flight.
class _SavePill extends StatelessWidget {
  const _SavePill({
    required this.label,
    required this.onPressed,
    required this.loading,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final foreground =
        accent.computeLuminance() > 0.6 ? Colors.black : Colors.white;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: BorderRadius.circular(999),
      color: accent,
      disabledColor: context.appColors.muted,
      // Non-null while loading so the pill stays filled under the spinner; the
      // tap is swallowed.
      onPressed: onPressed == null && !loading
          ? null
          : () {
              if (loading) return;
              onPressed?.call();
            },
      child: loading
          ? SizedBox(
              height: 18,
              width: 18,
              child: CupertinoActivityIndicator(color: foreground, radius: 9),
            )
          : Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: onPressed == null
                    ? context.appColors.mutedForeground
                    : foreground,
              ),
            ),
    );
  }
}

class GoalLogCard extends ConsumerWidget {
  final Goal habit;
  final String? status; // 'done', 'missed', or null
  final int streak;
  final VoidCallback onTap;

  /// The day this card represents. Needed to decide whether the habit's CURRENT
  /// verification rule is the one that governed this day — rule edits apply
  /// forward only, so naming a threshold on an earlier day would misreport it.
  final DateTime date;

  /// True when this is an auto-verified habit whose day couldn't be verified
  /// (D6): renders the "?" resolve affordance in place of the pending circle.
  final bool couldNotVerify;

  /// True when the user's own check-in has taken this verified habit-day over,
  /// freezing it against auto verdicts (D9).
  ///
  /// The freeze is deliberate — without it the next reconcile pass would
  /// overwrite a correction the user made on purpose. What it was missing is
  /// any sign that it happened: cycling a verified habit's status silently
  /// switched Apple Health off for that day, so a habit could sit at `missed`
  /// while the sensor said otherwise and the app simply looked broken.
  final bool manuallyResolved;

  /// Hands the day back to auto-verification. Non-null only when
  /// [manuallyResolved] — it is the release half of the marker, so the user does
  /// not have to discover that a third tap on the row means "let Apple Health
  /// decide again".
  final VoidCallback? onRelease;

  /// The habit's display target (own manual, or a projected rule). When set,
  /// the leading slot shows a progress ring + count instead of the status icon.
  final HabitTarget? target;
  final TargetVerdict? verdict;
  final double progressAmount;

  const GoalLogCard({
    super.key,
    required this.habit,
    required this.status,
    required this.streak,
    required this.onTap,
    required this.date,
    this.couldNotVerify = false,
    this.manuallyResolved = false,
    this.onRelease,
    this.target,
    this.verdict,
    this.progressAmount = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    Color cardColor = context.appColors.card;
    Color borderColor = context.appColors.border;
    Color textColor = context.appColors.foreground;
    Color iconBgColor = context.appColors.muted;
    IconData icon = LucideIcons.circle;
    Color iconColor = context.appColors.mutedForeground;
    bool hasStrikethrough = false;

    if (status == 'done') {
      cardColor = context.appColors.success.withValues(alpha: 0.15);
      borderColor = context.appColors.success.withValues(alpha: 0.4);
      textColor = context.appColors.success;
      iconBgColor = context.appColors.success.withValues(alpha: 0.2);
      iconColor = context.appColors.success;
      icon = LucideIcons.check;
    } else if (status == 'missed') {
      cardColor = const Color(
        0xFF450A0A,
      ).withValues(alpha: 0.2); // Very dark red
      borderColor = const Color(0xFFEF4444).withValues(alpha: 0.4);
      textColor = context.appColors.mutedForeground;
      iconBgColor = const Color(0xFF450A0A).withValues(alpha: 0.4);
      iconColor = const Color(0xFFEF4444);
      icon = LucideIcons.x;
      hasStrikethrough = true;
    } else if (couldNotVerify) {
      // Actionable "?" state — subtle primary tint (like an editable cell).
      cardColor = primary.withValues(alpha: 0.06);
      borderColor = primary.withValues(alpha: 0.3);
      iconBgColor = primary.withValues(alpha: 0.12);
      iconColor = primary;
    }

    // For a target habit the spoken status is the progress ("40 of 80"); the
    // ring carries the visual state, so the card's own colour stays neutral
    // while pending.
    final a11yStatus = target != null
        ? '${formatTargetAmount(progressAmount)} / '
              '${formatTargetAmount(target!.amount)}'
              '${targetUnitShortLabel(context.t, target!.unit).isEmpty ? '' : ' ${targetUnitShortLabel(context.t, target!.unit)}'}'
        : status == 'done'
        ? context.t.a11y.statusDone
        : status == 'missed'
        ? context.t.a11y.statusMissed
        : couldNotVerify
        ? context.t.verification.couldNotVerifyTapToResolve
        : context.t.a11y.statusPending;

    // The marker only makes sense where the freeze does: on a verified habit,
    // and only when a release is actually wired up. A habit whose rule was
    // removed reads as manual now — there is nothing for Apple Health to take
    // back, so claiming otherwise would be a lie.
    final showManualMarker =
        habit.isVerified && manuallyResolved && onRelease != null;

    // Whether the verification line gives up its rule for the resolve prompt.
    // ONE predicate drives both the visible line and the spoken label — they
    // desynced when only the widget was narrowed, so a hybrid card showed the
    // rule on screen while VoiceOver said nothing about it.
    final lineShowsPrompt = couldNotVerify && target == null;
    final ruleInEffect = habit.verificationRuleAppliesOn(date);

    // The card excludes its children's semantics, so the verification line is
    // silent unless spoken here. The generic "auto-verified" word leads, because
    // the shield icon carries that meaning visually and a bare "≥ 30 min" has no
    // context read aloud. Skipped when the line is the prompt — [a11yStatus] is
    // then already that prompt, and the line would only repeat it. On a day that
    // predates a rule edit the threshold is omitted for the same reason the
    // visible line omits it: it would name a rule this day was not judged
    // against.
    final a11yVerification = !habit.isVerified || lineShowsPrompt
        ? ''
        : ruleInEffect
        ? ', ${context.t.verification.autoVerified}, '
              '${habitVerificationLabel(context.t, conditions: habit.verificationConditions, join: habit.verificationJoin, habitTitle: habit.title)}'
        : ', ${context.t.verification.autoVerified}';

    // The freeze, spoken. The card sets `excludeSemantics`, so the chip below is
    // invisible to VoiceOver no matter how it is built — its meaning has to be
    // carried here or not at all. Stated as a consequence ("will not change this
    // day"), because "set by you" alone does not explain why the habit has
    // stopped moving, which is the whole question the marker exists to answer.
    final a11yManual = showManualMarker
        ? ', ${context.t.verification.manualOverrideHint(app: context.t.health.appName)}'
        : '';

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '${habit.title}, $a11yStatus$a11yVerification$a11yManual',
      hint: context.t.a11y.toggleHint,
      // The release as a rotor action rather than a reachable button, for the
      // same reason: the excluded subtree cannot expose one. This is the only
      // route by which a VoiceOver user can hand the day back without cycling
      // the status twice more and hoping.
      customSemanticsActions: showManualMarker
          ? {
              CustomSemanticsAction(
                label: context.t.verification.manualReleaseToAuto(
                  app: context.t.health.appName,
                ),
              ): onRelease!,
            }
          : const {},
      child: GestureDetector(
        onTap: () {
          ref.hapticLight();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              if (target != null && verdict != null)
                TargetRing(
                  target: target!,
                  verdict: verdict!,
                  size: 44,
                  strokeWidth: 4,
                  accent: habit.color,
                  child: Text(
                    formatTargetAmount(progressAmount),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: textColor,
                    ),
                  ),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: couldNotVerify
                      ? Text(
                          '?',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: iconColor,
                            height: 1,
                          ),
                        )
                      : Icon(icon, color: iconColor, size: 20),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The name owns the whole of row 1. It used to share it with
                    // an auto-verified pill, which took its intrinsic width and
                    // left the name breaking mid-word; the marker now lives on
                    // row 2 (see [VerificationLine]). Two lines of budget, then
                    // an ellipsis — the app doesn't clamp Dynamic Type, so 17pt
                    // can render far larger than this.
                    Text(
                      habit.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        decoration: hasStrikethrough
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: const Color(
                          0xFFEF4444,
                        ).withValues(alpha: 0.5),
                        decorationThickness: 2,
                      ),
                    ),
                    // A habit can be BOTH auto-verified and carry a manual
                    // target — the two are orthogonal (see `displayTargetFor`),
                    // and while mobile's tracking-mode picker keeps them
                    // exclusive, the macOS editor writes a target without
                    // clearing the rule. So these are separate `if`s, not a
                    // chain: the progress readout must never be swallowed by the
                    // verification line.
                    if (target != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${formatTargetAmount(progressAmount)} / '
                        '${formatTargetAmount(target!.amount)}'
                        '${targetUnitShortLabel(context.t, target!.unit).isEmpty ? '' : ' ${targetUnitShortLabel(context.t, target!.unit)}'}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: context.appColors.mutedForeground,
                        ),
                      ),
                    ],
                    if (habit.isVerified) ...[
                      const SizedBox(height: 2),
                      VerificationLine(
                        conditions: habit.verificationConditions,
                        join: habit.verificationJoin,
                        habitTitle: habit.title,
                        ruleInEffect: ruleInEffect,
                        // With a target present the leading slot is the ring and
                        // the tap opens the entry sheet, which cannot resolve a
                        // verification — so the "tap to fix it" prompt would be a
                        // lie. Show the rule instead.
                        couldNotVerify: lineShowsPrompt,
                      ),
                    ] else if (lineShowsPrompt) ...[
                      // A marker left behind after its rule was removed: the
                      // habit reads as manual now, so there is no rule to show
                      // beside the prompt, but the day is still resolvable. Kept
                      // to one ellipsized line like [VerificationLine] — the long
                      // string wrapped to three rows here and made the card jump.
                      const SizedBox(height: 2),
                      Text(
                        context.t.verification.couldNotVerifyShort,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: context.appColors.mutedForeground,
                        ),
                      ),
                    ],
                    // The freeze, made visible and undoable. Its own row rather
                    // than folded into [VerificationLine]: that line states the
                    // RULE, and this states that the rule is not being applied
                    // to this day — putting them in one line would read as a
                    // qualification of the rule instead of a contradiction of it.
                    if (showManualMarker) ...[
                      const SizedBox(height: 4),
                      _ManualOverrideChip(onRelease: onRelease!),
                    ],
                  ],
                ),
              ),
              StreakBadge(
                streak: streak,
                isMissed: status == 'missed',
                isDone: status == 'done',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "set by you" marker on a frozen verified habit-day, and its release.
///
/// Marker and control in one element on purpose. Two would have been a label
/// that explains the state next to a button that undoes it, which is more
/// chrome on a row that is otherwise a single tap target — and the release only
/// ever applies when the marker is showing, so nothing is lost by fusing them.
///
/// Its own [GestureDetector] wins the tap over the card's, so releasing the day
/// cannot be mistaken for cycling it. That matters: the card's tap is what
/// created the freeze in the first place, and an undo that advanced the cycle
/// instead would be the same trap one step along.
class _ManualOverrideChip extends StatelessWidget {
  const _ManualOverrideChip({required this.onRelease});

  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final app = context.t.health.appName;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onRelease,
      // 44pt is the HIG minimum, and here it is a safety margin rather than a
      // guideline: the control DIRECTLY BELOW this strip is the card's own tap
      // target, which cycles the status — so a near-miss on "hand this day back"
      // would instead flip done→missed AND re-freeze it. The text is 12pt; the
      // padding is what makes the target real.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          // WRAP, not Row, and that is the fix rather than a tidy-up.
          //
          // A Row here cannot degrade safely. With both halves `Flexible` the
          // ACTIONABLE label ellipsized as readily as the inert one; with
          // `flex: 0` on the inert half it was worse — `flex: 0` is INFLEXIBLE,
          // so "Set by you" took its full intrinsic width and the action
          // collapsed to ZERO, leaving a 44pt tap target that still worked and
          // no longer said anything. At accessibility text sizes neither half
          // fits alone, so no pair of flex values rescues it.
          //
          // Wrapping lets the action move to a second line instead of vanishing.
          // Vertical growth is safe: the sheet scrolls, and the 44pt constraint
          // above is a floor, not a height.
          child: Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.userPen,
                      size: 12, color: colors.mutedForeground),
                  const SizedBox(width: 4),
                  // Flexible INSIDE each group, Wrap BETWEEN them. The Wrap
                  // moves the action to its own line; this keeps a single line
                  // from overflowing once it has one to itself. Ellipsis is the
                  // last resort rather than the first, which is the whole
                  // difference from the Row this replaced.
                  Flexible(
                    child: Text(
                      context.t.verification.manualSetByYou,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: colors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.rotateCcw,
                    size: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      context.t.verification.manualReleaseToAuto(app: app),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StreakBadge extends StatelessWidget {
  final int streak;
  final bool isMissed;
  final bool isDone;

  const StreakBadge({
    super.key,
    required this.streak,
    this.isMissed = false,
    this.isDone = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = context.appColors.muted;
    Color textColor = context.appColors.mutedForeground;
    IconData icon = LucideIcons.flame;
    Color iconColor = const Color(0xFFF97316); // Orange

    if (isMissed) {
      bgColor = const Color(0xFF450A0A).withValues(alpha: 0.5);
      textColor = const Color(0xFFEF4444);
      icon = LucideIcons.heartCrack;
      iconColor = const Color(0xFFEF4444);
    } else if (isDone) {
      bgColor = context.appColors.success.withValues(alpha: 0.2);
      textColor = context.appColors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
