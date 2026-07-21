import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/app_logger.dart';
import '../../core/haptics.dart';
import '../../core/private_sync_service.dart';
import '../../core/rtl.dart';
import '../../core/theme.dart';
import '../../i18n/translations.g.dart';
import '../../providers/sync_refresh.dart'; // refreshSyncEnabled
import '../kit/evolve_dialog.dart';
import '../kit/evolve_switch.dart';
import '../kit/evolve_sheet.dart';

/// iCloud Sync settings for Private Mode (iOS-only). Surfaces the
/// [PrivateSyncService] state and lets the user enable/disable end-to-end
/// encrypted CloudKit sync, sync on demand, and see the last sync time.
class IcloudSyncScreen extends ConsumerStatefulWidget {
  const IcloudSyncScreen({super.key});

  static Route<void> route() {
    // MaterialPageRoute so iOS gets the native Cupertino slide + edge-swipe-back
    // gesture for free (Android keeps its native Material transition).
    return MaterialPageRoute<void>(
      builder: (context) => const IcloudSyncScreen(),
    );
  }

  @override
  ConsumerState<IcloudSyncScreen> createState() => _IcloudSyncScreenState();
}

class _IcloudSyncScreenState extends ConsumerState<IcloudSyncScreen> {
  PrivateSyncStatus? _status;

  /// What has and has not actually reached CloudKit. Null while loading, or
  /// when there is no local store to inspect (non-iOS / sync never enabled).
  SyncDiagnostics? _diagnostics;

  /// True while an enable/disable/sync action is in flight; drives the
  /// "Syncing…" status text and disables the controls.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Read the pending/errored counts. Deliberately separate from [_refresh] and
  /// never allowed to throw: the status line must still render if the private
  /// DB cannot be opened, which is one of the states a user comes here to
  /// diagnose.
  Future<void> _refreshDiagnostics() async {
    if (!mounted) return;
    try {
      final d = await ref.read(privateSyncServiceProvider).diagnostics();
      if (!mounted) return;
      setState(() => _diagnostics = d);
    } catch (e, stack) {
      AppLogger.error('iCloud sync diagnostics failed', e, stack);
    }
  }

  Future<void> _refresh() async {
    // Guard `ref` up front: _refresh runs from initState AND from _runAction's
    // catch path, where the user may already have popped this screen during the
    // async gap — reading a provider through a disposed `ref` throws the "Using
    // ref … unmounted" StateError (the reported crash class). Bail before
    // touching `ref`, and never let a status() failure escape as an unhandled
    // async error (it would reach the global handler and crash).
    if (!mounted) return;
    try {
      final status = await ref.read(privateSyncServiceProvider).status();
      if (!mounted) return;
      setState(() => _status = status);
    } catch (e, stack) {
      AppLogger.error('iCloud sync status refresh failed', e, stack);
    }
    await _refreshDiagnostics();
  }

  Future<void> _runAction(
    Future<PrivateSyncStatus> Function(PrivateSyncService service) action,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final status = await action(ref.read(privateSyncServiceProvider));
      if (!mounted) return;
      setState(() => _status = status);
      // The counts are the whole point after a sync: they say whether it
      // actually moved anything, which the status line alone cannot.
      await _refreshDiagnostics();
      // enable()/disable() flipped the per-device flag — rebuild any widget
      // watching it (e.g. the dashboard SyncOffBanner) so it reflects the change.
      refreshSyncEnabled(ref);
    } catch (e, stack) {
      AppLogger.error('iCloud sync action failed', e, stack);
      // Re-read so the UI reflects the real state after a failure.
      await _refresh();
    } finally {
      // Guard both the setState and the haptic: the user may have popped this
      // screen while the async action was in flight, disposing the widget.
      // Firing the haptic here would read a provider through a dead `ref`.
      if (mounted) {
        setState(() => _busy = false);
        ref.hapticLight();
      }
    }
  }

  Future<void> _onToggle(bool value) async {
    if (value) {
      final confirmed = await _showDisclosureDialog();
      if (confirmed != true) return;
      await _runAction((service) => service.enable());
      // enable() DEFERS rather than minting a rival key when the zone already
      // has data this device has no key for. Explain the wait and offer the
      // deliberate override, instead of leaving the toggle silently snapping
      // back to off.
      final status = _status;
      if (mounted && status != null && status.keyPending) {
        await _offerStartFresh();
      }
    } else {
      await _runAction((service) => service.disable());
    }
  }

  /// The escape hatch from a permanent deferral: a device whose iCloud Keychain
  /// will never deliver the key (it is switched off) would otherwise wait
  /// forever. Destructive, so it is never automatic — the user is told exactly
  /// what it costs and has to say yes.
  Future<void> _offerStartFresh() async {
    final confirmed = await showEvolveConfirm(
      context: context,
      title: context.t.icloudSync.forceEnableTitle,
      message: context.t.icloudSync.forceEnableBody,
      confirmLabel: context.t.icloudSync.forceEnable,
      ref: ref,
      isDestructive: true,
    );
    if (confirmed != true) return;
    await _runAction((service) => service.enable(force: true));
  }

  Future<void> _onResetFromThisDevice() async {
    final confirmed = await showEvolveConfirm(
      context: context,
      title: context.t.icloudSync.resetFromDevice,
      message: context.t.icloudSync.resetFromDeviceConfirm,
      confirmLabel: context.t.icloudSync.resetFromDevice,
      ref: ref,
      isDestructive: true,
    );
    if (confirmed != true) return;
    await _runAction((service) => service.resetSyncFromThisDevice());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t.icloudSync.resetFromDeviceDone)),
    );
  }

  Future<bool> _showDisclosureDialog() {
    return showEvolveConfirm(
      context: context,
      title: context.t.icloudSync.disclosureTitle,
      message: context.t.icloudSync.disclosureBody,
      confirmLabel: context.t.icloudSync.disclosureAccept,
      ref: ref,
    );
  }

  /// Maps the current status to the localized one-line status text.
  String _statusLabel(BuildContext context, PrivateSyncStatus status) {
    if (_busy) return context.t.icloudSync.statusSyncing;
    if (!status.isEnabled) return context.t.icloudSync.statusOff;
    if (status.account == CloudAccountStatus.noAccount) {
      return context.t.icloudSync.statusNoAccount;
    }
    if (status.account != CloudAccountStatus.available) {
      return context.t.icloudSync.statusUnavailable;
    }
    if (status.keyPending) {
      return context.t.icloudSync.statusWaitingKey;
    }
    // A key split is never "Up to date": syncing runs, reports success and
    // applies nothing, which is exactly how it stayed invisible for weeks.
    if (status.undecryptableCount > 0) {
      return context.t.icloudSync.keySplitTitle;
    }
    // "Up to date" is a claim about the DATA, not about the account, and it may
    // only be made when [SyncDiagnostics.isFullySynced] licenses it. Reaching
    // this line used to be enough: a device with thousands of rows that had
    // never left it, and a `last_full_sync_at` stamped moments ago by a push in
    // which every record failed, rendered exactly the same "Up to date" as a
    // healthy one. The per-count breakdown is on the details row below; the
    // headline's job is simply never to lie.
    final diagnostics = _diagnostics;
    if (diagnostics != null && !diagnostics.isFullySynced) {
      return context.t.icloudSync.statusNotSynced;
    }
    return context.t.icloudSync.statusIdle;
  }

  /// Prominent, actionable explanation of a key split — the one sync failure a
  /// user cannot resolve by waiting or retrying.
  Widget _buildKeySplitCard(BuildContext context, int count) {
    final danger = context.appColors.destructive;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.triangleAlert, size: 18, color: danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t.icloudSync.keySplitTitle,
                  style: GoogleFonts.inter(
                    color: context.appColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.t.icloudSync.keySplitBody(count: count),
            style: GoogleFonts.inter(
              color: context.appColors.mutedForeground,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _busy ? null : _onResetFromThisDevice,
              style: TextButton.styleFrom(foregroundColor: danger),
              child: Text(context.t.icloudSync.resetFromDevice),
            ),
          ),
        ],
      ),
    );
  }

  /// "Never synced" or "Last synced `<date> <time>`".
  String _lastSyncedLabel(BuildContext context, PrivateSyncStatus status) {
    final at = status.lastSyncedAt;
    if (at == null) return context.t.icloudSync.lastSyncedNever;
    final local = at.toLocal();
    final materialLocalizations = MaterialLocalizations.of(context);
    final date = materialLocalizations.formatShortDate(local);
    final time = materialLocalizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return context.t.icloudSync.lastSyncedAt(time: '$date $time');
  }

  /// The one-line truth about whether anything is stranded. Failures are named
  /// ahead of the pending count: a user with both needs to know that retrying
  /// is not what is missing.
  String _diagnosticsLabel(BuildContext context, SyncDiagnostics d) {
    // totalStuck, not a hand-rolled sum: adding a bucket to SyncDiagnostics
    // (as `heldByReason` was) must not silently under-count here.
    final stuck = d.totalStuck;
    if (stuck > 0) return context.t.icloudSync.detailsFailed(count: stuck);
    if (d.totalPending > 0) {
      return context.t.icloudSync.detailsPending(count: d.totalPending);
    }
    return context.t.icloudSync.detailsAllSynced;
  }

  /// The full per-table report, as copyable monospace text.
  ///
  /// Deliberately raw rather than prettified: its job is to be pasted into a
  /// bug report or read aloud from a device that cannot be attached to a
  /// debugger, and a per-table count is the only thing that localises a stall
  /// to a specific table.
  Future<void> _showDiagnosticsSheet(SyncDiagnostics d) async {
    final report = d.toReport();
    await showEvolveSheet<void>(
      context: context,
      title: context.t.icloudSync.detailsTitle,
      itemsBuilder: (sheetContext) => [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.appColors.border),
            ),
            // Horizontal scroll: the report is a fixed-width table and wrapping
            // it would destroy the column alignment that makes it readable.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                report,
                // Platform monospace rather than a google_fonts family: the
                // report's column alignment needs fixed width, and this screen
                // must render offline (GoogleFonts fetches at runtime).
                style: TextStyle(
                  fontFamily: 'Menlo',
                  fontFamilyFallback: const ['Courier New', 'monospace'],
                  color: context.appColors.foreground,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report));
              if (!sheetContext.mounted) return;
              Navigator.pop(sheetContext);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.t.icloudSync.detailsCopied)),
              );
            },
            icon: const Icon(LucideIcons.copy, size: 16),
            label: Text(context.t.icloudSync.detailsCopy),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        backgroundColor: context.appColors.background,
        elevation: 0,
        leading: IconButton(
          icon: DirectionalIcon(
            LucideIcons.chevronLeft,
            LucideIcons.chevronRight,
            color: context.appColors.foreground,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.t.icloudSync.title,
          style: TextStyle(
            color: context.appColors.foreground,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: status == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (status.undecryptableCount > 0)
                    _buildKeySplitCard(context, status.undecryptableCount),
                  _buildSettingsCard(context, [
                    _buildSwitchRow(
                      context: context,
                      icon: LucideIcons.cloud,
                      title: context.t.icloudSync.enableTitle,
                      subtitle: _statusLabel(context, status),
                      value: status.isEnabled,
                      onChanged: _busy ? null : _onToggle,
                    ),
                    _buildDivider(context),
                    _buildActionRow(
                      context: context,
                      icon: LucideIcons.refreshCw,
                      title: context.t.icloudSync.syncNow,
                      subtitle: _lastSyncedLabel(context, status),
                      enabled: !_busy && status.isEnabled && status.isAvailable,
                      onTap: () => _runAction((service) => service.syncNow()),
                    ),
                    // Only meaningful once there is a local store to inspect.
                    if (_diagnostics != null) ...[
                      _buildDivider(context),
                      _buildActionRow(
                        context: context,
                        icon: LucideIcons.listChecks,
                        title: context.t.icloudSync.detailsTitle,
                        subtitle: _diagnosticsLabel(context, _diagnostics!),
                        enabled: !_busy,
                        onTap: () => _showDiagnosticsSheet(_diagnostics!),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 24),
                  _buildDisclosureNote(context),
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    return EvolveListSection(
      children: children.where((c) => c is! Divider).toList(),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.appColors.border,
      indent: 56,
    );
  }

  Widget _buildSwitchRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDisabled = onChanged == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.appColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.appColors.border),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isDisabled
                  ? context.appColors.mutedForeground
                  : primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isDisabled
                        ? context.appColors.mutedForeground
                        : context.appColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: context.appColors.mutedForeground.withValues(
                        alpha: 0.6,
                      ),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          EvolveSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final color = enabled ? primaryColor : context.appColors.mutedForeground;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.appColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.appColors.border),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: enabled
                          ? context.appColors.foreground
                          : context.appColors.mutedForeground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: context.appColors.mutedForeground.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const DirectionalIcon(
              LucideIcons.chevronRight,
              LucideIcons.chevronLeft,
              color: AppColors.mutedForeground,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclosureNote(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.shieldCheck,
            size: 18,
            color: context.appColors.mutedForeground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t.icloudSync.disclosureTitle,
                  style: GoogleFonts.inter(
                    color: context.appColors.foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t.icloudSync.disclosureBody,
                  style: GoogleFonts.inter(
                    color: context.appColors.mutedForeground.withValues(
                      alpha: 0.8,
                    ),
                    fontSize: 12,
                    height: 1.4,
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
