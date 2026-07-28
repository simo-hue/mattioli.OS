import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/desktop_private_sync_service.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The full per-table report, as copyable monospace text. Deliberately raw:
/// a per-table count is the only thing that localises a stall to a specific
/// table, and this Mac is one half of the pair being compared.
Future<void> showSyncDiagnosticsDialog(
  BuildContext context,
  SyncDiagnostics d,
) async {
  final report = d.toReport();
  await showEvolveDialog<void>(
    context: context,
    builder: (dialogContext) => EvolveAlertDialog(
      icon: LucideIcons.listChecks,
      title: Text(t.icloudSync.detailsTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        // The report is a fixed-width table; wrapping would destroy the
        // column alignment that makes it readable.
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
              fontSize: 11,
              height: 1.5,
              color: dialogContext.evolveColors.foreground,
            ),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: report));
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (context.mounted) {
              showEvolveToast(context, message: t.icloudSync.detailsCopied);
            }
          },
          icon: const Icon(LucideIcons.copy, size: 16),
          label: Text(t.icloudSync.detailsCopy),
        ),
      ],
    ),
  );
}
