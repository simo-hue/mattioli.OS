import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App name, version and build number.
class AppBuildInfo {
  const AppBuildInfo({
    required this.appName,
    required this.version,
    required this.build,
  });

  final String appName;
  final String version;
  final String build;
}

/// Reads the version out of the running bundle.
///
/// A provider rather than a direct `PackageInfo.fromPlatform()` call so widget
/// tests can override it: `package_info_plus` answers over a platform channel
/// that does not exist under `flutter_test`, and a footer that throws would
/// take the whole Settings page down with it.
final appBuildInfoProvider = FutureProvider<AppBuildInfo>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppBuildInfo(
    appName: info.appName,
    version: info.version,
    build: info.buildNumber,
  );
});

/// The version block docked at the bottom of the Settings sidebar.
///
/// macOS Settings showed no build identity at all, and it is the first thing a
/// support conversation asks for. Click to copy — reading a build number off a
/// screenshot is how it usually gets transcribed wrong.
class SettingsAboutFooter extends ConsumerWidget {
  const SettingsAboutFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.evolveColors;
    // While the read is in flight, and if it fails, the footer renders nothing
    // rather than a spinner or an error: it is chrome, and a sidebar that
    // reflows once on open is worse than one that quietly gains a line.
    final info = ref.watch(appBuildInfoProvider).asData?.value;
    if (info == null) return const SizedBox.shrink();

    final label = t.settingsPage.aboutVersion(
      version: info.version,
      build: info.build,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 8),
            color: colors.border.withValues(alpha: 0.5),
          ),
          Tooltip(
            message: t.settingsPage.aboutCopyTooltip,
            child: InkWell(
              borderRadius: BorderRadius.circular(7),
              onTap: () async {
                await Clipboard.setData(
                  ClipboardData(text: '${info.appName} $label'),
                );
                if (!context.mounted) return;
                showEvolveToast(context, message: t.settingsPage.aboutCopied);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.foreground.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: colors.muted.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
