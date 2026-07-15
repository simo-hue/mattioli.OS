import 'dart:async';

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
/// 4. **Periodic** — a coarse 15-minute pull. With CloudKit push deferred,
///    this is how a Mac that sits open-and-idle learns about iPhone edits.
///
/// (Trigger #5, the manual "Sync now" button, lives in the settings UI.)
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
  static const _periodicInterval = Duration(minutes: 15);

  late final SyncWriteDebouncer _writeDebouncer;
  late final AppLifecycleListener _lifecycle;
  Timer? _periodic;

  @override
  void initState() {
    super.initState();
    _writeDebouncer = SyncWriteDebouncer(onFlush: _sync);
    DesktopPrivateDb.onPrivateWrite = _onPrivateWrite;
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChanged);
    _periodic = Timer.periodic(_periodicInterval, (_) => unawaited(_sync()));
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_sync()));
  }

  @override
  void dispose() {
    if (identical(DesktopPrivateDb.onPrivateWrite, _onPrivateWrite)) {
      DesktopPrivateDb.onPrivateWrite = null;
    }
    _writeDebouncer.dispose();
    _lifecycle.dispose();
    _periodic?.cancel();
    super.dispose();
  }

  void _onPrivateWrite() {
    if (_isPrivateMode) _writeDebouncer.notifyWrite();
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_sync());
  }

  bool get _isPrivateMode =>
      ref.read(activeDesktopDataModeProvider) == DesktopDataMode.private;

  Future<void> _sync() async {
    if (!mounted || !_isPrivateMode) return;
    try {
      final status =
          await ref.read(desktopPrivateSyncServiceProvider).syncNow();
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
      // triggers (window refocus, the 15-min timer, the post-frame launch sync)
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
