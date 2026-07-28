import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/import_merge_stats.dart';
import 'package:evolve_desktop/features/settings/presentation/dialogs/import_mode_dialog.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Post-import summary dialog: one line per entity with the merge outcome,
/// mirroring mobile's import-completed dialog.
Future<void> showImportResultDialog(
  BuildContext context,
  ImportMergeStats stats,
) {
  return showEvolveDialog<void>(
    context: context,
    builder: (ctx) => EvolveAlertDialog(
      icon: LucideIcons.circleCheck,
      title: Text(t.settingsPage.importCompletedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stats.replaced
                ? t.settingsPage.importSummaryReplaced
                : t.settingsPage.importSummaryMerged,
            style: TextStyle(color: ctx.evolveColors.foreground),
          ),
          const SizedBox(height: 12),
          settingsImportSummaryRow(
            ctx,
            LucideIcons.check,
            _mergeRowText(
              stats,
              stats.habits,
              t.settingsPage.importEntityHabits,
            ),
          ),
          settingsImportSummaryRow(
            ctx,
            LucideIcons.history,
            _mergeRowText(stats, stats.logs, t.settingsPage.importEntityLogs),
          ),
          settingsImportSummaryRow(
            ctx,
            LucideIcons.target,
            _mergeRowText(
              stats,
              stats.macroGoals,
              t.settingsPage.importEntityMacroGoals,
            ),
          ),
          settingsImportSummaryRow(
            ctx,
            LucideIcons.folder,
            _mergeRowText(
              stats,
              stats.categories,
              t.settingsPage.importEntityCategories,
            ),
          ),
          settingsImportSummaryRow(
            ctx,
            LucideIcons.smile,
            _mergeRowText(stats, stats.moods, t.settingsPage.importEntityMoods),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.settingsPage.importSummaryDone),
        ),
      ],
    ),
  );
}

/// One summary line. Replace mode shows a single total; merge mode breaks the
/// outcome into added / updated / unchanged. Invalid rows append ", N skipped".
String _mergeRowText(ImportMergeStats stats, EntityMerge m, String label) {
  final base = stats.replaced
      ? t.settingsPage.importRowReplace(count: m.total, label: label)
      : t.settingsPage.importRowMerge(
          label: label,
          added: m.added,
          updated: m.updated,
          unchanged: m.unchanged,
        );
  return m.skipped > 0
      ? '$base${t.settingsPage.importRowSkipped(count: m.skipped)}'
      : base;
}
