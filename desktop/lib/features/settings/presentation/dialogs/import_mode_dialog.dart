import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/desktop_backup_import_service.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// One `icon + text` line of an import summary.
Widget settingsImportSummaryRow(
  BuildContext context,
  IconData icon,
  String text,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: context.evolveColors.foreground.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: context.evolveColors.foreground,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Pre-import chooser for [preview]. Returns the selected mode — `false` =
/// merge, `true` = replace — or null when cancelled or dismissed.
///
/// The initial selection MUST stay merge: replace wipes every existing record
/// not in the backup, and in private mode the wipe is tombstoned to iCloud, so
/// it destroys the copy on the user's other devices too. It has to be an
/// explicit opt-in, never the pre-selected default. Mirrors mobile.
///
/// Top-level rather than a `_SettingsPageState` method so that default is
/// reachable from a test without going through the native file picker.
Future<bool?> showImportModeDialog(
  BuildContext context,
  BackupImportPreview preview,
) {
  bool replaceExisting = false;
  return showEvolveDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return EvolveAlertDialog(
            maxWidth: 470,
            icon: LucideIcons.upload,
            title: Text(t.settingsPage.importSummaryTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Same per-entity icons as the post-import summary dialog so
                // the two read as one flow.
                settingsImportSummaryRow(
                  context,
                  LucideIcons.check,
                  t.settingsPage.importHabitsCount(count: preview.habitsCount),
                ),
                settingsImportSummaryRow(
                  context,
                  LucideIcons.history,
                  t.settingsPage.importLogsCount(count: preview.logsCount),
                ),
                settingsImportSummaryRow(
                  context,
                  LucideIcons.target,
                  t.settingsPage.importMacroGoalsCount(
                    count: preview.macroGoalsCount,
                  ),
                ),
                settingsImportSummaryRow(
                  context,
                  LucideIcons.folder,
                  t.settingsPage.importCategoriesCount(
                    count: preview.categoriesCount,
                  ),
                ),
                settingsImportSummaryRow(
                  context,
                  LucideIcons.smile,
                  t.settingsPage.importMoodsCount(count: preview.moodsCount),
                ),
                if (preview.totalSkipped > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: EvolveColors.destructive.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: EvolveColors.destructive.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.triangleAlert,
                          size: 14,
                          color: EvolveColors.destructive,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.settingsPage.importPreviewSkipped(
                              count: preview.totalSkipped,
                            ),
                            style: const TextStyle(
                              color: EvolveColors.destructive,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                EvolveRadioRow<bool>(
                  value: false,
                  groupValue: replaceExisting,
                  onChanged: (val) => setState(() => replaceExisting = val),
                  title: t.settingsPage.importMergeTitle,
                  subtitle: t.settingsPage.importMergeSubtitle,
                ),
                const SizedBox(height: 8),
                EvolveRadioRow<bool>(
                  value: true,
                  groupValue: replaceExisting,
                  onChanged: (val) => setState(() => replaceExisting = val),
                  title: t.settingsPage.importReplaceTitle,
                  subtitle: t.settingsPage.importReplaceSubtitle,
                ),
              ],
            ),
            actions: [
              // Cancel returns null, NOT false: false is a real answer here
              // (merge), so popping it would silently start an import.
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t.settingsPage.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, replaceExisting),
                child: Text(t.settingsPage.importConfirmButton),
              ),
            ],
          );
        },
      );
    },
  );
}
