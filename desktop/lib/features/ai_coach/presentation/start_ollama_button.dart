import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/ollama_start_controller.dart';

/// The in-app control that starts the local Ollama server (or points to the
/// download when it isn't installed). Reflects the launch-and-poll status:
/// "Start Ollama" → "Starting Ollama…" (spinner) → hidden once reachable.
class StartOllamaButton extends ConsumerWidget {
  const StartOllamaButton({super.key});

  static final Uri _downloadUrl = Uri.parse('https://ollama.com/download');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(ollamaStartControllerProvider);
    // Assume installed until the probe resolves, to avoid flashing "Get Ollama"
    // for the users who picked the Ollama preset because they have it.
    final installed = ref.watch(ollamaInstalledProvider).asData?.value ?? true;

    final starting = status == OllamaStartStatus.starting;

    if (starting) {
      return const _PillButton(
        label: null,
        spinner: true,
        onTap: null,
      );
    }
    // Install-state comes only from the (re-probed) provider, so a mid-session
    // install flips this back to "Start" without a sticky terminal status.
    if (!installed) {
      return _PillButton(
        label: t.coachSettings.getOllama,
        icon: LucideIcons.download,
        onTap: () => _openDownload(context),
      );
    }
    return _PillButton(
      label: t.coachSettings.startOllama,
      icon: LucideIcons.play,
      onTap: () => ref.read(ollamaStartControllerProvider.notifier).start(),
    );
  }

  /// Opens the download page; surfaces a toast if the browser can't be opened so
  /// the tap is never a silent dead-end.
  Future<void> _openDownload(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(_downloadUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      showEvolveToast(
        context,
        message: t.coachSettings.ollamaDownloadFailed,
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
    this.spinner = false,
  });

  final String? label;
  final IconData? icon;
  final bool spinner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.evolveAccent;
    final onAccent = Theme.of(context).colorScheme.onPrimary;
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
            if (spinner) ...[
              EvolveSpinner(radius: 7, color: onAccent),
              const SizedBox(width: 9),
              Text(t.coachSettings.startingOllama),
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
