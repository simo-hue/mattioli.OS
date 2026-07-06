import 'dart:async';

/// Coalesces bursts of local private-mode writes into one deferred sync.
///
/// The app's write paths call [notifyWrite] after every private mutation; the
/// debouncer restarts a quiet-period timer, and once writes stop for [delay]
/// it invokes [onFlush] (typically `service.syncNow()`) exactly once.
///
/// Loop safety, per the mobile plan: hook the WRITE METHODS of the private
/// store — never provider rebuilds, and never the sync engine's own applies
/// (pulled records are written through `SyncLocalStore.applyUpsert`, which
/// bypasses the app write paths entirely) — so a pull can never re-trigger a
/// push through this class.
///
/// [onFlush] errors are swallowed: the sync service already logs its failures,
/// dirty rows stay dirty, and the next trigger (foreground, periodic, manual,
/// or the next write) retries naturally.
class SyncWriteDebouncer {
  SyncWriteDebouncer({
    required this.onFlush,
    this.delay = const Duration(seconds: 3),
  });

  final Future<void> Function() onFlush;
  final Duration delay;

  Timer? _timer;
  bool _disposed = false;

  /// True while a flush is scheduled (mainly for tests/diagnostics).
  bool get isPending => _timer?.isActive ?? false;

  /// Signal that a private write just happened; (re)starts the quiet timer.
  void notifyWrite() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(delay, () {
      unawaited(onFlush().catchError((_) {}));
    });
  }

  /// Cancel any scheduled flush and stop accepting notifications.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
