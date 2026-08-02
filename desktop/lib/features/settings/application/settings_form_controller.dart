import 'dart:async';

import 'package:evolve_desktop/app/localization/desktop_locale_controller.dart';
import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/calendar_view_preference.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/auth/application/consent_controller.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/settings/application/desktop_biometric_controller.dart';
import 'package:evolve_desktop/features/settings/application/desktop_synced_settings.dart';
import 'package:evolve_desktop/features/settings/data/desktop_notification_service.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every value the Settings panes render and write.
///
/// This used to be seventeen mutable fields on `_SettingsPageState`, which is
/// why every pane had to be a method on that one class: a pane cannot move out
/// of a file while the state it reads is private to a widget in it.
///
/// No `==`/`hashCode` on purpose. `setState` rebuilt unconditionally, and a
/// value-equal state object would silently start skipping notifications — a
/// different behaviour than the one every test was written against.
@immutable
class SettingsFormState {
  const SettingsFormState({
    required this.themeMode,
    required this.timeFormat24h,
    required this.habitReminders,
    required this.eveningReview,
    required this.goalDeadlines,
    required this.aiInsights,
    required this.weeklyReport,
    required this.crashReports,
    required this.aiSuggestions,
    required this.focusMode,
    required this.milestones,
    required this.deepWorkInsights,
    required this.calendarView,
    required this.language,
    required this.morningTime,
    required this.eveningTime,
    required this.accent,
    this.saveFailures = 0,
  });

  /// The first-launch values, i.e. the old FIELD INITIALISERS.
  ///
  /// These are not the same decision as the `?? SettingsCodec.default…`
  /// fallbacks in [SettingsFormController.build]: initialisation early-returns
  /// when SharedPreferences is absent, so these win on a fresh install, while
  /// the fallbacks win when prefs exist but hold nothing. `settings_parity_test`
  /// asserts BOTH cases — do not collapse them into one default.
  const SettingsFormState.initial()
    : this(
        // The canonical theme CODE ('light'/'dark'/'system'), not a bool.
        //
        // It used to be `bool _darkMode`, and every write derived from it
        // collapsed `'system'` — the value the schema permits and the one every
        // user who never picked a theme has — into a concrete theme. The prefs
        // mirror is what `DesktopAppearanceController.build()` reads on the next
        // cold start, so a collapsed mirror destroyed "follow system"
        // permanently on a Mac that never completes a pull.
        themeMode: SettingsCodec.themeSystem,
        timeFormat24h: true,
        habitReminders: true,
        eveningReview: true,
        goalDeadlines: true,
        // FALSE, matching both the `?? false` in `build` and mobile's
        // AppSettings. They used to initialise to `true`, and because
        // initialisation early-returns when SharedPreferences is absent, the
        // initialiser won on a fresh install — so a first-launch Mac pushed
        // `true` into the synced row and switched both features on for an
        // iPhone that had them off.
        //
        // Neither has a UI row any more (nothing on either platform delivers an
        // AI insight or a weekly report), but both still sync, so the value this
        // holds still reaches the phone.
        aiInsights: false,
        weeklyReport: false,
        crashReports: true,
        // Experience/Pro toggles (mobile parity — same keys and defaults as
        // mobile's AppSettings: ai/focus/deep-work OFF, milestones ON).
        aiSuggestions: false,
        focusMode: false,
        milestones: true,
        deepWorkInsights: false,
        // Canonical CODES, not display labels: these are what gets persisted,
        // and the pickers match on them, so they must not move when the UI
        // language does.
        calendarView: kCalendarViewWeek,
        language: SettingsCodec.languageSystem,
        // The canonical defaults, from the shared codec — these MUST match the
        // `profiles` schema DEFAULTs and mobile. They used to read
        // '08:00'/'20:30' here, and because initialisation early-returns when
        // SharedPreferences is absent they won whenever prefs were empty: a
        // first-launch Mac dragged the iPhone's briefs 60 and 30 minutes earlier
        // the first time any toggle was touched.
        morningTime: SettingsCodec.defaultMorningBriefTime,
        eveningTime: SettingsCodec.defaultEveningReviewTime,
        // The accent SEED, not a theme token. `EvolveColors.primaryStrong` is
        // chrome that legitimately stays #FAFAFA; borrowing it here made the
        // page's idea of "no accent yet" a third independent literal. `build`
        // overwrites this from the controller, so the practical effect is nil —
        // but the drift it invites is exactly how the Mac and the iPhone ended
        // up on different whites.
        accent: DesktopAppearanceController.defaultAccent,
      );

  final String themeMode;
  final bool timeFormat24h;
  final bool habitReminders;
  final bool eveningReview;
  final bool goalDeadlines;
  final bool aiInsights;
  final bool weeklyReport;
  final bool crashReports;
  final bool aiSuggestions;
  final bool focusMode;
  final bool milestones;
  final bool deepWorkInsights;
  final String calendarView;
  final String language;
  final String morningTime;
  final String eveningTime;
  final Color accent;

  /// Monotonic count of writes that were attempted and failed.
  ///
  /// The toast belongs to the page — it needs an Overlay and the page's own
  /// `mounted` — so the controller reports the failure as a state change the
  /// page listens for, rather than taking a BuildContext it would have to hold
  /// across an await.
  final int saveFailures;

  SettingsFormState copyWith({
    String? themeMode,
    bool? timeFormat24h,
    bool? habitReminders,
    bool? eveningReview,
    bool? goalDeadlines,
    bool? aiInsights,
    bool? weeklyReport,
    bool? crashReports,
    bool? aiSuggestions,
    bool? focusMode,
    bool? milestones,
    bool? deepWorkInsights,
    String? calendarView,
    String? language,
    String? morningTime,
    String? eveningTime,
    Color? accent,
    int? saveFailures,
  }) {
    return SettingsFormState(
      themeMode: themeMode ?? this.themeMode,
      timeFormat24h: timeFormat24h ?? this.timeFormat24h,
      habitReminders: habitReminders ?? this.habitReminders,
      eveningReview: eveningReview ?? this.eveningReview,
      goalDeadlines: goalDeadlines ?? this.goalDeadlines,
      aiInsights: aiInsights ?? this.aiInsights,
      weeklyReport: weeklyReport ?? this.weeklyReport,
      crashReports: crashReports ?? this.crashReports,
      aiSuggestions: aiSuggestions ?? this.aiSuggestions,
      focusMode: focusMode ?? this.focusMode,
      milestones: milestones ?? this.milestones,
      deepWorkInsights: deepWorkInsights ?? this.deepWorkInsights,
      calendarView: calendarView ?? this.calendarView,
      language: language ?? this.language,
      morningTime: morningTime ?? this.morningTime,
      eveningTime: eveningTime ?? this.eveningTime,
      accent: accent ?? this.accent,
      saveFailures: saveFailures ?? this.saveFailures,
    );
  }
}

/// Owns the Settings form: its values, the local prefs mirror, the synced-store
/// write and the read-back that hydrates from it.
///
/// Kept alive, and scoped instead by [SettingsFormController.hydrate] /
/// [SettingsFormController.detach].
///
/// `autoDispose` would be the obvious way to tie this to the page, and it is
/// wrong here: Riverpod schedules the disposal on a zero-duration Timer, which
/// is still pending when a widget test tears down right after unmounting the
/// page. The attach flag below reproduces the page's `mounted` exactly — every
/// place that used to read it now reads `_attached` — with no scheduler
/// involved.
final settingsFormControllerProvider =
    NotifierProvider<SettingsFormController, SettingsFormState>(
      SettingsFormController.new,
    );

class SettingsFormController extends Notifier<SettingsFormState> {
  /// Whether a settings page is currently on screen.
  ///
  /// The stand-in for `_SettingsPageState.mounted`: hydration, the rollback and
  /// the pull listener all used to be gated on it, and a controller that
  /// outlives the page must not go on writing the prefs mirror and rebuilding
  /// the notification schedule after the page is gone.
  bool _attached = false;

  /// Whether the synced store has answered at least once this session.
  ///
  /// The read is kicked off UNAWAITED from [hydrate], and in Private mode it
  /// costs an encrypted-DB open plus a Keychain round-trip — the page is fully
  /// interactive throughout. Without this latch, [applySyncedSettings] came back
  /// and overwrote every field, so a toggle flipped during that window snapped
  /// back on screen and in the prefs mirror while `_syncProfile` had already
  /// written the new value to the store: the UI then disagreed with what was
  /// stored for the rest of the session, silently.
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
  /// In Supabase mode nothing ever clears it, because [applySyncedSettings] is
  /// a no-op there — harmless, since that mode never consults it, and it is
  /// bounded by the number of synced keys either way.
  final Set<String> _preloadEdits = <String>{};

  @override
  SettingsFormState build() {
    // A sync pull invalidates the synced settings; re-hydrate the visible fields
    // so a preference changed on the iPhone shows up here without a restart.
    ref.listen(desktopSyncedSettingsProvider, (_, next) {
      if (!_attached) return;
      final values = next.value;
      if (values != null && values.isNotEmpty) {
        unawaited(applySyncedSettings(values));
      }
    });

    // `read`, never `watch`: watching would re-run this build — and reset every
    // field to its initial value — the moment the user changed the accent.
    final preferences = ref.read(sharedPreferencesProvider);
    final appearance = ref.read(desktopAppearanceControllerProvider);
    var next = const SettingsFormState.initial().copyWith(
      themeMode: DesktopAppearanceController.themeCodeFor(appearance.themeMode),
      accent: appearance.accentColor,
    );
    // The synced store is the authority; the prefs below are only the local
    // mirror used until it answers. [hydrate] kicks the read-back off even when
    // there are no preferences to read, otherwise a fresh install never
    // hydrates.
    if (preferences == null) return next;

    next = next.copyWith(
      timeFormat24h: preferences.getBool('pref_time_format_24h') ?? true,
      habitReminders: preferences.getBool('notif_habit_reminders') ?? true,
      eveningReview: preferences.getBool('notif_evening_review') ?? true,
      goalDeadlines: preferences.getBool('notif_goal_deadlines') ?? true,
      // Mobile parity: AI insights and weekly reports default OFF.
      aiInsights: preferences.getBool('notif_ai_insights') ?? false,
      weeklyReport: preferences.getBool('notif_weekly_reports') ?? false,
      // Unanswered is not consent: the Settings switch has to read back the
      // same OFF that the consent screen offers, or the UI would claim a
      // permission the user never gave (Guideline 5.1.2).
      crashReports: preferences.getBool('has_sentry_consent') ?? false,
      aiSuggestions: preferences.getBool('pref_ai_suggestions') ?? false,
      focusMode: preferences.getBool('pref_focus_mode') ?? false,
      milestones: preferences.getBool('pref_milestones') ?? true,
      deepWorkInsights: preferences.getBool('pref_deep_work_insights') ?? false,
      // The pref stores the canonical CODE ('mese'…); older builds stored the
      // display label — normalizeCalendarViewCode accepts both.
      calendarView: normalizeCalendarViewCode(
        preferences.getString('pref_default_calendar_view'),
      ),
      language: SettingsCodec.normalizeLanguage(
        preferences.getString('pref_language') ??
            preferences.getString('language'),
      ),
      // NOTE the two different names on purpose: 'notif_morning_brief_time' is
      // the SharedPreferences key, 'morning_brief_time' is the DB column /
      // synced key. The legacy prefs fallback below reads the OLD prefs
      // spelling, not the column — conflating them would make a prefs read look
      // like a store read.
      morningTime:
          SettingsCodec.normalizeTimeOfDay(
            preferences.getString('notif_morning_brief_time') ??
                preferences.getString('morning_brief_time'),
          ) ??
          SettingsCodec.defaultMorningBriefTime,
      eveningTime:
          SettingsCodec.normalizeTimeOfDay(
            preferences.getString('notif_evening_review_time') ??
                preferences.getString('evening_review_time'),
          ) ??
          SettingsCodec.defaultEveningReviewTime,
    );
    return next;
  }

  /// What the page's `initState` used to do after the prefs reads: re-read the
  /// live appearance, arm the in-flight-edit guard for this visit, and kick the
  /// read-back off UNAWAITED.
  ///
  /// Separate from [build] rather than folded into it because
  /// [applySyncedSettings] can resolve synchronously — the store is often
  /// already cached — and a notifier may not assign `state` while its own build
  /// is still running.
  void hydrate() {
    _attached = true;
    // Reset per-visit, exactly as a fresh `State` did: an edit made before this
    // visit's first read lands must win over what that read delivers.
    _syncedLoaded = false;
    _preloadEdits.clear();
    // One microtask late, because `initState` runs inside the widget build
    // phase and Riverpod refuses to let a provider be modified there — while
    // both halves below do exactly that: the appearance re-read assigns `state`,
    // and [loadProfilePreferences] applies an already-cached synced map
    // synchronously, which also writes the theme/accent/locale controllers.
    // `setState` had no such rule, which is why the page could do this inline.
    // Still far earlier than anything the user could touch.
    scheduleMicrotask(() {
      if (!_attached) return;
      final appearance = ref.read(desktopAppearanceControllerProvider);
      state = state.copyWith(
        themeMode: DesktopAppearanceController.themeCodeFor(
          appearance.themeMode,
        ),
        accent: appearance.accentColor,
      );
      unawaited(loadProfilePreferences());
    });
  }

  /// The page has left the screen. Mirrors what `!mounted` used to shut off.
  void detach() => _attached = false;

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  void setThemeMode(String value) {
    // The controller is mutated BEFORE the write is attempted, so the rollback
    // has to put it back too — reverting only the row would leave the whole app
    // repainted in a theme that was never stored.
    final previousMode = ref
        .read(desktopAppearanceControllerProvider)
        .themeMode;
    ref
        .read(desktopAppearanceControllerProvider.notifier)
        .setThemeMode(DesktopAppearanceController.themeModeFor(value));
    _setString(
      'pref_theme_mode',
      value,
      (v) => state = state.copyWith(themeMode: v),
      previous: state.themeMode,
      profileColumn: 'theme_mode',
      profileValue: value,
      alsoRevert: () => ref
          .read(desktopAppearanceControllerProvider.notifier)
          .setThemeMode(previousMode),
    );
  }

  /// The accent's OWN rollback path.
  ///
  /// This does NOT go through [_setBool]/[_setString], so it needs its own
  /// rollback — a fix that only touched those two helpers would leave the
  /// accent, one of the two symptoms this whole effort started from, still
  /// failing in silence. `settings_write_failure_test` pins it.
  void setAccentColor(Color color) {
    final previousAccent = ref
        .read(desktopAppearanceControllerProvider)
        .accentColor;
    ref
        .read(desktopAppearanceControllerProvider.notifier)
        .setAccentColor(color);
    // Re-read rather than reuse `color`: the controller normalises what it was
    // handed, and the value that reaches the store must be the one on screen.
    final accent = ref.read(desktopAppearanceControllerProvider).accentColor;
    state = state.copyWith(accent: accent);
    unawaited(
      _persistOrRollback(
        values: {'accent_color': dashboardColorToHex(accent)},
        revert: () {
          ref
              .read(desktopAppearanceControllerProvider.notifier)
              .setAccentColor(previousAccent);
          state = state.copyWith(accent: previousAccent);
        },
      ),
    );
  }

  /// Persists the canonical CODE ('mese'…) in BOTH SharedPreferences and the
  /// profiles row (they used to diverge: prefs got the label, the profile the
  /// code).
  void setCalendarView(String value) => _setString(
    'pref_default_calendar_view',
    value,
    (v) => state = state.copyWith(calendarView: v),
    previous: state.calendarView,
    profileColumn: 'pref_default_calendar_view',
  );

  void setLanguage(String value) => _setString(
    'pref_language',
    value,
    // Takes the value it is HANDED, not the tapped one: on a failed write this
    // same callback is re-run with the previous language, and the live locale
    // controller has to come back with it or the app keeps speaking a language
    // nothing stored.
    (v) {
      state = state.copyWith(language: v);
      ref.read(desktopLocaleControllerProvider.notifier).setLanguage(v);
    },
    previous: state.language,
    profileColumn: 'language',
    profileValue: value,
  );

  void setTimeFormat24h(bool value) => _setBool(
    'pref_time_format_24h',
    value,
    (v) => state = state.copyWith(timeFormat24h: v),
    profileColumn: 'pref_time_format_24h',
  );

  void setFocusMode(bool value) {
    // Stays local in account mode (profileColumn is null there), so this
    // deliberately makes no cross-device claim.
    _setBool(
      'pref_focus_mode',
      value,
      (v) => state = state.copyWith(focusMode: v),
      profileColumn: ref.read(activeDesktopDataModeProvider).isPrivate
          ? 'pref_focus_mode'
          : null,
    );
    unawaited(syncNotifications());
  }

  void setHabitReminders(bool value) => _setNotificationBool(
    key: 'notif_habit_reminders',
    value: value,
    update: (v) => state = state.copyWith(habitReminders: v),
    profileColumn: 'notif_habit_reminders',
    requestPermissions: value,
  );

  void setEveningReview(bool value) => _setNotificationBool(
    key: 'notif_evening_review',
    value: value,
    update: (v) => state = state.copyWith(eveningReview: v),
    profileColumn: 'notif_evening_review',
    requestPermissions: value,
  );

  void setMorningTime(String value) => _setNotificationString(
    'notif_morning_brief_time',
    value,
    (v) => state = state.copyWith(morningTime: v),
    previous: state.morningTime,
    profileColumn: 'morning_brief_time',
  );

  void setEveningTime(String value) => _setNotificationString(
    'notif_evening_review_time',
    value,
    (v) => state = state.copyWith(eveningTime: v),
    previous: state.eveningTime,
    profileColumn: 'evening_review_time',
  );

  Future<void> setCrashReports(bool value) async {
    final consent = ref.read(desktopConsentControllerProvider);
    state = state.copyWith(crashReports: value);
    await ref
        .read(desktopConsentControllerProvider.notifier)
        .setConsent(
          acceptedTerms: consent.hasAcceptedTerms,
          sentryConsent: value,
          completed: consent.hasCompletedOnboarding,
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
      // The schedule is rebuilt from the controller's fields, so a rollback has
      // to rebuild it again or macOS keeps firing on the un-stored setting.
      alsoRevert: () => unawaited(syncNotifications()),
    );
    if (requestPermissions) {
      unawaited(DesktopNotificationService.instance.requestPermissions());
    }
    unawaited(syncNotifications());
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
      alsoRevert: () => unawaited(syncNotifications()),
    );
    unawaited(syncNotifications());
  }

  Future<void> syncNotifications() async {
    await DesktopNotificationService.instance.sync(
      habitReminders: state.habitReminders,
      eveningReview: state.eveningReview,
      morningBriefTime: state.morningTime,
      eveningReviewTime: state.eveningTime,
      habits: ref.read(dashboardControllerProvider).habits,
      // Focus Mode cancels every scheduled notification (mobile parity).
      focusMode: state.focusMode,
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
    update(value);
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
    update(value);
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

  // ---------------------------------------------------------------------------
  // Hydration
  // ---------------------------------------------------------------------------

  /// Hydrates the form (and the live controllers) from whichever store owns the
  /// settings in the active mode.
  Future<void> loadProfilePreferences() async {
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
        // `ref.listen` registered in [build] fires when the value arrives AND
        // this await resumes with the same map, so [applySyncedSettings] ran
        // twice: the first pass released the in-flight-edit guard and the
        // second then clobbered the very edit the guard existed to protect.
        //
        // It also let a STALE generation win: an invalidation mid-await (every
        // sync pull invalidates this provider) leaves the old future to
        // complete after the listener has already applied the newer map.
        //
        // Nothing is lost by not awaiting: [build] and [hydrate] run in the same
        // frame, so the listener is in place before any future can complete, and
        // it delivers the first value.
        final values = ref.read(desktopSyncedSettingsProvider).value;
        if (values != null) await applySyncedSettings(values);
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
      if (!_attached || profile == null) return;
      ref
          .read(desktopAppearanceControllerProvider.notifier)
          .applyProfile(
            themeMode: profile['theme_mode'] as String?,
            accentColor: profile['accent_color'] as String?,
          );
      final appearance = ref.read(desktopAppearanceControllerProvider);
      state = state.copyWith(
        themeMode: DesktopAppearanceController.themeCodeFor(
          appearance.themeMode,
        ),
        timeFormat24h:
            profile['pref_time_format_24h'] as bool? ?? state.timeFormat24h,
        habitReminders:
            profile['notif_habit_reminders'] as bool? ?? state.habitReminders,
        eveningReview:
            profile['notif_evening_review'] as bool? ?? state.eveningReview,
        goalDeadlines:
            profile['notif_goal_deadlines'] as bool? ?? state.goalDeadlines,
        aiInsights: profile['notif_ai_insights'] as bool? ?? state.aiInsights,
        weeklyReport:
            profile['notif_weekly_reports'] as bool? ?? state.weeklyReport,
        calendarView: normalizeCalendarViewCode(
          profile['pref_default_calendar_view'] as String?,
        ),
        language: SettingsCodec.normalizeLanguage(
          profile['language'] as String?,
        ),
        morningTime:
            SettingsCodec.normalizeTimeOfDay(
              profile['morning_brief_time'] as String?,
            ) ??
            state.morningTime,
        eveningTime:
            SettingsCodec.normalizeTimeOfDay(
              profile['evening_review_time'] as String?,
            ) ??
            state.eveningTime,
        accent: appearance.accentColor,
      );
      // Reading is not enough: the locale controller is what actually changes
      // the UI language, so the pulled value has to reach it.
      ref
          .read(desktopLocaleControllerProvider.notifier)
          .applyProfile(state.language);
      final preferences = ref.read(sharedPreferencesProvider);
      if (preferences != null) {
        await Future.wait([
          // `applyProfile` no longer writes the prefs mirror (a read path must
          // not mutate), so the hydration that OWNS this refresh writes it.
          preferences.setString('pref_theme_mode', state.themeMode),
          preferences.setString(
            'pref_accent_color',
            dashboardColorToHex(state.accent),
          ),
          // The LEGACY bool needs a yes/no, so 'system' is resolved for this
          // key alone. `pref_theme_mode` above keeps the three-valued truth.
          preferences.setBool(
            'desktop_dark_mode',
            DesktopAppearanceController.resolvesDark(appearance.themeMode),
          ),
          preferences.setBool('pref_time_format_24h', state.timeFormat24h),
          preferences.setBool('notif_habit_reminders', state.habitReminders),
          preferences.setBool('notif_evening_review', state.eveningReview),
          preferences.setBool('notif_goal_deadlines', state.goalDeadlines),
          preferences.setBool('notif_ai_insights', state.aiInsights),
          preferences.setBool('notif_weekly_reports', state.weeklyReport),
          // Prefs hold the canonical code, never the display label.
          preferences.setString(
            'pref_default_calendar_view',
            state.calendarView,
          ),
          preferences.setString('pref_language', state.language),
          preferences.setString('notif_morning_brief_time', state.morningTime),
          preferences.setString('notif_evening_review_time', state.eveningTime),
          preferences.setInt('accent_color', state.accent.toARGB32()),
        ]);
      }
      final biometric = profile['biometric_lock'] as bool?;
      if (biometric != null) {
        await ref
            .read(desktopBiometricControllerProvider.notifier)
            .applyProfile(biometric);
      }
      await syncNotifications();
    } catch (error, stack) {
      AppLogger.error('Unable to download desktop preferences', error, stack);
    }
  }

  /// Applies settings READ from the synced store: the live controllers first
  /// (theme / accent / language), then this form's fields, then the local prefs
  /// mirror, then the notification schedule.
  ///
  /// Keys the store has no value for are left untouched — [SyncedSettingsStore]
  /// omits "never set" keys precisely so a caller can keep its own default
  /// instead of being handed a fabricated one.
  Future<void> applySyncedSettings(Map<String, String?> values) async {
    if (values.isEmpty || !_attached) return;

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

    // Theme, accent and language live in controllers, not in this form. Without
    // this the fields below would show the pulled values while the app went on
    // rendering the old theme and speaking the old language.
    applyDesktopSyncedSettingsFromRef(ref, incoming);
    final appearance = ref.read(desktopAppearanceControllerProvider);

    bool boolOr(String key, bool current) =>
        SyncedSettingsStore.decodeBool(incoming[key]) ?? current;

    state = state.copyWith(
      themeMode: DesktopAppearanceController.themeCodeFor(appearance.themeMode),
      accent: appearance.accentColor,
      timeFormat24h: boolOr(kSettingTimeFormat24h, state.timeFormat24h),
      habitReminders: boolOr(kSettingHabitReminders, state.habitReminders),
      eveningReview: boolOr(kSettingEveningReview, state.eveningReview),
      goalDeadlines: boolOr(kSettingGoalDeadlines, state.goalDeadlines),
      aiInsights: boolOr(kSettingAiInsights, state.aiInsights),
      weeklyReport: boolOr(kSettingWeeklyReports, state.weeklyReport),
      aiSuggestions: boolOr(kSettingAiSuggestions, state.aiSuggestions),
      focusMode: boolOr(kSettingFocusMode, state.focusMode),
      milestones: boolOr(kSettingMilestones, state.milestones),
      deepWorkInsights: boolOr(
        kSettingDeepWorkInsights,
        state.deepWorkInsights,
      ),
      calendarView: incoming.containsKey(kSettingCalendarView)
          ? normalizeCalendarViewCode(incoming[kSettingCalendarView])
          : state.calendarView,
      language: incoming.containsKey(kSettingLanguage)
          ? SettingsCodec.normalizeLanguage(incoming[kSettingLanguage])
          : state.language,
      morningTime:
          SettingsCodec.normalizeTimeOfDay(
            incoming[kSettingMorningBriefTime],
          ) ??
          state.morningTime,
      eveningTime:
          SettingsCodec.normalizeTimeOfDay(
            incoming[kSettingEveningReviewTime],
          ) ??
          state.eveningTime,
    );

    // Released HERE, not on the next tap: from now on this form is hydrated, so
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
        preferences.setString('pref_theme_mode', state.themeMode),
        preferences.setString(
          'pref_accent_color',
          dashboardColorToHex(state.accent),
        ),
        preferences.setBool(
          'desktop_dark_mode',
          DesktopAppearanceController.resolvesDark(appearance.themeMode),
        ),
        preferences.setInt('accent_color', state.accent.toARGB32()),
        preferences.setBool('pref_time_format_24h', state.timeFormat24h),
        preferences.setBool('notif_habit_reminders', state.habitReminders),
        preferences.setBool('notif_evening_review', state.eveningReview),
        preferences.setBool('notif_goal_deadlines', state.goalDeadlines),
        preferences.setBool('notif_ai_insights', state.aiInsights),
        preferences.setBool('notif_weekly_reports', state.weeklyReport),
        preferences.setBool('pref_ai_suggestions', state.aiSuggestions),
        preferences.setBool('pref_focus_mode', state.focusMode),
        preferences.setBool('pref_milestones', state.milestones),
        preferences.setBool('pref_deep_work_insights', state.deepWorkInsights),
        preferences.setString('pref_default_calendar_view', state.calendarView),
        preferences.setString('pref_language', state.language),
        // Prefs key ≠ DB column, deliberately: 'notif_morning_brief_time' here,
        // 'morning_brief_time' in the store.
        preferences.setString('notif_morning_brief_time', state.morningTime),
        preferences.setString('notif_evening_review_time', state.eveningTime),
      ]);
    }

    // Times and toggles only take effect once the schedule is rebuilt. Guarded:
    // the prefs write above is awaited, so the page can be gone by now.
    if (!_attached) return;
    await syncNotifications();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

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
    // Keyed on the synced column name, which IS the key [applySyncedSettings]
    // reads, so the two always agree on what "this setting" means.
    if (!_syncedLoaded) _preloadEdits.addAll(values.keys);
    if (await _syncProfile(values)) return;
    if (!_attached) return;
    revert();
    reportSaveFailure();
  }

  /// Raises the failure counter the page listens on so it can toast.
  void reportSaveFailure() =>
      state = state.copyWith(saveFailures: state.saveFailures + 1);

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

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Puts every setting back to its default, locally and in the synced store.
  ///
  /// Reports the failure through [reportSaveFailure] rather than returning it:
  /// the local state has already been reset across two dozen fields and
  /// un-resetting them piecemeal would be its own bug, but the user must still
  /// be told, or a reset that never reached the store looks exactly like one
  /// that did.
  Future<void> resetSettingsToDefaults() async {
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
    state = state.copyWith(
      // Reset stays on an explicit 'dark' rather than 'system', matching
      // mobile's reset — changing only desktop would break parity.
      themeMode: SettingsCodec.themeDark,
      accent: DesktopAppearanceController.defaultAccent,
      calendarView: kCalendarViewWeek,
      language: SettingsCodec.languageSystem,
      timeFormat24h: true,
      habitReminders: true,
      goalDeadlines: true,
      // Mobile defaults: AI insights and weekly reports start OFF (matches
      // the initial-state defaults and the profile values synced below).
      aiInsights: false,
      weeklyReport: false,
      aiSuggestions: false,
      focusMode: false,
      milestones: true,
      deepWorkInsights: false,
      eveningReview: true,
      morningTime: SettingsCodec.defaultMorningBriefTime,
      eveningTime: SettingsCodec.defaultEveningReviewTime,
    );
    await ref
        .read(desktopBiometricControllerProvider.notifier)
        .setEnabled(false);
    // Only keys in PrivateDbSchema.syncedSettingKeys. `biometric_lock` used to
    // be in this payload and is now device-local: a reset on the Mac must not
    // reach across and unlock the user's iPhone. It is reset locally, above.
    // `_syncProfile` filters the map, so this list is the contract, not a hope.
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
    if (!saved && _attached) reportSaveFailure();
    await syncNotifications();
  }
}
