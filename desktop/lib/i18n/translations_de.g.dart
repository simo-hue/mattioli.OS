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
	@override late final _Translations$verification$de verification = _Translations$verification$de._(_root);
	@override late final _Translations$macroTargets$de macroTargets = _Translations$macroTargets$de._(_root);
	@override late final _Translations$auth$de auth = _Translations$auth$de._(_root);
	@override late final _Translations$privateData$de privateData = _Translations$privateData$de._(_root);
	@override late final _Translations$icloudSync$de icloudSync = _Translations$icloudSync$de._(_root);
	@override late final _Translations$privateRecovery$de privateRecovery = _Translations$privateRecovery$de._(_root);
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
	@override late final _Translations$appLogs$de appLogs = _Translations$appLogs$de._(_root);
	@override late final _Translations$coachSettings$de coachSettings = _Translations$coachSettings$de._(_root);
	@override late final _Translations$tour$de tour = _Translations$tour$de._(_root);
	@override late final _Translations$palette$de palette = _Translations$palette$de._(_root);
	@override late final _Translations$targets$de targets = _Translations$targets$de._(_root);
	@override late final _Translations$trackingMode$de trackingMode = _Translations$trackingMode$de._(_root);
}

// Path: verification
class _Translations$verification$de extends Translations$verification$en {
	_Translations$verification$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get autoVerified => 'Automatisch geprüft';
	@override late final _Translations$verification$compound$de compound = _Translations$verification$compound$de._(_root);
	@override late final _Translations$verification$templates$de templates = _Translations$verification$templates$de._(_root);
	@override late final _Translations$verification$units$de units = _Translations$verification$units$de._(_root);
}

// Path: macroTargets
class _Translations$macroTargets$de extends Translations$macroTargets$en {
	_Translations$macroTargets$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get sectionTitle => 'Numerisches Ziel';
	@override String get none => 'Keins';
	@override String get amountLabel => 'Zielwert';
	@override String get linkLabel => 'Mit einer Gewohnheit verknüpfen';
	@override String get manual => 'Manuell';
	@override String get unitCount => 'Anzahl';
	@override String get reached => 'Erreicht';
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

// Path: icloudSync
class _Translations$icloudSync$de extends Translations$icloudSync$en {
	_Translations$icloudSync$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get bannerAction => 'Aktivieren';
	@override String get bannerText => 'iCloud-Sync ist aus — deine Gewohnheiten liegen nur auf diesem Gerät und gehen verloren, wenn du es zurücksetzt oder ersetzt.';
	@override String get deleteSyncNote => 'Die iCloud-Synchronisierung ist aktiv: Dabei wird auch die synchronisierte Kopie in deiner iCloud gelöscht und die Synchronisierung deaktiviert. Andere Geräte behalten ihre lokale Kopie — führe dies auf jedem Gerät aus, um überall zu löschen.';
	@override String get detailsAllSynced => 'Alles hochgeladen';
	@override String get detailsCopied => 'Bericht kopiert';
	@override String get detailsCopy => 'Bericht kopieren';
	@override String detailsFailed({required Object count}) => '${count} Elemente konnten nicht hochgeladen werden';
	@override String detailsPending({required Object count}) => '${count} Elemente warten auf den Upload';
	@override String get detailsTitle => 'Synchronisierungsdetails';
	@override String get disclosureAccept => 'Aktivieren';
	@override String get disclosureBody => 'Deine privaten Daten werden ausschließlich über deinen eigenen iCloud-Account synchronisiert, Ende-zu-Ende-verschlüsselt — niemals über unsere Server. Der Verschlüsselungsschlüssel liegt in deinem iCloud-Schlüsselbund; wenn du den iCloud-Schlüsselbund deaktivierst, können synchronisierte Daten nicht wiederhergestellt werden.';
	@override String get disclosureTitle => 'Ende-zu-Ende-verschlüsselt';
	@override String get enableTitle => 'iCloud-Synchronisierung aktivieren';
	@override String get forceEnable => 'Neu beginnen';
	@override String get forceEnableBody => 'Die Daten eines anderen Geräts sind bereits in iCloud, aber dessen Verschlüsselungsschlüssel hat dieses Gerät noch nicht erreicht. Meist genügt es, ein paar Minuten zu warten. Ein Neuanfang löscht, was in iCloud liegt, und ersetzt es durch die Daten dieses Geräts. Dies kann nicht rückgängig gemacht werden.';
	@override String get forceEnableTitle => 'Mit diesem Gerät neu beginnen';
	@override String keySplitBody({required Object count}) => '${count} Einträge in iCloud wurden auf einem anderen Gerät mit einem anderen Schlüssel verschlüsselt, daher kann dieses Gerät sie nicht lesen. Setze die Synchronisierung von dem Gerät aus zurück, das die Daten enthält, die du behalten möchtest.';
	@override String get keySplitTitle => 'Einige iCloud-Daten sind nicht lesbar';
	@override String lastSyncedAt({required Object time}) => 'Zuletzt synchronisiert ${time}';
	@override String get lastSyncedNever => 'Noch nie synchronisiert';
	@override String get resetFromDevice => 'Synchronisierung von diesem Gerät zurücksetzen';
	@override String get resetFromDeviceConfirm => 'Dies löscht alles, was derzeit in iCloud gespeichert ist, und lädt stattdessen die Daten dieses Geräts hoch. Deine anderen Geräte laden anschließend diese Kopie herunter. Führe dies nur auf dem Gerät aus, das die Daten enthält, die du behalten möchtest. Dies kann nicht rückgängig gemacht werden.';
	@override String get resetFromDeviceDetail => 'Alles in iCloud durch die Daten dieses Geräts ersetzen';
	@override String get resetFromDeviceDone => 'Synchronisierung zurückgesetzt. Die Daten dieses Geräts sind jetzt die Kopie in iCloud.';
	@override String get statusIdle => 'Aktuell';
	@override String get statusNoAccount => 'Bei iCloud anmelden, um zu synchronisieren';
	@override String get statusNotSynced => 'Es wurde nicht alles synchronisiert';
	@override String get statusOff => 'Synchronisierung aus';
	@override String get statusSyncing => 'Synchronisiere…';
	@override String get statusUnavailable => 'iCloud ist derzeit nicht verfügbar';
	@override String get statusWaitingKey => 'Warten auf den Verschlüsselungsschlüssel von deinem anderen Gerät';
	@override String get statusWaitingKeychain => 'Warte auf den iCloud-Schlüsselbund — stelle sicher, dass die App auf deinem iPhone aktuell ist';
	@override String get syncNow => 'Jetzt synchronisieren';
	@override String get syncNowNeedsSync => 'Schalte zuerst die iCloud-Synchronisierung ein.';
	@override String get title => 'iCloud-Synchronisierung';
	@override String get unavailablePlatform => 'Auf diesem Gerät nicht verfügbar';
}

// Path: privateRecovery
class _Translations$privateRecovery$de extends Translations$privateRecovery$en {
	_Translations$privateRecovery$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get preparing => 'Dein privater Bereich wird vorbereitet…';
	@override String get restoredFromCloudToast => 'Lokale Datenbank konnte nicht entsperrt werden – deine Daten wurden aus iCloud wiederhergestellt.';
	@override String get waitingTitle => 'Warten auf iCloud';
	@override String get waitingMessage => 'Die Synchronisierung ist aktiv, aber dein Verschlüsselungsschlüssel ist noch nicht aus dem iCloud-Schlüsselbund eingetroffen. Warte einen Moment und versuche es erneut.';
	@override String get lockedTitle => 'Private Daten können nicht entsperrt werden';
	@override String get lockedMessageLocalOnly => 'Dieses Gerät kann deine lokale private Datenbank nicht entsperren – der Verschlüsselungsschlüssel fehlt – und die iCloud-Synchronisierung ist aus, es gibt also keine Cloud-Kopie zum Wiederherstellen. Du kannst zurücksetzen und neu beginnen.';
	@override String get lockedMessageICloudUnavailable => 'Dieses Gerät kann deine lokale private Datenbank nicht entsperren. Die iCloud-Synchronisierung ist aktiv, aber das Konto ist nicht verfügbar – melde dich bei iCloud an und versuche es erneut.';
	@override String get errorTitle => 'Privater Modus konnte nicht geöffnet werden';
	@override String get errorMessage => 'Beim Öffnen deiner privaten Datenbank ist etwas schiefgelaufen. Versuche es erneut oder kehre zur Anmeldung zurück.';
	@override String get enableSyncHint => 'Hast du diese Daten auf einem anderen Gerät? Aktiviere nach dem Zurücksetzen die iCloud-Synchronisierung in den Einstellungen, um sie hierher zu holen.';
	@override String get retry => 'Erneut versuchen';
	@override String get resetFresh => 'Zurücksetzen und neu beginnen';
	@override String get backToSignIn => 'Zurück zur Anmeldung';
	@override String get undecryptableTitle => 'Deine Daten sind sicher – aber diese Version der App kann sie nicht entsperren';
	@override String get undecryptableMessage => 'Die private Datenbank auf diesem Mac ist unversehrt; sie ist lediglich mit einem anderen Schlüssel verschlüsselt als dem, den dieser Build besitzt. Es wurde nichts geändert oder gelöscht. Meist bedeutet das, dass sie von einem anderen Evolve-Build (etwa einem Entwicklungs-Build) erstellt wurde. Öffne diesen Build, um an die Daten zu kommen, oder stelle bei einer Neuinstallation aus iCloud wieder her.';
	@override String get schemaTooNewTitle => 'Diese Datenbank stammt aus einer neueren Version';
	@override String get schemaTooNewMessage => 'Deine privaten Daten wurden zuletzt mit einer neueren Version von Evolve geöffnet und sind vollständig intakt. Diese ältere Version kann sie nicht sicher lesen. Aktualisiere auf die neueste Version – oder öffne den neueren Build erneut – und alles ist wieder da.';
	@override String get copyDiagnostics => 'Diagnose kopieren';
	@override String get diagnosticsCopied => 'Diagnose in die Zwischenablage kopiert';
	@override String get resetConfirmTitle => 'Diese Datenbank beiseitelegen?';
	@override String get resetConfirmBody => 'Evolve startet mit einer leeren privaten Datenbank. Deine vorhandene verschlüsselte Datei bleibt auf diesem Mac erhalten und wird nicht gelöscht – sie kann also weiterhin wiederhergestellt werden.';
	@override String resetConfirmBodySized({required Object size}) => 'Evolve startet mit einer leeren privaten Datenbank. Deine vorhandene verschlüsselte Datei (${size}) bleibt auf diesem Mac erhalten und wird nicht gelöscht – sie kann also weiterhin wiederhergestellt werden.';
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
	@override String get unexpectedErrorTitle => 'Etwas ist schiefgelaufen';
	@override String get unexpectedErrorMessage => 'Ein unerwarteter Fehler ist aufgetreten. Bitte versuche es erneut.';
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
	@override String get periodWhen => 'Wann';
}

// Path: createHabit
class _Translations$createHabit$de extends Translations$createHabit$en {
	_Translations$createHabit$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Neue Gewohnheit';
	@override String get subtitle => 'Definiere deine neue Gewohnheit.';
	@override String get titleHint => 'z. B. Meditation';
	@override String get weeklyFrequency => 'Wöchentliche Häufigkeit';
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
	@override String get archiveCategory2 => 'Kategorie archivieren';
	@override String categoryUnavailableLinked({required Object label, required Object count}) => 'Die Kategorie „${label}" ist für neue Ziele nicht mehr verfügbar, bleibt aber mit ${count} bisherigen Zielen und deinen Statistiken verknüpft.';
	@override String categoryUnavailableArchived({required Object label}) => 'Die Kategorie „${label}" ist für neue Ziele nicht mehr verfügbar, bleibt aber in deinem Verlauf.';
	@override String get archive => 'Archivieren';
	@override String get createNewCategory => 'Neue Kategorie erstellen';
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
	@override String get goodAfternoon => 'Guten Nachmittag';
	@override String get goodEvening => 'Guten Abend';
	@override String get manager => 'Verwaltung';
	@override String get aiChat => 'AI-Chat';
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
	@override String get sortRate => 'Quote';
	@override String get sortStreak => 'Serie';
	@override String get sortName => 'Name';
	@override String get filterActive => 'Aktiv';
	@override String get filterAll => 'Alle';
	@override String get noActiveHabits => 'Keine aktiven Gewohnheiten – wechsle zu Alle, um beendete anzuzeigen.';
	@override String get worstStreakLabel => 'Schlechteste';
	@override String get momentumTitle => 'Momentum';
	@override String get momentumSubtitle => 'Deine aktuelle Form';
	@override String get momentumForm => 'FORM';
	@override String get momentumRate => '7 Tage';
	@override String get momentumStreakHealth => 'Serien';
	@override String get momentumTrend => 'Trend';
	@override String get rollingImproving => 'Steigend';
	@override String get rollingDeclining => 'Fallend';
	@override String get rollingSteady => 'Stabil';
	@override String get lifetimeConsistency => 'Beständigkeit';
	@override String get lifetimeConsistencyDetail => 'Gesamtabschluss';
	@override String get lifetimeTotalDone => 'Gesamt erledigt';
	@override String get lifetimeTotalDoneDetail => 'Abgehakte Gewohnheiten';
	@override String get lifetimePerfectDays => 'Perfekte Tage';
	@override String get lifetimePerfectDaysDetail => 'Alles erledigt';
	@override String get lifetimeDaysTracked => 'Erfasste Tage';
	@override String get lifetimeDaysTrackedDetail => 'Seit dem Start';
	@override String get keystoneTitle => 'SCHLÜSSELGEWOHNHEIT';
	@override String keystoneImpact({required Object withPct, required Object withoutPct}) => 'An ihren Tagen erreichst du ${withPct}% deiner anderen Gewohnheiten, sonst ${withoutPct}%.';
	@override String get yearActivity => '365-Tage-Aktivität';
	@override String get yearActivitySubtitle => 'Jede Gewohnheit, jeden Tag';
	@override String activeDaysCount({required Object count}) => '${count} aktive Tage';
	@override String get heatmapLess => 'Weniger';
	@override String get heatmapMore => 'Mehr';
	@override String get bestHabitsTitle => 'Beste Gewohnheiten';
	@override String get criticalHabitsTitle => 'Braucht Aufmerksamkeit';
	@override String criticalStalled({required Object days}) => '${days}T untätig';
	@override String get rollingTitle => 'Gleitender Abschluss';
	@override String get rollingSubtitle => '7- und 30-Tage-Rate';
	@override String get rolling7 => '7 Tage';
	@override String get rolling30 => '30 Tage';
	@override String get weekVsAvgTitle => 'Diese Woche vs. Schnitt';
	@override String get weekVsAvgSubtitle => 'Wie diese Woche abschneidet';
	@override String get thisWeek => 'Diese Woche';
	@override String get yourAverage => 'Dein Durchschnitt';
	@override String get weekdayShapeTitle => 'Wochenrhythmus';
	@override String get weekdayShapeSubtitle => 'Abschluss nach Wochentag';
	@override String get weekdayWeekendTitle => 'Woche vs. Wochenende';
	@override String get weekdayWeekendSubtitle => 'Wo du am stärksten bist';
	@override String get weekdaysLabel => 'Wochentage';
	@override String get weekendLabel => 'Wochenende';
	@override String get seasonalityTitle => 'Saisonalität';
	@override String get seasonalitySubtitle => 'Abschluss nach Monat';
	@override String get bounceBackTitle => 'Erholungsrate';
	@override String get bounceBackSubtitle => 'Comeback nach einem Aussetzer';
	@override String bounceBackDetail({required Object recoveries, required Object opportunities}) => '${recoveries} von ${opportunities} Malen erholt';
	@override String get dangerZoneTitle => 'Gefahrenzone';
	@override String get dangerZoneSubtitle => 'Wann Serien reißen';
	@override String get dangerZoneNone => 'Noch keine gerissenen Serien';
	@override String dangerZoneDetail({required Object breaks, required Object total}) => '${breaks} von ${total} Brüchen hier';
	@override String get performanceComparisonTitle => 'Leistungsvergleich';
	@override String get performanceComparisonSubtitle => 'Beste vs. schlechteste Serie';
	@override String perfCompGap({required Object pct}) => '${pct}% Abstand';
	@override String get perfCompBest => 'Beste';
	@override String get perfCompWorst => 'Schlechteste';
	@override String get consistencyTitle => 'Beständigkeit';
	@override String get consistencySubtitle => 'Regelmäßigste Gewohnheiten';
	@override String get consistencySteadiest => 'Am stetigsten';
	@override String get consistencyErratic => 'Am unregelmäßigsten';
	@override String get medalsTitle => 'Serien-Rangliste';
	@override String get medalsSubtitle => 'Längste aktuelle Serien';
	@override String get neverMissedTitle => 'Nie verpasst';
	@override String get neverMissedEmpty => 'Noch keine perfekten Gewohnheiten';
	@override String get distributionTitle => 'Verteilung';
	@override String get distributionSubtitle => 'Gewohnheiten nach Erfolgsrate';
	@override String get synergyTitle => 'Gewohnheits-Synergie';
	@override String get synergySubtitle => 'Welche Gewohnheiten zusammen laufen';
	@override String get moodSensitiveTitle => 'Stimmungsabhängig';
	@override String get moodSensitiveSubtitle => 'Am meisten von der Stimmung beeinflusst';
	@override String get resilientHabitsTitle => 'Robuste Gewohnheiten';
	@override String get resilientHabitsSubtitle => 'Auch an schlechten Tagen erledigt';
	@override String get correlationAnalysisTitle => 'Stimmungskorrelation';
	@override String get correlationAnalysisSubtitle => 'Abschluss bei niedriger vs. hoher Stimmung';
	@override String get moodEnergyTrendTitle => 'Stimmung & Energie';
	@override String moodEnergyTrendSubtitle({required Object days}) => 'Letzte ${days} Tage';
	@override String get allTimeBest => 'Allzeitrekord';
	@override String get topPerformerLabel => 'Top-Gewohnheit';
	@override String get currentStreakShort => 'Jetzt';
	@override String get recordLabel => 'Rekord';
	@override String get recordDetail => 'Längste Serie aller Zeiten';
	@override String get adherenceTitle => 'Planeinhaltung';
	@override String get adherenceSubtitle => 'Von den fälligen Tagen';
	@override String adherenceDetail({required Object done, required Object scheduled}) => '${done} von ${scheduled} geplanten Tagen';
	@override String get atRiskTitle => 'Gefährdet';
	@override String get atRiskYes => 'Ja';
	@override String get atRiskNo => 'Im Plan';
	@override String atRiskDetail({required Object days}) => '${days} Tage seit dem letzten Mal';
	@override String get daysUnit => 'T';
	@override String get gapTitle => 'Abstände';
	@override String get gapSubtitle => 'Tage zwischen Abschlüssen';
	@override String get gapAvg => 'Ø Abstand';
	@override String get gapLongest => 'Längster';
	@override String get gapSince => 'Seit letztem';
	@override String get habitBounceBackShort => 'Erholung';
	@override String get habitConsistencyDetail => 'Regelmäßigkeitswert';
	@override String habitPercentile({required Object pct}) => 'Besser als ${pct}% deiner Gewohnheiten';
	@override String get monthVsTitle => 'Dieser Monat vs. letzter';
	@override String get monthVsSubtitle => 'Abschluss Monat für Monat';
	@override String get thisMonthLabel => 'Dieser Monat';
	@override String get lastMonthLabel => 'Letzter Monat';
	@override String get nextDayMoodTitle => 'Stimmung am Folgetag';
	@override String get nextDayMoodSubtitle => 'Stimmung & Energie am nächsten Tag';
	@override String get nextDayAfterDone => 'Nach dem Erledigen';
	@override String get nextDayAfterMissed => 'Nach dem Verpassen';
	@override String nextDayMoodLift({required Object value}) => '${value} Stimmungsplus';
	@override String get streakHistoryTitle => 'Serienverlauf';
	@override String get streakHistorySubtitle => 'Jede Folge aufeinanderfolgender Tage';
	@override String streakHistoryDetail({required Object count, required Object longest}) => '${count} Serien · längste ${longest} Tage';
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
	@override String dayDotTooltip({required Object day, required Object month, required Object status}) => '${day}. ${month} · ${status}';
	@override String dayDotTooltipToday({required Object status}) => 'Heute · ${status}';
	@override String get editHabit => 'Gewohnheit bearbeiten';
	@override String get newHabit => 'Neue Gewohnheit';
	@override String get optionalReminder => 'Optionale Erinnerung';
	@override String get reminderHint => 'z. B. 08:30';
	@override String get close => 'Schließen';
	@override String get statusDone => 'Erledigt';
	@override String get statusSkipped => 'Übersprungen';
	@override String get statusUnrecorded => 'Nicht erfasst';
	@override String weekOf({required Object day, required Object month}) => 'Woche vom ${day}. ${month}';
	@override String get lifeWeeks => 'Wochen deines Weges';
	@override String get catMindfulness => 'Achtsamkeit';
	@override String get editableHint => 'Nur heute und gestern können bearbeitet werden.';
	@override String get titleRequired => 'Titel ist erforderlich';
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
	@override String rangeSameMonth({required Object startDay, required Object endDay, required Object month, required Object year}) => '${startDay}. – ${endDay}. ${month} ${year}';
	@override String rangeSameYear({required Object startDay, required Object startMonth, required Object endDay, required Object endMonth, required Object year}) => '${startDay}. ${startMonth} – ${endDay}. ${endMonth} ${year}';
	@override String rangeCrossYear({required Object startDay, required Object startMonth, required Object startYear, required Object endDay, required Object endMonth, required Object endYear}) => '${startDay}. ${startMonth} ${startYear} – ${endDay}. ${endMonth} ${endYear}';
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
	@override late final _Translations$ai$apiKey$de apiKey = _Translations$ai$apiKey$de._(_root);
	@override late final _Translations$ai$coachPrompts$de coachPrompts = _Translations$ai$coachPrompts$de._(_root);
	@override late final _Translations$ai$local$de local = _Translations$ai$local$de._(_root);
	@override late final _Translations$ai$standard$de standard = _Translations$ai$standard$de._(_root);
	@override late final _Translations$ai$consent$de consent = _Translations$ai$consent$de._(_root);
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
	@override String get defaultUserName => 'Nutzer';
	@override String userNameLine({required Object userName}) => '- Name: ${userName}';
	@override String activeGoalsCount({required Object count}) => '- Aktive Ziele: ${count}';
	@override String completedGoalsCount({required Object count}) => '- Abgeschlossene Ziele: ${count}';
	@override String todayCompletion({required Object completed, required Object total}) => '- Gewohnheiten heute: ${completed} von insgesamt ${total} abgeschlossen.';
	@override String get newChatTooltip => 'Neuer Chat';
	@override String get clearConfirmTitle => 'Neuen Chat starten?';
	@override String get clearConfirmBody => 'Dies löscht die aktuelle Unterhaltung — sie wird nicht gespeichert.';
	@override String get clearConfirmCancel => 'Abbrechen';
	@override String get clearConfirmAccept => 'Neuer Chat';
	@override String get copyTooltip => 'Kopieren';
	@override String get copiedToast => 'In die Zwischenablage kopiert';
	@override String get linkOpenFailed => 'Link konnte nicht geöffnet werden.';
}

// Path: settingsPage
class _Translations$settingsPage$de extends Translations$settingsPage$en {
	_Translations$settingsPage$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get aboutCopied => 'Versionsdetails kopiert';
	@override String get aboutCopyTooltip => 'Versionsdetails kopieren';
	@override String aboutVersion({required Object version, required Object build}) => 'Version ${version} (${build})';
	@override String get accentColor => 'Akzentfarbe';
	@override String get accentColorDetail => 'Erweiterte Palette, reserviert für Evolve Pro.';
	@override String get accessProtection => 'Zugriffsschutz';
	@override String get account => 'Konto';
	@override String get accountAndOnboarding => 'Konto und Onboarding';
	@override String get accountDataManagementContent => 'Wähle, ob die Daten gelöscht werden sollen, während das Konto aktiv bleibt, oder ob das Konto dauerhaft gelöscht werden soll.';
	@override String get accountDataManagementTitle => 'Konto- und Datenverwaltung';
	@override String get accountDeleted => 'Konto gelöscht.';
	@override String get accountPaneSubtitle => 'Mit welchem Konto du angemeldet bist und wo deine Daten liegen.';
	@override String get accountSyncOn => 'Aktiv — über dein Konto';
	@override String get activateEvolveProStart => 'Abonniere mit deinem Apple-Konto.';
	@override String get advancedPaneSubtitle => 'Erweiterte Einstellungen und Diagnose.';
	@override String get aiAndSystem => 'AI & SYSTEM';
	@override String get aiInsights => 'AI-Insights';
	@override String get aiInsightsDetail => 'Personalisierte Analysen und Tipps von der AI.';
	@override String get aiSuggestions => 'AI-Vorschläge';
	@override String get aiSuggestionsDetail => 'Intelligente Gewohnheitsanalyse';
	@override String get appLogsDetail => 'Diagnoseprotokolle dieser Sitzung ansehen';
	@override String get appLogsTitle => 'App-Protokolle';
	@override String get appearanceAndVisual => 'Erscheinungsbild und Optik';
	@override String get appearanceSubtitle => 'Lokale Einstellungen, an den Desktop angepasst';
	@override String get appearanceTitle => 'Erscheinungsbild und Anwendung';
	@override String get applyAction => 'Anwenden';
	@override String get availableWithActiveSession => 'Verfügbar mit einer aktiven Supabase-Sitzung';
	@override String get avatarGateTitle => 'Avatar';
	@override String get avatarPickFailed => 'Bildauswahl fehlgeschlagen.';
	@override String get bestValue => 'Bester Wert';
	@override String get billingAppleDetail => 'Dein Abonnement wird mit deinem Apple-Konto gekauft und verwaltet.';
	@override String get billingAppleTitle => 'Abrechnung über Apple';
	@override String get billingPlatformUnsupported => 'In-App-Käufe sind auf dieser Plattform nicht verfügbar.';
	@override String get billingUnavailableDetail => 'Abonnements sind vorübergehend nicht verfügbar. Bitte versuche es später erneut.';
	@override String get biometricActivationCancelled => 'Aktivierung abgebrochen.';
	@override String get biometricLock => 'Biometrische Sperre';
	@override String get biometricLockDetail => 'Verfügbar mit dem nativen Adapter unter macOS und Windows; unter Linux nicht unterstützt.';
	@override String get calendarExperienceLanguage => 'Kalender, Erlebnis und Sprache';
	@override late final _Translations$settingsPage$calendarViewOptions$de calendarViewOptions = _Translations$settingsPage$calendarViewOptions$de._(_root);
	@override String get cancel => 'Abbrechen';
	@override String get changePassword => 'Passwort ändern';
	@override String get changePasswordDetail => 'Aktualisierung der Anmeldedaten über Supabase Auth.';
	@override String get commercialChannelRequired => 'Käufe nicht verfügbar';
	@override String get confirm => 'Bestätigen';
	@override String get confirmDeleteAccountMessage => 'Das Konto und alle zugehörigen Daten werden dauerhaft gelöscht. Diese Aktion ist unwiderruflich.';
	@override String get confirmDeleteAccountTitle => 'Kontolöschung bestätigen';
	@override String get confirmNewPassword => 'Neues Passwort bestätigen';
	@override String get confirmResetDataMessage => 'Gewohnheiten, Ziele und Einstellungen werden gelöscht. Das Konto bleibt aktiv. Diese Aktion kann nicht rückgängig gemacht werden.';
	@override String get confirmResetDataTitle => 'Zurücksetzen der Daten bestätigen';
	@override String get confirmSignOutMessage => 'Möchtest du dich wirklich abmelden? Du musst deine Anmeldedaten erneut eingeben, um dich wieder anzumelden.';
	@override String get confirmSignOutTitle => 'Abmeldung bestätigen';
	@override String get currentPassword => 'Aktuelles Passwort';
	@override String get customColor => 'Benutzerdefinierte Farbe';
	@override String get dataAndConsents => 'Daten und Einwilligungen';
	@override String get dataBackupPaneSubtitle => 'Wohin deine Daten kopiert werden, wie du sie ein- und ausführst und wie du sie löschst.';
	@override String get dataRepository => 'Daten-Repository';
	@override String get dataStorage => 'Datenspeicherung';
	@override String get dataStorageAccount => 'Dein Evolve-Konto';
	@override String get dataStorageThisMac => 'Nur auf diesem Mac, verschlüsselt';
	@override String get dateOfBirth => 'Geburtsdatum';
	@override String get dateOfBirthHint => 'JJJJ-MM-TT';
	@override String get deepWorkInsights => 'Deep-Work-Insights';
	@override String get deepWorkInsightsDetail => 'Erweiterte Analyse deiner Fokus-Sitzungen.';
	@override String get defaultCalendarView => 'Standard-Kalenderansicht';
	@override String get deleteAccountAction => 'Konto löschen';
	@override String get deleteAccountAndData => 'Konto und Daten löschen';
	@override String get deleteAccountAndDataDetail => 'Unwiderruflicher Vorgang, durch Bestätigung geschützt.';
	@override String get deleteAccountGateTitle => 'Konto löschen';
	@override String get deletePrivateData => 'private Daten löschen';
	@override String get deletePrivateDataDetail => 'Löscht die verschlüsselte lokale Datenbank dauerhaft.';
	@override String get detailsHeader => 'Abo-Details';
	@override String get disabledTurnOnFirst => 'Schalte die Erinnerung ein, um eine Zeit zu wählen.';
	@override String get email => 'E-Mail';
	@override String get encryptedLocalDatabase => 'Verschlüsselte lokale Datenbank';
	@override String get enterCurrentPassword => 'Gib dein aktuelles Passwort ein.';
	@override String get eveningReview => 'Abendliche Rückschau';
	@override String get eveningReviewDetail => 'Erinnert dich daran, deinen Tag zu festigen.';
	@override String get eveningReviewTime => 'Uhrzeit der abendlichen Rückschau';
	@override String get expiresOn => 'Läuft ab am';
	@override String get exportData => 'Daten exportieren';
	@override String get exportDataDetail => 'Teilt einen vollständigen JSON-Export der verfügbaren Daten.';
	@override String get exportDoneClipboard => 'Das JSON ist in der Zwischenablage: Linux unterstützt keine Dateifreigabe.';
	@override String get exportDoneSaved => 'Die JSON-Datei wurde am gewählten Ort gespeichert.';
	@override String get exportDoneShare => 'Das JSON wurde an die Freigabeauswahl gesendet.';
	@override String get exportDoneTitle => 'Export abgeschlossen';
	@override String get exportPrivateShareText => 'Meine privaten Daten, exportiert aus Evolve';
	@override String get exportShareText => 'Meine aus Evolve exportierten Daten';
	@override String get focusMode => 'Fokusmodus';
	@override String get focusModeDetail => 'Pausiert alle Erinnerungen und Benachrichtigungen.';
	@override String get focusModeOnBody => 'Diese Erinnerungen pausieren, bis du ihn ausschaltest.';
	@override String get focusModeOnTitle => 'Fokus ist aktiv';
	@override String get fullName => 'Vollständiger Name';
	@override String get gateChangePassword => 'Passwortänderung';
	@override String get gateLogout => 'Abmelden';
	@override String get gateProfile => 'Profil';
	@override String get gateRequiresActiveSession => 'Erfordert eine aktive Supabase-Sitzung.';
	@override String get generalPaneSubtitle => 'Aussehen und Sprache von Evolve.';
	@override String get goToLogin => 'Zur Anmeldung';
	@override String get goToLoginDetail => 'Setze den privaten Modus aus und melde dich bei Supabase an.';
	@override String get groupAppLock => 'App-Sperre';
	@override String get groupAppearance => 'Erscheinungsbild';
	@override String get groupBackups => 'Backups';
	@override String get groupDailyReminders => 'Tägliche Erinnerungen';
	@override String get groupDataStorage => 'Datenspeicherung';
	@override String get groupDelivery => 'Zustellung';
	@override String get groupDiagnostics => 'Diagnose';
	@override String get groupDiagnosticsConsent => 'Diagnose & Einwilligungen';
	@override String get groupFocus => 'Fokus';
	@override String get groupGettingStarted => 'Erste Schritte';
	@override String get groupLanguageFormats => 'Sprache & Formate';
	@override String get groupLegal => 'Rechtliches';
	@override String get groupSignIn => 'Anmeldung';
	@override String get habitReminders => 'Gewohnheitserinnerungen';
	@override String get habitRemindersDetail => 'Sendet das tägliche Morgenbriefing.';
	@override String get hapticFeedback => 'Haptisches Feedback';
	@override String get hapticFeedbackDetail => 'Der Desktop behält die Einstellung bei, erzeugt aber keine Vibrationen.';
	@override String importCategoriesCount({required Object count}) => '${count} Kategorien';
	@override String get importCompletedTitle => 'Import abgeschlossen';
	@override String get importConfirmButton => 'Import bestätigen';
	@override String get importData => 'Daten importieren';
	@override String get importDataDetail => 'Stellt ein Backup (JSON oder ZIP) von Evolve wieder her.';
	@override String get importDataGateTitle => 'Daten importieren';
	@override String get importEntityCategories => 'Kategorien';
	@override String get importEntityHabits => 'Gewohnheiten';
	@override String get importEntityLogs => 'Gewohnheits-Logs';
	@override String get importEntityMacroGoals => 'Makro-Ziele';
	@override String get importEntityMoods => 'Stimmungsdaten';
	@override String importError({required Object error}) => 'Fehler beim Import: ${error}';
	@override String importHabitsCount({required Object count}) => '${count} Gewohnheiten';
	@override String get importInProgress => 'Daten werden importiert...';
	@override String get importLockedMessage => 'Dieses Gerät kann deine lokale private Datenbank nicht entsperren – ihr Verschlüsselungsschlüssel fehlt (das passiert nach dem Wechsel auf einen neuen Mac oder einer Änderung der App-Signierung). Die vorhandenen lokalen Daten sind nicht wiederherstellbar, aber du kannst sie zurücksetzen und dieses Backup in eine neue, leere Datenbank importieren. Dies kann nicht rückgängig gemacht werden.';
	@override String get importLockedResetButton => 'Zurücksetzen & importieren';
	@override String get importLockedTitle => 'Gesperrte private Datenbank zurücksetzen?';
	@override String importLogsCount({required Object count}) => '${count} Check-ins (Log)';
	@override String importMacroGoalsCount({required Object count}) => '${count} Makro-Ziele';
	@override String get importMergeSubtitle => 'Wird mit deinen Daten zusammengeführt, wobei die neueste Version jedes Eintrags behalten wird.';
	@override String get importMergeTitle => 'Mit aktuellen Daten zusammenführen';
	@override String importMoodsCount({required Object count}) => '${count} Stimmungsaufzeichnungen';
	@override String importPreviewSkipped({required Object count}) => '⚠ ${count} ungültige Datensätze werden übersprungen';
	@override String get importPrivateOnly => 'Die Importfunktion ist derzeit nur im privaten Modus (lokal) verfügbar.';
	@override String get importReplaceConfirmButton => 'Löschen & ersetzen';
	@override String importReplaceConfirmMessage({required Object count}) => 'Dies löscht deine aktuellen Daten endgültig (etwa ${count} Einträge) und behält nur, was in diesem Backup ist. Das kann nicht rückgängig gemacht werden.';
	@override String get importReplaceConfirmTitle => 'Alle Daten ersetzen?';
	@override String get importReplaceSubtitle => 'Löscht endgültig jeden vorhandenen Eintrag, der nicht in diesem Backup ist.';
	@override String get importReplaceTitle => 'Aktuelle Daten ersetzen';
	@override String importRowMerge({required Object label, required Object added, required Object updated, required Object unchanged}) => '${label}: ${added} hinzugefügt, ${updated} aktualisiert, ${unchanged} unverändert';
	@override String importRowReplace({required Object count, required Object label}) => '${count} ${label}';
	@override String importRowSkipped({required Object count}) => ', ${count} übersprungen';
	@override String get importSuccess => 'Import erfolgreich abgeschlossen!';
	@override String get importSummaryDone => 'Super!';
	@override String get importSummaryMerged => 'Deine Daten wurden mit dem Backup zusammengeführt. Zusammenfassung:';
	@override String get importSummaryReplaced => 'Deine Daten wurden durch das Backup ersetzt. Zusammenfassung:';
	@override String get importSummaryTitle => 'Importübersicht';
	@override String get insightsAndReports => 'Insights und Berichte';
	@override String get language => 'Sprache';
	@override late final _Translations$settingsPage$languageOptions$de languageOptions = _Translations$settingsPage$languageOptions$de._(_root);
	@override String get manageSubscription => 'Abonnement verwalten';
	@override String get manageSubscriptionDetail => 'Öffnet die Abonnementverwaltung des Apple-Kontos.';
	@override String get milestones => 'Meilensteine';
	@override String get milestonesDetail => 'Feiern beim Erreichen wichtiger Meilensteine.';
	@override String get morningBriefTime => 'Uhrzeit des Morgenbriefings';
	@override String get nativeDeliveryTitle => 'Native Zustellung je nach Betriebssystem';
	@override String get newPassword => 'Neues Passwort';
	@override String get newPasswordMinLength => 'Das neue Passwort muss mindestens 8 Zeichen lang sein.';
	@override String get nextRenewal => 'Nächste Verlängerung';
	@override String get notAuthenticated => 'Nicht authentifiziert';
	@override String get notificationPermissionsDenied => 'Berechtigung nicht erteilt. Du kannst sie in den Systemeinstellungen ändern.';
	@override String get notificationPermissionsGranted => 'Berechtigungen für dieses System verfügbar.';
	@override String get notificationPermissionsTitle => 'Benachrichtigungsberechtigungen';
	@override String get notifications => 'Benachrichtigungen';
	@override String get notificationsPaneSubtitle => 'Alles, was dich unterbrechen kann.';
	@override String get notificationsSubtitle => 'Betriebshinweise des Desktop-Clients';
	@override String get operationFailed => 'Vorgang fehlgeschlagen.';
	@override String get operationalReminders => 'Betriebshinweise';
	@override String get pageSubtitle => 'Verwalte dein Profil, das Desktop-Verhalten, den Datenschutz und den Evolve-Plan.';
	@override String get pageTitle => 'Einstellungen';
	@override String get passwordUpdateFailed => 'Aktualisierung fehlgeschlagen. Überprüfe dein aktuelles Passwort.';
	@override String get passwordsDontMatch => 'Die Passwörter stimmen nicht überein';
	@override String get paymentMethod => 'Zahlungsmethode';
	@override String get paymentMethodValue => 'Apple Pay / App Store';
	@override String get perHabitRemindersNote => 'Erinnerungen für einzelne Gewohnheiten stellst du bei der jeweiligen Gewohnheit ein; diese Schalter ändern daran nichts.';
	@override String perMonth({required Object price}) => '${price} pro Monat';
	@override String perMonthWithSavings({required Object price, required Object percent}) => '${price} pro Monat · Spare ${percent} %';
	@override String get personalInfo => 'Persönliche Informationen';
	@override String get personalInfoDetail => 'Vorname, Nachname, E-Mail und Geburtsdatum';
	@override String get planAnnual => 'Jährlich';
	@override String get planLabel => 'Plan';
	@override String get planManagement => 'Planverwaltung';
	@override String get planMonthly => 'Monatlich';
	@override String get priceUnavailable => 'Preis nicht verfügbar';
	@override String get privacyPaneSubtitle => 'Was Evolve sehen kann und wer es sonst öffnen darf.';
	@override String get privacyPolicy => 'Datenschutzerklärung';
	@override String get privacySubtitle => 'Zugriffsschutz, Einwilligungen und Datenverwaltung';
	@override String get privacyTitle => 'Datenschutz und Sicherheit';
	@override String get privateMode => 'Privater Modus';
	@override String get privateModeDataProtected => 'Deine Daten sind geschützt und werden nur auf diesem Gerät gespeichert.';
	@override String get proActiveMessage => 'Dein Abo ist aktiv. Der AI Coach ist enthalten — ohne OpenRouter-Konto und ohne API-Schlüssel — zusammen mit erweiterten Trendstatistiken und allen Werkzeugen von Evolve für persönliches Wachstum.';
	@override String get proActiveName => 'Evolve PRO aktiv';
	@override String get proName => 'Evolve PRO';
	@override String get proStartJourney => 'Starte deinen Weg';
	@override String get proSubtitle => 'Plan, Kaufwiederherstellung und Abonnementverwaltung';
	@override String get proThankYou => 'Danke, dass du die Entwicklung von Evolve unterstützt.';
	@override String get proTitle => 'Evolve Pro';
	@override String get proUpsellSubtitle => 'Schalte alle Funktionen frei und beschleunige dein Wachstum.';
	@override String get proUpsellTitle => 'Zu Evolve PRO wechseln';
	@override String get proWelcomeTitle => 'Willkommen bei Evolve PRO';
	@override String get profileFallback => 'Profil';
	@override String get profileLabel => 'Profil';
	@override String get profileSubtitle => 'Persönliche Informationen und Synchronisierungsstatus';
	@override String get railGroupApp => 'App';
	@override String get railGroupData => 'Daten';
	@override String get railGroupYou => 'Du';
	@override String get renewalDisclaimer => 'Das Abonnement verlängert sich automatisch, sofern die automatische Verlängerung nicht mindestens 24 Stunden vor Ablauf des Zeitraums in den Apple-Kontoeinstellungen deaktiviert wird.';
	@override String get requestNotificationPermissions => 'Benachrichtigungsberechtigungen anfordern';
	@override String get requestNotificationPermissionsDetail => 'Öffnet die native Eingabeaufforderung auf der unterstützten Plattform.';
	@override String get resetDataAction => 'Daten zurücksetzen';
	@override String get resetDataSuccess => 'Daten erfolgreich gelöscht.';
	@override String get resetDataTitle => 'Daten zurücksetzen';
	@override String get resetTutorial => 'Tutorial zurücksetzen';
	@override String get resetTutorialDetail => 'Öffnet die Schritt-für-Schritt-Anleitungen für Dashboard und Ziele erneut.';
	@override String get restoreDefaults => 'Standardeinstellungen wiederherstellen…';
	@override String get restoreDefaultsDetail => 'Deine Gewohnheiten, Ziele, dein Konto und die App-Sperre bleiben unberührt.';
	@override String get restorePurchases => 'Käufe wiederherstellen';
	@override String get restorePurchasesDetail => 'Stellt ein bereits gekauftes Abonnement wieder her.';
	@override String get reviewInitialConsent => 'Erstzustimmung überprüfen';
	@override String get reviewInitialConsentDetail => 'Bedingungen, Datenschutz, Benachrichtigungen und Absturzberichte';
	@override String get save => 'Speichern';
	@override String get searchClear => 'Suche löschen';
	@override String get searchNoResults => 'Keine Einstellung gefunden';
	@override String get searchPlaceholder => 'Einstellungen durchsuchen';
	@override String get sectionAccount => 'Konto';
	@override String get sectionAdvanced => 'Erweitert';
	@override String get sectionApplication => 'Anwendung';
	@override String get sectionDataBackup => 'Daten & Backup';
	@override String get sectionGeneral => 'Allgemein';
	@override String get sectionPrivacy => 'Datenschutz';
	@override String get sectionPrivacySecurity => 'Datenschutz & Sicherheit';
	@override String get sendCrashReports => 'Absturzberichte senden';
	@override String get sendCrashReportsDetail => 'Gesonderte Einwilligung für Sentry.';
	@override String get sessionUnavailable => 'Sitzung nicht verfügbar';
	@override String get settingSaveFailed => 'Diese Einstellung konnte nicht gespeichert werden. Der vorherige Wert wurde wiederhergestellt.';
	@override String get signOut => 'Vom Konto abmelden';
	@override String get signOutDetailActive => 'Die Sitzung auf diesem Gerät schließen';
	@override String get statusActive => 'Aktiv';
	@override String get statusLabel => 'Status';
	@override String subscribeCta({required Object plan, required Object price}) => 'Abonnieren — ${plan} · ${price}';
	@override String subscribeCtaNoPrice({required Object plan}) => 'Abonnieren — ${plan}';
	@override String get subscription => 'Abonnement';
	@override String get supabaseWithEncryptedCache => 'Supabase mit verschlüsseltem Cache';
	@override String get syncsToIPhoneNote => 'Diese Einstellungen gelten auch auf deinem iPhone.';
	@override String get systemPermissionsManagement => 'Verwaltung der Systemberechtigungen';
	@override String get systemPermissionsManagementDetail => 'Benachrichtigungen, Kalender und Sicherheit.';
	@override String get systemPermissionsOpenFailed => 'Einstellungen konnten nicht geöffnet werden.';
	@override String get systemPermissionsTitle => 'Systemberechtigungen';
	@override String get systemSection => 'System';
	@override String get termsEula => 'Nutzungsbedingungen (EULA)';
	@override String get themeDark => 'Dunkel';
	@override String get themeLight => 'Hell';
	@override String get themeMode => 'Design';
	@override String get themeSystem => 'System folgen';
	@override String get timeFormat24h => '24-Stunden-Format';
	@override String get timeFormat24hDetail => 'Verwende Uhrzeiten wie 20:30 statt 8:30 PM.';
	@override String get tutorialResetMessage => 'Die Anleitungen werden in den entsprechenden Bereichen erneut angezeigt.';
	@override String get tutorialResetTitle => 'Tutorials zurückgesetzt';
	@override String get updateAvatar => 'Avatar aktualisieren';
	@override String get updateAvatarDetail => 'Wähle ein lokales Bild für das Desktop-Profil.';
	@override String get updatePassword => 'Passwort aktualisieren';
	@override String useAccent({required Object hex}) => 'Akzent ${hex} verwenden';
	@override String get verified => 'Verifiziert';
	@override String get weeklyReports => 'Wochenberichte';
	@override String get weeklyReportsDetail => 'Eine wöchentliche Zusammenfassung deiner Fortschritte.';
	@override String get youArePro => 'Du bist PRO-Nutzer';
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
	@override String get subtitle => 'Evolve lädt deine personenbezogenen Daten erst auf einen Server, nachdem du hier zugestimmt hast.';
	@override String get uploadTitle => 'Was diesen Mac verlässt';
	@override String get uploadAccountTitle => 'Mit einem Evolve-Konto';
	@override String get uploadAccountBody => 'Ziele, Gewohnheiten, Stimmungs-Check-ins, deine App-Einstellungen und dein Profil (Name, E-Mail, Geburtsdatum) werden auf die Server von Evolve geladen, um deine Geräte zu synchronisieren. Dein Profilbild bleibt auf diesem Mac.';
	@override String get uploadPrivateTitle => 'Privat auf diesem Mac';
	@override String get uploadPrivateBody => 'zu uns wird nichts hochgeladen; die optionale iCloud-Synchronisierung ist Ende-zu-Ende-verschlüsselt und erreicht nur dein eigenes iCloud-Konto.';
	@override String get uploadNeverTitle => 'Nie abgerufen';
	@override String get uploadNeverBody => 'Kontakte, Kalender, Kamera, Mikrofon, Standort.';
	@override String get acceptTerms => 'Ich akzeptiere die Bedingungen und die Datenschutzrichtlinie';
	@override String get termsSubtitle => 'Ich habe die Dokumente gelesen, bin mindestens 14 Jahre alt und stimme dem oben beschriebenen Hochladen zu.';
	@override String get crashDiagnostics => 'Absturzdiagnose';
	@override String get crashSubtitle => 'Standardmäßig aus. Wenn aktiviert, gehen anonymisierte Absturzberichte an unseren Diagnoseanbieter Sentry.';
	@override String get openPrivacy => 'Datenschutzrichtlinie öffnen';
	@override String get openTerms => 'Nutzungsbedingungen';
	@override String get notificationsTitle => 'Benachrichtigungen aktivieren';
	@override String get notificationsSubtitle => 'Erhalte Gewohnheits-Erinnerungen und Tagesübersichten.';
	@override String get enableNotifications => 'Aktivieren';
	@override String get notificationsEnabled => 'Aktiviert';
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
	@override String get limitReminderBody => 'Bleibst du heute innerhalb deines Limits? Sieh kurz nach, wenn du kannst.';
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
	@override String get loadOffersFailed => 'Abo-Pläne konnten nicht geladen werden. Prüfe deine Verbindung und versuche es erneut.';
	@override String get proActivated => 'Evolve Pro aktiviert.';
	@override String get purchasesRestored => 'Käufe wiederhergestellt.';
	@override String get noActiveSub => 'Kein aktives Pro-Abonnement gefunden.';
	@override String get restoreFailed => 'Käufe konnten nicht wiederhergestellt werden.';
	@override String get configKey => 'In-App-Käufe sind vorübergehend nicht verfügbar.';
	@override String get loginFirst => 'Melde dich an, bevor du Evolve Pro verwaltest.';
	@override String get paidAppsAgreement => 'Die Vereinbarung für kostenpflichtige Apps ist nicht aktiv. Der Kontoinhaber muss die Vereinbarung für kostenpflichtige Apps in App Store Connect akzeptieren.';
	@override String get alreadyPurchased => 'Dieses Abonnement ist bereits gekauft. Verwenden Sie „Käufe wiederherstellen“, um den Pro-Zugriff erneut zu aktivieren.';
	@override String get purchasesNotAllowed => 'In-App-Käufe sind auf diesem Gerät oder Apple-Konto nicht zulässig.';
	@override String get planUnavailable => 'Der ausgewählte Plan ist nicht zum Kauf verfügbar. Versuchen Sie es später noch einmal.';
	@override String get paymentPending => 'Die Zahlung steht aus. Der Pro-Zugang wird aktiviert, wenn Apple die Transaktion bestätigt.';
	@override String get connectionUnavailable => 'Verbindung nicht verfügbar. Überprüfen Sie Ihr Netzwerk und versuchen Sie es erneut.';
	@override String get linkedToAnotherAccount => 'Dieser Kauf ist bereits mit einem anderen Evolve-Konto verknüpft. Melden Sie sich mit diesem Konto an oder wenden Sie sich an den Support.';
	@override String get purchaseInProgress => 'Ein Kaufvorgang ist bereits im Gange. Warten Sie ein paar Sekunden.';
	@override String get restoreInProgress => 'Eine Wiederherstellung wird bereits durchgeführt. Warten Sie ein paar Sekunden.';
	@override String get purchaseFailedMessage => 'Der Kauf konnte nicht abgeschlossen werden. Versuchen Sie es in Kürze noch einmal.';
	@override String get restoreFailedMessage => 'Einkäufe konnten nicht wiederhergestellt werden. Versuchen Sie es in Kürze noch einmal.';
	@override String get purchaseRegisteredNotActive => 'Kauf registriert, aber Pro-Abonnement ist noch nicht aktiv. Warten Sie einige Sekunden und verwenden Sie „Käufe wiederherstellen“.';
	@override String get noActiveSubscription => 'Für diese Apple-ID wurde kein aktives Evolve PRO-Abonnement gefunden. Stelle sicher, dass du dieselbe Apple-ID wie beim Kauf verwendest.';
	@override String get invalidConfig => 'Kaufkonfiguration ungültig. Bitte versuche es später erneut oder kontaktiere den Support.';
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
	@override String get aiCoachTitle => 'AI Coach, ohne Einrichtung';
	@override String get aiCoachDesc => 'Wir betreiben ihn mit unserem Schlüssel: kein API-Schlüssel zu besorgen, kein zweites Konto. Lieber dein eigenes OpenRouter-Konto? Das ist ebenfalls kostenlos.';
	@override String get statsTitle => 'Gewohnheitsspezifische Statistiken';
	@override String get statsDesc => 'Wichtige Erkenntnisse zur Steigerung Ihrer Produktivität.';
	@override String get metricsTitle => 'Erweiterte Zielmetriken';
	@override String get metricsDesc => 'Sehen Sie sich detaillierte Diagramme und detaillierte Leistungsstatistiken für jedes Jahr an.';
	@override String get unlimitedTitle => 'Unbegrenzte Gewohnheiten';
	@override String get unlimitedDesc => 'Erstellen und verfolgen Sie alle gewünschten Gewohnheiten ohne Einschränkungen.';
	@override String get maybeLater => 'Vielleicht später';
	@override String get viewPlans => 'Pro-Abos ansehen';
}

// Path: appLogs
class _Translations$appLogs$de extends Translations$appLogs$en {
	_Translations$appLogs$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'App-Protokolle';
	@override String get copiedToClipboard => 'Protokolle in die Zwischenablage kopiert';
	@override String get clearLogsTitle => 'Protokolle löschen';
	@override String get clearLogsConfirm => 'Möchten Sie wirklich alle Protokolleinträge löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
	@override String get clearLogsAction => 'Alle löschen';
	@override String get copyAll => 'Alle Protokolle kopieren';
	@override String get searchPlaceholder => 'Protokolle durchsuchen...';
	@override String get filterAll => 'Alle';
	@override String get filterErrors => 'Fehler';
	@override String get filterWarnings => 'Warnungen';
	@override String get filterInfo => 'Info';
	@override String get emptyTitle => 'Keine Protokolle';
	@override String get emptySubtitle => 'Protokolle werden hier angezeigt, während die App läuft';
	@override String get stackTraceAvailable => 'Tippen für Stack-Trace';
	@override String get detailMessage => 'NACHRICHT';
	@override String get detailError => 'FEHLER';
	@override String get detailExtras => 'Zusätzlicher Kontext';
	@override String get detailStackTrace => 'STACK-TRACE';
	@override String get shareLogs => 'Protokolldatei teilen';
	@override String get exportDone => 'Protokolle exportiert';
}

// Path: coachSettings
class _Translations$coachSettings$de extends Translations$coachSettings$en {
	_Translations$coachSettings$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get accountModeNote => 'Lieber dein eigener OpenRouter-Schlüssel oder ein lokales Modell? Die gibt es im Privaten Modus.';
	@override String activeCloud({required Object model}) => 'Cloud · ${model}';
	@override String activeLocal({required Object model}) => 'Lokal · ${model}';
	@override String get activeLocalNoModel => 'Lokal · Modell wählen';
	@override String activeStandard({required Object model}) => 'Evolve AI · ${model}';
	@override String get backendStandard => 'Evolve AI';
	@override String get baseUrlLabel => 'Basis-URL';
	@override String get cardLive => 'Aktiv';
	@override String get cardOff => 'Aus';
	@override String get cloudKeyMissing => 'Noch kein Schlüssel — diese Engine antwortet nicht. Verbinde unten dein OpenRouter-Konto, wechsle zu Evolve AI oder nutze einen lokalen Server.';
	@override String get detectedAction => 'Lokal verwenden';
	@override String detectedBody({required Object app}) => '${app} läuft auf diesem Mac. Den Coach zu 100 % privat ausführen?';
	@override String get detectedDismiss => 'Jetzt nicht';
	@override String detectedTitle({required Object app}) => '${app} erkannt';
	@override String get discovering => 'Suche nach Modellen…';
	@override String get engineOpenRouter => 'OpenRouter';
	@override String get engineOpenRouterHint => 'Dein eigener Schlüssel · kostenlos';
	@override String getLocalServer({required Object app}) => '${app} installieren';
	@override String get groupEngine => 'Engine';
	@override String get groupPrivacy => 'Datenschutz';
	@override String get groupTuning => 'AI-Coach-Feinabstimmung';
	@override String get lmStudioNoModelsJit => 'LM Studio listet keine Modelle auf. Es listet nur geladene Modelle, wenn Just-In-Time-Laden aus ist — lade ein Modell in LM Studio oder aktiviere Developer → Server Settings → Just In Time Model Loading.';
	@override String get lmStudioServerOffBody => 'LM Studio ist geöffnet, aber sein lokaler Server ist aus. Schalte ihn über Developer → Start Server ein oder aktiviere Settings → Run the LLM server on login.';
	@override String get lmStudioServerOffTitle => 'Der Server von LM Studio läuft nicht';
	@override String get lmStudioStartTimeout => 'Dauert länger als erwartet — öffne LM Studio und prüfe, ob der Start abgeschlossen ist.';
	@override String get localGroupLabel => 'Lokal — auf diesem Mac';
	@override String localServerDownloadFailed({required Object url}) => 'Browser konnte nicht geöffnet werden — besuche ${url}';
	@override String localServerNotInstalledBody({required Object app}) => 'Installiere die kostenlose ${app}-App und drücke dann Start.';
	@override String localServerNotInstalledTitle({required Object app}) => '${app} ist nicht installiert';
	@override String get localServerOfflineBody => 'Starte deinen lokalen Server, um privat zu chatten — ganz ohne Terminal.';
	@override String localServerOfflineTitle({required Object app}) => '${app} läuft nicht';
	@override String localServerStartFailed({required Object app}) => '${app} konnte nicht gestartet werden — versuche, es aus dem Programme-Ordner zu öffnen.';
	@override String get localServerStartingBody => 'Das kann ein paar Sekunden dauern…';
	@override String get manualModelAdd => 'Dieses Modell verwenden';
	@override String get manualModelLabel => 'Modell-ID';
	@override String get modelLabel => 'Modell';
	@override String get noModelsFound => 'Keine Modelle gefunden — gib unten manuell eine Modell-ID ein.';
	@override String get ollamaServerOffBody => 'Ollama ist geöffnet, antwortet aber nicht auf seinem Port. Beende es über die Menüleiste und drücke dann erneut Start.';
	@override String get ollamaServerOffTitle => 'Ollama läuft, antwortet aber nicht';
	@override String get ollamaStartTimeout => 'Dauert länger als erwartet — prüfe das Ollama-Symbol in der Menüleiste (der erste Start braucht evtl. eine Freigabe).';
	@override String get presetLmStudio => 'LM Studio';
	@override String get presetOllama => 'Ollama';
	@override String get refreshModels => 'Modelle aktualisieren';
	@override String get remoteBadge => 'Extern';
	@override String get remoteWarning => 'Dieser Endpunkt ist keine lokale Adresse — Nachrichten verlassen dieses Gerät.';
	@override String get sendMessage => 'Senden';
	@override String get settingsRowConfigure => 'Engine & lokaler Server';
	@override String get settingsRowStatus => 'Aktive Engine';
	@override String get settingsSectionLabel => 'KI-Coach';
	@override String get settingsSubtitle => 'Wähle die Engine für deinen Coach und verbinde sie für volle Privatsphäre mit einem lokalen Server.';
	@override String get standardNeedsProNote => 'Evolve AI ist Teil von Evolve Pro. Schließe ein Abo ab, um es freizuschalten.';
	@override String get standardNeedsSignInNote => 'Melde dich an, um Evolve AI zu nutzen. Dein Abo schaltet es auf allen Geräten frei.';
	@override String get standardPrivateNote => 'Evolve AI braucht ein Evolve-Konto, und der Private Modus führt keines. Verbinde dein OpenRouter-Konto oder nutze ein lokales Modell — beides funktioniert hier weiterhin.';
	@override String get standardStatusNeedsPro => 'Erfordert Pro';
	@override String get standardStatusNeedsSignIn => 'Anmeldung nötig';
	@override String get standardStatusReady => 'In Pro enthalten';
	@override String get standardStatusUnavailable => 'Nicht verfügbar';
	@override String get standardUnavailableNote => 'Evolve AI ist in diesem Build nicht verfügbar. Verbinde dein OpenRouter-Konto oder nutze ein lokales Modell.';
	@override String startLocalServer({required Object app}) => '${app} starten';
	@override String startingLocalServer({required Object app}) => '${app} wird gestartet…';
	@override String get statusChecking => 'Wird geprüft…';
	@override String get statusConnected => 'Verbunden';
	@override String get statusOffline => 'Server offline';
	@override String get stopResponse => 'Stopp';
	@override String get systemPromptHint => 'Coach-Persona überschreiben (leer lassen für Standard)';
	@override String get systemPromptLabel => 'System-Prompt';
	@override String get systemPromptReset => 'Zurücksetzen';
	@override String get temperatureLabel => 'Temperatur';
	@override String get temperatureLower => 'Temperatur senken';
	@override String get temperatureRaise => 'Temperatur erhöhen';
	@override String get tuningFootnote => 'Sie gelten für jede Engine, auch für Evolve AI.';
	@override String get useCustomServer => 'Eigenen Server verwenden…';
}

// Path: tour
class _Translations$tour$de extends Translations$tour$en {
	_Translations$tour$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get back => 'Zurück';
	@override String get next => 'Weiter';
	@override String get continueLabel => 'Weiter';
	@override String get finish => 'Fertig';
	@override String get welcomeTitle => 'Willkommen bei Evolve';
	@override String get welcomeBody => 'Machen wir eine kurze Tour durch deinen Arbeitsbereich — von der täglichen Übersicht bis zu deinem KI-Coach. Es dauert nur einen Moment.';
	@override String get welcomeStart => 'Tour starten';
	@override String get welcomeSkip => 'Tutorial überspringen';
	@override String get doneTitle => 'Alles bereit';
	@override String get doneBody => 'Das ist die ganze App. Starte über die Seitenleiste, wo du willst — und du kannst die Tour jederzeit in den Einstellungen wiederholen.';
	@override String get doneButton => 'Loslegen';
	@override String get overviewOrientationTitle => 'Deine Übersicht';
	@override String get overviewOrientationDesc => 'Das ist deine tägliche Basis — ein Überblick über heute, sobald du Evolve öffnest.';
	@override String get overviewCheckinTitle => 'Täglicher Check-in';
	@override String get overviewCheckinDesc => 'Halte fest, wie dein Tag läuft. Mit der Zeit zeigt sich, wie deine Stimmung mit Gewohnheiten und Zielen zusammenhängt.';
	@override String get overviewHabitsTitle => 'Heutige Gewohnheiten';
	@override String get overviewHabitsDesc => 'Die für heute geplanten Gewohnheiten stehen hier — hake sie nach und nach ab.';
	@override String get overviewGoalsTitle => 'Fokus-Ziele';
	@override String get overviewGoalsDesc => 'Die Ziele, auf die du dich konzentrierst, erscheinen hier, damit nichts untergeht.';
	@override String get habitsOrientationTitle => 'Die Gewohnheiten-Seite';
	@override String get habitsOrientationDesc => 'Hier baust du dein tägliches Protokoll auf und verfolgst deine Beständigkeit.';
	@override String get habitsAddTitle => 'Gewohnheit hinzufügen';
	@override String get habitsAddDesc => 'Erstelle hier eine neue Gewohnheit — mit Name, Kategorie, Farbe und optionaler Erinnerung.';
	@override String get habitsCheckoffTitle => 'Als erledigt markieren';
	@override String get habitsCheckoffDesc => 'Setze hier ein Häkchen, um eine Gewohnheit für heute abzuschließen. Mehr braucht es nicht, um eine Serie am Leben zu halten.';
	@override String get habitsStreakTitle => 'Serien & Verlauf';
	@override String get habitsStreakDesc => 'Sieh deine Serie wachsen und deine letzten sieben Tage auf einen Blick.';
	@override String get habitsCalendarTitle => 'Kalenderansicht';
	@override String get habitsCalendarDesc => 'Wechsle zum Kalender, um deinen Verlauf nach Woche, Monat, Jahr — oder deinem ganzen Leben zu sehen.';
	@override String get insightsOrientationTitle => 'Deine Statistiken';
	@override String get insightsOrientationDesc => 'Sieh, wie sich Gewohnheiten und Ziele über die Zeit entwickeln und wo du abweichst.';
	@override String get insightsFilterTitle => 'Nach Gewohnheit filtern';
	@override String get insightsFilterDesc => 'Konzentriere die Statistik auf eine einzelne Gewohnheit oder behalte den Gesamtüberblick.';
	@override String get insightsTabsTitle => 'Statistik-Bereiche';
	@override String get insightsTabsDesc => 'Wechsle zwischen den Bereichen für Trends, Hinweise, Gewohnheits-Fortschritt und deine Stimmung.';
	@override String get goalsOrientationTitle => 'Die Ziele-Seite';
	@override String get goalsOrientationDesc => 'Setze und verfolge deine größeren Ziele — das, worauf deine täglichen Gewohnheiten hinarbeiten.';
	@override String get goalsPlanTitle => 'Planungsart';
	@override String get goalsPlanDesc => 'Wähle, wie du planst — täglich, wöchentlich oder länger — passend zu deiner Denkweise über Ziele.';
	@override String get goalsAddTitle => 'Ziel hinzufügen';
	@override String get goalsAddDesc => 'Erstelle hier ein neues Ziel und gib ihm eine Vorgabe, auf die du hinarbeitest.';
	@override String get goalsCheckTitle => 'Erreichen oder verfehlen';
	@override String get goalsCheckDesc => 'Markiere ein Ziel als erreicht oder verfehlt. Jedes Ergebnis fließt mit der Zeit in deine Leistung ein.';
	@override String get goalsStatsTitle => 'Leistung';
	@override String get goalsStatsDesc => 'Schalte die Leistungsstatistik ein, um zu sehen, wie du bei deinen Zielen stehst.';
	@override String get coachOrientationTitle => 'Dein KI-Coach';
	@override String get coachOrientationDesc => 'Persönliche Begleitung auf Basis deiner echten Gewohnheiten und Ziele — direkt auf deinem Mac.';
	@override String get coachModelTitle => 'Wähle die Engine';
	@override String get coachModelDesc => 'Wähle das KI-Modell — unsere Cloud oder ein lokales Modell, das privat auf deinem Mac läuft. Auch die Servereinstellungen sind hier.';
	@override String get coachContextTitle => 'Was der Coach sieht';
	@override String get coachContextDesc => 'Bestimme, ob der Coach deine Gewohnheiten und Ziele nutzen darf, um seine Ratschläge anzupassen.';
	@override String get coachSuggestionsTitle => 'Erste Impulse';
	@override String get coachSuggestionsDesc => 'Nicht sicher, wo du anfangen sollst? Tippe auf einen dieser Vorschläge, um loszulegen.';
	@override String get coachInputTitle => 'Frag alles';
	@override String get coachInputDesc => 'Gib hier deine Frage ein und drücke Senden. Damit endet die Tour — viel Freude mit Evolve!';
}

// Path: palette
class _Translations$palette$de extends Translations$palette$en {
	_Translations$palette$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get searchHint => 'Ziele, Gewohnheiten, Einstellungen, Aktionen suchen…';
	@override String get groupSuggested => 'Vorschläge';
	@override String get groupThisWeek => 'Diese Woche';
	@override String get groupGoals => 'Ziele';
	@override String get groupHabits => 'Gewohnheiten';
	@override String get groupActions => 'Aktionen';
	@override String get groupSections => 'Gehe zu';
	@override String get groupSettings => 'Einstellungen';
	@override String get goToThisWeek => 'Zu dieser Woche';
	@override String get createGoalBlank => 'Ziel erstellen';
	@override String createGoal({required Object title}) => 'Ziel „${title}“ erstellen';
	@override String createHabit({required Object title}) => 'Gewohnheit „${title}“ erstellen';
	@override String goToPeriod({required Object period}) => 'Gehe zu ${period}';
	@override String get switchToDark => 'Zum dunklen Design wechseln';
	@override String get switchToLight => 'Zum hellen Design wechseln';
	@override String get manageCategories => 'Zielkategorien verwalten';
	@override String get replayTour => 'Geführte Tour wiederholen';
	@override String noResults({required Object query}) => 'Keine Ergebnisse für „${query}“';
	@override String get rowOpen => 'Öffnen';
	@override String get rowComplete => 'Als erledigt markieren';
	@override String get rowReschedule => 'Auf nächste Periode verschieben';
	@override String get deleteGoalTitle => 'Ziel löschen?';
	@override String deleteGoalMessage({required Object title}) => '„${title}“ wird dauerhaft gelöscht.';
	@override String get deleteHabitTitle => 'Gewohnheit löschen?';
	@override String deleteHabitMessage({required Object title}) => '„${title}“ wird dauerhaft gelöscht.';
	@override String get footerNavigate => 'navigieren';
	@override String get footerOpen => 'öffnen';
	@override String get footerMenu => 'Menü';
	@override String get footerClose => 'schließen';
}

// Path: targets
class _Translations$targets$de extends Translations$targets$en {
	_Translations$targets$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get sectionTitle => 'Ziel';
	@override String get none => 'Einfach';
	@override String get atLeastLabel => 'Erreiche';
	@override String get atMostLabel => 'Bleib unter';
	@override late final _Translations$targets$presets$de presets = _Translations$targets$presets$de._(_root);
	@override late final _Translations$targets$units$de units = _Translations$targets$units$de._(_root);
	@override late final _Translations$targets$entry$de entry = _Translations$targets$entry$de._(_root);
	@override String get amountLabel => 'Erreiche';
	@override String get amountLabelAtMost => 'Bleib unter';
	@override String get stepLabel => 'Schritt';
	@override String stepHint({required Object step}) => 'Jedes + fügt ${step} hinzu';
	@override String rangeError({required Object min, required Object max}) => 'Gib eine Zahl zwischen ${min} und ${max} ein';
	@override String get stepPositiveError => 'Der Schritt muss größer als 0 sein';
	@override String get stepExceedsWarning => 'Ein Tippen würde das ganze Ziel überschreiten';
	@override String notDivisibleWarning({required Object amount, required Object below, required Object above}) => 'Du kannst ${amount} nicht genau treffen — Tippen erreicht ${below}, dann ${above}';
	@override String notDivisibleWarningNoBelow({required Object amount, required Object above}) => 'Du kannst ${amount} nicht genau treffen — das erste Tippen erreicht ${above}';
	@override String tooManyTapsWarning({required Object taps}) => 'Das sind ${taps} Tipp-Vorgänge für einen Tag';
	@override String get confirmTitle => 'Ziel prüfen';
	@override String get confirmAdjust => 'Anpassen';
	@override String get confirmSaveAnyway => 'Trotzdem speichern';
}

// Path: trackingMode
class _Translations$trackingMode$de extends Translations$trackingMode$en {
	_Translations$trackingMode$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Wie wird es erfasst?';
	@override String get checkbox => 'Häkchen';
	@override String get number => 'Zahl';
	@override String get automatic => 'Automatisch';
	@override String get automaticLocked => 'Verifiziert — auf dem iPhone bearbeiten';
}

// Path: verification.compound
class _Translations$verification$compound$de extends Translations$verification$compound$en {
	_Translations$verification$compound$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String summaryAll({required Object count}) => 'Alle ${count} Bedingungen';
	@override String summaryAny({required Object count}) => 'Mind. 1 von ${count} Bedingungen';
}

// Path: verification.templates
class _Translations$verification$templates$de extends Translations$verification$templates$en {
	_Translations$verification$templates$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get steps => 'Schritte';
	@override String get exerciseMinutes => 'Trainingsminuten';
	@override String get activeEnergy => 'Aktive Energie';
	@override String get standHours => 'Stehstunden';
	@override String get distance => 'Distanz';
	@override String get mindfulMinutes => 'Achtsamkeitsminuten';
	@override String get sleepHours => 'Schlafstunden';
	@override String get workout => 'Training';
	@override String get screenTimeTotal => 'Gesamte Gerätenutzung';
	@override String get screenTimeApps => 'Zeit in ausgewählten Apps';
}

// Path: verification.units
class _Translations$verification$units$de extends Translations$verification$units$en {
	_Translations$verification$units$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get minutes => 'Min.';
	@override String get hours => 'Std.';
	@override String get kilocalories => 'kcal';
	@override String get kilometers => 'km';
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
	@override String get pick => 'Auswählen';
	@override String get gotIt => 'Verstanden';
	@override String get done => 'Fertig';
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
	@override String get apiKeyMissingShort => '⚠️ Der AI-Coach braucht deinen eigenen OpenRouter-API-Schlüssel. Füge ihn in den Einstellungen hinzu, um loszulegen.';
	@override String get apiKeyInvalid => '⚠️ OpenRouter hat diesen API-Schlüssel abgelehnt. Prüfe ihn in den Einstellungen oder erstelle einen neuen auf openrouter.ai/keys.';
	@override String get defaultSystemPrompt => 'Du bist der "Discipline Coach", ein virtueller Assistent, der dem Nutzer hilft, diszipliniert zu bleiben, Ziele zu erreichen und gesunde Gewohnheiten aufzubauen. Sei motivierend, aber konkret, direkt und praktisch. Verwende einen professionellen, aber freundlichen Ton.';
	@override String communicationError({required Object code}) => '❌ Fehler bei der Kommunikation mit der AI. (Code: ${code})';
	@override String get connectionError => '❌ Verbindungsfehler. Stelle sicher, dass du online bist, und versuche es erneut.';
	@override String get connectionErrorShort => '❌ Verbindungsfehler.';
	@override String get connectionCheckTimeout => '❌ Fehler: Die Verbindungsprüfung hat zu lange gedauert.';
	@override String get contextTooLong => '⚠️ Diese Unterhaltung ist zu lang für das Modell geworden. Starte oben rechts einen neuen Chat, um fortzufahren.';
	@override String get noInternet => '❌ Fehler: Keine Internetverbindung. Prüfe dein Netzwerk.';
	@override String get serverTimeout => '❌ Fehler: Der Server braucht zu lange für die Antwort. Versuche es erneut.';
	@override String apiError({required Object code}) => '❌ API-Fehler: ${code} (Details in Sentry prüfen)';
}

// Path: ai.apiKey
class _Translations$ai$apiKey$de extends Translations$ai$apiKey$en {
	_Translations$ai$apiKey$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get rowTitle => 'Dein OpenRouter-Konto';
	@override String get description => 'Lieber den Coach über dein eigenes Konto laufen lassen? Verbinde einen OpenRouter-Schlüssel und zahle direkt an den Anbieter — ohne Evolve-Abo. Erstelle einen auf openrouter.ai/keys: Er wird im Schlüsselbund dieses Geräts gespeichert und nur an OpenRouter gesendet.';
	@override String get fieldLabel => 'API-Schlüssel';
	@override String get hint => 'sk-or-v1-…';
	@override String get save => 'Schlüssel speichern';
	@override String get saved => 'API-Schlüssel gespeichert';
	@override String get remove => 'Schlüssel entfernen';
	@override String get removed => 'API-Schlüssel entfernt';
	@override String get removeConfirmTitle => 'API-Schlüssel entfernen?';
	@override String get removeConfirmBody => 'Diese Engine antwortet nicht mehr, bis du wieder ein Konto verbindest. Evolve AI und lokale Modelle sind nicht betroffen.';
	@override String get statusSet => 'Gespeichert';
	@override String get statusMissing => 'Nicht gesetzt';
	@override String get saveFailed => 'Der Schlüssel konnte nicht im Schlüsselbund gespeichert werden. Versuch es noch einmal.';
	@override String get setupTitle => 'OpenRouter-Konto verbinden';
	@override String get setupBody => 'Diese Engine läuft über dein eigenes OpenRouter-Konto. Verbinde es, um zu chatten — oder wechsle zu Evolve AI, in Pro enthalten.';
	@override String get setupAction => 'Konto verbinden';
}

// Path: ai.coachPrompts
class _Translations$ai$coachPrompts$de extends Translations$ai$coachPrompts$en {
	_Translations$ai$coachPrompts$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override late final _Translations$ai$coachPrompts$diagnoseWeakestHabit$de diagnoseWeakestHabit = _Translations$ai$coachPrompts$diagnoseWeakestHabit$de._(_root);
	@override late final _Translations$ai$coachPrompts$goalOnTrack$de goalOnTrack = _Translations$ai$coachPrompts$goalOnTrack$de._(_root);
	@override late final _Translations$ai$coachPrompts$weeklyReviewDown$de weeklyReviewDown = _Translations$ai$coachPrompts$weeklyReviewDown$de._(_root);
	@override late final _Translations$ai$coachPrompts$weeklyReviewUp$de weeklyReviewUp = _Translations$ai$coachPrompts$weeklyReviewUp$de._(_root);
	@override late final _Translations$ai$coachPrompts$protectStreak$de protectStreak = _Translations$ai$coachPrompts$protectStreak$de._(_root);
	@override late final _Translations$ai$coachPrompts$alignHabitsToGoal$de alignHabitsToGoal = _Translations$ai$coachPrompts$alignHabitsToGoal$de._(_root);
	@override late final _Translations$ai$coachPrompts$designHabitForGoal$de designHabitForGoal = _Translations$ai$coachPrompts$designHabitForGoal$de._(_root);
	@override late final _Translations$ai$coachPrompts$raiseTheBar$de raiseTheBar = _Translations$ai$coachPrompts$raiseTheBar$de._(_root);
	@override late final _Translations$ai$coachPrompts$firstStep$de firstStep = _Translations$ai$coachPrompts$firstStep$de._(_root);
	@override late final _Translations$ai$coachPrompts$whatCanYouHelp$de whatCanYouHelp = _Translations$ai$coachPrompts$whatCanYouHelp$de._(_root);
}

// Path: ai.local
class _Translations$ai$local$de extends Translations$ai$local$en {
	_Translations$ai$local$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String notReachable({required Object url}) => '❌ Lokaler KI-Server unter ${url} nicht erreichbar. Stelle sicher, dass Ollama oder LM Studio läuft.';
	@override String get modelMissing => '⚠️ Wähle zuerst ein lokales Modell — öffne oben die Modellauswahl.';
	@override String requestFailed({required Object code}) => '❌ Fehler des lokalen Modells (Code: ${code}).';
	@override String get streamError => '❌ Verbindung zum lokalen Modell fehlgeschlagen.';
	@override String get timeout => '❌ Das lokale Modell braucht zu lange — es wird möglicherweise noch geladen. Versuche es erneut.';
	@override String get modelNotFound => '❌ Dieses Modell ist auf dem Server nicht verfügbar. Öffne die Modellauswahl, um eines zu wählen oder zu laden.';
	@override String authRequired({required Object app}) => '❌ ${app} verweigert die Verbindung — es erfordert ein API-Token. Deaktiviere die Authentifizierung in den Servereinstellungen oder richte Evolve auf einen Server, der keines verlangt.';
	@override String get stillLoading => 'Das Modell wird noch geladen — ein Kaltstart kann eine Weile dauern.';
}

// Path: ai.standard
class _Translations$ai$standard$de extends Translations$ai$standard$en {
	_Translations$ai$standard$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get sessionExpired => '⚠️ Deine Sitzung ist abgelaufen. Melde dich erneut an, um Evolve AI weiter zu nutzen.';
	@override String get needsPro => '⚠️ Evolve AI ist Teil von Evolve Pro. Schließe in den Einstellungen ein Abo ab — oder wechsle die Engine zu deinem eigenen OpenRouter-Konto, das ist kostenlos.';
	@override String get rateLimited => '⚠️ Du hast das Fair-Use-Limit von Evolve AI vorerst erreicht. Versuch es später noch einmal oder wechsle zu deinem eigenen OpenRouter-Konto.';
	@override String get unavailable => '❌ Evolve AI ist gerade nicht verfügbar. Das liegt an uns — bitte versuch es gleich noch einmal.';
}

// Path: ai.consent
class _Translations$ai$consent$de extends Translations$ai$consent$en {
	_Translations$ai$consent$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get allow => 'Erlauben';
	@override String get byokBody => 'Zum Antworten sendet der AI Coach deine Nachricht, deinen Vornamen und den Kontext, den du teilst, über dein eigenes OpenRouter-Konto an OpenRouter, Inc. OpenRouter leitet sie gemäß den Einstellungen deines Kontos an einen Modellanbieter weiter. Du kannst die Einwilligung jederzeit in den Einstellungen widerrufen; alles andere in Evolve funktioniert weiter.';
	@override String get byokTitle => 'Deine Nachrichten an OpenRouter senden?';
	@override String get consentStatusRevoked => 'Nicht erlaubt';
	@override String get consentStopSharing => 'Teilen beenden…';
	@override String get decline => 'Jetzt nicht';
	@override String get privateNote => 'Deine private Datenbank bleibt auf diesem Gerät — nur was du im Chat sendest, verlässt es.';
	@override String get revokeAction => 'Weitergabe beenden';
	@override String get revokeBody => 'Der AI Coach fragt erneut, bevor er etwas sendet. Sonst ändert sich nichts.';
	@override String get revokeTitle => 'Weitergabe an die KI beenden?';
	@override String get rowTitle => 'Datenweitergabe an die KI';
	@override String get standardBody => 'Zum Antworten sendet der AI Coach deine Nachricht, deinen Vornamen und den Kontext, den du teilst, an OpenRouter, Inc., das sie zur Ausführung des Modells an Google LLC (Google AI Studio) weiterleitet. Da dies Googles kostenlose Stufe nutzt, kann Google den Text für begrenzte Zeit speichern und zur Verbesserung seiner Dienste verwenden — er ist nicht so privat wie eine kostenpflichtige Stufe. Du kannst die Einwilligung jederzeit in den Einstellungen widerrufen; alles andere in Evolve funktioniert weiter.';
	@override String get standardTitle => 'Deine Nachrichten an die KI senden?';
	@override String get statusGranted => 'Erlaubt';
	@override String get statusNone => 'Nicht erlaubt';
}

// Path: settingsPage.calendarViewOptions
class _Translations$settingsPage$calendarViewOptions$de extends Translations$settingsPage$calendarViewOptions$en {
	_Translations$settingsPage$calendarViewOptions$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get month => 'Monat';
	@override String get week => 'Woche';
	@override String get year => 'Jahr';
	@override String get life => 'Leben';
}

// Path: settingsPage.languageOptions
class _Translations$settingsPage$languageOptions$de extends Translations$settingsPage$languageOptions$en {
	_Translations$settingsPage$languageOptions$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get system => 'System';
	@override String get italian => 'Italienisch';
	@override String get english => 'Englisch';
	@override String get spanish => 'Spanisch';
	@override String get german => 'Deutsch';
	@override String get arabic => 'Arabisch';
}

// Path: targets.presets
class _Translations$targets$presets$de extends Translations$targets$presets$en {
	_Translations$targets$presets$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override late final _Translations$targets$presets$countDaily$de countDaily = _Translations$targets$presets$countDaily$de._(_root);
	@override late final _Translations$targets$presets$durationDaily$de durationDaily = _Translations$targets$presets$durationDaily$de._(_root);
	@override late final _Translations$targets$presets$limitCountDaily$de limitCountDaily = _Translations$targets$presets$limitCountDaily$de._(_root);
	@override late final _Translations$targets$presets$limitDurationDaily$de limitDurationDaily = _Translations$targets$presets$limitDurationDaily$de._(_root);
}

// Path: targets.units
class _Translations$targets$units$de extends Translations$targets$units$en {
	_Translations$targets$units$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get min => 'Min.';
	@override String get hour => 'Std.';
	@override String get kcal => 'kcal';
	@override String get km => 'km';
}

// Path: targets.entry
class _Translations$targets$entry$de extends Translations$targets$entry$en {
	_Translations$targets$entry$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get keepGoing => 'Weiter so';
	@override String get withinLimit => 'Innerhalb des Limits';
	@override String get overLimit => 'Über dem Limit';
}

// Path: ai.coachPrompts.diagnoseWeakestHabit
class _Translations$ai$coachPrompts$diagnoseWeakestHabit$de extends Translations$ai$coachPrompts$diagnoseWeakestHabit$en {
	_Translations$ai$coachPrompts$diagnoseWeakestHabit$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get label => '🩺 Meine schwächste Gewohnheit fixen';
	@override String payload({required Object habit, required Object done, required Object scheduled}) => '\'${habit}\' ist diese Woche meine schwächste Gewohnheit — ${done}/${scheduled} Tage geschafft. Was ist der wahrscheinlichste Grund, warum ich sie auslasse, und zwei konkrete Lösungen für diese Woche?';
}

// Path: ai.coachPrompts.goalOnTrack
class _Translations$ai$coachPrompts$goalOnTrack$de extends Translations$ai$coachPrompts$goalOnTrack$en {
	_Translations$ai$coachPrompts$goalOnTrack$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get label => '🎯 Bin ich auf Kurs?';
	@override String payload({required Object goal}) => 'Sei ehrlich, was mein Ziel \'${goal}\' angeht: Bin ich auf Kurs, es zu erreichen, und welche eine Änderung würde meine Chancen am meisten verbessern?';
}

// Path: ai.coachPrompts.weeklyReviewDown
class _Translations$ai$coachPrompts$weeklyReviewDown$de extends Translations$ai$coachPrompts$weeklyReviewDown$en {
	_Translations$ai$coachPrompts$weeklyReviewDown$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get label => '📉 Meine Woche auswerten';
	@override String payload({required Object thisPct, required Object lastPct}) => 'Meine Konstanz ist diese Woche auf ${thisPct}% gefallen, von ${lastPct}% in der Vorwoche. Was ist die wahrscheinlichste Ursache und die eine Änderung für nächste Woche?';
}

// Path: ai.coachPrompts.weeklyReviewUp
class _Translations$ai$coachPrompts$weeklyReviewUp$de extends Translations$ai$coachPrompts$weeklyReviewUp$en {
	_Translations$ai$coachPrompts$weeklyReviewUp$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get label => '📊 Meine Woche auswerten';
	@override String payload({required Object thisPct, required Object lastPct}) => 'Meine Konstanz liegt diese Woche bei ${thisPct}% gegenüber ${lastPct}% in der Vorwoche. Was funktioniert, und was ist die eine Sache, die ich nächste Woche stärker vorantreiben sollte?';
}

// Path: ai.coachPrompts.protectStreak
class _Translations$ai$coachPrompts$protectStreak$de extends Translations$ai$coachPrompts$protectStreak$en {
	_Translations$ai$coachPrompts$protectStreak$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get label => '🛡️ Meine Serie schützen';
	@override String payload({required Object habit, required Object days}) => 'Meine längste aktive Serie ist \'${habit}\' mit ${days} Tagen. Was ist das größte Risiko, sie zu brechen, und wie schütze ich sie diese Woche?';
}

// Path: ai.coachPrompts.alignHabitsToGoal
class _Translations$ai$coachPrompts$alignHabitsToGoal$de extends Translations$ai$coachPrompts$alignHabitsToGoal$en {
	_Translations$ai$coachPrompts$alignHabitsToGoal$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get label => '🔗 Welche Gewohnheiten dienen meinen Zielen?';
	@override String payload({required Object goal}) => 'Wenn ich meine Gewohnheiten mit meinem Ziel \'${goal}\' vergleiche: Welche bringen es wirklich voran und welche sind nur Ballast? Sei konkret und nenne eine Gewohnheit, die mir fehlen könnte.';
}

// Path: ai.coachPrompts.designHabitForGoal
class _Translations$ai$coachPrompts$designHabitForGoal$de extends Translations$ai$coachPrompts$designHabitForGoal$en {
	_Translations$ai$coachPrompts$designHabitForGoal$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get label => '💡 Ein Ziel in eine Gewohnheit verwandeln';
	@override String payload({required Object goal}) => 'Ich will mein Ziel \'${goal}\' erreichen. Welche einzelne tägliche Gewohnheit hätte die größte Wirkung? Gib mir eine konkrete Gewohnheit, die ich morgen anfangen kann.';
}

// Path: ai.coachPrompts.raiseTheBar
class _Translations$ai$coachPrompts$raiseTheBar$de extends Translations$ai$coachPrompts$raiseTheBar$en {
	_Translations$ai$coachPrompts$raiseTheBar$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get label => '🚀 Die Latte höher legen';
	@override String get payload => 'Ich schaffe alle meine Gewohnheiten und meine Ziele sind auf Kurs. Wo werde ich vielleicht nachlässig, und wie lege ich die Latte höher, ohne auszubrennen?';
}

// Path: ai.coachPrompts.firstStep
class _Translations$ai$coachPrompts$firstStep$de extends Translations$ai$coachPrompts$firstStep$en {
	_Translations$ai$coachPrompts$firstStep$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get label => '🌱 Wo fange ich an?';
	@override String get payload => 'Ich fange gerade erst an und habe noch keine Ziele oder Gewohnheiten eingerichtet. Schlage mir ein realistisches erstes Ziel und eine kleine tägliche Gewohnheit dafür vor und erkläre, warum diese Kombination funktioniert.';
}

// Path: ai.coachPrompts.whatCanYouHelp
class _Translations$ai$coachPrompts$whatCanYouHelp$de extends Translations$ai$coachPrompts$whatCanYouHelp$en {
	_Translations$ai$coachPrompts$whatCanYouHelp$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get label => '💬 Womit kannst du helfen?';
	@override String get payload => 'Gib mir auf Basis meiner Gewohnheiten und Ziele in dieser App drei konkrete Beispiele, wie du mir helfen kannst — keine allgemeinen Ratschläge, sondern Dinge, die mit meinen echten Daten zu tun haben.';
}

// Path: targets.presets.countDaily
class _Translations$targets$presets$countDaily$de extends Translations$targets$presets$countDaily$en {
	_Translations$targets$presets$countDaily$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get label => 'Anzahl';
	@override String get description => 'Erledige es eine bestimmte Anzahl pro Tag.';
}

// Path: targets.presets.durationDaily
class _Translations$targets$presets$durationDaily$de extends Translations$targets$presets$durationDaily$en {
	_Translations$targets$presets$durationDaily$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get label => 'Dauer';
	@override String get description => 'Verbringe eine bestimmte Anzahl Minuten pro Tag.';
}

// Path: targets.presets.limitCountDaily
class _Translations$targets$presets$limitCountDaily$de extends Translations$targets$presets$limitCountDaily$en {
	_Translations$targets$presets$limitCountDaily$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get label => 'Limit';
	@override String get description => 'Bleib täglich unter einer bestimmten Anzahl.';
}

// Path: targets.presets.limitDurationDaily
class _Translations$targets$presets$limitDurationDaily$de extends Translations$targets$presets$limitDurationDaily$en {
	_Translations$targets$presets$limitDurationDaily$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get label => 'Zeitlimit';
	@override String get description => 'Bleib täglich unter einer bestimmten Minutenzahl.';
}

/// The flat map containing all translations for locale <de>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsDe {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'verification.autoVerified' => 'Automatisch geprüft',
			'verification.compound.summaryAll' => ({required Object count}) => 'Alle ${count} Bedingungen',
			'verification.compound.summaryAny' => ({required Object count}) => 'Mind. 1 von ${count} Bedingungen',
			'verification.templates.steps' => 'Schritte',
			'verification.templates.exerciseMinutes' => 'Trainingsminuten',
			'verification.templates.activeEnergy' => 'Aktive Energie',
			'verification.templates.standHours' => 'Stehstunden',
			'verification.templates.distance' => 'Distanz',
			'verification.templates.mindfulMinutes' => 'Achtsamkeitsminuten',
			'verification.templates.sleepHours' => 'Schlafstunden',
			'verification.templates.workout' => 'Training',
			'verification.templates.screenTimeTotal' => 'Gesamte Gerätenutzung',
			'verification.templates.screenTimeApps' => 'Zeit in ausgewählten Apps',
			'verification.units.minutes' => 'Min.',
			'verification.units.hours' => 'Std.',
			'verification.units.kilocalories' => 'kcal',
			'verification.units.kilometers' => 'km',
			'macroTargets.sectionTitle' => 'Numerisches Ziel',
			'macroTargets.none' => 'Keins',
			'macroTargets.amountLabel' => 'Zielwert',
			'macroTargets.linkLabel' => 'Mit einer Gewohnheit verknüpfen',
			'macroTargets.manual' => 'Manuell',
			'macroTargets.unitCount' => 'Anzahl',
			'macroTargets.reached' => 'Erreicht',
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
			'privateData.deleteTitle' => 'Private Daten löschen',
			'privateData.deleteMessage' => 'Möchtest du wirklich die gesamte verschlüsselte lokale Datenbank löschen? Dieser Vorgang ist unwiderruflich und die Daten können nicht wiederhergestellt werden.',
			'privateData.deleteSuccess' => 'Private Daten gelöscht.',
			'privateData.deleteFailed' => 'Vorgang fehlgeschlagen.',
			'privateData.exportDoneTitle' => 'Export abgeschlossen',
			'privateData.exportDoneClipboard' => 'Das JSON ist in der Zwischenablage: Linux unterstützt keine Dateifreigabe.',
			'privateData.exportDoneShare' => 'Das JSON wurde an die Teilen-Auswahl gesendet.',
			'icloudSync.bannerAction' => 'Aktivieren',
			'icloudSync.bannerText' => 'iCloud-Sync ist aus — deine Gewohnheiten liegen nur auf diesem Gerät und gehen verloren, wenn du es zurücksetzt oder ersetzt.',
			'icloudSync.deleteSyncNote' => 'Die iCloud-Synchronisierung ist aktiv: Dabei wird auch die synchronisierte Kopie in deiner iCloud gelöscht und die Synchronisierung deaktiviert. Andere Geräte behalten ihre lokale Kopie — führe dies auf jedem Gerät aus, um überall zu löschen.',
			'icloudSync.detailsAllSynced' => 'Alles hochgeladen',
			'icloudSync.detailsCopied' => 'Bericht kopiert',
			'icloudSync.detailsCopy' => 'Bericht kopieren',
			'icloudSync.detailsFailed' => ({required Object count}) => '${count} Elemente konnten nicht hochgeladen werden',
			'icloudSync.detailsPending' => ({required Object count}) => '${count} Elemente warten auf den Upload',
			'icloudSync.detailsTitle' => 'Synchronisierungsdetails',
			'icloudSync.disclosureAccept' => 'Aktivieren',
			'icloudSync.disclosureBody' => 'Deine privaten Daten werden ausschließlich über deinen eigenen iCloud-Account synchronisiert, Ende-zu-Ende-verschlüsselt — niemals über unsere Server. Der Verschlüsselungsschlüssel liegt in deinem iCloud-Schlüsselbund; wenn du den iCloud-Schlüsselbund deaktivierst, können synchronisierte Daten nicht wiederhergestellt werden.',
			'icloudSync.disclosureTitle' => 'Ende-zu-Ende-verschlüsselt',
			'icloudSync.enableTitle' => 'iCloud-Synchronisierung aktivieren',
			'icloudSync.forceEnable' => 'Neu beginnen',
			'icloudSync.forceEnableBody' => 'Die Daten eines anderen Geräts sind bereits in iCloud, aber dessen Verschlüsselungsschlüssel hat dieses Gerät noch nicht erreicht. Meist genügt es, ein paar Minuten zu warten. Ein Neuanfang löscht, was in iCloud liegt, und ersetzt es durch die Daten dieses Geräts. Dies kann nicht rückgängig gemacht werden.',
			'icloudSync.forceEnableTitle' => 'Mit diesem Gerät neu beginnen',
			'icloudSync.keySplitBody' => ({required Object count}) => '${count} Einträge in iCloud wurden auf einem anderen Gerät mit einem anderen Schlüssel verschlüsselt, daher kann dieses Gerät sie nicht lesen. Setze die Synchronisierung von dem Gerät aus zurück, das die Daten enthält, die du behalten möchtest.',
			'icloudSync.keySplitTitle' => 'Einige iCloud-Daten sind nicht lesbar',
			'icloudSync.lastSyncedAt' => ({required Object time}) => 'Zuletzt synchronisiert ${time}',
			'icloudSync.lastSyncedNever' => 'Noch nie synchronisiert',
			'icloudSync.resetFromDevice' => 'Synchronisierung von diesem Gerät zurücksetzen',
			'icloudSync.resetFromDeviceConfirm' => 'Dies löscht alles, was derzeit in iCloud gespeichert ist, und lädt stattdessen die Daten dieses Geräts hoch. Deine anderen Geräte laden anschließend diese Kopie herunter. Führe dies nur auf dem Gerät aus, das die Daten enthält, die du behalten möchtest. Dies kann nicht rückgängig gemacht werden.',
			'icloudSync.resetFromDeviceDetail' => 'Alles in iCloud durch die Daten dieses Geräts ersetzen',
			'icloudSync.resetFromDeviceDone' => 'Synchronisierung zurückgesetzt. Die Daten dieses Geräts sind jetzt die Kopie in iCloud.',
			'icloudSync.statusIdle' => 'Aktuell',
			'icloudSync.statusNoAccount' => 'Bei iCloud anmelden, um zu synchronisieren',
			'icloudSync.statusNotSynced' => 'Es wurde nicht alles synchronisiert',
			'icloudSync.statusOff' => 'Synchronisierung aus',
			'icloudSync.statusSyncing' => 'Synchronisiere…',
			'icloudSync.statusUnavailable' => 'iCloud ist derzeit nicht verfügbar',
			'icloudSync.statusWaitingKey' => 'Warten auf den Verschlüsselungsschlüssel von deinem anderen Gerät',
			'icloudSync.statusWaitingKeychain' => 'Warte auf den iCloud-Schlüsselbund — stelle sicher, dass die App auf deinem iPhone aktuell ist',
			'icloudSync.syncNow' => 'Jetzt synchronisieren',
			'icloudSync.syncNowNeedsSync' => 'Schalte zuerst die iCloud-Synchronisierung ein.',
			'icloudSync.title' => 'iCloud-Synchronisierung',
			'icloudSync.unavailablePlatform' => 'Auf diesem Gerät nicht verfügbar',
			'privateRecovery.preparing' => 'Dein privater Bereich wird vorbereitet…',
			'privateRecovery.restoredFromCloudToast' => 'Lokale Datenbank konnte nicht entsperrt werden – deine Daten wurden aus iCloud wiederhergestellt.',
			'privateRecovery.waitingTitle' => 'Warten auf iCloud',
			'privateRecovery.waitingMessage' => 'Die Synchronisierung ist aktiv, aber dein Verschlüsselungsschlüssel ist noch nicht aus dem iCloud-Schlüsselbund eingetroffen. Warte einen Moment und versuche es erneut.',
			'privateRecovery.lockedTitle' => 'Private Daten können nicht entsperrt werden',
			'privateRecovery.lockedMessageLocalOnly' => 'Dieses Gerät kann deine lokale private Datenbank nicht entsperren – der Verschlüsselungsschlüssel fehlt – und die iCloud-Synchronisierung ist aus, es gibt also keine Cloud-Kopie zum Wiederherstellen. Du kannst zurücksetzen und neu beginnen.',
			'privateRecovery.lockedMessageICloudUnavailable' => 'Dieses Gerät kann deine lokale private Datenbank nicht entsperren. Die iCloud-Synchronisierung ist aktiv, aber das Konto ist nicht verfügbar – melde dich bei iCloud an und versuche es erneut.',
			'privateRecovery.errorTitle' => 'Privater Modus konnte nicht geöffnet werden',
			'privateRecovery.errorMessage' => 'Beim Öffnen deiner privaten Datenbank ist etwas schiefgelaufen. Versuche es erneut oder kehre zur Anmeldung zurück.',
			'privateRecovery.enableSyncHint' => 'Hast du diese Daten auf einem anderen Gerät? Aktiviere nach dem Zurücksetzen die iCloud-Synchronisierung in den Einstellungen, um sie hierher zu holen.',
			'privateRecovery.retry' => 'Erneut versuchen',
			'privateRecovery.resetFresh' => 'Zurücksetzen und neu beginnen',
			'privateRecovery.backToSignIn' => 'Zurück zur Anmeldung',
			'privateRecovery.undecryptableTitle' => 'Deine Daten sind sicher – aber diese Version der App kann sie nicht entsperren',
			'privateRecovery.undecryptableMessage' => 'Die private Datenbank auf diesem Mac ist unversehrt; sie ist lediglich mit einem anderen Schlüssel verschlüsselt als dem, den dieser Build besitzt. Es wurde nichts geändert oder gelöscht. Meist bedeutet das, dass sie von einem anderen Evolve-Build (etwa einem Entwicklungs-Build) erstellt wurde. Öffne diesen Build, um an die Daten zu kommen, oder stelle bei einer Neuinstallation aus iCloud wieder her.',
			'privateRecovery.schemaTooNewTitle' => 'Diese Datenbank stammt aus einer neueren Version',
			'privateRecovery.schemaTooNewMessage' => 'Deine privaten Daten wurden zuletzt mit einer neueren Version von Evolve geöffnet und sind vollständig intakt. Diese ältere Version kann sie nicht sicher lesen. Aktualisiere auf die neueste Version – oder öffne den neueren Build erneut – und alles ist wieder da.',
			'privateRecovery.copyDiagnostics' => 'Diagnose kopieren',
			'privateRecovery.diagnosticsCopied' => 'Diagnose in die Zwischenablage kopiert',
			'privateRecovery.resetConfirmTitle' => 'Diese Datenbank beiseitelegen?',
			'privateRecovery.resetConfirmBody' => 'Evolve startet mit einer leeren privaten Datenbank. Deine vorhandene verschlüsselte Datei bleibt auf diesem Mac erhalten und wird nicht gelöscht – sie kann also weiterhin wiederhergestellt werden.',
			'privateRecovery.resetConfirmBodySized' => ({required Object size}) => 'Evolve startet mit einer leeren privaten Datenbank. Deine vorhandene verschlüsselte Datei (${size}) bleibt auf diesem Mac erhalten und wird nicht gelöscht – sie kann also weiterhin wiederhergestellt werden.',
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
			'common.actions.pick' => 'Auswählen',
			'common.actions.gotIt' => 'Verstanden',
			'common.actions.done' => 'Fertig',
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
			'common.unexpectedErrorTitle' => 'Etwas ist schiefgelaufen',
			'common.unexpectedErrorMessage' => 'Ein unerwarteter Fehler ist aufgetreten. Bitte versuche es erneut.',
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
			'createGoal.periodWhen' => 'Wann',
			'createHabit.title' => 'Neue Gewohnheit',
			'createHabit.subtitle' => 'Definiere deine neue Gewohnheit.',
			'createHabit.titleHint' => 'z. B. Meditation',
			'createHabit.weeklyFrequency' => 'Wöchentliche Häufigkeit',
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
			'macroGoals.archiveCategory2' => 'Kategorie archivieren',
			'macroGoals.categoryUnavailableLinked' => ({required Object label, required Object count}) => 'Die Kategorie „${label}" ist für neue Ziele nicht mehr verfügbar, bleibt aber mit ${count} bisherigen Zielen und deinen Statistiken verknüpft.',
			'macroGoals.categoryUnavailableArchived' => ({required Object label}) => 'Die Kategorie „${label}" ist für neue Ziele nicht mehr verfügbar, bleibt aber in deinem Verlauf.',
			'macroGoals.archive' => 'Archivieren',
			'macroGoals.createNewCategory' => 'Neue Kategorie erstellen',
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
			'dashboard.goodAfternoon' => 'Guten Nachmittag',
			'dashboard.goodEvening' => 'Guten Abend',
			'dashboard.manager' => 'Verwaltung',
			'dashboard.aiChat' => 'AI-Chat',
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
			'stats.sortRate' => 'Quote',
			'stats.sortStreak' => 'Serie',
			'stats.sortName' => 'Name',
			'stats.filterActive' => 'Aktiv',
			'stats.filterAll' => 'Alle',
			'stats.noActiveHabits' => 'Keine aktiven Gewohnheiten – wechsle zu Alle, um beendete anzuzeigen.',
			'stats.worstStreakLabel' => 'Schlechteste',
			'stats.momentumTitle' => 'Momentum',
			'stats.momentumSubtitle' => 'Deine aktuelle Form',
			'stats.momentumForm' => 'FORM',
			'stats.momentumRate' => '7 Tage',
			'stats.momentumStreakHealth' => 'Serien',
			'stats.momentumTrend' => 'Trend',
			'stats.rollingImproving' => 'Steigend',
			'stats.rollingDeclining' => 'Fallend',
			'stats.rollingSteady' => 'Stabil',
			'stats.lifetimeConsistency' => 'Beständigkeit',
			'stats.lifetimeConsistencyDetail' => 'Gesamtabschluss',
			'stats.lifetimeTotalDone' => 'Gesamt erledigt',
			'stats.lifetimeTotalDoneDetail' => 'Abgehakte Gewohnheiten',
			'stats.lifetimePerfectDays' => 'Perfekte Tage',
			'stats.lifetimePerfectDaysDetail' => 'Alles erledigt',
			'stats.lifetimeDaysTracked' => 'Erfasste Tage',
			'stats.lifetimeDaysTrackedDetail' => 'Seit dem Start',
			'stats.keystoneTitle' => 'SCHLÜSSELGEWOHNHEIT',
			'stats.keystoneImpact' => ({required Object withPct, required Object withoutPct}) => 'An ihren Tagen erreichst du ${withPct}% deiner anderen Gewohnheiten, sonst ${withoutPct}%.',
			'stats.yearActivity' => '365-Tage-Aktivität',
			'stats.yearActivitySubtitle' => 'Jede Gewohnheit, jeden Tag',
			'stats.activeDaysCount' => ({required Object count}) => '${count} aktive Tage',
			'stats.heatmapLess' => 'Weniger',
			'stats.heatmapMore' => 'Mehr',
			'stats.bestHabitsTitle' => 'Beste Gewohnheiten',
			'stats.criticalHabitsTitle' => 'Braucht Aufmerksamkeit',
			'stats.criticalStalled' => ({required Object days}) => '${days}T untätig',
			'stats.rollingTitle' => 'Gleitender Abschluss',
			'stats.rollingSubtitle' => '7- und 30-Tage-Rate',
			'stats.rolling7' => '7 Tage',
			'stats.rolling30' => '30 Tage',
			'stats.weekVsAvgTitle' => 'Diese Woche vs. Schnitt',
			'stats.weekVsAvgSubtitle' => 'Wie diese Woche abschneidet',
			'stats.thisWeek' => 'Diese Woche',
			'stats.yourAverage' => 'Dein Durchschnitt',
			'stats.weekdayShapeTitle' => 'Wochenrhythmus',
			'stats.weekdayShapeSubtitle' => 'Abschluss nach Wochentag',
			'stats.weekdayWeekendTitle' => 'Woche vs. Wochenende',
			'stats.weekdayWeekendSubtitle' => 'Wo du am stärksten bist',
			'stats.weekdaysLabel' => 'Wochentage',
			'stats.weekendLabel' => 'Wochenende',
			'stats.seasonalityTitle' => 'Saisonalität',
			'stats.seasonalitySubtitle' => 'Abschluss nach Monat',
			'stats.bounceBackTitle' => 'Erholungsrate',
			'stats.bounceBackSubtitle' => 'Comeback nach einem Aussetzer',
			'stats.bounceBackDetail' => ({required Object recoveries, required Object opportunities}) => '${recoveries} von ${opportunities} Malen erholt',
			'stats.dangerZoneTitle' => 'Gefahrenzone',
			'stats.dangerZoneSubtitle' => 'Wann Serien reißen',
			'stats.dangerZoneNone' => 'Noch keine gerissenen Serien',
			'stats.dangerZoneDetail' => ({required Object breaks, required Object total}) => '${breaks} von ${total} Brüchen hier',
			'stats.performanceComparisonTitle' => 'Leistungsvergleich',
			'stats.performanceComparisonSubtitle' => 'Beste vs. schlechteste Serie',
			'stats.perfCompGap' => ({required Object pct}) => '${pct}% Abstand',
			'stats.perfCompBest' => 'Beste',
			'stats.perfCompWorst' => 'Schlechteste',
			'stats.consistencyTitle' => 'Beständigkeit',
			'stats.consistencySubtitle' => 'Regelmäßigste Gewohnheiten',
			'stats.consistencySteadiest' => 'Am stetigsten',
			'stats.consistencyErratic' => 'Am unregelmäßigsten',
			'stats.medalsTitle' => 'Serien-Rangliste',
			'stats.medalsSubtitle' => 'Längste aktuelle Serien',
			'stats.neverMissedTitle' => 'Nie verpasst',
			'stats.neverMissedEmpty' => 'Noch keine perfekten Gewohnheiten',
			'stats.distributionTitle' => 'Verteilung',
			'stats.distributionSubtitle' => 'Gewohnheiten nach Erfolgsrate',
			'stats.synergyTitle' => 'Gewohnheits-Synergie',
			'stats.synergySubtitle' => 'Welche Gewohnheiten zusammen laufen',
			'stats.moodSensitiveTitle' => 'Stimmungsabhängig',
			'stats.moodSensitiveSubtitle' => 'Am meisten von der Stimmung beeinflusst',
			'stats.resilientHabitsTitle' => 'Robuste Gewohnheiten',
			'stats.resilientHabitsSubtitle' => 'Auch an schlechten Tagen erledigt',
			'stats.correlationAnalysisTitle' => 'Stimmungskorrelation',
			'stats.correlationAnalysisSubtitle' => 'Abschluss bei niedriger vs. hoher Stimmung',
			'stats.moodEnergyTrendTitle' => 'Stimmung & Energie',
			'stats.moodEnergyTrendSubtitle' => ({required Object days}) => 'Letzte ${days} Tage',
			_ => null,
		} ?? switch (path) {
			'stats.allTimeBest' => 'Allzeitrekord',
			'stats.topPerformerLabel' => 'Top-Gewohnheit',
			'stats.currentStreakShort' => 'Jetzt',
			'stats.recordLabel' => 'Rekord',
			'stats.recordDetail' => 'Längste Serie aller Zeiten',
			'stats.adherenceTitle' => 'Planeinhaltung',
			'stats.adherenceSubtitle' => 'Von den fälligen Tagen',
			'stats.adherenceDetail' => ({required Object done, required Object scheduled}) => '${done} von ${scheduled} geplanten Tagen',
			'stats.atRiskTitle' => 'Gefährdet',
			'stats.atRiskYes' => 'Ja',
			'stats.atRiskNo' => 'Im Plan',
			'stats.atRiskDetail' => ({required Object days}) => '${days} Tage seit dem letzten Mal',
			'stats.daysUnit' => 'T',
			'stats.gapTitle' => 'Abstände',
			'stats.gapSubtitle' => 'Tage zwischen Abschlüssen',
			'stats.gapAvg' => 'Ø Abstand',
			'stats.gapLongest' => 'Längster',
			'stats.gapSince' => 'Seit letztem',
			'stats.habitBounceBackShort' => 'Erholung',
			'stats.habitConsistencyDetail' => 'Regelmäßigkeitswert',
			'stats.habitPercentile' => ({required Object pct}) => 'Besser als ${pct}% deiner Gewohnheiten',
			'stats.monthVsTitle' => 'Dieser Monat vs. letzter',
			'stats.monthVsSubtitle' => 'Abschluss Monat für Monat',
			'stats.thisMonthLabel' => 'Dieser Monat',
			'stats.lastMonthLabel' => 'Letzter Monat',
			'stats.nextDayMoodTitle' => 'Stimmung am Folgetag',
			'stats.nextDayMoodSubtitle' => 'Stimmung & Energie am nächsten Tag',
			'stats.nextDayAfterDone' => 'Nach dem Erledigen',
			'stats.nextDayAfterMissed' => 'Nach dem Verpassen',
			'stats.nextDayMoodLift' => ({required Object value}) => '${value} Stimmungsplus',
			'stats.streakHistoryTitle' => 'Serienverlauf',
			'stats.streakHistorySubtitle' => 'Jede Folge aufeinanderfolgender Tage',
			'stats.streakHistoryDetail' => ({required Object count, required Object longest}) => '${count} Serien · längste ${longest} Tage',
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
			'habitsPage.dayDotTooltip' => ({required Object day, required Object month, required Object status}) => '${day}. ${month} · ${status}',
			'habitsPage.dayDotTooltipToday' => ({required Object status}) => 'Heute · ${status}',
			'habitsPage.editHabit' => 'Gewohnheit bearbeiten',
			'habitsPage.newHabit' => 'Neue Gewohnheit',
			'habitsPage.optionalReminder' => 'Optionale Erinnerung',
			'habitsPage.reminderHint' => 'z. B. 08:30',
			'habitsPage.close' => 'Schließen',
			'habitsPage.statusDone' => 'Erledigt',
			'habitsPage.statusSkipped' => 'Übersprungen',
			'habitsPage.statusUnrecorded' => 'Nicht erfasst',
			'habitsPage.weekOf' => ({required Object day, required Object month}) => 'Woche vom ${day}. ${month}',
			'habitsPage.lifeWeeks' => 'Wochen deines Weges',
			'habitsPage.catMindfulness' => 'Achtsamkeit',
			'habitsPage.editableHint' => 'Nur heute und gestern können bearbeitet werden.',
			'habitsPage.titleRequired' => 'Titel ist erforderlich',
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
			'goalsPage.rangeSameMonth' => ({required Object startDay, required Object endDay, required Object month, required Object year}) => '${startDay}. – ${endDay}. ${month} ${year}',
			'goalsPage.rangeSameYear' => ({required Object startDay, required Object startMonth, required Object endDay, required Object endMonth, required Object year}) => '${startDay}. ${startMonth} – ${endDay}. ${endMonth} ${year}',
			'goalsPage.rangeCrossYear' => ({required Object startDay, required Object startMonth, required Object startYear, required Object endDay, required Object endMonth, required Object endYear}) => '${startDay}. ${startMonth} ${startYear} – ${endDay}. ${endMonth} ${endYear}',
			'goalsStats.proRequired' => 'Pro-Funktion erforderlich',
			'goalsStats.active' => 'Aktiv',
			'goalsStats.failed' => 'Gescheitert',
			'goalsStats.complAbbr' => 'Abg.',
			'goalsStats.seasonality' => 'Saisonalität',
			'goalsStats.interestEvolution' => 'Interessenentwicklung',
			'ai.coach' => 'AI-Coach',
			'ai.dailyHabits' => 'Tägliche Gewohnheiten',
			'ai.macroGoals' => 'Makroziele',
			'ai.openRouter.apiKeyMissingShort' => '⚠️ Der AI-Coach braucht deinen eigenen OpenRouter-API-Schlüssel. Füge ihn in den Einstellungen hinzu, um loszulegen.',
			'ai.openRouter.apiKeyInvalid' => '⚠️ OpenRouter hat diesen API-Schlüssel abgelehnt. Prüfe ihn in den Einstellungen oder erstelle einen neuen auf openrouter.ai/keys.',
			'ai.openRouter.defaultSystemPrompt' => 'Du bist der "Discipline Coach", ein virtueller Assistent, der dem Nutzer hilft, diszipliniert zu bleiben, Ziele zu erreichen und gesunde Gewohnheiten aufzubauen. Sei motivierend, aber konkret, direkt und praktisch. Verwende einen professionellen, aber freundlichen Ton.',
			'ai.openRouter.communicationError' => ({required Object code}) => '❌ Fehler bei der Kommunikation mit der AI. (Code: ${code})',
			'ai.openRouter.connectionError' => '❌ Verbindungsfehler. Stelle sicher, dass du online bist, und versuche es erneut.',
			'ai.openRouter.connectionErrorShort' => '❌ Verbindungsfehler.',
			'ai.openRouter.connectionCheckTimeout' => '❌ Fehler: Die Verbindungsprüfung hat zu lange gedauert.',
			'ai.openRouter.contextTooLong' => '⚠️ Diese Unterhaltung ist zu lang für das Modell geworden. Starte oben rechts einen neuen Chat, um fortzufahren.',
			'ai.openRouter.noInternet' => '❌ Fehler: Keine Internetverbindung. Prüfe dein Netzwerk.',
			'ai.openRouter.serverTimeout' => '❌ Fehler: Der Server braucht zu lange für die Antwort. Versuche es erneut.',
			'ai.openRouter.apiError' => ({required Object code}) => '❌ API-Fehler: ${code} (Details in Sentry prüfen)',
			'ai.apiKey.rowTitle' => 'Dein OpenRouter-Konto',
			'ai.apiKey.description' => 'Lieber den Coach über dein eigenes Konto laufen lassen? Verbinde einen OpenRouter-Schlüssel und zahle direkt an den Anbieter — ohne Evolve-Abo. Erstelle einen auf openrouter.ai/keys: Er wird im Schlüsselbund dieses Geräts gespeichert und nur an OpenRouter gesendet.',
			'ai.apiKey.fieldLabel' => 'API-Schlüssel',
			'ai.apiKey.hint' => 'sk-or-v1-…',
			'ai.apiKey.save' => 'Schlüssel speichern',
			'ai.apiKey.saved' => 'API-Schlüssel gespeichert',
			'ai.apiKey.remove' => 'Schlüssel entfernen',
			'ai.apiKey.removed' => 'API-Schlüssel entfernt',
			'ai.apiKey.removeConfirmTitle' => 'API-Schlüssel entfernen?',
			'ai.apiKey.removeConfirmBody' => 'Diese Engine antwortet nicht mehr, bis du wieder ein Konto verbindest. Evolve AI und lokale Modelle sind nicht betroffen.',
			'ai.apiKey.statusSet' => 'Gespeichert',
			'ai.apiKey.statusMissing' => 'Nicht gesetzt',
			'ai.apiKey.saveFailed' => 'Der Schlüssel konnte nicht im Schlüsselbund gespeichert werden. Versuch es noch einmal.',
			'ai.apiKey.setupTitle' => 'OpenRouter-Konto verbinden',
			'ai.apiKey.setupBody' => 'Diese Engine läuft über dein eigenes OpenRouter-Konto. Verbinde es, um zu chatten — oder wechsle zu Evolve AI, in Pro enthalten.',
			'ai.apiKey.setupAction' => 'Konto verbinden',
			'ai.coachPrompts.diagnoseWeakestHabit.label' => '🩺 Meine schwächste Gewohnheit fixen',
			'ai.coachPrompts.diagnoseWeakestHabit.payload' => ({required Object habit, required Object done, required Object scheduled}) => '\'${habit}\' ist diese Woche meine schwächste Gewohnheit — ${done}/${scheduled} Tage geschafft. Was ist der wahrscheinlichste Grund, warum ich sie auslasse, und zwei konkrete Lösungen für diese Woche?',
			'ai.coachPrompts.goalOnTrack.label' => '🎯 Bin ich auf Kurs?',
			'ai.coachPrompts.goalOnTrack.payload' => ({required Object goal}) => 'Sei ehrlich, was mein Ziel \'${goal}\' angeht: Bin ich auf Kurs, es zu erreichen, und welche eine Änderung würde meine Chancen am meisten verbessern?',
			'ai.coachPrompts.weeklyReviewDown.label' => '📉 Meine Woche auswerten',
			'ai.coachPrompts.weeklyReviewDown.payload' => ({required Object thisPct, required Object lastPct}) => 'Meine Konstanz ist diese Woche auf ${thisPct}% gefallen, von ${lastPct}% in der Vorwoche. Was ist die wahrscheinlichste Ursache und die eine Änderung für nächste Woche?',
			'ai.coachPrompts.weeklyReviewUp.label' => '📊 Meine Woche auswerten',
			'ai.coachPrompts.weeklyReviewUp.payload' => ({required Object thisPct, required Object lastPct}) => 'Meine Konstanz liegt diese Woche bei ${thisPct}% gegenüber ${lastPct}% in der Vorwoche. Was funktioniert, und was ist die eine Sache, die ich nächste Woche stärker vorantreiben sollte?',
			'ai.coachPrompts.protectStreak.label' => '🛡️ Meine Serie schützen',
			'ai.coachPrompts.protectStreak.payload' => ({required Object habit, required Object days}) => 'Meine längste aktive Serie ist \'${habit}\' mit ${days} Tagen. Was ist das größte Risiko, sie zu brechen, und wie schütze ich sie diese Woche?',
			'ai.coachPrompts.alignHabitsToGoal.label' => '🔗 Welche Gewohnheiten dienen meinen Zielen?',
			'ai.coachPrompts.alignHabitsToGoal.payload' => ({required Object goal}) => 'Wenn ich meine Gewohnheiten mit meinem Ziel \'${goal}\' vergleiche: Welche bringen es wirklich voran und welche sind nur Ballast? Sei konkret und nenne eine Gewohnheit, die mir fehlen könnte.',
			'ai.coachPrompts.designHabitForGoal.label' => '💡 Ein Ziel in eine Gewohnheit verwandeln',
			'ai.coachPrompts.designHabitForGoal.payload' => ({required Object goal}) => 'Ich will mein Ziel \'${goal}\' erreichen. Welche einzelne tägliche Gewohnheit hätte die größte Wirkung? Gib mir eine konkrete Gewohnheit, die ich morgen anfangen kann.',
			'ai.coachPrompts.raiseTheBar.label' => '🚀 Die Latte höher legen',
			'ai.coachPrompts.raiseTheBar.payload' => 'Ich schaffe alle meine Gewohnheiten und meine Ziele sind auf Kurs. Wo werde ich vielleicht nachlässig, und wie lege ich die Latte höher, ohne auszubrennen?',
			'ai.coachPrompts.firstStep.label' => '🌱 Wo fange ich an?',
			'ai.coachPrompts.firstStep.payload' => 'Ich fange gerade erst an und habe noch keine Ziele oder Gewohnheiten eingerichtet. Schlage mir ein realistisches erstes Ziel und eine kleine tägliche Gewohnheit dafür vor und erkläre, warum diese Kombination funktioniert.',
			'ai.coachPrompts.whatCanYouHelp.label' => '💬 Womit kannst du helfen?',
			'ai.coachPrompts.whatCanYouHelp.payload' => 'Gib mir auf Basis meiner Gewohnheiten und Ziele in dieser App drei konkrete Beispiele, wie du mir helfen kannst — keine allgemeinen Ratschläge, sondern Dinge, die mit meinen echten Daten zu tun haben.',
			'ai.local.notReachable' => ({required Object url}) => '❌ Lokaler KI-Server unter ${url} nicht erreichbar. Stelle sicher, dass Ollama oder LM Studio läuft.',
			'ai.local.modelMissing' => '⚠️ Wähle zuerst ein lokales Modell — öffne oben die Modellauswahl.',
			'ai.local.requestFailed' => ({required Object code}) => '❌ Fehler des lokalen Modells (Code: ${code}).',
			'ai.local.streamError' => '❌ Verbindung zum lokalen Modell fehlgeschlagen.',
			'ai.local.timeout' => '❌ Das lokale Modell braucht zu lange — es wird möglicherweise noch geladen. Versuche es erneut.',
			'ai.local.modelNotFound' => '❌ Dieses Modell ist auf dem Server nicht verfügbar. Öffne die Modellauswahl, um eines zu wählen oder zu laden.',
			'ai.local.authRequired' => ({required Object app}) => '❌ ${app} verweigert die Verbindung — es erfordert ein API-Token. Deaktiviere die Authentifizierung in den Servereinstellungen oder richte Evolve auf einen Server, der keines verlangt.',
			'ai.local.stillLoading' => 'Das Modell wird noch geladen — ein Kaltstart kann eine Weile dauern.',
			'ai.standard.sessionExpired' => '⚠️ Deine Sitzung ist abgelaufen. Melde dich erneut an, um Evolve AI weiter zu nutzen.',
			'ai.standard.needsPro' => '⚠️ Evolve AI ist Teil von Evolve Pro. Schließe in den Einstellungen ein Abo ab — oder wechsle die Engine zu deinem eigenen OpenRouter-Konto, das ist kostenlos.',
			'ai.standard.rateLimited' => '⚠️ Du hast das Fair-Use-Limit von Evolve AI vorerst erreicht. Versuch es später noch einmal oder wechsle zu deinem eigenen OpenRouter-Konto.',
			'ai.standard.unavailable' => '❌ Evolve AI ist gerade nicht verfügbar. Das liegt an uns — bitte versuch es gleich noch einmal.',
			'ai.consent.allow' => 'Erlauben',
			'ai.consent.byokBody' => 'Zum Antworten sendet der AI Coach deine Nachricht, deinen Vornamen und den Kontext, den du teilst, über dein eigenes OpenRouter-Konto an OpenRouter, Inc. OpenRouter leitet sie gemäß den Einstellungen deines Kontos an einen Modellanbieter weiter. Du kannst die Einwilligung jederzeit in den Einstellungen widerrufen; alles andere in Evolve funktioniert weiter.',
			'ai.consent.byokTitle' => 'Deine Nachrichten an OpenRouter senden?',
			'ai.consent.consentStatusRevoked' => 'Nicht erlaubt',
			'ai.consent.consentStopSharing' => 'Teilen beenden…',
			'ai.consent.decline' => 'Jetzt nicht',
			'ai.consent.privateNote' => 'Deine private Datenbank bleibt auf diesem Gerät — nur was du im Chat sendest, verlässt es.',
			'ai.consent.revokeAction' => 'Weitergabe beenden',
			'ai.consent.revokeBody' => 'Der AI Coach fragt erneut, bevor er etwas sendet. Sonst ändert sich nichts.',
			'ai.consent.revokeTitle' => 'Weitergabe an die KI beenden?',
			'ai.consent.rowTitle' => 'Datenweitergabe an die KI',
			'ai.consent.standardBody' => 'Zum Antworten sendet der AI Coach deine Nachricht, deinen Vornamen und den Kontext, den du teilst, an OpenRouter, Inc., das sie zur Ausführung des Modells an Google LLC (Google AI Studio) weiterleitet. Da dies Googles kostenlose Stufe nutzt, kann Google den Text für begrenzte Zeit speichern und zur Verbesserung seiner Dienste verwenden — er ist nicht so privat wie eine kostenpflichtige Stufe. Du kannst die Einwilligung jederzeit in den Einstellungen widerrufen; alles andere in Evolve funktioniert weiter.',
			'ai.consent.standardTitle' => 'Deine Nachrichten an die KI senden?',
			'ai.consent.statusGranted' => 'Erlaubt',
			'ai.consent.statusNone' => 'Nicht erlaubt',
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
			'aiCoach.defaultUserName' => 'Nutzer',
			'aiCoach.userNameLine' => ({required Object userName}) => '- Name: ${userName}',
			'aiCoach.activeGoalsCount' => ({required Object count}) => '- Aktive Ziele: ${count}',
			'aiCoach.completedGoalsCount' => ({required Object count}) => '- Abgeschlossene Ziele: ${count}',
			'aiCoach.todayCompletion' => ({required Object completed, required Object total}) => '- Gewohnheiten heute: ${completed} von insgesamt ${total} abgeschlossen.',
			'aiCoach.newChatTooltip' => 'Neuer Chat',
			'aiCoach.clearConfirmTitle' => 'Neuen Chat starten?',
			'aiCoach.clearConfirmBody' => 'Dies löscht die aktuelle Unterhaltung — sie wird nicht gespeichert.',
			'aiCoach.clearConfirmCancel' => 'Abbrechen',
			'aiCoach.clearConfirmAccept' => 'Neuer Chat',
			'aiCoach.copyTooltip' => 'Kopieren',
			'aiCoach.copiedToast' => 'In die Zwischenablage kopiert',
			'aiCoach.linkOpenFailed' => 'Link konnte nicht geöffnet werden.',
			'settingsPage.aboutCopied' => 'Versionsdetails kopiert',
			'settingsPage.aboutCopyTooltip' => 'Versionsdetails kopieren',
			'settingsPage.aboutVersion' => ({required Object version, required Object build}) => 'Version ${version} (${build})',
			'settingsPage.accentColor' => 'Akzentfarbe',
			'settingsPage.accentColorDetail' => 'Erweiterte Palette, reserviert für Evolve Pro.',
			'settingsPage.accessProtection' => 'Zugriffsschutz',
			'settingsPage.account' => 'Konto',
			'settingsPage.accountAndOnboarding' => 'Konto und Onboarding',
			'settingsPage.accountDataManagementContent' => 'Wähle, ob die Daten gelöscht werden sollen, während das Konto aktiv bleibt, oder ob das Konto dauerhaft gelöscht werden soll.',
			'settingsPage.accountDataManagementTitle' => 'Konto- und Datenverwaltung',
			'settingsPage.accountDeleted' => 'Konto gelöscht.',
			'settingsPage.accountPaneSubtitle' => 'Mit welchem Konto du angemeldet bist und wo deine Daten liegen.',
			'settingsPage.accountSyncOn' => 'Aktiv — über dein Konto',
			'settingsPage.activateEvolveProStart' => 'Abonniere mit deinem Apple-Konto.',
			'settingsPage.advancedPaneSubtitle' => 'Erweiterte Einstellungen und Diagnose.',
			'settingsPage.aiAndSystem' => 'AI & SYSTEM',
			'settingsPage.aiInsights' => 'AI-Insights',
			'settingsPage.aiInsightsDetail' => 'Personalisierte Analysen und Tipps von der AI.',
			'settingsPage.aiSuggestions' => 'AI-Vorschläge',
			'settingsPage.aiSuggestionsDetail' => 'Intelligente Gewohnheitsanalyse',
			'settingsPage.appLogsDetail' => 'Diagnoseprotokolle dieser Sitzung ansehen',
			'settingsPage.appLogsTitle' => 'App-Protokolle',
			'settingsPage.appearanceAndVisual' => 'Erscheinungsbild und Optik',
			'settingsPage.appearanceSubtitle' => 'Lokale Einstellungen, an den Desktop angepasst',
			'settingsPage.appearanceTitle' => 'Erscheinungsbild und Anwendung',
			'settingsPage.applyAction' => 'Anwenden',
			'settingsPage.availableWithActiveSession' => 'Verfügbar mit einer aktiven Supabase-Sitzung',
			'settingsPage.avatarGateTitle' => 'Avatar',
			'settingsPage.avatarPickFailed' => 'Bildauswahl fehlgeschlagen.',
			'settingsPage.bestValue' => 'Bester Wert',
			'settingsPage.billingAppleDetail' => 'Dein Abonnement wird mit deinem Apple-Konto gekauft und verwaltet.',
			'settingsPage.billingAppleTitle' => 'Abrechnung über Apple',
			'settingsPage.billingPlatformUnsupported' => 'In-App-Käufe sind auf dieser Plattform nicht verfügbar.',
			'settingsPage.billingUnavailableDetail' => 'Abonnements sind vorübergehend nicht verfügbar. Bitte versuche es später erneut.',
			'settingsPage.biometricActivationCancelled' => 'Aktivierung abgebrochen.',
			'settingsPage.biometricLock' => 'Biometrische Sperre',
			'settingsPage.biometricLockDetail' => 'Verfügbar mit dem nativen Adapter unter macOS und Windows; unter Linux nicht unterstützt.',
			'settingsPage.calendarExperienceLanguage' => 'Kalender, Erlebnis und Sprache',
			'settingsPage.calendarViewOptions.month' => 'Monat',
			'settingsPage.calendarViewOptions.week' => 'Woche',
			'settingsPage.calendarViewOptions.year' => 'Jahr',
			'settingsPage.calendarViewOptions.life' => 'Leben',
			'settingsPage.cancel' => 'Abbrechen',
			'settingsPage.changePassword' => 'Passwort ändern',
			'settingsPage.changePasswordDetail' => 'Aktualisierung der Anmeldedaten über Supabase Auth.',
			'settingsPage.commercialChannelRequired' => 'Käufe nicht verfügbar',
			'settingsPage.confirm' => 'Bestätigen',
			'settingsPage.confirmDeleteAccountMessage' => 'Das Konto und alle zugehörigen Daten werden dauerhaft gelöscht. Diese Aktion ist unwiderruflich.',
			'settingsPage.confirmDeleteAccountTitle' => 'Kontolöschung bestätigen',
			'settingsPage.confirmNewPassword' => 'Neues Passwort bestätigen',
			'settingsPage.confirmResetDataMessage' => 'Gewohnheiten, Ziele und Einstellungen werden gelöscht. Das Konto bleibt aktiv. Diese Aktion kann nicht rückgängig gemacht werden.',
			'settingsPage.confirmResetDataTitle' => 'Zurücksetzen der Daten bestätigen',
			'settingsPage.confirmSignOutMessage' => 'Möchtest du dich wirklich abmelden? Du musst deine Anmeldedaten erneut eingeben, um dich wieder anzumelden.',
			'settingsPage.confirmSignOutTitle' => 'Abmeldung bestätigen',
			'settingsPage.currentPassword' => 'Aktuelles Passwort',
			'settingsPage.customColor' => 'Benutzerdefinierte Farbe',
			'settingsPage.dataAndConsents' => 'Daten und Einwilligungen',
			'settingsPage.dataBackupPaneSubtitle' => 'Wohin deine Daten kopiert werden, wie du sie ein- und ausführst und wie du sie löschst.',
			'settingsPage.dataRepository' => 'Daten-Repository',
			'settingsPage.dataStorage' => 'Datenspeicherung',
			'settingsPage.dataStorageAccount' => 'Dein Evolve-Konto',
			'settingsPage.dataStorageThisMac' => 'Nur auf diesem Mac, verschlüsselt',
			'settingsPage.dateOfBirth' => 'Geburtsdatum',
			'settingsPage.dateOfBirthHint' => 'JJJJ-MM-TT',
			'settingsPage.deepWorkInsights' => 'Deep-Work-Insights',
			'settingsPage.deepWorkInsightsDetail' => 'Erweiterte Analyse deiner Fokus-Sitzungen.',
			'settingsPage.defaultCalendarView' => 'Standard-Kalenderansicht',
			'settingsPage.deleteAccountAction' => 'Konto löschen',
			'settingsPage.deleteAccountAndData' => 'Konto und Daten löschen',
			'settingsPage.deleteAccountAndDataDetail' => 'Unwiderruflicher Vorgang, durch Bestätigung geschützt.',
			'settingsPage.deleteAccountGateTitle' => 'Konto löschen',
			'settingsPage.deletePrivateData' => 'private Daten löschen',
			'settingsPage.deletePrivateDataDetail' => 'Löscht die verschlüsselte lokale Datenbank dauerhaft.',
			'settingsPage.detailsHeader' => 'Abo-Details',
			'settingsPage.disabledTurnOnFirst' => 'Schalte die Erinnerung ein, um eine Zeit zu wählen.',
			'settingsPage.email' => 'E-Mail',
			'settingsPage.encryptedLocalDatabase' => 'Verschlüsselte lokale Datenbank',
			'settingsPage.enterCurrentPassword' => 'Gib dein aktuelles Passwort ein.',
			'settingsPage.eveningReview' => 'Abendliche Rückschau',
			'settingsPage.eveningReviewDetail' => 'Erinnert dich daran, deinen Tag zu festigen.',
			'settingsPage.eveningReviewTime' => 'Uhrzeit der abendlichen Rückschau',
			'settingsPage.expiresOn' => 'Läuft ab am',
			'settingsPage.exportData' => 'Daten exportieren',
			'settingsPage.exportDataDetail' => 'Teilt einen vollständigen JSON-Export der verfügbaren Daten.',
			'settingsPage.exportDoneClipboard' => 'Das JSON ist in der Zwischenablage: Linux unterstützt keine Dateifreigabe.',
			'settingsPage.exportDoneSaved' => 'Die JSON-Datei wurde am gewählten Ort gespeichert.',
			'settingsPage.exportDoneShare' => 'Das JSON wurde an die Freigabeauswahl gesendet.',
			'settingsPage.exportDoneTitle' => 'Export abgeschlossen',
			'settingsPage.exportPrivateShareText' => 'Meine privaten Daten, exportiert aus Evolve',
			'settingsPage.exportShareText' => 'Meine aus Evolve exportierten Daten',
			'settingsPage.focusMode' => 'Fokusmodus',
			'settingsPage.focusModeDetail' => 'Pausiert alle Erinnerungen und Benachrichtigungen.',
			'settingsPage.focusModeOnBody' => 'Diese Erinnerungen pausieren, bis du ihn ausschaltest.',
			'settingsPage.focusModeOnTitle' => 'Fokus ist aktiv',
			'settingsPage.fullName' => 'Vollständiger Name',
			'settingsPage.gateChangePassword' => 'Passwortänderung',
			'settingsPage.gateLogout' => 'Abmelden',
			'settingsPage.gateProfile' => 'Profil',
			'settingsPage.gateRequiresActiveSession' => 'Erfordert eine aktive Supabase-Sitzung.',
			'settingsPage.generalPaneSubtitle' => 'Aussehen und Sprache von Evolve.',
			'settingsPage.goToLogin' => 'Zur Anmeldung',
			'settingsPage.goToLoginDetail' => 'Setze den privaten Modus aus und melde dich bei Supabase an.',
			'settingsPage.groupAppLock' => 'App-Sperre',
			'settingsPage.groupAppearance' => 'Erscheinungsbild',
			'settingsPage.groupBackups' => 'Backups',
			'settingsPage.groupDailyReminders' => 'Tägliche Erinnerungen',
			'settingsPage.groupDataStorage' => 'Datenspeicherung',
			'settingsPage.groupDelivery' => 'Zustellung',
			'settingsPage.groupDiagnostics' => 'Diagnose',
			'settingsPage.groupDiagnosticsConsent' => 'Diagnose & Einwilligungen',
			'settingsPage.groupFocus' => 'Fokus',
			'settingsPage.groupGettingStarted' => 'Erste Schritte',
			'settingsPage.groupLanguageFormats' => 'Sprache & Formate',
			'settingsPage.groupLegal' => 'Rechtliches',
			'settingsPage.groupSignIn' => 'Anmeldung',
			'settingsPage.habitReminders' => 'Gewohnheitserinnerungen',
			'settingsPage.habitRemindersDetail' => 'Sendet das tägliche Morgenbriefing.',
			'settingsPage.hapticFeedback' => 'Haptisches Feedback',
			'settingsPage.hapticFeedbackDetail' => 'Der Desktop behält die Einstellung bei, erzeugt aber keine Vibrationen.',
			'settingsPage.importCategoriesCount' => ({required Object count}) => '${count} Kategorien',
			'settingsPage.importCompletedTitle' => 'Import abgeschlossen',
			'settingsPage.importConfirmButton' => 'Import bestätigen',
			'settingsPage.importData' => 'Daten importieren',
			'settingsPage.importDataDetail' => 'Stellt ein Backup (JSON oder ZIP) von Evolve wieder her.',
			'settingsPage.importDataGateTitle' => 'Daten importieren',
			'settingsPage.importEntityCategories' => 'Kategorien',
			'settingsPage.importEntityHabits' => 'Gewohnheiten',
			'settingsPage.importEntityLogs' => 'Gewohnheits-Logs',
			'settingsPage.importEntityMacroGoals' => 'Makro-Ziele',
			'settingsPage.importEntityMoods' => 'Stimmungsdaten',
			'settingsPage.importError' => ({required Object error}) => 'Fehler beim Import: ${error}',
			'settingsPage.importHabitsCount' => ({required Object count}) => '${count} Gewohnheiten',
			'settingsPage.importInProgress' => 'Daten werden importiert...',
			'settingsPage.importLockedMessage' => 'Dieses Gerät kann deine lokale private Datenbank nicht entsperren – ihr Verschlüsselungsschlüssel fehlt (das passiert nach dem Wechsel auf einen neuen Mac oder einer Änderung der App-Signierung). Die vorhandenen lokalen Daten sind nicht wiederherstellbar, aber du kannst sie zurücksetzen und dieses Backup in eine neue, leere Datenbank importieren. Dies kann nicht rückgängig gemacht werden.',
			'settingsPage.importLockedResetButton' => 'Zurücksetzen & importieren',
			'settingsPage.importLockedTitle' => 'Gesperrte private Datenbank zurücksetzen?',
			'settingsPage.importLogsCount' => ({required Object count}) => '${count} Check-ins (Log)',
			'settingsPage.importMacroGoalsCount' => ({required Object count}) => '${count} Makro-Ziele',
			'settingsPage.importMergeSubtitle' => 'Wird mit deinen Daten zusammengeführt, wobei die neueste Version jedes Eintrags behalten wird.',
			'settingsPage.importMergeTitle' => 'Mit aktuellen Daten zusammenführen',
			'settingsPage.importMoodsCount' => ({required Object count}) => '${count} Stimmungsaufzeichnungen',
			'settingsPage.importPreviewSkipped' => ({required Object count}) => '⚠ ${count} ungültige Datensätze werden übersprungen',
			'settingsPage.importPrivateOnly' => 'Die Importfunktion ist derzeit nur im privaten Modus (lokal) verfügbar.',
			'settingsPage.importReplaceConfirmButton' => 'Löschen & ersetzen',
			'settingsPage.importReplaceConfirmMessage' => ({required Object count}) => 'Dies löscht deine aktuellen Daten endgültig (etwa ${count} Einträge) und behält nur, was in diesem Backup ist. Das kann nicht rückgängig gemacht werden.',
			'settingsPage.importReplaceConfirmTitle' => 'Alle Daten ersetzen?',
			'settingsPage.importReplaceSubtitle' => 'Löscht endgültig jeden vorhandenen Eintrag, der nicht in diesem Backup ist.',
			'settingsPage.importReplaceTitle' => 'Aktuelle Daten ersetzen',
			'settingsPage.importRowMerge' => ({required Object label, required Object added, required Object updated, required Object unchanged}) => '${label}: ${added} hinzugefügt, ${updated} aktualisiert, ${unchanged} unverändert',
			'settingsPage.importRowReplace' => ({required Object count, required Object label}) => '${count} ${label}',
			'settingsPage.importRowSkipped' => ({required Object count}) => ', ${count} übersprungen',
			'settingsPage.importSuccess' => 'Import erfolgreich abgeschlossen!',
			'settingsPage.importSummaryDone' => 'Super!',
			'settingsPage.importSummaryMerged' => 'Deine Daten wurden mit dem Backup zusammengeführt. Zusammenfassung:',
			'settingsPage.importSummaryReplaced' => 'Deine Daten wurden durch das Backup ersetzt. Zusammenfassung:',
			'settingsPage.importSummaryTitle' => 'Importübersicht',
			'settingsPage.insightsAndReports' => 'Insights und Berichte',
			'settingsPage.language' => 'Sprache',
			'settingsPage.languageOptions.system' => 'System',
			'settingsPage.languageOptions.italian' => 'Italienisch',
			'settingsPage.languageOptions.english' => 'Englisch',
			'settingsPage.languageOptions.spanish' => 'Spanisch',
			'settingsPage.languageOptions.german' => 'Deutsch',
			'settingsPage.languageOptions.arabic' => 'Arabisch',
			'settingsPage.manageSubscription' => 'Abonnement verwalten',
			'settingsPage.manageSubscriptionDetail' => 'Öffnet die Abonnementverwaltung des Apple-Kontos.',
			'settingsPage.milestones' => 'Meilensteine',
			'settingsPage.milestonesDetail' => 'Feiern beim Erreichen wichtiger Meilensteine.',
			'settingsPage.morningBriefTime' => 'Uhrzeit des Morgenbriefings',
			'settingsPage.nativeDeliveryTitle' => 'Native Zustellung je nach Betriebssystem',
			'settingsPage.newPassword' => 'Neues Passwort',
			'settingsPage.newPasswordMinLength' => 'Das neue Passwort muss mindestens 8 Zeichen lang sein.',
			'settingsPage.nextRenewal' => 'Nächste Verlängerung',
			'settingsPage.notAuthenticated' => 'Nicht authentifiziert',
			'settingsPage.notificationPermissionsDenied' => 'Berechtigung nicht erteilt. Du kannst sie in den Systemeinstellungen ändern.',
			'settingsPage.notificationPermissionsGranted' => 'Berechtigungen für dieses System verfügbar.',
			'settingsPage.notificationPermissionsTitle' => 'Benachrichtigungsberechtigungen',
			'settingsPage.notifications' => 'Benachrichtigungen',
			'settingsPage.notificationsPaneSubtitle' => 'Alles, was dich unterbrechen kann.',
			'settingsPage.notificationsSubtitle' => 'Betriebshinweise des Desktop-Clients',
			'settingsPage.operationFailed' => 'Vorgang fehlgeschlagen.',
			'settingsPage.operationalReminders' => 'Betriebshinweise',
			'settingsPage.pageSubtitle' => 'Verwalte dein Profil, das Desktop-Verhalten, den Datenschutz und den Evolve-Plan.',
			'settingsPage.pageTitle' => 'Einstellungen',
			'settingsPage.passwordUpdateFailed' => 'Aktualisierung fehlgeschlagen. Überprüfe dein aktuelles Passwort.',
			'settingsPage.passwordsDontMatch' => 'Die Passwörter stimmen nicht überein',
			'settingsPage.paymentMethod' => 'Zahlungsmethode',
			'settingsPage.paymentMethodValue' => 'Apple Pay / App Store',
			'settingsPage.perHabitRemindersNote' => 'Erinnerungen für einzelne Gewohnheiten stellst du bei der jeweiligen Gewohnheit ein; diese Schalter ändern daran nichts.',
			'settingsPage.perMonth' => ({required Object price}) => '${price} pro Monat',
			'settingsPage.perMonthWithSavings' => ({required Object price, required Object percent}) => '${price} pro Monat · Spare ${percent} %',
			'settingsPage.personalInfo' => 'Persönliche Informationen',
			'settingsPage.personalInfoDetail' => 'Vorname, Nachname, E-Mail und Geburtsdatum',
			'settingsPage.planAnnual' => 'Jährlich',
			'settingsPage.planLabel' => 'Plan',
			'settingsPage.planManagement' => 'Planverwaltung',
			'settingsPage.planMonthly' => 'Monatlich',
			'settingsPage.priceUnavailable' => 'Preis nicht verfügbar',
			'settingsPage.privacyPaneSubtitle' => 'Was Evolve sehen kann und wer es sonst öffnen darf.',
			'settingsPage.privacyPolicy' => 'Datenschutzerklärung',
			'settingsPage.privacySubtitle' => 'Zugriffsschutz, Einwilligungen und Datenverwaltung',
			'settingsPage.privacyTitle' => 'Datenschutz und Sicherheit',
			'settingsPage.privateMode' => 'Privater Modus',
			'settingsPage.privateModeDataProtected' => 'Deine Daten sind geschützt und werden nur auf diesem Gerät gespeichert.',
			'settingsPage.proActiveMessage' => 'Dein Abo ist aktiv. Der AI Coach ist enthalten — ohne OpenRouter-Konto und ohne API-Schlüssel — zusammen mit erweiterten Trendstatistiken und allen Werkzeugen von Evolve für persönliches Wachstum.',
			'settingsPage.proActiveName' => 'Evolve PRO aktiv',
			'settingsPage.proName' => 'Evolve PRO',
			'settingsPage.proStartJourney' => 'Starte deinen Weg',
			'settingsPage.proSubtitle' => 'Plan, Kaufwiederherstellung und Abonnementverwaltung',
			'settingsPage.proThankYou' => 'Danke, dass du die Entwicklung von Evolve unterstützt.',
			'settingsPage.proTitle' => 'Evolve Pro',
			'settingsPage.proUpsellSubtitle' => 'Schalte alle Funktionen frei und beschleunige dein Wachstum.',
			'settingsPage.proUpsellTitle' => 'Zu Evolve PRO wechseln',
			'settingsPage.proWelcomeTitle' => 'Willkommen bei Evolve PRO',
			'settingsPage.profileFallback' => 'Profil',
			'settingsPage.profileLabel' => 'Profil',
			'settingsPage.profileSubtitle' => 'Persönliche Informationen und Synchronisierungsstatus',
			'settingsPage.railGroupApp' => 'App',
			'settingsPage.railGroupData' => 'Daten',
			'settingsPage.railGroupYou' => 'Du',
			'settingsPage.renewalDisclaimer' => 'Das Abonnement verlängert sich automatisch, sofern die automatische Verlängerung nicht mindestens 24 Stunden vor Ablauf des Zeitraums in den Apple-Kontoeinstellungen deaktiviert wird.',
			'settingsPage.requestNotificationPermissions' => 'Benachrichtigungsberechtigungen anfordern',
			'settingsPage.requestNotificationPermissionsDetail' => 'Öffnet die native Eingabeaufforderung auf der unterstützten Plattform.',
			'settingsPage.resetDataAction' => 'Daten zurücksetzen',
			'settingsPage.resetDataSuccess' => 'Daten erfolgreich gelöscht.',
			'settingsPage.resetDataTitle' => 'Daten zurücksetzen',
			'settingsPage.resetTutorial' => 'Tutorial zurücksetzen',
			'settingsPage.resetTutorialDetail' => 'Öffnet die Schritt-für-Schritt-Anleitungen für Dashboard und Ziele erneut.',
			'settingsPage.restoreDefaults' => 'Standardeinstellungen wiederherstellen…',
			'settingsPage.restoreDefaultsDetail' => 'Deine Gewohnheiten, Ziele, dein Konto und die App-Sperre bleiben unberührt.',
			'settingsPage.restorePurchases' => 'Käufe wiederherstellen',
			'settingsPage.restorePurchasesDetail' => 'Stellt ein bereits gekauftes Abonnement wieder her.',
			'settingsPage.reviewInitialConsent' => 'Erstzustimmung überprüfen',
			'settingsPage.reviewInitialConsentDetail' => 'Bedingungen, Datenschutz, Benachrichtigungen und Absturzberichte',
			'settingsPage.save' => 'Speichern',
			'settingsPage.searchClear' => 'Suche löschen',
			'settingsPage.searchNoResults' => 'Keine Einstellung gefunden',
			'settingsPage.searchPlaceholder' => 'Einstellungen durchsuchen',
			'settingsPage.sectionAccount' => 'Konto',
			'settingsPage.sectionAdvanced' => 'Erweitert',
			'settingsPage.sectionApplication' => 'Anwendung',
			'settingsPage.sectionDataBackup' => 'Daten & Backup',
			'settingsPage.sectionGeneral' => 'Allgemein',
			'settingsPage.sectionPrivacy' => 'Datenschutz',
			'settingsPage.sectionPrivacySecurity' => 'Datenschutz & Sicherheit',
			'settingsPage.sendCrashReports' => 'Absturzberichte senden',
			'settingsPage.sendCrashReportsDetail' => 'Gesonderte Einwilligung für Sentry.',
			'settingsPage.sessionUnavailable' => 'Sitzung nicht verfügbar',
			'settingsPage.settingSaveFailed' => 'Diese Einstellung konnte nicht gespeichert werden. Der vorherige Wert wurde wiederhergestellt.',
			'settingsPage.signOut' => 'Vom Konto abmelden',
			'settingsPage.signOutDetailActive' => 'Die Sitzung auf diesem Gerät schließen',
			'settingsPage.statusActive' => 'Aktiv',
			'settingsPage.statusLabel' => 'Status',
			'settingsPage.subscribeCta' => ({required Object plan, required Object price}) => 'Abonnieren — ${plan} · ${price}',
			'settingsPage.subscribeCtaNoPrice' => ({required Object plan}) => 'Abonnieren — ${plan}',
			'settingsPage.subscription' => 'Abonnement',
			'settingsPage.supabaseWithEncryptedCache' => 'Supabase mit verschlüsseltem Cache',
			'settingsPage.syncsToIPhoneNote' => 'Diese Einstellungen gelten auch auf deinem iPhone.',
			'settingsPage.systemPermissionsManagement' => 'Verwaltung der Systemberechtigungen',
			'settingsPage.systemPermissionsManagementDetail' => 'Benachrichtigungen, Kalender und Sicherheit.',
			'settingsPage.systemPermissionsOpenFailed' => 'Einstellungen konnten nicht geöffnet werden.',
			'settingsPage.systemPermissionsTitle' => 'Systemberechtigungen',
			'settingsPage.systemSection' => 'System',
			'settingsPage.termsEula' => 'Nutzungsbedingungen (EULA)',
			'settingsPage.themeDark' => 'Dunkel',
			'settingsPage.themeLight' => 'Hell',
			'settingsPage.themeMode' => 'Design',
			'settingsPage.themeSystem' => 'System folgen',
			'settingsPage.timeFormat24h' => '24-Stunden-Format',
			'settingsPage.timeFormat24hDetail' => 'Verwende Uhrzeiten wie 20:30 statt 8:30 PM.',
			'settingsPage.tutorialResetMessage' => 'Die Anleitungen werden in den entsprechenden Bereichen erneut angezeigt.',
			'settingsPage.tutorialResetTitle' => 'Tutorials zurückgesetzt',
			'settingsPage.updateAvatar' => 'Avatar aktualisieren',
			'settingsPage.updateAvatarDetail' => 'Wähle ein lokales Bild für das Desktop-Profil.',
			_ => null,
		} ?? switch (path) {
			'settingsPage.updatePassword' => 'Passwort aktualisieren',
			'settingsPage.useAccent' => ({required Object hex}) => 'Akzent ${hex} verwenden',
			'settingsPage.verified' => 'Verifiziert',
			'settingsPage.weeklyReports' => 'Wochenberichte',
			'settingsPage.weeklyReportsDetail' => 'Eine wöchentliche Zusammenfassung deiner Fortschritte.',
			'settingsPage.youArePro' => 'Du bist PRO-Nutzer',
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
			'consentPage.subtitle' => 'Evolve lädt deine personenbezogenen Daten erst auf einen Server, nachdem du hier zugestimmt hast.',
			'consentPage.uploadTitle' => 'Was diesen Mac verlässt',
			'consentPage.uploadAccountTitle' => 'Mit einem Evolve-Konto',
			'consentPage.uploadAccountBody' => 'Ziele, Gewohnheiten, Stimmungs-Check-ins, deine App-Einstellungen und dein Profil (Name, E-Mail, Geburtsdatum) werden auf die Server von Evolve geladen, um deine Geräte zu synchronisieren. Dein Profilbild bleibt auf diesem Mac.',
			'consentPage.uploadPrivateTitle' => 'Privat auf diesem Mac',
			'consentPage.uploadPrivateBody' => 'zu uns wird nichts hochgeladen; die optionale iCloud-Synchronisierung ist Ende-zu-Ende-verschlüsselt und erreicht nur dein eigenes iCloud-Konto.',
			'consentPage.uploadNeverTitle' => 'Nie abgerufen',
			'consentPage.uploadNeverBody' => 'Kontakte, Kalender, Kamera, Mikrofon, Standort.',
			'consentPage.acceptTerms' => 'Ich akzeptiere die Bedingungen und die Datenschutzrichtlinie',
			'consentPage.termsSubtitle' => 'Ich habe die Dokumente gelesen, bin mindestens 14 Jahre alt und stimme dem oben beschriebenen Hochladen zu.',
			'consentPage.crashDiagnostics' => 'Absturzdiagnose',
			'consentPage.crashSubtitle' => 'Standardmäßig aus. Wenn aktiviert, gehen anonymisierte Absturzberichte an unseren Diagnoseanbieter Sentry.',
			'consentPage.openPrivacy' => 'Datenschutzrichtlinie öffnen',
			'consentPage.openTerms' => 'Nutzungsbedingungen',
			'consentPage.notificationsTitle' => 'Benachrichtigungen aktivieren',
			'consentPage.notificationsSubtitle' => 'Erhalte Gewohnheits-Erinnerungen und Tagesübersichten.',
			'consentPage.enableNotifications' => 'Aktivieren',
			'consentPage.notificationsEnabled' => 'Aktiviert',
			'notif.macScheduling' => 'Tägliche Planung auf macOS aktiv.',
			'notif.linuxImmediate' => 'Linux zeigt sofortige Benachrichtigungen, unterstützt aber keine Planung.',
			'notif.openEvolve' => 'Evolve öffnen',
			'notif.windowsScheduling' => 'Windows plant das nächste Vorkommen bei jedem Start.',
			'notif.morningBody' => 'Sieh dir die heutigen Gewohnheiten an und wähle, wo du beginnst.',
			'notif.habitReminderBody' => 'Zeit, deine Gewohnheit zu erledigen.',
			'notif.limitReminderBody' => 'Bleibst du heute innerhalb deines Limits? Sieh kurz nach, wenn du kannst.',
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
			'subscriptionCtrl.loadOffersFailed' => 'Abo-Pläne konnten nicht geladen werden. Prüfe deine Verbindung und versuche es erneut.',
			'subscriptionCtrl.proActivated' => 'Evolve Pro aktiviert.',
			'subscriptionCtrl.purchasesRestored' => 'Käufe wiederhergestellt.',
			'subscriptionCtrl.noActiveSub' => 'Kein aktives Pro-Abonnement gefunden.',
			'subscriptionCtrl.restoreFailed' => 'Käufe konnten nicht wiederhergestellt werden.',
			'subscriptionCtrl.configKey' => 'In-App-Käufe sind vorübergehend nicht verfügbar.',
			'subscriptionCtrl.loginFirst' => 'Melde dich an, bevor du Evolve Pro verwaltest.',
			'subscriptionCtrl.paidAppsAgreement' => 'Die Vereinbarung für kostenpflichtige Apps ist nicht aktiv. Der Kontoinhaber muss die Vereinbarung für kostenpflichtige Apps in App Store Connect akzeptieren.',
			'subscriptionCtrl.alreadyPurchased' => 'Dieses Abonnement ist bereits gekauft. Verwenden Sie „Käufe wiederherstellen“, um den Pro-Zugriff erneut zu aktivieren.',
			'subscriptionCtrl.purchasesNotAllowed' => 'In-App-Käufe sind auf diesem Gerät oder Apple-Konto nicht zulässig.',
			'subscriptionCtrl.planUnavailable' => 'Der ausgewählte Plan ist nicht zum Kauf verfügbar. Versuchen Sie es später noch einmal.',
			'subscriptionCtrl.paymentPending' => 'Die Zahlung steht aus. Der Pro-Zugang wird aktiviert, wenn Apple die Transaktion bestätigt.',
			'subscriptionCtrl.connectionUnavailable' => 'Verbindung nicht verfügbar. Überprüfen Sie Ihr Netzwerk und versuchen Sie es erneut.',
			'subscriptionCtrl.linkedToAnotherAccount' => 'Dieser Kauf ist bereits mit einem anderen Evolve-Konto verknüpft. Melden Sie sich mit diesem Konto an oder wenden Sie sich an den Support.',
			'subscriptionCtrl.purchaseInProgress' => 'Ein Kaufvorgang ist bereits im Gange. Warten Sie ein paar Sekunden.',
			'subscriptionCtrl.restoreInProgress' => 'Eine Wiederherstellung wird bereits durchgeführt. Warten Sie ein paar Sekunden.',
			'subscriptionCtrl.purchaseFailedMessage' => 'Der Kauf konnte nicht abgeschlossen werden. Versuchen Sie es in Kürze noch einmal.',
			'subscriptionCtrl.restoreFailedMessage' => 'Einkäufe konnten nicht wiederhergestellt werden. Versuchen Sie es in Kürze noch einmal.',
			'subscriptionCtrl.purchaseRegisteredNotActive' => 'Kauf registriert, aber Pro-Abonnement ist noch nicht aktiv. Warten Sie einige Sekunden und verwenden Sie „Käufe wiederherstellen“.',
			'subscriptionCtrl.noActiveSubscription' => 'Für diese Apple-ID wurde kein aktives Evolve PRO-Abonnement gefunden. Stelle sicher, dass du dieselbe Apple-ID wie beim Kauf verwendest.',
			'subscriptionCtrl.invalidConfig' => 'Kaufkonfiguration ungültig. Bitte versuche es später erneut oder kontaktiere den Support.',
			'authCtrl.appleNoToken' => 'Apple hat kein Identity-Token zurückgegeben.',
			'authCtrl.appleAuthFailed' => 'Apple-Authentifizierung fehlgeschlagen.',
			'authCtrl.cantOpenBrowser' => 'Der Systembrowser konnte nicht geöffnet werden.',
			'authCtrl.accessNotCompleted' => ({required Object provider}) => '${provider}-Anmeldung nicht abgeschlossen.',
			'authCtrl.providerAuthFailed' => ({required Object provider}) => '${provider}-Authentifizierung fehlgeschlagen.',
			'authCtrl.operationFailed' => 'Vorgang fehlgeschlagen. Versuche es gleich erneut.',
			'proModal.title' => 'Evolve PRO freischalten',
			'proModal.subtitle' => 'Bringen Sie Ihr Gewohnheitssystem auf die nächste Stufe',
			'proModal.featuresHeader' => 'Was der PRO-Plan enthält',
			'proModal.aiCoachTitle' => 'AI Coach, ohne Einrichtung',
			'proModal.aiCoachDesc' => 'Wir betreiben ihn mit unserem Schlüssel: kein API-Schlüssel zu besorgen, kein zweites Konto. Lieber dein eigenes OpenRouter-Konto? Das ist ebenfalls kostenlos.',
			'proModal.statsTitle' => 'Gewohnheitsspezifische Statistiken',
			'proModal.statsDesc' => 'Wichtige Erkenntnisse zur Steigerung Ihrer Produktivität.',
			'proModal.metricsTitle' => 'Erweiterte Zielmetriken',
			'proModal.metricsDesc' => 'Sehen Sie sich detaillierte Diagramme und detaillierte Leistungsstatistiken für jedes Jahr an.',
			'proModal.unlimitedTitle' => 'Unbegrenzte Gewohnheiten',
			'proModal.unlimitedDesc' => 'Erstellen und verfolgen Sie alle gewünschten Gewohnheiten ohne Einschränkungen.',
			'proModal.maybeLater' => 'Vielleicht später',
			'proModal.viewPlans' => 'Pro-Abos ansehen',
			'appLogs.title' => 'App-Protokolle',
			'appLogs.copiedToClipboard' => 'Protokolle in die Zwischenablage kopiert',
			'appLogs.clearLogsTitle' => 'Protokolle löschen',
			'appLogs.clearLogsConfirm' => 'Möchten Sie wirklich alle Protokolleinträge löschen? Diese Aktion kann nicht rückgängig gemacht werden.',
			'appLogs.clearLogsAction' => 'Alle löschen',
			'appLogs.copyAll' => 'Alle Protokolle kopieren',
			'appLogs.searchPlaceholder' => 'Protokolle durchsuchen...',
			'appLogs.filterAll' => 'Alle',
			'appLogs.filterErrors' => 'Fehler',
			'appLogs.filterWarnings' => 'Warnungen',
			'appLogs.filterInfo' => 'Info',
			'appLogs.emptyTitle' => 'Keine Protokolle',
			'appLogs.emptySubtitle' => 'Protokolle werden hier angezeigt, während die App läuft',
			'appLogs.stackTraceAvailable' => 'Tippen für Stack-Trace',
			'appLogs.detailMessage' => 'NACHRICHT',
			'appLogs.detailError' => 'FEHLER',
			'appLogs.detailExtras' => 'Zusätzlicher Kontext',
			'appLogs.detailStackTrace' => 'STACK-TRACE',
			'appLogs.shareLogs' => 'Protokolldatei teilen',
			'appLogs.exportDone' => 'Protokolle exportiert',
			'coachSettings.accountModeNote' => 'Lieber dein eigener OpenRouter-Schlüssel oder ein lokales Modell? Die gibt es im Privaten Modus.',
			'coachSettings.activeCloud' => ({required Object model}) => 'Cloud · ${model}',
			'coachSettings.activeLocal' => ({required Object model}) => 'Lokal · ${model}',
			'coachSettings.activeLocalNoModel' => 'Lokal · Modell wählen',
			'coachSettings.activeStandard' => ({required Object model}) => 'Evolve AI · ${model}',
			'coachSettings.backendStandard' => 'Evolve AI',
			'coachSettings.baseUrlLabel' => 'Basis-URL',
			'coachSettings.cardLive' => 'Aktiv',
			'coachSettings.cardOff' => 'Aus',
			'coachSettings.cloudKeyMissing' => 'Noch kein Schlüssel — diese Engine antwortet nicht. Verbinde unten dein OpenRouter-Konto, wechsle zu Evolve AI oder nutze einen lokalen Server.',
			'coachSettings.detectedAction' => 'Lokal verwenden',
			'coachSettings.detectedBody' => ({required Object app}) => '${app} läuft auf diesem Mac. Den Coach zu 100 % privat ausführen?',
			'coachSettings.detectedDismiss' => 'Jetzt nicht',
			'coachSettings.detectedTitle' => ({required Object app}) => '${app} erkannt',
			'coachSettings.discovering' => 'Suche nach Modellen…',
			'coachSettings.engineOpenRouter' => 'OpenRouter',
			'coachSettings.engineOpenRouterHint' => 'Dein eigener Schlüssel · kostenlos',
			'coachSettings.getLocalServer' => ({required Object app}) => '${app} installieren',
			'coachSettings.groupEngine' => 'Engine',
			'coachSettings.groupPrivacy' => 'Datenschutz',
			'coachSettings.groupTuning' => 'AI-Coach-Feinabstimmung',
			'coachSettings.lmStudioNoModelsJit' => 'LM Studio listet keine Modelle auf. Es listet nur geladene Modelle, wenn Just-In-Time-Laden aus ist — lade ein Modell in LM Studio oder aktiviere Developer → Server Settings → Just In Time Model Loading.',
			'coachSettings.lmStudioServerOffBody' => 'LM Studio ist geöffnet, aber sein lokaler Server ist aus. Schalte ihn über Developer → Start Server ein oder aktiviere Settings → Run the LLM server on login.',
			'coachSettings.lmStudioServerOffTitle' => 'Der Server von LM Studio läuft nicht',
			'coachSettings.lmStudioStartTimeout' => 'Dauert länger als erwartet — öffne LM Studio und prüfe, ob der Start abgeschlossen ist.',
			'coachSettings.localGroupLabel' => 'Lokal — auf diesem Mac',
			'coachSettings.localServerDownloadFailed' => ({required Object url}) => 'Browser konnte nicht geöffnet werden — besuche ${url}',
			'coachSettings.localServerNotInstalledBody' => ({required Object app}) => 'Installiere die kostenlose ${app}-App und drücke dann Start.',
			'coachSettings.localServerNotInstalledTitle' => ({required Object app}) => '${app} ist nicht installiert',
			'coachSettings.localServerOfflineBody' => 'Starte deinen lokalen Server, um privat zu chatten — ganz ohne Terminal.',
			'coachSettings.localServerOfflineTitle' => ({required Object app}) => '${app} läuft nicht',
			'coachSettings.localServerStartFailed' => ({required Object app}) => '${app} konnte nicht gestartet werden — versuche, es aus dem Programme-Ordner zu öffnen.',
			'coachSettings.localServerStartingBody' => 'Das kann ein paar Sekunden dauern…',
			'coachSettings.manualModelAdd' => 'Dieses Modell verwenden',
			'coachSettings.manualModelLabel' => 'Modell-ID',
			'coachSettings.modelLabel' => 'Modell',
			'coachSettings.noModelsFound' => 'Keine Modelle gefunden — gib unten manuell eine Modell-ID ein.',
			'coachSettings.ollamaServerOffBody' => 'Ollama ist geöffnet, antwortet aber nicht auf seinem Port. Beende es über die Menüleiste und drücke dann erneut Start.',
			'coachSettings.ollamaServerOffTitle' => 'Ollama läuft, antwortet aber nicht',
			'coachSettings.ollamaStartTimeout' => 'Dauert länger als erwartet — prüfe das Ollama-Symbol in der Menüleiste (der erste Start braucht evtl. eine Freigabe).',
			'coachSettings.presetLmStudio' => 'LM Studio',
			'coachSettings.presetOllama' => 'Ollama',
			'coachSettings.refreshModels' => 'Modelle aktualisieren',
			'coachSettings.remoteBadge' => 'Extern',
			'coachSettings.remoteWarning' => 'Dieser Endpunkt ist keine lokale Adresse — Nachrichten verlassen dieses Gerät.',
			'coachSettings.sendMessage' => 'Senden',
			'coachSettings.settingsRowConfigure' => 'Engine & lokaler Server',
			'coachSettings.settingsRowStatus' => 'Aktive Engine',
			'coachSettings.settingsSectionLabel' => 'KI-Coach',
			'coachSettings.settingsSubtitle' => 'Wähle die Engine für deinen Coach und verbinde sie für volle Privatsphäre mit einem lokalen Server.',
			'coachSettings.standardNeedsProNote' => 'Evolve AI ist Teil von Evolve Pro. Schließe ein Abo ab, um es freizuschalten.',
			'coachSettings.standardNeedsSignInNote' => 'Melde dich an, um Evolve AI zu nutzen. Dein Abo schaltet es auf allen Geräten frei.',
			'coachSettings.standardPrivateNote' => 'Evolve AI braucht ein Evolve-Konto, und der Private Modus führt keines. Verbinde dein OpenRouter-Konto oder nutze ein lokales Modell — beides funktioniert hier weiterhin.',
			'coachSettings.standardStatusNeedsPro' => 'Erfordert Pro',
			'coachSettings.standardStatusNeedsSignIn' => 'Anmeldung nötig',
			'coachSettings.standardStatusReady' => 'In Pro enthalten',
			'coachSettings.standardStatusUnavailable' => 'Nicht verfügbar',
			'coachSettings.standardUnavailableNote' => 'Evolve AI ist in diesem Build nicht verfügbar. Verbinde dein OpenRouter-Konto oder nutze ein lokales Modell.',
			'coachSettings.startLocalServer' => ({required Object app}) => '${app} starten',
			'coachSettings.startingLocalServer' => ({required Object app}) => '${app} wird gestartet…',
			'coachSettings.statusChecking' => 'Wird geprüft…',
			'coachSettings.statusConnected' => 'Verbunden',
			'coachSettings.statusOffline' => 'Server offline',
			'coachSettings.stopResponse' => 'Stopp',
			'coachSettings.systemPromptHint' => 'Coach-Persona überschreiben (leer lassen für Standard)',
			'coachSettings.systemPromptLabel' => 'System-Prompt',
			'coachSettings.systemPromptReset' => 'Zurücksetzen',
			'coachSettings.temperatureLabel' => 'Temperatur',
			'coachSettings.temperatureLower' => 'Temperatur senken',
			'coachSettings.temperatureRaise' => 'Temperatur erhöhen',
			'coachSettings.tuningFootnote' => 'Sie gelten für jede Engine, auch für Evolve AI.',
			'coachSettings.useCustomServer' => 'Eigenen Server verwenden…',
			'tour.back' => 'Zurück',
			'tour.next' => 'Weiter',
			'tour.continueLabel' => 'Weiter',
			'tour.finish' => 'Fertig',
			'tour.welcomeTitle' => 'Willkommen bei Evolve',
			'tour.welcomeBody' => 'Machen wir eine kurze Tour durch deinen Arbeitsbereich — von der täglichen Übersicht bis zu deinem KI-Coach. Es dauert nur einen Moment.',
			'tour.welcomeStart' => 'Tour starten',
			'tour.welcomeSkip' => 'Tutorial überspringen',
			'tour.doneTitle' => 'Alles bereit',
			'tour.doneBody' => 'Das ist die ganze App. Starte über die Seitenleiste, wo du willst — und du kannst die Tour jederzeit in den Einstellungen wiederholen.',
			'tour.doneButton' => 'Loslegen',
			'tour.overviewOrientationTitle' => 'Deine Übersicht',
			'tour.overviewOrientationDesc' => 'Das ist deine tägliche Basis — ein Überblick über heute, sobald du Evolve öffnest.',
			'tour.overviewCheckinTitle' => 'Täglicher Check-in',
			'tour.overviewCheckinDesc' => 'Halte fest, wie dein Tag läuft. Mit der Zeit zeigt sich, wie deine Stimmung mit Gewohnheiten und Zielen zusammenhängt.',
			'tour.overviewHabitsTitle' => 'Heutige Gewohnheiten',
			'tour.overviewHabitsDesc' => 'Die für heute geplanten Gewohnheiten stehen hier — hake sie nach und nach ab.',
			'tour.overviewGoalsTitle' => 'Fokus-Ziele',
			'tour.overviewGoalsDesc' => 'Die Ziele, auf die du dich konzentrierst, erscheinen hier, damit nichts untergeht.',
			'tour.habitsOrientationTitle' => 'Die Gewohnheiten-Seite',
			'tour.habitsOrientationDesc' => 'Hier baust du dein tägliches Protokoll auf und verfolgst deine Beständigkeit.',
			'tour.habitsAddTitle' => 'Gewohnheit hinzufügen',
			'tour.habitsAddDesc' => 'Erstelle hier eine neue Gewohnheit — mit Name, Kategorie, Farbe und optionaler Erinnerung.',
			'tour.habitsCheckoffTitle' => 'Als erledigt markieren',
			'tour.habitsCheckoffDesc' => 'Setze hier ein Häkchen, um eine Gewohnheit für heute abzuschließen. Mehr braucht es nicht, um eine Serie am Leben zu halten.',
			'tour.habitsStreakTitle' => 'Serien & Verlauf',
			'tour.habitsStreakDesc' => 'Sieh deine Serie wachsen und deine letzten sieben Tage auf einen Blick.',
			'tour.habitsCalendarTitle' => 'Kalenderansicht',
			'tour.habitsCalendarDesc' => 'Wechsle zum Kalender, um deinen Verlauf nach Woche, Monat, Jahr — oder deinem ganzen Leben zu sehen.',
			'tour.insightsOrientationTitle' => 'Deine Statistiken',
			'tour.insightsOrientationDesc' => 'Sieh, wie sich Gewohnheiten und Ziele über die Zeit entwickeln und wo du abweichst.',
			'tour.insightsFilterTitle' => 'Nach Gewohnheit filtern',
			'tour.insightsFilterDesc' => 'Konzentriere die Statistik auf eine einzelne Gewohnheit oder behalte den Gesamtüberblick.',
			'tour.insightsTabsTitle' => 'Statistik-Bereiche',
			'tour.insightsTabsDesc' => 'Wechsle zwischen den Bereichen für Trends, Hinweise, Gewohnheits-Fortschritt und deine Stimmung.',
			'tour.goalsOrientationTitle' => 'Die Ziele-Seite',
			'tour.goalsOrientationDesc' => 'Setze und verfolge deine größeren Ziele — das, worauf deine täglichen Gewohnheiten hinarbeiten.',
			'tour.goalsPlanTitle' => 'Planungsart',
			'tour.goalsPlanDesc' => 'Wähle, wie du planst — täglich, wöchentlich oder länger — passend zu deiner Denkweise über Ziele.',
			'tour.goalsAddTitle' => 'Ziel hinzufügen',
			'tour.goalsAddDesc' => 'Erstelle hier ein neues Ziel und gib ihm eine Vorgabe, auf die du hinarbeitest.',
			'tour.goalsCheckTitle' => 'Erreichen oder verfehlen',
			'tour.goalsCheckDesc' => 'Markiere ein Ziel als erreicht oder verfehlt. Jedes Ergebnis fließt mit der Zeit in deine Leistung ein.',
			'tour.goalsStatsTitle' => 'Leistung',
			'tour.goalsStatsDesc' => 'Schalte die Leistungsstatistik ein, um zu sehen, wie du bei deinen Zielen stehst.',
			'tour.coachOrientationTitle' => 'Dein KI-Coach',
			'tour.coachOrientationDesc' => 'Persönliche Begleitung auf Basis deiner echten Gewohnheiten und Ziele — direkt auf deinem Mac.',
			'tour.coachModelTitle' => 'Wähle die Engine',
			'tour.coachModelDesc' => 'Wähle das KI-Modell — unsere Cloud oder ein lokales Modell, das privat auf deinem Mac läuft. Auch die Servereinstellungen sind hier.',
			'tour.coachContextTitle' => 'Was der Coach sieht',
			'tour.coachContextDesc' => 'Bestimme, ob der Coach deine Gewohnheiten und Ziele nutzen darf, um seine Ratschläge anzupassen.',
			'tour.coachSuggestionsTitle' => 'Erste Impulse',
			'tour.coachSuggestionsDesc' => 'Nicht sicher, wo du anfangen sollst? Tippe auf einen dieser Vorschläge, um loszulegen.',
			'tour.coachInputTitle' => 'Frag alles',
			'tour.coachInputDesc' => 'Gib hier deine Frage ein und drücke Senden. Damit endet die Tour — viel Freude mit Evolve!',
			'palette.searchHint' => 'Ziele, Gewohnheiten, Einstellungen, Aktionen suchen…',
			'palette.groupSuggested' => 'Vorschläge',
			'palette.groupThisWeek' => 'Diese Woche',
			'palette.groupGoals' => 'Ziele',
			'palette.groupHabits' => 'Gewohnheiten',
			'palette.groupActions' => 'Aktionen',
			'palette.groupSections' => 'Gehe zu',
			'palette.groupSettings' => 'Einstellungen',
			'palette.goToThisWeek' => 'Zu dieser Woche',
			'palette.createGoalBlank' => 'Ziel erstellen',
			'palette.createGoal' => ({required Object title}) => 'Ziel „${title}“ erstellen',
			'palette.createHabit' => ({required Object title}) => 'Gewohnheit „${title}“ erstellen',
			'palette.goToPeriod' => ({required Object period}) => 'Gehe zu ${period}',
			'palette.switchToDark' => 'Zum dunklen Design wechseln',
			'palette.switchToLight' => 'Zum hellen Design wechseln',
			'palette.manageCategories' => 'Zielkategorien verwalten',
			'palette.replayTour' => 'Geführte Tour wiederholen',
			'palette.noResults' => ({required Object query}) => 'Keine Ergebnisse für „${query}“',
			'palette.rowOpen' => 'Öffnen',
			'palette.rowComplete' => 'Als erledigt markieren',
			'palette.rowReschedule' => 'Auf nächste Periode verschieben',
			'palette.deleteGoalTitle' => 'Ziel löschen?',
			'palette.deleteGoalMessage' => ({required Object title}) => '„${title}“ wird dauerhaft gelöscht.',
			'palette.deleteHabitTitle' => 'Gewohnheit löschen?',
			'palette.deleteHabitMessage' => ({required Object title}) => '„${title}“ wird dauerhaft gelöscht.',
			'palette.footerNavigate' => 'navigieren',
			'palette.footerOpen' => 'öffnen',
			'palette.footerMenu' => 'Menü',
			'palette.footerClose' => 'schließen',
			'targets.sectionTitle' => 'Ziel',
			'targets.none' => 'Einfach',
			'targets.atLeastLabel' => 'Erreiche',
			'targets.atMostLabel' => 'Bleib unter',
			'targets.presets.countDaily.label' => 'Anzahl',
			'targets.presets.countDaily.description' => 'Erledige es eine bestimmte Anzahl pro Tag.',
			'targets.presets.durationDaily.label' => 'Dauer',
			'targets.presets.durationDaily.description' => 'Verbringe eine bestimmte Anzahl Minuten pro Tag.',
			'targets.presets.limitCountDaily.label' => 'Limit',
			'targets.presets.limitCountDaily.description' => 'Bleib täglich unter einer bestimmten Anzahl.',
			'targets.presets.limitDurationDaily.label' => 'Zeitlimit',
			'targets.presets.limitDurationDaily.description' => 'Bleib täglich unter einer bestimmten Minutenzahl.',
			'targets.units.min' => 'Min.',
			'targets.units.hour' => 'Std.',
			'targets.units.kcal' => 'kcal',
			'targets.units.km' => 'km',
			'targets.entry.keepGoing' => 'Weiter so',
			'targets.entry.withinLimit' => 'Innerhalb des Limits',
			'targets.entry.overLimit' => 'Über dem Limit',
			'targets.amountLabel' => 'Erreiche',
			'targets.amountLabelAtMost' => 'Bleib unter',
			'targets.stepLabel' => 'Schritt',
			'targets.stepHint' => ({required Object step}) => 'Jedes + fügt ${step} hinzu',
			'targets.rangeError' => ({required Object min, required Object max}) => 'Gib eine Zahl zwischen ${min} und ${max} ein',
			'targets.stepPositiveError' => 'Der Schritt muss größer als 0 sein',
			'targets.stepExceedsWarning' => 'Ein Tippen würde das ganze Ziel überschreiten',
			'targets.notDivisibleWarning' => ({required Object amount, required Object below, required Object above}) => 'Du kannst ${amount} nicht genau treffen — Tippen erreicht ${below}, dann ${above}',
			'targets.notDivisibleWarningNoBelow' => ({required Object amount, required Object above}) => 'Du kannst ${amount} nicht genau treffen — das erste Tippen erreicht ${above}',
			'targets.tooManyTapsWarning' => ({required Object taps}) => 'Das sind ${taps} Tipp-Vorgänge für einen Tag',
			'targets.confirmTitle' => 'Ziel prüfen',
			'targets.confirmAdjust' => 'Anpassen',
			'targets.confirmSaveAnyway' => 'Trotzdem speichern',
			'trackingMode.title' => 'Wie wird es erfasst?',
			'trackingMode.checkbox' => 'Häkchen',
			'trackingMode.number' => 'Zahl',
			'trackingMode.automatic' => 'Automatisch',
			'trackingMode.automaticLocked' => 'Verifiziert — auf dem iPhone bearbeiten',
			_ => null,
		};
	}
}
