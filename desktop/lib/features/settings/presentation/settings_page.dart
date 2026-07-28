import 'package:evolve_desktop/core/desktop_backup_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/desktop_private_sync_service.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/settings/application/settings_form_controller.dart';
import 'package:evolve_desktop/features/statistics/data/private_analytics_source.dart';
import 'package:evolve_desktop/features/settings/presentation/dialogs/import_mode_dialog.dart';
import 'package:evolve_desktop/features/settings/presentation/dialogs/import_result_dialog.dart';
import 'package:evolve_desktop/features/settings/presentation/dialogs/settings_dialogs.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/account_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/advanced_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/ai_coach_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/data_backup_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/general_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/notifications_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/privacy_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/subscription_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_search.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_about_footer.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_row_kit.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_search_widgets.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:evolve_desktop/shared/widgets/evolve_image_crop_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:evolve_desktop/features/auth/application/desktop_profile_controller.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

export 'package:evolve_desktop/features/settings/presentation/dialogs/import_mode_dialog.dart'
    show showImportModeDialog;
export 'package:evolve_desktop/features/settings/presentation/panes/subscription_pane.dart'
    show annualSavingPercent, showPaywallDialog;

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

/// Longest edge, in pixels, of a stored avatar. The image is encrypted here and
/// decrypted on every device that pulls it by synchronous pure-Dart AES-GCM on
/// the UI isolate (~1.9 MB/s), so a multi-MB camera original freezes both this
/// app and the paired iPhone. Mirrors mobile's picker cap.
const int kAvatarMaxDimension = 512;

/// Re-encodes [bytes] so the longest edge is at most [maxDimension]. Returns
/// the original bytes unchanged when they already fit, when the re-encode would
/// be larger, or when the image cannot be decoded — so this never returns more
/// bytes than it was handed.
///
/// image_picker's `maxWidth`/`maxHeight`/`imageQuality` cannot do this here:
/// image_picker_macos routes gallery picks to file_selector and silently
/// ignores all three, so the downscale has to happen in Dart.
Future<Uint8List> downscaleAvatarBytes(
  Uint8List bytes, {
  int maxDimension = kAvatarMaxDimension,
}) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final longestEdge = math.max(descriptor.width, descriptor.height);
    if (longestEdge <= maxDimension) return bytes;

    final scale = maxDimension / longestEdge;
    codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * scale).round().clamp(1, maxDimension),
      targetHeight: (descriptor.height * scale).round().clamp(1, maxDimension),
    );
    image = (await codec.getNextFrame()).image;
    final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
    if (encoded == null) return bytes;
    // PNG is lossless, so re-encoding a small, heavily compressed photo can
    // come out BIGGER than the source. What costs the sync path is bytes, not
    // pixels, so keep whichever payload is smaller.
    if (encoded.lengthInBytes >= bytes.length) return bytes;
    return encoded.buffer.asUint8List();
  } catch (error, stack) {
    // The downscale is an optimisation, never a gate: an undecodable or exotic
    // format still has to be usable as an avatar.
    AppLogger.error('Unable to downscale desktop avatar', error, stack);
    return bytes;
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    // The buffer has to outlive instantiateCodec — dart:ui's own
    // instantiateImageCodecWithSize holds it until the codec exists — so it is
    // released here rather than right after ImageDescriptor.encoded.
    buffer?.dispose();
  }
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  SettingsSection _section = SettingsSection.account;

  /// The detail pane's own scroll position, separate from the page-level
  /// PrimaryScrollController the whole page used to share.
  final ScrollController _paneScroll = ScrollController();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';

  /// The row the search just jumped to, tinted until the user does anything
  /// else. Cleared on a timer so the page does not stay permanently marked.
  String? _highlightedRow;
  Timer? _highlightTimer;
  final GlobalKey _highlightTarget = GlobalKey();

  File? _profileImage;

  /// Everything the panes render and write lives in
  /// [settingsFormControllerProvider], not here: seventeen mutable fields on
  /// this class were the reason every pane had to be one of its methods.
  ///
  /// Watched, so the whole page still rebuilds on any form change exactly as
  /// `setState` made it.
  SettingsFormState get _form => ref.watch(settingsFormControllerProvider);

  /// Captured once, at init, so `dispose` can detach without reaching for `ref`
  /// on a widget that is on its way out.
  late final SettingsFormController _formController = ref.read(
    settingsFormControllerProvider.notifier,
  );

  /// iCloud sync card state (Private mode, macOS only). [_syncBusy] is true
  /// while an enable/disable/sync action is in flight; it drives the
  /// "Syncing…" label and disables the controls.
  PrivateSyncStatus? _syncStatus;

  /// What has and has not actually reached CloudKit. Null while loading, or
  /// when there is no local store to inspect.
  SyncDiagnostics? _syncDiagnostics;
  bool _syncBusy = false;

  @override
  void dispose() {
    // The form controller outlives this page; tell it the page is gone so it
    // stops applying pulls and rolling writes back into a UI nobody is looking
    // at. This is what `!mounted` used to do for the same code.
    _formController.detach();
    _highlightTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _paneScroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Deep-link: one request provider, one consumer. This used to be two
    // ad-hoc booleans handled asymmetrically — the privacy one here, the
    // subscription one in a build-time listener — and the subscription flag had
    // no producer left anywhere in lib/ or test/.
    final requested = ref.read(settingsSectionRequestProvider);
    if (requested != null) {
      _section = requested.section;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // The highlight has to wait for first build — there is no row to tint
        // or scroll to before the pane exists.
        if (requested.rowId != null) {
          _jumpToRow(requested.section, rowId: requested.rowId);
        }
        ref.read(settingsSectionRequestProvider.notifier).consume();
      });
    }
    unawaited(_refreshSyncStatus());
    // Reads SharedPreferences and the appearance controller into the form's
    // initial state, then kicks the synced read-back off UNAWAITED — even when
    // there are no preferences to read, otherwise a fresh install never
    // hydrates. `hydrate` is deliberately a step after the controller's own
    // build: the store is often already cached, in which case the read-back
    // resolves synchronously and a notifier may not assign `state` mid-build.
    _formController.hydrate();
  }

  @override
  Widget build(BuildContext context) {
    // A request that arrives while Settings is already open (the chat header's
    // engine chip, the coach page's banners) still has to land.
    ref.listen(settingsSectionRequestProvider, (_, target) {
      if (target != null) {
        _jumpToRow(target.section, rowId: target.rowId);
        ref.read(settingsSectionRequestProvider.notifier).consume();
      }
    });

    // The failure toast lives here rather than in the form controller: it needs
    // an Overlay and this page's own `mounted`, neither of which a provider has.
    // The controller raises a counter; every increment is one failed write.
    ref.listen(
      settingsFormControllerProvider.select((form) => form.saveFailures),
      (previous, next) {
        if (next <= (previous ?? 0)) return;
        showEvolveToast(
          context,
          message: t.settingsPage.settingSaveFailed,
          kind: EvolveToastKind.error,
        );
      },
    );

    final dataMode = ref.watch(activeDesktopDataModeProvider);
    final isPrivateMode = dataMode.isPrivate;

    // Filter available sections based on mode
    final availableSections = SettingsSection.values.where((section) {
      if (isPrivateMode && section == SettingsSection.subscription) {
        return false;
      }
      return true;
    }).toList();

    return SettingsHighlight(
      rowId: _highlightedRow,
      targetKey: _highlightTarget,
      child: CallbackShortcuts(
        bindings: {
          // ⌘F is the macOS convention for "find in this window", and the rail
          // is where the field lives.
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
              _searchFocus.requestFocus,
        },
        // autofocus so CallbackShortcuts actually receives key events: it only
        // hears them when something in its subtree holds focus, and with
        // `autofocus: false` the binding was dead until the user happened to
        // click a control first. Key events still bubble UP from here, so the
        // shell's own ⌘1–⌘5 / ⌘K bindings keep working.
        child: Focus(autofocus: true, child: _shell(availableSections)),
      ),
    );
  }

  Widget _shell(List<SettingsSection> availableSections) {
    return DesktopPage(
      title: t.settingsPage.pageTitle,
      // `pinned` is what makes the rail a rail. Without it the page header, the
      // sidebar and the pane all lived in one SingleChildScrollView, so on the
      // taller panes the destinations scrolled off the top — a sidebar that
      // scrolls away is not a sidebar. Now the page fills the viewport and the
      // pane owns the only scrollable.
      //
      // The page subtitle is gone with it: it listed the panes, directly above
      // the rail that lists them.
      pinned: true,
      child: EvolvePanel(
        padding: EdgeInsets.zero,
        child: Row(
          // `stretch`, not `start`. Under `start` the rail was only as tall as
          // its destinations and `const VerticalDivider(width: 1)` resolved to
          // 1x0 logical pixels — it had never painted anything.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 236, child: _rail(availableSections)),
            Container(
              width: 1,
              color: context.evolveColors.border.withValues(alpha: 0.6),
            ),
            Expanded(child: _paneBody()),
          ],
        ),
      ),
    );
  }

  /// The fixed source list: destinations grouped You / App / Data, with the
  /// expert pane separated at the bottom.
  Widget _rail(List<SettingsSection> sections) {
    final query = _searchQuery.trim();
    if (query.isNotEmpty) {
      return _searchRail(query);
    }

    final children = <Widget>[];
    SettingsSectionGroup? previous;

    for (final section in sections) {
      if (section.group != previous) {
        if (previous != null) children.add(const SizedBox(height: 10));
        final caption = section.group.caption;
        children.add(
          caption != null
              ? Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(11, 4, 11, 6),
                  child: Text(
                    caption,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: context.evolveColors.muted.withValues(alpha: 0.65),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(11, 2, 11, 8),
                  child: Container(
                    height: 1,
                    color: context.evolveColors.border.withValues(alpha: 0.5),
                  ),
                ),
        );
        previous = section.group;
      }
      children.add(
        _SettingsDestination(
          key: section.key,
          section: section,
          selected: section == _section,
          onTap: () => _selectSection(section),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _searchField(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
        // Docked below the destinations, outside the scrollable — the build
        // number should be readable without scrolling to find it.
        const SettingsAboutFooter(),
      ],
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 10),
      child: EvolveSearchField(
        controller: _searchController,
        focusNode: _searchFocus,
        hintText: t.settingsPage.searchPlaceholder,
        clearTooltip: t.settingsPage.searchClear,
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  /// The rail while a query is active: matching ROWS across every pane, not
  /// just the panes themselves. Searching only pane names would answer
  /// "language" with "General" and leave the user to hunt.
  Widget _searchRail(String query) {
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;
    final results = searchSettings(query, isPrivateMode: isPrivateMode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _searchField(),
        Expanded(
          child: results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(15, 6, 15, 0),
                  child: Text(
                    t.settingsPage.searchNoResults,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.evolveColors.muted,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final entry = results[index];
                    return SettingsSearchResult(
                      key: ValueKey('settings.result.${entry.id}'),
                      entry: entry,
                      onTap: () => _jumpToRow(entry.section, rowId: entry.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Opens [section] and, when [rowId] is given, tints that row so the eye
  /// lands on it.
  ///
  /// Shared by the sidebar's own result list and by the ⌘K palette, which
  /// deep-links through `settingsSectionRequestProvider`. Both are searching
  /// the same index for the same query, so "found it" has to mean the same
  /// thing in both — a palette hit that dumped the user at the top of General
  /// while the sidebar scrolled and highlighted was the tell that one of them
  /// was wrong.
  ///
  /// When called from the sidebar the query is deliberately left in the field:
  /// the user may want the next match, and clearing it would throw the result
  /// list away the instant they used it.
  void _jumpToRow(SettingsSection section, {String? rowId}) {
    _highlightTimer?.cancel();
    setState(() {
      _section = section;
      _highlightedRow = rowId;
    });
    if (_paneScroll.hasClients) _paneScroll.jumpTo(0);

    // Scroll the row into view once it exists. Two frames: the pane rebuilds on
    // the first, and the row's RenderObject is only attached after that.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _highlightTarget.currentContext;
      if (target != null) {
        unawaited(
          Scrollable.ensureVisible(
            target,
            alignment: 0.15,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          ),
        );
      }
    });

    if (rowId == null) return;
    _highlightTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _highlightedRow = null);
    });
  }

  /// The detail pane. Owns its own scroll position, which is reset on every
  /// pane change: the offset used to belong to the shared page-level
  /// PrimaryScrollController, so switching from a tall pane to a short one left
  /// the viewport parked past the end of the new content.
  Widget _paneBody() {
    return Scrollbar(
      controller: _paneScroll,
      child: SingleChildScrollView(
        controller: _paneScroll,
        padding: const EdgeInsets.all(22),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            // Capped rather than fluid. One column of full-width cards on a
            // 27-inch display gives 1,600px-wide rows whose label and control
            // are a screen apart.
            constraints: const BoxConstraints(maxWidth: 720),
            child: switch (_section) {
              SettingsSection.account => SettingsAccountPane(
                profileImage: _profileImage,
                onPickAvatar: _pickAvatar,
              ),
              SettingsSection.general => const SettingsGeneralPane(),
              SettingsSection.notifications =>
                const SettingsNotificationsPane(),
              SettingsSection.aiCoach => const SettingsAiCoachPane(),
              SettingsSection.dataBackup => SettingsDataBackupPane(
                syncStatus: _syncStatus,
                syncStatusLabel: _syncStatusLabel(),
                lastSyncedLabel: _lastSyncedLabel(),
                onResetSyncFromThisDevice: _onResetSyncFromThisDevice,
                onSyncToggle: _onSyncToggle,
                onSyncNow: _onSyncNow,
                onExport: _exportData,
                onImport: _importData,
                onDeletePrivateData: _deletePrivateData,
                onDeleteAccountOrReset: _showDeleteOrResetDialog,
              ),
              SettingsSection.privacy => const SettingsPrivacyPane(),
              SettingsSection.advanced => SettingsAdvancedPane(
                syncDiagnostics: _syncDiagnostics,
              ),
              SettingsSection.subscription => const SettingsSubscriptionPane(),
            },
          ),
        ),
      ),
    );
  }

  /// Adapter kept on the page for the one caller that opens the spinner after
  /// an await without a `mounted` check — see `_deletePrivateData`. Spelling it
  /// `showSettingsLoadingDialog(context, …)` there would newly trip
  /// `use_build_context_synchronously` on a gap this code has always had; the
  /// gap is pre-existing and untouched by this refactor.
  void _showLoadingDialog(String message) =>
      showSettingsLoadingDialog(context, message);

  void _selectSection(SettingsSection section) {
    if (section == _section) return;
    setState(() => _section = section);
    // Jump, not animate: changing panes is navigation, and a new document
    // should appear at its top immediately.
    if (_paneScroll.hasClients) _paneScroll.jumpTo(0);
  }

  Future<void> _exportData() async {
    try {
      final isPrivateMode = ref.read(activeDesktopDataModeProvider).isPrivate;
      final String json;
      final String fileName;
      final String shareText;
      final String doneTitle;

      if (isPrivateMode) {
        // Private mode: export the full local data space from the encrypted DB
        // (profile, settings, habits, logs, macro goals, categories, moods) in
        // the canonical cross-client shape (see exportSnapshot).
        final payload = await DesktopPrivateDb.instance.exportData();
        json = const JsonEncoder.withIndent('  ').convert(payload);
        fileName = 'evolve_private_export.json';
        shareText = t.settingsPage.exportPrivateShareText;
        doneTitle = t.privateData.exportDoneTitle;
      } else {
        // Cloud mode: emit a full, lossless snapshot of the user's Supabase
        // rows in the same canonical cross-client shape as the Private-mode
        // (and mobile) export, so every importer round-trips it (categories +
        // goals + logs + macro goals + moods + profile). Read straight from
        // the tables — the in-memory dashboard snapshot is lossy (no log
        // ids/streaks, no category list).
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;
        if (userId == null) {
          if (!mounted) return;
          showSettingsGate(
            context,
            t.settingsPage.exportDoneTitle,
            t.settingsPage.operationFailed,
          );
          return;
        }
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
        doneTitle = t.settingsPage.exportDoneTitle;
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
        if (path == null) return; // user cancelled the dialog — not an error
        if (!mounted) return;
        showSettingsGate(context, doneTitle, t.settingsPage.exportDoneSaved);
      } else if (Platform.isLinux) {
        await Clipboard.setData(ClipboardData(text: json));
        if (!mounted) return;
        showSettingsGate(
          context,
          doneTitle,
          isPrivateMode
              ? t.privateData.exportDoneClipboard
              : t.settingsPage.exportDoneClipboard,
        );
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
        if (!mounted) return;
        showSettingsGate(
          context,
          doneTitle,
          isPrivateMode
              ? t.privateData.exportDoneShare
              : t.settingsPage.exportDoneShare,
        );
      }
    } catch (error, stack) {
      AppLogger.error('Errore durante exportData', error, stack);
      if (!mounted) return;
      showSettingsGate(
        context,
        t.settingsPage.exportDoneTitle,
        t.settingsPage.operationFailed,
      );
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;

      final selectedFile = File(image.path);

      final Uint8List? croppedBytes = await showEvolveDialog<Uint8List>(
        context: context,
        builder: (context) =>
            EvolveImageCropDialog(image: FileImage(selectedFile)),
      );

      if (croppedBytes == null) return;
      await selectedFile.writeAsBytes(croppedBytes, flush: true);

      final isPrivateMode = ref.read(activeDesktopDataModeProvider).isPrivate;
      if (isPrivateMode) {
        final original = croppedBytes;
        final resized = await downscaleAvatarBytes(original);
        // Keep the source extension when the bytes were passed through, since
        // the downscale re-encodes to PNG whenever it does any work.
        final extension = identical(resized, original)
            ? p.extension(image.path)
            : '.png';
        final supportDir = await getApplicationSupportDirectory();
        final avatarDir = Directory(p.join(supportDir.path, 'private_profile'));
        await avatarDir.create(recursive: true);
        final selectedFile = File(p.join(avatarDir.path, 'avatar$extension'));
        await selectedFile.writeAsBytes(resized, flush: true);
        // Evict the (path-keyed) cached decode so the UI re-reads the new bytes.
        // The avatar is written to a STABLE path (avatar.<ext>), so an in-place
        // overwrite otherwise keeps showing the previous photo (settings avatar
        // + shell header) until cache pressure or restart. Mirrors mobile.
        await FileImage(selectedFile).evict();
        await ref
            .read(privateProfileProvider.notifier)
            .updateAvatar(selectedFile.path);
        setState(() => _profileImage = selectedFile);
      } else {
        setState(() => _profileImage = File(image.path));
      }
    } catch (error, stack) {
      AppLogger.error('Unable to pick desktop avatar', error, stack);
      if (mounted) {
        showSettingsGate(
          context,
          t.settingsPage.avatarGateTitle,
          t.settingsPage.avatarPickFailed,
        );
      }
    }
  }

  Future<void> _showDeleteOrResetDialog() async {
    final action = await showEvolveDialog<String>(
      context: context,
      builder: (context) => EvolveAlertDialog(
        icon: LucideIcons.userCog,
        title: Text(t.settingsPage.accountDataManagementTitle),
        content: Text(t.settingsPage.accountDataManagementContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.settingsPage.cancel),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'reset'),
            child: Text(t.settingsPage.resetDataAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: Text(t.settingsPage.deleteAccountAction),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'reset') {
      final confirmed = await confirmSettingsAction(
        context,
        title: t.settingsPage.confirmResetDataTitle,
        message: t.settingsPage.confirmResetDataMessage,
        destructive: true,
      );
      if (confirmed) await _resetData();
      return;
    }

    final confirmed = await confirmSettingsAction(
      context,
      title: t.settingsPage.confirmDeleteAccountTitle,
      message: t.settingsPage.confirmDeleteAccountMessage,
      destructive: true,
    );
    if (confirmed) await _deleteAccount();
  }

  Future<void> _resetData() async {
    showSettingsLoadingDialog(context, t.settingsPage.resetDataTitle);
    try {
      await ref.read(dashboardControllerProvider.notifier).resetData();
      await _formController.resetSettingsToDefaults();
      if (mounted) {
        Navigator.pop(context); // close loading dialog
        showSettingsResultDialog(
          context,
          t.settingsPage.resetDataTitle,
          t.settingsPage.resetDataSuccess,
        );
      }
    } catch (error, stack) {
      AppLogger.error('Unable to reset desktop data', error, stack);
      if (mounted) {
        Navigator.pop(context); // close loading dialog
        showSettingsResultDialog(
          context,
          t.settingsPage.resetDataTitle,
          t.settingsPage.operationFailed,
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (!ref.read(desktopAuthControllerProvider).isLoggedIn) {
      showSettingsResultDialog(
        context,
        t.settingsPage.deleteAccountGateTitle,
        t.settingsPage.gateRequiresActiveSession,
      );
      return;
    }
    // The spinner lives on the root navigator and outlives this page: deleting
    // the account signs out, which swaps the shell for the sign-in page and
    // disposes this state. gotrue notifies its auth subscribers BEFORE awaiting
    // the /logout round trip, so that swap lands while we are still suspended
    // here — a `mounted`-gated pop would leave a barrier-blocking, buttonless
    // spinner over the sign-in page with force-quit as the only way out. Hold
    // the navigator captured before the await and pop it unconditionally.
    final navigator = Navigator.of(context, rootNavigator: true);
    showSettingsLoadingDialog(context, t.settingsPage.deleteAccountGateTitle);
    try {
      await ref.read(desktopAuthControllerProvider.notifier).deleteAccount();
      navigator.pop();
      // Success disposes this page, so the confirmation is best-effort: it can
      // only render on the rare path where the swap has not landed yet.
      if (mounted) {
        showSettingsResultDialog(
          context,
          t.settingsPage.deleteAccountGateTitle,
          t.settingsPage.accountDeleted,
        );
      }
    } catch (error, stack) {
      AppLogger.error('Unable to delete desktop account', error, stack);
      navigator.pop();
      if (mounted) {
        showSettingsResultDialog(
          context,
          t.settingsPage.deleteAccountGateTitle,
          t.settingsPage.operationFailed,
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
      );

      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;

      final isPrivateMode =
          ref.read(activeDesktopDataModeProvider) == DesktopDataMode.private;

      final privateStore = DesktopPrivateDb.instance;
      final importService = DesktopBackupImportService(
        privateStore,
        isPrivateMode ? null : Supabase.instance.client,
      );

      // Private-mode import needs the encrypted local DB to open. If its key is
      // unreadable (after a migration or a code-signing change that rotated the
      // Keychain access group) the DB is LOCKED and every write throws
      // PrivateDatabaseLockedException. Detect it up front and offer an explicit
      // reset-and-import — the old local data is unrecoverable (its key is
      // gone), but the user's backup imports cleanly onto a fresh key.
      if (isPrivateMode && await privateStore.isDatabaseLocked()) {
        if (!mounted) return;
        final recover = await confirmSettingsAction(
          context,
          title: t.settingsPage.importLockedTitle,
          message: t.settingsPage.importLockedMessage,
          destructive: true,
          confirmLabel: t.settingsPage.importLockedResetButton,
        );
        if (!recover) return;
        await privateStore.resetLockedDatabase();
      }

      // 1. Preview (accepts both the web `.zip` and native `.json` backups).
      final preview = await importService.parsePreview(path);

      if (!mounted) return;

      // 2. Ask for Replace/Merge.
      final replaceExisting = await showImportModeDialog(context, preview);

      if (replaceExisting == null) return;
      if (!mounted) return;

      // Replace deletes every record not in the backup and, in private mode,
      // tombstones the deletions to iCloud — so a stale or partial backup can
      // take out a full history on every device at once. Require a second,
      // explicit confirmation that names the loss with a real count.
      if (replaceExisting) {
        final logCount = ref
            .read(dashboardControllerProvider)
            .habitLogs
            .values
            .fold<int>(0, (sum, day) => sum + day.length);
        final proceed = await confirmSettingsAction(
          context,
          title: t.settingsPage.importReplaceConfirmTitle,
          message: t.settingsPage.importReplaceConfirmMessage(count: logCount),
          confirmLabel: t.settingsPage.importReplaceConfirmButton,
          destructive: true,
        );
        if (!proceed) return;
        if (!mounted) return;
      }

      // 3. Execute
      showSettingsLoadingDialog(context, t.settingsPage.importInProgress);

      final stats = await importService.executeImport(
        canonicalData: preview.canonicalData,
        replaceExisting: replaceExisting,
        isPrivateMode: isPrivateMode,
        skipped: preview.skipped,
      );

      // Refresh dashboard + category/profile providers so imported data shows.
      ref.invalidate(desktopGoalCategoriesControllerProvider);
      if (isPrivateMode) ref.invalidate(privateProfileProvider);

      await Future.wait([
        ref.read(dashboardControllerProvider.notifier).refresh(),
        ref.read(desktopGoalCategoriesControllerProvider.future),
        if (isPrivateMode) ref.read(privateProfileProvider.future),
      ]);

      if (!mounted) return;
      Navigator.pop(context); // close loading

      // Per-entity outcome summary (added / updated / unchanged / skipped),
      // mirroring the mobile client's post-import dialog.
      await showImportResultDialog(context, stats);
    } catch (e, st) {
      AppLogger.error('Errore durante importData', e, st);
      if (!mounted) return;
      // Close loading if still open
      if (Navigator.canPop(context)) Navigator.pop(context);

      showEvolveToast(
        context,
        message: t.settingsPage.importError(error: e),
        kind: EvolveToastKind.error,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // iCloud sync (Private mode, macOS)
  // ---------------------------------------------------------------------------

  Future<void> _refreshSyncStatus() async {
    if (!Platform.isMacOS) return;
    if (!ref.read(activeDesktopDataModeProvider).isPrivate) return;
    final status = await ref.read(desktopPrivateSyncServiceProvider).status();
    if (!mounted) return;
    setState(() => _syncStatus = status);
    await _refreshSyncDiagnostics();
  }

  /// Read the pending/errored counts. Never allowed to throw: the settings page
  /// must still render if the private DB cannot be opened, which is one of the
  /// states a user comes here to diagnose.
  Future<void> _refreshSyncDiagnostics() async {
    if (!mounted) return;
    try {
      final d = await ref.read(desktopPrivateSyncServiceProvider).diagnostics();
      if (!mounted) return;
      setState(() => _syncDiagnostics = d);
    } catch (error, stack) {
      AppLogger.error('iCloud sync diagnostics failed', error, stack);
    }
  }

  Future<void> _runSyncAction(
    Future<PrivateSyncStatus> Function(PrivateSyncService service) action,
  ) async {
    if (_syncBusy) return;
    setState(() => _syncBusy = true);
    try {
      final status = await action(ref.read(desktopPrivateSyncServiceProvider));
      if (!mounted) return;
      setState(() => _syncStatus = status);
      // A pull writes straight to the encrypted DB — refresh the UI providers.
      if (status.appliedChanges > 0) {
        unawaited(ref.read(dashboardControllerProvider.notifier).refresh());
        ref.invalidate(privateAnalyticsDataProvider);
        ref.invalidate(privateProfileProvider);
        ref.invalidate(desktopGoalCategoriesControllerProvider);
      }
    } catch (error, stack) {
      AppLogger.error('iCloud sync action failed', error, stack);
      await _refreshSyncStatus(); // reflect the real state after a failure
    } finally {
      if (mounted) setState(() => _syncBusy = false);
    }
  }

  Future<void> _onSyncToggle(bool value) async {
    if (_syncBusy) return;
    if (value) {
      final accepted = await confirmSettingsAction(
        context,
        title: t.icloudSync.disclosureTitle,
        message: t.icloudSync.disclosureBody,
      );
      if (!accepted) return;
      await _runSyncAction((service) => service.enable());
      // enable() DEFERS rather than minting a rival key when the zone already
      // holds data this Mac has no key for. Explain and offer the deliberate
      // override instead of letting the toggle snap silently back to off.
      if (mounted && (_syncStatus?.keyPending ?? false)) {
        await _offerStartFresh();
      }
    } else {
      await _runSyncAction((service) => service.disable());
    }
    // The reactive data-loss banner watches desktopSyncEnabledProvider (a plain
    // prefs bool whose instance identity never changes); invalidate so it
    // clears/returns immediately instead of after an app restart.
    if (mounted) refreshDesktopSyncEnabled(ref);
  }

  Future<void> _onSyncNow() async {
    final status = _syncStatus;
    if (_syncBusy ||
        status == null ||
        !status.isEnabled ||
        !status.isAvailable) {
      return;
    }
    await _runSyncAction((service) => service.syncNow());
  }

  /// One-line status under the enable toggle.
  String _syncStatusLabel() {
    final status = _syncStatus;
    if (_syncBusy) return t.icloudSync.statusSyncing;
    if (status == null || !status.isEnabled) return t.icloudSync.statusOff;
    if (status.account == CloudAccountStatus.noAccount) {
      return t.icloudSync.statusNoAccount;
    }
    if (status.account != CloudAccountStatus.available) {
      return t.icloudSync.statusUnavailable;
    }
    if (status.keyPending) {
      return t.icloudSync.statusWaitingKey;
    }
    // A key split is never "Up to date": syncing runs, reports success and
    // applies nothing, which is exactly how it stayed invisible for weeks.
    //
    // The headline moved to the warning banner above this row, which also
    // carries the remedy. This line stays a STATUS — repeating the banner's
    // title three lines below it read as a rendering bug.
    if (status.undecryptableCount > 0) {
      return t.icloudSync.statusNotSynced;
    }
    if (!status.hasKey) {
      // Enabled + iCloud fine, but the E2E key hasn't arrived through iCloud
      // Keychain — typically an iPhone app that predates the shared keychain
      // group. The copy nudges the fix.
      return t.icloudSync.statusWaitingKeychain;
    }
    // "Up to date" is a claim about the DATA, not about the account, and it may
    // only be made when [SyncDiagnostics.isFullySynced] licenses it. Reaching
    // this line used to be enough: a device with thousands of rows that had
    // never left it, and a `last_full_sync_at` stamped moments ago by a push in
    // which every record failed, rendered exactly the same "Up to date" as a
    // healthy one. The per-count breakdown is on the details row below; the
    // headline's job is simply never to lie.
    final diagnostics = _syncDiagnostics;
    if (diagnostics != null && !diagnostics.isFullySynced) {
      return t.icloudSync.statusNotSynced;
    }
    return t.icloudSync.statusIdle;
  }

  /// The escape hatch from a permanent deferral: a Mac whose iCloud Keychain
  /// will never deliver the key would otherwise wait forever. Destructive, so
  /// never automatic — the user is told what it costs and has to agree.
  Future<void> _offerStartFresh() async {
    final accepted = await confirmSettingsAction(
      context,
      title: t.icloudSync.forceEnableTitle,
      message: t.icloudSync.forceEnableBody,
      destructive: true,
    );
    if (!accepted) return;
    await _runSyncAction((service) => service.enable(force: true));
  }

  Future<void> _onResetSyncFromThisDevice() async {
    final accepted = await confirmSettingsAction(
      context,
      title: t.icloudSync.resetFromDevice,
      message: t.icloudSync.resetFromDeviceConfirm,
      destructive: true,
    );
    if (!accepted) return;
    await _runSyncAction((service) => service.resetSyncFromThisDevice());
    if (mounted) {
      showEvolveToast(context, message: t.icloudSync.resetFromDeviceDone);
    }
  }

  /// "Never synced" or "Last synced `<date> <time>`" under the Sync-now row.
  String _lastSyncedLabel() {
    final at = _syncStatus?.lastSyncedAt;
    if (at == null) return t.icloudSync.lastSyncedNever;
    final local = at.toLocal();
    final materialLocalizations = MaterialLocalizations.of(context);
    final date = materialLocalizations.formatShortDate(local);
    final time = materialLocalizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: _form.timeFormat24h,
    );
    return t.icloudSync.lastSyncedAt(time: '$date $time');
  }

  Future<void> _deletePrivateData() async {
    // With sync on, deleting is a FULL reset (local + the user's iCloud copy);
    // the disclosure must also say other devices keep their local copy.
    final syncEnabled = _syncStatus?.isEnabled ?? false;
    final message = syncEnabled
        ? '${t.privateData.deleteMessage}\n\n${t.icloudSync.deleteSyncNote}'
        : t.privateData.deleteMessage;
    final confirmed = await confirmSettingsAction(
      context,
      title: t.privateData.deleteTitle,
      message: message,
      destructive: true,
    );
    if (!confirmed) return;

    _showLoadingDialog(t.privateData.deleteTitle);
    try {
      // Order mirrors mobile: queue/perform the cloud-zone wipe and remove the
      // shared keychain secrets FIRST (requestFullReset sets pending_zone_wipe,
      // which deleteAllPrivateData preserves if the wipe must wait for
      // connectivity), then wipe the local space.
      // Best-effort: a failure here must never block the local data wipe below.
      try {
        await ref.read(desktopPrivateSyncServiceProvider).requestFullReset();
      } catch (error, stack) {
        AppLogger.error('iCloud full reset failed during delete', error, stack);
      }
      // Wipe all private data but stay in Private mode with a fresh, empty
      // profile (mirrors the mobile client — non-destructive to the mode).
      await DesktopPrivateDb.instance.deleteAllPrivateData();
      await ref.read(dashboardControllerProvider.notifier).refresh();
      ref.invalidate(privateProfileProvider);
      ref.invalidate(desktopGoalCategoriesControllerProvider);
      // Cancel the now-orphaned per-habit reminders: the habits were just wiped,
      // so re-syncing with the (empty) habit list clears every scheduled
      // notification. Without this, deleted habits keep firing reminders (and
      // their Done/Skip actions would re-write phantom logs). Mirrors mobile's
      // cancelAll() on delete.
      await _formController.syncNotifications();
      await _refreshSyncStatus();
      if (mounted) {
        Navigator.pop(context); // close loading dialog
        showSettingsResultDialog(
          context,
          t.privateData.deleteTitle,
          t.privateData.deleteSuccess,
        );
      }
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
        await ref.read(dashboardControllerProvider.notifier).refresh();
        ref.invalidate(privateProfileProvider);
        ref.invalidate(desktopGoalCategoriesControllerProvider);
        await _refreshSyncStatus();
        if (mounted) {
          Navigator.pop(context); // close loading dialog
          showSettingsResultDialog(
            context,
            t.privateData.deleteTitle,
            t.privateData.deleteSuccess,
          );
        }
      } catch (error, stack) {
        AppLogger.error(
          'Unable to reset locked private database',
          error,
          stack,
        );
        if (mounted) {
          Navigator.pop(context); // close loading dialog
          showSettingsResultDialog(
            context,
            t.privateData.deleteTitle,
            t.privateData.deleteFailed,
          );
        }
      }
    } catch (error, stack) {
      AppLogger.error('Unable to delete private database', error, stack);
      if (mounted) {
        Navigator.pop(context); // close loading dialog
        showSettingsResultDialog(
          context,
          t.privateData.deleteTitle,
          t.privateData.deleteFailed,
        );
      }
    }
  }
}

class _SettingsDestination extends StatelessWidget {
  const _SettingsDestination({
    super.key,
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final SettingsSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final contentColor = selected
        ? Theme.of(context).colorScheme.onPrimary
        : context.evolveColors.muted;
    // `selected` was conveyed by accent fill and FontWeight.w800 alone, which
    // VoiceOver cannot see: the rail read as six identical buttons with no
    // indication of where you were. `button` is explicit because the InkWell
    // sits under a Material of type transparency, which does not imply it.
    return Semantics(
      selected: selected,
      button: true,
      label: section.label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: selected ? context.evolveAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              hoverColor: selected
                  ? Colors.transparent
                  : context.evolveColors.panel.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(section.icon, color: contentColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      // German and Arabic overflow the 171px text box; without a
                      // tooltip an ellipsised destination is unreadable and
                      // unidentifiable.
                      child: Tooltip(
                        message: section.label,
                        waitDuration: const Duration(milliseconds: 600),
                        child: Text(
                          section.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            letterSpacing: -0.2,
                            color: contentColor,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
