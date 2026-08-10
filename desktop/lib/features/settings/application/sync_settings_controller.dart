import 'dart:async';
import 'dart:io';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_sync_service.dart';
import 'package:evolve_desktop/features/auth/application/desktop_profile_controller.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/statistics/data/private_analytics_source.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Everything the iCloud sync card and the Advanced pane's sync report read.
///
/// These were `_syncStatus` / `_syncDiagnostics` / `_syncBusy` on
/// `_SettingsPageState`, which is why every sync flow had to be a method on that
/// same class — and why the Data & Backup pane had to be handed two
/// already-rendered strings instead of reading the state it displays.
///
/// No `==`/`hashCode`, for the same reason `SettingsFormState` has none: the old
/// code rebuilt unconditionally through `setState`, and a value-equal state
/// object would start skipping notifications — a different behaviour than the
/// one the tests were written against.
@immutable
class SyncSettingsState {
  const SyncSettingsState({this.status, this.diagnostics, this.busy = false});

  /// Null until the first [SyncSettingsController.refreshStatus] answers, and
  /// on every platform/mode where the card does not apply.
  final PrivateSyncStatus? status;

  /// What has and has not actually reached CloudKit. Null while loading, or
  /// when there is no local store to inspect.
  final SyncDiagnostics? diagnostics;

  /// True while an enable/disable/sync action is in flight; drives the
  /// "Syncing…" label and disables the controls.
  final bool busy;

  bool get isEnabled => status?.isEnabled ?? false;
  bool get keyPending => status?.keyPending ?? false;
  int get undecryptableCount => status?.undecryptableCount ?? 0;

  /// One-line status under the enable toggle.
  ///
  /// Derived state, not a rendering decision: it needs no BuildContext, only the
  /// three fields above, so it belongs beside them rather than being computed on
  /// the page and passed down as a finished string.
  String get statusLabel {
    final status = this.status;
    if (busy) return t.icloudSync.statusSyncing;
    if (status == null || !status.isEnabled) return t.icloudSync.statusOff;
    if (status.account == CloudAccountStatus.noAccount) {
      return t.icloudSync.statusNoAccount;
    }
    if (status.account != CloudAccountStatus.available) {
      return t.icloudSync.statusUnavailable;
    }
    if (status.keyPending) {
      return t.icloudSync.statusWaitingKey;
    }
    // A key split is never "Up to date": syncing runs, reports success and
    // applies nothing, which is exactly how it stayed invisible for weeks.
    //
    // The headline moved to the warning banner above this row, which also
    // carries the remedy. This line stays a STATUS — repeating the banner's
    // title three lines below it read as a rendering bug.
    if (status.undecryptableCount > 0) {
      return t.icloudSync.statusNotSynced;
    }
    if (!status.hasKey) {
      // Enabled + iCloud fine, but the E2E key hasn't arrived through iCloud
      // Keychain — typically an iPhone app that predates the shared keychain
      // group. The copy nudges the fix.
      return t.icloudSync.statusWaitingKeychain;
    }
    // "Up to date" is a claim about the DATA, not about the account, and it may
    // only be made when [SyncDiagnostics.isFullySynced] licenses it. Reaching
    // this line used to be enough: a device with thousands of rows that had
    // never left it, and a `last_full_sync_at` stamped moments ago by a push in
    // which every record failed, rendered exactly the same "Up to date" as a
    // healthy one. The per-count breakdown is on the details row below; the
    // headline's job is simply never to lie.
    final diagnostics = this.diagnostics;
    if (diagnostics != null && !diagnostics.isFullySynced) {
      return t.icloudSync.statusNotSynced;
    }
    return t.icloudSync.statusIdle;
  }

  SyncSettingsState copyWith({PrivateSyncStatus? status, bool? busy}) {
    return SyncSettingsState(
      status: status ?? this.status,
      diagnostics: diagnostics,
      busy: busy ?? this.busy,
    );
  }

  /// Its own setter rather than a `copyWith` parameter: a null diagnostics read
  /// is MEANINGFUL — "there is no local store to inspect" — and a `??` fallback
  /// would silently keep the previous snapshot and go on rendering the details
  /// row for a store that is no longer there.
  SyncSettingsState withDiagnostics(SyncDiagnostics? value) =>
      SyncSettingsState(status: status, diagnostics: value, busy: busy);
}

/// Owns the iCloud sync card's state and the async work behind it.
///
/// Kept alive and scoped by [hydrate] / [detach], exactly like
/// `SettingsFormController`: `autoDispose` schedules its disposal on a
/// zero-duration Timer that is still pending when a widget test tears down right
/// after unmounting the page.
///
/// Deliberately holds NO dialogs. Enabling sync asks for consent first and may
/// then offer "start fresh"; resetting from this device confirms and then
/// toasts. Those sequences are driven by the Data & Backup pane, which has the
/// BuildContext — this class only performs the steps.
final syncSettingsControllerProvider =
    NotifierProvider<SyncSettingsController, SyncSettingsState>(
      SyncSettingsController.new,
    );

class SyncSettingsController extends Notifier<SyncSettingsState> {
  /// Whether a settings page is currently on screen. The stand-in for
  /// `_SettingsPageState.mounted`: every `setState` these flows used to make was
  /// gated on it.
  bool _attached = false;

  /// Identifies WHICH page visit owns [_attached].
  ///
  /// The shell cross-fades sections, so a re-entered SettingsPage mounts and
  /// hydrates BEFORE the outgoing one disposes; without an identity the
  /// outgoing [detach] would clear the flag out from under the live page, and
  /// the very next sync action would leave [busy] true forever — the "toggle
  /// permanently dead" state [hydrate] exists to prevent.
  int _attachToken = 0;

  @override
  SyncSettingsState build() => const SyncSettingsState();

  /// The page has mounted: forget the previous visit and re-read the status.
  ///
  /// The reset is what a fresh `State` gave for free, and it is not cosmetic:
  /// an action still in flight when the page went away leaves [busy] true, and
  /// a controller that outlives the page would come back with the toggle
  /// permanently dead.
  ///
  /// One microtask late because `initState` runs inside the build phase, and
  /// Riverpod refuses to let a provider be modified there.
  ///
  /// Returns the token identifying this visit; the page hands it straight back
  /// to [detach] when it leaves.
  int hydrate() {
    _attached = true;
    scheduleMicrotask(() {
      if (!_attached) return;
      state = const SyncSettingsState();
      unawaited(refreshStatus());
    });
    return ++_attachToken;
  }

  /// The page has left the screen. Mirrors what `!mounted` used to shut off.
  ///
  /// Ignored unless [token] is the visit that is actually on screen: an
  /// outgoing page disposes AFTER its replacement has hydrated, and a blind
  /// clear here would detach the live one.
  void detach(int token) {
    if (token == _attachToken) _attached = false;
  }

  Future<void> refreshStatus() async {
    if (!Platform.isMacOS) return;
    if (!ref.read(activeDesktopDataModeProvider).isPrivate) return;
    final status = await ref.read(desktopPrivateSyncServiceProvider).status();
    if (!_attached) return;
    state = state.copyWith(status: status);
    await refreshDiagnostics();
  }

  /// Read the pending/errored counts. Never allowed to throw: the settings page
  /// must still render if the private DB cannot be opened, which is one of the
  /// states a user comes here to diagnose.
  Future<void> refreshDiagnostics() async {
    if (!_attached) return;
    try {
      final d = await ref.read(desktopPrivateSyncServiceProvider).diagnostics();
      if (!_attached) return;
      state = state.withDiagnostics(d);
    } catch (error, stack) {
      AppLogger.error('iCloud sync diagnostics failed', error, stack);
    }
  }

  /// Turns sync on. Never forces on the first attempt: `enable()` DEFERS rather
  /// than minting a rival key when the zone already holds data this Mac has no
  /// key for, which is what leaves [SyncSettingsState.keyPending] set for the
  /// caller to act on.
  Future<void> enable({bool force = false}) =>
      _runSyncAction((service) => service.enable(force: force));

  Future<void> disable() => _runSyncAction((service) => service.disable());

  Future<void> syncNow() async {
    final status = state.status;
    if (state.busy ||
        status == null ||
        !status.isEnabled ||
        !status.isAvailable) {
      return;
    }
    await _runSyncAction((service) => service.syncNow());
  }

  Future<void> resetSyncFromThisDevice() =>
      _runSyncAction((service) => service.resetSyncFromThisDevice());

  Future<void> _runSyncAction(
    Future<PrivateSyncStatus> Function(PrivateSyncService service) action,
  ) async {
    if (state.busy) return;
    state = state.copyWith(busy: true);
    try {
      final status = await action(ref.read(desktopPrivateSyncServiceProvider));
      if (!_attached) return;
      state = state.copyWith(status: status);
      // A pull writes straight to the encrypted DB — refresh the UI providers.
      if (status.appliedChanges > 0) {
        unawaited(ref.read(dashboardControllerProvider.notifier).refresh());
        ref.invalidate(privateAnalyticsDataProvider);
        ref.invalidate(privateProfileProvider);
        ref.invalidate(desktopGoalCategoriesControllerProvider);
      }
    } catch (error, stack) {
      AppLogger.error('iCloud sync action failed', error, stack);
      await refreshStatus(); // reflect the real state after a failure
    } finally {
      if (_attached) state = state.copyWith(busy: false);
    }
  }
}
