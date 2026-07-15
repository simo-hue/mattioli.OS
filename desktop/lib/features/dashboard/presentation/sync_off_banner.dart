import 'dart:io';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_sync_service.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Dismisses the banner for the current app session only. It returns next launch
/// while sync stays off, because the data-loss risk it warns about is permanent.
class _SyncBannerDismissed extends Notifier<bool> {
  @override
  bool build() => false;
  void dismiss() => state = true;
}

final _syncBannerDismissedProvider =
    NotifierProvider<_SyncBannerDismissed, bool>(_SyncBannerDismissed.new);

/// A persistent, dismissible warning shown to Private-mode users on macOS who
/// have NOT enabled iCloud sync: their data lives only on this device (the
/// encrypted DB is excluded from device backups and its key never leaves the
/// device), so a new machine / erase-and-restore loses everything with no
/// recovery. Nudges them to turn sync on. Renders nothing on Windows/Linux, in
/// Supabase mode, when sync is already on, or once dismissed for the session.
/// Mirrors mobile's `SyncOffBanner`.
class SyncOffBanner extends ConsumerWidget {
  const SyncOffBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // macOS-only: Windows/Linux Private mode is local-only (no CloudKit), so
    // there is no sync to turn on and nothing to warn about.
    if (!Platform.isMacOS) return const SizedBox.shrink();
    if (!ref.watch(activeDesktopDataModeProvider).isPrivate) {
      return const SizedBox.shrink();
    }
    if (ref.watch(_syncBannerDismissedProvider)) return const SizedBox.shrink();

    // Reactive: rebuilds when sync is toggled (the settings toggle calls
    // refreshDesktopSyncEnabled), so the banner clears immediately after the
    // user enables iCloud sync instead of lingering until an app restart.
    if (ref.watch(desktopSyncEnabledProvider)) return const SizedBox.shrink();

    final colors = context.evolveColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: EvolveColors.destructive.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: EvolveColors.destructive.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              LucideIcons.cloudOff,
              size: 18,
              color: EvolveColors.destructive,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.icloudSync.bannerText,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 6),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      // Deep-link Settings straight to the Privacy (iCloud-sync)
                      // section — desktop's equivalent of mobile pushing the
                      // IcloudSyncScreen.
                      ref
                          .read(privacySettingsRequestProvider.notifier)
                          .request();
                      ref
                          .read(navigationControllerProvider.notifier)
                          .select(DesktopSection.settings);
                    },
                    child: Text(
                      t.icloudSync.bannerAction,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: EvolveColors.destructive,
                      ),
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
            icon: Icon(LucideIcons.x, size: 16, color: colors.muted),
            onPressed: () =>
                ref.read(_syncBannerDismissedProvider.notifier).dismiss(),
          ),
        ],
      ),
    );
  }
}
