import 'dart:async';

import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_logger.dart';
import 'desktop_data_mode.dart';
import 'desktop_private_db.dart';
import 'desktop_private_sync_service.dart';
import 'private_data_refresh.dart';

/// Hosts the automatic iCloud-sync triggers for the desktop app. Wraps the
/// widget tree once (from `EvolveDesktopApp`'s builder) and owns:
///
/// 1. **Launch** — one sync shortly after startup.
/// 2. **Window refocus** — `AppLifecycleListener` fires `resumed` whenever the
///    app regains focus (a Mac's closest analogue to mobile's foreground).
/// 3. **After-write** — private-mode mutations funnel through
///    [DesktopPrivateDb.onPrivateWrite] and coalesce into one sync a few quiet
///    seconds after the last edit ([SyncWriteDebouncer]).
/// 4. **Periodic** — a 60-second pull. In practice this is THE sync path: the
///    push subscription below registers but has never been observed to deliver
///    on either device, so this timer sets the latency the user actually
///    experiences.
/// 5. **CloudKit zone-change push** — a silent push from a
///    `CKDatabaseSubscription`. Wired and registered, delivery unconfirmed.
///
/// (Trigger #6, the manual "Sync now" button, lives in the settings UI.)
///
/// Every path funnels through [_sync], which is gated to Private mode; the
/// service itself additionally no-ops when sync is disabled, the platform
/// isn't macOS, or iCloud is unavailable — so the triggers are always safe to
/// fire.
class DesktopSyncLifecycle extends ConsumerStatefulWidget {
  const DesktopSyncLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DesktopSyncLifecycle> createState() =>
      _DesktopSyncLifecycleState();
}

class _DesktopSyncLifecycleState extends ConsumerState<DesktopSyncLifecycle> {
  /// How often an open, focused window polls for another device's edits.
  ///
  /// 60 seconds. Push is registered but has never once been observed to deliver,
  /// so in practice this timer IS the sync — it is not a backstop. Sizing it as
  /// though push works would mean shipping the latency the user actually
  /// experiences rather than the one the design assumes.
  ///
  /// Was 15 minutes, then 3. Without CloudKit push subscriptions this timer is
  /// the ONLY way a Mac that already has focus learns about an iPhone edit —
  /// window-refocus only fires if you actually switch away and back, so a user
  /// sitting in front of the app could wait a quarter of an hour for a settings
  /// change to appear. That reads as "sync is broken" long before it reads as
  /// "sync is slow".
  ///
  /// The cost is more CloudKit round-trips; each is a delta fetch that returns
  /// nothing when idle, so for a zone this size it is negligible. Push now
  /// handles the common case, but this stays as the backstop — Apple does not
  /// guarantee silent-push delivery, so removing it would trade certain
  /// convergence for likely convergence.
  static const _periodicInterval = Duration(seconds: 60);

  late final SyncWriteDebouncer _writeDebouncer;
  late final AppLifecycleListener _lifecycle;
  Timer? _periodic;

  @override
  void initState() {
    super.initState();
    _writeDebouncer = SyncWriteDebouncer(onFlush: () => _sync(reason: 'write'));
    DesktopPrivateDb.onPrivateWrite = _onPrivateWrite;
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChanged);
    _periodic =
        Timer.periodic(_periodicInterval, (_) => unawaited(_sync(reason: 'poll')));
    // CloudKit zone-change push. Routes into the SAME sync as every other
    // trigger — push changes only WHEN sync runs, never what it does. Left
    // wired despite never having been observed to fire: it costs nothing when
    // silent, and the timer above is what actually guarantees convergence.
    MethodChannelCloudKitBridge.setRemoteChangeHandler(
      () => unawaited(_sync(reason: 'push')),
      // Native-side APNs events: the only way an "this device has no push
      // token" state becomes visible in an exported log.
      onNativeLog: (level, message) => level == 'error'
          ? AppLogger.error(message, 'native')
          : AppLogger.info(message),
    );
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_sync(reason: 'launch')));
  }

  @override
  void dispose() {
    if (identical(DesktopPrivateDb.onPrivateWrite, _onPrivateWrite)) {
      DesktopPrivateDb.onPrivateWrite = null;
    }
    _writeDebouncer.dispose();
    _lifecycle.dispose();
    _periodic?.cancel();
    MethodChannelCloudKitBridge.clearRemoteChangeHandler();
    super.dispose();
  }

  void _onPrivateWrite() {
    if (_isPrivateMode) _writeDebouncer.notifyWrite();
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_sync(reason: 'refocus'));
  }

  bool get _isPrivateMode =>
      ref.read(activeDesktopDataModeProvider) == DesktopDataMode.private;

  Future<void> _sync({String reason = 'unknown'}) async {
    if (!mounted || !_isPrivateMode) return;
    try {
      final status =
          await ref.read(desktopPrivateSyncServiceProvider).syncNow(reason: reason);
      // The engine writes pulled records straight to the encrypted DB, bypassing
      // the controllers — refresh the same full private surface the manual
      // "Sync now" and notification-write paths refresh (incl. profile +
      // categories), so a cross-device profile/category edit shows up too.
      if (mounted && status.appliedChanges > 0) {
        refreshPrivateAfterPull(
            ProviderScope.containerOf(context, listen: false));
      }
    } on PrivateDatabaseLockedException {
      // The encrypted Private DB is in the recoverable *locked* state (its file
      // exists but the SQLCipher key is unreadable — a fresh machine, or a
      // code-signing change that rotated the Keychain access group). Recovering
      // it belongs to [PrivateModeGate], which offers reset / iCloud-restore /
      // import; the mode is still `private` while that screen is up, so these
      // triggers (window refocus, the periodic timer, the post-frame launch sync)
      // keep firing. They run fire-and-forget via `unawaited`, so an uncaught
      // throw here becomes an UNHANDLED zone exception and crashes the app.
      // Swallow it quietly and let the gate drive recovery.
    } catch (error, stack) {
      // Automatic sync is best-effort: a transient CloudKit / network / store
      // failure must never crash the app for the same fire-and-forget reason.
      AppLogger.warning('[DesktopSync] automatic sync failed', error, stack);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
