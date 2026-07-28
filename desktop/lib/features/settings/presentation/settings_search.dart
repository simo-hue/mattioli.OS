import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';

/// One searchable setting.
///
/// [label] and [detail] are closures, not strings: the index is a top-level
/// constant list, and resolving `t.…` at construction time would freeze the
/// English labels into it for the life of the isolate. The language picker is
/// itself one of the entries, so that bug would be visible the moment anyone
/// used the feature.
class SettingsSearchEntry {
  const SettingsSearchEntry({
    required this.id,
    required this.section,
    required this.label,
    this.detail,
    this.keywords = const [],
    this.availability = SettingsRowAvailability.always,
  });

  /// Matches the `id` passed to the row widget, which is also the key tests
  /// navigate by. `settings_search_index_test` asserts every entry here
  /// actually renders — the index cannot be derived from the panes, so it is
  /// held honest by a test rather than by hope.
  final String id;
  final SettingsSection section;
  final String Function() label;
  final String Function()? detail;

  /// Extra query terms that are not in the visible copy — what a user would
  /// plausibly type looking for this. "dark mode" finds Theme; "password"
  /// finds the sign-in row; "backup" finds export.
  final List<String> keywords;

  final SettingsRowAvailability availability;

  bool isAvailable({required bool isPrivateMode}) => switch (availability) {
    SettingsRowAvailability.always => true,
    SettingsRowAvailability.accountOnly => !isPrivateMode,
    SettingsRowAvailability.privateOnly => isPrivateMode,
  };
}

enum SettingsRowAvailability { always, accountOnly, privateOnly }

/// Everything the sidebar search can find.
///
/// ~40 controls across eight panes with no filter field is why this exists:
/// macOS System Settings puts search at the top of the source list, and it is
/// the baseline users compare against.
const List<SettingsSearchEntry> kSettingsSearchIndex = [
  // ── Account ───────────────────────────────────────────────────────────────
  SettingsSearchEntry(
    id: 'account.email',
    section: SettingsSection.account,
    label: _emailLabel,
    availability: SettingsRowAvailability.accountOnly,
    keywords: ['email', 'sign in', 'login'],
  ),
  SettingsSearchEntry(
    id: 'account.fullName',
    section: SettingsSection.account,
    label: _fullNameLabel,
    keywords: ['name', 'personal information', 'profile'],
  ),
  SettingsSearchEntry(
    id: 'account.dateOfBirth',
    section: SettingsSection.account,
    label: _dateOfBirthLabel,
    keywords: ['birthday', 'date of birth', 'age', 'personal information'],
  ),
  SettingsSearchEntry(
    id: 'account.changePassword',
    section: SettingsSection.account,
    label: _changePasswordLabel,
    detail: _changePasswordDetail,
    availability: SettingsRowAvailability.accountOnly,
    keywords: ['password', 'credentials', 'security'],
  ),
  SettingsSearchEntry(
    id: 'account.resetConsent',
    section: SettingsSection.account,
    label: _resetConsentLabel,
    detail: _resetConsentDetail,
    availability: SettingsRowAvailability.accountOnly,
    keywords: ['consent', 'terms', 'onboarding'],
  ),
  SettingsSearchEntry(
    id: 'account.dataStorage',
    section: SettingsSection.account,
    label: _dataStorageLabel,
    keywords: ['storage', 'private mode', 'where'],
  ),

  // ── General ───────────────────────────────────────────────────────────────
  SettingsSearchEntry(
    id: 'general.theme',
    section: SettingsSection.general,
    label: _themeLabel,
    keywords: ['dark mode', 'light', 'appearance'],
  ),
  SettingsSearchEntry(
    id: 'general.accent',
    section: SettingsSection.general,
    label: _accentLabel,
    detail: _accentDetail,
    keywords: ['colour', 'color', 'accent', 'theme'],
  ),
  SettingsSearchEntry(
    id: 'general.calendarView',
    section: SettingsSection.general,
    label: _calendarViewLabel,
    keywords: ['calendar', 'month', 'week', 'year'],
  ),
  SettingsSearchEntry(
    id: 'general.language',
    section: SettingsSection.general,
    label: _languageLabel,
    keywords: ['language', 'locale', 'translation'],
  ),
  SettingsSearchEntry(
    id: 'general.timeFormat',
    section: SettingsSection.general,
    label: _timeFormatLabel,
    detail: _timeFormatDetail,
    keywords: ['24 hour', 'clock', 'am pm', 'time'],
  ),
  SettingsSearchEntry(
    id: 'general.replayTour',
    section: SettingsSection.general,
    label: _replayTourLabel,
    detail: _replayTourDetail,
    keywords: ['tutorial', 'tour', 'onboarding', 'guide'],
  ),

  // ── Notifications ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    id: 'notifications.focusMode',
    section: SettingsSection.notifications,
    label: _focusModeLabel,
    detail: _focusModeDetail,
    keywords: ['focus', 'do not disturb', 'mute', 'pause'],
  ),
  SettingsSearchEntry(
    id: 'notifications.morningBrief',
    section: SettingsSection.notifications,
    label: _morningBriefLabel,
    detail: _morningBriefDetail,
    keywords: ['reminder', 'morning', 'habits'],
  ),
  SettingsSearchEntry(
    id: 'notifications.morningBriefTime',
    section: SettingsSection.notifications,
    label: _morningBriefTimeLabel,
    keywords: ['time', 'schedule', 'morning'],
  ),
  SettingsSearchEntry(
    id: 'notifications.eveningReview',
    section: SettingsSection.notifications,
    label: _eveningReviewLabel,
    detail: _eveningReviewDetail,
    keywords: ['reminder', 'evening', 'review'],
  ),
  SettingsSearchEntry(
    id: 'notifications.eveningReviewTime',
    section: SettingsSection.notifications,
    label: _eveningReviewTimeLabel,
    keywords: ['time', 'schedule', 'evening'],
  ),
  SettingsSearchEntry(
    id: 'notifications.permission',
    section: SettingsSection.notifications,
    label: _notificationPermissionLabel,
    detail: _notificationPermissionDetail,
    keywords: ['permission', 'allow', 'system'],
  ),

  // ── AI Coach ──────────────────────────────────────────────────────────────
  SettingsSearchEntry(
    id: 'coach.dataSharing',
    section: SettingsSection.aiCoach,
    label: _coachSharingLabel,
    keywords: ['ai', 'coach', 'consent', 'privacy', 'sharing'],
  ),

  // ── Data & Backup ─────────────────────────────────────────────────────────
  SettingsSearchEntry(
    id: 'data.icloudSync',
    section: SettingsSection.dataBackup,
    label: _icloudEnableLabel,
    availability: SettingsRowAvailability.privateOnly,
    keywords: ['icloud', 'sync', 'devices', 'iphone'],
  ),
  SettingsSearchEntry(
    id: 'data.syncNow',
    section: SettingsSection.dataBackup,
    label: _syncNowLabel,
    availability: SettingsRowAvailability.privateOnly,
    keywords: ['sync', 'refresh', 'now'],
  ),
  SettingsSearchEntry(
    id: 'data.accountSync',
    section: SettingsSection.dataBackup,
    label: _icloudSyncLabel,
    availability: SettingsRowAvailability.accountOnly,
    keywords: ['sync', 'cloud', 'devices'],
  ),
  SettingsSearchEntry(
    id: 'data.export',
    section: SettingsSection.dataBackup,
    label: _exportLabel,
    detail: _exportDetail,
    keywords: ['backup', 'export', 'json', 'save'],
  ),
  SettingsSearchEntry(
    id: 'data.import',
    section: SettingsSection.dataBackup,
    label: _importLabel,
    detail: _importDetail,
    keywords: ['backup', 'import', 'restore', 'merge'],
  ),

  // ── Privacy & Security ────────────────────────────────────────────────────
  SettingsSearchEntry(
    id: 'privacy.appLock',
    section: SettingsSection.privacy,
    label: _appLockLabel,
    detail: _appLockDetail,
    keywords: ['touch id', 'lock', 'biometric', 'security'],
  ),
  SettingsSearchEntry(
    id: 'privacy.crashReports',
    section: SettingsSection.privacy,
    label: _crashReportsLabel,
    detail: _crashReportsDetail,
    availability: SettingsRowAvailability.accountOnly,
    keywords: ['crash', 'diagnostics', 'telemetry', 'analytics'],
  ),
  SettingsSearchEntry(
    id: 'privacy.systemPermissions',
    section: SettingsSection.privacy,
    label: _systemPermissionsLabel,
    detail: _systemPermissionsDetail,
    keywords: ['permissions', 'system settings', 'access'],
  ),
  SettingsSearchEntry(
    id: 'privacy.privacyPolicy',
    section: SettingsSection.privacy,
    label: _privacyPolicyLabel,
    keywords: ['legal', 'policy', 'gdpr'],
  ),
  SettingsSearchEntry(
    id: 'privacy.terms',
    section: SettingsSection.privacy,
    label: _termsLabel,
    keywords: ['legal', 'terms', 'eula', 'licence'],
  ),

  // ── Advanced ──────────────────────────────────────────────────────────────
  SettingsSearchEntry(
    id: 'advanced.appLogs',
    section: SettingsSection.advanced,
    label: _appLogsLabel,
    detail: _appLogsDetail,
    keywords: ['logs', 'debug', 'diagnostics', 'support'],
  ),
  SettingsSearchEntry(
    id: 'advanced.restoreDefaults',
    section: SettingsSection.advanced,
    label: _restoreDefaultsLabel,
    detail: _restoreDefaultsDetail,
    keywords: ['reset', 'defaults', 'restore'],
  ),
];

/// One match, carrying *why* it matched.
///
/// The sidebar does not care — it shows the list in order — but the ⌘K palette
/// does: it has to decide whether a settings hit outranks the generic "Create
/// goal “…”" row that every query produces. "The user typed this setting's
/// name" and "the word appears somewhere in this setting's help text" are very
/// different claims, and [isLabelMatch] is the line between them.
class SettingsSearchHit {
  const SettingsSearchHit({required this.entry, required this.rank});

  final SettingsSearchEntry entry;

  /// 0 = label prefix, 1 = label substring, 2 = keyword, 3 = help text.
  /// Lower is better; the list is returned sorted by it.
  final int rank;

  /// Whether the query appears in the setting's own visible label, rather than
  /// only in its hidden keywords or its help text.
  bool get isLabelMatch => rank <= 1;
}

/// Ranked matches for [query], best first.
///
/// Ranking: a label that starts with the query, then a label that contains it,
/// then a keyword hit, then help text. Without it, typing "time" put "Morning
/// brief time" below whatever happened to mention the word first.
List<SettingsSearchHit> searchSettingsRanked(
  String query, {
  required bool isPrivateMode,
  List<SettingsSearchEntry> index = kSettingsSearchIndex,
}) {
  final needle = _fold(query);
  if (needle.isEmpty) return const [];

  final scored = <(int, int, SettingsSearchEntry)>[];
  for (var i = 0; i < index.length; i++) {
    final entry = index[i];
    if (!entry.isAvailable(isPrivateMode: isPrivateMode)) continue;

    final label = _fold(entry.label());
    final detail = _fold(entry.detail?.call() ?? '');
    final rank = label.startsWith(needle)
        ? 0
        : label.contains(needle)
        ? 1
        : entry.keywords.any((k) => _fold(k).contains(needle))
        ? 2
        : detail.contains(needle)
        ? 3
        : -1;
    if (rank < 0) continue;
    // `i` is the tiebreak, so equal-rank matches keep index (rail) order
    // instead of coming out in whatever order the sort happened to produce.
    scored.add((rank, i, entry));
  }

  scored.sort((a, b) {
    final byRank = a.$1.compareTo(b.$1);
    return byRank != 0 ? byRank : a.$2.compareTo(b.$2);
  });
  return [
    for (final (rank, _, entry) in scored)
      SettingsSearchHit(entry: entry, rank: rank),
  ];
}

/// Ranked matches for [query], without the match reason. The sidebar's form.
List<SettingsSearchEntry> searchSettings(
  String query, {
  required bool isPrivateMode,
  List<SettingsSearchEntry> index = kSettingsSearchIndex,
}) => [
  for (final hit in searchSettingsRanked(
    query,
    isPrivateMode: isPrivateMode,
    index: index,
  ))
    hit.entry,
];

/// Lower-cases and strips the accents Latin-script locales put in the middle of
/// otherwise matching words, so "idioma" finds "Idioma" and, more to the point,
/// "grafica" finds "Grafica"/"Gráfica" whichever way the user types it.
String _fold(String value) {
  final lower = value.toLowerCase().trim();
  const from = 'áàâäãåéèêëíìîïóòôöõúùûüñçß';
  const to = 'aaaaaaeeeeiiiiooooouuuuncs';
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final at = from.indexOf(char);
    buffer.write(at < 0 ? char : to[at]);
  }
  return buffer.toString();
}

// Label/detail closures. Top-level functions rather than lambdas so the index
// above can stay `const`.
String _emailLabel() => t.settingsPage.email;
String _fullNameLabel() => t.settingsPage.fullName;
String _dateOfBirthLabel() => t.settingsPage.dateOfBirth;
String _changePasswordLabel() => t.settingsPage.changePassword;
String _changePasswordDetail() => t.settingsPage.changePasswordDetail;
String _resetConsentLabel() => t.settingsPage.reviewInitialConsent;
String _resetConsentDetail() => t.settingsPage.reviewInitialConsentDetail;
String _dataStorageLabel() => t.settingsPage.dataStorage;
String _themeLabel() => t.settingsPage.themeMode;
String _accentLabel() => t.settingsPage.accentColor;
String _accentDetail() => t.settingsPage.accentColorDetail;
String _calendarViewLabel() => t.settingsPage.defaultCalendarView;
String _languageLabel() => t.settingsPage.language;
String _timeFormatLabel() => t.settingsPage.timeFormat24h;
String _timeFormatDetail() => t.settingsPage.timeFormat24hDetail;
String _replayTourLabel() => t.settingsPage.resetTutorial;
String _replayTourDetail() => t.settingsPage.resetTutorialDetail;
String _focusModeLabel() => t.settingsPage.focusMode;
String _focusModeDetail() => t.settingsPage.focusModeDetail;
String _morningBriefLabel() => t.settingsPage.habitReminders;
String _morningBriefDetail() => t.settingsPage.habitRemindersDetail;
String _morningBriefTimeLabel() => t.settingsPage.morningBriefTime;
String _eveningReviewLabel() => t.settingsPage.eveningReview;
String _eveningReviewDetail() => t.settingsPage.eveningReviewDetail;
String _eveningReviewTimeLabel() => t.settingsPage.eveningReviewTime;
String _notificationPermissionLabel() =>
    t.settingsPage.requestNotificationPermissions;
String _notificationPermissionDetail() =>
    t.settingsPage.requestNotificationPermissionsDetail;
String _coachSharingLabel() => t.ai.consent.rowTitle;
String _icloudSyncLabel() => t.icloudSync.title;
String _icloudEnableLabel() => t.icloudSync.enableTitle;
String _syncNowLabel() => t.icloudSync.syncNow;
String _exportLabel() => t.settingsPage.exportData;
String _exportDetail() => t.settingsPage.exportDataDetail;
String _importLabel() => t.settingsPage.importData;
String _importDetail() => t.settingsPage.importDataDetail;
String _appLockLabel() => t.settingsPage.biometricLock;
String _appLockDetail() => t.settingsPage.biometricLockDetail;
String _crashReportsLabel() => t.settingsPage.sendCrashReports;
String _crashReportsDetail() => t.settingsPage.sendCrashReportsDetail;
String _systemPermissionsLabel() => t.settingsPage.systemPermissionsManagement;
String _systemPermissionsDetail() =>
    t.settingsPage.systemPermissionsManagementDetail;
String _privacyPolicyLabel() => t.settingsPage.privacyPolicy;
String _termsLabel() => t.settingsPage.termsEula;
String _appLogsLabel() => t.settingsPage.appLogsTitle;
String _appLogsDetail() => t.settingsPage.appLogsDetail;
String _restoreDefaultsLabel() => t.settingsPage.restoreDefaults;
String _restoreDefaultsDetail() => t.settingsPage.restoreDefaultsDetail;
