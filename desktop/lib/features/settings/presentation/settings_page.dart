import 'package:evolve_legal/evolve_legal.dart';
import 'package:evolve_desktop/core/desktop_backup_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/app/localization/desktop_locale_controller.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/calendar_view_preference.dart';
import 'package:evolve_desktop/core/tutorial_provider.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/import_merge_stats.dart';
import 'package:evolve_desktop/core/desktop_private_sync_service.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/application/consent_controller.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/ai_coach/application/coach_consent_controller.dart';
import 'package:evolve_desktop/features/ai_coach/presentation/coach_settings_panels.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/settings/application/desktop_biometric_controller.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/settings/application/desktop_synced_settings.dart';
import 'package:evolve_desktop/features/settings/data/desktop_notification_service.dart';
import 'package:evolve_desktop/features/settings/data/desktop_system_settings_service.dart';
import 'package:evolve_desktop/features/settings/presentation/app_logs_dialog.dart';
import 'package:evolve_desktop/features/statistics/data/private_analytics_source.dart';
import 'package:evolve_desktop/features/settings/presentation/pro_features_modal.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_search.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_about_footer.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_row_kit.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_search_widgets.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:evolve_desktop/shared/widgets/evolve_image_crop_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:evolve_desktop/features/auth/application/desktop_profile_controller.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

/// Canonical language codes for the Settings language picker, in picker order.
/// These are the values persisted to `pref_language` and to the synced
/// `language` setting, and the ones [SettingsCodec.normalizeLanguage] — the one
/// parser both apps share — resolves to.
const List<String> _kLanguageCodes = [
  SettingsCodec.languageSystem,
  ...SettingsCodec.languageCodes,
];

/// Calendar-view codes in picker order.
const List<String> _kCalendarViewCodes = [
  kCalendarViewMonth,
  kCalendarViewWeek,
  kCalendarViewYear,
  kCalendarViewLife,
];

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

/// One `icon + text` line of an import summary.
Widget _importSummaryRow(BuildContext context, IconData icon, String text) {
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
                _importSummaryRow(
                  context,
                  LucideIcons.check,
                  t.settingsPage.importHabitsCount(count: preview.habitsCount),
                ),
                _importSummaryRow(
                  context,
                  LucideIcons.history,
                  t.settingsPage.importLogsCount(count: preview.logsCount),
                ),
                _importSummaryRow(
                  context,
                  LucideIcons.target,
                  t.settingsPage.importMacroGoalsCount(
                    count: preview.macroGoalsCount,
                  ),
                ),
                _importSummaryRow(
                  context,
                  LucideIcons.folder,
                  t.settingsPage.importCategoriesCount(
                    count: preview.categoriesCount,
                  ),
                ),
                _importSummaryRow(
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

  /// The canonical theme CODE ('light'/'dark'/'system'), not a bool.
  ///
  /// It used to be `bool _darkMode`, and every write derived from it collapsed
  /// `'system'` — the value the schema permits and the one every user who never
  /// picked a theme has — into a concrete theme. The prefs mirror is what
  /// `DesktopAppearanceController.build()` reads on the next cold start, so a
  /// collapsed mirror destroyed "follow system" permanently on a Mac that never
  /// completes a pull.
  String _themeMode = SettingsCodec.themeSystem;
  bool _timeFormat24h = true;
  bool _habitReminders = true;
  bool _eveningReview = true;
  bool _goalDeadlines = true;
  // FALSE, matching both the `?? false` a few lines into initState and mobile's
  // AppSettings. They used to initialise to `true` here, and because initState
  // early-returns when SharedPreferences is absent, the field initialiser won
  // on a fresh install — so a first-launch Mac pushed `true` into the synced
  // row and switched both features on for an iPhone that had them off.
  //
  // Neither has a UI row any more (nothing on either platform delivers an AI
  // insight or a weekly report), but both still sync, so the value this holds
  // still reaches the phone.
  bool _aiInsights = false;
  bool _weeklyReport = false;
  bool _crashReports = true;
  // Experience/Pro toggles (mobile parity — same keys and defaults as
  // mobile's AppSettings: ai/focus/deep-work OFF, milestones ON).
  bool _aiSuggestions = false;
  bool _focusMode = false;
  bool _milestones = true;
  bool _deepWorkInsights = false;
  // Canonical CODES, not display labels: these are what gets persisted, and the
  // pickers match on them, so they must not move when the UI language does.
  String _calendarView = kCalendarViewWeek;
  String _language = SettingsCodec.languageSystem;
  // The canonical defaults, from the shared codec — these MUST match the
  // `profiles` schema DEFAULTs and mobile. They used to read '08:00'/'20:30'
  // here, and because initState early-returns when SharedPreferences is absent
  // they won whenever prefs were empty: a first-launch Mac dragged the iPhone's
  // briefs 60 and 30 minutes earlier the first time any toggle was touched.
  String _morningTime = SettingsCodec.defaultMorningBriefTime;
  String _eveningTime = SettingsCodec.defaultEveningReviewTime;
  // The accent SEED, not a theme token. `EvolveColors.primaryStrong` is chrome
  // that legitimately stays #FAFAFA; borrowing it here made the page's idea of
  // "no accent yet" a third independent literal. initState overwrites this from
  // the controller, so the practical effect is nil — but the drift it invites
  // is exactly how the Mac and the iPhone ended up on different whites.
  Color _accent = DesktopAppearanceController.defaultAccent;
  File? _profileImage;

  /// Whether the synced store has answered at least once this session.
  ///
  /// The read is kicked off UNAWAITED from `initState`, and in Private mode it
  /// costs an encrypted-DB open plus a Keychain round-trip — the page is fully
  /// interactive throughout. Without this latch, `_applySyncedSettings` came
  /// back and overwrote every field, so a toggle flipped during that window
  /// snapped back on screen and in the prefs mirror while `_syncProfile` had
  /// already written the new value to the store: the UI then disagreed with
  /// what was stored for the rest of the session, silently.
  bool _syncedLoaded = false;

  /// Synced keys the user edited BEFORE the first load landed.
  ///
  /// The first load skips these and applies everything else, so an edit already
  /// made wins over what the load happened to find, while a key the user never
  /// touched still hydrates. Cleared the moment [_syncedLoaded] latches —
  /// keeping them would make the user's own earlier tap suppress every later
  /// pull of that key, which is the "my iPhone change never reaches the Mac"
  /// bug wearing the fix's clothes. Mobile's `settings_provider.dart` uses the
  /// same pair; `test/settings_hydration_clobber_test.dart` pins both halves.
  ///
  /// In Supabase mode nothing ever clears it, because `_applySyncedSettings` is
  /// a no-op there — harmless, since that mode never consults it, and it is
  /// bounded by the number of synced keys either way.
  final Set<String> _preloadEdits = <String>{};

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
    final preferences = ref.read(sharedPreferencesProvider);
    final appearance = ref.read(desktopAppearanceControllerProvider);
    _themeMode = DesktopAppearanceController.themeCodeFor(appearance.themeMode);
    _accent = appearance.accentColor;
    // The synced store is the authority; the prefs below are only the local
    // mirror used until it answers. Kick the read-back off even when there are
    // no preferences to read, otherwise a fresh install never hydrates.
    if (preferences == null) {
      unawaited(_loadProfilePreferences());
      return;
    }
    _timeFormat24h = preferences.getBool('pref_time_format_24h') ?? true;
    _habitReminders = preferences.getBool('notif_habit_reminders') ?? true;
    _eveningReview = preferences.getBool('notif_evening_review') ?? true;
    _goalDeadlines = preferences.getBool('notif_goal_deadlines') ?? true;
    // Mobile parity: AI insights and weekly reports default OFF.
    _aiInsights = preferences.getBool('notif_ai_insights') ?? false;
    _weeklyReport = preferences.getBool('notif_weekly_reports') ?? false;
    _crashReports = preferences.getBool('has_sentry_consent') ?? true;
    _aiSuggestions = preferences.getBool('pref_ai_suggestions') ?? false;
    _focusMode = preferences.getBool('pref_focus_mode') ?? false;
    _milestones = preferences.getBool('pref_milestones') ?? true;
    _deepWorkInsights = preferences.getBool('pref_deep_work_insights') ?? false;
    // The pref stores the canonical CODE ('mese'…); older builds stored the
    // display label — normalizeCalendarViewCode accepts both.
    _calendarView = normalizeCalendarViewCode(
      preferences.getString('pref_default_calendar_view'),
    );
    _language = SettingsCodec.normalizeLanguage(
      preferences.getString('pref_language') ??
          preferences.getString('language'),
    );
    // NOTE the two different names on purpose: 'notif_morning_brief_time' is the
    // SharedPreferences key, 'morning_brief_time' is the DB column / synced key.
    // The legacy prefs fallback below reads the OLD prefs spelling, not the
    // column — conflating them would make a prefs read look like a store read.
    _morningTime =
        SettingsCodec.normalizeTimeOfDay(
          preferences.getString('notif_morning_brief_time') ??
              preferences.getString('morning_brief_time'),
        ) ??
        SettingsCodec.defaultMorningBriefTime;
    _eveningTime =
        SettingsCodec.normalizeTimeOfDay(
          preferences.getString('notif_evening_review_time') ??
              preferences.getString('evening_review_time'),
        ) ??
        SettingsCodec.defaultEveningReviewTime;
    unawaited(_loadProfilePreferences());
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

    // A sync pull invalidates the synced settings; re-hydrate the visible fields
    // so a preference changed on the iPhone shows up here without a restart.
    ref.listen(desktopSyncedSettingsProvider, (_, next) {
      final values = next.value;
      if (values != null && values.isNotEmpty) {
        unawaited(_applySyncedSettings(values));
      }
    });

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
              SettingsSection.account => _account(),
              SettingsSection.general => _general(),
              SettingsSection.notifications => _notifications(),
              SettingsSection.aiCoach => _aiCoach(),
              SettingsSection.dataBackup => _dataBackup(),
              SettingsSection.privacy => _privacy(),
              SettingsSection.advanced => _advanced(),
              SettingsSection.subscription => const _SubscriptionSettings(),
            },
          ),
        ),
      ),
    );
  }

  void _selectSection(SettingsSection section) {
    if (section == _section) return;
    setState(() => _section = section);
    // Jump, not animate: changing panes is navigation, and a new document
    // should appear at its top immediately.
    if (_paneScroll.hasClients) _paneScroll.jumpTo(0);
  }

  Widget _account() {
    final auth = ref.watch(desktopAuthControllerProvider);
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(section: SettingsSection.account),
        const SizedBox(height: 20),
        _ProfileCard(
          user: auth.user,
          image: _profileImage,
          isPro: ref.watch(desktopIsProProvider),
          onPickAvatar: _pickAvatar,
          isPrivateMode: isPrivateMode,
          privateProfile: isPrivateMode
              ? ref.watch(privateProfileProvider).value
              : null,
        ),
        const SizedBox(height: 24),
        _SettingsColumn(
          groups: [
            // Editable in BOTH modes. The dialog these replace was gated
            // behind `if (!isPrivateMode)`, so a Private-mode user could never
            // change their own name or birthday — while
            // `privateProfileProvider.updateProfile` sat fully implemented and
            // unreachable.
            SettingsGroup(
              title: t.settingsPage.personalInfo,
              children: const [_PersonalInfoRows()],
            ),
            if (!isPrivateMode)
              SettingsGroup(
                title: t.settingsPage.groupSignIn,
                children: [
                  SettingsInfoRow(
                    id: 'account.email',
                    label: t.settingsPage.email,
                    value:
                        auth.user?.email ?? t.settingsPage.sessionUnavailable,
                  ),
                  // Moved here from Privacy › "Access protection". Credential
                  // management is account lifecycle, and scattering it across
                  // two panes is what made "Privacy" mean nothing in
                  // particular.
                  SettingsActionRow(
                    id: 'account.changePassword',
                    title: t.settingsPage.changePassword,
                    detail: t.settingsPage.changePasswordDetail,
                    state: auth.isLoggedIn
                        ? const SettingsRowState.enabled()
                        : SettingsRowState.disabled(
                            t.settingsPage.gateRequiresActiveSession,
                          ),
                    onTap: () => showEvolveDialog<void>(
                      context: context,
                      builder: (context) => const _ChangePasswordDialog(),
                    ),
                  ),
                  SettingsActionRow(
                    id: 'account.resetConsent',
                    title: t.settingsPage.reviewInitialConsent,
                    detail: t.settingsPage.reviewInitialConsentDetail,
                    onTap: _reviewConsent,
                  ),
                ],
              ),
            // One row where there were two. "Account" and "Data repository" sat
            // consecutively encoding the same fact — which data mode you are in
            // — and the second said it in vendor language ("Supabase with
            // encrypted cache"), duplicating the profile card directly above.
            // Untitled: the card holds one row, and a group heading that reads
            // identically to the row inside it is noise.
            SettingsGroup(
              children: [
                SettingsInfoRow(
                  id: 'account.dataStorage',
                  label: t.settingsPage.dataStorage,
                  value: isPrivateMode
                      ? t.settingsPage.dataStorageThisMac
                      : t.settingsPage.dataStorageAccount,
                ),
              ],
            ),
            // "Update avatar" is gone. In account mode — the ONLY mode it
            // rendered in — `_pickAvatar` just sets a widget-local File that is
            // never uploaded, never written to `profiles` and never restored at
            // init, so the picture reverted on the next rebuild. The avatar in
            // the card above is the one working affordance; see TO_SIMO_DO.md
            // for the missing account-mode upload path.
          ],
        ),
        const SizedBox(height: 18),
        if (!isPrivateMode)
          SettingsDestructiveButton(
            label: t.settingsPage.signOut,
            caption: auth.isLoggedIn
                ? t.settingsPage.signOutDetailActive
                : t.settingsPage.availableWithActiveSession,
            onTap: auth.isLoggedIn
                ? () => _confirmSignOut()
                : () => _showGate(
                    t.settingsPage.gateLogout,
                    t.settingsPage.gateRequiresActiveSession,
                  ),
          )
        else
          SettingsDestructiveButton(
            label: t.settingsPage.goToLogin,
            caption: t.settingsPage.goToLoginDetail,
            onTap: () {
              ref.read(desktopAuthControllerProvider.notifier).goToLogin();
            },
          ),
      ],
    );
  }

  Widget _general() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(section: SettingsSection.general),
        const SizedBox(height: 20),
        _SettingsColumn(
          groups: [
            SettingsGroup(
              title: t.settingsPage.groupAppearance,
              children: [
                // Three options, not a switch. A binary control cannot express
                // `'system'` — which the schema permits and which every user
                // who never picked a theme actually has — so one touch of the
                // old switch wrote a concrete 'dark'/'light' to the synced
                // store, pinned the iPhone too, and left no way back to "follow
                // system" from the Mac.
                SettingsSelectRow<String>(
                  id: 'general.theme',
                  label: t.settingsPage.themeMode,
                  value: _themeMode,
                  options: [
                    for (final code in SettingsCodec.themeModes)
                      EvolveSelectOption(
                        value: code,
                        label: _themeModeOptionLabel(code),
                      ),
                  ],
                  onChanged: (value) {
                    // The controller is mutated BEFORE the write is attempted,
                    // so the rollback has to put it back too — reverting only
                    // the row would leave the whole app repainted in a theme
                    // that was never stored.
                    final previousMode = ref
                        .read(desktopAppearanceControllerProvider)
                        .themeMode;
                    ref
                        .read(desktopAppearanceControllerProvider.notifier)
                        .setThemeMode(
                          DesktopAppearanceController.themeModeFor(value),
                        );
                    _setString(
                      'pref_theme_mode',
                      value,
                      (v) => _themeMode = v,
                      previous: _themeMode,
                      profileColumn: 'theme_mode',
                      profileValue: value,
                      alsoRevert: () => ref
                          .read(desktopAppearanceControllerProvider.notifier)
                          .setThemeMode(previousMode),
                    );
                  },
                ),
                // Accent finally sits beside Theme. "Appearance and visuals"
                // used to hold Theme alone while the most appearance-like
                // control on the page lived one card further down, under
                // "Calendar, experience and language".
                SettingsColorRow(
                  id: 'general.accent',
                  icon: LucideIcons.palette,
                  label: t.settingsPage.accentColor,
                  detail: t.settingsPage.accentColorDetail,
                  selected: _accent,
                  onChanged: (color) {
                    // This row does NOT go through `_setBool`/`_setString`, so
                    // it needs its own rollback — a fix that only touched those
                    // two helpers would leave the accent, one of the two
                    // symptoms this whole effort started from, still failing in
                    // silence.
                    final previousAccent = ref
                        .read(desktopAppearanceControllerProvider)
                        .accentColor;
                    ref
                        .read(desktopAppearanceControllerProvider.notifier)
                        .setAccentColor(color);
                    final accent = ref.read(
                      desktopAppearanceControllerProvider.select(
                        (appearance) => appearance.accentColor,
                      ),
                    );
                    setState(() => _accent = accent);
                    unawaited(
                      _persistOrRollback(
                        values: {'accent_color': dashboardColorToHex(accent)},
                        revert: () {
                          ref
                              .read(
                                desktopAppearanceControllerProvider.notifier,
                              )
                              .setAccentColor(previousAccent);
                          _accent = previousAccent;
                        },
                      ),
                    );
                  },
                  // Custom accent color is Pro (mobile parity). Private mode is
                  // always Pro via desktopIsProProvider, so it's never locked.
                  customLocked: !ref.watch(desktopIsProProvider),
                  onCustomLocked: () =>
                      unawaited(showProFeaturesDialog(context, ref)),
                ),
              ],
            ),
            SettingsGroup(
              title: t.settingsPage.groupLanguageFormats,
              // The code has always implemented this distinction and the UI has
              // never shown it: these four dual-write the profiles row, so they
              // reach the paired iPhone.
              footnote: t.settingsPage.syncsToIPhoneNote,
              children: [
                SettingsSelectRow<String>(
                  id: 'general.calendarView',
                  label: t.settingsPage.defaultCalendarView,
                  value: _calendarView,
                  options: [
                    for (final code in _kCalendarViewCodes)
                      EvolveSelectOption(
                        value: code,
                        label: _calendarViewOptionLabel(code),
                      ),
                  ],
                  // Persist the canonical CODE ('mese'…) in BOTH
                  // SharedPreferences and the profiles row (they used to
                  // diverge: prefs got the label, the profile the code).
                  onChanged: (value) => _setString(
                    'pref_default_calendar_view',
                    value,
                    (v) => _calendarView = v,
                    previous: _calendarView,
                    profileColumn: 'pref_default_calendar_view',
                  ),
                ),
                SettingsSelectRow<String>(
                  id: 'general.language',
                  label: t.settingsPage.language,
                  value: _language,
                  options: [
                    for (final code in _kLanguageCodes)
                      EvolveSelectOption(
                        value: code,
                        label: _languageOptionLabel(code),
                      ),
                  ],
                  onChanged: (value) => _setString(
                    'pref_language',
                    value,
                    // Takes the value it is HANDED, not the tapped one: on a
                    // failed write this same callback is re-run with the
                    // previous language, and the live locale controller has to
                    // come back with it or the app keeps speaking a language
                    // nothing stored.
                    (v) {
                      _language = v;
                      ref
                          .read(desktopLocaleControllerProvider.notifier)
                          .setLanguage(v);
                    },
                    previous: _language,
                    profileColumn: 'language',
                    profileValue: value,
                  ),
                ),
                SettingsSwitchRow(
                  id: 'general.timeFormat',
                  label: t.settingsPage.timeFormat24h,
                  detail: t.settingsPage.timeFormat24hDetail,
                  value: _timeFormat24h,
                  onChanged: (value) => _setBool(
                    'pref_time_format_24h',
                    value,
                    (v) => _timeFormat24h = v,
                    profileColumn: 'pref_time_format_24h',
                  ),
                ),
              ],
            ),
            SettingsGroup(
              title: t.settingsPage.groupGettingStarted,
              children: [
                SettingsActionRow(
                  id: 'general.replayTour',
                  title: t.settingsPage.resetTutorial,
                  detail: t.settingsPage.resetTutorialDetail,
                  onTap: _resetTutorials,
                ),
              ],
            ),
            // Gone from this pane:
            //   * "AI & SYSTEM" entirely. AI Suggestions, Milestones and Deep
            //     Work Insights have no consumer on EITHER platform — they are
            //     internal AppSettings fields that were surfaced as switches,
            //     and iOS never showed them. AI Suggestions also carried the
            //     page's only PRO badge, so the Pro signal was attached to the
            //     one control that did nothing. The pref keys and profile
            //     columns stay; only the rows go.
            //   * Focus mode, to Notifications, where the switches it silences
            //     live.
            //   * App Logs, to Advanced. A diagnostics viewer does not belong
            //     under "Calendar, experience and language".
          ],
        ),
      ],
    );
  }

  Widget _notifications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(section: SettingsSection.notifications),
        const SizedBox(height: 20),
        _SettingsColumn(
          groups: [
            // Focus mode leads the pane because it overrides everything under
            // it. It used to live in the Application pane's "AI & SYSTEM" card,
            // three destinations away from the switches it silences.
            SettingsGroup(
              title: t.settingsPage.groupFocus,
              children: [
                SettingsSwitchRow(
                  id: 'notifications.focusMode',
                  label: t.settingsPage.focusMode,
                  detail: t.settingsPage.focusModeDetail,
                  value: _focusMode,
                  onChanged: (value) {
                    // Stays local in account mode (profileColumn is null
                    // there), so this deliberately makes no cross-device claim.
                    _setBool(
                      'pref_focus_mode',
                      value,
                      (v) => _focusMode = v,
                      profileColumn:
                          ref.read(activeDesktopDataModeProvider).isPrivate
                          ? 'pref_focus_mode'
                          : null,
                    );
                    unawaited(_syncNotifications());
                  },
                ),
              ],
            ),
            SettingsGroup(
              title: t.settingsPage.groupDailyReminders,
              footnote: t.settingsPage.perHabitRemindersNote,
              children: [
                SettingsSwitchRow(
                  id: 'notifications.morningBrief',
                  label: t.settingsPage.habitReminders,
                  detail: t.settingsPage.habitRemindersDetail,
                  value: _habitReminders,
                  onChanged: (value) => _setNotificationBool(
                    key: 'notif_habit_reminders',
                    value: value,
                    update: (v) => _habitReminders = v,
                    profileColumn: 'notif_habit_reminders',
                    requestPermissions: value,
                  ),
                ),
                // Always rendered, disabled when its switch is off. It used to
                // be `if (_habitReminders)`, so the pane changed height under
                // the cursor and the rows below jumped on every toggle.
                SettingsTimeRow(
                  id: 'notifications.morningBriefTime',
                  label: t.settingsPage.morningBriefTime,
                  value: _morningTime,
                  use24hFormat: _timeFormat24h,
                  state: _habitReminders
                      ? const SettingsRowState.enabled()
                      : SettingsRowState.disabled(
                          t.settingsPage.disabledTurnOnFirst,
                        ),
                  onChanged: (value) => _setNotificationString(
                    'notif_morning_brief_time',
                    value,
                    (v) => _morningTime = v,
                    previous: _morningTime,
                    profileColumn: 'morning_brief_time',
                  ),
                ),
                SettingsSwitchRow(
                  id: 'notifications.eveningReview',
                  label: t.settingsPage.eveningReview,
                  detail: t.settingsPage.eveningReviewDetail,
                  value: _eveningReview,
                  onChanged: (value) => _setNotificationBool(
                    key: 'notif_evening_review',
                    value: value,
                    update: (v) => _eveningReview = v,
                    profileColumn: 'notif_evening_review',
                    requestPermissions: value,
                  ),
                ),
                SettingsTimeRow(
                  id: 'notifications.eveningReviewTime',
                  label: t.settingsPage.eveningReviewTime,
                  value: _eveningTime,
                  use24hFormat: _timeFormat24h,
                  state: _eveningReview
                      ? const SettingsRowState.enabled()
                      : SettingsRowState.disabled(
                          t.settingsPage.disabledTurnOnFirst,
                        ),
                  onChanged: (value) => _setNotificationString(
                    'notif_evening_review_time',
                    value,
                    (v) => _eveningTime = v,
                    previous: _eveningTime,
                    profileColumn: 'evening_review_time',
                  ),
                ),
                if (_focusMode)
                  SettingsWarningRow(
                    title: t.settingsPage.focusModeOnTitle,
                    body: t.settingsPage.focusModeOnBody,
                    destructive: false,
                  ),
              ],
            ),
            // "Insights and reports" is gone: notif_ai_insights and
            // notif_weekly_reports have no scheduler on macOS
            // (DesktopNotificationService.sync takes neither) and an empty
            // placeholder on iOS, so nothing was ever delivered for either.
            // Both keys and both profile columns stay — the iPhone still
            // round-trips them.
            SettingsGroup(
              title: t.settingsPage.groupDelivery,
              footnote: DesktopNotificationService.instance.platformSummary,
              children: [
                SettingsActionRow(
                  id: 'notifications.permission',
                  icon: LucideIcons.bell,
                  title: t.settingsPage.requestNotificationPermissions,
                  detail: t.settingsPage.requestNotificationPermissionsDetail,
                  onTap: _requestNotificationPermissions,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Where the user's data is copied, how it gets in and out, and how it is
  /// erased.
  ///
  /// New pane. All of this used to be crammed into Privacy alongside the device
  /// lock, account credentials and crash-report consent. Note that the pane
  /// exists in BOTH data modes: in account mode the iCloud card collapses to a
  /// single status row rather than vanishing, so the dashboard's SyncOffBanner
  /// has a deep-link target that does not disappear, and so export, import and
  /// erase are never stranded.
  Widget _dataBackup() {
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;
    final syncEnabled = _syncStatus?.isEnabled ?? false;
    final undecryptable = _syncStatus?.undecryptableCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(section: SettingsSection.dataBackup),
        const SizedBox(height: 20),
        _SettingsColumn(
          groups: [
            if (isPrivateMode && Platform.isMacOS)
              SettingsGroup(
                title: t.icloudSync.title,
                footnote: t.icloudSync.disclosureBody,
                children: [
                  // Promoted from an ordinary action row that sat two below
                  // "Sync now" and looked identical to it — for the single most
                  // cross-device-destructive action on the page. iOS already
                  // shows this as a card.
                  if (undecryptable > 0)
                    SettingsWarningRow(
                      title: t.icloudSync.keySplitTitle,
                      body: t.icloudSync.keySplitBody(count: undecryptable),
                      actionLabel: t.icloudSync.resetFromDevice,
                      onAction: _onResetSyncFromThisDevice,
                    ),
                  SettingsSwitchRow(
                    id: 'data.icloudSync',
                    label: t.icloudSync.enableTitle,
                    detail: _syncStatusLabel(),
                    value: syncEnabled,
                    onChanged: _onSyncToggle,
                  ),
                  SettingsActionRow(
                    id: 'data.syncNow',
                    title: t.icloudSync.syncNow,
                    detail: _lastSyncedLabel(),
                    // It used to render fully tappable and then return early in
                    // exactly these states, so the click did nothing and said
                    // nothing. iOS disables it; now so do we.
                    state: syncEnabled
                        ? const SettingsRowState.enabled()
                        : SettingsRowState.disabled(
                            t.icloudSync.syncNowNeedsSync,
                          ),
                    onTap: _onSyncNow,
                  ),
                ],
              )
            else
              SettingsGroup(
                title: t.icloudSync.title,
                children: [
                  SettingsInfoRow(
                    id: 'data.accountSync',
                    label: t.icloudSync.title,
                    value: isPrivateMode
                        ? t.icloudSync.unavailablePlatform
                        : t.settingsPage.accountSyncOn,
                  ),
                ],
              ),
            SettingsGroup(
              title: t.settingsPage.groupBackups,
              children: [
                SettingsActionRow(
                  id: 'data.export',
                  title: t.settingsPage.exportData,
                  detail: t.settingsPage.exportDataDetail,
                  onTap: _exportData,
                ),
                SettingsActionRow(
                  id: 'data.import',
                  title: t.settingsPage.importData,
                  detail: t.settingsPage.importDataDetail,
                  onTap: _importData,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Erasing content is a first-class action here rather than the hidden
        // third option inside the "Delete account and data" dialog — the only
        // route to a non-account-destroying maintenance action used to be the
        // app's most frightening label. Deleting the ACCOUNT lives in Account.
        if (isPrivateMode)
          SettingsDestructiveButton(
            label: t.settingsPage.deletePrivateData,
            caption: t.settingsPage.deletePrivateDataDetail,
            onTap: _deletePrivateData,
          )
        else
          SettingsDestructiveButton(
            label: t.settingsPage.deleteAccountAndData,
            caption: t.settingsPage.deleteAccountAndDataDetail,
            onTap: _showDeleteOrResetDialog,
          ),
      ],
    );
  }

  /// Narrowed to what a user would actually call privacy. Sync, backups and
  /// erasure moved to Data & Backup; account credentials moved to Account.
  Widget _privacy() {
    final biometric = ref.watch(desktopBiometricControllerProvider);
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;
    final privacyPolicy = LegalUrls.privacy(
      LocaleSettings.currentLocale.languageCode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(section: SettingsSection.privacy),
        const SizedBox(height: 20),
        _SettingsColumn(
          groups: [
            // Hidden rather than disabled off macOS/Windows: the controller
            // refuses outright on Linux, and a permanently impossible control
            // is noise, not information.
            if (ref
                .read(desktopBiometricControllerProvider.notifier)
                .isSupportedPlatform)
              SettingsGroup(
                title: t.settingsPage.groupAppLock,
                children: [
                  SettingsSwitchRow(
                    id: 'privacy.appLock',
                    label: t.settingsPage.biometricLock,
                    detail: t.settingsPage.biometricLockDetail,
                    value: biometric.enabled,
                    onChanged: _setBiometricLock,
                  ),
                ],
              ),
            if (!isPrivateMode)
              SettingsGroup(
                title: t.settingsPage.groupDiagnosticsConsent,
                children: [
                  SettingsSwitchRow(
                    id: 'privacy.crashReports',
                    label: t.settingsPage.sendCrashReports,
                    detail: t.settingsPage.sendCrashReportsDetail,
                    value: _crashReports,
                    onChanged: _setCrashReportingConsent,
                  ),
                ],
              ),
            SettingsGroup(
              title: t.settingsPage.systemPermissionsTitle,
              children: [
                SettingsActionRow(
                  id: 'privacy.systemPermissions',
                  title: t.settingsPage.systemPermissionsManagement,
                  detail: t.settingsPage.systemPermissionsManagementDetail,
                  external: true,
                  onTap: _openSystemPermissions,
                ),
              ],
            ),
            // These existed only inside the Pro purchase surface, which is
            // filtered out of the rail entirely in Private mode — so a
            // Private-mode user could not reach the privacy policy from
            // Settings at all. They stay in the paywall too, for App Store
            // compliance.
            SettingsGroup(
              title: t.settingsPage.groupLegal,
              children: [
                SettingsActionRow(
                  id: 'privacy.privacyPolicy',
                  title: t.settingsPage.privacyPolicy,
                  external: true,
                  onTap: () => unawaited(
                    launchUrl(
                      privacyPolicy,
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
                SettingsActionRow(
                  id: 'privacy.terms',
                  title: t.settingsPage.termsEula,
                  external: true,
                  onTap: () => unawaited(
                    launchUrl(
                      LegalUrls.appleEula,
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Expert and developer-adjacent surface, in one place at the bottom of the
  /// rail where Mac users expect it.
  ///
  /// App Logs used to be the last row of the Application pane's "Calendar,
  /// experience and language" card, directly under "Reset tutorial".
  Widget _advanced() {
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;
    final diagnostics = _syncDiagnostics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(section: SettingsSection.advanced),
        const SizedBox(height: 20),
        _SettingsColumn(
          groups: [
            // System prompt and temperature were a collapsed disclosure inside
            // the coach modal. They are genuinely expert controls — a Pro
            // subscriber can rewrite the prompt for the managed engine — so
            // they belong here rather than in front of everyone configuring an
            // engine.
            SettingsGroup(
              title: t.coachSettings.groupTuning,
              footnote: t.coachSettings.tuningFootnote,
              children: const [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: CoachAdvancedPanel(),
                ),
              ],
            ),
            SettingsGroup(
              title: t.settingsPage.groupDiagnostics,
              children: [
                SettingsActionRow(
                  id: 'advanced.appLogs',
                  title: t.settingsPage.appLogsTitle,
                  detail: t.settingsPage.appLogsDetail,
                  onTap: () => unawaited(showAppLogsDialog(context)),
                ),
                if (isPrivateMode && Platform.isMacOS && diagnostics != null)
                  SettingsActionRow(
                    id: 'advanced.syncReport',
                    title: t.icloudSync.detailsTitle,
                    detail: _diagnosticsLabel(diagnostics),
                    onTap: () => _showDiagnosticsDialog(diagnostics),
                  ),
              ],
            ),
            // Previously reachable ONLY by pressing the red "Delete account and
            // data" button and picking the third option in the dialog that
            // opened — a settings reset hidden behind the app's most
            // destructive label.
            SettingsGroup(
              title: t.settingsPage.sectionAdvanced,
              children: [
                SettingsActionRow(
                  id: 'advanced.restoreDefaults',
                  title: t.settingsPage.restoreDefaults,
                  detail: t.settingsPage.restoreDefaultsDetail,
                  destructive: true,
                  onTap: _confirmRestoreDefaults,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmRestoreDefaults() async {
    final confirmed = await showEvolveDialog<bool>(
      context: context,
      builder: (dialogContext) => EvolveAlertDialog(
        icon: LucideIcons.rotateCcw,
        title: Text(t.settingsPage.restoreDefaults),
        content: Text(
          t.settingsPage.restoreDefaultsDetail,
          style: TextStyle(
            color: dialogContext.evolveColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.settingsPage.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.settingsPage.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _resetSettingsToDefaults();
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
          _showGate(
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
        _showGate(doneTitle, t.settingsPage.exportDoneSaved);
      } else if (Platform.isLinux) {
        await Clipboard.setData(ClipboardData(text: json));
        if (!mounted) return;
        _showGate(
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
        _showGate(
          doneTitle,
          isPrivateMode
              ? t.privateData.exportDoneShare
              : t.settingsPage.exportDoneShare,
        );
      }
    } catch (error, stack) {
      AppLogger.error('Errore durante exportData', error, stack);
      if (!mounted) return;
      _showGate(t.settingsPage.exportDoneTitle, t.settingsPage.operationFailed);
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(desktopAuthControllerProvider.notifier).signOut();
    } catch (_) {}
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
        _showGate(
          t.settingsPage.avatarGateTitle,
          t.settingsPage.avatarPickFailed,
        );
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await _confirm(
      title: t.settingsPage.confirmSignOutTitle,
      message: t.settingsPage.confirmSignOutMessage,
      destructive: true,
    );
    if (confirmed) await _signOut();
  }

  Future<void> _setBiometricLock(bool value) async {
    final changed = await ref
        .read(desktopBiometricControllerProvider.notifier)
        .setEnabled(value);
    if (!mounted) return;
    if (!changed) {
      final message = ref.read(desktopBiometricControllerProvider).errorMessage;
      _showGate(
        t.settingsPage.biometricLock,
        message ?? t.settingsPage.biometricActivationCancelled,
      );
    }
  }

  Future<void> _requestNotificationPermissions() async {
    final granted = await DesktopNotificationService.instance
        .requestPermissions();
    if (!mounted) return;
    _showGate(
      t.settingsPage.notificationPermissionsTitle,
      granted
          ? t.settingsPage.notificationPermissionsGranted
          : t.settingsPage.notificationPermissionsDenied,
    );
  }

  void _setNotificationBool({
    required String key,
    required bool value,
    required ValueChanged<bool> update,
    required String profileColumn,
    bool requestPermissions = false,
  }) {
    _setBool(
      key,
      value,
      update,
      profileColumn: profileColumn,
      // The schedule is rebuilt from the page's fields, so a rollback has to
      // rebuild it again or macOS keeps firing on the un-stored setting.
      alsoRevert: () => unawaited(_syncNotifications()),
    );
    if (requestPermissions) {
      unawaited(DesktopNotificationService.instance.requestPermissions());
    }
    unawaited(_syncNotifications());
  }

  void _setNotificationString(
    String key,
    String value,
    ValueChanged<String> update, {
    required String previous,
    required String profileColumn,
  }) {
    _setString(
      key,
      value,
      update,
      previous: previous,
      profileColumn: profileColumn,
      alsoRevert: () => unawaited(_syncNotifications()),
    );
    unawaited(_syncNotifications());
  }

  Future<void> _syncNotifications() async {
    await DesktopNotificationService.instance.sync(
      habitReminders: _habitReminders,
      eveningReview: _eveningReview,
      morningBriefTime: _morningTime,
      eveningReviewTime: _eveningTime,
      habits: ref.read(dashboardControllerProvider).habits,
      // Focus Mode cancels every scheduled notification (mobile parity).
      focusMode: _focusMode,
    );
  }

  Future<void> _openSystemPermissions() async {
    try {
      await DesktopSystemSettingsService.openPermissions();
    } catch (error, stack) {
      AppLogger.error('Unable to open system permissions', error, stack);
      if (mounted) {
        _showGate(
          t.settingsPage.systemPermissionsTitle,
          t.settingsPage.systemPermissionsOpenFailed,
        );
      }
    }
  }

  Future<void> _resetTutorials() async {
    // Clear the completion flag and rewind the central tour to Overview, then
    // navigate to the Dashboard. The Dashboard's existing onboarding flow
    // watches tourControllerProvider and re-triggers the welcome dialog + tour.
    await ref.read(tourControllerProvider.notifier).resetForReplay();
    ref
        .read(navigationControllerProvider.notifier)
        .select(DesktopSection.overview);
    if (mounted) {
      _showGate(
        t.settingsPage.tutorialResetTitle,
        t.settingsPage.tutorialResetMessage,
      );
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
      final confirmed = await _confirm(
        title: t.settingsPage.confirmResetDataTitle,
        message: t.settingsPage.confirmResetDataMessage,
        destructive: true,
      );
      if (confirmed) await _resetData();
      return;
    }

    final confirmed = await _confirm(
      title: t.settingsPage.confirmDeleteAccountTitle,
      message: t.settingsPage.confirmDeleteAccountMessage,
      destructive: true,
    );
    if (confirmed) await _deleteAccount();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    bool destructive = false,
    String? confirmLabel,
  }) async {
    return await showEvolveDialog<bool>(
          context: context,
          builder: (context) => EvolveAlertDialog(
            icon: destructive
                ? LucideIcons.triangleAlert
                : LucideIcons.circleCheck,
            iconColor: destructive ? EvolveColors.destructive : null,
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t.settingsPage.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: EvolveColors.destructive,
                      )
                    : null,
                child: Text(confirmLabel ?? t.settingsPage.confirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _resetData() async {
    _showLoadingDialog(t.settingsPage.resetDataTitle);
    try {
      await ref.read(dashboardControllerProvider.notifier).resetData();
      await _resetSettingsToDefaults();
      if (mounted) {
        Navigator.pop(context); // close loading dialog
        _showResultDialog(
          t.settingsPage.resetDataTitle,
          t.settingsPage.resetDataSuccess,
        );
      }
    } catch (error, stack) {
      AppLogger.error('Unable to reset desktop data', error, stack);
      if (mounted) {
        Navigator.pop(context); // close loading dialog
        _showResultDialog(
          t.settingsPage.resetDataTitle,
          t.settingsPage.operationFailed,
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (!ref.read(desktopAuthControllerProvider).isLoggedIn) {
      _showResultDialog(
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
    _showLoadingDialog(t.settingsPage.deleteAccountGateTitle);
    try {
      await ref.read(desktopAuthControllerProvider.notifier).deleteAccount();
      navigator.pop();
      // Success disposes this page, so the confirmation is best-effort: it can
      // only render on the rare path where the swap has not landed yet.
      if (mounted) {
        _showResultDialog(
          t.settingsPage.deleteAccountGateTitle,
          t.settingsPage.accountDeleted,
        );
      }
    } catch (error, stack) {
      AppLogger.error('Unable to delete desktop account', error, stack);
      navigator.pop();
      if (mounted) {
        _showResultDialog(
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
        final recover = await _confirm(
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
        final proceed = await _confirm(
          title: t.settingsPage.importReplaceConfirmTitle,
          message: t.settingsPage.importReplaceConfirmMessage(count: logCount),
          confirmLabel: t.settingsPage.importReplaceConfirmButton,
          destructive: true,
        );
        if (!proceed) return;
        if (!mounted) return;
      }

      // 3. Execute
      _showLoadingDialog(t.settingsPage.importInProgress);

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
      await _showImportResult(stats);
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

  /// Post-import summary dialog: one line per entity with the merge outcome,
  /// mirroring mobile's import-completed dialog.
  Future<void> _showImportResult(ImportMergeStats stats) {
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
            _importSummaryRow(
              ctx,
              LucideIcons.check,
              _mergeRowText(
                stats,
                stats.habits,
                t.settingsPage.importEntityHabits,
              ),
            ),
            _importSummaryRow(
              ctx,
              LucideIcons.history,
              _mergeRowText(stats, stats.logs, t.settingsPage.importEntityLogs),
            ),
            _importSummaryRow(
              ctx,
              LucideIcons.target,
              _mergeRowText(
                stats,
                stats.macroGoals,
                t.settingsPage.importEntityMacroGoals,
              ),
            ),
            _importSummaryRow(
              ctx,
              LucideIcons.folder,
              _mergeRowText(
                stats,
                stats.categories,
                t.settingsPage.importEntityCategories,
              ),
            ),
            _importSummaryRow(
              ctx,
              LucideIcons.smile,
              _mergeRowText(
                stats,
                stats.moods,
                t.settingsPage.importEntityMoods,
              ),
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

  /// The one-line truth about whether anything is stranded. Failures are named
  /// ahead of the pending count: a user with both needs to know that retrying
  /// is not what is missing.
  String _diagnosticsLabel(SyncDiagnostics d) {
    // totalStuck, not a hand-rolled sum: adding a bucket to SyncDiagnostics
    // (as `heldByReason` was) must not silently under-count here.
    final stuck = d.totalStuck;
    if (stuck > 0) return t.icloudSync.detailsFailed(count: stuck);
    if (d.totalPending > 0) {
      return t.icloudSync.detailsPending(count: d.totalPending);
    }
    return t.icloudSync.detailsAllSynced;
  }

  /// The full per-table report, as copyable monospace text. Deliberately raw:
  /// a per-table count is the only thing that localises a stall to a specific
  /// table, and this Mac is one half of the pair being compared.
  Future<void> _showDiagnosticsDialog(SyncDiagnostics d) async {
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
              if (mounted) {
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
      final accepted = await _confirm(
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
    final accepted = await _confirm(
      title: t.icloudSync.forceEnableTitle,
      message: t.icloudSync.forceEnableBody,
      destructive: true,
    );
    if (!accepted) return;
    await _runSyncAction((service) => service.enable(force: true));
  }

  Future<void> _onResetSyncFromThisDevice() async {
    final accepted = await _confirm(
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
      alwaysUse24HourFormat: _timeFormat24h,
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
    final confirmed = await _confirm(
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
      await _syncNotifications();
      await _refreshSyncStatus();
      if (mounted) {
        Navigator.pop(context); // close loading dialog
        _showResultDialog(
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
          _showResultDialog(
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
          _showResultDialog(
            t.privateData.deleteTitle,
            t.privateData.deleteFailed,
          );
        }
      }
    } catch (error, stack) {
      AppLogger.error('Unable to delete private database', error, stack);
      if (mounted) {
        Navigator.pop(context); // close loading dialog
        _showResultDialog(
          t.privateData.deleteTitle,
          t.privateData.deleteFailed,
        );
      }
    }
  }

  Future<void> _resetSettingsToDefaults() async {
    final preferences = ref.read(sharedPreferencesProvider);
    final keys = preferences?.getKeys().where(
      (key) => key.startsWith('pref_') || key.startsWith('notif_'),
    );
    if (preferences != null && keys != null) {
      await Future.wait([for (final key in keys) preferences.remove(key)]);
    }
    ref
        .read(desktopAppearanceControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    ref
        .read(desktopAppearanceControllerProvider.notifier)
        .setAccentColor(DesktopAppearanceController.defaultAccent);
    ref
        .read(desktopLocaleControllerProvider.notifier)
        .setLanguage(SettingsCodec.languageSystem);
    setState(() {
      // Reset stays on an explicit 'dark' rather than 'system', matching
      // mobile's reset — changing only desktop would break parity.
      _themeMode = SettingsCodec.themeDark;
      _accent = DesktopAppearanceController.defaultAccent;
      _calendarView = kCalendarViewWeek;
      _language = SettingsCodec.languageSystem;
      _timeFormat24h = true;
      _habitReminders = true;
      _goalDeadlines = true;
      // Mobile defaults: AI insights and weekly reports start OFF (matches
      // the initial-state defaults and the profile values synced below).
      _aiInsights = false;
      _weeklyReport = false;
      _aiSuggestions = false;
      _focusMode = false;
      _milestones = true;
      _deepWorkInsights = false;
      _eveningReview = true;
      _morningTime = SettingsCodec.defaultMorningBriefTime;
      _eveningTime = SettingsCodec.defaultEveningReviewTime;
    });
    await ref
        .read(desktopBiometricControllerProvider.notifier)
        .setEnabled(false);
    // Only keys in PrivateDbSchema.syncedSettingKeys. `biometric_lock` used to
    // be in this payload and is now device-local: a reset on the Mac must not
    // reach across and unlock the user's iPhone. It is reset locally, above.
    // `_syncProfile` filters the map, so this list is the contract, not a hope.
    // No rollback here — the local state has already been reset across two
    // dozen fields and un-resetting them piecemeal would be its own bug. But
    // the user must still be told, or a reset that never reached the store
    // looks exactly like one that did.
    final saved = await _syncProfile({
      kSettingThemeMode: SettingsCodec.themeDark,
      // Derived from the accent actually applied above, not a hardcoded hex —
      // the two used to be independent literals and could silently drift apart,
      // which is how the Mac and the iPhone ended up on different whites.
      kSettingAccentColor: dashboardColorToHex(
        DesktopAppearanceController.defaultAccent,
      ),
      kSettingCalendarView: kCalendarViewWeek,
      kSettingHapticFeedback: true,
      kSettingLanguage: SettingsCodec.languageSystem,
      kSettingTimeFormat24h: true,
      kSettingAiSuggestions: false,
      kSettingFocusMode: false,
      kSettingMilestones: true,
      kSettingDeepWorkInsights: false,
      kSettingHabitReminders: true,
      kSettingGoalDeadlines: true,
      kSettingAiInsights: false,
      kSettingWeeklyReports: false,
      kSettingEveningReview: true,
      kSettingMorningBriefTime: SettingsCodec.defaultMorningBriefTime,
      kSettingEveningReviewTime: SettingsCodec.defaultEveningReviewTime,
    });
    if (!saved && mounted) {
      showEvolveToast(
        context,
        message: t.settingsPage.settingSaveFailed,
        kind: EvolveToastKind.error,
      );
    }
    await _syncNotifications();
  }

  Future<void> _reviewConsent() async {
    final consent = ref.read(desktopConsentControllerProvider);
    await ref
        .read(desktopConsentControllerProvider.notifier)
        .setConsent(
          acceptedTerms: false,
          sentryConsent: consent.hasSentryConsent,
          completed: false,
        );
  }

  Future<void> _setCrashReportingConsent(bool value) async {
    final consent = ref.read(desktopConsentControllerProvider);
    setState(() => _crashReports = value);
    await ref
        .read(desktopConsentControllerProvider.notifier)
        .setConsent(
          acceptedTerms: consent.hasAcceptedTerms,
          sentryConsent: value,
          completed: consent.hasCompletedOnboarding,
        );
  }

  /// [update] takes the value to apply rather than closing over the tapped one,
  /// because a failed write re-runs it with the PREVIOUS value. The previous
  /// bool is the negation: these all come from a switch whose rendered position
  /// is the field itself, so a tap always inverts it.
  void _setBool(
    String key,
    bool value,
    ValueChanged<bool> update, {
    String? profileColumn,
    Object? profileValue,
    VoidCallback? alsoRevert,
  }) {
    final preferences = ref.read(sharedPreferencesProvider);
    final previousPref = preferences?.getBool(key);
    setState(() => update(value));
    if (preferences != null) unawaited(preferences.setBool(key, value));
    if (profileColumn != null) {
      unawaited(
        _persistOrRollback(
          values: {profileColumn: profileValue ?? value},
          revert: () {
            update(!value);
            alsoRevert?.call();
            if (preferences == null) return;
            unawaited(
              previousPref == null
                  ? preferences.remove(key)
                  : preferences.setBool(key, previousPref),
            );
          },
        ),
      );
    }
  }

  /// As [_setBool], but the previous value cannot be derived, so the caller
  /// states it.
  void _setString(
    String key,
    String value,
    ValueChanged<String> update, {
    required String previous,
    String? profileColumn,
    Object? profileValue,
    VoidCallback? alsoRevert,
  }) {
    final preferences = ref.read(sharedPreferencesProvider);
    final previousPref = preferences?.getString(key);
    setState(() => update(value));
    if (preferences != null) unawaited(preferences.setString(key, value));
    if (profileColumn != null) {
      unawaited(
        _persistOrRollback(
          values: {profileColumn: profileValue ?? value},
          revert: () {
            update(previous);
            alsoRevert?.call();
            if (preferences == null) return;
            unawaited(
              previousPref == null
                  ? preferences.remove(key)
                  : preferences.setString(key, previousPref),
            );
          },
        ),
      );
    }
  }

  /// Hydrates the page (and the live controllers) from whichever store owns the
  /// settings in the active mode.
  Future<void> _loadProfilePreferences() async {
    // Private mode has NO Supabase session, so the Supabase branch below used to
    // return on its first line and the page hydrated purely from this Mac's own
    // SharedPreferences — it wrote settings into the synced row and read none of
    // them back. That is the whole reason the accent and the app language
    // differed between the iPhone and the Mac.
    if (ref.read(activeDesktopDataModeProvider).isPrivate) {
      try {
        // The SNAPSHOT, not `.future`, and this is load-bearing twice over.
        //
        // Awaiting the future made the store land TWICE whenever it was still
        // loading at mount — which in Private mode is the normal case, since
        // the read costs an encrypted-DB open plus a Keychain round-trip. The
        // `ref.listen` registered in `build()` fires when the value arrives AND
        // this await resumes with the same map, so `_applySyncedSettings` ran
        // twice: the first pass released the in-flight-edit guard and the
        // second then clobbered the very edit the guard existed to protect.
        //
        // It also let a STALE generation win: an invalidation mid-await (every
        // sync pull invalidates this provider) leaves the old future to
        // complete after the listener has already applied the newer map.
        //
        // Nothing is lost by not awaiting: initState and the first build run in
        // the same frame, so the listener is in place before any future can
        // complete, and it delivers the first value.
        final values = ref.read(desktopSyncedSettingsProvider).value;
        if (values != null) await _applySyncedSettings(values);
      } catch (error, stack) {
        AppLogger.error('Unable to read the private settings', error, stack);
      }
      return;
    }

    final client = ref.read(supabaseClientProvider);
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    try {
      final profile = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted || profile == null) return;
      ref
          .read(desktopAppearanceControllerProvider.notifier)
          .applyProfile(
            themeMode: profile['theme_mode'] as String?,
            accentColor: profile['accent_color'] as String?,
          );
      final appearance = ref.read(desktopAppearanceControllerProvider);
      setState(() {
        _themeMode = DesktopAppearanceController.themeCodeFor(
          appearance.themeMode,
        );
        _timeFormat24h =
            profile['pref_time_format_24h'] as bool? ?? _timeFormat24h;
        _habitReminders =
            profile['notif_habit_reminders'] as bool? ?? _habitReminders;
        _eveningReview =
            profile['notif_evening_review'] as bool? ?? _eveningReview;
        _goalDeadlines =
            profile['notif_goal_deadlines'] as bool? ?? _goalDeadlines;
        _aiInsights = profile['notif_ai_insights'] as bool? ?? _aiInsights;
        _weeklyReport =
            profile['notif_weekly_reports'] as bool? ?? _weeklyReport;
        _calendarView = normalizeCalendarViewCode(
          profile['pref_default_calendar_view'] as String?,
        );
        _language = SettingsCodec.normalizeLanguage(
          profile['language'] as String?,
        );
        _morningTime =
            SettingsCodec.normalizeTimeOfDay(
              profile['morning_brief_time'] as String?,
            ) ??
            _morningTime;
        _eveningTime =
            SettingsCodec.normalizeTimeOfDay(
              profile['evening_review_time'] as String?,
            ) ??
            _eveningTime;
        _accent = appearance.accentColor;
      });
      // Reading is not enough: the locale controller is what actually changes
      // the UI language, so the pulled value has to reach it.
      ref
          .read(desktopLocaleControllerProvider.notifier)
          .applyProfile(_language);
      final preferences = ref.read(sharedPreferencesProvider);
      if (preferences != null) {
        await Future.wait([
          // `applyProfile` no longer writes the prefs mirror (a read path must
          // not mutate), so the hydration that OWNS this refresh writes it.
          preferences.setString('pref_theme_mode', _themeMode),
          preferences.setString(
            'pref_accent_color',
            dashboardColorToHex(_accent),
          ),
          // The LEGACY bool needs a yes/no, so 'system' is resolved for this
          // key alone. `pref_theme_mode` above keeps the three-valued truth.
          preferences.setBool(
            'desktop_dark_mode',
            DesktopAppearanceController.resolvesDark(appearance.themeMode),
          ),
          preferences.setBool('pref_time_format_24h', _timeFormat24h),
          preferences.setBool('notif_habit_reminders', _habitReminders),
          preferences.setBool('notif_evening_review', _eveningReview),
          preferences.setBool('notif_goal_deadlines', _goalDeadlines),
          preferences.setBool('notif_ai_insights', _aiInsights),
          preferences.setBool('notif_weekly_reports', _weeklyReport),
          // Prefs hold the canonical code, never the display label.
          preferences.setString('pref_default_calendar_view', _calendarView),
          preferences.setString('pref_language', _language),
          preferences.setString('notif_morning_brief_time', _morningTime),
          preferences.setString('notif_evening_review_time', _eveningTime),
          preferences.setInt('accent_color', _accent.toARGB32()),
        ]);
      }
      final biometric = profile['biometric_lock'] as bool?;
      if (biometric != null) {
        await ref
            .read(desktopBiometricControllerProvider.notifier)
            .applyProfile(biometric);
      }
      await _syncNotifications();
    } catch (error, stack) {
      AppLogger.error('Unable to download desktop preferences', error, stack);
    }
  }

  /// Applies settings READ from the synced store: the live controllers first
  /// (theme / accent / language), then this page's fields, then the local prefs
  /// mirror, then the notification schedule.
  ///
  /// Keys the store has no value for are left untouched — [SyncedSettingsStore]
  /// omits "never set" keys precisely so a caller can keep its own default
  /// instead of being handed a fabricated one.
  Future<void> _applySyncedSettings(Map<String, String?> values) async {
    if (values.isEmpty || !mounted) return;

    // Keys the user changed while this very read was in flight are dropped, so
    // the load cannot revert an edit the user has already made (and already
    // published). Everything else still hydrates — dropping the whole load
    // instead would resurrect the original "the Mac never reads the store back"
    // bug. Empty after the first load, so this is a no-op for every later pull.
    final incoming = _preloadEdits.isEmpty
        ? values
        : <String, String?>{
            for (final e in values.entries)
              if (!_preloadEdits.contains(e.key)) e.key: e.value,
          };

    // Theme, accent and language live in controllers, not in this page. Without
    // this the fields below would show the pulled values while the app went on
    // rendering the old theme and speaking the old language.
    applyDesktopSyncedSettings(ref, incoming);
    final appearance = ref.read(desktopAppearanceControllerProvider);

    bool boolOr(String key, bool current) =>
        SyncedSettingsStore.decodeBool(incoming[key]) ?? current;

    setState(() {
      _themeMode = DesktopAppearanceController.themeCodeFor(
        appearance.themeMode,
      );
      _accent = appearance.accentColor;
      _timeFormat24h = boolOr(kSettingTimeFormat24h, _timeFormat24h);
      _habitReminders = boolOr(kSettingHabitReminders, _habitReminders);
      _eveningReview = boolOr(kSettingEveningReview, _eveningReview);
      _goalDeadlines = boolOr(kSettingGoalDeadlines, _goalDeadlines);
      _aiInsights = boolOr(kSettingAiInsights, _aiInsights);
      _weeklyReport = boolOr(kSettingWeeklyReports, _weeklyReport);
      _aiSuggestions = boolOr(kSettingAiSuggestions, _aiSuggestions);
      _focusMode = boolOr(kSettingFocusMode, _focusMode);
      _milestones = boolOr(kSettingMilestones, _milestones);
      _deepWorkInsights = boolOr(kSettingDeepWorkInsights, _deepWorkInsights);
      if (incoming.containsKey(kSettingCalendarView)) {
        _calendarView = normalizeCalendarViewCode(
          incoming[kSettingCalendarView],
        );
      }
      if (incoming.containsKey(kSettingLanguage)) {
        _language = SettingsCodec.normalizeLanguage(incoming[kSettingLanguage]);
      }
      _morningTime =
          SettingsCodec.normalizeTimeOfDay(
            incoming[kSettingMorningBriefTime],
          ) ??
          _morningTime;
      _eveningTime =
          SettingsCodec.normalizeTimeOfDay(
            incoming[kSettingEveningReviewTime],
          ) ??
          _eveningTime;
    });

    // Released HERE, not on the next tap: from now on this page is hydrated, so
    // a pull is a genuine change made on another device and must be applied
    // even for a key the user once touched. Latching without clearing would
    // turn the guard into "my iPhone change never arrives on the Mac".
    _syncedLoaded = true;
    _preloadEdits.clear();

    // Local mirror only — SharedPreferences, never a synced column. This is what
    // the controllers read on the next cold start, before the store answers.
    final preferences = ref.read(sharedPreferencesProvider);
    if (preferences != null) {
      await Future.wait([
        preferences.setString('pref_theme_mode', _themeMode),
        preferences.setString(
          'pref_accent_color',
          dashboardColorToHex(_accent),
        ),
        preferences.setBool(
          'desktop_dark_mode',
          DesktopAppearanceController.resolvesDark(appearance.themeMode),
        ),
        preferences.setInt('accent_color', _accent.toARGB32()),
        preferences.setBool('pref_time_format_24h', _timeFormat24h),
        preferences.setBool('notif_habit_reminders', _habitReminders),
        preferences.setBool('notif_evening_review', _eveningReview),
        preferences.setBool('notif_goal_deadlines', _goalDeadlines),
        preferences.setBool('notif_ai_insights', _aiInsights),
        preferences.setBool('notif_weekly_reports', _weeklyReport),
        preferences.setBool('pref_ai_suggestions', _aiSuggestions),
        preferences.setBool('pref_focus_mode', _focusMode),
        preferences.setBool('pref_milestones', _milestones),
        preferences.setBool('pref_deep_work_insights', _deepWorkInsights),
        preferences.setString('pref_default_calendar_view', _calendarView),
        preferences.setString('pref_language', _language),
        // Prefs key ≠ DB column, deliberately: 'notif_morning_brief_time' here,
        // 'morning_brief_time' in the store.
        preferences.setString('notif_morning_brief_time', _morningTime),
        preferences.setString('notif_evening_review_time', _eveningTime),
      ]);
    }

    // Times and toggles only take effect once the schedule is rebuilt. Guarded:
    // the prefs write above is awaited, so the page can be gone by now and
    // `_syncNotifications` reads providers off `ref`.
    if (!mounted) return;
    await _syncNotifications();
  }

  /// Writes [values], and on failure puts the UI back where the store actually
  /// is and says so.
  ///
  /// [revert] is a LOCAL rollback on purpose. The obvious alternative —
  /// `ref.invalidate(desktopSyncedSettingsProvider)` so the existing listeners
  /// re-apply the true stored value — is a no-op in the dominant failure mode:
  /// whatever made the write fail (a Keychain key-guard lockout, a corrupt
  /// store) makes the READ fail too, `desktopSyncedSettingsProvider` swallows
  /// that into an empty map, and both listeners are guarded on `isNotEmpty`.
  /// The UI would go on showing a value that was never stored, silently, with
  /// only a log line to show for it.
  Future<void> _persistOrRollback({
    required Map<String, dynamic> values,
    required VoidCallback revert,
  }) async {
    // Keyed on the synced column name, which IS the key `_applySyncedSettings`
    // reads, so the two always agree on what "this setting" means.
    if (!_syncedLoaded) _preloadEdits.addAll(values.keys);
    if (await _syncProfile(values)) return;
    if (!mounted) return;
    setState(revert);
    showEvolveToast(
      context,
      message: t.settingsPage.settingSaveFailed,
      kind: EvolveToastKind.error,
    );
  }

  /// True when the values are persisted (or when there was legitimately nothing
  /// to persist), false when a write was attempted and failed.
  ///
  /// It used to return `Future<void>` and every caller `unawaited` it, so a
  /// failed write was indistinguishable from a successful one: the switch had
  /// already moved, the prefs mirror had already been rewritten, and the user
  /// was told nothing.
  Future<bool> _syncProfile(Map<String, dynamic> values) async {
    // Private mode: persist through the SHARED store, which dual-writes the
    // per-key `user_settings` row and the legacy `profiles` column so a
    // not-yet-updated iPhone still sees the change.
    if (ref.read(activeDesktopDataModeProvider).isPrivate) {
      // Filtered to the canonical list rather than passed through: a key that is
      // not synced (a device-local column, or a typo) would otherwise be written
      // into a payload that travels to the user's other devices. The store
      // throws on an unknown key by design; filtering here keeps a caller that
      // mixes in a local-only value from taking the whole write down with it.
      final synced = <String, String?>{
        for (final e in values.entries)
          if (PrivateDbSchema.syncedSettingKeys.contains(e.key))
            e.key: encodeDesktopSetting(e.value),
      };
      // Nothing synced in this payload is not a failure: the caller mixed in
      // only device-local keys, which are already persisted by SharedPreferences.
      if (synced.isEmpty) return true;
      try {
        await ref.read(desktopSyncedSettingsWriterProvider)(synced);
        return true;
      } catch (error, stack) {
        AppLogger.error('Unable to save the private settings', error, stack);
        return false;
      }
    }
    final client = ref.read(supabaseClientProvider);
    final user = client?.auth.currentUser;
    // Signed out in cloud mode: there is no remote row to write, and the local
    // prefs write already succeeded. Not a failure to report to the user.
    if (client == null || user == null) return true;
    try {
      await client.from('profiles').upsert({'id': user.id, ...values});
      return true;
    } catch (error, stack) {
      AppLogger.error('Unable to sync desktop preferences', error, stack);
      return false;
    }
  }

  String _languageOptionLabel(String code) => switch (code) {
    'it' => t.settingsPage.languageOptions.italian,
    'en' => t.settingsPage.languageOptions.english,
    'es' => t.settingsPage.languageOptions.spanish,
    'de' => t.settingsPage.languageOptions.german,
    'ar' => t.settingsPage.languageOptions.arabic,
    _ => t.settingsPage.languageOptions.system,
  };

  /// The canonical CODE stays the value; only the label follows the UI
  /// language, exactly like the calendar-view and language rows.
  String _themeModeOptionLabel(String code) => switch (code) {
    SettingsCodec.themeLight => t.settingsPage.themeLight,
    SettingsCodec.themeDark => t.settingsPage.themeDark,
    _ => t.settingsPage.themeSystem,
  };

  String _calendarViewOptionLabel(String code) => switch (code) {
    kCalendarViewMonth => t.settingsPage.calendarViewOptions.month,
    kCalendarViewYear => t.settingsPage.calendarViewOptions.year,
    kCalendarViewLife => t.settingsPage.calendarViewOptions.life,
    _ => t.settingsPage.calendarViewOptions.week,
  };

  void _showGate(String title, String detail) {
    showEvolveToast(context, message: '$title: $detail');
  }

  void _showLoadingDialog(String message) {
    showEvolveDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EvolveDialog(
        maxWidth: 280,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 28,
                child: EvolveSpinner(radius: 14),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ctx.evolveColors.foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResultDialog(String title, String detail) {
    showEvolveDialog<void>(
      context: context,
      builder: (ctx) => EvolveAlertDialog(
        icon: LucideIcons.info,
        title: Text(title),
        content: Text(detail),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.notifications.actionDone),
          ),
        ],
      ),
    );
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

extension _AiCoachSection on _SettingsPageState {
  /// AI Coach: the engine configuration itself, inline, plus what the coach is
  /// allowed to see.
  Widget _aiCoach() {
    final hasConsent =
        ref.watch(hasAnyCoachConsentProvider).asData?.value ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(section: SettingsSection.aiCoach),
        const SizedBox(height: 20),
        _SettingsColumn(
          groups: [
            // The engine configuration IS the pane now. There is no launcher
            // row and no modal: CoachSettingsDialog held the whole feature —
            // engine cards, API key, local server address, model picker — two
            // levels down behind a chevron, which is why none of it was
            // discoverable.
            SettingsGroup(
              title: t.coachSettings.groupEngine,
              children: const [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: CoachEnginePanel(),
                ),
              ],
            ),
            SettingsGroup(
              title: t.coachSettings.groupPrivacy,
              children: [
                // Withdrawing consent must be as easy as giving it (GDPR Art.
                // 7(3) — Simone is the named controller), and Guideline 5.1.2
                // expects the same.
                //
                // Always rendered, both states. It used to appear ONLY while a
                // consent existed, so the row erased itself the moment it was
                // used: there was no way to see that sharing was off, and no
                // way back. Splitting the status from the action is what lets
                // it stay.
                SettingsStatusRow(
                  id: 'coach.dataSharing',
                  label: t.ai.consent.rowTitle,
                  status: hasConsent
                      ? t.ai.consent.statusGranted
                      : t.ai.consent.consentStatusRevoked,
                  actionLabel: hasConsent
                      ? t.ai.consent.consentStopSharing
                      : null,
                  destructiveAction: true,
                  onAction: hasConsent
                      ? () => _revokeCoachConsent(context)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _revokeCoachConsent(BuildContext context) async {
    final confirmed = await showEvolveDialog<bool>(
      context: context,
      builder: (dialogContext) => EvolveAlertDialog(
        icon: LucideIcons.triangleAlert,
        iconColor: EvolveColors.destructive,
        title: Text(t.ai.consent.revokeTitle),
        content: Text(
          t.ai.consent.revokeBody,
          style: TextStyle(
            color: dialogContext.evolveColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.common.actions.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.ai.consent.revokeAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(coachConsentStoreProvider).revokeAll();
    ref.invalidate(hasAnyCoachConsentProvider);
  }
}

/// The pane heading, derived from the destination itself.
///
/// It used to take a free-text title and subtitle, and four of the six panes
/// then disagreed with the rail entry that opened them ("Application" opened
/// "Appearance and application"). Taking the [SettingsSection] makes one string
/// the name of the destination in both places, by construction.
class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading({required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.label, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text(section.purpose, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

/// The pane body: one column of group cards.
///
/// It replaces `_GroupGrid`, which above a 1280px breakpoint packed the cards
/// into two columns greedily by `children.length`. Three things were wrong with
/// that and only the first was cosmetic. Reading order broke — the Application
/// pane's groups of 1, 6 and 4 rows rendered as left = 1, 3 and right = 2, so
/// the eye met them out of order. Row COUNT is not height, so a 56px switch and
/// a ~90px colour row balanced as equals. And the breakpoint measured
/// `constraints.maxWidth` of the whole panel, rail included, so the cards
/// actually split at ~1030px of usable content width rather than the 1280 the
/// code named. macOS Settings puts one column in a pane; so do we.
class _SettingsColumn extends StatelessWidget {
  const _SettingsColumn({required this.groups});

  final List<Widget> groups;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 18),
          groups[i],
        ],
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.user,
    required this.image,
    required this.isPro,
    required this.onPickAvatar,
    this.isPrivateMode = false,
    this.privateProfile,
  });

  final User? user;
  final File? image;
  final bool isPro;
  final VoidCallback onPickAvatar;
  final bool isPrivateMode;
  final PrivateProfileState? privateProfile;

  @override
  Widget build(BuildContext context) {
    final metadata = user?.userMetadata;
    final fullName = isPrivateMode
        ? privateProfile?.fullName
        : (metadata?['full_name'] as String?)?.trim();
    final avatarUrl = isPrivateMode
        ? privateProfile?.avatarPath
        : metadata?['avatar_url'] as String?;
    return EvolvePanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          InkWell(
            onTap: onPickAvatar,
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPro
                      ? EvolveColors.amber
                      : context.evolveAccent.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: context.evolveColors.panel,
                backgroundImage: image != null
                    ? FileImage(image!)
                    : avatarUrl != null
                    ? (isPrivateMode
                              ? FileImage(File(avatarUrl))
                              : NetworkImage(avatarUrl))
                          as ImageProvider
                    : null,
                child: image == null && avatarUrl == null
                    ? Icon(
                        LucideIcons.user,
                        size: 20,
                        color: context.evolveAccent,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPrivateMode
                      ? t.settingsPage.privateMode
                      : fullName?.isNotEmpty ?? false
                      ? fullName!
                      : user?.email?.split('@').first ??
                            t.settingsPage.profileFallback,
                  style: TextStyle(
                    color: context.evolveColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPrivateMode
                      ? t.settingsPage.privateModeDataProtected
                      : user?.email ?? t.settingsPage.sessionUnavailable,
                  style: TextStyle(
                    color: context.evolveColors.muted.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isPro)
            const StatusPill(
              label: 'PRO',
              color: EvolveColors.amber,
              icon: LucideIcons.sparkles,
            )
          else
            StatusPill(
              label: user == null
                  ? t.settingsPage.notAuthenticated
                  : t.settingsPage.verified,
              color: user == null ? EvolveColors.amber : context.evolveAccent,
              icon: user == null ? LucideIcons.lock : LucideIcons.shieldCheck,
            ),
        ],
      ),
    );
  }
}

class _PlatformNote extends StatelessWidget {
  const _PlatformNote({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      glowColor: EvolveColors.violet,
      child: Row(
        children: [
          const EvolveIconChip(
            icon: LucideIcons.monitor,
            color: EvolveColors.violet,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: SettingsRowCopy(label: title, detail: detail),
          ),
        ],
      ),
    );
  }
}

/// Product identifiers for the plan-label switch in the "already Pro" details
/// panel. Kept in sync with [DesktopSubscriptionController.proProductIds].
const _kMonthlyProductId = 'com.simo.evolve.pro.monthly';
const _kYearlyProductId = 'com.simo.evolve.pro.yearly';

/// Whole-percent saving of the annual plan against twelve months of the monthly
/// plan, or null when there is no honest saving to claim.
///
/// Computed from live store prices rather than stated as a constant: Apple's
/// price tiers are not linear across currencies, so a fixed "Save 40%" claim is
/// wrong in most storefronts. Returns null when either price is unusable or the
/// annual plan is not actually cheaper, so the UI falls back to a neutral line.
@visibleForTesting
int? annualSavingPercent({
  required double monthlyPrice,
  required double yearlyPrice,
}) {
  if (monthlyPrice <= 0 || yearlyPrice <= 0) return null;
  final saving = (1 - yearlyPrice / (monthlyPrice * 12)) * 100;
  // Round first: 0.6% would otherwise survive the check and render as "Save 1%".
  final rounded = saving.round();
  if (rounded < 1) return null;
  return rounded;
}

/// Opens the subscription purchase surface as a modal dialog — the SAME plans,
/// pricing, purchase, restore and compliance the Settings → Subscription section
/// renders, presented directly so a locked feature (e.g. the AI Coach) sends the
/// user straight to plans instead of deep-linking through Settings. This is the
/// desktop counterpart of the mobile SubscriptionScreen step of the paywall
/// funnel; the feature pitch is omitted because the Pro-features dialog that
/// opened this already made it.
Future<void> showPaywallDialog(BuildContext context) {
  return showEvolveDialog<void>(
    context: context,
    builder: (dialogContext) => EvolveDialog(
      maxWidth: 560,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        child: _SubscriptionSettings(
          showFeaturePitch: false,
          // A successful purchase should return the user to the feature they
          // were trying to unlock, so close this modal once Pro is active.
          onProActivated: () => Navigator.of(dialogContext).maybePop(),
        ),
      ),
    ),
  );
}

class _SubscriptionSettings extends ConsumerStatefulWidget {
  const _SubscriptionSettings({
    this.showFeaturePitch = true,
    this.onProActivated,
  });

  /// When false, the upsell panel + feature list at the top are omitted — used by
  /// [showPaywallDialog], where the preceding Pro-features dialog already pitched
  /// them and repeating would be redundant.
  final bool showFeaturePitch;

  /// Invoked after the user dismisses the purchase-success dialog. Set by
  /// [showPaywallDialog] to close the modal; null in the Settings section, where
  /// the surface should stay put and flip to the "already Pro" panel in place.
  final VoidCallback? onProActivated;

  @override
  ConsumerState<_SubscriptionSettings> createState() =>
      _SubscriptionSettingsState();
}

class _SubscriptionSettingsState extends ConsumerState<_SubscriptionSettings> {
  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(desktopSubscriptionControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(section: SettingsSection.subscription),
        const SizedBox(height: 20),
        // A subscribed user gets the status + details panel; everyone else gets
        // the purchase surface. Mirrors the mobile paywall's two states.
        if (subscription.isPro)
          ..._proView(context, subscription)
        else
          ..._purchaseView(context, subscription),
      ],
    );
  }

  // ------------------------------------------------------------------ Purchase

  List<Widget> _purchaseView(
    BuildContext context,
    DesktopSubscriptionState subscription,
  ) {
    final busy = subscription.isLoading;
    final plan = ref.watch(desktopSelectedPlanProvider);
    return [
      if (widget.showFeaturePitch) ...[
        _featurePitch(context),
        const SizedBox(height: 24),
        EvolveSectionLabel(t.proModal.featuresHeader, withRule: false),
        const SizedBox(height: 12),
        for (final feature in proFeatures()) ...[
          ProFeatureRow(feature: feature),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 6),
      ],
      _PlatformNote(
        title: subscription.isSupportedPlatform
            ? t.settingsPage.billingAppleTitle
            : t.settingsPage.commercialChannelRequired,
        detail: subscription.isSupportedPlatform
            ? subscription.isConfigured
                  ? t.settingsPage.billingAppleDetail
                  : t.settingsPage.billingUnavailableDetail
            : t.settingsPage.billingPlatformUnsupported,
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _PlanCard(
              key: SettingsKeys.row('subscription.planMonthly'),
              title: t.settingsPage.planMonthly,
              // Never fall back to the plan NAME here: that renders the title
              // twice where Guideline 3.1.2 requires the price per period. The
              // product resolves from the Offering or the direct-product fetch.
              price: subscription.monthlyProduct?.priceString,
              selected: plan == DesktopPlan.monthly,
              onTap: () => ref
                  .read(desktopSelectedPlanProvider.notifier)
                  .select(DesktopPlan.monthly),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _PlanCard(
              key: SettingsKeys.row('subscription.planAnnual'),
              title: t.settingsPage.planAnnual,
              price: subscription.yearlyProduct?.priceString,
              // Honest per-month + saving from live store prices, or the neutral
              // "best value" line when no price resolved — never an invented %.
              detail: _annualSubtitle(subscription) ?? t.settingsPage.bestValue,
              selected: plan == DesktopPlan.yearly,
              onTap: () => ref
                  .read(desktopSelectedPlanProvider.notifier)
                  .select(DesktopPlan.yearly),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      // The money step, as the loudest thing on the surface rather than the
      // quietest. It was a chevron row rendered identically to "Replay the
      // guided tour", two rows below the plan cards, naming neither the plan
      // the user had picked nor what it would cost — so the confirmation of
      // what you were about to buy lived only in a tint on a card above it.
      SettingsPrimaryButton(
        id: 'subscription.subscribe',
        icon: LucideIcons.sparkles,
        label: _subscribeLabel(subscription, plan),
        caption: t.settingsPage.activateEvolveProStart,
        busy: busy,
        onPressed: () => unawaited(_activate()),
      ),
      const SizedBox(height: 18),
      const _ComplianceLinks(),
      const SizedBox(height: 24),
      _SettingsColumn(
        groups: [
          SettingsGroup(
            title: t.settingsPage.planManagement,
            children: [_restoreRow(busy)],
          ),
        ],
      ),
    ];
  }

  /// Names the plan being bought and what it costs.
  ///
  /// Falls back to the plan alone when no store price has resolved: a CTA is
  /// the last place to invent a figure, and the card beside it already says
  /// "Price unavailable".
  String _subscribeLabel(
    DesktopSubscriptionState subscription,
    DesktopPlan plan,
  ) {
    final planName = switch (plan) {
      DesktopPlan.monthly => t.settingsPage.planMonthly,
      DesktopPlan.yearly => t.settingsPage.planAnnual,
    };
    final price = subscription.productFor(plan)?.priceString;
    return price == null
        ? t.settingsPage.subscribeCtaNoPrice(plan: planName)
        : t.settingsPage.subscribeCta(plan: planName, price: price);
  }

  /// The ONE restore row, rendered by both states.
  ///
  /// It stays visible after subscribing on purpose: a Pro user whose
  /// entitlement has desynced (new Mac, reinstall, a purchase made on the
  /// iPhone) has no other way back, which is the gap the iPhone still has —
  /// it renders restore only in the non-Pro branch. Defined once so the two
  /// states cannot drift, and so neither can grow a second copy.
  Widget _restoreRow(bool busy) {
    return SettingsActionRow(
      id: 'subscription.restore',
      icon: LucideIcons.refreshCw,
      title: t.settingsPage.restorePurchases,
      detail: t.settingsPage.restorePurchasesDetail,
      busy: busy,
      onTap: () => unawaited(_restore()),
    );
  }

  Widget _featurePitch(BuildContext context) {
    return EvolvePanel(
      padding: const EdgeInsets.all(20),
      radius: 20,
      glowColor: proAccent,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: proAccent.withValues(alpha: 0.1),
                border: Border.all(color: proAccent.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                LucideIcons.sparkles,
                size: 26,
                color: proAccent,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              t.settingsPage.proUpsellTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.evolveColors.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.settingsPage.proUpsellSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.evolveColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Annual-plan subtitle carrying the two things Guideline 3.1.2 wants beyond
  /// the headline price: the price per month and a saving that is actually true.
  /// Both come from the store at runtime, never from constants — Apple's price
  /// tiers aren't linear across currencies, so a hardcoded "save X%" is false
  /// abroad. Returns null when no store price resolved, so the caller shows the
  /// neutral "best value" line instead of inventing a figure.
  String? _annualSubtitle(DesktopSubscriptionState subscription) {
    final yearly = subscription.yearlyProduct;
    final perMonth = yearly?.pricePerMonthString;
    if (yearly == null || perMonth == null) return null;
    final monthly = subscription.monthlyProduct;
    final percent = monthly == null
        ? null
        : annualSavingPercent(
            monthlyPrice: monthly.price,
            yearlyPrice: yearly.price,
          );
    if (percent == null) return t.settingsPage.perMonth(price: perMonth);
    return t.settingsPage.perMonthWithSavings(
      price: perMonth,
      percent: percent,
    );
  }

  // ---------------------------------------------------------------- Already Pro

  List<Widget> _proView(
    BuildContext context,
    DesktopSubscriptionState subscription,
  ) {
    final details = ref
        .read(desktopSubscriptionControllerProvider.notifier)
        .proDetails();
    return [
      EvolvePanel(
        padding: const EdgeInsets.all(20),
        radius: 20,
        glowColor: EvolveColors.success,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EvolveColors.success.withValues(alpha: 0.1),
                  border: Border.all(
                    color: EvolveColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  LucideIcons.shieldCheck,
                  size: 26,
                  color: EvolveColors.success,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                t.settingsPage.youArePro,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.evolveColors.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t.settingsPage.proThankYou,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.evolveColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      _SettingsColumn(
        groups: [
          SettingsGroup(
            title: t.settingsPage.detailsHeader,
            children: _detailRows(context, details),
          ),
          SettingsGroup(
            title: t.settingsPage.planManagement,
            children: [
              SettingsActionRow(
                id: 'subscription.manage',
                icon: LucideIcons.creditCard,
                title: t.settingsPage.manageSubscription,
                detail: t.settingsPage.manageSubscriptionDetail,
                external: true,
                onTap: () => unawaited(_manage()),
              ),
              _restoreRow(subscription.isLoading),
            ],
          ),
        ],
      ),
    ];
  }

  List<Widget> _detailRows(BuildContext context, DesktopProDetails? details) {
    final planLabel = switch (details?.productIdentifier) {
      _kMonthlyProductId =>
        '${t.settingsPage.proName} ${t.settingsPage.planMonthly}',
      _kYearlyProductId =>
        '${t.settingsPage.proName} ${t.settingsPage.planAnnual}',
      _ => t.settingsPage.proActiveName,
    };
    final expiration = details?.expiration;
    final dateFormat = DateFormat(
      'dd MMMM yyyy',
      LocaleSettings.currentLocale.languageCode,
    );
    return [
      SettingsInfoRow(
        icon: LucideIcons.sparkles,
        label: t.settingsPage.planLabel,
        value: planLabel,
      ),
      SettingsInfoRow(
        icon: LucideIcons.circleCheck,
        label: t.settingsPage.statusLabel,
        value: t.settingsPage.statusActive,
      ),
      if (expiration != null)
        SettingsInfoRow(
          icon: LucideIcons.calendar,
          label: (details?.willRenew ?? false)
              ? t.settingsPage.nextRenewal
              : t.settingsPage.expiresOn,
          value: dateFormat.format(expiration),
        ),
      if (details?.isAppStorePayment ?? false)
        SettingsInfoRow(
          icon: LucideIcons.creditCard,
          label: t.settingsPage.paymentMethod,
          value: t.settingsPage.paymentMethodValue,
        ),
    ];
  }

  // -------------------------------------------------------------------- Actions

  Future<void> _activate() async {
    final controller = ref.read(desktopSubscriptionControllerProvider.notifier);
    final plan = ref.read(desktopSelectedPlanProvider);
    var package = ref
        .read(desktopSubscriptionControllerProvider)
        .packageFor(plan);

    // Prices may be showing via the direct-product fallback while no Offering is
    // published — but a purchase needs a Package. Retry the offering load once,
    // then purchase if one materialised; otherwise surface the failure.
    if (package == null) {
      await controller.refresh();
      package = ref
          .read(desktopSubscriptionControllerProvider)
          .packageFor(plan);
      if (package == null) {
        if (mounted) {
          showEvolveToast(
            context,
            message: t.subscriptionCtrl.loadOffersFailed,
            kind: EvolveToastKind.error,
          );
        }
        return;
      }
    }

    final result = await controller.purchase(package);
    if (!mounted) return;
    switch (result.status) {
      case DesktopPurchaseStatus.activated:
        _showProSuccessDialog();
        break;
      case DesktopPurchaseStatus.cancelled:
        break;
      case DesktopPurchaseStatus.pending:
        showEvolveToast(
          context,
          message: result.message ?? t.subscriptionCtrl.paymentPending,
        );
        break;
      case DesktopPurchaseStatus.registeredNotActive:
        showEvolveToast(
          context,
          message: t.subscriptionCtrl.purchaseRegisteredNotActive,
        );
        break;
      case DesktopPurchaseStatus.failed:
        showEvolveToast(
          context,
          message: result.message ?? t.subscriptionCtrl.purchaseFailedMessage,
          kind: EvolveToastKind.error,
        );
        break;
    }
  }

  Future<void> _restore() async {
    final result = await ref
        .read(desktopSubscriptionControllerProvider.notifier)
        .restore();
    if (!mounted) return;
    switch (result.status) {
      case DesktopRestoreStatus.restored:
        showEvolveToast(
          context,
          message: t.subscriptionCtrl.purchasesRestored,
          kind: EvolveToastKind.success,
        );
        break;
      case DesktopRestoreStatus.noActiveSub:
        showEvolveToast(
          context,
          message: t.subscriptionCtrl.noActiveSubscription,
        );
        break;
      case DesktopRestoreStatus.cancelled:
        break;
      case DesktopRestoreStatus.failed:
        showEvolveToast(
          context,
          message: result.message ?? t.subscriptionCtrl.restoreFailedMessage,
          kind: EvolveToastKind.error,
        );
        break;
    }
  }

  Future<void> _manage() async {
    final ok = await ref
        .read(desktopSubscriptionControllerProvider.notifier)
        .manageSubscription();
    if (!ok && mounted) {
      showEvolveToast(
        context,
        message: t.subscriptionCtrl.cantOpenApple,
        kind: EvolveToastKind.error,
      );
    }
  }

  void _showProSuccessDialog() {
    showEvolveDialog<void>(
      context: context,
      builder: (dialogContext) => EvolveDialog(
        maxWidth: 420,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: proAccent.withValues(alpha: 0.1),
                  border: Border.all(color: proAccent.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  size: 34,
                  color: proAccent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t.settingsPage.proWelcomeTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.evolveColors.foreground,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t.settingsPage.proActiveMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.evolveColors.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: proAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    // In the modal paywall this closes it so the user lands back
                    // on the unlocked feature; in the Settings section it's null
                    // and the surface flips to the "already Pro" panel in place.
                    widget.onProActivated?.call();
                  },
                  child: Text(t.settingsPage.proStartJourney),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Guideline 3.1.2 disclosures for the purchase surface: the auto-renewal
/// statement plus functional links to the Privacy Policy and the EULA. Same
/// copy and same targets as the mobile paywall.
class _ComplianceLinks extends StatelessWidget {
  const _ComplianceLinks();

  @override
  Widget build(BuildContext context) {
    // Privacy follows the app's language; the EULA is Apple's, which Apple
    // hosts and localises itself.
    final privacyPolicy = LegalUrls.privacy(
      LocaleSettings.currentLocale.languageCode,
    );
    return Column(
      children: [
        Text(
          t.settingsPage.renewalDisclaimer,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.evolveColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegalLink(label: t.settingsPage.privacyPolicy, url: privacyPolicy),
            Text(
              '  •  ',
              style: TextStyle(color: context.evolveColors.muted, fontSize: 12),
            ),
            _LegalLink(
              label: t.settingsPage.termsEula,
              url: LegalUrls.appleEula,
            ),
          ],
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.url});

  final String label;
  final Uri url;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () =>
            unawaited(launchUrl(url, mode: LaunchMode.externalApplication)),
        child: Text(
          label,
          style: TextStyle(
            color: context.evolveAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: context.evolveAccent,
          ),
        ),
      ),
    );
  }
}

/// One of the two plan choices.
///
/// Selection used to be carried by an accent tint and an accent border and
/// nothing else — on a card whose price is already painted in that same
/// accent. Colour alone is a weak signal for the one control that decides what
/// the user is charged, it is no signal at all to anyone who cannot separate
/// the two hues, and it never reached the accessibility tree: both cards
/// announced identically. There is now a radio indicator that fills and
/// carries a checkmark, and a `selected` flag a screen reader can read.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final String title;

  /// Localized store price, or null when the offering has not resolved. Never
  /// substitute the plan name: the price slot must read as a price or as an
  /// explicit absence of one.
  final String? price;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // MergeSemantics so the card announces as ONE choice — "Annual, €29.99,
    // selected" — rather than as three unrelated strings next to a button.
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: selected
                  ? context.evolveAccent.withValues(alpha: 0.08)
                  : context.evolveColors.panel.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? context.evolveAccent
                    : context.evolveColors.border.withValues(alpha: 0.5),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: context.evolveAccent.withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PlanRadio(selected: selected),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  price ?? t.settingsPage.priceUnavailable,
                  style: price == null
                      ? TextStyle(
                          color: context.evolveColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )
                      : TextStyle(
                          color: context.evolveAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 5),
                  Text(detail!, style: settingsRowSubtitleStyle(context)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The plan card's selection indicator: a radio ring that fills with the accent
/// and carries a checkmark when chosen. Shape and glyph both change, so the
/// state survives being read in greyscale.
class _PlanRadio extends StatelessWidget {
  const _PlanRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = context.evolveAccent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? accent : Colors.transparent,
        border: Border.all(
          color: selected ? accent : context.evolveColors.border,
          width: selected ? 1 : 1.5,
        ),
      ),
      child: selected
          ? Icon(
              LucideIcons.check,
              size: 13,
              color: Theme.of(context).colorScheme.onPrimary,
            )
          : null,
    );
  }
}

/// Full name and date of birth, editable inline in the Account pane.
///
/// This was `_PersonalInfoDialog`. Two things were wrong with it beyond being a
/// modal for a routine edit. It was gated behind `if (!isPrivateMode)`, so a
/// Private-mode user could never change their own name or birthday — even
/// though `privateProfileProvider.updateProfile` was fully implemented and
/// simply unreachable. And its Email field was a labelled `hintText` with no
/// controller, which renders as an empty focusable box: the address was
/// invisible until you clicked into it. Email is now a read-only value row in
/// the pane, where it belongs.
///
/// Commits on blur, not per keystroke — the profile is synced, and writing on
/// every character would push a partial name to the iPhone.
class _PersonalInfoRows extends ConsumerStatefulWidget {
  const _PersonalInfoRows();

  @override
  ConsumerState<_PersonalInfoRows> createState() => _PersonalInfoRowsState();
}

class _PersonalInfoRowsState extends ConsumerState<_PersonalInfoRows> {
  final TextEditingController _name = TextEditingController();
  DateTime? _birthDate;

  /// What the store last confirmed, so a rejected edit can be put back. The
  /// dialog swallowed write failures whole (`catch (_)`), leaving the field
  /// showing a name nothing had stored — the same class of silent lie the rest
  /// of this page was fixed for.
  String _storedName = '';

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _hydrate() {
    final isPrivate = ref.read(activeDesktopDataModeProvider).isPrivate;
    final String? storedBirthDate;
    if (isPrivate) {
      final profile = ref.read(privateProfileProvider).value;
      _storedName = profile?.fullName ?? '';
      storedBirthDate = profile?.dateOfBirth;
    } else {
      final user = ref.read(desktopAuthControllerProvider).user;
      _storedName = user?.userMetadata?['full_name'] as String? ?? '';
      storedBirthDate = user?.userMetadata?['date_of_birth'] as String?;
    }
    _name.text = _storedName;
    // The profile stores an ISO `yyyy-MM-dd` string (or empty).
    _birthDate = storedBirthDate == null || storedBirthDate.trim().isEmpty
        ? null
        : DateTime.tryParse(storedBirthDate.trim());
  }

  /// The ISO `yyyy-MM-dd` shape the free-text field used to produce (empty
  /// string when unset), so profiles round-trip unchanged.
  String get _isoBirthDate {
    final date = _birthDate;
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _persist({
    required String name,
    required String birthDate,
  }) async {
    try {
      final isPrivate = ref.read(activeDesktopDataModeProvider).isPrivate;
      if (isPrivate) {
        await ref
            .read(privateProfileProvider.notifier)
            .updateProfile(fullName: name, dateOfBirth: birthDate);
      } else {
        await ref
            .read(desktopAuthControllerProvider.notifier)
            .updatePersonalInfo(fullName: name, dateOfBirth: birthDate);
      }
      _storedName = name;
    } catch (error, stack) {
      AppLogger.error('Unable to save personal information', error, stack);
      if (!mounted) return;
      setState(() {
        _name.text = _storedName;
        _hydrateBirthDateFromStore();
      });
      showEvolveToast(
        context,
        message: t.settingsPage.settingSaveFailed,
        kind: EvolveToastKind.error,
      );
    }
  }

  void _hydrateBirthDateFromStore() {
    final isPrivate = ref.read(activeDesktopDataModeProvider).isPrivate;
    final stored = isPrivate
        ? ref.read(privateProfileProvider).value?.dateOfBirth
        : ref
                  .read(desktopAuthControllerProvider)
                  .user
                  ?.userMetadata?['date_of_birth']
              as String?;
    _birthDate = stored == null || stored.trim().isEmpty
        ? null
        : DateTime.tryParse(stored.trim());
  }

  void _commitName(String value) {
    final name = value.trim();
    // An empty name is not a change, it is a mistake — the dialog's Save button
    // refused it too. Put the stored one back so the row does not sit there
    // blank, implying it saved.
    if (name.isEmpty) {
      setState(() => _name.text = _storedName);
      return;
    }
    if (name == _storedName) return;
    unawaited(_persist(name: name, birthDate: _isoBirthDate));
  }

  void _commitBirthDate(DateTime? date) {
    setState(() => _birthDate = date);
    final name = _name.text.trim();
    // Both fields go in one write, so a birthday change must not blank a name
    // the user has not filled in yet.
    if (name.isEmpty) return;
    unawaited(_persist(name: name, birthDate: _isoBirthDate));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsTextRow(
          id: 'account.fullName',
          label: t.settingsPage.fullName,
          controller: _name,
          onCommit: _commitName,
        ),
        const SettingsRowHairline(),
        SettingsDateRow(
          id: 'account.dateOfBirth',
          label: t.settingsPage.dateOfBirth,
          value: _birthDate,
          hint: t.settingsPage.dateOfBirthHint,
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          onChanged: _commitBirthDate,
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EvolveAlertDialog(
      icon: LucideIcons.keyRound,
      title: Text(t.settingsPage.changePassword),
      content: SizedBox(
        width: 470,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.settingsPage.currentPassword,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.settingsPage.newPassword,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.settingsPage.confirmNewPassword,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: EvolveColors.destructive),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.settingsPage.cancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: EvolveSpinner(radius: 9),
                )
              : Text(t.settingsPage.updatePassword),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_currentController.text.isEmpty) {
      setState(() => _error = t.settingsPage.enterCurrentPassword);
      return;
    }
    if (_newController.text.length < 8) {
      setState(() => _error = t.settingsPage.newPasswordMinLength);
      return;
    }
    if (_newController.text != _confirmController.text) {
      setState(() => _error = t.settingsPage.passwordsDontMatch);
      return;
    }
    setState(() {
      _error = null;
      _isSaving = true;
    });
    try {
      await ref
          .read(desktopAuthControllerProvider.notifier)
          .updatePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = t.settingsPage.passwordUpdateFailed;
        });
      }
    }
  }
}
