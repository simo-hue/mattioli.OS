import 'dart:async';
import 'dart:convert';

import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/application/consent_controller.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  bool _launchAtLogin = false;
  bool _darkMode = true;
  bool _reduceAnimations = false;
  bool _timeFormat24h = true;
  bool _habitReminders = true;
  bool _eveningReview = true;
  bool _goalDeadlines = true;
  bool _aiInsights = true;
  bool _weeklyReport = true;
  bool _biometricLock = false;
  bool _crashReports = false;
  String _calendarView = 'Settimana';
  String _language = 'Sistema';
  String _morningTime = '08:00';
  String _eveningTime = '20:30';
  Color _accent = EvolveColors.primaryStrong;

  @override
  void initState() {
    super.initState();
    final preferences = ref.read(sharedPreferencesProvider);
    final appearance = ref.read(desktopAppearanceControllerProvider);
    _darkMode = appearance.themeMode != ThemeMode.light;
    _accent = appearance.accentColor;
    if (preferences == null) return;
    _launchAtLogin = preferences.getBool('desktop_launch_at_login') ?? false;
    _reduceAnimations =
        preferences.getBool('desktop_reduce_animations') ?? false;
    _timeFormat24h = preferences.getBool('pref_time_format_24h') ?? true;
    _habitReminders = preferences.getBool('notif_habit_reminders') ?? true;
    _eveningReview = preferences.getBool('notif_evening_review') ?? true;
    _goalDeadlines = preferences.getBool('notif_goal_deadlines') ?? true;
    _aiInsights = preferences.getBool('notif_ai_insights') ?? true;
    _weeklyReport = preferences.getBool('notif_weekly_reports') ?? true;
    _biometricLock = preferences.getBool('biometric_lock') ?? false;
    _crashReports = preferences.getBool('has_sentry_consent') ?? false;
    _calendarView =
        preferences.getString('pref_default_calendar_view') ?? 'Settimana';
    _language = preferences.getString('language') ?? 'Sistema';
    _morningTime = preferences.getString('morning_brief_time') ?? '08:00';
    _eveningTime = preferences.getString('evening_review_time') ?? '20:30';
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
        const _ProfileCard(),
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
                  ? EvolveColors.primaryStrong
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
              detail: 'Richiede file picker e storage profile adapter',
              onTap: () => _showGate(
                'Avatar profile-gated',
                'La superficie e pronta; upload e persistenza richiedono lo storage adapter.',
              ),
            ),
            _ActionRow(
              icon: Icons.login_rounded,
              title: 'Autenticazione',
              detail: backendConfigured
                  ? 'Sessione Supabase attiva'
                  : 'Configura Supabase per attivare l’accesso reale',
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => const _AuthSessionDialog(),
              ),
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
                  ? () => unawaited(_signOut())
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
          title: 'Applicazione desktop',
          children: [
            _SwitchRow(
              label: 'Apri Evolve all\'accesso',
              detail: 'Avvio automatico della sessione desktop.',
              value: _launchAtLogin,
              onChanged: (value) => _setBool(
                'desktop_launch_at_login',
                value,
                () => _launchAtLogin = value,
              ),
            ),
            _SwitchRow(
              label: 'Modalita scura',
              detail: 'Il tema chiaro verra applicato dal theme controller.',
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
            _SwitchRow(
              label: 'Riduci animazioni',
              detail: 'Limita le transizioni per una maggiore accessibilita.',
              value: _reduceAnimations,
              onChanged: (value) => _setBool(
                'desktop_reduce_animations',
                value,
                () => _reduceAnimations = value,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: 'Dashboard e localizzazione',
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
                'language',
                value,
                () => _language = value,
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
            const _ReadOnlyRow(
              label: 'Feedback aptico',
              detail:
                  'Adattamento desktop: non applicabile a mouse e tastiera.',
              status: 'Mobile only',
            ),
            _ActionRow(
              icon: Icons.restart_alt_rounded,
              title: 'Ripristina tutorial',
              detail: 'Riapre i walkthrough di dashboard e obiettivi.',
              onTap: () => _showGate(
                'Tutorial ripristinati',
                'La preview locale registrera il walkthrough al prossimo avvio.',
              ),
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
          subtitle:
              'Preferenze replicate; il delivery nativo verra collegato per piattaforma',
        ),
        const SizedBox(height: 17),
        _SettingsGroup(
          title: 'Promemoria operativi',
          children: [
            _SwitchRow(
              label: 'Promemoria abitudini',
              detail: 'Invia il morning briefing giornaliero.',
              value: _habitReminders,
              onChanged: (value) => _setBool(
                'notif_habit_reminders',
                value,
                () => _habitReminders = value,
                profileColumn: 'notif_habit_reminders',
              ),
            ),
            if (_habitReminders)
              _SelectRow(
                label: 'Orario morning brief',
                value: _morningTime,
                options: const ['07:30', '08:00', '08:30', '09:00'],
                onChanged: (value) => _setString(
                  'morning_brief_time',
                  value,
                  () => _morningTime = value,
                  profileColumn: 'morning_brief_time',
                ),
              ),
            _SwitchRow(
              label: 'Review serale',
              detail: 'Ricorda di consolidare la giornata.',
              value: _eveningReview,
              onChanged: (value) => _setBool(
                'notif_evening_review',
                value,
                () => _eveningReview = value,
                profileColumn: 'notif_evening_review',
              ),
            ),
            if (_eveningReview)
              _SelectRow(
                label: 'Orario review serale',
                value: _eveningTime,
                options: const ['19:30', '20:00', '20:30', '21:00'],
                onChanged: (value) => _setString(
                  'evening_review_time',
                  value,
                  () => _eveningTime = value,
                  profileColumn: 'evening_review_time',
                ),
              ),
            _SwitchRow(
              label: 'Scadenze obiettivi',
              detail: 'Avvisa prima dei macro-obiettivi in scadenza.',
              value: _goalDeadlines,
              onChanged: (value) => _setBool(
                'notif_goal_deadlines',
                value,
                () => _goalDeadlines = value,
                profileColumn: 'notif_goal_deadlines',
              ),
            ),
            _SwitchRow(
              label: 'Insight AI',
              detail: 'Mostra suggerimenti quando emerge un pattern utile.',
              value: _aiInsights,
              onChanged: (value) => _setBool(
                'notif_ai_insights',
                value,
                () => _aiInsights = value,
                profileColumn: 'notif_ai_insights',
              ),
            ),
            _SwitchRow(
              label: 'Report settimanale',
              detail: 'Prepara una sintesi ogni domenica.',
              value: _weeklyReport,
              onChanged: (value) => _setBool(
                'notif_weekly_reports',
                value,
                () => _weeklyReport = value,
                profileColumn: 'notif_weekly_reports',
              ),
            ),
            _ActionRow(
              icon: Icons.notifications_active_outlined,
              title: 'Richiedi permessi notifiche',
              detail: 'Apre il prompt nativo sul target supportato.',
              onTap: () => _showGate(
                'Permessi notifiche',
                'Il prompt verra collegato al notification adapter per ciascun target desktop.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _PlatformNote(
          title: 'Delivery nativo per sistema operativo',
          detail:
              'macOS, Windows e Linux richiedono inizializzazione e permessi differenti. Le preferenze sono pronte; il servizio di scheduling resta platform-gated.',
        ),
      ],
    );
  }

  Widget _privacy() {
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
              value: _biometricLock,
              onChanged: (value) {
                _setBool(
                  'biometric_lock',
                  value,
                  () => _biometricLock = value,
                  profileColumn: 'biometric_lock',
                );
                _showGate(
                  'Biometria platform-gated',
                  'La preferenza e registrata localmente. L\'autenticazione nativa verra attivata per macOS e Windows.',
                );
              },
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
              onChanged: (value) => _setBool(
                'has_sentry_consent',
                value,
                () => _crashReports = value,
                profileColumn: 'sentry_consent',
              ),
            ),
            _ActionRow(
              icon: Icons.download_outlined,
              title: 'Esporta dati',
              detail:
                  'Copia un export JSON dei dati disponibili negli appunti.',
              onTap: _exportPreview,
            ),
            _ActionRow(
              icon: Icons.settings_outlined,
              title: 'Gestione permessi di sistema',
              detail: 'Notifiche, avvio automatico e sicurezza.',
              onTap: () => _showGate(
                'Permessi di sistema',
                'L\'apertura delle impostazioni native verra implementata per target.',
              ),
            ),
            _ActionRow(
              icon: Icons.delete_forever_outlined,
              title: 'Elimina account e dati',
              detail: 'Operazione irreversibile protetta da conferma.',
              destructive: true,
              onTap: () => _showGate(
                'Eliminazione account',
                'Disabilitata nella preview: richiede RPC verificata, sessione valida e conferma esplicita.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportPreview() async {
    final snapshot = ref.read(dashboardControllerProvider);
    final json = const JsonEncoder.withIndent('  ').convert({
      'source': ref.read(backendConfiguredProvider)
          ? 'evolve-desktop-supabase-cache'
          : 'evolve-desktop-local-preview',
      'habits': [
        for (final habit in snapshot.habits)
          {
            'id': habit.id,
            'title': habit.title,
            'category': habit.category,
            'weekly_progress': habit.weeklyProgress,
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
    });
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    _showGate(
      'Export copiato',
      'Il JSON dei dati disponibili e negli appunti.',
    );
  }

  Future<void> _signOut() async {
    try {
      await ref.read(desktopAuthControllerProvider.notifier).signOut();
    } catch (_) {}
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
      setState(() {
        _darkMode = (profile['theme_mode'] as String? ?? 'dark') != 'light';
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
        _biometricLock = profile['biometric_lock'] as bool? ?? _biometricLock;
        _calendarView = _calendarLabel(
          profile['pref_default_calendar_view'] as String?,
        );
        _language = _languageLabel(profile['language'] as String?);
        _morningTime = profile['morning_brief_time'] as String? ?? _morningTime;
        _eveningTime =
            profile['evening_review_time'] as String? ?? _eveningTime;
        _accent = dashboardColorFromHex(profile['accent_color'] as String?);
      });
      ref
          .read(desktopAppearanceControllerProvider.notifier)
          .applyProfile(
            themeMode: profile['theme_mode'] as String?,
            accentColor: profile['accent_color'] as String?,
          );
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
          preferences.setBool('biometric_lock', _biometricLock),
          preferences.setString('pref_default_calendar_view', _calendarView),
          preferences.setString('language', _language),
          preferences.setString('morning_brief_time', _morningTime),
          preferences.setString('evening_review_time', _eveningTime),
          preferences.setInt('accent_color', _accent.toARGB32()),
        ]);
      }
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
            ? EvolveColors.primary.withValues(alpha: 0.1)
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
                  color: selected ? EvolveColors.primary : EvolveColors.muted,
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
                          ? EvolveColors.primary
                          : EvolveColors.muted,
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
        color: EvolveColors.panelRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EvolveColors.border),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _RowCopy(label: label, detail: detail),
          ),
          for (final color in const [
            EvolveColors.primaryStrong,
            EvolveColors.cyan,
            EvolveColors.violet,
            EvolveColors.amber,
            EvolveColors.rose,
          ])
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: InkWell(
                onTap: () => onChanged(color),
                child: CircleAvatar(
                  radius: 11,
                  backgroundColor: color,
                  child: selected == color
                      ? const Icon(Icons.check_rounded, size: 14)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.detail,
    required this.status,
  });

  final String label;
  final String detail;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _RowCopy(label: label, detail: detail),
          ),
          StatusPill(label: status, color: EvolveColors.subtle),
        ],
      ),
    );
  }
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
    final color = destructive ? EvolveColors.rose : EvolveColors.foreground;
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
            const Icon(Icons.chevron_right_rounded, color: EvolveColors.subtle),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.color = EvolveColors.foreground,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RowCopy extends StatelessWidget {
  const _RowCopy({
    required this.label,
    required this.detail,
    this.color = EvolveColors.foreground,
  });

  final String label;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 3),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EvolveColors.panelRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EvolveColors.border),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0x2255C881),
            child: Icon(
              Icons.person_outline_rounded,
              color: EvolveColors.primary,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profilo locale',
                  style: TextStyle(
                    color: EvolveColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Nome, email, data di nascita e avatar arriveranno dal profilo Supabase.',
                  style: TextStyle(color: EvolveColors.subtle, fontSize: 12),
                ),
              ],
            ),
          ),
          StatusPill(
            label: 'Preview',
            color: EvolveColors.amber,
            icon: Icons.science_outlined,
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

class _SubscriptionSettings extends StatefulWidget {
  const _SubscriptionSettings();

  @override
  State<_SubscriptionSettings> createState() => _SubscriptionSettingsState();
}

class _SubscriptionSettingsState extends State<_SubscriptionSettings> {
  String _plan = 'yearly';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SettingsHeading(
          title: 'Evolve Pro',
          subtitle: 'Piano, ripristino acquisti e gestione abbonamento',
        ),
        const SizedBox(height: 17),
        const _PlatformNote(
          title: 'Acquisti platform-gated',
          detail:
              'RevenueCat e previsto per macOS. Windows e Linux richiedono un canale commerciale alternativo.',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _PlanCard(
                title: 'Mensile',
                price: '4,99 EUR',
                selected: _plan == 'monthly',
                onTap: () => setState(() => _plan = 'monthly'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _PlanCard(
                title: 'Annuale',
                price: '29,99 EUR',
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
              detail: 'Apre il checkout nativo sul target supportato.',
              onTap: () =>
                  _show(context, 'Checkout non attivo nella preview locale.'),
            ),
            _ActionRow(
              icon: Icons.restore_rounded,
              title: 'Ripristina acquisti',
              detail: 'Recupera lo stato entitlement dal provider.',
              onTap: () =>
                  _show(context, 'Restore non attivo nella preview locale.'),
            ),
            _ActionRow(
              icon: Icons.manage_accounts_outlined,
              title: 'Gestisci abbonamento',
              detail: 'Apre il customer center quando disponibile.',
              onTap: () => _show(
                context,
                'Customer center non attivo nella preview locale.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _show(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          color: selected ? const Color(0xFF14251E) : EvolveColors.panelRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? EvolveColors.primaryStrong : EvolveColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              price,
              style: const TextStyle(
                color: EvolveColors.primaryStrong,
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

class _AuthSessionDialog extends ConsumerWidget {
  const _AuthSessionDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(desktopAuthControllerProvider);
    return AlertDialog(
      title: const Text('Autenticazione desktop'),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoRow(
              label: 'Sessione',
              value: auth.isLoggedIn ? 'Attiva' : 'Preview locale',
              color: auth.isLoggedIn
                  ? EvolveColors.primaryStrong
                  : EvolveColors.amber,
            ),
            _InfoRow(
              label: 'Email',
              value: auth.user?.email ?? 'Non collegata',
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: null, child: Text('Apple')),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(onPressed: null, child: Text('Google')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Apple e Google richiedono la configurazione dei redirect desktop.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chiudi'),
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
