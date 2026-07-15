import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/app_logger.dart';
import '../../core/private_local_database.dart'; // privateLocalDatabaseProvider
import '../../core/private_mode_recovery.dart';
import '../../core/private_sync_service.dart'; // privateSyncServiceProvider
import '../../core/theme.dart';
import '../../i18n/translations.g.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shared_prefs_provider.dart';
import '../../providers/sync_refresh.dart'; // invalidatePrivateDataProviders, refreshSyncEnabled
import '../kit/evolve_button.dart';
import '../kit/evolve_dialog.dart'; // showEvolveConfirm
import '../kit/evolve_toast.dart';

/// Ensures the encrypted Private DB is open before showing [child] (the home
/// dashboard). Transparently recovers a LOCKED DB from iCloud when it's safe,
/// and offers an explicit recovery choice when it isn't — instead of dead-ending
/// on the old "private mode start" error. Wraps the home route in Private mode
/// so it covers BOTH the fresh "continue privately" entry and the startup
/// restore of a previous Private session. Mirrors desktop's `PrivateModeGate`.
class PrivateModeGate extends ConsumerStatefulWidget {
  const PrivateModeGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PrivateModeGate> createState() => _PrivateModeGateState();
}

class _PrivateModeGateState extends ConsumerState<PrivateModeGate> {
  PrivateRecoveryResult? _result;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    final store = ref.read(privateLocalDatabaseProvider);
    final sync = ref.read(privateSyncServiceProvider);
    final result = await openOrRecoverPrivate(store: store, sync: sync);
    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
    });
    if (result.status != PrivateRecoveryStatus.ready) return;
    if (result.restoredFromCloud) {
      invalidatePrivateDataProviders(ref);
      showEvolveToast(
        context,
        message: context.t.privateRecovery.restoredFromCloudToast,
        kind: EvolveToastKind.neutral,
      );
    } else {
      // Normal Private-mode open — offer iCloud sync once (off by default), so
      // the CloudKit-as-source-of-truth recovery actually protects this user.
      await _maybePromptSync();
    }
  }

  /// One-time, opt-in prompt to enable end-to-end-encrypted iCloud sync the
  /// first time a user reaches Private mode on a device where sync CAN work
  /// (iCloud available, not already on). Reuses the existing E2E disclosure copy.
  static const _syncPromptKey = 'private_sync_onboarding_shown_v1';

  Future<void> _maybePromptSync() async {
    // Runs fire-and-forget from _run (itself launched in initState). probe() and
    // enable() reach the Keychain / CloudKit and can throw; a throw here would
    // become an unhandled async error at the global handler. Contain it — the
    // one-time onboarding prompt must never crash entry into Private mode.
    try {
      final prefs = ref.read(sharedPrefsProvider);
      if (prefs.getBool(_syncPromptKey) ?? false) return;
      final sync = ref.read(privateSyncServiceProvider);
      final probe = await sync.probe();
      if (!mounted) return;
      if (probe.isEnabled) {
        await prefs.setBool(_syncPromptKey, true);
        return;
      }
      // No iCloud account yet — don't burn the one-time prompt; offer again later.
      if (!probe.isAvailable) return;
      await prefs.setBool(_syncPromptKey, true);
      if (!mounted) return;
      final enable = await showEvolveConfirm(
        context: context,
        title: context.t.icloudSync.disclosureTitle,
        message: context.t.icloudSync.disclosureBody,
        confirmLabel: context.t.icloudSync.disclosureAccept,
        ref: ref,
      );
      if (!enable || !mounted) return;
      await ref.read(privateSyncServiceProvider).enable();
      if (!mounted) return;
      refreshSyncEnabled(ref);
      invalidatePrivateDataProviders(ref);
      showEvolveToast(
        context,
        message: context.t.icloudSync.statusIdle,
        kind: EvolveToastKind.success,
      );
    } catch (e, stack) {
      AppLogger.error('Private-mode sync onboarding failed', e, stack);
    }
  }

  Future<void> _reset({required bool enableSync}) async {
    setState(() => _busy = true);
    final store = ref.read(privateLocalDatabaseProvider);
    final sync = ref.read(privateSyncServiceProvider);
    final ok = await resetAndReopenPrivate(
      store: store,
      sync: sync,
      enableSync: enableSync,
    );
    if (!mounted) return;
    if (ok) invalidatePrivateDataProviders(ref);
    setState(() {
      _result = PrivateRecoveryResult(
        ok ? PrivateRecoveryStatus.ready : PrivateRecoveryStatus.error,
      );
      _busy = false;
    });
  }

  void _backToSignIn() {
    // Leaving Private mode flips the persisted data mode; the router redirect
    // sends the user to '/login' so they're never stranded.
    ref.read(authProvider.notifier).returnToLoginFromPrivateMode();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (!_busy &&
        result != null &&
        result.status == PrivateRecoveryStatus.ready) {
      return widget.child;
    }
    return _RecoveryScaffold(
      busy: _busy,
      result: result,
      onRetry: _run,
      onResetFresh: () => _reset(enableSync: false),
      onBackToSignIn: _backToSignIn,
    );
  }
}

class _RecoveryScaffold extends StatelessWidget {
  const _RecoveryScaffold({
    required this.busy,
    required this.result,
    required this.onRetry,
    required this.onResetFresh,
    required this.onBackToSignIn,
  });

  final bool busy;
  final PrivateRecoveryResult? result;
  final VoidCallback onRetry;
  final VoidCallback onResetFresh;
  final VoidCallback onBackToSignIn;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: busy
                  ? _busyView(context, colors)
                  : _stateView(context, colors),
            ),
          ),
        ),
      ),
    );
  }

  Widget _busyView(BuildContext context, AppColorsExtension colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: colors.primary, strokeWidth: 3),
        const SizedBox(height: 20),
        Text(
          context.t.privateRecovery.preparing,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.mutedForeground,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _stateView(BuildContext context, AppColorsExtension colors) {
    final t = context.t;
    final status = result?.status ?? PrivateRecoveryStatus.error;
    final iCloudUnavailable = result?.iCloudUnavailable ?? false;

    final (IconData icon, Color iconColor, String title, String message) =
        switch (status) {
      PrivateRecoveryStatus.waitingForICloudKey => (
          LucideIcons.cloud,
          colors.primary,
          t.privateRecovery.waitingTitle,
          t.privateRecovery.waitingMessage,
        ),
      PrivateRecoveryStatus.needsUserChoice => (
          LucideIcons.lockKeyhole,
          colors.destructive,
          t.privateRecovery.lockedTitle,
          iCloudUnavailable
              ? t.privateRecovery.lockedMessageICloudUnavailable
              : t.privateRecovery.lockedMessageLocalOnly,
        ),
      _ => (
          LucideIcons.circleAlert,
          colors.destructive,
          t.privateRecovery.errorTitle,
          t.privateRecovery.errorMessage,
        ),
    };

    final showReset = status == PrivateRecoveryStatus.needsUserChoice ||
        status == PrivateRecoveryStatus.error;
    final showRetry = status == PrivateRecoveryStatus.waitingForICloudKey ||
        status == PrivateRecoveryStatus.error ||
        iCloudUnavailable;
    final showSyncHint =
        status == PrivateRecoveryStatus.needsUserChoice && !iCloudUnavailable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 44, color: iconColor),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.foreground,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.mutedForeground,
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (showSyncHint) ...[
          const SizedBox(height: 12),
          Text(
            t.privateRecovery.enableSyncHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 26),
        if (showRetry) ...[
          EvolveButton(
            label: t.privateRecovery.retry,
            onPressed: onRetry,
          ),
          const SizedBox(height: 10),
        ],
        if (showReset) ...[
          EvolveButton(
            label: t.privateRecovery.resetFresh,
            onPressed: onResetFresh,
            style: EvolveButtonStyle.destructive,
          ),
          const SizedBox(height: 10),
        ],
        EvolveButton(
          label: t.privateRecovery.backToSignIn,
          onPressed: onBackToSignIn,
          style: EvolveButtonStyle.plain,
        ),
      ],
    );
  }
}
