import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/app_logger.dart';
import '../../core/haptics.dart';
import '../../core/private_sync_service.dart';
import '../../core/rtl.dart';
import '../../core/theme.dart';
import '../../i18n/translations.g.dart';
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

  /// True while an enable/disable/sync action is in flight; drives the
  /// "Syncing…" status text and disables the controls.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await ref.read(privateSyncServiceProvider).status();
    if (!mounted) return;
    setState(() => _status = status);
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
    } catch (e, stack) {
      AppLogger.error('iCloud sync action failed', e, stack);
      // Re-read so the UI reflects the real state after a failure.
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
      ref.hapticLight();
    }
  }

  Future<void> _onToggle(bool value) async {
    if (value) {
      final confirmed = await _showDisclosureDialog();
      if (confirmed != true) return;
      await _runAction((service) => service.enable());
    } else {
      await _runAction((service) => service.disable());
    }
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
    return context.t.icloudSync.statusIdle;
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
