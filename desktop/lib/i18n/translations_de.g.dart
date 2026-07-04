///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'translations.g.dart';

// Path: <root>
class TranslationsDe extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsDe({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.de,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <de>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsDe _root = this; // ignore: unused_field

	@override 
	TranslationsDe $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsDe(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$auth$de auth = _Translations$auth$de._(_root);
	@override late final _Translations$privateAi$de privateAi = _Translations$privateAi$de._(_root);
	@override late final _Translations$privateData$de privateData = _Translations$privateData$de._(_root);
	@override late final _Translations$namePrompt$de namePrompt = _Translations$namePrompt$de._(_root);
	@override late final _Translations$nav$de nav = _Translations$nav$de._(_root);
	@override late final _Translations$shell$de shell = _Translations$shell$de._(_root);
	@override late final _Translations$common$de common = _Translations$common$de._(_root);
	@override late final _Translations$form$de form = _Translations$form$de._(_root);
	@override late final _Translations$createGoal$de createGoal = _Translations$createGoal$de._(_root);
	@override late final _Translations$createHabit$de createHabit = _Translations$createHabit$de._(_root);
	@override late final _Translations$macroGoals$de macroGoals = _Translations$macroGoals$de._(_root);
	@override late final _Translations$statistics$de statistics = _Translations$statistics$de._(_root);
	@override late final _Translations$goalState$de goalState = _Translations$goalState$de._(_root);
	@override late final _Translations$dueLabel$de dueLabel = _Translations$dueLabel$de._(_root);
	@override late final _Translations$dashboard$de dashboard = _Translations$dashboard$de._(_root);
	@override late final _Translations$stats$de stats = _Translations$stats$de._(_root);
	@override late final _Translations$habitsPage$de habitsPage = _Translations$habitsPage$de._(_root);
	@override String get lavoro => 'Arbeit';
	@override String get salute => 'Gesundheit';
	@override String get finanza => 'Finanzen';
	@override String get relazioni => 'Beziehungen';
	@override String get formazione => 'Bildung';
	@override String get hobby => 'Hobby';
	@override String get spirituale => 'Spiritualität';
	@override String get altro => 'Sonstiges';
	@override late final _Translations$goalsPage$de goalsPage = _Translations$goalsPage$de._(_root);
	@override late final _Translations$goalsStats$de goalsStats = _Translations$goalsStats$de._(_root);
	@override late final _Translations$ai$de ai = _Translations$ai$de._(_root);
	@override late final _Translations$aiCoach$de aiCoach = _Translations$aiCoach$de._(_root);
	@override late final _Translations$settingsPage$de settingsPage = _Translations$settingsPage$de._(_root);
	@override late final _Translations$consent$de consent = _Translations$consent$de._(_root);
	@override late final _Translations$notifications$de notifications = _Translations$notifications$de._(_root);
	@override late final _Translations$privacy$de privacy = _Translations$privacy$de._(_root);
	@override late final _Translations$consentPage$de consentPage = _Translations$consentPage$de._(_root);
	@override late final _Translations$notif$de notif = _Translations$notif$de._(_root);
	@override late final _Translations$biometricGate$de biometricGate = _Translations$biometricGate$de._(_root);
	@override late final _Translations$sync$de sync = _Translations$sync$de._(_root);
	@override late final _Translations$subscriptionCtrl$de subscriptionCtrl = _Translations$subscriptionCtrl$de._(_root);
	@override late final _Translations$authCtrl$de authCtrl = _Translations$authCtrl$de._(_root);
	@override late final _Translations$proModal$de proModal = _Translations$proModal$de._(_root);
	@override late final _Translations$tutorial$de tutorial = _Translations$tutorial$de._(_root);
}

// Path: auth
class _Translations$auth$de extends Translations$auth$en {
	_Translations$auth$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get continuePrivately => 'Privat auf diesem Mac fortfahren';
	@override String get signIn => 'Anmelden';
	@override String get register => 'Registrieren';
	@override String get or => 'ODER';
	@override String get password => 'Passwort';
	@override String get forgotPassword => 'Passwort vergessen?';
	@override String get haveAccount => 'Du hast bereits ein Konto?';
	@override String get noAccount => 'Du hast kein Konto?';
	@override String get continueWithApple => 'Mit Apple fortfahren';
	@override String get continueWithGoogle => 'Mit Google fortfahren';
	@override String get readPrivacyPolicy => 'Datenschutzerklärung lesen';
	@override String get nameLabel => 'Vorname';
	@override String get invalidEmail => 'Gib eine gültige E-Mail-Adresse ein';
	@override String get confirmEmail => 'Prüfe deine E-Mail, um die Registrierung zu bestätigen.';
	@override String get resetSent => 'E-Mail gesendet. Prüfe deinen Posteingang.';
	@override String get signInTitle => 'Bei Evolve anmelden';
	@override String get signUpTitle => 'Erstelle dein Konto';
	@override String get resetTitle => 'Passwort wiederherstellen';
	@override String get emailLabel => 'E-Mail';
	@override String get passwordMin8 => 'Verwende mindestens 8 Zeichen.';
	@override String get sendResetLink => 'Wiederherstellungslink senden';
}

// Path: privateAi
class _Translations$privateAi$de extends Translations$privateAi$en {
	_Translations$privateAi$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get consentTitle => 'Senden an die KI erlauben';
	@override String get consentBody => 'Im privaten Modus bleiben deine Daten auf deinem Gerät. Um den KI-Coach zu nutzen, werden die Gewohnheiten und Ziele, die du teilst, an einen externen KI-Anbieter (OpenRouter) gesendet. Möchtest du fortfahren?';
	@override String get cancel => 'Abbrechen';
	@override String get accept => 'Akzeptieren';
}

// Path: privateData
class _Translations$privateData$de extends Translations$privateData$en {
	_Translations$privateData$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get deleteTitle => 'Private Daten löschen';
	@override String get deleteMessage => 'Möchtest du wirklich die gesamte verschlüsselte lokale Datenbank löschen? Dieser Vorgang ist unwiderruflich und die Daten können nicht wiederhergestellt werden.';
	@override String get deleteSuccess => 'Private Daten gelöscht.';
	@override String get deleteFailed => 'Vorgang fehlgeschlagen.';
	@override String get exportDoneTitle => 'Export abgeschlossen';
	@override String get exportDoneClipboard => 'Das JSON ist in der Zwischenablage: Linux unterstützt keine Dateifreigabe.';
	@override String get exportDoneShare => 'Das JSON wurde an die Teilen-Auswahl gesendet.';
}

// Path: namePrompt
class _Translations$namePrompt$de extends Translations$namePrompt$en {
	_Translations$namePrompt$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Wie heißt du?';
	@override String get subtitle => 'Gib deinen Namen ein, um das Dashboard zu personalisieren.';
	@override String get hint => 'z. B. Simo';
	@override String get save => 'Speichern und fortfahren';
}

// Path: nav
class _Translations$nav$de extends Translations$nav$en {
	_Translations$nav$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get overview => 'Übersicht';
	@override String get habits => 'Gewohnheiten';
	@override String get insights => 'Statistiken';
	@override String get goals => 'Ziele';
	@override String get coach => 'AI-Coach';
	@override String get settings => 'Einstellungen';
}

// Path: shell
class _Translations$shell$de extends Translations$shell$en {
	_Translations$shell$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get syncPending => 'Sync ausstehend';
	@override String get syncing => 'Synchronisierung';
	@override String get synced => 'Synchronisiert';
	@override String get syncTooltip => 'Synchronisieren';
	@override String get searchHint => 'Suchen oder navigieren';
	@override String get searchSectionHint => 'Abschnitt suchen...';
}

// Path: common
class _Translations$common$de extends Translations$common$en {
	_Translations$common$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override late final _Translations$common$actions$de actions = _Translations$common$actions$de._(_root);
	@override List<String> get months => [
		'Januar',
		'Februar',
		'März',
		'April',
		'Mai',
		'Juni',
		'Juli',
		'August',
		'September',
		'Oktober',
		'November',
		'Dezember',
	];
	@override List<String> get weekdayInitials => [
		'M',
		'D',
		'M',
		'D',
		'F',
		'S',
		'S',
	];
	@override late final _Translations$common$calendarView$de calendarView = _Translations$common$calendarView$de._(_root);
	@override List<String> get weekdaysLong => [
		'Montag',
		'Dienstag',
		'Mittwoch',
		'Donnerstag',
		'Freitag',
		'Samstag',
		'Sonntag',
	];
	@override String get none => 'Keiner';
	@override String get habits => 'Gewohnheiten';
	@override late final _Translations$common$status$de status = _Translations$common$status$de._(_root);
	@override String get total => 'Gesamt';
	@override String get completed => 'Abgeschlossen';
}

// Path: form
class _Translations$form$de extends Translations$form$en {
	_Translations$form$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Titel';
	@override String get category => 'Kategorie';
	@override String get color => 'Farbe';
	@override String get add => 'Hinzufügen';
}

// Path: createGoal
class _Translations$createGoal$de extends Translations$createGoal$en {
	_Translations$createGoal$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Neues Ziel';
	@override String get subtitle => 'Definiere deinen nächsten Meilenstein.';
	@override String get titleHint => 'z. B. Das neue Produkt einführen';
	@override String get categoryHint => 'z. B. Arbeit';
	@override String get timeline => 'Zeitleiste';
	@override String get thisWeek => 'Diese Woche';
	@override String get thisMonth => 'Dieser Monat';
	@override String get thisQuarter => 'Dieses Quartal';
	@override String get thisYear => 'Dieses Jahr';
	@override String get longTerm => 'Langfristig (Lifetime)';
	@override String get dueLifetime => 'Ganzes Leben';
	@override String dueByYear({required Object year}) => 'Bis ${year}';
	@override String get defaultCategory => 'Ziel';
}

// Path: createHabit
class _Translations$createHabit$de extends Translations$createHabit$en {
	_Translations$createHabit$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Neue Gewohnheit';
	@override String get subtitle => 'Definiere deine neue Gewohnheit.';
	@override String get titleHint => 'z. B. Meditation';
	@override String get categoryHint => 'z. B. Wohlbefinden';
	@override String get weeklyFrequency => 'Wöchentliche Häufigkeit';
	@override String get defaultCategory => 'Allgemein';
}

// Path: macroGoals
class _Translations$macroGoals$de extends Translations$macroGoals$en {
	_Translations$macroGoals$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override late final _Translations$macroGoals$types$de types = _Translations$macroGoals$types$de._(_root);
	@override String quarterNumber({required Object quarter}) => 'Quartal ${quarter}';
	@override String get addLifetimeGoal => 'Lebenszeitziel hinzufügen...';
	@override String get addAnnualGoal => 'Jahresziel hinzufügen...';
	@override String get addQuarterlyGoal => 'Vierteljährliches Ziel hinzufügen...';
	@override String get addMonthlyGoal => 'Monatsziel hinzufügen...';
	@override String get addWeeklyGoal => 'Wöchentliches Ziel hinzufügen...';
	@override String get completed => 'VOLLENDET';
	@override String get failed => 'FEHLGESCHLAGEN';
	@override String get create => 'Erstellen';
	@override String get strength => 'Stärke';
	@override String get bestMonth => 'Bester Monat';
	@override String get successRate2 => 'Erfolgsquote';
	@override String get effectiveType => 'Effektiver Typ';
	@override String get historicalTotal => 'Historische Summe';
	@override String get from_ => 'aus';
	@override String get globalSuccess => 'Gesamterfolg';
	@override String get completedGoals => 'Abgeschlossene Ziele';
	@override String get bestYear => 'Bestes Jahr';
	@override String get mostProductiveYear => 'Produktivstes Jahr';
	@override String get totalGoals => 'Ziele gesamt';
	@override String get allYears => 'Alle Jahre';
	@override String get selectYearHeader => 'Jahr auswählen';
	@override String get completions => 'Abschlüsse';
	@override String get success2 => 'Erfolg';
}

// Path: statistics
class _Translations$statistics$de extends Translations$statistics$en {
	_Translations$statistics$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get completed2 => 'Abgeschlossen';
	@override String get notCompleted => 'Nicht abgeschlossen';
	@override String get ofCompletion => 'Abschluss';
	@override String get growth => 'Wachstum';
	@override String get decline => 'Rückgang';
	@override String get strongestDay => 'Stärkster Tag';
	@override String get weakestDay => 'Schwächster Tag';
	@override String get worstNegativeStreak => 'Schlechteste negative Serie';
	@override String get missedConsecutiveDays => 'aufeinanderfolgende verpasste Tage';
	@override String get brokenStreaks => 'Unterbrochene Serien';
	@override String get noBrokenStreaks => 'Keine unterbrochenen Serien erfasst';
	@override String get startedOn => 'begonnen am';
	@override String get moodCorrelation => 'Stimmungskorrelation';
	@override String get avgMood => 'Durchschn. Stimmung (✓)';
	@override String get avgEnergy => 'Durchschn. Energie (✓)';
	@override String get onCompletedDays => 'an erledigten Tagen';
	@override String get resilient => 'Resilient';
	@override String get completedVsMissed => 'Abgeschlossen vs. verpasst';
	@override String get mood2 => 'Stimmung';
	@override String get energy => 'Energie';
	@override String get performancePerLevel => 'Leistung nach Niveau';
	@override String get withHighMood => 'Bei guter Stimmung';
	@override String get withLowMood => 'Bei schlechter Stimmung';
	@override String get moodEnergyAnalysis => 'Die Analyse zeigt, wie deine Beständigkeit von Stimmung und Energie beeinflusst wird.';
	@override String get missed2 => 'Verpasst';
	@override String get positive => 'positiv';
	@override String get neutral => 'neutral';
	@override String get high => 'hoch';
	@override String get low => 'niedrig';
	@override String get skipped => 'Übersprungen';
	@override String get criticalHabits => 'Kritische Gewohnheiten';
	@override String get bestHabitsTitle => 'Beste Gewohnheiten';
	@override String get worseningHabitsDescription => 'Gewohnheiten, die sich verschlechtern.';
	@override String get everythingIsGreat => 'Alles läuft gut';
	@override String get allHabitsStableDescription => 'Alle deine Gewohnheiten halten oder verbessern ihren Trend. Weiter so.';
	@override String habitCompletionPeriodDescription({required Object rate}) => 'Du hast diese Gewohnheit im ausgewählten Zeitraum zu ${rate}% abgeschlossen.';
	@override String habitLostConsistencyDescription({required Object drop}) => 'Diese Gewohnheit hat in der letzten Woche gegenüber der vorherigen ${drop}% Konstanz verloren.';
	@override String get negativeStreak => 'Negative Serie';
	@override String get currentStreak2 => 'Aktuelle Serie';
	@override String get improvementAreas => 'Verbesserungsbereiche';
	@override String get habitsRequiringMoreAttention => 'Gewohnheiten, die mehr Aufmerksamkeit erfordern.';
	@override String get failureAnalysis => 'Fehleranalyse';
	@override String get missedDaysPattern => 'Häufigkeit und Muster deiner verpassten Tage.';
	@override String get recoveryPatterns => 'Erholungsmuster';
	@override String get recoverySpeed => 'Wie schnell du nach einem Ausrutscher wieder auf Kurs kommst.';
	@override String get avgRecoveryTime => 'Durchschnittliche Erholungszeit';
	@override String get worstStreak => 'Schlechteste Serie';
	@override String get frequency => 'HÄUFIGKEIT';
	@override String get daysShortUnit => 'T';
	@override String get perMonthUnit => 'Monat';
	@override String get succ => 'Erfolg';
	@override String get blackDay => 'KRITISCHER TAG';
	@override String get correlationsWith => 'Korrelationen mit';
	@override String get howThisHabitRelatesToOthers => 'Wie diese Gewohnheit mit den anderen zusammenhängt';
	@override String get positiveCorrelations => 'Positive Korrelationen';
	@override String get negativeCorrelations => 'Negative Korrelationen';
	@override String get noSignificantPositiveCorrelation => 'Keine signifikante positive Korrelation';
	@override String get noSignificantNegativeCorrelation => 'Keine signifikante negative Korrelation';
	@override String habitTogetherPercent({required Object percentage}) => '${percentage}% zusammen';
	@override String habitPositiveCorrelationDescription({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'Wenn du "${currentGoal}" abschließt, hast du eine Wahrscheinlichkeit von ${percentage}%, auch "${otherGoal}" abzuschließen.';
	@override String habitNegativeCorrelationDescription({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'Wenn du "${currentGoal}" abschließt, hast du nur eine Wahrscheinlichkeit von ${percentage}%, auch "${otherGoal}" abzuschließen.';
	@override String get weeklyTrend => 'Wöchentlicher Trend';
	@override String get monthlyTrend => 'Monatlicher Trend';
	@override String get yearlyTrend => 'Jährlicher Trend';
	@override String get performanceEvolution => 'Leistungsentwicklung';
	@override String get globalTrend => 'Globaler Trend';
	@override String get total => 'Gesamt';
	@override String get all => 'Alles';
	@override String get noDataForAlerts => 'Nicht genügend Daten, um Warnungen zu erzeugen.';
	@override String get missed => 'Verpasst';
}

// Path: goalState
class _Translations$goalState$de extends Translations$goalState$en {
	_Translations$goalState$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get active => 'In Bearbeitung';
}

// Path: dueLabel
class _Translations$dueLabel$de extends Translations$dueLabel$en {
	_Translations$dueLabel$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get lifetime => 'Lebensziel';
	@override String get annual => 'Jahresziel';
	@override String get quarter => 'Quartal';
}

// Path: dashboard
class _Translations$dashboard$de extends Translations$dashboard$en {
	_Translations$dashboard$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get mood => 'Stimmung';
	@override String get energy => 'Energie';
	@override String get goodMorning => 'Guten Morgen';
	@override String get consecutiveDays => 'aufeinanderfolgende Tage';
	@override String get welcomeTitle => 'Willkommen bei Evolve';
	@override String get welcomeSubtitle => 'Beginne deine persönliche Wachstumsreise.';
	@override String get welcomeBody => 'Diese App hilft dir, gute Gewohnheiten aufzubauen und deine langfristigen Ziele zu erreichen.';
	@override String get welcomeStart => 'Loslegen';
	@override String get subtitle => 'Halte das Tempo. Jede kleine Handlung stärkt die Person, die du wirst.';
	@override String get completionToday => 'Heutiger Abschluss';
	@override String habitsCount({required Object done, required Object total}) => '${done}/${total} Gewohnheiten';
	@override String get bestStreak => 'Beste Serie';
	@override String get activeGoals => 'Aktive Ziele';
	@override String avgProgress({required Object pct}) => '${pct}% durchschnittlicher Fortschritt';
	@override String get momentum => 'Momentum';
	@override String get vsLastWeek => 'gegenüber letzter Woche';
	@override String get weeklyTrend => 'Wochentrend';
	@override String get weeklyTrendSubtitle => 'Abschlussrate deiner Gewohnheiten';
	@override String thisWeekPill({required Object value}) => '${value} diese Woche';
	@override String get todayProtocol => 'Heutiges Protokoll';
	@override String get todayProtocolSubtitle => 'Erledige die wesentlichen Aktionen, bevor du weitere hinzufügst';
	@override String actionsCount({required Object count}) => '${count} Aktionen';
	@override String get emptyHabits => 'Deine Leinwand ist leer. Erstelle deine erste Gewohnheit.';
	@override String streakDaysShort({required Object n}) => '${n} T';
	@override String get checkInDone => 'Check-in erfasst';
	@override String get checkInPrompt => 'Wie fühlst du dich heute?';
	@override String moodEnergyValue({required Object mood, required Object energy}) => 'Stimmung ${mood}/10 · Energie ${energy}/10';
	@override String get checkInHint => 'Erfasse Stimmung und Energie, um deine Musteranalyse zu verbessern.';
	@override String get updateCheckIn => 'Check-in aktualisieren';
	@override String get doCheckIn => 'Check-in machen';
	@override String get dailyCheckIn => 'Täglicher Check-in';
	@override String get dailyCheckInSubtitle => 'Eine kurze Erfassung hilft Evolve, deine Muster besser zu verstehen.';
	@override String get record => 'Speichern';
	@override String get focusGoals => 'Ziele im Fokus';
	@override String get currentPriorities => 'Aktuelle Prioritäten';
	@override String get goalLimitReached => 'Limit von 100 Zielen erreicht. Wechsle zu Pro, um mehr zu erstellen.';
	@override String get emptyFocusGoals => 'Keine Ziele im Fokus. Füge eines hinzu.';
	@override String get weekToStart => 'Woche zum Starten';
	@override String get weekGrowing => 'Woche im Aufwind';
	@override String get weekToRecover => 'Woche zum Aufholen';
	@override String vsPreviousWeek({required Object value}) => '${value} gegenüber der Vorwoche.';
}

// Path: stats
class _Translations$stats$de extends Translations$stats$en {
	_Translations$stats$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Statistiken';
	@override String get global => 'Global';
	@override String get resilience => 'Widerstandsfähigkeit';
	@override String get tabHabits => 'Gewohnheiten';
	@override String get tabMood => 'Stimmung';
	@override String get last30Days => 'Letzte 30 Tage';
	@override String get singleHabit => 'Einzelne Gewohnheit';
	@override String get noHabit => 'Keine Gewohnheit';
	@override String get completionToday => 'Heutiger Abschluss';
	@override String get bestStreakLabel => 'Beste Serie';
	@override String get criticalDay => 'Kritischer Tag';
	@override String get completePrioritiesFirst => 'Erledige zuerst die Prioritäten';
	@override String get recentActivity => 'Letzte Aktivität';
	@override String get recentActivitySubtitle => 'Abschlussintensität der letzten 90 Tage';
	@override String get trendGlobal => 'Globaler Trend';
	@override String get trendGlobalSubtitle => 'Zeitlicher Vergleich des Protokolls';
	@override String vsPrevDay({required Object value}) => '${value}% ggü. Vortag';
	@override String get bestHabit => 'Beste Gewohnheit';
	@override String get criticalArea => 'Kritischer Bereich';
	@override String get streakAtRisk => 'Serie in Gefahr';
	@override String streakAtRiskDetail({required Object habit}) => '${habit} braucht Aufmerksamkeit bei den nächsten Check-ins.';
	@override String get patternToConsolidate => 'Muster zum Festigen';
	@override String get checkLowMoodDays => 'Prüfe Tage mit schlechter Stimmung und halte das Kernprotokoll ein.';
	@override String get goalDue => 'Ziel läuft bald ab';
	@override String get noGoalNeedsIntervention => 'Kein aktives Ziel erfordert Eingreifen.';
	@override String get performancePerHabit => 'Leistung pro Gewohnheit';
	@override String get performancePerHabitSubtitle => 'Rangliste aus synchronisierten Logs nach wöchentlicher Konstanz';
	@override String get avgMood => 'Durchschnittliche Stimmung';
	@override String get avgEnergy => 'Durchschnittliche Energie';
	@override String checkInsAvailable({required Object count}) => '${count} Check-ins verfügbar';
	@override String get resilientHabit => 'Resiliente Gewohnheit';
	@override String get completedEvenHardDays => 'Auch an schwierigen Tagen erledigt';
	@override String get moodEnergy => 'Stimmung und Energie';
	@override String get moodEnergySubtitle => 'Durchschnitt der verfügbaren Check-ins der letzten 90 Tage';
	@override String get completion => 'Abschluss';
	@override String get currentWeek => 'Aktuelle Woche';
	@override String get currentStreak => 'Aktuelle Serie';
	@override String get currentStreakDetail => 'Serie aus verfügbaren Logs synchronisiert';
	@override String get trend30 => '30-Tage-Trend';
	@override String get trend30Detail => 'Abschluss der letzten 30 Tage';
	@override String get yearlyCalendar => 'Jahreskalender';
	@override String yearlyCalendarSubtitle({required Object habit}) => 'Verteilung der Abschlüsse von ${habit}';
	@override String get performancePerDay => 'Leistung pro Tag';
	@override String get performancePerDaySubtitle => 'Starke und schwache Wochentage';
	@override String protectStreak({required Object days}) => 'Schütze die ${days}-Tage-Serie';
	@override String get keepSameSlot => 'Behalte denselben Zeitraum bei, um an intensiven Tagen Reibung zu verringern.';
	@override String worstNegativeSeq({required Object days}) => 'Die schlimmste Negativserie dauerte ${days} Tage.';
	@override String get positiveLever => 'Positiver Hebel erkannt';
	@override String bestHabitRegularity({required Object habit}) => '${habit} hält die beste jüngste Regelmäßigkeit.';
	@override String get moodSensitivity => 'Stimmungsempfindlichkeit';
	@override String get lowEnergyCompletion => 'Abschluss bei niedriger Energie';
	@override String get moodOutputCorrelation => 'Korrelation Stimmung-Leistung';
	@override String get moodOutputSubtitle => 'Verfügbare Abschlüsse an Check-in-Tagen';
	@override String get keyCorrelations => 'Wichtige Korrelationen';
	@override String get keyCorrelationsSubtitle => 'Muster mit dem größten Einfluss auf das Protokoll';
	@override String get moreLogsNeeded => 'Es werden mehr Logs benötigt, um nützliche Korrelationen zu berechnen.';
	@override String get createHabitForAnalysis => 'Erstelle mindestens eine Gewohnheit, um die detaillierte Analyse zu sehen.';
	@override String get noData => 'Keine Daten';
	@override String get tabInfo => 'Info';
	@override String get tabTrend => 'Trend';
	@override String get tabAlerts => 'Warnungen';
	@override String get tabOverview => 'Übersicht';
	@override String get tabCalendar => 'Kalender';
	@override String get tabPerformance => 'Leistung';
	@override String get tabImprovement => 'Verbesserung';
	@override String get pageSubtitle => 'Erkenne die Muster, die Wachstum fördern, und handle bei kritischen Bereichen.';
	@override String actionsFraction({required Object done, required Object total}) => '${done}/${total} Aktionen';
	@override String affectedByHardDays({required Object habit}) => '${habit} leidet an schwierigen Tagen';
	@override String get last30DaysTrend => 'Trend der letzten 30 Tage';
	@override String strongestDayDetail({required Object pct, required Object done, required Object total}) => 'Gut gemacht, ${pct}% Abschluss (${done}/${total})';
	@override String weakestDayDetail({required Object pct, required Object done, required Object total}) => 'Nur ${pct}% Abschluss (${done}/${total})';
	@override String brokenStreakItem({required Object days}) => 'Serie von ${days} Tagen unterbrochen';
	@override String togetherProbability({required Object percentage}) => '${percentage}% zusammen';
	@override String get criticalHabitsSubtitle => 'Gewohnheiten, die sich verschlechtern.';
	@override String get bestHabitsSubtitle => 'Die Gewohnheiten, bei denen du am bestandigsten bist.';
	@override String get timeframeWeek => 'Woche';
	@override String get timeframeMonth => 'Monat';
	@override String get timeframeYear => 'Jahr';
	@override String get timeframeAll => 'Alles';
	@override String negativeStreakDays({required Object days}) => '${days} Tage ohne Abschluss';
	@override String dropPercent({required Object drop}) => '-${drop}%';
	@override String blackDayDetail({required Object day}) => 'Schwarzer Tag: ${day}';
	@override String failureDetail({required Object streak, required Object frequency}) => 'Schlimmste Serie: ${streak}T · ~${frequency}/Monat verpasst';
	@override String recoveryDetail({required Object days}) => 'Durchschnittliche Erholungszeit: ${days} Tage';
	@override String successRate({required Object rate}) => '${rate}% Erfolg';
}

// Path: habitsPage
class _Translations$habitsPage$de extends Translations$habitsPage$en {
	_Translations$habitsPage$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get today => 'Heute';
	@override String get subtitle => 'Baue dein tägliches Protokoll auf und beobachte die Konstanz im Zeitverlauf.';
	@override String get tabProtocol => 'Protokoll';
	@override String get tabCalendar => 'Kalender';
	@override String get deleteHabitTitle => 'Gewohnheit löschen';
	@override String deleteHabitConfirm({required Object title}) => '„${title}“ aus dem Protokoll entfernen?';
	@override String get activeProtocol => 'Aktives Protokoll';
	@override String get completedToday => 'Heute erledigt';
	@override String get dailyProtocol => 'Tägliches Protokoll';
	@override String get protocolSubtitle => 'Wochenübersicht, Erinnerungen und Schnellaktionen';
	@override String get colHabit => 'GEWOHNHEIT';
	@override String get colStreak => 'SERIE';
	@override String get colLast7Days => 'LETZTE 7 TAGE';
	@override String get colReminder => 'ERINNERUNG';
	@override String streakDays({required Object n}) => '${n} Tage';
	@override String get prevPeriod => 'Vorheriger Zeitraum';
	@override String get nextPeriod => 'Nächster Zeitraum';
	@override List<String> get weekdayAbbrevUpper => [
		'MO',
		'DI',
		'MI',
		'DO',
		'FR',
		'SA',
		'SO',
	];
	@override String get lifeView => 'Lebensansicht';
	@override String get lifeViewSubtitle => 'Eine Zelle steht für einen Monat des Weges bis zum Alter von 85.';
	@override String get monthsLived => 'Gelebte Monate';
	@override String get currentAge => 'Aktuelles Alter';
	@override String get monthsRemaining => 'Verbleibende Monate';
	@override String dayDetail({required Object day, required Object month}) => 'Details ${day}. ${month}';
	@override String get dayDetailSubtitle => 'Aktualisiere den Status der Gewohnheiten für diesen Tag.';
	@override String get editHabit => 'Gewohnheit bearbeiten';
	@override String get newHabit => 'Neue Gewohnheit';
	@override String get optionalReminder => 'Optionale Erinnerung';
	@override String get reminderHint => 'z. B. 08:30';
	@override String get close => 'Schließen';
	@override String statusDone({required Object category}) => '${category} · Erledigt';
	@override String statusSkipped({required Object category}) => '${category} · Übersprungen';
	@override String statusUnrecorded({required Object category}) => '${category} · Nicht erfasst';
	@override String weekOf({required Object day, required Object month}) => 'Woche vom ${day}. ${month}';
	@override String get lifeWeeks => 'Wochen deines Weges';
	@override String get catWellness => 'Wohlbefinden';
	@override String get catProductivity => 'Produktivität';
	@override String get catEducation => 'Bildung';
	@override String get catHealth => 'Gesundheit';
	@override String get catMindfulness => 'Achtsamkeit';
}

// Path: goalsPage
class _Translations$goalsPage$de extends Translations$goalsPage$en {
	_Translations$goalsPage$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Makroziele';
	@override String get subtitle => 'Langfristige Planung.';
	@override String get sampleGoal => 'Beispielziel';
	@override String get periodLifetime => 'Lebensziele';
	@override String get subtitleLifetime => 'Lebenslange Ziele';
	@override String get subtitleAnnual => 'Jahresziele';
	@override String get subtitleQuarterly => 'Quartalsziele';
	@override String get subtitleMonthly => 'Monatsziele';
	@override String get subtitleWeekly => 'Wochenziele';
	@override String get statsTab => 'Stats';
	@override String get fullView => 'Vollständige Ansicht';
	@override String get categoriesTitle => 'Zielkategorien';
	@override String get defaultPill => 'Standard';
	@override String get editCategory => 'Kategorie bearbeiten';
	@override String get archiveCategory => 'Kategorie archivieren';
	@override String get categoryCreateFailed => 'Kategorie konnte nicht erstellt werden.';
	@override String get categoryArchiveFailed => 'Kategorie konnte nicht archiviert werden.';
	@override String get categoryEditFailed => 'Kategorie konnte nicht bearbeitet werden.';
	@override String get addCategory => 'Kategorie hinzufügen';
	@override String get back => 'Zurück';
	@override String get finish => 'Fertig';
	@override String get next => 'Weiter';
	@override String get categoriesTooltip => 'Kategorien';
	@override String get rescheduleTooltip => 'Auf nächsten Zeitraum verschieben';
	@override String get defaultCategory => 'Standard';
	@override String get emptyActive => 'Kein aktives Ziel in diesem Zeitraum.';
	@override String get emptyAdd => 'Füge das erste Ziel für diesen Zeitraum hinzu.';
	@override String get newGoal => 'Neues Ziel';
	@override String get editGoal => 'Ziel bearbeiten';
	@override String get horizonLabel => 'Horizont';
	@override String get newCategory => 'Neue Kategorie';
	@override String get nameLabel => 'Name';
	@override String weekPeriodLabel({required Object week, required Object month, required Object year}) => 'Woche ${week}, ${month} ${year}';
	@override String get currentQuarter => 'Aktuelles Quartal';
	@override String get currentMonth => 'Aktueller Monat';
	@override String get tutPlanningTitle => 'Planungstyp';
	@override String get tutPlanningDesc => 'Hier kannst du den Zeithorizont deiner Ziele auswählen.';
	@override String get tutNewGoalDesc => 'Von hier aus kannst du schnell ein neues Ziel hinzufügen.';
	@override String get tutCompleteTitle => 'Abschließen oder scheitern';
	@override String get tutCompleteDesc => 'Markiere das Ziel mit einem Klick als abgeschlossen oder gescheitert.';
	@override String get tutCategoryDesc => 'Verwalte Kategorien und verknüpfe sie mit deinen Zielen.';
	@override String get tutRescheduleTitle => 'Verschieben';
	@override String get tutRescheduleDesc => 'Verschiebe das Ziel in den nächsten Zeitraum, wenn du es nicht abschließen konntest.';
	@override String get tutEditDesc => 'Bearbeite die Details deines Ziels.';
	@override String get tutDeleteDesc => 'Lösche ein Ziel, wenn es nicht mehr relevant ist.';
	@override String get tutStatsTitle => 'Analyse und Statistiken';
	@override String get tutStatsDesc => 'Wechsle zur Statistikansicht, um deine Leistung im Zeitverlauf zu analysieren.';
}

// Path: goalsStats
class _Translations$goalsStats$de extends Translations$goalsStats$en {
	_Translations$goalsStats$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get proRequired => 'Pro-Funktion erforderlich';
	@override String get active => 'Aktiv';
	@override String get failed => 'Gescheitert';
	@override String get complAbbr => 'Abg.';
	@override String get seasonality => 'Saisonalität';
	@override String get interestEvolution => 'Interessenentwicklung';
}

// Path: ai
class _Translations$ai$de extends Translations$ai$en {
	_Translations$ai$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get coach => 'AI-Coach';
	@override String get dailyHabits => 'Tägliche Gewohnheiten';
	@override String get macroGoals => 'Makroziele';
	@override late final _Translations$ai$openRouter$de openRouter = _Translations$ai$openRouter$de._(_root);
}

// Path: aiCoach
class _Translations$aiCoach$de extends Translations$aiCoach$en {
	_Translations$aiCoach$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get greeting => 'Hallo! Ich bin Evolve AI Coach. Ich helfe dir, dein Protokoll zu optimieren und deine Ziele zu erreichen. Wie kann ich dir heute helfen?';
	@override String get systemPersona => 'Du bist Evolve AI Coach, ein virtueller Assistent für persönliche Disziplin.';
	@override String get habitsHeader => 'AKTIVE GEWOHNHEITEN:';
	@override String get noActiveHabits => 'Keine aktiven Gewohnheiten.';
	@override String habitLine({required Object title, required Object done, required Object streak}) => '${title} (Heute erledigt: ${done}, Serie: ${streak})';
	@override String get goalsHeader => 'ZIELE:';
	@override String get noActiveGoals => 'Keine aktiven langfristigen Ziele.';
	@override String goalLine({required Object title, required Object due}) => '${title} (Fällig: ${due})';
	@override String get contextTitle => 'KI-Kontext';
	@override String get contextBody => 'Wähle, welche Daten du mit dem KI-Coach teilst, um personalisierte Ratschläge zu erhalten.';
	@override String get shareHabitsDesc => 'Teilt deine aktiven Gewohnheiten, Serien und den heutigen Abschlussstatus.';
	@override String get shareGoalsDesc => 'Teilt deine aktiven langfristigen Ziele.';
	@override String get saveClose => 'Speichern und schließen';
	@override String get subtitle => 'Analysiere Muster mit einem kontextbezogenen Coach auf Basis deiner Reisedaten.';
	@override String get contextButton => 'Kontext';
	@override String get typing => 'AI Coach schreibt...';
	@override String get inputHint => 'Frag deinen Coach um Rat...';
}

// Path: settingsPage
class _Translations$settingsPage$de extends Translations$settingsPage$en {
	_Translations$settingsPage$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get account => 'Konto';
	@override String get notifications => 'Benachrichtigungen';
	@override String get language => 'Sprache';
	@override String get timeFormat24h => '24-Stunden-Format';
	@override String get subscription => 'Abonnement';
	@override String get proName => 'Evolve PRO';
	@override String get planMonthly => 'Monatlich';
	@override String get planAnnual => 'Jährlich';
	@override String get restorePurchases => 'Käufe wiederherstellen';
	@override String get deletePrivateData => 'private Daten löschen';
	@override String get importInProgress => 'Daten werden importiert...';
	@override String get passwordsDontMatch => 'Die Passwörter stimmen nicht überein';
	@override String get email => 'E-Mail';
	@override String get cancel => 'Abbrechen';
	@override String get confirm => 'Bestätigen';
	@override String get save => 'Speichern';
	@override String get pageTitle => 'Einstellungen';
	@override String get pageSubtitle => 'Verwalte dein Profil, das Desktop-Verhalten, den Datenschutz und den Evolve-Plan.';
	@override String get profileLabel => 'Profil';
	@override String get profileSubtitle => 'Persönliche Informationen und Synchronisierungsstatus';
	@override String get accountAndOnboarding => 'Konto und Onboarding';
	@override String get privateMode => 'Privater Modus';
	@override String get sessionUnavailable => 'Sitzung nicht verfügbar';
	@override String get dataRepository => 'Daten-Repository';
	@override String get encryptedLocalDatabase => 'Verschlüsselte lokale Datenbank';
	@override String get supabaseWithEncryptedCache => 'Supabase mit verschlüsseltem Cache';
	@override String get personalInfo => 'Persönliche Informationen';
	@override String get personalInfoDetail => 'Vorname, Nachname, E-Mail und Geburtsdatum';
	@override String get updateAvatar => 'Avatar aktualisieren';
	@override String get updateAvatarDetail => 'Wähle ein lokales Bild für das Desktop-Profil.';
	@override String get reviewInitialConsent => 'Erstzustimmung überprüfen';
	@override String get reviewInitialConsentDetail => 'Bedingungen, Datenschutz, Benachrichtigungen und Absturzberichte';
	@override String get signOut => 'Vom Konto abmelden';
	@override String get signOutDetailActive => 'Die Sitzung auf diesem Gerät schließen';
	@override String get availableWithActiveSession => 'Verfügbar mit einer aktiven Supabase-Sitzung';
	@override String get goToLogin => 'Zur Anmeldung';
	@override String get goToLoginDetail => 'Setze den privaten Modus aus und melde dich bei Supabase an.';
	@override String get appearanceTitle => 'Erscheinungsbild und Anwendung';
	@override String get appearanceSubtitle => 'Lokale Einstellungen, an den Desktop angepasst';
	@override String get appearanceAndVisual => 'Erscheinungsbild und Optik';
	@override String get darkMode => 'Dunkler Modus';
	@override String get darkModeDetail => 'Verwende das schwarz-weiße dunkle Design.';
	@override String get calendarExperienceLanguage => 'Kalender, Erlebnis und Sprache';
	@override String get accentColor => 'Akzentfarbe';
	@override String get accentColorDetail => 'Erweiterte Palette, reserviert für Evolve Pro.';
	@override String get defaultCalendarView => 'Standard-Kalenderansicht';
	@override String get timeFormat24hDetail => 'Verwende Uhrzeiten wie 20:30 statt 8:30 PM.';
	@override String get hapticFeedback => 'Haptisches Feedback';
	@override String get hapticFeedbackDetail => 'Der Desktop behält die Einstellung bei, erzeugt aber keine Vibrationen.';
	@override String get resetTutorial => 'Tutorial zurücksetzen';
	@override String get resetTutorialDetail => 'Öffnet die Schritt-für-Schritt-Anleitungen für Dashboard und Ziele erneut.';
	@override String get notificationsSubtitle => 'Betriebshinweise des Desktop-Clients';
	@override String get operationalReminders => 'Betriebshinweise';
	@override String get habitReminders => 'Gewohnheitserinnerungen';
	@override String get habitRemindersDetail => 'Sendet das tägliche Morgenbriefing.';
	@override String get morningBriefTime => 'Uhrzeit des Morgenbriefings';
	@override String get eveningReview => 'Abendliche Rückschau';
	@override String get eveningReviewDetail => 'Erinnert dich daran, deinen Tag zu festigen.';
	@override String get eveningReviewTime => 'Uhrzeit der abendlichen Rückschau';
	@override String get requestNotificationPermissions => 'Benachrichtigungsberechtigungen anfordern';
	@override String get requestNotificationPermissionsDetail => 'Öffnet die native Eingabeaufforderung auf der unterstützten Plattform.';
	@override String get nativeDeliveryTitle => 'Native Zustellung je nach Betriebssystem';
	@override String get privacyTitle => 'Datenschutz und Sicherheit';
	@override String get privacySubtitle => 'Zugriffsschutz, Einwilligungen und Datenverwaltung';
	@override String get accessProtection => 'Zugriffsschutz';
	@override String get biometricLock => 'Biometrische Sperre';
	@override String get biometricLockDetail => 'Verfügbar mit dem nativen Adapter unter macOS und Windows; unter Linux nicht unterstützt.';
	@override String get changePassword => 'Passwort ändern';
	@override String get changePasswordDetail => 'Aktualisierung der Anmeldedaten über Supabase Auth.';
	@override String get dataAndConsents => 'Daten und Einwilligungen';
	@override String get sendCrashReports => 'Absturzberichte senden';
	@override String get sendCrashReportsDetail => 'Gesonderte Einwilligung für Sentry.';
	@override String get exportData => 'Daten exportieren';
	@override String get exportDataDetail => 'Teilt einen vollständigen JSON-Export der verfügbaren Daten.';
	@override String get importData => 'Daten importieren';
	@override String get importDataDetail => 'Stellt ein Backup (.zip-Format) von Evolve wieder her.';
	@override String get systemPermissionsManagement => 'Verwaltung der Systemberechtigungen';
	@override String get systemPermissionsManagementDetail => 'Benachrichtigungen, Kalender und Sicherheit.';
	@override String get deletePrivateDataDetail => 'Löscht die verschlüsselte lokale Datenbank dauerhaft.';
	@override String get deleteAccountAndData => 'Konto und Daten löschen';
	@override String get deleteAccountAndDataDetail => 'Unwiderruflicher Vorgang, durch Bestätigung geschützt.';
	@override String get exportPrivateShareText => 'Meine privaten Daten, exportiert aus Evolve';
	@override String get exportShareText => 'Meine aus Evolve exportierten Daten';
	@override String get exportDoneTitle => 'Export abgeschlossen';
	@override String get exportDoneClipboard => 'Das JSON ist in der Zwischenablage: Linux unterstützt keine Dateifreigabe.';
	@override String get exportDoneShare => 'Das JSON wurde an die Freigabeauswahl gesendet.';
	@override String get avatarGateTitle => 'Avatar';
	@override String get avatarPickFailed => 'Bildauswahl fehlgeschlagen.';
	@override String get confirmSignOutTitle => 'Abmeldung bestätigen';
	@override String get confirmSignOutMessage => 'Möchtest du dich wirklich abmelden? Du musst deine Anmeldedaten erneut eingeben, um dich wieder anzumelden.';
	@override String get gateProfile => 'Profil';
	@override String get gateLogout => 'Abmelden';
	@override String get gateChangePassword => 'Passwortänderung';
	@override String get gateRequiresActiveSession => 'Erfordert eine aktive Supabase-Sitzung.';
	@override String get biometricActivationCancelled => 'Aktivierung abgebrochen.';
	@override String get notificationPermissionsTitle => 'Benachrichtigungsberechtigungen';
	@override String get notificationPermissionsGranted => 'Berechtigungen für dieses System verfügbar.';
	@override String get notificationPermissionsDenied => 'Berechtigung nicht erteilt. Du kannst sie in den Systemeinstellungen ändern.';
	@override String get systemPermissionsTitle => 'Systemberechtigungen';
	@override String get systemPermissionsOpenFailed => 'Einstellungen konnten nicht geöffnet werden.';
	@override String get tutorialResetTitle => 'Tutorials zurückgesetzt';
	@override String get tutorialResetMessage => 'Die Anleitungen werden in den entsprechenden Bereichen erneut angezeigt.';
	@override String get accountDataManagementTitle => 'Konto- und Datenverwaltung';
	@override String get accountDataManagementContent => 'Wähle, ob die Daten gelöscht werden sollen, während das Konto aktiv bleibt, oder ob das Konto dauerhaft gelöscht werden soll.';
	@override String get resetDataAction => 'Daten zurücksetzen';
	@override String get deleteAccountAction => 'Konto löschen';
	@override String get confirmResetDataTitle => 'Zurücksetzen der Daten bestätigen';
	@override String get confirmResetDataMessage => 'Gewohnheiten, Ziele und Einstellungen werden gelöscht. Das Konto bleibt aktiv. Diese Aktion kann nicht rückgängig gemacht werden.';
	@override String get confirmDeleteAccountTitle => 'Kontolöschung bestätigen';
	@override String get confirmDeleteAccountMessage => 'Das Konto und alle zugehörigen Daten werden dauerhaft gelöscht. Diese Aktion ist unwiderruflich.';
	@override String get resetDataTitle => 'Daten zurücksetzen';
	@override String get resetDataSuccess => 'Daten erfolgreich gelöscht.';
	@override String get operationFailed => 'Vorgang fehlgeschlagen.';
	@override String get deleteAccountGateTitle => 'Konto löschen';
	@override String get accountDeleted => 'Konto gelöscht.';
	@override String get importDataGateTitle => 'Daten importieren';
	@override String get importPrivateOnly => 'Die Importfunktion ist derzeit nur im privaten Modus (lokal) verfügbar.';
	@override String get importSummaryTitle => 'Importübersicht';
	@override String importHabitsCount({required Object count}) => '${count} Gewohnheiten';
	@override String importLogsCount({required Object count}) => '${count} Check-ins (Log)';
	@override String importMacroGoalsCount({required Object count}) => '${count} Makro-Ziele';
	@override String importCategoriesCount({required Object count}) => '${count} Kategorien';
	@override String importMoodsCount({required Object count}) => '${count} Stimmungsaufzeichnungen';
	@override String get importReplaceTitle => 'Aktuelle Daten ersetzen';
	@override String get importReplaceSubtitle => 'Löscht alle vorhandenen lokalen Daten vor dem Import. (Empfohlen)';
	@override String get importMergeTitle => 'Mit aktuellen Daten zusammenführen';
	@override String get importMergeSubtitle => 'Fügt die importierten Daten hinzu, ohne etwas zu löschen. Kann zu Duplikaten führen.';
	@override String get importConfirmButton => 'Import bestätigen';
	@override String get importSuccess => 'Import erfolgreich abgeschlossen!';
	@override String importError({required Object error}) => 'Fehler beim Import: ${error}';
	@override String get proTitle => 'Evolve Pro';
	@override String get proSubtitle => 'Plan, Kaufwiederherstellung und Abonnementverwaltung';
	@override String get revenueCatMacos => 'RevenueCat macOS';
	@override String get commercialChannelRequired => 'Kommerzieller Kanal erforderlich';
	@override String get revenueCatOffersRead => 'Angebote und Berechtigungsstatus werden von RevenueCat gelesen.';
	@override String get revenueCatConfigureKey => 'Konfiguriere den öffentlichen RevenueCat-Schlüssel des Desktop-Clients.';
	@override String get revenueCatNotSupported => 'RevenueCat Flutter stellt keine In-App-Käufe unter Windows und Linux bereit.';
	@override String get bestValue => 'Bester Wert';
	@override String get planManagement => 'Planverwaltung';
	@override String get activateEvolvePro => 'Evolve Pro aktivieren';
	@override String get activateEvolveProActive => 'Evolve Pro-Berechtigung aktiv.';
	@override String get activateEvolveProStart => 'Starte den nativen StoreKit-Checkout unter macOS.';
	@override String get restorePurchasesDetail => 'Ruft den Berechtigungsstatus vom Anbieter ab.';
	@override String get manageSubscription => 'Abonnement verwalten';
	@override String get manageSubscriptionDetail => 'Öffnet die Abonnementverwaltung des Apple-Kontos.';
	@override String get notAuthenticated => 'Nicht authentifiziert';
	@override String get verified => 'Verifiziert';
	@override String get privateModeDataProtected => 'Deine Daten sind geschützt und werden nur auf diesem Gerät gespeichert.';
	@override String get profileFallback => 'Profil';
	@override String get fullName => 'Vollständiger Name';
	@override String get dateOfBirth => 'Geburtsdatum';
	@override String get dateOfBirthHint => 'JJJJ-MM-TT';
	@override String get currentPassword => 'Aktuelles Passwort';
	@override String get newPassword => 'Neues Passwort';
	@override String get confirmNewPassword => 'Neues Passwort bestätigen';
	@override String get updatePassword => 'Passwort aktualisieren';
	@override String get enterCurrentPassword => 'Gib dein aktuelles Passwort ein.';
	@override String get newPasswordMinLength => 'Das neue Passwort muss mindestens 8 Zeichen lang sein.';
	@override String get passwordUpdateFailed => 'Aktualisierung fehlgeschlagen. Überprüfe dein aktuelles Passwort.';
	@override String get sectionApplication => 'Anwendung';
	@override String get sectionPrivacy => 'Datenschutz';
	@override String get customColor => 'Benutzerdefinierte Farbe';
	@override String get applyAction => 'Anwenden';
	@override String useAccent({required Object hex}) => 'Akzent ${hex} verwenden';
	@override String get proUpsellTitle => 'Zu Evolve PRO wechseln';
	@override String get proUpsellSubtitle => 'Schalte alle Funktionen frei und beschleunige dein Wachstum.';
	@override String get proWelcomeTitle => 'Willkommen bei Evolve PRO';
	@override String get proActiveMessage => 'Ihr Abonnement ist aktiv. Sie haben jetzt vollständigen und unbegrenzten Zugriff auf den personalisierten AI Coach, erweiterte Trendstatistiken und alle persönlichen Wachstumstools von Evolve.';
	@override String get proStartJourney => 'Starte deinen Weg';
}

// Path: consent
class _Translations$consent$de extends Translations$consent$en {
	_Translations$consent$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get onboardingTitle => 'Deine Privatsphäre ist wichtig';
	@override String get continueButton => 'Weiter';
}

// Path: notifications
class _Translations$notifications$de extends Translations$notifications$en {
	_Translations$notifications$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get actionDone => 'Erledigt';
	@override String get actionSkip => 'Überspringen';
	@override String get actionSnooze => 'Später';
	@override String get morningBrief => 'Morgenbriefing';
	@override String get eveningReview => 'Abend-Review';
	@override String get morningBriefBody => 'Zeit, deinen Tag zu strukturieren. Prüfe deine Ziele.';
	@override String get eveningReviewBody => 'Wie lief der Tag? Erfasse deinen Fortschritt und aktualisiere den Verlauf.';
}

// Path: privacy
class _Translations$privacy$de extends Translations$privacy$en {
	_Translations$privacy$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get biometricAuthReason => 'Authentifiziere dich, um den App-Schutz zu aktivieren.';
	@override String get biometricUnlockReason => 'Entsperre die App, um fortzufahren.';
}

// Path: consentPage
class _Translations$consentPage$de extends Translations$consentPage$en {
	_Translations$consentPage$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get subtitle => 'Bevor du Evolve Desktop verwendest, bestätige die Bedingungen, die Datenschutzrichtlinie und die für die Synchronisierung erforderliche Datenverarbeitung.';
	@override String get acceptTerms => 'Ich akzeptiere die Bedingungen und die Datenschutzrichtlinie';
	@override String get termsSubtitle => 'Ich bestätige, dass ich die Dokumente gelesen habe und mindestens 14 Jahre alt bin.';
	@override String get crashDiagnostics => 'Absturzdiagnose';
	@override String get crashSubtitle => 'Erlaube das Senden anonymisierter technischer Berichte.';
	@override String get openPrivacy => 'Datenschutzrichtlinie öffnen';
}

// Path: notif
class _Translations$notif$de extends Translations$notif$en {
	_Translations$notif$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get macScheduling => 'Tägliche Planung auf macOS aktiv.';
	@override String get linuxImmediate => 'Linux zeigt sofortige Benachrichtigungen, unterstützt aber keine Planung.';
	@override String get openEvolve => 'Evolve öffnen';
	@override String get windowsScheduling => 'Windows plant das nächste Vorkommen bei jedem Start.';
	@override String get morningBody => 'Sieh dir die heutigen Gewohnheiten an und wähle, wo du beginnst.';
	@override String get habitReminderBody => 'Zeit, deine Gewohnheit zu erledigen.';
	@override String get eveningBody => 'Lass den Tag ausklingen und aktualisiere deinen Fortschritt.';
}

// Path: biometricGate
class _Translations$biometricGate$de extends Translations$biometricGate$en {
	_Translations$biometricGate$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get appLocked => 'App gesperrt';
	@override String get unlockPrompt => 'Entsperre mit lokaler Authentifizierung, um fortzufahren.';
	@override String get verifying => 'Wird überprüft...';
	@override String get unlock => 'Entsperren';
	@override String get notSupportedLinux => 'Die biometrische Sperre wird unter Linux nicht unterstützt.';
	@override String get noLocalAuth => 'Keine lokale Authentifizierungsmethode verfügbar.';
	@override String get authFailed => 'Authentifizierung fehlgeschlagen.';
	@override String get authUnavailable => 'Lokale Authentifizierung nicht verfügbar.';
}

// Path: sync
class _Translations$sync$de extends Translations$sync$en {
	_Translations$sync$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get syncFailed => 'Synchronisierung fehlgeschlagen. Lokale Daten beibehalten.';
	@override String get editSavedLocally => 'Änderung lokal gespeichert. Synchronisierung wird erneut versucht.';
}

// Path: subscriptionCtrl
class _Translations$subscriptionCtrl$de extends Translations$subscriptionCtrl$en {
	_Translations$subscriptionCtrl$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get purchaseComplete => 'Kauf abgeschlossen: Berechtigung wird synchronisiert.';
	@override String get purchaseIncomplete => 'Kauf nicht abgeschlossen.';
	@override String get cantOpenApple => 'Apple-Abonnementverwaltung konnte nicht geöffnet werden.';
	@override String get macOnly => 'In-App-Käufe sind im macOS-Client verfügbar.';
	@override String get loadOffersFailed => 'RevenueCat-Angebote konnten nicht geladen werden.';
	@override String get proActivated => 'Evolve Pro aktiviert.';
	@override String get purchasesRestored => 'Käufe wiederhergestellt.';
	@override String get noActiveSub => 'Kein aktives Pro-Abonnement gefunden.';
	@override String get restoreFailed => 'Käufe konnten nicht wiederhergestellt werden.';
	@override String get configKey => 'Konfiguriere den öffentlichen RevenueCat-Schlüssel des Desktop-Clients.';
	@override String get loginFirst => 'Melde dich an, bevor du Evolve Pro verwaltest.';
}

// Path: authCtrl
class _Translations$authCtrl$de extends Translations$authCtrl$en {
	_Translations$authCtrl$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get appleNoToken => 'Apple hat kein Identity-Token zurückgegeben.';
	@override String get appleAuthFailed => 'Apple-Authentifizierung fehlgeschlagen.';
	@override String get cantOpenBrowser => 'Der Systembrowser konnte nicht geöffnet werden.';
	@override String accessNotCompleted({required Object provider}) => '${provider}-Anmeldung nicht abgeschlossen.';
	@override String providerAuthFailed({required Object provider}) => '${provider}-Authentifizierung fehlgeschlagen.';
	@override String get operationFailed => 'Vorgang fehlgeschlagen. Versuche es gleich erneut.';
}

// Path: proModal
class _Translations$proModal$de extends Translations$proModal$en {
	_Translations$proModal$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Evolve PRO freischalten';
	@override String get subtitle => 'Bringen Sie Ihr Gewohnheitssystem auf die nächste Stufe';
	@override String get featuresHeader => 'Was der PRO-Plan enthält';
	@override String get aiCoachTitle => 'Personalisierter AI-Coach';
	@override String get aiCoachDesc => 'Erweiterte Trendanalyse und intelligente KI-generierte Vorschläge.';
	@override String get statsTitle => 'Gewohnheitsspezifische Statistiken';
	@override String get statsDesc => 'Wichtige Erkenntnisse zur Steigerung Ihrer Produktivität.';
	@override String get metricsTitle => 'Erweiterte Zielmetriken';
	@override String get metricsDesc => 'Sehen Sie sich detaillierte Diagramme und detaillierte Leistungsstatistiken für jedes Jahr an.';
	@override String get unlimitedTitle => 'Unbegrenzte Gewohnheiten';
	@override String get unlimitedDesc => 'Erstellen und verfolgen Sie alle gewünschten Gewohnheiten ohne Einschränkungen.';
	@override String get maybeLater => 'Vielleicht später';
	@override String get viewPlans => 'Pro-Abos ansehen';
}

// Path: tutorial
class _Translations$tutorial$de extends Translations$tutorial$en {
	_Translations$tutorial$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get back => 'Zurück';
	@override String get next => 'Weiter';
	@override String get finish => 'Fertig';
	@override String get dailyCheckIn => 'Täglicher Check-in';
	@override String get dailyCheckinDesc => 'Hier kannst du deine tägliche Stimmung festhalten, um dein Wohlbefinden zu verfolgen und mit dem Erreichen deiner Ziele zu verknüpfen.';
	@override String get manageHabits => 'Gewohnheiten verwalten';
	@override String get addEditOrDeleteDailyHabits => 'Fügen Sie schnell und einfach tägliche Gewohnheiten hinzu, bearbeiten oder löschen Sie sie.';
	@override String get movingToGoals => 'Weiter zu den Zielen';
	@override String get goalsPageDesc => 'Die Seite, auf der du deine langfristigen Ziele und deren Leistung verwaltest.';
	@override String get filterByHabit => 'Nach Gewohnheit filtern';
	@override String get filterHabitDesc => 'Von hier aus kannst du eine bestimmte Gewohnheit für Details auswählen oder \'Alle Gewohnheiten\' für einen Gesamtüberblick.';
	@override String get statisticsSections => 'Statistikbereiche';
	@override String get statsSectionsDesc => 'Navigiere zwischen den Tabs, um Trends, Leistungs-Warnungen, den Verlauf deiner Gewohnheiten und deine Stimmung zu sehen.';
}

// Path: common.actions
class _Translations$common$actions$de extends Translations$common$actions$en {
	_Translations$common$actions$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get cancel => 'Abbrechen';
	@override String get save => 'Speichern';
	@override String get delete => 'Löschen';
	@override String get edit => 'Bearbeiten';
}

// Path: common.calendarView
class _Translations$common$calendarView$de extends Translations$common$calendarView$en {
	_Translations$common$calendarView$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get year => 'Jahr';
	@override String get month => 'Monat';
	@override String get week => 'Woche';
	@override String get life => 'Leben';
}

// Path: common.status
class _Translations$common$status$de extends Translations$common$status$en {
	_Translations$common$status$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get error => 'Fehler';
}

// Path: macroGoals.types
class _Translations$macroGoals$types$de extends Translations$macroGoals$types$en {
	_Translations$macroGoals$types$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get annual => 'Jährlich';
	@override String get quarterly => 'Quartalsweise';
	@override String get monthly => 'Monatlich';
	@override String get weekly => 'Wöchentlich';
	@override String get lifetime => 'Lebenslang';
}

// Path: ai.openRouter
class _Translations$ai$openRouter$de extends Translations$ai$openRouter$en {
	_Translations$ai$openRouter$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get apiKeyMissingFull => '⚠️ Fehler: Der OpenRouter-API-Schlüssel ist nicht konfiguriert.\n\nFüge deinen API-Schlüssel in `lib/core/openrouter_config.dart` hinzu.';
	@override String get apiKeyMissingShort => '⚠️ Fehler: Der OpenRouter-API-Schlüssel ist nicht konfiguriert.';
	@override String get defaultSystemPrompt => 'Du bist der "Discipline Coach", ein virtueller Assistent, der dem Nutzer hilft, diszipliniert zu bleiben, Ziele zu erreichen und gesunde Gewohnheiten aufzubauen. Sei motivierend, aber konkret, direkt und praktisch. Verwende einen professionellen, aber freundlichen Ton.';
	@override String communicationError({required Object code}) => '❌ Fehler bei der Kommunikation mit der AI. (Code: ${code})';
	@override String get connectionError => '❌ Verbindungsfehler. Stelle sicher, dass du online bist, und versuche es erneut.';
	@override String get connectionErrorShort => '❌ Verbindungsfehler.';
	@override String get connectionCheckTimeout => '❌ Fehler: Die Verbindungsprüfung hat zu lange gedauert.';
	@override String get contextTooLong => '⚠️ Speicherlimit überschritten oder ungültige Anfrage. Die Unterhaltung ist möglicherweise zu lang oder komplex. Verwende das Papierkorb-Symbol oben, um den Chat zu löschen und neu zu starten.';
	@override String get noInternet => '❌ Fehler: Keine Internetverbindung. Prüfe dein Netzwerk.';
	@override String get serverTimeout => '❌ Fehler: Der Server braucht zu lange für die Antwort. Versuche es erneut.';
	@override String apiError({required Object code}) => '❌ API-Fehler: ${code} (Details in Sentry prüfen)';
}

/// The flat map containing all translations for locale <de>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsDe {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'auth.continuePrivately' => 'Privat auf diesem Mac fortfahren',
			'auth.signIn' => 'Anmelden',
			'auth.register' => 'Registrieren',
			'auth.or' => 'ODER',
			'auth.password' => 'Passwort',
			'auth.forgotPassword' => 'Passwort vergessen?',
			'auth.haveAccount' => 'Du hast bereits ein Konto?',
			'auth.noAccount' => 'Du hast kein Konto?',
			'auth.continueWithApple' => 'Mit Apple fortfahren',
			'auth.continueWithGoogle' => 'Mit Google fortfahren',
			'auth.readPrivacyPolicy' => 'Datenschutzerklärung lesen',
			'auth.nameLabel' => 'Vorname',
			'auth.invalidEmail' => 'Gib eine gültige E-Mail-Adresse ein',
			'auth.confirmEmail' => 'Prüfe deine E-Mail, um die Registrierung zu bestätigen.',
			'auth.resetSent' => 'E-Mail gesendet. Prüfe deinen Posteingang.',
			'auth.signInTitle' => 'Bei Evolve anmelden',
			'auth.signUpTitle' => 'Erstelle dein Konto',
			'auth.resetTitle' => 'Passwort wiederherstellen',
			'auth.emailLabel' => 'E-Mail',
			'auth.passwordMin8' => 'Verwende mindestens 8 Zeichen.',
			'auth.sendResetLink' => 'Wiederherstellungslink senden',
			'privateAi.consentTitle' => 'Senden an die KI erlauben',
			'privateAi.consentBody' => 'Im privaten Modus bleiben deine Daten auf deinem Gerät. Um den KI-Coach zu nutzen, werden die Gewohnheiten und Ziele, die du teilst, an einen externen KI-Anbieter (OpenRouter) gesendet. Möchtest du fortfahren?',
			'privateAi.cancel' => 'Abbrechen',
			'privateAi.accept' => 'Akzeptieren',
			'privateData.deleteTitle' => 'Private Daten löschen',
			'privateData.deleteMessage' => 'Möchtest du wirklich die gesamte verschlüsselte lokale Datenbank löschen? Dieser Vorgang ist unwiderruflich und die Daten können nicht wiederhergestellt werden.',
			'privateData.deleteSuccess' => 'Private Daten gelöscht.',
			'privateData.deleteFailed' => 'Vorgang fehlgeschlagen.',
			'privateData.exportDoneTitle' => 'Export abgeschlossen',
			'privateData.exportDoneClipboard' => 'Das JSON ist in der Zwischenablage: Linux unterstützt keine Dateifreigabe.',
			'privateData.exportDoneShare' => 'Das JSON wurde an die Teilen-Auswahl gesendet.',
			'namePrompt.title' => 'Wie heißt du?',
			'namePrompt.subtitle' => 'Gib deinen Namen ein, um das Dashboard zu personalisieren.',
			'namePrompt.hint' => 'z. B. Simo',
			'namePrompt.save' => 'Speichern und fortfahren',
			'nav.overview' => 'Übersicht',
			'nav.habits' => 'Gewohnheiten',
			'nav.insights' => 'Statistiken',
			'nav.goals' => 'Ziele',
			'nav.coach' => 'AI-Coach',
			'nav.settings' => 'Einstellungen',
			'shell.syncPending' => 'Sync ausstehend',
			'shell.syncing' => 'Synchronisierung',
			'shell.synced' => 'Synchronisiert',
			'shell.syncTooltip' => 'Synchronisieren',
			'shell.searchHint' => 'Suchen oder navigieren',
			'shell.searchSectionHint' => 'Abschnitt suchen...',
			'common.actions.cancel' => 'Abbrechen',
			'common.actions.save' => 'Speichern',
			'common.actions.delete' => 'Löschen',
			'common.actions.edit' => 'Bearbeiten',
			'common.months.0' => 'Januar',
			'common.months.1' => 'Februar',
			'common.months.2' => 'März',
			'common.months.3' => 'April',
			'common.months.4' => 'Mai',
			'common.months.5' => 'Juni',
			'common.months.6' => 'Juli',
			'common.months.7' => 'August',
			'common.months.8' => 'September',
			'common.months.9' => 'Oktober',
			'common.months.10' => 'November',
			'common.months.11' => 'Dezember',
			'common.weekdayInitials.0' => 'M',
			'common.weekdayInitials.1' => 'D',
			'common.weekdayInitials.2' => 'M',
			'common.weekdayInitials.3' => 'D',
			'common.weekdayInitials.4' => 'F',
			'common.weekdayInitials.5' => 'S',
			'common.weekdayInitials.6' => 'S',
			'common.calendarView.year' => 'Jahr',
			'common.calendarView.month' => 'Monat',
			'common.calendarView.week' => 'Woche',
			'common.calendarView.life' => 'Leben',
			'common.weekdaysLong.0' => 'Montag',
			'common.weekdaysLong.1' => 'Dienstag',
			'common.weekdaysLong.2' => 'Mittwoch',
			'common.weekdaysLong.3' => 'Donnerstag',
			'common.weekdaysLong.4' => 'Freitag',
			'common.weekdaysLong.5' => 'Samstag',
			'common.weekdaysLong.6' => 'Sonntag',
			'common.none' => 'Keiner',
			'common.habits' => 'Gewohnheiten',
			'common.status.error' => 'Fehler',
			'common.total' => 'Gesamt',
			'common.completed' => 'Abgeschlossen',
			'form.title' => 'Titel',
			'form.category' => 'Kategorie',
			'form.color' => 'Farbe',
			'form.add' => 'Hinzufügen',
			'createGoal.title' => 'Neues Ziel',
			'createGoal.subtitle' => 'Definiere deinen nächsten Meilenstein.',
			'createGoal.titleHint' => 'z. B. Das neue Produkt einführen',
			'createGoal.categoryHint' => 'z. B. Arbeit',
			'createGoal.timeline' => 'Zeitleiste',
			'createGoal.thisWeek' => 'Diese Woche',
			'createGoal.thisMonth' => 'Dieser Monat',
			'createGoal.thisQuarter' => 'Dieses Quartal',
			'createGoal.thisYear' => 'Dieses Jahr',
			'createGoal.longTerm' => 'Langfristig (Lifetime)',
			'createGoal.dueLifetime' => 'Ganzes Leben',
			'createGoal.dueByYear' => ({required Object year}) => 'Bis ${year}',
			'createGoal.defaultCategory' => 'Ziel',
			'createHabit.title' => 'Neue Gewohnheit',
			'createHabit.subtitle' => 'Definiere deine neue Gewohnheit.',
			'createHabit.titleHint' => 'z. B. Meditation',
			'createHabit.categoryHint' => 'z. B. Wohlbefinden',
			'createHabit.weeklyFrequency' => 'Wöchentliche Häufigkeit',
			'createHabit.defaultCategory' => 'Allgemein',
			'macroGoals.types.annual' => 'Jährlich',
			'macroGoals.types.quarterly' => 'Quartalsweise',
			'macroGoals.types.monthly' => 'Monatlich',
			'macroGoals.types.weekly' => 'Wöchentlich',
			'macroGoals.types.lifetime' => 'Lebenslang',
			'macroGoals.quarterNumber' => ({required Object quarter}) => 'Quartal ${quarter}',
			'macroGoals.addLifetimeGoal' => 'Lebenszeitziel hinzufügen...',
			'macroGoals.addAnnualGoal' => 'Jahresziel hinzufügen...',
			'macroGoals.addQuarterlyGoal' => 'Vierteljährliches Ziel hinzufügen...',
			'macroGoals.addMonthlyGoal' => 'Monatsziel hinzufügen...',
			'macroGoals.addWeeklyGoal' => 'Wöchentliches Ziel hinzufügen...',
			'macroGoals.completed' => 'VOLLENDET',
			'macroGoals.failed' => 'FEHLGESCHLAGEN',
			'macroGoals.create' => 'Erstellen',
			'macroGoals.strength' => 'Stärke',
			'macroGoals.bestMonth' => 'Bester Monat',
			'macroGoals.successRate2' => 'Erfolgsquote',
			'macroGoals.effectiveType' => 'Effektiver Typ',
			'macroGoals.historicalTotal' => 'Historische Summe',
			'macroGoals.from_' => 'aus',
			'macroGoals.globalSuccess' => 'Gesamterfolg',
			'macroGoals.completedGoals' => 'Abgeschlossene Ziele',
			'macroGoals.bestYear' => 'Bestes Jahr',
			'macroGoals.mostProductiveYear' => 'Produktivstes Jahr',
			'macroGoals.totalGoals' => 'Ziele gesamt',
			'macroGoals.allYears' => 'Alle Jahre',
			'macroGoals.selectYearHeader' => 'Jahr auswählen',
			'macroGoals.completions' => 'Abschlüsse',
			'macroGoals.success2' => 'Erfolg',
			'statistics.completed2' => 'Abgeschlossen',
			'statistics.notCompleted' => 'Nicht abgeschlossen',
			'statistics.ofCompletion' => 'Abschluss',
			'statistics.growth' => 'Wachstum',
			'statistics.decline' => 'Rückgang',
			'statistics.strongestDay' => 'Stärkster Tag',
			'statistics.weakestDay' => 'Schwächster Tag',
			'statistics.worstNegativeStreak' => 'Schlechteste negative Serie',
			'statistics.missedConsecutiveDays' => 'aufeinanderfolgende verpasste Tage',
			'statistics.brokenStreaks' => 'Unterbrochene Serien',
			'statistics.noBrokenStreaks' => 'Keine unterbrochenen Serien erfasst',
			'statistics.startedOn' => 'begonnen am',
			'statistics.moodCorrelation' => 'Stimmungskorrelation',
			'statistics.avgMood' => 'Durchschn. Stimmung (✓)',
			'statistics.avgEnergy' => 'Durchschn. Energie (✓)',
			'statistics.onCompletedDays' => 'an erledigten Tagen',
			'statistics.resilient' => 'Resilient',
			'statistics.completedVsMissed' => 'Abgeschlossen vs. verpasst',
			'statistics.mood2' => 'Stimmung',
			'statistics.energy' => 'Energie',
			'statistics.performancePerLevel' => 'Leistung nach Niveau',
			'statistics.withHighMood' => 'Bei guter Stimmung',
			'statistics.withLowMood' => 'Bei schlechter Stimmung',
			'statistics.moodEnergyAnalysis' => 'Die Analyse zeigt, wie deine Beständigkeit von Stimmung und Energie beeinflusst wird.',
			'statistics.missed2' => 'Verpasst',
			'statistics.positive' => 'positiv',
			'statistics.neutral' => 'neutral',
			'statistics.high' => 'hoch',
			'statistics.low' => 'niedrig',
			'statistics.skipped' => 'Übersprungen',
			'statistics.criticalHabits' => 'Kritische Gewohnheiten',
			'statistics.bestHabitsTitle' => 'Beste Gewohnheiten',
			'statistics.worseningHabitsDescription' => 'Gewohnheiten, die sich verschlechtern.',
			'statistics.everythingIsGreat' => 'Alles läuft gut',
			'statistics.allHabitsStableDescription' => 'Alle deine Gewohnheiten halten oder verbessern ihren Trend. Weiter so.',
			'statistics.habitCompletionPeriodDescription' => ({required Object rate}) => 'Du hast diese Gewohnheit im ausgewählten Zeitraum zu ${rate}% abgeschlossen.',
			'statistics.habitLostConsistencyDescription' => ({required Object drop}) => 'Diese Gewohnheit hat in der letzten Woche gegenüber der vorherigen ${drop}% Konstanz verloren.',
			'statistics.negativeStreak' => 'Negative Serie',
			'statistics.currentStreak2' => 'Aktuelle Serie',
			'statistics.improvementAreas' => 'Verbesserungsbereiche',
			'statistics.habitsRequiringMoreAttention' => 'Gewohnheiten, die mehr Aufmerksamkeit erfordern.',
			'statistics.failureAnalysis' => 'Fehleranalyse',
			'statistics.missedDaysPattern' => 'Häufigkeit und Muster deiner verpassten Tage.',
			'statistics.recoveryPatterns' => 'Erholungsmuster',
			'statistics.recoverySpeed' => 'Wie schnell du nach einem Ausrutscher wieder auf Kurs kommst.',
			'statistics.avgRecoveryTime' => 'Durchschnittliche Erholungszeit',
			'statistics.worstStreak' => 'Schlechteste Serie',
			'statistics.frequency' => 'HÄUFIGKEIT',
			'statistics.daysShortUnit' => 'T',
			'statistics.perMonthUnit' => 'Monat',
			'statistics.succ' => 'Erfolg',
			'statistics.blackDay' => 'KRITISCHER TAG',
			'statistics.correlationsWith' => 'Korrelationen mit',
			'statistics.howThisHabitRelatesToOthers' => 'Wie diese Gewohnheit mit den anderen zusammenhängt',
			'statistics.positiveCorrelations' => 'Positive Korrelationen',
			'statistics.negativeCorrelations' => 'Negative Korrelationen',
			'statistics.noSignificantPositiveCorrelation' => 'Keine signifikante positive Korrelation',
			'statistics.noSignificantNegativeCorrelation' => 'Keine signifikante negative Korrelation',
			'statistics.habitTogetherPercent' => ({required Object percentage}) => '${percentage}% zusammen',
			'statistics.habitPositiveCorrelationDescription' => ({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'Wenn du "${currentGoal}" abschließt, hast du eine Wahrscheinlichkeit von ${percentage}%, auch "${otherGoal}" abzuschließen.',
			'statistics.habitNegativeCorrelationDescription' => ({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'Wenn du "${currentGoal}" abschließt, hast du nur eine Wahrscheinlichkeit von ${percentage}%, auch "${otherGoal}" abzuschließen.',
			'statistics.weeklyTrend' => 'Wöchentlicher Trend',
			'statistics.monthlyTrend' => 'Monatlicher Trend',
			'statistics.yearlyTrend' => 'Jährlicher Trend',
			'statistics.performanceEvolution' => 'Leistungsentwicklung',
			'statistics.globalTrend' => 'Globaler Trend',
			'statistics.total' => 'Gesamt',
			'statistics.all' => 'Alles',
			'statistics.noDataForAlerts' => 'Nicht genügend Daten, um Warnungen zu erzeugen.',
			'statistics.missed' => 'Verpasst',
			'goalState.active' => 'In Bearbeitung',
			'dueLabel.lifetime' => 'Lebensziel',
			'dueLabel.annual' => 'Jahresziel',
			'dueLabel.quarter' => 'Quartal',
			'dashboard.mood' => 'Stimmung',
			'dashboard.energy' => 'Energie',
			'dashboard.goodMorning' => 'Guten Morgen',
			'dashboard.consecutiveDays' => 'aufeinanderfolgende Tage',
			'dashboard.welcomeTitle' => 'Willkommen bei Evolve',
			'dashboard.welcomeSubtitle' => 'Beginne deine persönliche Wachstumsreise.',
			'dashboard.welcomeBody' => 'Diese App hilft dir, gute Gewohnheiten aufzubauen und deine langfristigen Ziele zu erreichen.',
			'dashboard.welcomeStart' => 'Loslegen',
			'dashboard.subtitle' => 'Halte das Tempo. Jede kleine Handlung stärkt die Person, die du wirst.',
			'dashboard.completionToday' => 'Heutiger Abschluss',
			'dashboard.habitsCount' => ({required Object done, required Object total}) => '${done}/${total} Gewohnheiten',
			'dashboard.bestStreak' => 'Beste Serie',
			'dashboard.activeGoals' => 'Aktive Ziele',
			'dashboard.avgProgress' => ({required Object pct}) => '${pct}% durchschnittlicher Fortschritt',
			'dashboard.momentum' => 'Momentum',
			'dashboard.vsLastWeek' => 'gegenüber letzter Woche',
			'dashboard.weeklyTrend' => 'Wochentrend',
			'dashboard.weeklyTrendSubtitle' => 'Abschlussrate deiner Gewohnheiten',
			'dashboard.thisWeekPill' => ({required Object value}) => '${value} diese Woche',
			'dashboard.todayProtocol' => 'Heutiges Protokoll',
			'dashboard.todayProtocolSubtitle' => 'Erledige die wesentlichen Aktionen, bevor du weitere hinzufügst',
			'dashboard.actionsCount' => ({required Object count}) => '${count} Aktionen',
			'dashboard.emptyHabits' => 'Deine Leinwand ist leer. Erstelle deine erste Gewohnheit.',
			'dashboard.streakDaysShort' => ({required Object n}) => '${n} T',
			'dashboard.checkInDone' => 'Check-in erfasst',
			'dashboard.checkInPrompt' => 'Wie fühlst du dich heute?',
			'dashboard.moodEnergyValue' => ({required Object mood, required Object energy}) => 'Stimmung ${mood}/10 · Energie ${energy}/10',
			'dashboard.checkInHint' => 'Erfasse Stimmung und Energie, um deine Musteranalyse zu verbessern.',
			'dashboard.updateCheckIn' => 'Check-in aktualisieren',
			'dashboard.doCheckIn' => 'Check-in machen',
			'dashboard.dailyCheckIn' => 'Täglicher Check-in',
			'dashboard.dailyCheckInSubtitle' => 'Eine kurze Erfassung hilft Evolve, deine Muster besser zu verstehen.',
			'dashboard.record' => 'Speichern',
			'dashboard.focusGoals' => 'Ziele im Fokus',
			'dashboard.currentPriorities' => 'Aktuelle Prioritäten',
			'dashboard.goalLimitReached' => 'Limit von 100 Zielen erreicht. Wechsle zu Pro, um mehr zu erstellen.',
			'dashboard.emptyFocusGoals' => 'Keine Ziele im Fokus. Füge eines hinzu.',
			'dashboard.weekToStart' => 'Woche zum Starten',
			'dashboard.weekGrowing' => 'Woche im Aufwind',
			'dashboard.weekToRecover' => 'Woche zum Aufholen',
			'dashboard.vsPreviousWeek' => ({required Object value}) => '${value} gegenüber der Vorwoche.',
			'stats.title' => 'Statistiken',
			'stats.global' => 'Global',
			'stats.resilience' => 'Widerstandsfähigkeit',
			'stats.tabHabits' => 'Gewohnheiten',
			'stats.tabMood' => 'Stimmung',
			'stats.last30Days' => 'Letzte 30 Tage',
			'stats.singleHabit' => 'Einzelne Gewohnheit',
			'stats.noHabit' => 'Keine Gewohnheit',
			'stats.completionToday' => 'Heutiger Abschluss',
			'stats.bestStreakLabel' => 'Beste Serie',
			'stats.criticalDay' => 'Kritischer Tag',
			'stats.completePrioritiesFirst' => 'Erledige zuerst die Prioritäten',
			'stats.recentActivity' => 'Letzte Aktivität',
			'stats.recentActivitySubtitle' => 'Abschlussintensität der letzten 90 Tage',
			'stats.trendGlobal' => 'Globaler Trend',
			'stats.trendGlobalSubtitle' => 'Zeitlicher Vergleich des Protokolls',
			'stats.vsPrevDay' => ({required Object value}) => '${value}% ggü. Vortag',
			'stats.bestHabit' => 'Beste Gewohnheit',
			'stats.criticalArea' => 'Kritischer Bereich',
			'stats.streakAtRisk' => 'Serie in Gefahr',
			'stats.streakAtRiskDetail' => ({required Object habit}) => '${habit} braucht Aufmerksamkeit bei den nächsten Check-ins.',
			'stats.patternToConsolidate' => 'Muster zum Festigen',
			'stats.checkLowMoodDays' => 'Prüfe Tage mit schlechter Stimmung und halte das Kernprotokoll ein.',
			'stats.goalDue' => 'Ziel läuft bald ab',
			'stats.noGoalNeedsIntervention' => 'Kein aktives Ziel erfordert Eingreifen.',
			'stats.performancePerHabit' => 'Leistung pro Gewohnheit',
			'stats.performancePerHabitSubtitle' => 'Rangliste aus synchronisierten Logs nach wöchentlicher Konstanz',
			'stats.avgMood' => 'Durchschnittliche Stimmung',
			'stats.avgEnergy' => 'Durchschnittliche Energie',
			'stats.checkInsAvailable' => ({required Object count}) => '${count} Check-ins verfügbar',
			'stats.resilientHabit' => 'Resiliente Gewohnheit',
			'stats.completedEvenHardDays' => 'Auch an schwierigen Tagen erledigt',
			'stats.moodEnergy' => 'Stimmung und Energie',
			'stats.moodEnergySubtitle' => 'Durchschnitt der verfügbaren Check-ins der letzten 90 Tage',
			'stats.completion' => 'Abschluss',
			'stats.currentWeek' => 'Aktuelle Woche',
			'stats.currentStreak' => 'Aktuelle Serie',
			'stats.currentStreakDetail' => 'Serie aus verfügbaren Logs synchronisiert',
			'stats.trend30' => '30-Tage-Trend',
			'stats.trend30Detail' => 'Abschluss der letzten 30 Tage',
			'stats.yearlyCalendar' => 'Jahreskalender',
			'stats.yearlyCalendarSubtitle' => ({required Object habit}) => 'Verteilung der Abschlüsse von ${habit}',
			'stats.performancePerDay' => 'Leistung pro Tag',
			'stats.performancePerDaySubtitle' => 'Starke und schwache Wochentage',
			'stats.protectStreak' => ({required Object days}) => 'Schütze die ${days}-Tage-Serie',
			'stats.keepSameSlot' => 'Behalte denselben Zeitraum bei, um an intensiven Tagen Reibung zu verringern.',
			'stats.worstNegativeSeq' => ({required Object days}) => 'Die schlimmste Negativserie dauerte ${days} Tage.',
			'stats.positiveLever' => 'Positiver Hebel erkannt',
			'stats.bestHabitRegularity' => ({required Object habit}) => '${habit} hält die beste jüngste Regelmäßigkeit.',
			'stats.moodSensitivity' => 'Stimmungsempfindlichkeit',
			'stats.lowEnergyCompletion' => 'Abschluss bei niedriger Energie',
			'stats.moodOutputCorrelation' => 'Korrelation Stimmung-Leistung',
			'stats.moodOutputSubtitle' => 'Verfügbare Abschlüsse an Check-in-Tagen',
			'stats.keyCorrelations' => 'Wichtige Korrelationen',
			'stats.keyCorrelationsSubtitle' => 'Muster mit dem größten Einfluss auf das Protokoll',
			'stats.moreLogsNeeded' => 'Es werden mehr Logs benötigt, um nützliche Korrelationen zu berechnen.',
			'stats.createHabitForAnalysis' => 'Erstelle mindestens eine Gewohnheit, um die detaillierte Analyse zu sehen.',
			'stats.noData' => 'Keine Daten',
			'stats.tabInfo' => 'Info',
			'stats.tabTrend' => 'Trend',
			'stats.tabAlerts' => 'Warnungen',
			'stats.tabOverview' => 'Übersicht',
			'stats.tabCalendar' => 'Kalender',
			'stats.tabPerformance' => 'Leistung',
			'stats.tabImprovement' => 'Verbesserung',
			'stats.pageSubtitle' => 'Erkenne die Muster, die Wachstum fördern, und handle bei kritischen Bereichen.',
			'stats.actionsFraction' => ({required Object done, required Object total}) => '${done}/${total} Aktionen',
			'stats.affectedByHardDays' => ({required Object habit}) => '${habit} leidet an schwierigen Tagen',
			'stats.last30DaysTrend' => 'Trend der letzten 30 Tage',
			'stats.strongestDayDetail' => ({required Object pct, required Object done, required Object total}) => 'Gut gemacht, ${pct}% Abschluss (${done}/${total})',
			'stats.weakestDayDetail' => ({required Object pct, required Object done, required Object total}) => 'Nur ${pct}% Abschluss (${done}/${total})',
			'stats.brokenStreakItem' => ({required Object days}) => 'Serie von ${days} Tagen unterbrochen',
			'stats.togetherProbability' => ({required Object percentage}) => '${percentage}% zusammen',
			'stats.criticalHabitsSubtitle' => 'Gewohnheiten, die sich verschlechtern.',
			'stats.bestHabitsSubtitle' => 'Die Gewohnheiten, bei denen du am bestandigsten bist.',
			'stats.timeframeWeek' => 'Woche',
			'stats.timeframeMonth' => 'Monat',
			'stats.timeframeYear' => 'Jahr',
			'stats.timeframeAll' => 'Alles',
			'stats.negativeStreakDays' => ({required Object days}) => '${days} Tage ohne Abschluss',
			'stats.dropPercent' => ({required Object drop}) => '-${drop}%',
			'stats.blackDayDetail' => ({required Object day}) => 'Schwarzer Tag: ${day}',
			'stats.failureDetail' => ({required Object streak, required Object frequency}) => 'Schlimmste Serie: ${streak}T · ~${frequency}/Monat verpasst',
			'stats.recoveryDetail' => ({required Object days}) => 'Durchschnittliche Erholungszeit: ${days} Tage',
			'stats.successRate' => ({required Object rate}) => '${rate}% Erfolg',
			'habitsPage.today' => 'Heute',
			'habitsPage.subtitle' => 'Baue dein tägliches Protokoll auf und beobachte die Konstanz im Zeitverlauf.',
			'habitsPage.tabProtocol' => 'Protokoll',
			'habitsPage.tabCalendar' => 'Kalender',
			'habitsPage.deleteHabitTitle' => 'Gewohnheit löschen',
			'habitsPage.deleteHabitConfirm' => ({required Object title}) => '„${title}“ aus dem Protokoll entfernen?',
			'habitsPage.activeProtocol' => 'Aktives Protokoll',
			'habitsPage.completedToday' => 'Heute erledigt',
			'habitsPage.dailyProtocol' => 'Tägliches Protokoll',
			'habitsPage.protocolSubtitle' => 'Wochenübersicht, Erinnerungen und Schnellaktionen',
			'habitsPage.colHabit' => 'GEWOHNHEIT',
			'habitsPage.colStreak' => 'SERIE',
			'habitsPage.colLast7Days' => 'LETZTE 7 TAGE',
			'habitsPage.colReminder' => 'ERINNERUNG',
			'habitsPage.streakDays' => ({required Object n}) => '${n} Tage',
			'habitsPage.prevPeriod' => 'Vorheriger Zeitraum',
			'habitsPage.nextPeriod' => 'Nächster Zeitraum',
			'habitsPage.weekdayAbbrevUpper.0' => 'MO',
			'habitsPage.weekdayAbbrevUpper.1' => 'DI',
			'habitsPage.weekdayAbbrevUpper.2' => 'MI',
			'habitsPage.weekdayAbbrevUpper.3' => 'DO',
			'habitsPage.weekdayAbbrevUpper.4' => 'FR',
			'habitsPage.weekdayAbbrevUpper.5' => 'SA',
			'habitsPage.weekdayAbbrevUpper.6' => 'SO',
			'habitsPage.lifeView' => 'Lebensansicht',
			'habitsPage.lifeViewSubtitle' => 'Eine Zelle steht für einen Monat des Weges bis zum Alter von 85.',
			'habitsPage.monthsLived' => 'Gelebte Monate',
			'habitsPage.currentAge' => 'Aktuelles Alter',
			'habitsPage.monthsRemaining' => 'Verbleibende Monate',
			'habitsPage.dayDetail' => ({required Object day, required Object month}) => 'Details ${day}. ${month}',
			'habitsPage.dayDetailSubtitle' => 'Aktualisiere den Status der Gewohnheiten für diesen Tag.',
			'habitsPage.editHabit' => 'Gewohnheit bearbeiten',
			'habitsPage.newHabit' => 'Neue Gewohnheit',
			'habitsPage.optionalReminder' => 'Optionale Erinnerung',
			'habitsPage.reminderHint' => 'z. B. 08:30',
			'habitsPage.close' => 'Schließen',
			'habitsPage.statusDone' => ({required Object category}) => '${category} · Erledigt',
			'habitsPage.statusSkipped' => ({required Object category}) => '${category} · Übersprungen',
			'habitsPage.statusUnrecorded' => ({required Object category}) => '${category} · Nicht erfasst',
			'habitsPage.weekOf' => ({required Object day, required Object month}) => 'Woche vom ${day}. ${month}',
			'habitsPage.lifeWeeks' => 'Wochen deines Weges',
			'habitsPage.catWellness' => 'Wohlbefinden',
			'habitsPage.catProductivity' => 'Produktivität',
			'habitsPage.catEducation' => 'Bildung',
			'habitsPage.catHealth' => 'Gesundheit',
			'habitsPage.catMindfulness' => 'Achtsamkeit',
			'lavoro' => 'Arbeit',
			'salute' => 'Gesundheit',
			'finanza' => 'Finanzen',
			'relazioni' => 'Beziehungen',
			'formazione' => 'Bildung',
			'hobby' => 'Hobby',
			'spirituale' => 'Spiritualität',
			'altro' => 'Sonstiges',
			'goalsPage.title' => 'Makroziele',
			'goalsPage.subtitle' => 'Langfristige Planung.',
			'goalsPage.sampleGoal' => 'Beispielziel',
			'goalsPage.periodLifetime' => 'Lebensziele',
			'goalsPage.subtitleLifetime' => 'Lebenslange Ziele',
			'goalsPage.subtitleAnnual' => 'Jahresziele',
			'goalsPage.subtitleQuarterly' => 'Quartalsziele',
			'goalsPage.subtitleMonthly' => 'Monatsziele',
			'goalsPage.subtitleWeekly' => 'Wochenziele',
			'goalsPage.statsTab' => 'Stats',
			'goalsPage.fullView' => 'Vollständige Ansicht',
			'goalsPage.categoriesTitle' => 'Zielkategorien',
			'goalsPage.defaultPill' => 'Standard',
			'goalsPage.editCategory' => 'Kategorie bearbeiten',
			'goalsPage.archiveCategory' => 'Kategorie archivieren',
			'goalsPage.categoryCreateFailed' => 'Kategorie konnte nicht erstellt werden.',
			'goalsPage.categoryArchiveFailed' => 'Kategorie konnte nicht archiviert werden.',
			'goalsPage.categoryEditFailed' => 'Kategorie konnte nicht bearbeitet werden.',
			'goalsPage.addCategory' => 'Kategorie hinzufügen',
			'goalsPage.back' => 'Zurück',
			'goalsPage.finish' => 'Fertig',
			'goalsPage.next' => 'Weiter',
			'goalsPage.categoriesTooltip' => 'Kategorien',
			'goalsPage.rescheduleTooltip' => 'Auf nächsten Zeitraum verschieben',
			'goalsPage.defaultCategory' => 'Standard',
			'goalsPage.emptyActive' => 'Kein aktives Ziel in diesem Zeitraum.',
			'goalsPage.emptyAdd' => 'Füge das erste Ziel für diesen Zeitraum hinzu.',
			'goalsPage.newGoal' => 'Neues Ziel',
			'goalsPage.editGoal' => 'Ziel bearbeiten',
			'goalsPage.horizonLabel' => 'Horizont',
			'goalsPage.newCategory' => 'Neue Kategorie',
			'goalsPage.nameLabel' => 'Name',
			'goalsPage.weekPeriodLabel' => ({required Object week, required Object month, required Object year}) => 'Woche ${week}, ${month} ${year}',
			'goalsPage.currentQuarter' => 'Aktuelles Quartal',
			'goalsPage.currentMonth' => 'Aktueller Monat',
			'goalsPage.tutPlanningTitle' => 'Planungstyp',
			'goalsPage.tutPlanningDesc' => 'Hier kannst du den Zeithorizont deiner Ziele auswählen.',
			'goalsPage.tutNewGoalDesc' => 'Von hier aus kannst du schnell ein neues Ziel hinzufügen.',
			'goalsPage.tutCompleteTitle' => 'Abschließen oder scheitern',
			'goalsPage.tutCompleteDesc' => 'Markiere das Ziel mit einem Klick als abgeschlossen oder gescheitert.',
			'goalsPage.tutCategoryDesc' => 'Verwalte Kategorien und verknüpfe sie mit deinen Zielen.',
			'goalsPage.tutRescheduleTitle' => 'Verschieben',
			'goalsPage.tutRescheduleDesc' => 'Verschiebe das Ziel in den nächsten Zeitraum, wenn du es nicht abschließen konntest.',
			'goalsPage.tutEditDesc' => 'Bearbeite die Details deines Ziels.',
			'goalsPage.tutDeleteDesc' => 'Lösche ein Ziel, wenn es nicht mehr relevant ist.',
			'goalsPage.tutStatsTitle' => 'Analyse und Statistiken',
			'goalsPage.tutStatsDesc' => 'Wechsle zur Statistikansicht, um deine Leistung im Zeitverlauf zu analysieren.',
			'goalsStats.proRequired' => 'Pro-Funktion erforderlich',
			'goalsStats.active' => 'Aktiv',
			'goalsStats.failed' => 'Gescheitert',
			'goalsStats.complAbbr' => 'Abg.',
			'goalsStats.seasonality' => 'Saisonalität',
			'goalsStats.interestEvolution' => 'Interessenentwicklung',
			'ai.coach' => 'AI-Coach',
			'ai.dailyHabits' => 'Tägliche Gewohnheiten',
			'ai.macroGoals' => 'Makroziele',
			'ai.openRouter.apiKeyMissingFull' => '⚠️ Fehler: Der OpenRouter-API-Schlüssel ist nicht konfiguriert.\n\nFüge deinen API-Schlüssel in `lib/core/openrouter_config.dart` hinzu.',
			'ai.openRouter.apiKeyMissingShort' => '⚠️ Fehler: Der OpenRouter-API-Schlüssel ist nicht konfiguriert.',
			'ai.openRouter.defaultSystemPrompt' => 'Du bist der "Discipline Coach", ein virtueller Assistent, der dem Nutzer hilft, diszipliniert zu bleiben, Ziele zu erreichen und gesunde Gewohnheiten aufzubauen. Sei motivierend, aber konkret, direkt und praktisch. Verwende einen professionellen, aber freundlichen Ton.',
			'ai.openRouter.communicationError' => ({required Object code}) => '❌ Fehler bei der Kommunikation mit der AI. (Code: ${code})',
			'ai.openRouter.connectionError' => '❌ Verbindungsfehler. Stelle sicher, dass du online bist, und versuche es erneut.',
			'ai.openRouter.connectionErrorShort' => '❌ Verbindungsfehler.',
			'ai.openRouter.connectionCheckTimeout' => '❌ Fehler: Die Verbindungsprüfung hat zu lange gedauert.',
			'ai.openRouter.contextTooLong' => '⚠️ Speicherlimit überschritten oder ungültige Anfrage. Die Unterhaltung ist möglicherweise zu lang oder komplex. Verwende das Papierkorb-Symbol oben, um den Chat zu löschen und neu zu starten.',
			'ai.openRouter.noInternet' => '❌ Fehler: Keine Internetverbindung. Prüfe dein Netzwerk.',
			'ai.openRouter.serverTimeout' => '❌ Fehler: Der Server braucht zu lange für die Antwort. Versuche es erneut.',
			'ai.openRouter.apiError' => ({required Object code}) => '❌ API-Fehler: ${code} (Details in Sentry prüfen)',
			'aiCoach.greeting' => 'Hallo! Ich bin Evolve AI Coach. Ich helfe dir, dein Protokoll zu optimieren und deine Ziele zu erreichen. Wie kann ich dir heute helfen?',
			'aiCoach.systemPersona' => 'Du bist Evolve AI Coach, ein virtueller Assistent für persönliche Disziplin.',
			'aiCoach.habitsHeader' => 'AKTIVE GEWOHNHEITEN:',
			'aiCoach.noActiveHabits' => 'Keine aktiven Gewohnheiten.',
			'aiCoach.habitLine' => ({required Object title, required Object done, required Object streak}) => '${title} (Heute erledigt: ${done}, Serie: ${streak})',
			'aiCoach.goalsHeader' => 'ZIELE:',
			'aiCoach.noActiveGoals' => 'Keine aktiven langfristigen Ziele.',
			'aiCoach.goalLine' => ({required Object title, required Object due}) => '${title} (Fällig: ${due})',
			'aiCoach.contextTitle' => 'KI-Kontext',
			'aiCoach.contextBody' => 'Wähle, welche Daten du mit dem KI-Coach teilst, um personalisierte Ratschläge zu erhalten.',
			'aiCoach.shareHabitsDesc' => 'Teilt deine aktiven Gewohnheiten, Serien und den heutigen Abschlussstatus.',
			'aiCoach.shareGoalsDesc' => 'Teilt deine aktiven langfristigen Ziele.',
			'aiCoach.saveClose' => 'Speichern und schließen',
			'aiCoach.subtitle' => 'Analysiere Muster mit einem kontextbezogenen Coach auf Basis deiner Reisedaten.',
			'aiCoach.contextButton' => 'Kontext',
			'aiCoach.typing' => 'AI Coach schreibt...',
			'aiCoach.inputHint' => 'Frag deinen Coach um Rat...',
			'settingsPage.account' => 'Konto',
			'settingsPage.notifications' => 'Benachrichtigungen',
			'settingsPage.language' => 'Sprache',
			'settingsPage.timeFormat24h' => '24-Stunden-Format',
			'settingsPage.subscription' => 'Abonnement',
			'settingsPage.proName' => 'Evolve PRO',
			'settingsPage.planMonthly' => 'Monatlich',
			'settingsPage.planAnnual' => 'Jährlich',
			'settingsPage.restorePurchases' => 'Käufe wiederherstellen',
			'settingsPage.deletePrivateData' => 'private Daten löschen',
			'settingsPage.importInProgress' => 'Daten werden importiert...',
			'settingsPage.passwordsDontMatch' => 'Die Passwörter stimmen nicht überein',
			'settingsPage.email' => 'E-Mail',
			'settingsPage.cancel' => 'Abbrechen',
			'settingsPage.confirm' => 'Bestätigen',
			'settingsPage.save' => 'Speichern',
			'settingsPage.pageTitle' => 'Einstellungen',
			'settingsPage.pageSubtitle' => 'Verwalte dein Profil, das Desktop-Verhalten, den Datenschutz und den Evolve-Plan.',
			'settingsPage.profileLabel' => 'Profil',
			'settingsPage.profileSubtitle' => 'Persönliche Informationen und Synchronisierungsstatus',
			'settingsPage.accountAndOnboarding' => 'Konto und Onboarding',
			'settingsPage.privateMode' => 'Privater Modus',
			'settingsPage.sessionUnavailable' => 'Sitzung nicht verfügbar',
			'settingsPage.dataRepository' => 'Daten-Repository',
			'settingsPage.encryptedLocalDatabase' => 'Verschlüsselte lokale Datenbank',
			'settingsPage.supabaseWithEncryptedCache' => 'Supabase mit verschlüsseltem Cache',
			'settingsPage.personalInfo' => 'Persönliche Informationen',
			'settingsPage.personalInfoDetail' => 'Vorname, Nachname, E-Mail und Geburtsdatum',
			'settingsPage.updateAvatar' => 'Avatar aktualisieren',
			'settingsPage.updateAvatarDetail' => 'Wähle ein lokales Bild für das Desktop-Profil.',
			'settingsPage.reviewInitialConsent' => 'Erstzustimmung überprüfen',
			'settingsPage.reviewInitialConsentDetail' => 'Bedingungen, Datenschutz, Benachrichtigungen und Absturzberichte',
			'settingsPage.signOut' => 'Vom Konto abmelden',
			'settingsPage.signOutDetailActive' => 'Die Sitzung auf diesem Gerät schließen',
			'settingsPage.availableWithActiveSession' => 'Verfügbar mit einer aktiven Supabase-Sitzung',
			_ => null,
		} ?? switch (path) {
			'settingsPage.goToLogin' => 'Zur Anmeldung',
			'settingsPage.goToLoginDetail' => 'Setze den privaten Modus aus und melde dich bei Supabase an.',
			'settingsPage.appearanceTitle' => 'Erscheinungsbild und Anwendung',
			'settingsPage.appearanceSubtitle' => 'Lokale Einstellungen, an den Desktop angepasst',
			'settingsPage.appearanceAndVisual' => 'Erscheinungsbild und Optik',
			'settingsPage.darkMode' => 'Dunkler Modus',
			'settingsPage.darkModeDetail' => 'Verwende das schwarz-weiße dunkle Design.',
			'settingsPage.calendarExperienceLanguage' => 'Kalender, Erlebnis und Sprache',
			'settingsPage.accentColor' => 'Akzentfarbe',
			'settingsPage.accentColorDetail' => 'Erweiterte Palette, reserviert für Evolve Pro.',
			'settingsPage.defaultCalendarView' => 'Standard-Kalenderansicht',
			'settingsPage.timeFormat24hDetail' => 'Verwende Uhrzeiten wie 20:30 statt 8:30 PM.',
			'settingsPage.hapticFeedback' => 'Haptisches Feedback',
			'settingsPage.hapticFeedbackDetail' => 'Der Desktop behält die Einstellung bei, erzeugt aber keine Vibrationen.',
			'settingsPage.resetTutorial' => 'Tutorial zurücksetzen',
			'settingsPage.resetTutorialDetail' => 'Öffnet die Schritt-für-Schritt-Anleitungen für Dashboard und Ziele erneut.',
			'settingsPage.notificationsSubtitle' => 'Betriebshinweise des Desktop-Clients',
			'settingsPage.operationalReminders' => 'Betriebshinweise',
			'settingsPage.habitReminders' => 'Gewohnheitserinnerungen',
			'settingsPage.habitRemindersDetail' => 'Sendet das tägliche Morgenbriefing.',
			'settingsPage.morningBriefTime' => 'Uhrzeit des Morgenbriefings',
			'settingsPage.eveningReview' => 'Abendliche Rückschau',
			'settingsPage.eveningReviewDetail' => 'Erinnert dich daran, deinen Tag zu festigen.',
			'settingsPage.eveningReviewTime' => 'Uhrzeit der abendlichen Rückschau',
			'settingsPage.requestNotificationPermissions' => 'Benachrichtigungsberechtigungen anfordern',
			'settingsPage.requestNotificationPermissionsDetail' => 'Öffnet die native Eingabeaufforderung auf der unterstützten Plattform.',
			'settingsPage.nativeDeliveryTitle' => 'Native Zustellung je nach Betriebssystem',
			'settingsPage.privacyTitle' => 'Datenschutz und Sicherheit',
			'settingsPage.privacySubtitle' => 'Zugriffsschutz, Einwilligungen und Datenverwaltung',
			'settingsPage.accessProtection' => 'Zugriffsschutz',
			'settingsPage.biometricLock' => 'Biometrische Sperre',
			'settingsPage.biometricLockDetail' => 'Verfügbar mit dem nativen Adapter unter macOS und Windows; unter Linux nicht unterstützt.',
			'settingsPage.changePassword' => 'Passwort ändern',
			'settingsPage.changePasswordDetail' => 'Aktualisierung der Anmeldedaten über Supabase Auth.',
			'settingsPage.dataAndConsents' => 'Daten und Einwilligungen',
			'settingsPage.sendCrashReports' => 'Absturzberichte senden',
			'settingsPage.sendCrashReportsDetail' => 'Gesonderte Einwilligung für Sentry.',
			'settingsPage.exportData' => 'Daten exportieren',
			'settingsPage.exportDataDetail' => 'Teilt einen vollständigen JSON-Export der verfügbaren Daten.',
			'settingsPage.importData' => 'Daten importieren',
			'settingsPage.importDataDetail' => 'Stellt ein Backup (.zip-Format) von Evolve wieder her.',
			'settingsPage.systemPermissionsManagement' => 'Verwaltung der Systemberechtigungen',
			'settingsPage.systemPermissionsManagementDetail' => 'Benachrichtigungen, Kalender und Sicherheit.',
			'settingsPage.deletePrivateDataDetail' => 'Löscht die verschlüsselte lokale Datenbank dauerhaft.',
			'settingsPage.deleteAccountAndData' => 'Konto und Daten löschen',
			'settingsPage.deleteAccountAndDataDetail' => 'Unwiderruflicher Vorgang, durch Bestätigung geschützt.',
			'settingsPage.exportPrivateShareText' => 'Meine privaten Daten, exportiert aus Evolve',
			'settingsPage.exportShareText' => 'Meine aus Evolve exportierten Daten',
			'settingsPage.exportDoneTitle' => 'Export abgeschlossen',
			'settingsPage.exportDoneClipboard' => 'Das JSON ist in der Zwischenablage: Linux unterstützt keine Dateifreigabe.',
			'settingsPage.exportDoneShare' => 'Das JSON wurde an die Freigabeauswahl gesendet.',
			'settingsPage.avatarGateTitle' => 'Avatar',
			'settingsPage.avatarPickFailed' => 'Bildauswahl fehlgeschlagen.',
			'settingsPage.confirmSignOutTitle' => 'Abmeldung bestätigen',
			'settingsPage.confirmSignOutMessage' => 'Möchtest du dich wirklich abmelden? Du musst deine Anmeldedaten erneut eingeben, um dich wieder anzumelden.',
			'settingsPage.gateProfile' => 'Profil',
			'settingsPage.gateLogout' => 'Abmelden',
			'settingsPage.gateChangePassword' => 'Passwortänderung',
			'settingsPage.gateRequiresActiveSession' => 'Erfordert eine aktive Supabase-Sitzung.',
			'settingsPage.biometricActivationCancelled' => 'Aktivierung abgebrochen.',
			'settingsPage.notificationPermissionsTitle' => 'Benachrichtigungsberechtigungen',
			'settingsPage.notificationPermissionsGranted' => 'Berechtigungen für dieses System verfügbar.',
			'settingsPage.notificationPermissionsDenied' => 'Berechtigung nicht erteilt. Du kannst sie in den Systemeinstellungen ändern.',
			'settingsPage.systemPermissionsTitle' => 'Systemberechtigungen',
			'settingsPage.systemPermissionsOpenFailed' => 'Einstellungen konnten nicht geöffnet werden.',
			'settingsPage.tutorialResetTitle' => 'Tutorials zurückgesetzt',
			'settingsPage.tutorialResetMessage' => 'Die Anleitungen werden in den entsprechenden Bereichen erneut angezeigt.',
			'settingsPage.accountDataManagementTitle' => 'Konto- und Datenverwaltung',
			'settingsPage.accountDataManagementContent' => 'Wähle, ob die Daten gelöscht werden sollen, während das Konto aktiv bleibt, oder ob das Konto dauerhaft gelöscht werden soll.',
			'settingsPage.resetDataAction' => 'Daten zurücksetzen',
			'settingsPage.deleteAccountAction' => 'Konto löschen',
			'settingsPage.confirmResetDataTitle' => 'Zurücksetzen der Daten bestätigen',
			'settingsPage.confirmResetDataMessage' => 'Gewohnheiten, Ziele und Einstellungen werden gelöscht. Das Konto bleibt aktiv. Diese Aktion kann nicht rückgängig gemacht werden.',
			'settingsPage.confirmDeleteAccountTitle' => 'Kontolöschung bestätigen',
			'settingsPage.confirmDeleteAccountMessage' => 'Das Konto und alle zugehörigen Daten werden dauerhaft gelöscht. Diese Aktion ist unwiderruflich.',
			'settingsPage.resetDataTitle' => 'Daten zurücksetzen',
			'settingsPage.resetDataSuccess' => 'Daten erfolgreich gelöscht.',
			'settingsPage.operationFailed' => 'Vorgang fehlgeschlagen.',
			'settingsPage.deleteAccountGateTitle' => 'Konto löschen',
			'settingsPage.accountDeleted' => 'Konto gelöscht.',
			'settingsPage.importDataGateTitle' => 'Daten importieren',
			'settingsPage.importPrivateOnly' => 'Die Importfunktion ist derzeit nur im privaten Modus (lokal) verfügbar.',
			'settingsPage.importSummaryTitle' => 'Importübersicht',
			'settingsPage.importHabitsCount' => ({required Object count}) => '${count} Gewohnheiten',
			'settingsPage.importLogsCount' => ({required Object count}) => '${count} Check-ins (Log)',
			'settingsPage.importMacroGoalsCount' => ({required Object count}) => '${count} Makro-Ziele',
			'settingsPage.importCategoriesCount' => ({required Object count}) => '${count} Kategorien',
			'settingsPage.importMoodsCount' => ({required Object count}) => '${count} Stimmungsaufzeichnungen',
			'settingsPage.importReplaceTitle' => 'Aktuelle Daten ersetzen',
			'settingsPage.importReplaceSubtitle' => 'Löscht alle vorhandenen lokalen Daten vor dem Import. (Empfohlen)',
			'settingsPage.importMergeTitle' => 'Mit aktuellen Daten zusammenführen',
			'settingsPage.importMergeSubtitle' => 'Fügt die importierten Daten hinzu, ohne etwas zu löschen. Kann zu Duplikaten führen.',
			'settingsPage.importConfirmButton' => 'Import bestätigen',
			'settingsPage.importSuccess' => 'Import erfolgreich abgeschlossen!',
			'settingsPage.importError' => ({required Object error}) => 'Fehler beim Import: ${error}',
			'settingsPage.proTitle' => 'Evolve Pro',
			'settingsPage.proSubtitle' => 'Plan, Kaufwiederherstellung und Abonnementverwaltung',
			'settingsPage.revenueCatMacos' => 'RevenueCat macOS',
			'settingsPage.commercialChannelRequired' => 'Kommerzieller Kanal erforderlich',
			'settingsPage.revenueCatOffersRead' => 'Angebote und Berechtigungsstatus werden von RevenueCat gelesen.',
			'settingsPage.revenueCatConfigureKey' => 'Konfiguriere den öffentlichen RevenueCat-Schlüssel des Desktop-Clients.',
			'settingsPage.revenueCatNotSupported' => 'RevenueCat Flutter stellt keine In-App-Käufe unter Windows und Linux bereit.',
			'settingsPage.bestValue' => 'Bester Wert',
			'settingsPage.planManagement' => 'Planverwaltung',
			'settingsPage.activateEvolvePro' => 'Evolve Pro aktivieren',
			'settingsPage.activateEvolveProActive' => 'Evolve Pro-Berechtigung aktiv.',
			'settingsPage.activateEvolveProStart' => 'Starte den nativen StoreKit-Checkout unter macOS.',
			'settingsPage.restorePurchasesDetail' => 'Ruft den Berechtigungsstatus vom Anbieter ab.',
			'settingsPage.manageSubscription' => 'Abonnement verwalten',
			'settingsPage.manageSubscriptionDetail' => 'Öffnet die Abonnementverwaltung des Apple-Kontos.',
			'settingsPage.notAuthenticated' => 'Nicht authentifiziert',
			'settingsPage.verified' => 'Verifiziert',
			'settingsPage.privateModeDataProtected' => 'Deine Daten sind geschützt und werden nur auf diesem Gerät gespeichert.',
			'settingsPage.profileFallback' => 'Profil',
			'settingsPage.fullName' => 'Vollständiger Name',
			'settingsPage.dateOfBirth' => 'Geburtsdatum',
			'settingsPage.dateOfBirthHint' => 'JJJJ-MM-TT',
			'settingsPage.currentPassword' => 'Aktuelles Passwort',
			'settingsPage.newPassword' => 'Neues Passwort',
			'settingsPage.confirmNewPassword' => 'Neues Passwort bestätigen',
			'settingsPage.updatePassword' => 'Passwort aktualisieren',
			'settingsPage.enterCurrentPassword' => 'Gib dein aktuelles Passwort ein.',
			'settingsPage.newPasswordMinLength' => 'Das neue Passwort muss mindestens 8 Zeichen lang sein.',
			'settingsPage.passwordUpdateFailed' => 'Aktualisierung fehlgeschlagen. Überprüfe dein aktuelles Passwort.',
			'settingsPage.sectionApplication' => 'Anwendung',
			'settingsPage.sectionPrivacy' => 'Datenschutz',
			'settingsPage.customColor' => 'Benutzerdefinierte Farbe',
			'settingsPage.applyAction' => 'Anwenden',
			'settingsPage.useAccent' => ({required Object hex}) => 'Akzent ${hex} verwenden',
			'settingsPage.proUpsellTitle' => 'Zu Evolve PRO wechseln',
			'settingsPage.proUpsellSubtitle' => 'Schalte alle Funktionen frei und beschleunige dein Wachstum.',
			'settingsPage.proWelcomeTitle' => 'Willkommen bei Evolve PRO',
			'settingsPage.proActiveMessage' => 'Ihr Abonnement ist aktiv. Sie haben jetzt vollständigen und unbegrenzten Zugriff auf den personalisierten AI Coach, erweiterte Trendstatistiken und alle persönlichen Wachstumstools von Evolve.',
			'settingsPage.proStartJourney' => 'Starte deinen Weg',
			'consent.onboardingTitle' => 'Deine Privatsphäre ist wichtig',
			'consent.continueButton' => 'Weiter',
			'notifications.actionDone' => 'Erledigt',
			'notifications.actionSkip' => 'Überspringen',
			'notifications.actionSnooze' => 'Später',
			'notifications.morningBrief' => 'Morgenbriefing',
			'notifications.eveningReview' => 'Abend-Review',
			'notifications.morningBriefBody' => 'Zeit, deinen Tag zu strukturieren. Prüfe deine Ziele.',
			'notifications.eveningReviewBody' => 'Wie lief der Tag? Erfasse deinen Fortschritt und aktualisiere den Verlauf.',
			'privacy.biometricAuthReason' => 'Authentifiziere dich, um den App-Schutz zu aktivieren.',
			'privacy.biometricUnlockReason' => 'Entsperre die App, um fortzufahren.',
			'consentPage.subtitle' => 'Bevor du Evolve Desktop verwendest, bestätige die Bedingungen, die Datenschutzrichtlinie und die für die Synchronisierung erforderliche Datenverarbeitung.',
			'consentPage.acceptTerms' => 'Ich akzeptiere die Bedingungen und die Datenschutzrichtlinie',
			'consentPage.termsSubtitle' => 'Ich bestätige, dass ich die Dokumente gelesen habe und mindestens 14 Jahre alt bin.',
			'consentPage.crashDiagnostics' => 'Absturzdiagnose',
			'consentPage.crashSubtitle' => 'Erlaube das Senden anonymisierter technischer Berichte.',
			'consentPage.openPrivacy' => 'Datenschutzrichtlinie öffnen',
			'notif.macScheduling' => 'Tägliche Planung auf macOS aktiv.',
			'notif.linuxImmediate' => 'Linux zeigt sofortige Benachrichtigungen, unterstützt aber keine Planung.',
			'notif.openEvolve' => 'Evolve öffnen',
			'notif.windowsScheduling' => 'Windows plant das nächste Vorkommen bei jedem Start.',
			'notif.morningBody' => 'Sieh dir die heutigen Gewohnheiten an und wähle, wo du beginnst.',
			'notif.habitReminderBody' => 'Zeit, deine Gewohnheit zu erledigen.',
			'notif.eveningBody' => 'Lass den Tag ausklingen und aktualisiere deinen Fortschritt.',
			'biometricGate.appLocked' => 'App gesperrt',
			'biometricGate.unlockPrompt' => 'Entsperre mit lokaler Authentifizierung, um fortzufahren.',
			'biometricGate.verifying' => 'Wird überprüft...',
			'biometricGate.unlock' => 'Entsperren',
			'biometricGate.notSupportedLinux' => 'Die biometrische Sperre wird unter Linux nicht unterstützt.',
			'biometricGate.noLocalAuth' => 'Keine lokale Authentifizierungsmethode verfügbar.',
			'biometricGate.authFailed' => 'Authentifizierung fehlgeschlagen.',
			'biometricGate.authUnavailable' => 'Lokale Authentifizierung nicht verfügbar.',
			'sync.syncFailed' => 'Synchronisierung fehlgeschlagen. Lokale Daten beibehalten.',
			'sync.editSavedLocally' => 'Änderung lokal gespeichert. Synchronisierung wird erneut versucht.',
			'subscriptionCtrl.purchaseComplete' => 'Kauf abgeschlossen: Berechtigung wird synchronisiert.',
			'subscriptionCtrl.purchaseIncomplete' => 'Kauf nicht abgeschlossen.',
			'subscriptionCtrl.cantOpenApple' => 'Apple-Abonnementverwaltung konnte nicht geöffnet werden.',
			'subscriptionCtrl.macOnly' => 'In-App-Käufe sind im macOS-Client verfügbar.',
			'subscriptionCtrl.loadOffersFailed' => 'RevenueCat-Angebote konnten nicht geladen werden.',
			'subscriptionCtrl.proActivated' => 'Evolve Pro aktiviert.',
			'subscriptionCtrl.purchasesRestored' => 'Käufe wiederhergestellt.',
			'subscriptionCtrl.noActiveSub' => 'Kein aktives Pro-Abonnement gefunden.',
			'subscriptionCtrl.restoreFailed' => 'Käufe konnten nicht wiederhergestellt werden.',
			'subscriptionCtrl.configKey' => 'Konfiguriere den öffentlichen RevenueCat-Schlüssel des Desktop-Clients.',
			'subscriptionCtrl.loginFirst' => 'Melde dich an, bevor du Evolve Pro verwaltest.',
			'authCtrl.appleNoToken' => 'Apple hat kein Identity-Token zurückgegeben.',
			'authCtrl.appleAuthFailed' => 'Apple-Authentifizierung fehlgeschlagen.',
			'authCtrl.cantOpenBrowser' => 'Der Systembrowser konnte nicht geöffnet werden.',
			'authCtrl.accessNotCompleted' => ({required Object provider}) => '${provider}-Anmeldung nicht abgeschlossen.',
			'authCtrl.providerAuthFailed' => ({required Object provider}) => '${provider}-Authentifizierung fehlgeschlagen.',
			'authCtrl.operationFailed' => 'Vorgang fehlgeschlagen. Versuche es gleich erneut.',
			'proModal.title' => 'Evolve PRO freischalten',
			'proModal.subtitle' => 'Bringen Sie Ihr Gewohnheitssystem auf die nächste Stufe',
			'proModal.featuresHeader' => 'Was der PRO-Plan enthält',
			'proModal.aiCoachTitle' => 'Personalisierter AI-Coach',
			'proModal.aiCoachDesc' => 'Erweiterte Trendanalyse und intelligente KI-generierte Vorschläge.',
			'proModal.statsTitle' => 'Gewohnheitsspezifische Statistiken',
			'proModal.statsDesc' => 'Wichtige Erkenntnisse zur Steigerung Ihrer Produktivität.',
			'proModal.metricsTitle' => 'Erweiterte Zielmetriken',
			'proModal.metricsDesc' => 'Sehen Sie sich detaillierte Diagramme und detaillierte Leistungsstatistiken für jedes Jahr an.',
			'proModal.unlimitedTitle' => 'Unbegrenzte Gewohnheiten',
			'proModal.unlimitedDesc' => 'Erstellen und verfolgen Sie alle gewünschten Gewohnheiten ohne Einschränkungen.',
			'proModal.maybeLater' => 'Vielleicht später',
			'proModal.viewPlans' => 'Pro-Abos ansehen',
			'tutorial.back' => 'Zurück',
			'tutorial.next' => 'Weiter',
			'tutorial.finish' => 'Fertig',
			'tutorial.dailyCheckIn' => 'Täglicher Check-in',
			'tutorial.dailyCheckinDesc' => 'Hier kannst du deine tägliche Stimmung festhalten, um dein Wohlbefinden zu verfolgen und mit dem Erreichen deiner Ziele zu verknüpfen.',
			'tutorial.manageHabits' => 'Gewohnheiten verwalten',
			'tutorial.addEditOrDeleteDailyHabits' => 'Fügen Sie schnell und einfach tägliche Gewohnheiten hinzu, bearbeiten oder löschen Sie sie.',
			'tutorial.movingToGoals' => 'Weiter zu den Zielen',
			'tutorial.goalsPageDesc' => 'Die Seite, auf der du deine langfristigen Ziele und deren Leistung verwaltest.',
			'tutorial.filterByHabit' => 'Nach Gewohnheit filtern',
			'tutorial.filterHabitDesc' => 'Von hier aus kannst du eine bestimmte Gewohnheit für Details auswählen oder \'Alle Gewohnheiten\' für einen Gesamtüberblick.',
			'tutorial.statisticsSections' => 'Statistikbereiche',
			'tutorial.statsSectionsDesc' => 'Navigiere zwischen den Tabs, um Trends, Leistungs-Warnungen, den Verlauf deiner Gewohnheiten und deine Stimmung zu sehen.',
			_ => null,
		};
	}
}
