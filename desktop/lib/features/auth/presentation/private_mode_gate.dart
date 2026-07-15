import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_sync_service.dart';
import 'package:evolve_desktop/core/private_data_refresh.dart';
import 'package:evolve_desktop/features/auth/application/private_mode_recovery.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Ensures the encrypted Private DB is open before showing [child] (the shell).
/// Transparently recovers a LOCKED DB from iCloud when it's safe, and offers an
/// explicit recovery choice when it isn't — instead of dead-ending on the old
/// "Operazione non riuscita" toast. Wraps the Private-mode branch of the app so
/// it covers BOTH the fresh "continue privately" entry and the startup restore
/// of a previous Private session. Mirrors mobile's `PrivateModeGate`.
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
    final sync = ref.read(desktopPrivateSyncServiceProvider);
    final result = await openOrRecoverPrivate(sync);
    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
    });
    if (result.status != PrivateRecoveryStatus.ready) return;
    if (result.restoredFromCloud) {
      refreshPrivateAfterPull(ProviderScope.containerOf(context, listen: false));
      showEvolveToast(
        context,
        message: t.privateRecovery.restoredFromCloudToast,
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
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs == null) return;
    if (prefs.getBool(_syncPromptKey) ?? false) return;
    final sync = ref.read(desktopPrivateSyncServiceProvider);
    final probe = await sync.probe();
    if (probe.isEnabled) {
      await prefs.setBool(_syncPromptKey, true);
      return;
    }
    // No iCloud account yet — don't burn the one-time prompt; offer again later.
    if (!probe.isAvailable || !mounted) return;
    await prefs.setBool(_syncPromptKey, true);
    if (!mounted) return;
    final enable = await showEvolveDialog<bool>(
      context: context,
      builder: (ctx) => EvolveAlertDialog(
        icon: LucideIcons.cloud,
        iconColor: context.evolveAccent,
        title: Text(t.icloudSync.disclosureTitle),
        subtitle: t.icloudSync.disclosureBody,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.actions.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.icloudSync.disclosureAccept),
          ),
        ],
      ),
    );
    if (enable != true || !mounted) return;
    await ref.read(desktopPrivateSyncServiceProvider).enable();
    if (!mounted) return;
    refreshPrivateAfterPull(ProviderScope.containerOf(context, listen: false));
    showEvolveToast(
      context,
      message: t.icloudSync.statusIdle,
      kind: EvolveToastKind.success,
    );
  }

  Future<void> _reset({required bool enableSync}) async {
    setState(() => _busy = true);
    final sync = ref.read(desktopPrivateSyncServiceProvider);
    final ok = await resetAndReopenPrivate(sync, enableSync: enableSync);
    if (!mounted) return;
    if (ok) {
      refreshPrivateAfterPull(ProviderScope.containerOf(context, listen: false));
    }
    setState(() {
      _result = PrivateRecoveryResult(
        ok ? PrivateRecoveryStatus.ready : PrivateRecoveryStatus.error,
      );
      _busy = false;
    });
  }

  void _backToSignIn() {
    // Leaving Private mode flips the persisted data mode; the app's home router
    // rebuilds to the sign-in page so the user is never stranded.
    ref.read(activeDesktopDataModeProvider.notifier).enterSupabaseMode();
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
    final colors = context.evolveColors;
    final accent = context.evolveAccent;

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: busy
                ? _Busy(label: t.privateRecovery.preparing, accent: accent)
                : _buildState(context, colors, accent),
          ),
        ),
      ),
    );
  }

  Widget _buildState(
    BuildContext context,
    EvolvePalette colors,
    Color accent,
  ) {
    final status = result?.status ?? PrivateRecoveryStatus.error;
    final iCloudUnavailable = result?.iCloudUnavailable ?? false;

    final (IconData icon, Color iconColor, String title, String message) =
        switch (status) {
      PrivateRecoveryStatus.waitingForICloudKey => (
          LucideIcons.cloud,
          accent,
          t.privateRecovery.waitingTitle,
          t.privateRecovery.waitingMessage,
        ),
      PrivateRecoveryStatus.needsUserChoice => (
          LucideIcons.lockKeyhole,
          EvolveColors.destructive,
          t.privateRecovery.lockedTitle,
          iCloudUnavailable
              ? t.privateRecovery.lockedMessageICloudUnavailable
              : t.privateRecovery.lockedMessageLocalOnly,
        ),
      _ => (
          LucideIcons.circleAlert,
          EvolveColors.destructive,
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
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.muted,
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
              color: colors.subtle,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 28),
        if (showRetry) ...[
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(t.privateRecovery.retry),
          ),
          const SizedBox(height: 10),
        ],
        if (showReset)
          OutlinedButton(
            onPressed: onResetFresh,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: EvolveColors.destructive,
              side: BorderSide(
                color: EvolveColors.destructive.withValues(alpha: 0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(t.privateRecovery.resetFresh),
          ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: onBackToSignIn,
          child: Text(
            t.privateRecovery.backToSignIn,
            style: TextStyle(color: colors.muted, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EvolveSpinner(radius: 16, color: accent),
        const SizedBox(height: 18),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.evolveColors.muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
