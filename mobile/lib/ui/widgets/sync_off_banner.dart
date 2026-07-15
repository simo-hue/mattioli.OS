import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data_mode.dart';
import '../../core/theme.dart';
import '../../i18n/translations.g.dart';
import '../../providers/sync_refresh.dart'; // syncEnabledProvider
import '../screens/icloud_sync_screen.dart';

/// Dismisses the banner for the current app session only. It returns next launch
/// while sync stays off, because the data-loss risk it warns about is permanent.
class _SyncBannerDismissed extends Notifier<bool> {
  @override
  bool build() => false;
  void dismiss() => state = true;
}

final _syncBannerDismissedProvider =
    NotifierProvider<_SyncBannerDismissed, bool>(_SyncBannerDismissed.new);

/// A persistent, dismissible warning shown to Private-mode users who have NOT
/// enabled iCloud sync: their data lives only on this device (the encrypted DB
/// is excluded from device backups and its key never leaves the device), so a
/// new phone / erase-and-restore loses everything with no recovery. Nudges them
/// to turn sync on. Renders nothing on Android, in Supabase mode, when sync is
/// already on, or once dismissed for the session.
class SyncOffBanner extends ConsumerWidget {
  const SyncOffBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isIOS) return const SizedBox.shrink();
    if (ref.watch(activeDataModeProvider) != AppDataMode.private) {
      return const SizedBox.shrink();
    }
    if (ref.watch(_syncBannerDismissedProvider)) return const SizedBox.shrink();

    // Reactive: rebuilds when sync is toggled (the toggle sites call
    // refreshSyncEnabled), so the banner clears immediately after the user
    // enables iCloud sync instead of lingering until an app restart.
    if (ref.watch(syncEnabledProvider)) return const SizedBox.shrink();

    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(LucideIcons.cloudOff,
                size: 18, color: AppColors.destructive),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t.icloudSync.bannerText,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).push(IcloudSyncScreen.route()),
                  child: Text(
                    context.t.icloudSync.bannerAction,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.destructive,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            visualDensity: VisualDensity.compact,
            icon: Icon(LucideIcons.x, size: 16, color: colors.mutedForeground),
            onPressed: () =>
                ref.read(_syncBannerDismissedProvider.notifier).dismiss(),
          ),
        ],
      ),
    );
  }
}
