import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/local_server_start_controller.dart';
import '../domain/local_server_target.dart';

/// The in-app control that starts a local LLM server (or points to the download
/// when its app isn't installed). Reflects the launch-and-poll status:
/// "Start {app}" → "Starting {app}…" (spinner) → hidden once reachable.
class StartLocalServerButton extends ConsumerWidget {
  const StartLocalServerButton({required this.target, super.key});

  final LocalServerTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(localServerStartControllerProvider);
    // Assume installed until the probe resolves, to avoid flashing "Get {app}"
    // at the users who picked this preset precisely because they have it.
    final installed =
        ref.watch(localAppInstalledProvider(target.preset)).asData?.value ??
        true;

    if (status == LocalServerStartStatus.starting) {
      return _PillButton(
        label: null,
        spinnerLabel: t.coachSettings.startingLocalServer(
          app: target.displayName,
        ),
        onTap: null,
      );
    }
    // Install-state comes only from the (re-probed) provider, so a mid-session
    // install flips this back to "Start" without a sticky terminal status.
    if (!installed) {
      return _PillButton(
        label: t.coachSettings.getLocalServer(app: target.displayName),
        icon: LucideIcons.download,
        onTap: () => _openDownload(context),
      );
    }
    return _PillButton(
      label: t.coachSettings.startLocalServer(app: target.displayName),
      icon: LucideIcons.play,
      onTap: () =>
          ref.read(localServerStartControllerProvider.notifier).start(),
    );
  }

  /// Opens the download page; surfaces a toast if the browser can't be opened so
  /// the tap is never a silent dead-end.
  Future<void> _openDownload(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(target.downloadUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      showEvolveToast(
        context,
        message: t.coachSettings.localServerDownloadFailed(
          url: target.downloadUrl,
        ),
        kind: EvolveToastKind.error,
      );
    }
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.spinnerLabel,
  });

  final String? label;
  final IconData? icon;

  /// Non-null puts the button in its spinner state, with this as the caption.
  final String? spinnerLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.evolveAccent;
    final onAccent = Theme.of(context).colorScheme.onPrimary;
    final spinnerCaption = spinnerLabel;
    return SizedBox(
      height: 34,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: accent.withValues(alpha: 0.6),
          disabledForegroundColor: onAccent,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinnerCaption != null) ...[
              EvolveSpinner(radius: 7, color: onAccent),
              const SizedBox(width: 9),
              Text(spinnerCaption),
            ] else ...[
              if (icon != null) ...[
                Icon(icon, size: 15),
                const SizedBox(width: 7),
              ],
              Text(label ?? ''),
            ],
          ],
        ),
      ),
    );
  }
}
