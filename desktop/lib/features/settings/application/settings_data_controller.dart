import 'dart:convert';
import 'dart:io';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_backup_import_service.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/desktop_private_sync_service.dart';
import 'package:evolve_desktop/core/import_merge_stats.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/application/desktop_profile_controller.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/settings/application/settings_form_controller.dart';
import 'package:evolve_desktop/features/settings/application/sync_settings_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Page size for the windowed export reads. A single unbounded PostgREST
/// `select` is capped by the project's `db-max-rows` (1000 by default), so a
/// backup built from one has to page or it silently ships incomplete.
const int kExportPageSize = 1000;

/// Fetches one window of rows. Abstracted so the paging loop is unit-testable
/// without a live Supabase client.
typedef ExportPageFetcher =
    Future<List<Map<String, dynamic>>> Function(int offset, int limit);

/// Concatenates every page from [fetchPage], requesting successive windows
/// until a short (final) page comes back. [fetchPage] must impose a stable
/// total order, otherwise windows can repeat or skip rows.
Future<List<Map<String, dynamic>>> fetchAllRowsPaginated(
  ExportPageFetcher fetchPage, {
  int pageSize = kExportPageSize,
}) async {
  final rows = <Map<String, dynamic>>[];
  var offset = 0;
  while (true) {
    final page = await fetchPage(offset, pageSize);
    rows.addAll(page);
    if (page.length < pageSize) break;
    offset += pageSize;
  }
  return rows;
}

/// How an export ended. The controller performs the delivery — a Save panel, the
/// clipboard or the share sheet, none of which need a BuildContext — and the
/// caller turns the outcome into the toast, because that does.
enum SettingsExportOutcome {
  /// The user dismissed the Save panel. Not an error, and deliberately silent.
  cancelled,
  savedToFile,
  copiedToClipboard,
  shared,
  failed,
}

@immutable
class SettingsExportResult {
  const SettingsExportResult(this.outcome, {required this.isPrivateMode});

  final SettingsExportOutcome outcome;

  /// The mode the export ACTUALLY ran in, captured before the first await.
  /// The confirmation copy differs between the two, and re-reading the mode at
  /// toast time would let a switch mid-export mislabel what was written.
  final bool isPrivateMode;
}

/// One import run's context, carried across the user's decisions.
///
/// The file path, the mode and the service instance are all fixed at the moment
/// the file is chosen, and the preview and the execute must agree on them. The
/// alternative — the controller keeping them in fields between calls — turns two
/// overlapping imports into a corrupted one.
@immutable
class SettingsImportSession {
  const SettingsImportSession({
    required this.path,
    required this.isPrivateMode,
    required this.isDatabaseLocked,
    required this.service,
  });

  final String path;
  final bool isPrivateMode;

  /// Private mode only: the encrypted local DB cannot be opened, so every write
  /// would throw. The caller has to offer the reset-and-import before going on.
  final bool isDatabaseLocked;

  final DesktopBackupImportService service;
}

/// Everything Settings does to the user's data as a whole: export, import,
/// reset, and the two deletions.
///
/// A plain [Provider] rather than a Notifier because none of this is state —
/// each flow starts, does its work and reports how it ended.
///
/// Deliberately holds NO dialogs. Every one of these flows is confirmed,
/// spinner-covered and then reported, and all three of those need a BuildContext
/// (and an Overlay) that a provider must not hold across an await. The Data &
/// Backup pane drives that sequence; this class performs the steps.
final settingsDataControllerProvider = Provider<SettingsDataController>(
  SettingsDataController.new,
);

class SettingsDataController {
  const SettingsDataController(this._ref);

  final Ref _ref;

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<SettingsExportResult> exportData() async {
    final isPrivateMode = _ref.read(activeDesktopDataModeProvider).isPrivate;
    SettingsExportResult result(SettingsExportOutcome outcome) =>
        SettingsExportResult(outcome, isPrivateMode: isPrivateMode);

    try {
      final String json;
      final String fileName;
      final String shareText;

      if (isPrivateMode) {
        // Private mode: export the full local data space from the encrypted DB
        // (profile, settings, habits, logs, macro goals, categories, moods) in
        // the canonical cross-client shape (see exportSnapshot).
        final payload = await DesktopPrivateDb.instance.exportData();
        json = const JsonEncoder.withIndent('  ').convert(payload);
        fileName = 'evolve_private_export.json';
        shareText = t.settingsPage.exportPrivateShareText;
      } else {
        // Cloud mode: emit a full, lossless snapshot of the user's Supabase
        // rows in the same canonical cross-client shape as the Private-mode
        // (and mobile) export, so every importer round-trips it (categories +
        // goals + logs + macro goals + moods + profile). Read straight from
        // the tables — the in-memory dashboard snapshot is lossy (no log
        // ids/streaks, no category list).
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;
        if (userId == null) return result(SettingsExportOutcome.failed);
        // Every table is paged: a single unbounded PostgREST select is capped by
        // the project's db-max-rows, which would silently truncate the backup
        // for any user with a long history. The `id` order is what makes the
        // windows a stable total order — ranges over an unordered select can
        // repeat or skip rows between pages.
        Future<List<Map<String, dynamic>>> rows(String table) {
          return fetchAllRowsPaginated((offset, limit) async {
            final res = await client
                .from(table)
                .select()
                .eq('user_id', userId)
                .order('id')
                .range(offset, offset + limit - 1);
            return List<Map<String, dynamic>>.from(res);
          });
        }

        final profileRow = await client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        final goals = await rows('goals');
        for (final g in goals) {
          // Supabase already returns integer[] as a list; the decode keeps the
          // representation stable if a stored string ever sneaks through.
          g['frequency_days'] = DesktopPrivateDb.decodeFrequencyDays(
            g['frequency_days'],
          );
        }

        // goal_progress rides in the export under 'habitProgress' so a
        // Replace-import can't wipe quantitative daily numbers by finding an empty
        // keep-set. Degrade to empty if the table isn't there yet (the v9 migration
        // lands before the targets flag flips), so a pre-migration export still
        // succeeds instead of failing whole.
        List<Map<String, dynamic>> habitProgress;
        try {
          habitProgress = await rows('goal_progress');
        } catch (error, stack) {
          AppLogger.error(
            'goal_progress export read skipped (pre-migration?)',
            error,
            stack,
          );
          habitProgress = const [];
        }

        json = const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': 1,
          'exportDate': DateTime.now().toIso8601String(),
          'mode': 'cloud',
          'profile': profileRow,
          'settings': profileRow,
          'habits': goals,
          'habitLogs': await rows('goal_logs'),
          'habitProgress': habitProgress,
          'macroGoals': await rows('long_term_goals'),
          'macroGoalCategories': await rows('macro_goal_categories'),
          'dailyMoods': await rows('daily_moods'),
        });
        fileName = 'mattioli_os_export.json';
        shareText = t.settingsPage.exportShareText;
      }

      // Delivery. macOS gets a native Save dialog (requires the user-selected
      // read-write entitlement); Linux has no share sheet so the clipboard is
      // used; anything else keeps the share-sheet behavior.
      if (Platform.isMacOS) {
        final path = await FilePicker.saveFile(
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['json'],
          bytes: utf8.encode(json),
        );
        // The user cancelled the dialog — not an error, and nothing to report.
        if (path == null) return result(SettingsExportOutcome.cancelled);
        return result(SettingsExportOutcome.savedToFile);
      } else if (Platform.isLinux) {
        await Clipboard.setData(ClipboardData(text: json));
        return result(SettingsExportOutcome.copiedToClipboard);
      } else {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(utf8.encode(json), mimeType: 'application/json'),
            ],
            fileNameOverrides: [fileName],
            text: shareText,
          ),
        );
        return result(SettingsExportOutcome.shared);
      }
    } catch (error, stack) {
      AppLogger.error('Errore durante exportData', error, stack);
      return result(SettingsExportOutcome.failed);
    }
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Asks for the file and pins down what this run is working with. Null when
  /// the user picked nothing.
  Future<SettingsImportSession?> beginImport() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json'],
    );

    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;

    final isPrivateMode =
        _ref.read(activeDesktopDataModeProvider) == DesktopDataMode.private;

    final privateStore = DesktopPrivateDb.instance;
    return SettingsImportSession(
      path: path,
      isPrivateMode: isPrivateMode,
      // Private-mode import needs the encrypted local DB to open. If its key is
      // unreadable (after a migration or a code-signing change that rotated the
      // Keychain access group) the DB is LOCKED and every write throws
      // PrivateDatabaseLockedException. Detect it up front so the caller can
      // offer an explicit reset-and-import — the old local data is unrecoverable
      // (its key is gone), but the user's backup imports cleanly onto a fresh
      // key.
      isDatabaseLocked: isPrivateMode && await privateStore.isDatabaseLocked(),
      service: DesktopBackupImportService(
        privateStore,
        isPrivateMode ? null : Supabase.instance.client,
      ),
    );
  }

  /// Throws away the unreadable encrypted DB so the backup has a fresh key to
  /// import onto. Only ever called after the user has accepted the loss.
  Future<void> resetLockedPrivateDatabase() =>
      DesktopPrivateDb.instance.resetLockedDatabase();

  /// Parses the backup (accepts both the web `.zip` and native `.json` shapes)
  /// without touching the store.
  Future<BackupImportPreview> parseImportPreview(
    SettingsImportSession session,
  ) => session.service.parsePreview(session.path);

  /// How many logs a Replace would delete — the real count the second
  /// confirmation names, rather than an abstract warning.
  int habitLogCount() => _ref
      .read(dashboardControllerProvider)
      .habitLogs
      .values
      .fold<int>(0, (sum, day) => sum + day.length);

  Future<ImportMergeStats> executeImport(
    SettingsImportSession session, {
    required BackupImportPreview preview,
    required bool replaceExisting,
  }) async {
    final stats = await session.service.executeImport(
      canonicalData: preview.canonicalData,
      replaceExisting: replaceExisting,
      isPrivateMode: session.isPrivateMode,
      skipped: preview.skipped,
    );

    // Refresh dashboard + category/profile providers so imported data shows.
    _ref.invalidate(desktopGoalCategoriesControllerProvider);
    if (session.isPrivateMode) _ref.invalidate(privateProfileProvider);

    await Future.wait([
      _ref.read(dashboardControllerProvider.notifier).refresh(),
      _ref.read(desktopGoalCategoriesControllerProvider.future),
      if (session.isPrivateMode) _ref.read(privateProfileProvider.future),
    ]);

    return stats;
  }

  // ---------------------------------------------------------------------------
  // Reset and deletion
  // ---------------------------------------------------------------------------

  /// Whether there is a session to delete an account with. Read fresh, at the
  /// moment of the tap.
  bool get hasActiveSession =>
      _ref.read(desktopAuthControllerProvider).isLoggedIn;

  /// Clears the user's content and puts every setting back to its default.
  /// Returns false when it did not complete, so the caller can say so.
  Future<bool> resetData() async {
    try {
      await _ref.read(dashboardControllerProvider.notifier).resetData();
      await _ref
          .read(settingsFormControllerProvider.notifier)
          .resetSettingsToDefaults();
      return true;
    } catch (error, stack) {
      AppLogger.error('Unable to reset desktop data', error, stack);
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      await _ref.read(desktopAuthControllerProvider.notifier).deleteAccount();
      return true;
    } catch (error, stack) {
      AppLogger.error('Unable to delete desktop account', error, stack);
      return false;
    }
  }

  /// Wipes the private data space, and with it the user's iCloud copy.
  ///
  /// Returns true when the data is gone — including through the locked-DB
  /// fallback, which is a successful deletion by any measure the user cares
  /// about.
  Future<bool> deletePrivateData() async {
    try {
      // Order mirrors mobile: queue/perform the cloud-zone wipe and remove the
      // shared keychain secrets FIRST (requestFullReset sets pending_zone_wipe,
      // which deleteAllPrivateData preserves if the wipe must wait for
      // connectivity), then wipe the local space.
      // Best-effort: a failure here must never block the local data wipe below.
      try {
        await _ref.read(desktopPrivateSyncServiceProvider).requestFullReset();
      } catch (error, stack) {
        AppLogger.error('iCloud full reset failed during delete', error, stack);
      }
      // Wipe all private data but stay in Private mode with a fresh, empty
      // profile (mirrors the mobile client — non-destructive to the mode).
      await DesktopPrivateDb.instance.deleteAllPrivateData();
      await _ref.read(dashboardControllerProvider.notifier).refresh();
      _ref.invalidate(privateProfileProvider);
      _ref.invalidate(desktopGoalCategoriesControllerProvider);
      // Cancel the now-orphaned per-habit reminders: the habits were just wiped,
      // so re-syncing with the (empty) habit list clears every scheduled
      // notification. Without this, deleted habits keep firing reminders (and
      // their Done/Skip actions would re-write phantom logs). Mirrors mobile's
      // cancelAll() on delete.
      await _ref
          .read(settingsFormControllerProvider.notifier)
          .syncNotifications();
      await _ref.read(syncSettingsControllerProvider.notifier).refreshStatus();
      return true;
    } on PrivateDatabaseLockedException {
      // Locked-DB recovery: the encrypted DB can't be unlocked (its key is
      // gone), so the wipe above couldn't even open it. Fall back to a
      // file-level reset so "delete private data" still recovers a locked
      // device for a user with no backup to import.
      // Kept as a fallback (not a pre-check) so the common path adds no latency.
      //
      // resetLockedDatabase now RETAINS the encrypted file (renamed aside, with
      // its key parked) — which is right for a recovery, and wrong here: this
      // action's dialog promises irreversible deletion, and the database may be
      // perfectly intact (a wrong key also reads as locked). So the retained
      // copy is destroyed immediately afterwards, or the app would keep a full
      // copy of the data it just told the user it had deleted.
      try {
        await DesktopPrivateDb.instance.resetLockedDatabase();
        await DesktopPrivateDb.instance.deleteLockedAsideCopy();
        await _ref.read(dashboardControllerProvider.notifier).refresh();
        _ref.invalidate(privateProfileProvider);
        _ref.invalidate(desktopGoalCategoriesControllerProvider);
        await _ref
            .read(syncSettingsControllerProvider.notifier)
            .refreshStatus();
        return true;
      } catch (error, stack) {
        AppLogger.error(
          'Unable to reset locked private database',
          error,
          stack,
        );
        return false;
      }
    } catch (error, stack) {
      AppLogger.error('Unable to delete private database', error, stack);
      return false;
    }
  }
}
