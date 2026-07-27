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
import 'package:evolve_desktop/features/ai_coach/application/coach_controllers.dart';
import 'package:evolve_desktop/features/ai_coach/application/coach_consent_controller.dart';
import 'package:evolve_desktop/features/ai_coach/domain/coach_backend.dart';
import 'package:evolve_desktop/features/ai_coach/presentation/coach_model_chip.dart';
import 'package:evolve_desktop/features/ai_coach/presentation/coach_settings_dialog.dart';
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
import 'package:evolve_desktop/shared/widgets/evolve_color_picker.dart';
import 'package:evolve_desktop/shared/widgets/popover.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:evolve_desktop/features/auth/application/desktop_profile_controller.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/core/rtl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum _SettingsSection {
  profile,
  appearance,
  notifications,
  aiCoach,
  privacy,
  subscription,
}

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
  _SettingsSection _section = _SettingsSection.profile;

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
  bool _aiInsights = true;
  bool _weeklyReport = true;
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
  void initState() {
    super.initState();
    // Deep-link: the data-loss SyncOffBanner asked to open straight on the
    // Privacy (iCloud-sync) section. Honour it here (pre-first-build, so no
    // setState needed) and clear the one-shot flag after the frame so a normal
    // visit still opens on Profile.
    if (ref.read(privacySettingsRequestProvider)) {
      _section = _SettingsSection.privacy;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(privacySettingsRequestProvider.notifier).consume();
        }
      });
    }
    if (ref.read(subscriptionSettingsRequestProvider)) {
      _section = _SettingsSection.subscription;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(subscriptionSettingsRequestProvider.notifier).consume();
        }
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
    ref.listen(subscriptionSettingsRequestProvider, (_, request) {
      if (request) {
        setState(() => _section = _SettingsSection.subscription);
        ref.read(subscriptionSettingsRequestProvider.notifier).consume();
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
    final availableSections = _SettingsSection.values.where((section) {
      if (isPrivateMode && section == _SettingsSection.subscription) {
        return false;
      }
      return true;
    }).toList();

    return DesktopPage(
      title: t.settingsPage.pageTitle,
      subtitle: t.settingsPage.pageSubtitle,
      // The group-card grid goes 2-up when the page content width (inside the
      // 28px gutters, LAYOUT_SPEC scale) reaches ~1280; below that the cards
      // stack full width.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumn = constraints.maxWidth >= 1280;
          return EvolvePanel(
            padding: EdgeInsets.zero,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 225,
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      children: [
                        for (final section in availableSections)
                          _SettingsDestination(
                            section: section,
                            selected: section == _section,
                            onTap: () => setState(() => _section = section),
                          ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: AlignmentDirectional.topStart,
                        children: [...previousChildren, ?currentChild],
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_section),
                        child: switch (_section) {
                          _SettingsSection.profile => _profile(twoColumn),
                          _SettingsSection.appearance => _appearance(twoColumn),
                          _SettingsSection.notifications => _notifications(
                            twoColumn,
                          ),
                          _SettingsSection.aiCoach => _aiCoach(twoColumn),
                          _SettingsSection.privacy => _privacy(twoColumn),
                          _SettingsSection.subscription =>
                            _SubscriptionSettings(twoColumn: twoColumn),
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _profile(bool twoColumn) {
    final auth = ref.watch(desktopAuthControllerProvider);
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(
          title: t.settingsPage.profileLabel,
          subtitle: t.settingsPage.profileSubtitle,
        ),
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
        _GroupGrid(
          twoColumn: twoColumn,
          groups: [
            _SettingsGroup(
              title: t.settingsPage.accountAndOnboarding,
              children: [
                _InfoRow(
                  icon: LucideIcons.mail,
                  label: t.settingsPage.account,
                  value: isPrivateMode
                      ? t.settingsPage.privateMode
                      : auth.user?.email ?? t.settingsPage.sessionUnavailable,
                ),
                _InfoRow(
                  icon: LucideIcons.database,
                  label: t.settingsPage.dataRepository,
                  value: isPrivateMode
                      ? t.settingsPage.encryptedLocalDatabase
                      : t.settingsPage.supabaseWithEncryptedCache,
                ),
                if (!isPrivateMode) ...[
                  _ActionRow(
                    icon: LucideIcons.user,
                    title: t.settingsPage.personalInfo,
                    detail: t.settingsPage.personalInfoDetail,
                    onTap: auth.isLoggedIn
                        ? () => showEvolveDialog<void>(
                            context: context,
                            builder: (context) => const _PersonalInfoDialog(),
                          )
                        : () => _showGate(
                            t.settingsPage.gateProfile,
                            t.settingsPage.gateRequiresActiveSession,
                          ),
                  ),
                  _ActionRow(
                    icon: LucideIcons.camera,
                    title: t.settingsPage.updateAvatar,
                    detail: t.settingsPage.updateAvatarDetail,
                    onTap: _pickAvatar,
                  ),
                  _ActionRow(
                    icon: LucideIcons.fileText,
                    title: t.settingsPage.reviewInitialConsent,
                    detail: t.settingsPage.reviewInitialConsentDetail,
                    onTap: _reviewConsent,
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (!isPrivateMode)
          _DestructiveButton(
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
          _DestructiveButton(
            label: t.settingsPage.goToLogin,
            caption: t.settingsPage.goToLoginDetail,
            onTap: () {
              ref.read(desktopAuthControllerProvider.notifier).goToLogin();
            },
          ),
      ],
    );
  }

  Widget _appearance(bool twoColumn) {
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(
          title: t.settingsPage.appearanceTitle,
          subtitle: t.settingsPage.appearanceSubtitle,
        ),
        const SizedBox(height: 20),
        _GroupGrid(
          twoColumn: twoColumn,
          groups: [
            _SettingsGroup(
              title: t.settingsPage.appearanceAndVisual,
              children: [
                // Three options, not a switch. A binary control cannot express
                // `'system'` — which the schema permits and which every user
                // who never picked a theme actually has — so one touch of the
                // old switch wrote a concrete 'dark'/'light' to the synced
                // store, pinned the iPhone too, and left no way back to "follow
                // system" from the Mac.
                _SelectRow<String>(
                  icon: LucideIcons.moon,
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
              ],
            ),
            _SettingsGroup(
              title: t.settingsPage.calendarExperienceLanguage,
              children: [
                _ColorRow(
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
                _SelectRow<String>(
                  icon: LucideIcons.calendar,
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
                _SelectRow<String>(
                  icon: LucideIcons.languages,
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
                _SwitchRow(
                  icon: LucideIcons.clock,
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
                // No haptic-feedback toggle on desktop: macOS generates no
                // haptics for this, so the row is hidden. The
                // pref_haptic_feedback column stays in the profiles row and
                // keeps syncing untouched for the mobile clients.
                _ActionRow(
                  icon: LucideIcons.info,
                  title: t.settingsPage.resetTutorial,
                  detail: t.settingsPage.resetTutorialDetail,
                  onTap: _resetTutorials,
                ),
                _ActionRow(
                  icon: LucideIcons.scrollText,
                  title: t.settingsPage.appLogsTitle,
                  detail: t.settingsPage.appLogsDetail,
                  onTap: () => unawaited(showAppLogsDialog(context)),
                ),
              ],
            ),
            // AI & System — the experience toggles the mobile client models in
            // AppSettings (same pref keys and defaults). In cloud mode they
            // stay local like on mobile (the Supabase profiles upsert never
            // includes them); in Private mode they persist to the encrypted
            // profiles row so they iCloud-sync across devices.
            _SettingsGroup(
              title: t.settingsPage.aiAndSystem,
              children: [
                _SwitchRow(
                  icon: LucideIcons.sparkles,
                  label: t.settingsPage.aiSuggestions,
                  detail: t.settingsPage.aiSuggestionsDetail,
                  // Pro-gated feature: badge the row like mobile instead of
                  // leaving it looking disabled.
                  badge: const EvolveProBadge(),
                  value: _aiSuggestions,
                  onChanged: (value) {
                    // Pro-gated exactly like mobile's toggleAi (Private mode
                    // is always entitled via desktopIsProProvider).
                    if (!ref.read(desktopIsProProvider)) {
                      unawaited(showProFeaturesDialog(context, ref));
                      return;
                    }
                    _setBool(
                      'pref_ai_suggestions',
                      value,
                      (v) => _aiSuggestions = v,
                      profileColumn: isPrivateMode
                          ? 'pref_ai_suggestions'
                          : null,
                    );
                  },
                ),
                _SwitchRow(
                  icon: LucideIcons.crosshair,
                  label: t.settingsPage.focusMode,
                  detail: t.settingsPage.focusModeDetail,
                  value: _focusMode,
                  onChanged: (value) {
                    _setBool(
                      'pref_focus_mode',
                      value,
                      (v) => _focusMode = v,
                      profileColumn: isPrivateMode ? 'pref_focus_mode' : null,
                    );
                    // Focus Mode suppresses local notifications (mobile
                    // parity) — re-sync so schedules are cancelled/restored.
                    unawaited(_syncNotifications());
                  },
                ),
                _SwitchRow(
                  icon: LucideIcons.flag,
                  label: t.settingsPage.milestones,
                  detail: t.settingsPage.milestonesDetail,
                  value: _milestones,
                  onChanged: (value) => _setBool(
                    'pref_milestones',
                    value,
                    (v) => _milestones = v,
                    profileColumn: isPrivateMode ? 'pref_milestones' : null,
                  ),
                ),
                _SwitchRow(
                  icon: LucideIcons.brain,
                  label: t.settingsPage.deepWorkInsights,
                  detail: t.settingsPage.deepWorkInsightsDetail,
                  value: _deepWorkInsights,
                  onChanged: (value) => _setBool(
                    'pref_deep_work_insights',
                    value,
                    (v) => _deepWorkInsights = v,
                    profileColumn: isPrivateMode
                        ? 'pref_deep_work_insights'
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _notifications(bool twoColumn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(
          title: t.settingsPage.notifications,
          subtitle: t.settingsPage.notificationsSubtitle,
        ),
        const SizedBox(height: 20),
        _GroupGrid(
          twoColumn: twoColumn,
          groups: [
            _SettingsGroup(
              title: t.settingsPage.operationalReminders,
              children: [
                _SwitchRow(
                  icon: LucideIcons.calendarCheck,
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
                if (_habitReminders)
                  _TimeRow(
                    icon: LucideIcons.sunrise,
                    label: t.settingsPage.morningBriefTime,
                    value: _morningTime,
                    use24hFormat: _timeFormat24h,
                    onChanged: (value) => _setNotificationString(
                      'notif_morning_brief_time',
                      value,
                      (v) => _morningTime = v,
                      previous: _morningTime,
                      profileColumn: 'morning_brief_time',
                    ),
                  ),
                _SwitchRow(
                  icon: LucideIcons.bellRing,
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
                if (_eveningReview)
                  _TimeRow(
                    icon: LucideIcons.sunset,
                    label: t.settingsPage.eveningReviewTime,
                    value: _eveningTime,
                    use24hFormat: _timeFormat24h,
                    onChanged: (value) => _setNotificationString(
                      'notif_evening_review_time',
                      value,
                      (v) => _eveningTime = v,
                      previous: _eveningTime,
                      profileColumn: 'evening_review_time',
                    ),
                  ),
                _ActionRow(
                  icon: LucideIcons.bell,
                  title: t.settingsPage.requestNotificationPermissions,
                  detail: t.settingsPage.requestNotificationPermissionsDetail,
                  onTap: _requestNotificationPermissions,
                ),
              ],
            ),
            // Insights & reports — notif_ai_insights / notif_weekly_reports
            // were already loaded and synced but had no rows here. Like the
            // other notification toggles they dual-write prefs + profiles row
            // and re-sync the local schedules; unlike the operational
            // reminders they do not prompt for permissions (mobile parity —
            // their delivery is still a placeholder there too).
            _SettingsGroup(
              title: t.settingsPage.insightsAndReports,
              children: [
                _SwitchRow(
                  icon: LucideIcons.lightbulb,
                  label: t.settingsPage.aiInsights,
                  detail: t.settingsPage.aiInsightsDetail,
                  value: _aiInsights,
                  onChanged: (value) => _setNotificationBool(
                    key: 'notif_ai_insights',
                    value: value,
                    update: (v) => _aiInsights = v,
                    profileColumn: 'notif_ai_insights',
                  ),
                ),
                _SwitchRow(
                  icon: LucideIcons.chartColumn,
                  label: t.settingsPage.weeklyReports,
                  detail: t.settingsPage.weeklyReportsDetail,
                  value: _weeklyReport,
                  onChanged: (value) => _setNotificationBool(
                    key: 'notif_weekly_reports',
                    value: value,
                    update: (v) => _weeklyReport = v,
                    profileColumn: 'notif_weekly_reports',
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        _PlatformNote(
          title: t.settingsPage.nativeDeliveryTitle,
          detail: DesktopNotificationService.instance.platformSummary,
        ),
      ],
    );
  }

  Widget _privacy(bool twoColumn) {
    final biometric = ref.watch(desktopBiometricControllerProvider);
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(
          title: t.settingsPage.privacyTitle,
          subtitle: t.settingsPage.privacySubtitle,
        ),
        const SizedBox(height: 20),
        _GroupGrid(
          twoColumn: twoColumn,
          groups: [
            // iCloud sync — Private mode on macOS only: the same E2E-encrypted
            // CloudKit dataset the iPhone app syncs.
            if (isPrivateMode && Platform.isMacOS)
              _SettingsGroup(
                title: t.icloudSync.title,
                children: [
                  _SwitchRow(
                    icon: LucideIcons.cloud,
                    label: t.icloudSync.enableTitle,
                    detail: _syncStatusLabel(),
                    value: _syncStatus?.isEnabled ?? false,
                    onChanged: _onSyncToggle,
                  ),
                  _ActionRow(
                    icon: LucideIcons.refreshCw,
                    title: t.icloudSync.syncNow,
                    detail: _lastSyncedLabel(),
                    onTap: _onSyncNow,
                  ),
                  // Only meaningful once there is a local store to inspect.
                  if (_syncDiagnostics != null)
                    _ActionRow(
                      icon: LucideIcons.listChecks,
                      title: t.icloudSync.detailsTitle,
                      detail: _diagnosticsLabel(_syncDiagnostics!),
                      onTap: () => _showDiagnosticsDialog(_syncDiagnostics!),
                    ),
                  // A key split cannot be resolved by waiting or retrying, so
                  // the only remedy gets its own row rather than hiding behind
                  // the diagnostics dialog.
                  if ((_syncStatus?.undecryptableCount ?? 0) > 0)
                    _ActionRow(
                      icon: LucideIcons.triangleAlert,
                      title: t.icloudSync.resetFromDevice,
                      detail: t.icloudSync.keySplitBody(
                        count: _syncStatus!.undecryptableCount,
                      ),
                      onTap: _onResetSyncFromThisDevice,
                    ),
                ],
              ),
            _SettingsGroup(
              title: t.settingsPage.accessProtection,
              children: [
                _SwitchRow(
                  icon: LucideIcons.shield,
                  label: t.settingsPage.biometricLock,
                  detail: t.settingsPage.biometricLockDetail,
                  value: biometric.enabled,
                  onChanged: _setBiometricLock,
                ),
                if (!isPrivateMode)
                  _ActionRow(
                    icon: LucideIcons.keyRound,
                    title: t.settingsPage.changePassword,
                    detail: t.settingsPage.changePasswordDetail,
                    onTap: ref.watch(desktopAuthControllerProvider).isLoggedIn
                        ? () => showEvolveDialog<void>(
                            context: context,
                            builder: (context) => const _ChangePasswordDialog(),
                          )
                        : () => _showGate(
                            t.settingsPage.gateChangePassword,
                            t.settingsPage.gateRequiresActiveSession,
                          ),
                  ),
              ],
            ),
            _SettingsGroup(
              title: t.settingsPage.dataAndConsents,
              children: [
                if (!isPrivateMode)
                  _SwitchRow(
                    icon: LucideIcons.circleAlert,
                    label: t.settingsPage.sendCrashReports,
                    detail: t.settingsPage.sendCrashReportsDetail,
                    value: _crashReports,
                    onChanged: _setCrashReportingConsent,
                  ),
                _ActionRow(
                  icon: LucideIcons.download,
                  title: t.settingsPage.exportData,
                  detail: t.settingsPage.exportDataDetail,
                  onTap: _exportData,
                ),
                _ActionRow(
                  icon: LucideIcons.upload,
                  title: t.settingsPage.importData,
                  detail: t.settingsPage.importDataDetail,
                  onTap: _importData,
                ),
                _ActionRow(
                  icon: LucideIcons.externalLink,
                  title: t.settingsPage.systemPermissionsManagement,
                  detail: t.settingsPage.systemPermissionsManagementDetail,
                  onTap: _openSystemPermissions,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (isPrivateMode)
          _DestructiveButton(
            label: t.settingsPage.deletePrivateData,
            caption: t.settingsPage.deletePrivateDataDetail,
            onTap: _deletePrivateData,
          )
        else
          _DestructiveButton(
            label: t.settingsPage.deleteAccountAndData,
            caption: t.settingsPage.deleteAccountAndDataDetail,
            onTap: _showDeleteOrResetDialog,
          ),
      ],
    );
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
              'goal_progress export read skipped (pre-migration?)', error, stack);
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
    if (status.undecryptableCount > 0) {
      return t.icloudSync.keySplitTitle;
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
      // device for a user with no backup to import — the local data is
      // unrecoverable anyway (key lost), which is exactly what this removes.
      // Kept as a fallback (not a pre-check) so the common path adds no latency.
      try {
        await DesktopPrivateDb.instance.resetLockedDatabase();
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
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _SettingsSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final contentColor = selected
        ? Theme.of(context).colorScheme.onPrimary
        : context.evolveColors.muted;
    return Padding(
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
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              child: Row(
                children: [
                  Icon(section.icon, color: contentColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension _AiCoachSection on _SettingsPageState {
  /// AI Coach engine settings: current engine at a glance + an entry into the
  /// full backend/local-server/model configuration dialog (the single config
  /// editor shared with the chat header).
  Widget _aiCoach(bool twoColumn) {
    final config = ref.watch(coachConfigProvider);
    // Shared with the chat header's chip rather than restated here: the two
    // labels naming the same engine differently is a bug waiting to be written,
    // and this copy had already grown its own three-way conditional.
    final backend = ref.watch(effectiveCoachBackendProvider);
    final engineValue = CoachModelChip.activeLabel(config, backend);
    final engineIcon = switch (backend) {
      CoachBackendKind.local => LucideIcons.cpu,
      CoachBackendKind.standard => LucideIcons.sparkles,
      CoachBackendKind.cloud => LucideIcons.cloud,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(
          title: t.coachSettings.settingsTitle,
          subtitle: t.coachSettings.settingsSubtitle,
        ),
        const SizedBox(height: 20),
        _GroupGrid(
          twoColumn: twoColumn,
          groups: [
            _SettingsGroup(
              // Distinct from the section heading ("AI Coach") above it.
              title: t.coachSettings.title,
              children: [
                _InfoRow(
                  icon: engineIcon,
                  label: t.coachSettings.settingsRowStatus,
                  value: engineValue,
                ),
                _ActionRow(
                  icon: LucideIcons.slidersHorizontal,
                  title: t.coachSettings.settingsRowConfigure,
                  detail: t.coachSettings.subtitle,
                  onTap: () => showCoachSettingsDialog(context),
                ),
                // Withdrawing consent must be as easy as giving it (GDPR Art.
                // 7(3) — Simone is the named controller), and Guideline 5.1.2
                // expects the same. Granting is one click in a dialog, so taking
                // it back is one click here. Renders only once a consent exists:
                // there is nothing to withdraw before that.
                if (ref.watch(hasAnyCoachConsentProvider).asData?.value ??
                    false)
                  _ActionRow(
                    icon: LucideIcons.shieldCheck,
                    title: t.ai.consent.rowTitle,
                    detail: t.ai.consent.statusGranted,
                    onTap: () => _revokeCoachConsent(context),
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

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

/// One settings group as a single titled card: the tiny uppercase muted label
/// sits inside an [EvolvePanel] (radius 20) above its rows, which render as
/// flat list tiles separated by hairline dividers — the macOS
/// grouped-settings look in the Evolve skin.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  /// Row count used by [_GroupGrid] to balance the two columns.
  int get rowCount => children.length;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      padding: EdgeInsets.zero,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 6),
            child: EvolveSectionLabel(title, withRule: false),
          ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const _RowHairline(),
            children[i],
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// 1px divider between the flat rows of a group card, indented past the icon
/// chip (16 content padding + 36 chip + 16 title gap).
class _RowHairline extends StatelessWidget {
  const _RowHairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsetsDirectional.only(start: 68),
      color: context.evolveColors.border.withValues(alpha: 0.35),
    );
  }
}

/// Adaptive tiling for the group cards: a single full-width column, or — when
/// the page content is wide enough — two columns filled greedily by row count
/// so their heights stay balanced. Cards never split across columns.
class _GroupGrid extends StatelessWidget {
  const _GroupGrid({required this.twoColumn, required this.groups});

  final bool twoColumn;
  final List<_SettingsGroup> groups;

  static const _gap = 18.0;

  Widget _column(List<_SettingsGroup> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: _gap),
          items[i],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!twoColumn || groups.length < 2) return _column(groups);
    final start = <_SettingsGroup>[];
    final end = <_SettingsGroup>[];
    var startRows = 0;
    var endRows = 0;
    for (final group in groups) {
      if (startRows <= endRows) {
        start.add(group);
        startRows += group.rowCount;
      } else {
        end.add(group);
        endRows += group.rowCount;
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _column(start)),
        const SizedBox(width: _gap),
        Expanded(child: _column(end)),
      ],
    );
  }
}

TextStyle _rowTitleStyle(BuildContext context) => TextStyle(
  color: context.evolveColors.foreground,
  fontSize: 15,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
);

TextStyle _rowSubtitleStyle(BuildContext context) => TextStyle(
  color: context.evolveColors.muted.withValues(alpha: 0.8),
  fontSize: 12,
  fontWeight: FontWeight.w500,
);

Widget _rowIconChip(BuildContext context, IconData icon) => EvolveIconChip(
  icon: icon,
  color: context.evolveAccent,
  size: 36,
  iconSize: 18,
  outlined: true,
);

/// Full-width destructive action styled exactly like the mobile
/// "Go to login" button (destructive .1 fill, .2 border, radius 14), with the
/// row's original detail text kept as a small muted caption underneath.
class _DestructiveButton extends StatelessWidget {
  const _DestructiveButton({
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: EvolveColors.destructive.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: EvolveColors.destructive.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: EvolveColors.destructive,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.evolveColors.muted.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Optional trailing chip after the title (e.g. the PRO badge on
  /// Pro-gated rows).
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _rowIconChip(context, icon),
      title: badge == null
          ? Text(label, style: _rowTitleStyle(context))
          : Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: _rowTitleStyle(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                badge!,
              ],
            ),
      subtitle: Text(detail, style: _rowSubtitleStyle(context)),
      trailing: EvolveSwitch(value: value, onChanged: onChanged),
    );
  }
}

/// Settings row wrapping an [EvolveSelect]. [value] and the options' values are
/// canonical CODES, never the rendered labels: [EvolveSelect] matches [value]
/// against the option values, so a localized label must not be the identity —
/// it would stop matching as soon as the UI language changes.
class _SelectRow<T> extends StatelessWidget {
  const _SelectRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final T value;
  final List<EvolveSelectOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _rowIconChip(context, icon),
      title: Text(label, style: _rowTitleStyle(context)),
      trailing: EvolveSelect<T>(
        value: value,
        options: options,
        onChanged: onChanged,
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.use24hFormat,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool use24hFormat;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final parts = value.split(':');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _rowIconChip(context, icon),
      title: Text(label, style: _rowTitleStyle(context)),
      trailing: EvolveTimePicker(
        value: TimeOfDay(
          hour: int.tryParse(parts.first) ?? 9,
          minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
        ),
        use24hFormat: use24hFormat,
        onChanged: (selected) => onChanged(
          '${selected.hour.toString().padLeft(2, '0')}:'
          '${selected.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.selected,
    required this.onChanged,
    this.customLocked = false,
    this.onCustomLocked,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Color selected;
  final ValueChanged<Color> onChanged;

  /// When true, the custom-color swatch is a Pro feature (mobile parity): it
  /// shows a lock and invokes [onCustomLocked] instead of opening the picker.
  final bool customLocked;
  final VoidCallback? onCustomLocked;

  @override
  Widget build(BuildContext context) {
    // RAW values, deliberately NOT mapped through `_visibleAccent` here. The
    // whole list used to be mapped before this loop, so `onChanged(color)`
    // below handed over the MAPPED colour: in a light theme, tapping the
    // leftmost "white" swatch stored and synced `#09090B` — a near-black the
    // user never chose — to every device. Mapping is a PAINT concern and now
    // happens per-swatch, one line above the widget that paints it.
    //
    // The first entry is the seed itself rather than a parallel literal, so it
    // cannot drift from what a fresh profile actually holds.
    final colors = [
      DesktopAppearanceController.defaultAccent,
      const Color(0xFFEAB308),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF97316),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _rowIconChip(context, icon),
          const SizedBox(width: 16),
          Expanded(
            child: _RowCopy(label: label, detail: detail),
          ),
          SizedBox(
            width: 220,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in colors)
                  // `color` is the stored identity — tooltip, equality and what
                  // gets published. `display` is pixels only.
                  Builder(
                    builder: (context) {
                      final display = _visibleAccent(context, color);
                      final isSelected = selected == color;
                      return Tooltip(
                        message: t.settingsPage.useAccent(hex: _toHex(color)),
                        child: InkWell(
                          onTap: () => onChanged(color),
                          customBorder: const CircleBorder(),
                          child: _Swatch(
                            color: display,
                            isSelected: isSelected,
                            child: isSelected
                                ? Icon(
                                    LucideIcons.check,
                                    size: 12,
                                    color: _checkColor(display),
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                Tooltip(
                  message: t.settingsPage.customColor,
                  child: InkWell(
                    onTap: customLocked
                        ? onCustomLocked
                        : () => _showFullColorPicker(context, colors.toList()),
                    customBorder: const CircleBorder(),
                    child: _Swatch(
                      color: context.evolveColors.panelRaised,
                      isSelected: false,
                      outlined: true,
                      child: Icon(
                        customLocked ? LucideIcons.lock : LucideIcons.plus,
                        size: 14,
                        color: context.evolveColors.foreground,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullColorPicker(BuildContext context, List<Color> colors) {
    showPopover(
      context: context,
      targetAlignment: Alignment.bottomCenter,
      popoverAlignment: Alignment.topCenter,
      offset: const Offset(0, 8),
      builder: (context) {
        return EvolveColorPickerContent(
          initialColor: selected,
          onColorChanged: onChanged,
        );
      },
    );
  }

  /// Paint-time substitution ONLY — never what gets stored or compared.
  ///
  /// Keyed off [DesktopAppearanceController.defaultAccent] rather than a
  /// repeated hex literal: the two were independent constants and drifted, so
  /// the substitution silently stopped firing for the seed white and the page
  /// painted an invisible swatch on a light background.
  Color _visibleAccent(BuildContext context, Color color) {
    if (Theme.of(context).brightness == Brightness.light &&
        color.toARGB32() ==
            DesktopAppearanceController.defaultAccent.toARGB32()) {
      return const Color(0xFF09090B);
    }
    return color;
  }

  Color _checkColor(Color color) =>
      color.computeLuminance() > 0.45 ? const Color(0xFF09090B) : Colors.white;

  String _toHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';
}

/// 24px color swatch circle; the selected one gets a foreground ring and a
/// soft tint glow (mobile color-picker recipe).
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.isSelected,
    this.outlined = false,
    this.child,
  });

  final Color color;
  final bool isSelected;
  final bool outlined;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: isSelected
            ? Border.all(color: context.evolveColors.foreground, width: 2)
            : outlined
            ? Border.all(color: context.evolveColors.border)
            : null,
        boxShadow: isSelected
            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
            : null,
      ),
      child: child == null ? null : Center(child: child),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _rowIconChip(context, icon),
      title: Text(title, style: _rowTitleStyle(context)),
      subtitle: Text(detail, style: _rowSubtitleStyle(context)),
      trailing: DirectionalIcon(
        LucideIcons.chevronRight,
        LucideIcons.chevronLeft,
        size: 18,
        color: context.evolveColors.muted,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _rowIconChip(context, icon),
      title: Text(label, style: _rowTitleStyle(context)),
      subtitle: Text(value, style: _rowSubtitleStyle(context)),
    );
  }
}

class _RowCopy extends StatelessWidget {
  const _RowCopy({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _rowTitleStyle(context)),
        const SizedBox(height: 3),
        Text(detail, style: _rowSubtitleStyle(context)),
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
            child: _RowCopy(label: title, detail: detail),
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
          twoColumn: false,
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
    required this.twoColumn,
    this.showFeaturePitch = true,
    this.onProActivated,
  });

  final bool twoColumn;

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
  String _plan = 'yearly';

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(desktopSubscriptionControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(
          title: t.settingsPage.proTitle,
          subtitle: t.settingsPage.proSubtitle,
        ),
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
              title: t.settingsPage.planMonthly,
              // Never fall back to the plan NAME here: that renders the title
              // twice where Guideline 3.1.2 requires the price per period. The
              // product resolves from the Offering or the direct-product fetch.
              price: subscription.monthlyProduct?.priceString,
              selected: _plan == 'monthly',
              onTap: () => setState(() => _plan = 'monthly'),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _PlanCard(
              title: t.settingsPage.planAnnual,
              price: subscription.yearlyProduct?.priceString,
              // Honest per-month + saving from live store prices, or the neutral
              // "best value" line when no price resolved — never an invented %.
              detail: _annualSubtitle(subscription) ?? t.settingsPage.bestValue,
              selected: _plan == 'yearly',
              onTap: () => setState(() => _plan = 'yearly'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const _ComplianceLinks(),
      const SizedBox(height: 24),
      _GroupGrid(
        twoColumn: widget.twoColumn,
        groups: [
          _SettingsGroup(
            title: t.settingsPage.planManagement,
            children: [
              _ActionRow(
                icon: LucideIcons.sparkles,
                title: t.settingsPage.activateEvolvePro,
                detail: t.settingsPage.activateEvolveProStart,
                onTap: busy ? () {} : () => unawaited(_activate()),
              ),
              _ActionRow(
                icon: LucideIcons.refreshCw,
                title: t.settingsPage.restorePurchases,
                detail: t.settingsPage.restorePurchasesDetail,
                onTap: busy ? () {} : () => unawaited(_restore()),
              ),
            ],
          ),
        ],
      ),
    ];
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
      _GroupGrid(
        twoColumn: widget.twoColumn,
        groups: [
          _SettingsGroup(
            title: t.settingsPage.detailsHeader,
            children: _detailRows(context, details),
          ),
          _SettingsGroup(
            title: t.settingsPage.planManagement,
            children: [
              _ActionRow(
                icon: LucideIcons.creditCard,
                title: t.settingsPage.manageSubscription,
                detail: t.settingsPage.manageSubscriptionDetail,
                onTap: () => unawaited(_manage()),
              ),
              _ActionRow(
                icon: LucideIcons.refreshCw,
                title: t.settingsPage.restorePurchases,
                detail: t.settingsPage.restorePurchasesDetail,
                onTap: subscription.isLoading
                    ? () {}
                    : () => unawaited(_restore()),
              ),
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
      _InfoRow(
        icon: LucideIcons.sparkles,
        label: t.settingsPage.planLabel,
        value: planLabel,
      ),
      _InfoRow(
        icon: LucideIcons.circleCheck,
        label: t.settingsPage.statusLabel,
        value: t.settingsPage.statusActive,
      ),
      if (expiration != null)
        _InfoRow(
          icon: LucideIcons.calendar,
          label: (details?.willRenew ?? false)
              ? t.settingsPage.nextRenewal
              : t.settingsPage.expiresOn,
          value: dateFormat.format(expiration),
        ),
      if (details?.isAppStorePayment ?? false)
        _InfoRow(
          icon: LucideIcons.creditCard,
          label: t.settingsPage.paymentMethod,
          value: t.settingsPage.paymentMethodValue,
        ),
    ];
  }

  // -------------------------------------------------------------------- Actions

  Future<void> _activate() async {
    final controller = ref.read(desktopSubscriptionControllerProvider.notifier);
    var package = _plan == 'monthly'
        ? ref.read(desktopSubscriptionControllerProvider).monthlyPackage
        : ref.read(desktopSubscriptionControllerProvider).yearlyPackage;

    // Prices may be showing via the direct-product fallback while no Offering is
    // published — but a purchase needs a Package. Retry the offering load once,
    // then purchase if one materialised; otherwise surface the failure.
    if (package == null) {
      await controller.refresh();
      final refreshed = ref.read(desktopSubscriptionControllerProvider);
      package = _plan == 'monthly'
          ? refreshed.monthlyPackage
          : refreshed.yearlyPackage;
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
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
    return InkWell(
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
            Text(title, style: Theme.of(context).textTheme.titleLarge),
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
              Text(detail!, style: _rowSubtitleStyle(context)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PersonalInfoDialog extends ConsumerStatefulWidget {
  const _PersonalInfoDialog();

  @override
  ConsumerState<_PersonalInfoDialog> createState() =>
      _PersonalInfoDialogState();
}

class _PersonalInfoDialogState extends ConsumerState<_PersonalInfoDialog> {
  late final TextEditingController _nameController;
  DateTime? _birthDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final isPrivate = ref.read(activeDesktopDataModeProvider).isPrivate;
    final String? storedBirthDate;
    if (isPrivate) {
      final profile = ref.read(privateProfileProvider).value;
      _nameController = TextEditingController(text: profile?.fullName);
      storedBirthDate = profile?.dateOfBirth;
    } else {
      final user = ref.read(desktopAuthControllerProvider).user;
      _nameController = TextEditingController(
        text: user?.userMetadata?['full_name'] as String?,
      );
      storedBirthDate = user?.userMetadata?['date_of_birth'] as String?;
    }
    // The profile stores an ISO `yyyy-MM-dd` string (or empty).
    _birthDate = storedBirthDate == null || storedBirthDate.trim().isEmpty
        ? null
        : DateTime.tryParse(storedBirthDate.trim());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPrivate = ref.watch(activeDesktopDataModeProvider).isPrivate;
    final email = ref.watch(desktopAuthControllerProvider).user?.email;
    return EvolveAlertDialog(
      icon: LucideIcons.user,
      title: Text(t.settingsPage.personalInfo),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: t.settingsPage.fullName),
            ),
            if (!isPrivate) ...[
              const SizedBox(height: 10),
              TextField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: t.settingsPage.email,
                  hintText: email ?? t.settingsPage.sessionUnavailable,
                ),
              ),
            ],
            const SizedBox(height: 10),
            EvolveDateField(
              value: _birthDate,
              label: t.settingsPage.dateOfBirth,
              hint: t.settingsPage.dateOfBirthHint,
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              onChanged: (date) => setState(() => _birthDate = date),
            ),
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
              : Text(t.settingsPage.save),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    // Persist the same ISO `yyyy-MM-dd` shape the free-text field produced
    // (empty string when unset), so profiles round-trip unchanged.
    final birthDate = _birthDate == null
        ? ''
        : '${_birthDate!.year.toString().padLeft(4, '0')}-'
              '${_birthDate!.month.toString().padLeft(2, '0')}-'
              '${_birthDate!.day.toString().padLeft(2, '0')}';
    setState(() => _isSaving = true);
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
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
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

extension on _SettingsSection {
  String get label => switch (this) {
    _SettingsSection.profile => t.settingsPage.profileLabel,
    _SettingsSection.appearance => t.settingsPage.sectionApplication,
    _SettingsSection.notifications => t.settingsPage.notifications,
    _SettingsSection.aiCoach => t.coachSettings.settingsSectionLabel,
    _SettingsSection.privacy => t.settingsPage.sectionPrivacy,
    _SettingsSection.subscription => t.settingsPage.subscription,
  };

  IconData get icon => switch (this) {
    _SettingsSection.profile => LucideIcons.user,
    _SettingsSection.appearance => LucideIcons.settings,
    _SettingsSection.notifications => LucideIcons.bell,
    _SettingsSection.aiCoach => LucideIcons.bot,
    _SettingsSection.privacy => LucideIcons.shield,
    _SettingsSection.subscription => LucideIcons.sparkles,
  };
}
