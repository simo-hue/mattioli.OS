import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/app/localization/desktop_locale_controller.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/application/consent_controller.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/settings/application/desktop_biometric_controller.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/settings/data/desktop_notification_service.dart';
import 'package:evolve_desktop/features/settings/data/desktop_system_settings_service.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _SettingsSection {
  profile,
  appearance,
  notifications,
  privacy,
  subscription,
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  _SettingsSection _section = _SettingsSection.profile;
  bool _darkMode = true;
  bool _timeFormat24h = true;
  bool _habitReminders = true;
  bool _eveningReview = true;
  bool _goalDeadlines = true;
  bool _aiInsights = true;
  bool _weeklyReport = true;
  bool _crashReports = true;
  String _calendarView = 'Settimana';
  String _language = 'Sistema';
  String _morningTime = '08:00';
  String _eveningTime = '20:30';
  Color _accent = EvolveColors.primaryStrong;
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    final preferences = ref.read(sharedPreferencesProvider);
    final appearance = ref.read(desktopAppearanceControllerProvider);
    _darkMode = appearance.themeMode != ThemeMode.light;
    _accent = appearance.accentColor;
    if (preferences == null) return;
    _timeFormat24h = preferences.getBool('pref_time_format_24h') ?? true;
    _habitReminders = preferences.getBool('notif_habit_reminders') ?? true;
    _eveningReview = preferences.getBool('notif_evening_review') ?? true;
    _goalDeadlines = preferences.getBool('notif_goal_deadlines') ?? true;
    _aiInsights = preferences.getBool('notif_ai_insights') ?? true;
    _weeklyReport = preferences.getBool('notif_weekly_reports') ?? true;
    _crashReports = preferences.getBool('has_sentry_consent') ?? true;
    _calendarView =
        preferences.getString('pref_default_calendar_view') ?? 'Settimana';
    _language = _languageLabel(
      preferences.getString('pref_language') ??
          preferences.getString('language'),
    );
    _morningTime =
        preferences.getString('notif_morning_brief_time') ??
        preferences.getString('morning_brief_time') ??
        '09:00';
    _eveningTime =
        preferences.getString('notif_evening_review_time') ??
        preferences.getString('evening_review_time') ??
        '21:00';
    unawaited(_loadProfilePreferences());
  }

  @override
  Widget build(BuildContext context) {
    return DesktopPage(
      title: 'Impostazioni',
      subtitle:
          'Gestisci profilo, comportamento desktop, privacy e piano Evolve.',
      child: EvolvePanel(
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
                    for (final section in _SettingsSection.values)
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
                child: switch (_section) {
                  _SettingsSection.profile => _profile(),
                  _SettingsSection.appearance => _appearance(),
                  _SettingsSection.notifications => _notifications(),
                  _SettingsSection.privacy => _privacy(),
                  _SettingsSection.subscription =>
                    const _SubscriptionSettings(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profile() {
    final backendConfigured = ref.watch(backendConfiguredProvider);
    final auth = ref.watch(desktopAuthControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SettingsHeading(
          title: 'Profilo',
          subtitle: 'Informazioni personali e stato sincronizzazione',
        ),
        const SizedBox(height: 17),
        _ProfileCard(
          user: auth.user,
          image: _profileImage,
          isPro: ref.watch(desktopSubscriptionControllerProvider).isPro,
          onPickAvatar: _pickAvatar,
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Account e onboarding',
          children: [
            _InfoRow(
              label: 'Account',
              value: auth.user?.email ?? 'Preview locale',
            ),
            _InfoRow(
              label: 'Repository dati',
              value: backendConfigured
                  ? 'Supabase con cache cifrata'
                  : 'In-memory preview',
              color: backendConfigured
                  ? context.evolveAccent
                  : EvolveColors.amber,
            ),
            _ActionRow(
              icon: Icons.badge_outlined,
              title: 'Informazioni personali',
              detail: 'Nome, cognome, email e data di nascita',
              onTap: auth.isLoggedIn
                  ? () => showDialog<void>(
                      context: context,
                      builder: (context) => const _PersonalInfoDialog(),
                    )
                  : () => _showGate(
                      'Profilo',
                      'Richiede una sessione Supabase attiva.',
                    ),
            ),
            _ActionRow(
              icon: Icons.photo_camera_outlined,
              title: 'Aggiorna avatar',
              detail: 'Scegli un immagine locale come nella versione mobile.',
              onTap: _pickAvatar,
            ),
            _ActionRow(
              icon: Icons.fact_check_outlined,
              title: 'Rivedi consenso iniziale',
              detail: 'Termini, privacy, notifiche e crash reporting',
              onTap: _reviewConsent,
            ),
            _ActionRow(
              icon: Icons.logout_rounded,
              title: 'Esci dall\'account',
              detail: auth.isLoggedIn
                  ? 'Chiudi la sessione su questo dispositivo'
                  : 'Disponibile con una sessione Supabase attiva',
              destructive: true,
              onTap: auth.isLoggedIn
                  ? () => _confirmSignOut()
                  : () => _showGate(
                      'Logout',
                      'Richiede una sessione Supabase attiva.',
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _appearance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SettingsHeading(
          title: 'Aspetto e applicazione',
          subtitle: 'Preferenze locali adattate al desktop',
        ),
        const SizedBox(height: 17),
        _SettingsGroup(
          title: 'Aspetto e visual',
          children: [
            _SwitchRow(
              label: 'Modalita scura',
              detail: 'Usa il tema scuro in bianco e nero del client mobile.',
              value: _darkMode,
              onChanged: (value) {
                ref
                    .read(desktopAppearanceControllerProvider.notifier)
                    .setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                _setBool(
                  'desktop_dark_mode',
                  value,
                  () => _darkMode = value,
                  profileColumn: 'theme_mode',
                  profileValue: value ? 'dark' : 'light',
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Calendario, esperienza e lingua',
          children: [
            _ColorRow(
              label: 'Colore accento',
              detail: 'Palette estesa riservata a Evolve Pro sul mobile.',
              selected: _accent,
              onChanged: (color) {
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
                  _syncProfile({'accent_color': dashboardColorToHex(accent)}),
                );
              },
            ),
            _SelectRow(
              label: 'Vista calendario predefinita',
              value: _calendarView,
              options: const ['Mese', 'Settimana', 'Anno', 'Vita'],
              onChanged: (value) => _setString(
                'pref_default_calendar_view',
                value,
                () => _calendarView = value,
                profileColumn: 'pref_default_calendar_view',
                profileValue: _calendarProfileValue(value),
              ),
            ),
            _SelectRow(
              label: 'Lingua',
              value: _language,
              options: const [
                'Sistema',
                'Italiano',
                'English',
                'Espanol',
                'Deutsch',
                'Arabic',
              ],
              onChanged: (value) => _setString(
                'pref_language',
                value,
                () {
                  _language = value;
                  ref
                      .read(desktopLocaleControllerProvider.notifier)
                      .setLanguage(_languageProfileValue(value));
                },
                profileColumn: 'language',
                profileValue: _languageProfileValue(value),
              ),
            ),
            _SwitchRow(
              label: 'Formato 24h',
              detail: 'Usa orari come 20:30 invece di 8:30 PM.',
              value: _timeFormat24h,
              onChanged: (value) => _setBool(
                'pref_time_format_24h',
                value,
                () => _timeFormat24h = value,
                profileColumn: 'pref_time_format_24h',
              ),
            ),
            _SwitchRow(
              label: 'Feedback aptico',
              detail:
                  'Preferenza condivisa con mobile; il desktop non genera vibrazioni.',
              value:
                  ref
                      .read(sharedPreferencesProvider)
                      ?.getBool('pref_haptic_feedback') ??
                  true,
              onChanged: (value) => _setBool(
                'pref_haptic_feedback',
                value,
                () {},
                profileColumn: 'pref_haptic_feedback',
              ),
            ),
            _ActionRow(
              icon: Icons.restart_alt_rounded,
              title: 'Ripristina tutorial',
              detail: 'Riapre i walkthrough di dashboard e obiettivi.',
              onTap: _resetTutorials,
            ),
          ],
        ),
      ],
    );
  }

  Widget _notifications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SettingsHeading(
          title: 'Notifiche',
          subtitle: 'Promemoria operativi sincronizzati con il client mobile',
        ),
        const SizedBox(height: 17),
        _SettingsGroup(
          title: 'Promemoria operativi',
          children: [
            _SwitchRow(
              label: 'Promemoria abitudini',
              detail: 'Invia il morning briefing giornaliero.',
              value: _habitReminders,
              onChanged: (value) => _setNotificationBool(
                key: 'notif_habit_reminders',
                value: value,
                update: () => _habitReminders = value,
                profileColumn: 'notif_habit_reminders',
                requestPermissions: value,
              ),
            ),
            if (_habitReminders)
              _TimeRow(
                label: 'Orario morning brief',
                value: _morningTime,
                use24hFormat: _timeFormat24h,
                onChanged: (value) => _setNotificationString(
                  'notif_morning_brief_time',
                  value,
                  () => _morningTime = value,
                  profileColumn: 'morning_brief_time',
                ),
              ),
            _SwitchRow(
              label: 'Review serale',
              detail: 'Ricorda di consolidare la giornata.',
              value: _eveningReview,
              onChanged: (value) => _setNotificationBool(
                key: 'notif_evening_review',
                value: value,
                update: () => _eveningReview = value,
                profileColumn: 'notif_evening_review',
                requestPermissions: value,
              ),
            ),
            if (_eveningReview)
              _TimeRow(
                label: 'Orario review serale',
                value: _eveningTime,
                use24hFormat: _timeFormat24h,
                onChanged: (value) => _setNotificationString(
                  'notif_evening_review_time',
                  value,
                  () => _eveningTime = value,
                  profileColumn: 'evening_review_time',
                ),
              ),
            _ActionRow(
              icon: Icons.notifications_active_outlined,
              title: 'Richiedi permessi notifiche',
              detail: 'Apre il prompt nativo sul target supportato.',
              onTap: _requestNotificationPermissions,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _PlatformNote(
          title: 'Delivery nativo per sistema operativo',
          detail: DesktopNotificationService.instance.platformSummary,
        ),
      ],
    );
  }

  Widget _privacy() {
    final biometric = ref.watch(desktopBiometricControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SettingsHeading(
          title: 'Privacy e sicurezza',
          subtitle: 'Protezione accesso, consensi e gestione dati',
        ),
        const SizedBox(height: 17),
        _SettingsGroup(
          title: 'Protezione accesso',
          children: [
            _SwitchRow(
              label: 'Blocco biometrico',
              detail:
                  'Disponibile con adapter nativo su macOS e Windows; non supportato su Linux.',
              value: biometric.enabled,
              onChanged: _setBiometricLock,
            ),
            _ActionRow(
              icon: Icons.key_outlined,
              title: 'Cambia password',
              detail: 'Aggiornamento credenziali tramite Supabase Auth.',
              onTap: ref.watch(desktopAuthControllerProvider).isLoggedIn
                  ? () => showDialog<void>(
                      context: context,
                      builder: (context) => const _ChangePasswordDialog(),
                    )
                  : () => _showGate(
                      'Cambio password',
                      'Richiede una sessione Supabase attiva.',
                    ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Dati e consensi',
          children: [
            _SwitchRow(
              label: 'Invia segnalazioni crash',
              detail: 'Consenso separato per Sentry.',
              value: _crashReports,
              onChanged: _setCrashReportingConsent,
            ),
            _ActionRow(
              icon: Icons.download_outlined,
              title: 'Esporta dati',
              detail: 'Condivide un export JSON completo dei dati disponibili.',
              onTap: _exportData,
            ),
            _ActionRow(
              icon: Icons.settings_outlined,
              title: 'Gestione permessi di sistema',
              detail: 'Notifiche, calendario e sicurezza.',
              onTap: _openSystemPermissions,
            ),
            _ActionRow(
              icon: Icons.delete_forever_outlined,
              title: 'Elimina account e dati',
              detail: 'Operazione irreversibile protetta da conferma.',
              destructive: true,
              onTap: _showDeleteOrResetDialog,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportData() async {
    final snapshot = ref.read(dashboardControllerProvider);
    final json = const JsonEncoder.withIndent('  ').convert({
      'exportDate': DateTime.now().toIso8601String(),
      'source': ref.read(backendConfiguredProvider)
          ? 'evolve-desktop-supabase-cache'
          : 'evolve-desktop-local-preview',
      'settings': {
        'themeMode': _darkMode ? 'dark' : 'light',
        'accentColor': dashboardColorToHex(_accent),
        'defaultCalendarView': _calendarProfileValue(_calendarView),
        'language': _languageProfileValue(_language),
        'timeFormat24h': _timeFormat24h,
        'habitReminders': _habitReminders,
        'goalDeadlines': _goalDeadlines,
        'aiInsights': _aiInsights,
        'weeklyReports': _weeklyReport,
        'eveningReview': _eveningReview,
        'biometricLock': ref.read(desktopBiometricControllerProvider).enabled,
        'morningBriefTime': _morningTime,
        'eveningReviewTime': _eveningTime,
      },
      'habits': [
        for (final habit in snapshot.habits)
          {
            'id': habit.id,
            'title': habit.title,
            'category': habit.category,
            'weekly_progress': habit.weeklyProgress,
            'reminder_time': habit.reminderTime,
          },
      ],
      'goals': [
        for (final goal in snapshot.goals)
          {
            'id': goal.id,
            'title': goal.title,
            'state': goal.state.name,
            'type': goal.type.name,
          },
      ],
      'habitLogs': snapshot.habitLogs,
      'moods': {
        for (final entry in snapshot.moods.entries)
          entry.key: entry.value.toJson(),
      },
    });
    if (Platform.isLinux) {
      await Clipboard.setData(ClipboardData(text: json));
    } else {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(utf8.encode(json), mimeType: 'application/json'),
          ],
          fileNameOverrides: const ['mattioli_os_export.json'],
          text: 'I miei dati esportati da Evolve',
        ),
      );
    }
    if (!mounted) return;
    _showGate(
      'Export completato',
      Platform.isLinux
          ? 'Il JSON e negli appunti: Linux non supporta la condivisione file.'
          : 'Il JSON e stato inviato al selettore di condivisione.',
    );
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
      setState(() => _profileImage = File(image.path));
    } catch (error, stack) {
      AppLogger.error('Unable to pick desktop avatar', error, stack);
      if (mounted) {
        _showGate('Avatar', 'Selezione immagine non riuscita.');
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await _confirm(
      title: 'Conferma uscita',
      message:
          'Sei sicuro di voler uscire? Dovrai reinserire le credenziali per accedere nuovamente.',
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
      _showGate('Blocco biometrico', message ?? 'Attivazione annullata.');
    }
  }

  Future<void> _requestNotificationPermissions() async {
    final granted = await DesktopNotificationService.instance
        .requestPermissions();
    if (!mounted) return;
    _showGate(
      'Permessi notifiche',
      granted
          ? 'Permessi disponibili per questo sistema.'
          : 'Permesso non concesso. Puoi modificarlo dalle impostazioni di sistema.',
    );
  }

  void _setNotificationBool({
    required String key,
    required bool value,
    required VoidCallback update,
    required String profileColumn,
    bool requestPermissions = false,
  }) {
    _setBool(key, value, update, profileColumn: profileColumn);
    if (requestPermissions) {
      unawaited(DesktopNotificationService.instance.requestPermissions());
    }
    unawaited(_syncNotifications());
  }

  void _setNotificationString(
    String key,
    String value,
    VoidCallback update, {
    required String profileColumn,
  }) {
    _setString(key, value, update, profileColumn: profileColumn);
    unawaited(_syncNotifications());
  }

  Future<void> _syncNotifications() async {
    await DesktopNotificationService.instance.sync(
      habitReminders: _habitReminders,
      eveningReview: _eveningReview,
      morningBriefTime: _morningTime,
      eveningReviewTime: _eveningTime,
      habits: ref.read(dashboardControllerProvider).habits,
    );
  }

  Future<void> _openSystemPermissions() async {
    try {
      await DesktopSystemSettingsService.openPermissions();
    } catch (error, stack) {
      AppLogger.error('Unable to open system permissions', error, stack);
      if (mounted) {
        _showGate('Permessi di sistema', 'Impossibile aprire le impostazioni.');
      }
    }
  }

  Future<void> _resetTutorials() async {
    final preferences = ref.read(sharedPreferencesProvider);
    if (preferences != null) {
      await Future.wait([
        preferences.setBool('has_seen_tutorial', false),
        preferences.setBool('has_seen_goals_tutorial', false),
        preferences.setBool('has_seen_stats_tutorial', false),
      ]);
    }
    if (mounted) {
      _showGate(
        'Tutorial ripristinati',
        'Le guide verranno mostrate nuovamente nelle relative sezioni.',
      );
    }
  }

  Future<void> _showDeleteOrResetDialog() async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gestione account e dati'),
        content: const Text(
          'Scegli se eliminare i dati mantenendo attivo l account oppure cancellare definitivamente l account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'reset'),
            child: const Text('Resetta i dati'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const Text('Elimina account'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'reset') {
      final confirmed = await _confirm(
        title: 'Conferma reset dati',
        message:
            'Verranno eliminate abitudini, obiettivi e preferenze. L account restera attivo. Questa azione non puo essere annullata.',
        destructive: true,
      );
      if (confirmed) await _resetData();
      return;
    }

    final confirmed = await _confirm(
      title: 'Conferma eliminazione account',
      message:
          'L account e tutti i dati associati verranno eliminati definitivamente. Questa azione e irreversibile.',
      destructive: true,
    );
    if (confirmed) await _deleteAccount();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: destructive
                    ? FilledButton.styleFrom(backgroundColor: EvolveColors.rose)
                    : null,
                child: const Text('Conferma'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _resetData() async {
    try {
      await ref.read(dashboardControllerProvider.notifier).resetData();
      await _resetSettingsToDefaults();
      if (mounted) _showGate('Reset dati', 'Dati eliminati con successo.');
    } catch (error, stack) {
      AppLogger.error('Unable to reset desktop data', error, stack);
      if (mounted) _showGate('Reset dati', 'Operazione non riuscita.');
    }
  }

  Future<void> _deleteAccount() async {
    if (!ref.read(desktopAuthControllerProvider).isLoggedIn) {
      _showGate('Elimina account', 'Richiede una sessione Supabase attiva.');
      return;
    }
    try {
      await ref.read(desktopAuthControllerProvider.notifier).deleteAccount();
      if (mounted) _showGate('Elimina account', 'Account eliminato.');
    } catch (error, stack) {
      AppLogger.error('Unable to delete desktop account', error, stack);
      if (mounted) _showGate('Elimina account', 'Operazione non riuscita.');
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
    setState(() {
      _darkMode = true;
      _accent = DesktopAppearanceController.defaultAccent;
      _calendarView = 'Settimana';
      _language = 'Sistema';
      _timeFormat24h = true;
      _habitReminders = true;
      _goalDeadlines = true;
      _aiInsights = false;
      _weeklyReport = false;
      _eveningReview = true;
      _morningTime = '09:00';
      _eveningTime = '21:00';
    });
    await ref
        .read(desktopBiometricControllerProvider.notifier)
        .setEnabled(false);
    await _syncProfile({
      'theme_mode': 'dark',
      'accent_color': '#FAFAFA',
      'pref_default_calendar_view': 'settimana',
      'pref_haptic_feedback': true,
      'language': 'system',
      'pref_time_format_24h': true,
      'notif_habit_reminders': true,
      'notif_goal_deadlines': true,
      'notif_ai_insights': false,
      'notif_weekly_reports': false,
      'notif_evening_review': true,
      'biometric_lock': false,
      'morning_brief_time': '09:00',
      'evening_review_time': '21:00',
    });
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

  void _setBool(
    String key,
    bool value,
    VoidCallback update, {
    String? profileColumn,
    Object? profileValue,
  }) {
    setState(update);
    final preferences = ref.read(sharedPreferencesProvider);
    if (preferences != null) unawaited(preferences.setBool(key, value));
    if (profileColumn != null) {
      unawaited(_syncProfile({profileColumn: profileValue ?? value}));
    }
  }

  void _setString(
    String key,
    String value,
    VoidCallback update, {
    String? profileColumn,
    Object? profileValue,
  }) {
    setState(update);
    final preferences = ref.read(sharedPreferencesProvider);
    if (preferences != null) unawaited(preferences.setString(key, value));
    if (profileColumn != null) {
      unawaited(_syncProfile({profileColumn: profileValue ?? value}));
    }
  }

  Future<void> _loadProfilePreferences() async {
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
        _darkMode = appearance.themeMode != ThemeMode.light;
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
        _calendarView = _calendarLabel(
          profile['pref_default_calendar_view'] as String?,
        );
        _language = _languageLabel(profile['language'] as String?);
        _morningTime = profile['morning_brief_time'] as String? ?? _morningTime;
        _eveningTime =
            profile['evening_review_time'] as String? ?? _eveningTime;
        _accent = appearance.accentColor;
      });
      final preferences = ref.read(sharedPreferencesProvider);
      if (preferences != null) {
        await Future.wait([
          preferences.setBool('desktop_dark_mode', _darkMode),
          preferences.setBool('pref_time_format_24h', _timeFormat24h),
          preferences.setBool('notif_habit_reminders', _habitReminders),
          preferences.setBool('notif_evening_review', _eveningReview),
          preferences.setBool('notif_goal_deadlines', _goalDeadlines),
          preferences.setBool('notif_ai_insights', _aiInsights),
          preferences.setBool('notif_weekly_reports', _weeklyReport),
          preferences.setString('pref_default_calendar_view', _calendarView),
          preferences.setString(
            'pref_language',
            _languageProfileValue(_language),
          ),
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

  Future<void> _syncProfile(Map<String, dynamic> values) async {
    final client = ref.read(supabaseClientProvider);
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    try {
      await client.from('profiles').upsert({'id': user.id, ...values});
    } catch (error, stack) {
      AppLogger.error('Unable to sync desktop preferences', error, stack);
    }
  }

  String _calendarProfileValue(String label) => switch (label) {
    'Mese' => 'mese',
    'Anno' => 'anno',
    'Vita' => 'vita',
    _ => 'settimana',
  };

  String _calendarLabel(String? value) => switch (value?.toLowerCase()) {
    'mese' || 'month' => 'Mese',
    'anno' || 'year' => 'Anno',
    'vita' || 'life' => 'Vita',
    _ => 'Settimana',
  };

  String _languageProfileValue(String label) => switch (label) {
    'Italiano' => 'it',
    'English' => 'en',
    'Espanol' => 'es',
    'Deutsch' => 'de',
    'Arabic' => 'ar',
    _ => 'system',
  };

  String _languageLabel(String? value) => switch (value?.toLowerCase()) {
    'it' => 'Italiano',
    'en' => 'English',
    'es' => 'Espanol',
    'de' => 'Deutsch',
    'ar' => 'Arabic',
    _ => 'Sistema',
  };

  void _showGate(String title, String detail) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title: $detail')));
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected
            ? context.evolveAccent.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Row(
              children: [
                Icon(
                  section.icon,
                  color: selected
                      ? context.evolveAccent
                      : context.evolveColors.muted,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? context.evolveAccent
                          : context.evolveColors.muted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.evolveColors.panelRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.evolveColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 9),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _RowCopy(label: label, detail: detail),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<String>(
            value: value,
            items: [
              for (final option in options)
                DropdownMenuItem(value: option, child: Text(option)),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.use24hFormat,
    required this.onChanged,
  });

  final String label;
  final String value;
  final bool use24hFormat;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          OutlinedButton(
            onPressed: () async {
              final parts = value.split(':');
              final selected = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: int.tryParse(parts.first) ?? 9,
                  minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(alwaysUse24HourFormat: use24hFormat),
                  child: child!,
                ),
              );
              if (selected == null) return;
              onChanged(
                '${selected.hour.toString().padLeft(2, '0')}:'
                '${selected.minute.toString().padLeft(2, '0')}',
              );
            },
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final String detail;
  final Color selected;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFFAFAFA),
      const Color(0xFFEAB308),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF97316),
    ].map((color) => _visibleAccent(context, color));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: [
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
                  Tooltip(
                    message: 'Usa accento ${_toHex(color)}',
                    child: InkWell(
                      onTap: () => onChanged(color),
                      customBorder: const CircleBorder(),
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: color,
                        child: selected == color
                            ? Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: _checkColor(color),
                              )
                            : null,
                      ),
                    ),
                  ),
                Tooltip(
                  message: 'Colore personalizzato',
                  child: InkWell(
                    onTap: () => _showFullColorPicker(context),
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: context.evolveColors.panelRaised,
                      child: Icon(
                        Icons.add_rounded,
                        size: 15,
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

  Future<void> _showFullColorPicker(BuildContext context) async {
    var color = selected;
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Colore accento'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: color,
            onColorChanged: (value) => color = value,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, color),
            child: const Text('Applica'),
          ),
        ],
      ),
    );
    if (picked != null) onChanged(picked);
  }

  Color _visibleAccent(BuildContext context, Color color) {
    if (Theme.of(context).brightness == Brightness.light &&
        color.toARGB32() == 0xFFFAFAFA) {
      return const Color(0xFF09090B);
    }
    return color;
  }

  Color _checkColor(Color color) =>
      color.computeLuminance() > 0.45 ? const Color(0xFF09090B) : Colors.white;

  String _toHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? EvolveColors.rose
        : context.evolveColors.foreground;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: _RowCopy(label: title, detail: detail, color: color),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.evolveColors.subtle,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              color: color ?? context.evolveColors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowCopy extends StatelessWidget {
  const _RowCopy({required this.label, required this.detail, this.color});

  final String label;
  final String detail;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color ?? context.evolveColors.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
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
  });

  final User? user;
  final File? image;
  final bool isPro;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    final metadata = user?.userMetadata;
    final fullName = (metadata?['full_name'] as String?)?.trim();
    final avatarUrl = metadata?['avatar_url'] as String?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.evolveColors.panelRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.evolveColors.border),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onPickAvatar,
            customBorder: const CircleBorder(),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: context.evolveAccent.withValues(alpha: 0.13),
              backgroundImage: image != null
                  ? FileImage(image!)
                  : avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: image == null && avatarUrl == null
                  ? Icon(
                      Icons.person_outline_rounded,
                      color: context.evolveAccent,
                    )
                  : null,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName?.isNotEmpty ?? false
                      ? fullName!
                      : user?.email?.split('@').first ?? 'Profilo locale',
                  style: TextStyle(
                    color: context.evolveColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  user?.email ?? 'Sessione locale di anteprima',
                  style: TextStyle(
                    color: context.evolveColors.subtle,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isPro)
            const StatusPill(
              label: 'PRO',
              color: EvolveColors.amber,
              icon: Icons.workspace_premium_outlined,
            )
          else
            StatusPill(
              label: user == null ? 'Preview' : 'Verificato',
              color: user == null ? EvolveColors.amber : context.evolveAccent,
              icon: user == null
                  ? Icons.science_outlined
                  : Icons.verified_outlined,
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
      color: const Color(0xFF151522),
      child: Row(
        children: [
          const Icon(Icons.devices_outlined, color: EvolveColors.violet),
          const SizedBox(width: 13),
          Expanded(
            child: _RowCopy(label: title, detail: detail),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionSettings extends ConsumerStatefulWidget {
  const _SubscriptionSettings();

  @override
  ConsumerState<_SubscriptionSettings> createState() =>
      _SubscriptionSettingsState();
}

class _SubscriptionSettingsState extends ConsumerState<_SubscriptionSettings> {
  String _plan = 'yearly';

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(desktopSubscriptionControllerProvider);
    final monthly = subscription.monthlyPackage;
    final yearly = subscription.yearlyPackage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SettingsHeading(
          title: 'Evolve Pro',
          subtitle: 'Piano, ripristino acquisti e gestione abbonamento',
        ),
        const SizedBox(height: 17),
        _PlatformNote(
          title: subscription.isSupportedPlatform
              ? 'RevenueCat macOS'
              : 'Canale commerciale richiesto',
          detail: subscription.isSupportedPlatform
              ? subscription.isConfigured
                    ? 'Offerte e stato entitlement vengono letti dal progetto RevenueCat mobile.'
                    : 'Avvia il desktop con il launcher mobile per iniettare la public key RevenueCat.'
              : 'RevenueCat Flutter non espone acquisti in-app su Windows e Linux.',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _PlanCard(
                title: 'Mensile',
                price: monthly?.storeProduct.priceString ?? 'Mensile',
                selected: _plan == 'monthly',
                onTap: () => setState(() => _plan = 'monthly'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _PlanCard(
                title: 'Annuale',
                price: yearly?.storeProduct.priceString ?? 'Annuale',
                detail: 'Miglior valore',
                selected: _plan == 'yearly',
                onTap: () => setState(() => _plan = 'yearly'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Gestione piano',
          children: [
            _ActionRow(
              icon: Icons.workspace_premium_outlined,
              title: 'Attiva Evolve Pro',
              detail: subscription.isPro
                  ? 'Entitlement Evolve Pro attivo.'
                  : 'Avvia il checkout StoreKit nativo su macOS.',
              onTap: subscription.isLoading
                  ? () {}
                  : () {
                      final package = _plan == 'monthly' ? monthly : yearly;
                      if (package == null) {
                        unawaited(
                          ref
                              .read(
                                desktopSubscriptionControllerProvider.notifier,
                              )
                              .refresh(),
                        );
                        return;
                      }
                      unawaited(
                        ref
                            .read(
                              desktopSubscriptionControllerProvider.notifier,
                            )
                            .purchase(package),
                      );
                    },
            ),
            _ActionRow(
              icon: Icons.restore_rounded,
              title: 'Ripristina acquisti',
              detail: 'Recupera lo stato entitlement dal provider.',
              onTap: () => unawaited(
                ref
                    .read(desktopSubscriptionControllerProvider.notifier)
                    .restore(),
              ),
            ),
            _ActionRow(
              icon: Icons.manage_accounts_outlined,
              title: 'Gestisci abbonamento',
              detail: 'Apre la gestione abbonamenti dell account Apple.',
              onTap: () => unawaited(
                ref
                    .read(desktopSubscriptionControllerProvider.notifier)
                    .manageSubscription(),
              ),
            ),
          ],
        ),
        if (subscription.message != null) ...[
          const SizedBox(height: 12),
          Text(subscription.message!),
        ],
      ],
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
  final String price;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected
              ? context.evolveAccent.withValues(alpha: 0.08)
              : context.evolveColors.panelRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? context.evolveAccent
                : context.evolveColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              price,
              style: TextStyle(
                color: context.evolveAccent,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 5),
              Text(detail!, style: Theme.of(context).textTheme.bodySmall),
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
  late final TextEditingController _birthDateController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(desktopAuthControllerProvider).user;
    _nameController = TextEditingController(
      text: user?.userMetadata?['full_name'] as String?,
    );
    _birthDateController = TextEditingController(
      text: user?.userMetadata?['date_of_birth'] as String?,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(desktopAuthControllerProvider).user?.email;
    return AlertDialog(
      title: const Text('Informazioni personali'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome completo'),
            ),
            const SizedBox(height: 10),
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: email ?? 'Preview locale',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _birthDateController,
              decoration: const InputDecoration(
                labelText: 'Data di nascita',
                hintText: 'AAAA-MM-GG',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salva'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final birthDate = _birthDateController.text.trim();
    if (birthDate.isNotEmpty && DateTime.tryParse(birthDate) == null) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref
          .read(desktopAuthControllerProvider.notifier)
          .updatePersonalInfo(fullName: name, dateOfBirth: birthDate);
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
    return AlertDialog(
      title: const Text('Cambia password'),
      content: SizedBox(
        width: 470,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password attuale'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nuova password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Conferma nuova password',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: EvolveColors.rose)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Aggiorna password'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_currentController.text.isEmpty) {
      setState(() => _error = 'Inserisci la password attuale.');
      return;
    }
    if (_newController.text.length < 8) {
      setState(
        () => _error = 'La nuova password deve avere almeno 8 caratteri.',
      );
      return;
    }
    if (_newController.text != _confirmController.text) {
      setState(() => _error = 'Le password non coincidono.');
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
          _error = 'Aggiornamento non riuscito. Verifica la password attuale.';
        });
      }
    }
  }
}

extension on _SettingsSection {
  String get label => switch (this) {
    _SettingsSection.profile => 'Profilo',
    _SettingsSection.appearance => 'Applicazione',
    _SettingsSection.notifications => 'Notifiche',
    _SettingsSection.privacy => 'Privacy',
    _SettingsSection.subscription => 'Abbonamento',
  };

  IconData get icon => switch (this) {
    _SettingsSection.profile => Icons.person_outline_rounded,
    _SettingsSection.appearance => Icons.tune_rounded,
    _SettingsSection.notifications => Icons.notifications_outlined,
    _SettingsSection.privacy => Icons.shield_outlined,
    _SettingsSection.subscription => Icons.workspace_premium_outlined,
  };
}
