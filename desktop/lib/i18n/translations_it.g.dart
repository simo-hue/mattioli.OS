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
class TranslationsIt extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsIt({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.it,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <it>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsIt _root = this; // ignore: unused_field

	@override 
	TranslationsIt $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsIt(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$auth$it auth = _Translations$auth$it._(_root);
	@override late final _Translations$privateAi$it privateAi = _Translations$privateAi$it._(_root);
	@override late final _Translations$privateData$it privateData = _Translations$privateData$it._(_root);
	@override late final _Translations$icloudSync$it icloudSync = _Translations$icloudSync$it._(_root);
	@override late final _Translations$namePrompt$it namePrompt = _Translations$namePrompt$it._(_root);
	@override late final _Translations$nav$it nav = _Translations$nav$it._(_root);
	@override late final _Translations$shell$it shell = _Translations$shell$it._(_root);
	@override late final _Translations$common$it common = _Translations$common$it._(_root);
	@override late final _Translations$form$it form = _Translations$form$it._(_root);
	@override late final _Translations$createGoal$it createGoal = _Translations$createGoal$it._(_root);
	@override late final _Translations$createHabit$it createHabit = _Translations$createHabit$it._(_root);
	@override late final _Translations$macroGoals$it macroGoals = _Translations$macroGoals$it._(_root);
	@override late final _Translations$statistics$it statistics = _Translations$statistics$it._(_root);
	@override late final _Translations$goalState$it goalState = _Translations$goalState$it._(_root);
	@override late final _Translations$dueLabel$it dueLabel = _Translations$dueLabel$it._(_root);
	@override late final _Translations$dashboard$it dashboard = _Translations$dashboard$it._(_root);
	@override late final _Translations$stats$it stats = _Translations$stats$it._(_root);
	@override late final _Translations$habitsPage$it habitsPage = _Translations$habitsPage$it._(_root);
	@override String get lavoro => 'Lavoro';
	@override String get salute => 'Salute';
	@override String get finanza => 'Finanza';
	@override String get relazioni => 'Relazioni';
	@override String get formazione => 'Formazione';
	@override String get hobby => 'Hobby';
	@override String get spirituale => 'Spirituale';
	@override String get altro => 'Altro';
	@override late final _Translations$goalsPage$it goalsPage = _Translations$goalsPage$it._(_root);
	@override late final _Translations$goalsStats$it goalsStats = _Translations$goalsStats$it._(_root);
	@override late final _Translations$ai$it ai = _Translations$ai$it._(_root);
	@override late final _Translations$aiCoach$it aiCoach = _Translations$aiCoach$it._(_root);
	@override late final _Translations$settingsPage$it settingsPage = _Translations$settingsPage$it._(_root);
	@override late final _Translations$consent$it consent = _Translations$consent$it._(_root);
	@override late final _Translations$notifications$it notifications = _Translations$notifications$it._(_root);
	@override late final _Translations$privacy$it privacy = _Translations$privacy$it._(_root);
	@override late final _Translations$consentPage$it consentPage = _Translations$consentPage$it._(_root);
	@override late final _Translations$notif$it notif = _Translations$notif$it._(_root);
	@override late final _Translations$biometricGate$it biometricGate = _Translations$biometricGate$it._(_root);
	@override late final _Translations$sync$it sync = _Translations$sync$it._(_root);
	@override late final _Translations$subscriptionCtrl$it subscriptionCtrl = _Translations$subscriptionCtrl$it._(_root);
	@override late final _Translations$authCtrl$it authCtrl = _Translations$authCtrl$it._(_root);
	@override late final _Translations$proModal$it proModal = _Translations$proModal$it._(_root);
	@override late final _Translations$tutorial$it tutorial = _Translations$tutorial$it._(_root);
	@override late final _Translations$appLogs$it appLogs = _Translations$appLogs$it._(_root);
}

// Path: auth
class _Translations$auth$it extends Translations$auth$en {
	_Translations$auth$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get continuePrivately => 'Continua in modalità privata su questo Mac';
	@override String get signIn => 'Accedi';
	@override String get register => 'Registrati';
	@override String get or => 'OPPURE';
	@override String get password => 'Password';
	@override String get forgotPassword => 'Password dimenticata?';
	@override String get haveAccount => 'Hai già un account?';
	@override String get noAccount => 'Non hai un account?';
	@override String get continueWithApple => 'Continua con Apple';
	@override String get continueWithGoogle => 'Continua con Google';
	@override String get readPrivacyPolicy => 'Leggi Privacy Policy';
	@override String get nameLabel => 'Nome';
	@override String get invalidEmail => 'Inserisci un\'email valida';
	@override String get confirmEmail => 'Controlla la tua email per confermare la registrazione.';
	@override String get resetSent => 'Email inviata! Controlla la tua casella di posta.';
	@override String get signInTitle => 'Accedi a Evolve';
	@override String get signUpTitle => 'Crea il tuo account';
	@override String get resetTitle => 'Recupera password';
	@override String get emailLabel => 'Email';
	@override String get passwordMin8 => 'Usa almeno 8 caratteri.';
	@override String get sendResetLink => 'Invia link di recupero';
}

// Path: privateAi
class _Translations$privateAi$it extends Translations$privateAi$en {
	_Translations$privateAi$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get consentTitle => 'Consenti l\'invio all\'AI';
	@override String get consentBody => 'In modalità privata i tuoi dati restano sul dispositivo. Per usare l\'AI Coach, le abitudini e gli obiettivi che scegli di condividere vengono inviati a un provider AI esterno (OpenRouter). Vuoi procedere?';
	@override String get cancel => 'Annulla';
	@override String get accept => 'Accetto';
}

// Path: privateData
class _Translations$privateData$it extends Translations$privateData$en {
	_Translations$privateData$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get deleteTitle => 'Elimina dati privati';
	@override String get deleteMessage => 'Sei sicuro di voler eliminare tutto il database locale crittografato? Questa operazione è irreversibile e i dati non potranno essere recuperati.';
	@override String get deleteSuccess => 'Dati privati eliminati.';
	@override String get deleteFailed => 'Operazione non riuscita.';
	@override String get exportDoneTitle => 'Export completato';
	@override String get exportDoneClipboard => 'Il JSON è negli appunti: Linux non supporta la condivisione file.';
	@override String get exportDoneShare => 'Il JSON è stato inviato al selettore di condivisione.';
}

// Path: icloudSync
class _Translations$icloudSync$it extends Translations$icloudSync$en {
	_Translations$icloudSync$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sincronizzazione iCloud';
	@override String get enableTitle => 'Abilita sincronizzazione iCloud';
	@override String get syncNow => 'Sincronizza ora';
	@override String get disclosureTitle => 'Crittografia end-to-end';
	@override String get disclosureBody => 'I tuoi dati privati si sincronizzano solo tramite il tuo account iCloud, con crittografia end-to-end — mai attraverso i nostri server. La chiave di crittografia risiede nel tuo Portachiavi iCloud; se disattivi il Portachiavi iCloud, i dati sincronizzati non potranno essere recuperati.';
	@override String get disclosureAccept => 'Abilita';
	@override String get statusIdle => 'Aggiornato';
	@override String get statusSyncing => 'Sincronizzazione…';
	@override String get statusOff => 'Sincronizzazione disattivata';
	@override String get statusNoAccount => 'Accedi a iCloud per sincronizzare';
	@override String get statusUnavailable => 'iCloud non è disponibile al momento';
	@override String get statusWaitingKeychain => 'In attesa del Portachiavi iCloud — assicurati che l\'app sul tuo iPhone sia aggiornata';
	@override String get lastSyncedNever => 'Mai sincronizzato';
	@override String lastSyncedAt({required Object time}) => 'Ultima sincronizzazione ${time}';
	@override String get deleteSyncNote => 'La sincronizzazione iCloud è attiva: verrà eliminata anche la copia sincronizzata nel tuo iCloud e la sincronizzazione verrà disattivata. Gli altri dispositivi conservano la loro copia locale — esegui questa operazione su ciascun dispositivo per eliminare tutto ovunque.';
}

// Path: namePrompt
class _Translations$namePrompt$it extends Translations$namePrompt$en {
	_Translations$namePrompt$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Come ti chiami?';
	@override String get subtitle => 'Inserisci il tuo nome per personalizzare la dashboard.';
	@override String get hint => 'Es. Simo';
	@override String get save => 'Salva e continua';
}

// Path: nav
class _Translations$nav$it extends Translations$nav$en {
	_Translations$nav$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get overview => 'Panoramica';
	@override String get habits => 'Abitudini';
	@override String get insights => 'Statistiche';
	@override String get goals => 'Obiettivi';
	@override String get coach => 'AI Coach';
	@override String get settings => 'Impostazioni';
}

// Path: shell
class _Translations$shell$it extends Translations$shell$en {
	_Translations$shell$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get syncPending => 'Sync in attesa';
	@override String get syncing => 'Sincronizzazione';
	@override String get synced => 'Sincronizzato';
	@override String get syncTooltip => 'Sincronizza';
	@override String get searchHint => 'Cerca o naviga';
	@override String get searchSectionHint => 'Cerca una sezione...';
}

// Path: common
class _Translations$common$it extends Translations$common$en {
	_Translations$common$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override late final _Translations$common$actions$it actions = _Translations$common$actions$it._(_root);
	@override List<String> get months => [
		'Gennaio',
		'Febbraio',
		'Marzo',
		'Aprile',
		'Maggio',
		'Giugno',
		'Luglio',
		'Agosto',
		'Settembre',
		'Ottobre',
		'Novembre',
		'Dicembre',
	];
	@override List<String> get weekdayInitials => [
		'L',
		'M',
		'M',
		'G',
		'V',
		'S',
		'D',
	];
	@override late final _Translations$common$calendarView$it calendarView = _Translations$common$calendarView$it._(_root);
	@override List<String> get weekdaysLong => [
		'Lunedì',
		'Martedì',
		'Mercoledì',
		'Giovedì',
		'Venerdì',
		'Sabato',
		'Domenica',
	];
	@override String get none => 'Nessuno';
	@override String get habits => 'Abitudini';
	@override late final _Translations$common$status$it status = _Translations$common$status$it._(_root);
	@override String get total => 'Totale';
	@override String get completed => 'Completati';
}

// Path: form
class _Translations$form$it extends Translations$form$en {
	_Translations$form$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Titolo';
	@override String get category => 'Categoria';
	@override String get color => 'Colore';
	@override String get add => 'Aggiungi';
}

// Path: createGoal
class _Translations$createGoal$it extends Translations$createGoal$en {
	_Translations$createGoal$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Nuovo Obiettivo';
	@override String get subtitle => 'Definisci il tuo prossimo traguardo.';
	@override String get titleHint => 'es. Lanciare il nuovo prodotto';
	@override String get categoryHint => 'es. Lavoro';
	@override String get timeline => 'Timeline';
	@override String get thisWeek => 'Questa Settimana';
	@override String get thisMonth => 'Questo Mese';
	@override String get thisQuarter => 'Questo Trimestre';
	@override String get thisYear => 'Quest\'Anno';
	@override String get longTerm => 'Lungo termine (Lifetime)';
	@override String get dueLifetime => 'Tutta la vita';
	@override String dueByYear({required Object year}) => 'Entro il ${year}';
	@override String get defaultCategory => 'Obiettivo';
}

// Path: createHabit
class _Translations$createHabit$it extends Translations$createHabit$en {
	_Translations$createHabit$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Nuova Abitudine';
	@override String get subtitle => 'Definisci la tua nuova abitudine.';
	@override String get titleHint => 'es. Meditazione';
	@override String get categoryHint => 'es. Benessere';
	@override String get weeklyFrequency => 'Frequenza settimanale';
	@override String get defaultCategory => 'Generale';
}

// Path: macroGoals
class _Translations$macroGoals$it extends Translations$macroGoals$en {
	_Translations$macroGoals$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override late final _Translations$macroGoals$types$it types = _Translations$macroGoals$types$it._(_root);
	@override String quarterNumber({required Object quarter}) => 'Trimestre ${quarter}';
	@override String get addLifetimeGoal => 'Aggiungi obiettivo lifetime...';
	@override String get addAnnualGoal => 'Aggiungi obiettivo annuale...';
	@override String get addQuarterlyGoal => 'Aggiungi obiettivo trimestrale...';
	@override String get addMonthlyGoal => 'Aggiungi obiettivo mensile...';
	@override String get addWeeklyGoal => 'Aggiungi obiettivo settimanale...';
	@override String get completed => 'COMPLETATI';
	@override String get failed => 'FALLITI';
	@override String get create => 'Crea';
	@override String get strength => 'Punto di Forza';
	@override String get bestMonth => 'Mese Migliore';
	@override String get successRate2 => 'di successo';
	@override String get effectiveType => 'Tipologia Efficace';
	@override String get historicalTotal => 'Totale Storico';
	@override String get from_ => 'dal';
	@override String get globalSuccess => 'Successo Globale';
	@override String get completedGoals => 'obiettivi completati';
	@override String get bestYear => 'Anno Migliore';
	@override String get mostProductiveYear => 'Anno Più Produttivo';
	@override String get totalGoals => 'obiettivi totali';
	@override String get allYears => 'Tutti gli anni';
	@override String get selectYearHeader => 'SELEZIONA ANNO';
	@override String get completions => 'Completamenti';
	@override String get success2 => 'Successo';
	@override String get archiveCategory2 => 'Archiviare categoria?';
	@override String categoryUnavailableLinked({required Object label, required Object count}) => 'La categoria "${label}" non sarà più disponibile per nuovi obiettivi, ma resterà collegata a ${count} obiettivi storici e alle statistiche.';
	@override String categoryUnavailableArchived({required Object label}) => 'La categoria "${label}" non sarà più disponibile per nuovi obiettivi, ma resterà nello storico.';
	@override String get archive => 'Archivia';
	@override String get createNewCategory => 'Crea nuova categoria';
}

// Path: statistics
class _Translations$statistics$it extends Translations$statistics$en {
	_Translations$statistics$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get completed2 => 'Completato';
	@override String get notCompleted => 'Non completato';
	@override String get ofCompletion => 'di completamento';
	@override String get growth => 'Crescita';
	@override String get decline => 'Calo';
	@override String get strongestDay => 'Giorno più forte';
	@override String get weakestDay => 'Giorno più debole';
	@override String get worstNegativeStreak => 'Serie Negativa Peggiore';
	@override String get missedConsecutiveDays => 'giorni consecutivi mancati';
	@override String get brokenStreaks => 'Streak Interrotti';
	@override String get noBrokenStreaks => 'Nessun streak interrotto registrato';
	@override String get startedOn => 'Iniziata il';
	@override String get moodCorrelation => 'Correlazione Mood';
	@override String get avgMood => 'Mood Medio (✓)';
	@override String get avgEnergy => 'Energia Media (✓)';
	@override String get onCompletedDays => 'nei giorni completati';
	@override String get resilient => 'Resiliente';
	@override String get completedVsMissed => 'Completato vs Mancato';
	@override String get mood2 => 'Umore';
	@override String get energy => 'Energia';
	@override String get performancePerLevel => 'Performance per Livello';
	@override String get withHighMood => 'Con Mood Alto';
	@override String get withLowMood => 'Con Mood Basso';
	@override String get moodEnergyAnalysis => 'L\'analisi mostra come la tua costanza è influenzata dal tuo stato d\'animo ed energia.';
	@override String get missed2 => 'Mancato';
	@override String get positive => 'positiva';
	@override String get neutral => 'neutra';
	@override String get high => 'alta';
	@override String get low => 'bassa';
	@override String get skipped => 'Saltato';
	@override String get criticalHabits => 'Abitudini Critiche';
	@override String get bestHabitsTitle => 'Abitudini Migliori';
	@override String get worseningHabitsDescription => 'Le abitudini che stanno peggiorando di più.';
	@override String get everythingIsGreat => 'Tutto alla grande!';
	@override String get allHabitsStableDescription => 'Tutte le tue abitudini stanno mantenendo o migliorando il loro trend. Continua così.';
	@override String habitCompletionPeriodDescription({required Object rate}) => 'Hai completato questa abitudine il ${rate}% delle volte nel periodo selezionato.';
	@override String habitLostConsistencyDescription({required Object drop}) => 'Questa abitudine ha perso il ${drop}% di costanza nell’ultima settimana rispetto alla precedente.';
	@override String get negativeStreak => 'Streak Negativa';
	@override String get currentStreak2 => 'Serie Attuale';
	@override String get improvementAreas => 'Aree di Miglioramento';
	@override String get habitsRequiringMoreAttention => 'Abitudini che richiedono più attenzione.';
	@override String get failureAnalysis => 'Analisi Fallimenti';
	@override String get missedDaysPattern => 'Frequenza e pattern dei tuoi giorni mancati.';
	@override String get recoveryPatterns => 'Pattern di Recupero';
	@override String get recoverySpeed => 'Quanto velocemente torni in carreggiata dopo un errore.';
	@override String get avgRecoveryTime => 'Tempo Medio Recupero';
	@override String get worstStreak => 'WORST STREAK';
	@override String get frequency => 'FREQUENZA';
	@override String get daysShortUnit => 'gg';
	@override String get perMonthUnit => 'mese';
	@override String get succ => 'succ.';
	@override String get blackDay => 'GIORNO NERO';
	@override String get correlationsWith => 'Correlazioni con';
	@override String get howThisHabitRelatesToOthers => 'Come questa abitudine si relaziona con le altre';
	@override String get positiveCorrelations => 'Correlazioni Positive';
	@override String get negativeCorrelations => 'Correlazioni Negative';
	@override String get noSignificantPositiveCorrelation => 'Nessuna correlazione positiva significativa';
	@override String get noSignificantNegativeCorrelation => 'Nessuna correlazione negativa significativa';
	@override String habitTogetherPercent({required Object percentage}) => '${percentage}% insieme';
	@override String habitPositiveCorrelationDescription({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'Quando completi "${currentGoal}", hai una probabilità del ${percentage}% di completare anche "${otherGoal}".';
	@override String habitNegativeCorrelationDescription({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'Quando completi "${currentGoal}", hai solo una probabilità del ${percentage}% di completare anche "${otherGoal}".';
	@override String get weeklyTrend => 'Trend Settimanale';
	@override String get monthlyTrend => 'Trend Mensile';
	@override String get yearlyTrend => 'Trend Annuale';
	@override String get performanceEvolution => 'Evoluzione Performance';
	@override String get globalTrend => 'Trend Globale';
	@override String get total => 'Totale';
	@override String get all => 'Tutto';
	@override String get noDataForAlerts => 'Nessun dato sufficiente per generare alert.';
	@override String get missed => 'Mancati';
}

// Path: goalState
class _Translations$goalState$it extends Translations$goalState$en {
	_Translations$goalState$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get active => 'In corso';
}

// Path: dueLabel
class _Translations$dueLabel$it extends Translations$dueLabel$en {
	_Translations$dueLabel$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get lifetime => 'Obiettivo di vita';
	@override String get annual => 'Obiettivo annuale';
	@override String get quarter => 'Trimestre';
}

// Path: dashboard
class _Translations$dashboard$it extends Translations$dashboard$en {
	_Translations$dashboard$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get mood => 'Umore';
	@override String get energy => 'Energia';
	@override String get goodMorning => 'Buongiorno';
	@override String get goodAfternoon => 'Buon pomeriggio';
	@override String get goodEvening => 'Buonasera';
	@override String get manager => 'Gestione';
	@override String get aiChat => 'AI Chat';
	@override String get consecutiveDays => 'giorni consecutivi';
	@override String get welcomeTitle => 'Benvenuto in Evolve';
	@override String get welcomeSubtitle => 'Inizia il tuo percorso di crescita personale.';
	@override String get welcomeBody => 'Questa applicazione ti aiuta a costruire buone abitudini e raggiungere i tuoi obiettivi a lungo termine.';
	@override String get welcomeStart => 'Inizia';
	@override String get subtitle => 'Mantieni il ritmo. Ogni piccola azione consolida la persona che stai costruendo.';
	@override String get completionToday => 'Completamento oggi';
	@override String habitsCount({required Object done, required Object total}) => '${done}/${total} abitudini';
	@override String get bestStreak => 'Migliore serie';
	@override String get activeGoals => 'Obiettivi attivi';
	@override String avgProgress({required Object pct}) => '${pct}% progresso medio';
	@override String get momentum => 'Momentum';
	@override String get vsLastWeek => 'rispetto alla scorsa settimana';
	@override String get weeklyTrend => 'Andamento settimanale';
	@override String get weeklyTrendSubtitle => 'Percentuale di completamento delle tue abitudini';
	@override String thisWeekPill({required Object value}) => '${value} questa settimana';
	@override String get todayProtocol => 'Protocollo di oggi';
	@override String get todayProtocolSubtitle => 'Completa le azioni essenziali prima di aggiungere altro';
	@override String actionsCount({required Object count}) => '${count} azioni';
	@override String get emptyHabits => 'Il tuo canvas è vuoto. Crea la tua prima abitudine.';
	@override String streakDaysShort({required Object n}) => '${n} gg';
	@override String get checkInDone => 'Check-in registrato';
	@override String get checkInPrompt => 'Come ti senti oggi?';
	@override String moodEnergyValue({required Object mood, required Object energy}) => 'Umore ${mood}/10 · Energia ${energy}/10';
	@override String get checkInHint => 'Registra umore ed energia per migliorare le analisi dei tuoi pattern.';
	@override String get updateCheckIn => 'Aggiorna check-in';
	@override String get doCheckIn => 'Fai il check-in';
	@override String get dailyCheckIn => 'Check-in quotidiano';
	@override String get dailyCheckInSubtitle => 'Una rilevazione rapida aiuta Evolve a leggere meglio i tuoi pattern.';
	@override String get record => 'Registra';
	@override String get focusGoals => 'Obiettivi in focus';
	@override String get currentPriorities => 'Priorità correnti';
	@override String get goalLimitReached => 'Limite di 100 obiettivi raggiunto. Passa a Pro per crearne altri.';
	@override String get emptyFocusGoals => 'Nessun obiettivo in focus. Aggiungine uno.';
	@override String get weekToStart => 'Settimana da avviare';
	@override String get weekGrowing => 'Settimana in crescita';
	@override String get weekToRecover => 'Settimana da recuperare';
	@override String vsPreviousWeek({required Object value}) => '${value} rispetto alla settimana precedente.';
}

// Path: stats
class _Translations$stats$it extends Translations$stats$en {
	_Translations$stats$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Statistiche';
	@override String get global => 'Globale';
	@override String get resilience => 'Resilienza';
	@override String get tabHabits => 'Abitudini';
	@override String get tabMood => 'Umore';
	@override String get last30Days => 'Ultimi 30 giorni';
	@override String get singleHabit => 'Singola abitudine';
	@override String get noHabit => 'Nessuna abitudine';
	@override String get completionToday => 'Completamento oggi';
	@override String get bestStreakLabel => 'Serie migliore';
	@override String get criticalDay => 'Giorno critico';
	@override String get completePrioritiesFirst => 'Completa prima le priorità';
	@override String get recentActivity => 'Attività recente';
	@override String get recentActivitySubtitle => 'Intensità di completamento negli ultimi 90 giorni';
	@override String get trendGlobal => 'Trend globale';
	@override String get trendGlobalSubtitle => 'Confronto temporale del protocollo';
	@override String vsPrevDay({required Object value}) => '${value}% vs giorno precedente';
	@override String get bestHabit => 'Abitudine migliore';
	@override String get criticalArea => 'Area critica';
	@override String get streakAtRisk => 'Serie a rischio';
	@override String streakAtRiskDetail({required Object habit}) => '${habit} richiede attenzione nei prossimi check-in.';
	@override String get patternToConsolidate => 'Pattern da consolidare';
	@override String get checkLowMoodDays => 'Controlla i giorni con umore basso e mantieni il protocollo essenziale.';
	@override String get goalDue => 'Obiettivo in scadenza';
	@override String get noGoalNeedsIntervention => 'Nessun obiettivo attivo richiede un intervento.';
	@override String get performancePerHabit => 'Performance per abitudine';
	@override String get performancePerHabitSubtitle => 'Classifica calcolata dai log sincronizzati per consistenza settimanale';
	@override String get avgMood => 'Umore medio';
	@override String get avgEnergy => 'Energia media';
	@override String checkInsAvailable({required Object count}) => '${count} check-in disponibili';
	@override String get resilientHabit => 'Abitudine resiliente';
	@override String get completedEvenHardDays => 'Completata anche nei giorni difficili';
	@override String get moodEnergy => 'Umore ed energia';
	@override String get moodEnergySubtitle => 'Media dei check-in disponibili negli ultimi 90 giorni';
	@override String get completion => 'Completamento';
	@override String get currentWeek => 'Settimana corrente';
	@override String get currentStreak => 'Serie corrente';
	@override String get currentStreakDetail => 'Serie sincronizzata dai log disponibili';
	@override String get trend30 => 'Trend 30 giorni';
	@override String get trend30Detail => 'Completamento negli ultimi 30 giorni';
	@override String get yearlyCalendar => 'Calendario annuale';
	@override String yearlyCalendarSubtitle({required Object habit}) => 'Distribuzione dei completamenti di ${habit}';
	@override String get performancePerDay => 'Performance per giorno';
	@override String get performancePerDaySubtitle => 'Giorni forti e giorni deboli della settimana';
	@override String protectStreak({required Object days}) => 'Proteggi la serie di ${days} giorni';
	@override String get keepSameSlot => 'Mantieni la stessa fascia oraria per ridurre la frizione nei giorni più intensi.';
	@override String worstNegativeSeq({required Object days}) => 'La peggiore sequenza negativa è durata ${days} giorni.';
	@override String get positiveLever => 'Leva positiva rilevata';
	@override String bestHabitRegularity({required Object habit}) => '${habit} mantiene la migliore regolarità recente.';
	@override String get moodSensitivity => 'Sensibilità all\'umore';
	@override String get lowEnergyCompletion => 'Completamento con energia bassa';
	@override String get moodOutputCorrelation => 'Correlazione umore-output';
	@override String get moodOutputSubtitle => 'Completamenti disponibili nei giorni con check-in';
	@override String get keyCorrelations => 'Correlazioni chiave';
	@override String get keyCorrelationsSubtitle => 'Pattern che influenzano maggiormente il protocollo';
	@override String get moreLogsNeeded => 'Servono più log per calcolare correlazioni utili.';
	@override String get createHabitForAnalysis => 'Crea almeno un\'abitudine per visualizzare l\'analisi granulare.';
	@override String get noData => 'Nessun dato';
	@override String get tabInfo => 'Info';
	@override String get tabTrend => 'Trend';
	@override String get tabAlerts => 'Alert';
	@override String get tabOverview => 'Overview';
	@override String get tabCalendar => 'Calendario';
	@override String get tabPerformance => 'Performance';
	@override String get tabImprovement => 'Miglioramento';
	@override String get pageSubtitle => 'Identifica i pattern che sostengono la crescita e intervieni sulle aree critiche.';
	@override String actionsFraction({required Object done, required Object total}) => '${done}/${total} azioni';
	@override String affectedByHardDays({required Object habit}) => '${habit} risente dei giorni difficili';
	@override String get last30DaysTrend => 'Trend Ultimi 30 Giorni';
	@override String strongestDayDetail({required Object pct, required Object done, required Object total}) => 'Ben fatto, ${pct}% di completamento (${done}/${total})';
	@override String weakestDayDetail({required Object pct, required Object done, required Object total}) => 'Solo ${pct}% di completamento (${done}/${total})';
	@override String brokenStreakItem({required Object days}) => 'Streak di ${days} giorni interrotto';
	@override String togetherProbability({required Object percentage}) => '${percentage}% insieme';
	@override String get criticalHabitsSubtitle => 'Le abitudini che stanno peggiorando di più.';
	@override String get bestHabitsSubtitle => 'Le abitudini in cui sei piu costante.';
	@override String get timeframeWeek => 'Settimana';
	@override String get timeframeMonth => 'Mese';
	@override String get timeframeYear => 'Anno';
	@override String get timeframeAll => 'Tutto';
	@override String negativeStreakDays({required Object days}) => '${days} giorni senza completamento';
	@override String dropPercent({required Object drop}) => '-${drop}%';
	@override String blackDayDetail({required Object day}) => 'Giorno nero: ${day}';
	@override String failureDetail({required Object streak, required Object frequency}) => 'Serie peggiore: ${streak}g · ~${frequency}/mese mancati';
	@override String recoveryDetail({required Object days}) => 'Tempo medio di recupero: ${days} giorni';
	@override String successRate({required Object rate}) => '${rate}% successo';
	@override String get sortRate => 'Percentuale';
	@override String get sortStreak => 'Serie';
	@override String get sortName => 'Nome';
	@override String get worstStreakLabel => 'Peggiore';
}

// Path: habitsPage
class _Translations$habitsPage$it extends Translations$habitsPage$en {
	_Translations$habitsPage$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get today => 'Oggi';
	@override String get subtitle => 'Costruisci il protocollo quotidiano e osserva la consistenza nel tempo.';
	@override String get tabProtocol => 'Protocollo';
	@override String get tabCalendar => 'Calendario';
	@override String get deleteHabitTitle => 'Elimina abitudine';
	@override String deleteHabitConfirm({required Object title}) => 'Vuoi rimuovere "${title}" dal protocollo?';
	@override String get activeProtocol => 'Protocollo attivo';
	@override String get completedToday => 'Completate oggi';
	@override String get dailyProtocol => 'Protocollo quotidiano';
	@override String get protocolSubtitle => 'Panoramica settimanale, reminder e azioni rapide';
	@override String get colHabit => 'ABITUDINE';
	@override String get colStreak => 'SERIE';
	@override String get colLast7Days => 'ULTIMI 7 GIORNI';
	@override String get colReminder => 'REMINDER';
	@override String streakDays({required Object n}) => '${n} giorni';
	@override String get prevPeriod => 'Periodo precedente';
	@override String get nextPeriod => 'Periodo successivo';
	@override List<String> get weekdayAbbrevUpper => [
		'LUN',
		'MAR',
		'MER',
		'GIO',
		'VEN',
		'SAB',
		'DOM',
	];
	@override String get lifeView => 'Vista vita';
	@override String get lifeViewSubtitle => 'Una cella rappresenta un mese del percorso fino a 85 anni.';
	@override String get monthsLived => 'Mesi vissuti';
	@override String get currentAge => 'Età attuale';
	@override String get monthsRemaining => 'Mesi rimanenti';
	@override String dayDetail({required Object day, required Object month}) => 'Dettaglio ${day} ${month}';
	@override String get dayDetailSubtitle => 'Aggiorna lo stato delle abitudini per questo giorno.';
	@override String get editHabit => 'Modifica abitudine';
	@override String get newHabit => 'Nuova abitudine';
	@override String get optionalReminder => 'Promemoria opzionale';
	@override String get reminderHint => 'es. 08:30';
	@override String get close => 'Chiudi';
	@override String statusDone({required Object category}) => '${category} · Completata';
	@override String statusSkipped({required Object category}) => '${category} · Saltata';
	@override String statusUnrecorded({required Object category}) => '${category} · Non registrata';
	@override String weekOf({required Object day, required Object month}) => 'Settimana del ${day} ${month}';
	@override String get lifeWeeks => 'Settimane del tuo percorso';
	@override String get catWellness => 'Benessere';
	@override String get catProductivity => 'Produttività';
	@override String get catEducation => 'Formazione';
	@override String get catHealth => 'Salute';
	@override String get catMindfulness => 'Mindfulness';
	@override String get editableHint => 'Puoi modificare solo oggi e ieri.';
}

// Path: goalsPage
class _Translations$goalsPage$it extends Translations$goalsPage$en {
	_Translations$goalsPage$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Macro Obiettivi';
	@override String get subtitle => 'Pianificazione a lungo termine.';
	@override String get sampleGoal => 'Obiettivo di esempio';
	@override String get periodLifetime => 'Obiettivi di vita';
	@override String get subtitleLifetime => 'Obiettivi Lifetime';
	@override String get subtitleAnnual => 'Obiettivi Annuali';
	@override String get subtitleQuarterly => 'Obiettivi Trimestrali';
	@override String get subtitleMonthly => 'Obiettivi Mensili';
	@override String get subtitleWeekly => 'Obiettivi Settimanali';
	@override String get statsTab => 'Stats';
	@override String get fullView => 'Visione completa';
	@override String get categoriesTitle => 'Categorie obiettivi';
	@override String get defaultPill => 'Predefinita';
	@override String get editCategory => 'Modifica categoria';
	@override String get archiveCategory => 'Archivia categoria';
	@override String get categoryCreateFailed => 'Creazione categoria non riuscita.';
	@override String get categoryArchiveFailed => 'Archivio categoria non riuscito.';
	@override String get categoryEditFailed => 'Modifica categoria non riuscita.';
	@override String get addCategory => 'Aggiungi categoria';
	@override String get back => 'Indietro';
	@override String get finish => 'Fine';
	@override String get next => 'Avanti';
	@override String get categoriesTooltip => 'Categorie';
	@override String get rescheduleTooltip => 'Riprogramma al periodo successivo';
	@override String get defaultCategory => 'Default';
	@override String get emptyActive => 'Nessun obiettivo attivo in questo periodo.';
	@override String get emptyAdd => 'Aggiungi il primo obiettivo per questo periodo.';
	@override String get newGoal => 'Nuovo obiettivo';
	@override String get editGoal => 'Modifica obiettivo';
	@override String get horizonLabel => 'Orizzonte';
	@override String get newCategory => 'Nuova categoria';
	@override String get nameLabel => 'Nome';
	@override String weekPeriodLabel({required Object week, required Object month, required Object year}) => 'Settimana ${week}, ${month} ${year}';
	@override String get currentQuarter => 'Trimestre corrente';
	@override String get currentMonth => 'Mese corrente';
	@override String get tutPlanningTitle => 'Tipo di pianificazione';
	@override String get tutPlanningDesc => 'Qui puoi selezionare l\'orizzonte temporale dei tuoi obiettivi.';
	@override String get tutNewGoalDesc => 'Da qui puoi inserire rapidamente un nuovo obiettivo.';
	@override String get tutCompleteTitle => 'Completa o fallisci';
	@override String get tutCompleteDesc => 'Segna l\'obiettivo come completato o fallito con un semplice clic.';
	@override String get tutCategoryDesc => 'Gestisci le categorie e associale ai tuoi obiettivi.';
	@override String get tutRescheduleTitle => 'Riprogramma';
	@override String get tutRescheduleDesc => 'Sposta l\'obiettivo al periodo successivo se non sei riuscito a completarlo.';
	@override String get tutEditDesc => 'Modifica i dettagli del tuo obiettivo.';
	@override String get tutDeleteDesc => 'Elimina un obiettivo se non è più rilevante.';
	@override String get tutStatsTitle => 'Analisi e statistiche';
	@override String get tutStatsDesc => 'Passa alla vista statistiche per analizzare il tuo rendimento nel tempo.';
}

// Path: goalsStats
class _Translations$goalsStats$it extends Translations$goalsStats$en {
	_Translations$goalsStats$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get proRequired => 'Funzione Pro richiesta';
	@override String get active => 'Attivi';
	@override String get failed => 'Falliti';
	@override String get complAbbr => 'Compl.';
	@override String get seasonality => 'Stagionalità';
	@override String get interestEvolution => 'Evoluzione Interessi';
}

// Path: ai
class _Translations$ai$it extends Translations$ai$en {
	_Translations$ai$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get coach => 'AI Coach';
	@override String get dailyHabits => 'Abitudini giornaliere';
	@override String get macroGoals => 'Macro obiettivi';
	@override late final _Translations$ai$openRouter$it openRouter = _Translations$ai$openRouter$it._(_root);
	@override late final _Translations$ai$suggestions$it suggestions = _Translations$ai$suggestions$it._(_root);
}

// Path: aiCoach
class _Translations$aiCoach$it extends Translations$aiCoach$en {
	_Translations$aiCoach$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get greeting => 'Ciao! Sono Evolve AI Coach. Sono qui per aiutarti a ottimizzare il tuo protocollo e raggiungere i tuoi obiettivi. Come posso esserti utile oggi?';
	@override String get systemPersona => 'Sei Evolve AI Coach, un assistente virtuale per la disciplina personale.';
	@override String get habitsHeader => 'ABITUDINI ATTIVE:';
	@override String get noActiveHabits => 'Nessuna abitudine attiva.';
	@override String habitLine({required Object title, required Object done, required Object streak}) => '${title} (Completata oggi: ${done}, Streak: ${streak})';
	@override String get goalsHeader => 'OBIETTIVI:';
	@override String get noActiveGoals => 'Nessun obiettivo a lungo termine attivo.';
	@override String goalLine({required Object title, required Object due}) => '${title} (Scadenza: ${due})';
	@override String get contextTitle => 'Contesto AI';
	@override String get contextBody => 'Scegli quali dati condividere con il Coach AI per ricevere consigli personalizzati.';
	@override String get shareHabitsDesc => 'Condivide le abitudini attive, le serie e lo stato di completamento di oggi.';
	@override String get shareGoalsDesc => 'Condivide i tuoi obiettivi attivi a lungo termine.';
	@override String get saveClose => 'Salva e Chiudi';
	@override String get subtitle => 'Ragiona sui pattern con un coach contestuale basato sui dati del percorso.';
	@override String get contextButton => 'Contesto';
	@override String get typing => 'AI Coach sta scrivendo...';
	@override String get inputHint => 'Chiedi consigli al tuo Coach...';
	@override String get defaultUserName => 'utente';
	@override String userNameLine({required Object userName}) => '- Nome: ${userName}';
	@override String activeGoalsCount({required Object count}) => '- Obiettivi attivi: ${count}';
	@override String completedGoalsCount({required Object count}) => '- Obiettivi completati: ${count}';
	@override String todayCompletion({required Object completed, required Object total}) => '- Abitudini oggi: ${completed} completate su ${total} totali.';
}

// Path: settingsPage
class _Translations$settingsPage$it extends Translations$settingsPage$en {
	_Translations$settingsPage$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get account => 'Account';
	@override String get notifications => 'Notifiche';
	@override String get language => 'Lingua';
	@override String get timeFormat24h => 'Formato 24h';
	@override String get subscription => 'Abbonamento';
	@override String get proName => 'Evolve Pro';
	@override String get planMonthly => 'Mensile';
	@override String get planAnnual => 'Annuale';
	@override String get restorePurchases => 'Ripristina acquisti';
	@override String get deletePrivateData => 'Elimina dati privati';
	@override String get importInProgress => 'Importazione in corso...';
	@override String get passwordsDontMatch => 'Le password non coincidono.';
	@override String get email => 'Email';
	@override String get cancel => 'Annulla';
	@override String get confirm => 'Conferma';
	@override String get save => 'Salva';
	@override String get pageTitle => 'Impostazioni';
	@override String get pageSubtitle => 'Gestisci profilo, comportamento desktop, privacy e piano Evolve.';
	@override String get profileLabel => 'Profilo';
	@override String get profileSubtitle => 'Informazioni personali e stato sincronizzazione';
	@override String get accountAndOnboarding => 'Account e onboarding';
	@override String get privateMode => 'Modalità Privata';
	@override String get sessionUnavailable => 'Sessione non disponibile';
	@override String get dataRepository => 'Repository dati';
	@override String get encryptedLocalDatabase => 'Database locale crittografato';
	@override String get supabaseWithEncryptedCache => 'Supabase con cache cifrata';
	@override String get personalInfo => 'Informazioni personali';
	@override String get personalInfoDetail => 'Nome, cognome, email e data di nascita';
	@override String get updateAvatar => 'Aggiorna avatar';
	@override String get updateAvatarDetail => 'Scegli un immagine locale per il profilo desktop.';
	@override String get reviewInitialConsent => 'Rivedi consenso iniziale';
	@override String get reviewInitialConsentDetail => 'Termini, privacy, notifiche e crash reporting';
	@override String get signOut => 'Esci dall\'account';
	@override String get signOutDetailActive => 'Chiudi la sessione su questo dispositivo';
	@override String get availableWithActiveSession => 'Disponibile con una sessione Supabase attiva';
	@override String get goToLogin => 'Vai al Login';
	@override String get goToLoginDetail => 'Sospendi la modalità privata e accedi a Supabase.';
	@override String get appearanceTitle => 'Aspetto e applicazione';
	@override String get appearanceSubtitle => 'Preferenze locali adattate al desktop';
	@override String get appearanceAndVisual => 'Aspetto e visual';
	@override String get darkMode => 'Modalita scura';
	@override String get darkModeDetail => 'Usa il tema scuro in bianco e nero.';
	@override String get calendarExperienceLanguage => 'Calendario, esperienza e lingua';
	@override String get accentColor => 'Colore accento';
	@override String get accentColorDetail => 'Palette estesa riservata a Evolve Pro.';
	@override String get defaultCalendarView => 'Vista calendario predefinita';
	@override String get timeFormat24hDetail => 'Usa orari come 20:30 invece di 8:30 PM.';
	@override String get hapticFeedback => 'Feedback aptico';
	@override String get hapticFeedbackDetail => 'Il desktop conserva la preferenza ma non genera vibrazioni.';
	@override String get resetTutorial => 'Ripristina tutorial';
	@override String get resetTutorialDetail => 'Riapre i walkthrough di dashboard e obiettivi.';
	@override String get notificationsSubtitle => 'Promemoria operativi del client desktop';
	@override String get operationalReminders => 'Promemoria operativi';
	@override String get habitReminders => 'Promemoria abitudini';
	@override String get habitRemindersDetail => 'Invia il morning briefing giornaliero.';
	@override String get morningBriefTime => 'Orario morning brief';
	@override String get eveningReview => 'Review serale';
	@override String get eveningReviewDetail => 'Ricorda di consolidare la giornata.';
	@override String get eveningReviewTime => 'Orario review serale';
	@override String get requestNotificationPermissions => 'Richiedi permessi notifiche';
	@override String get requestNotificationPermissionsDetail => 'Apre il prompt nativo sul target supportato.';
	@override String get nativeDeliveryTitle => 'Delivery nativo per sistema operativo';
	@override String get privacyTitle => 'Privacy e sicurezza';
	@override String get privacySubtitle => 'Protezione accesso, consensi e gestione dati';
	@override String get accessProtection => 'Protezione accesso';
	@override String get biometricLock => 'Blocco biometrico';
	@override String get biometricLockDetail => 'Disponibile con adapter nativo su macOS e Windows; non supportato su Linux.';
	@override String get changePassword => 'Cambia password';
	@override String get changePasswordDetail => 'Aggiornamento credenziali tramite Supabase Auth.';
	@override String get dataAndConsents => 'Dati e consensi';
	@override String get sendCrashReports => 'Invia segnalazioni crash';
	@override String get sendCrashReportsDetail => 'Consenso separato per Sentry.';
	@override String get exportData => 'Esporta dati';
	@override String get exportDataDetail => 'Condivide un export JSON completo dei dati disponibili.';
	@override String get importData => 'Importa dati';
	@override String get importDataDetail => 'Ripristina un backup (formato .zip) di Evolve.';
	@override String get systemPermissionsManagement => 'Gestione permessi di sistema';
	@override String get systemPermissionsManagementDetail => 'Notifiche, calendario e sicurezza.';
	@override String get deletePrivateDataDetail => 'Cancella definitivamente il database locale crittografato.';
	@override String get deleteAccountAndData => 'Elimina account e dati';
	@override String get deleteAccountAndDataDetail => 'Operazione irreversibile protetta da conferma.';
	@override String get exportPrivateShareText => 'I miei dati privati esportati da Evolve';
	@override String get exportShareText => 'I miei dati esportati da Evolve';
	@override String get exportDoneTitle => 'Export completato';
	@override String get exportDoneClipboard => 'Il JSON e negli appunti: Linux non supporta la condivisione file.';
	@override String get exportDoneShare => 'Il JSON e stato inviato al selettore di condivisione.';
	@override String get avatarGateTitle => 'Avatar';
	@override String get avatarPickFailed => 'Selezione immagine non riuscita.';
	@override String get confirmSignOutTitle => 'Conferma uscita';
	@override String get confirmSignOutMessage => 'Sei sicuro di voler uscire? Dovrai reinserire le credenziali per accedere nuovamente.';
	@override String get gateProfile => 'Profilo';
	@override String get gateLogout => 'Logout';
	@override String get gateChangePassword => 'Cambio password';
	@override String get gateRequiresActiveSession => 'Richiede una sessione Supabase attiva.';
	@override String get biometricActivationCancelled => 'Attivazione annullata.';
	@override String get notificationPermissionsTitle => 'Permessi notifiche';
	@override String get notificationPermissionsGranted => 'Permessi disponibili per questo sistema.';
	@override String get notificationPermissionsDenied => 'Permesso non concesso. Puoi modificarlo dalle impostazioni di sistema.';
	@override String get systemPermissionsTitle => 'Permessi di sistema';
	@override String get systemPermissionsOpenFailed => 'Impossibile aprire le impostazioni.';
	@override String get tutorialResetTitle => 'Tutorial ripristinati';
	@override String get tutorialResetMessage => 'Le guide verranno mostrate nuovamente nelle relative sezioni.';
	@override String get accountDataManagementTitle => 'Gestione account e dati';
	@override String get accountDataManagementContent => 'Scegli se eliminare i dati mantenendo attivo l account oppure cancellare definitivamente l account.';
	@override String get resetDataAction => 'Resetta i dati';
	@override String get deleteAccountAction => 'Elimina account';
	@override String get confirmResetDataTitle => 'Conferma reset dati';
	@override String get confirmResetDataMessage => 'Verranno eliminate abitudini, obiettivi e preferenze. L account restera attivo. Questa azione non puo essere annullata.';
	@override String get confirmDeleteAccountTitle => 'Conferma eliminazione account';
	@override String get confirmDeleteAccountMessage => 'L account e tutti i dati associati verranno eliminati definitivamente. Questa azione e irreversibile.';
	@override String get resetDataTitle => 'Reset dati';
	@override String get resetDataSuccess => 'Dati eliminati con successo.';
	@override String get operationFailed => 'Operazione non riuscita.';
	@override String get deleteAccountGateTitle => 'Elimina account';
	@override String get accountDeleted => 'Account eliminato.';
	@override String get importDataGateTitle => 'Importa dati';
	@override String get importPrivateOnly => 'La funzione di importazione è attualmente disponibile solo in Modalità Privata (Locale).';
	@override String get importSummaryTitle => 'Riepilogo Importazione';
	@override String importHabitsCount({required Object count}) => '${count} Abitudini';
	@override String importLogsCount({required Object count}) => '${count} Check-in (Log)';
	@override String importMacroGoalsCount({required Object count}) => '${count} Obiettivi Macro';
	@override String importCategoriesCount({required Object count}) => '${count} Categorie';
	@override String importMoodsCount({required Object count}) => '${count} Registrazioni Umore';
	@override String get importReplaceTitle => 'Sostituisci i dati attuali';
	@override String get importReplaceSubtitle => 'Elimina tutti i dati locali esistenti prima di importare. (Consigliato)';
	@override String get importMergeTitle => 'Unisci ai dati attuali';
	@override String get importMergeSubtitle => 'Aggiunge i dati importati senza eliminare nulla. Potrebbe causare duplicati.';
	@override String get importConfirmButton => 'Conferma Importazione';
	@override String get importSuccess => 'Importazione completata con successo!';
	@override String importError({required Object error}) => 'Errore durante importazione: ${error}';
	@override String get proTitle => 'Evolve Pro';
	@override String get proSubtitle => 'Piano, ripristino acquisti e gestione abbonamento';
	@override String get revenueCatMacos => 'RevenueCat macOS';
	@override String get commercialChannelRequired => 'Canale commerciale richiesto';
	@override String get revenueCatOffersRead => 'Offerte e stato entitlement vengono letti da RevenueCat.';
	@override String get revenueCatConfigureKey => 'Configura la public key RevenueCat del client desktop.';
	@override String get revenueCatNotSupported => 'RevenueCat Flutter non espone acquisti in-app su Windows e Linux.';
	@override String get bestValue => 'Miglior valore';
	@override String get planManagement => 'Gestione piano';
	@override String get activateEvolvePro => 'Attiva Evolve Pro';
	@override String get activateEvolveProActive => 'Entitlement Evolve Pro attivo.';
	@override String get activateEvolveProStart => 'Avvia il checkout StoreKit nativo su macOS.';
	@override String get restorePurchasesDetail => 'Recupera lo stato entitlement dal provider.';
	@override String get manageSubscription => 'Gestisci abbonamento';
	@override String get manageSubscriptionDetail => 'Apre la gestione abbonamenti dell account Apple.';
	@override String get notAuthenticated => 'Non autenticato';
	@override String get verified => 'Verificato';
	@override String get privateModeDataProtected => 'I tuoi dati sono protetti e salvati unicamente su questo dispositivo.';
	@override String get profileFallback => 'Profilo';
	@override String get fullName => 'Nome completo';
	@override String get dateOfBirth => 'Data di nascita';
	@override String get dateOfBirthHint => 'AAAA-MM-GG';
	@override String get currentPassword => 'Password attuale';
	@override String get newPassword => 'Nuova password';
	@override String get confirmNewPassword => 'Conferma nuova password';
	@override String get updatePassword => 'Aggiorna password';
	@override String get enterCurrentPassword => 'Inserisci la password attuale.';
	@override String get newPasswordMinLength => 'La nuova password deve avere almeno 8 caratteri.';
	@override String get passwordUpdateFailed => 'Aggiornamento non riuscito. Verifica la password attuale.';
	@override String get sectionApplication => 'Applicazione';
	@override String get sectionPrivacy => 'Privacy';
	@override String get customColor => 'Colore personalizzato';
	@override String get applyAction => 'Applica';
	@override String useAccent({required Object hex}) => 'Usa accento ${hex}';
	@override String get proUpsellTitle => 'Passa a Evolve Pro';
	@override String get proUpsellSubtitle => 'Sblocca tutte le funzionalità e accelera la tua crescita.';
	@override String get proWelcomeTitle => 'Benvenuto in Evolve Pro!';
	@override String get proActiveMessage => 'La tua iscrizione è attiva. Ora hai accesso completo ed illimitato all\'AI Coach personalizzato, alle statistiche avanzate dei trend e a tutti gli strumenti di crescita personale di Evolve.';
	@override String get proStartJourney => 'Inizia il tuo Percorso';
	@override String get systemSection => 'Sistema';
	@override String get appLogsTitle => 'Log dell\'app';
	@override String get appLogsDetail => 'Visualizza i log diagnostici di questa sessione';
}

// Path: consent
class _Translations$consent$it extends Translations$consent$en {
	_Translations$consent$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get onboardingTitle => 'La tua Privacy è Importante';
	@override String get continueButton => 'Continua';
}

// Path: notifications
class _Translations$notifications$it extends Translations$notifications$en {
	_Translations$notifications$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get actionDone => 'Fatto';
	@override String get actionSkip => 'Salta';
	@override String get actionSnooze => 'Posticipa';
	@override String get morningBrief => 'Morning Brief';
	@override String get eveningReview => 'Review Serale';
	@override String get morningBriefBody => 'È il momento di plasmare la tua giornata. Controlla i tuoi obiettivi.';
	@override String get eveningReviewBody => 'Com’è andata oggi? Traccia i tuoi progressi e aggiorna il Diario di Bordo.';
}

// Path: privacy
class _Translations$privacy$it extends Translations$privacy$en {
	_Translations$privacy$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get biometricAuthReason => 'Autenticati per abilitare la protezione dell\'app.';
	@override String get biometricUnlockReason => 'Sblocca l\'app per continuare.';
}

// Path: consentPage
class _Translations$consentPage$it extends Translations$consentPage$en {
	_Translations$consentPage$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get subtitle => 'Prima di usare Evolve Desktop conferma termini, privacy policy e trattamento dei dati necessari alla sincronizzazione.';
	@override String get acceptTerms => 'Accetto termini e privacy policy';
	@override String get termsSubtitle => 'Confermo di aver letto i documenti e di avere almeno 14 anni.';
	@override String get crashDiagnostics => 'Diagnostica crash';
	@override String get crashSubtitle => 'Consenti l\'invio di segnalazioni tecniche anonimizzate.';
	@override String get openPrivacy => 'Apri la privacy policy';
	@override String get openTerms => 'Termini di servizio';
	@override String get notificationsTitle => 'Abilita le notifiche';
	@override String get notificationsSubtitle => 'Ricevi promemoria delle abitudini e riepiloghi giornalieri.';
	@override String get enableNotifications => 'Abilita';
	@override String get notificationsEnabled => 'Attive';
}

// Path: notif
class _Translations$notif$it extends Translations$notif$en {
	_Translations$notif$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get macScheduling => 'Scheduling giornaliero attivo su macOS.';
	@override String get linuxImmediate => 'Linux mostra notifiche immediate, ma non supporta lo scheduling.';
	@override String get openEvolve => 'Apri Evolve';
	@override String get windowsScheduling => 'Windows pianifica la prossima occorrenza a ogni avvio.';
	@override String get morningBody => 'Rivedi le abitudini di oggi e scegli da dove iniziare.';
	@override String get habitReminderBody => 'È il momento di completare la tua abitudine.';
	@override String get eveningBody => 'Consolida la giornata e aggiorna i progressi.';
}

// Path: biometricGate
class _Translations$biometricGate$it extends Translations$biometricGate$en {
	_Translations$biometricGate$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get appLocked => 'App bloccata';
	@override String get unlockPrompt => 'Sblocca con l\'autenticazione locale per continuare.';
	@override String get verifying => 'Verifica...';
	@override String get unlock => 'Sblocca';
	@override String get notSupportedLinux => 'Il blocco biometrico non è supportato su Linux.';
	@override String get noLocalAuth => 'Nessun metodo di autenticazione locale disponibile.';
	@override String get authFailed => 'Autenticazione non riuscita.';
	@override String get authUnavailable => 'Autenticazione locale non disponibile.';
}

// Path: sync
class _Translations$sync$it extends Translations$sync$en {
	_Translations$sync$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get syncFailed => 'Sincronizzazione non riuscita. Dati locali mantenuti.';
	@override String get editSavedLocally => 'Modifica salvata localmente. Sincronizzazione da riprovare.';
}

// Path: subscriptionCtrl
class _Translations$subscriptionCtrl$it extends Translations$subscriptionCtrl$en {
	_Translations$subscriptionCtrl$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get purchaseComplete => 'Acquisto completato: sincronizzazione entitlement in corso.';
	@override String get purchaseIncomplete => 'Acquisto non completato.';
	@override String get cantOpenApple => 'Impossibile aprire la gestione abbonamenti Apple.';
	@override String get macOnly => 'Gli acquisti in-app sono disponibili nel client macOS.';
	@override String get loadOffersFailed => 'Impossibile caricare le offerte RevenueCat.';
	@override String get proActivated => 'Evolve Pro attivato.';
	@override String get purchasesRestored => 'Acquisti ripristinati.';
	@override String get noActiveSub => 'Nessun abbonamento Pro attivo trovato.';
	@override String get restoreFailed => 'Ripristino acquisti non riuscito.';
	@override String get configKey => 'Configura la public key RevenueCat del client desktop.';
	@override String get loginFirst => 'Accedi prima di gestire Evolve Pro.';
}

// Path: authCtrl
class _Translations$authCtrl$it extends Translations$authCtrl$en {
	_Translations$authCtrl$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get appleNoToken => 'Apple non ha restituito un identity token.';
	@override String get appleAuthFailed => 'Autenticazione Apple non riuscita.';
	@override String get cantOpenBrowser => 'Impossibile aprire il browser di sistema.';
	@override String accessNotCompleted({required Object provider}) => 'Accesso ${provider} non completato.';
	@override String providerAuthFailed({required Object provider}) => 'Autenticazione ${provider} non riuscita.';
	@override String get operationFailed => 'Operazione non riuscita. Riprova tra poco.';
}

// Path: proModal
class _Translations$proModal$it extends Translations$proModal$en {
	_Translations$proModal$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sblocca Evolve Pro';
	@override String get subtitle => 'Porta il tuo sistema di abitudini al livello successivo';
	@override String get featuresHeader => 'COSA INCLUDE IL PIANO PRO';
	@override String get aiCoachTitle => 'AI Coach Personalizzato';
	@override String get aiCoachDesc => 'Analisi avanzata dei trend e suggerimenti intelligenti generati dall\'AI.';
	@override String get statsTitle => 'Statistiche Specifiche Per Abitudine';
	@override String get statsDesc => 'Informazioni chiave per aumentare la tua produttività.';
	@override String get metricsTitle => 'Metriche Avanzate Obiettivi';
	@override String get metricsDesc => 'Visualizza grafici dettagliati e statistiche di performance profonde per ogni anno.';
	@override String get unlimitedTitle => 'Abitudini Illimitate';
	@override String get unlimitedDesc => 'Crea e traccia tutti gli habits che desideri senza alcun limite.';
	@override String get maybeLater => 'Forse più tardi';
	@override String get viewPlans => 'Vedi i piani Pro';
}

// Path: tutorial
class _Translations$tutorial$it extends Translations$tutorial$en {
	_Translations$tutorial$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get back => 'Indietro';
	@override String get next => 'Avanti';
	@override String get finish => 'Fine';
	@override String get dailyCheckIn => 'Daily Check-in';
	@override String get dailyCheckinDesc => 'Qui puoi registrare il tuo stato d\'animo quotidiano per tracciare il tuo benessere nel tempo e soprattutto correlarlo con il completamento dei tuoi obiettivi.';
	@override String get manageHabits => 'Gestione Abitudini';
	@override String get addEditOrDeleteDailyHabits => 'Aggiungi, modifica o elimina le tue abitudini quotidiane che vuoi rispettare in modo semplice e veloce.';
	@override String get movingToGoals => 'Passiamo agli Obiettivi';
	@override String get goalsPageDesc => 'La pagina dove puoi gestire i tuoi obiettivi a lungo termine e le relative performance.';
	@override String get filterByHabit => 'Filtra per Abitudine';
	@override String get filterHabitDesc => 'Da qui puoi selezionare una specifica abitudine per vederne i dettagli, oppure \'Tutti gli Habits\' per una panoramica globale.';
	@override String get statisticsSections => 'Sezioni Statistiche';
	@override String get statsSectionsDesc => 'Naviga tra le varie schede per vedere i Trend, gli Alert sulle performance, l\'andamento delle Abitudini e il tuo Mood.';
}

// Path: appLogs
class _Translations$appLogs$it extends Translations$appLogs$en {
	_Translations$appLogs$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Log App';
	@override String get copiedToClipboard => 'Log copiati negli appunti';
	@override String get clearLogsTitle => 'Cancella Log';
	@override String get clearLogsConfirm => 'Sei sicuro di voler cancellare tutte le voci di log? Questa azione non può essere annullata.';
	@override String get clearLogsAction => 'Cancella Tutto';
	@override String get copyAll => 'Copia Tutti i Log';
	@override String get searchPlaceholder => 'Cerca nei log...';
	@override String get filterAll => 'Tutti';
	@override String get filterErrors => 'Errori';
	@override String get filterWarnings => 'Avvisi';
	@override String get filterInfo => 'Info';
	@override String get emptyTitle => 'Nessun Log';
	@override String get emptySubtitle => 'I log appariranno qui durante l\'uso dell\'app';
	@override String get stackTraceAvailable => 'Tocca per visualizzare lo stack trace';
	@override String get detailMessage => 'MESSAGGIO';
	@override String get detailError => 'ERRORE';
	@override String get detailExtras => 'CONTESTO AGGIUNTIVO';
	@override String get detailStackTrace => 'STACK TRACE';
	@override String get shareLogs => 'Condividi file dei log';
	@override String get exportDone => 'Log esportati';
}

// Path: common.actions
class _Translations$common$actions$it extends Translations$common$actions$en {
	_Translations$common$actions$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get cancel => 'Annulla';
	@override String get save => 'Salva';
	@override String get delete => 'Elimina';
	@override String get edit => 'Modifica';
}

// Path: common.calendarView
class _Translations$common$calendarView$it extends Translations$common$calendarView$en {
	_Translations$common$calendarView$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get year => 'Anno';
	@override String get month => 'Mese';
	@override String get week => 'Settimana';
	@override String get life => 'Vita';
}

// Path: common.status
class _Translations$common$status$it extends Translations$common$status$en {
	_Translations$common$status$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get error => 'Errore';
}

// Path: macroGoals.types
class _Translations$macroGoals$types$it extends Translations$macroGoals$types$en {
	_Translations$macroGoals$types$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get annual => 'Annuale';
	@override String get quarterly => 'Trimestrale';
	@override String get monthly => 'Mensile';
	@override String get weekly => 'Settimanale';
	@override String get lifetime => 'Lifetime';
}

// Path: ai.openRouter
class _Translations$ai$openRouter$it extends Translations$ai$openRouter$en {
	_Translations$ai$openRouter$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get apiKeyMissingFull => '⚠️ Errore: chiave API di OpenRouter non configurata.\n\nInserisci la chiave API nel file `lib/core/openrouter_config.dart`.';
	@override String get apiKeyMissingShort => '⚠️ Errore: chiave API di OpenRouter non configurata.';
	@override String get defaultSystemPrompt => 'Sei il "Coach di Disciplina", un assistente virtuale focalizzato sull’aiutare la persona a mantenere la disciplina, raggiungere i propri obiettivi e costruire abitudini sane. Sii motivante ma concreto, diretto e pratico. Usa un tono professionale ma amichevole.';
	@override String communicationError({required Object code}) => '❌ Errore nella comunicazione con l’AI. (Codice: ${code})';
	@override String get connectionError => '❌ Errore di connessione. Assicurati di essere online e riprova.';
	@override String get connectionErrorShort => '❌ Errore di connessione.';
	@override String get connectionCheckTimeout => '❌ Errore: la verifica della connessione ha impiegato troppo tempo.';
	@override String get contextTooLong => '⚠️ Limite di memoria superato o richiesta non valida. La conversazione potrebbe essere troppo lunga o complessa. Usa l’icona del cestino in alto per svuotare la chat e ricominciare.';
	@override String get noInternet => '❌ Errore: nessuna connessione a internet. Verifica la rete.';
	@override String get serverTimeout => '❌ Errore: il server sta impiegando troppo tempo a rispondere. Riprova.';
	@override String apiError({required Object code}) => '❌ Errore API: ${code} (verifica Sentry per i dettagli)';
}

// Path: ai.suggestions
class _Translations$ai$suggestions$it extends Translations$ai$suggestions$en {
	_Translations$ai$suggestions$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get morningBoost => '🔥 Dammi la carica per iniziare!';
	@override String get avoidDistractions => '🧠 Come evitare le distrazioni?';
	@override String get lowEnergy => '⚡ Ho un calo di energia, cosa faccio?';
	@override String get stayFocused => '💪 Un consiglio per rimanere focalizzato';
	@override String get prepareTomorrow => '🛌 Come prepararsi per un domani produttivo?';
	@override String get disciplineReflection => '📝 Riflessione sulla disciplina di oggi';
	@override String get analyzeActiveGoals => '🎯 Analizza i miei obiettivi attivi';
	@override String get planMacroGoals => '🗺️ Come pianificare i miei macro obiettivi?';
	@override String get goalObstacles => '🛑 Quali ostacoli bloccano i miei obiettivi?';
	@override String get reachMilestones => '📈 Un consiglio per raggiungere i miei traguardi';
	@override String get consistencyStatus => '📈 Come sta andando la mia costanza?';
	@override String get weeklyStats => '📊 Le mie statistiche settimanali';
	@override String get planDay => '🌅 Pianifica la mia giornata';
	@override String get raiseBar => '🚀 Come posso alzare l’asticella?';
	@override String get recoverProcrastination => '🤕 Come recuperare se ho procrastinato?';
	@override String get connectHabitsGoals => '🔗 Come legare le abitudini agli obiettivi?';
	@override String get reviewGoalsHabits => '📊 Review di obiettivi e abitudini';
	@override String get disciplineAdvice => '🔥 Consiglio sulla disciplina';
	@override String get createNewHabit => '💡 Come creare una nuova abitudine?';
}

/// The flat map containing all translations for locale <it>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsIt {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'auth.continuePrivately' => 'Continua in modalità privata su questo Mac',
			'auth.signIn' => 'Accedi',
			'auth.register' => 'Registrati',
			'auth.or' => 'OPPURE',
			'auth.password' => 'Password',
			'auth.forgotPassword' => 'Password dimenticata?',
			'auth.haveAccount' => 'Hai già un account?',
			'auth.noAccount' => 'Non hai un account?',
			'auth.continueWithApple' => 'Continua con Apple',
			'auth.continueWithGoogle' => 'Continua con Google',
			'auth.readPrivacyPolicy' => 'Leggi Privacy Policy',
			'auth.nameLabel' => 'Nome',
			'auth.invalidEmail' => 'Inserisci un\'email valida',
			'auth.confirmEmail' => 'Controlla la tua email per confermare la registrazione.',
			'auth.resetSent' => 'Email inviata! Controlla la tua casella di posta.',
			'auth.signInTitle' => 'Accedi a Evolve',
			'auth.signUpTitle' => 'Crea il tuo account',
			'auth.resetTitle' => 'Recupera password',
			'auth.emailLabel' => 'Email',
			'auth.passwordMin8' => 'Usa almeno 8 caratteri.',
			'auth.sendResetLink' => 'Invia link di recupero',
			'privateAi.consentTitle' => 'Consenti l\'invio all\'AI',
			'privateAi.consentBody' => 'In modalità privata i tuoi dati restano sul dispositivo. Per usare l\'AI Coach, le abitudini e gli obiettivi che scegli di condividere vengono inviati a un provider AI esterno (OpenRouter). Vuoi procedere?',
			'privateAi.cancel' => 'Annulla',
			'privateAi.accept' => 'Accetto',
			'privateData.deleteTitle' => 'Elimina dati privati',
			'privateData.deleteMessage' => 'Sei sicuro di voler eliminare tutto il database locale crittografato? Questa operazione è irreversibile e i dati non potranno essere recuperati.',
			'privateData.deleteSuccess' => 'Dati privati eliminati.',
			'privateData.deleteFailed' => 'Operazione non riuscita.',
			'privateData.exportDoneTitle' => 'Export completato',
			'privateData.exportDoneClipboard' => 'Il JSON è negli appunti: Linux non supporta la condivisione file.',
			'privateData.exportDoneShare' => 'Il JSON è stato inviato al selettore di condivisione.',
			'icloudSync.title' => 'Sincronizzazione iCloud',
			'icloudSync.enableTitle' => 'Abilita sincronizzazione iCloud',
			'icloudSync.syncNow' => 'Sincronizza ora',
			'icloudSync.disclosureTitle' => 'Crittografia end-to-end',
			'icloudSync.disclosureBody' => 'I tuoi dati privati si sincronizzano solo tramite il tuo account iCloud, con crittografia end-to-end — mai attraverso i nostri server. La chiave di crittografia risiede nel tuo Portachiavi iCloud; se disattivi il Portachiavi iCloud, i dati sincronizzati non potranno essere recuperati.',
			'icloudSync.disclosureAccept' => 'Abilita',
			'icloudSync.statusIdle' => 'Aggiornato',
			'icloudSync.statusSyncing' => 'Sincronizzazione…',
			'icloudSync.statusOff' => 'Sincronizzazione disattivata',
			'icloudSync.statusNoAccount' => 'Accedi a iCloud per sincronizzare',
			'icloudSync.statusUnavailable' => 'iCloud non è disponibile al momento',
			'icloudSync.statusWaitingKeychain' => 'In attesa del Portachiavi iCloud — assicurati che l\'app sul tuo iPhone sia aggiornata',
			'icloudSync.lastSyncedNever' => 'Mai sincronizzato',
			'icloudSync.lastSyncedAt' => ({required Object time}) => 'Ultima sincronizzazione ${time}',
			'icloudSync.deleteSyncNote' => 'La sincronizzazione iCloud è attiva: verrà eliminata anche la copia sincronizzata nel tuo iCloud e la sincronizzazione verrà disattivata. Gli altri dispositivi conservano la loro copia locale — esegui questa operazione su ciascun dispositivo per eliminare tutto ovunque.',
			'namePrompt.title' => 'Come ti chiami?',
			'namePrompt.subtitle' => 'Inserisci il tuo nome per personalizzare la dashboard.',
			'namePrompt.hint' => 'Es. Simo',
			'namePrompt.save' => 'Salva e continua',
			'nav.overview' => 'Panoramica',
			'nav.habits' => 'Abitudini',
			'nav.insights' => 'Statistiche',
			'nav.goals' => 'Obiettivi',
			'nav.coach' => 'AI Coach',
			'nav.settings' => 'Impostazioni',
			'shell.syncPending' => 'Sync in attesa',
			'shell.syncing' => 'Sincronizzazione',
			'shell.synced' => 'Sincronizzato',
			'shell.syncTooltip' => 'Sincronizza',
			'shell.searchHint' => 'Cerca o naviga',
			'shell.searchSectionHint' => 'Cerca una sezione...',
			'common.actions.cancel' => 'Annulla',
			'common.actions.save' => 'Salva',
			'common.actions.delete' => 'Elimina',
			'common.actions.edit' => 'Modifica',
			'common.months.0' => 'Gennaio',
			'common.months.1' => 'Febbraio',
			'common.months.2' => 'Marzo',
			'common.months.3' => 'Aprile',
			'common.months.4' => 'Maggio',
			'common.months.5' => 'Giugno',
			'common.months.6' => 'Luglio',
			'common.months.7' => 'Agosto',
			'common.months.8' => 'Settembre',
			'common.months.9' => 'Ottobre',
			'common.months.10' => 'Novembre',
			'common.months.11' => 'Dicembre',
			'common.weekdayInitials.0' => 'L',
			'common.weekdayInitials.1' => 'M',
			'common.weekdayInitials.2' => 'M',
			'common.weekdayInitials.3' => 'G',
			'common.weekdayInitials.4' => 'V',
			'common.weekdayInitials.5' => 'S',
			'common.weekdayInitials.6' => 'D',
			'common.calendarView.year' => 'Anno',
			'common.calendarView.month' => 'Mese',
			'common.calendarView.week' => 'Settimana',
			'common.calendarView.life' => 'Vita',
			'common.weekdaysLong.0' => 'Lunedì',
			'common.weekdaysLong.1' => 'Martedì',
			'common.weekdaysLong.2' => 'Mercoledì',
			'common.weekdaysLong.3' => 'Giovedì',
			'common.weekdaysLong.4' => 'Venerdì',
			'common.weekdaysLong.5' => 'Sabato',
			'common.weekdaysLong.6' => 'Domenica',
			'common.none' => 'Nessuno',
			'common.habits' => 'Abitudini',
			'common.status.error' => 'Errore',
			'common.total' => 'Totale',
			'common.completed' => 'Completati',
			'form.title' => 'Titolo',
			'form.category' => 'Categoria',
			'form.color' => 'Colore',
			'form.add' => 'Aggiungi',
			'createGoal.title' => 'Nuovo Obiettivo',
			'createGoal.subtitle' => 'Definisci il tuo prossimo traguardo.',
			'createGoal.titleHint' => 'es. Lanciare il nuovo prodotto',
			'createGoal.categoryHint' => 'es. Lavoro',
			'createGoal.timeline' => 'Timeline',
			'createGoal.thisWeek' => 'Questa Settimana',
			'createGoal.thisMonth' => 'Questo Mese',
			'createGoal.thisQuarter' => 'Questo Trimestre',
			'createGoal.thisYear' => 'Quest\'Anno',
			'createGoal.longTerm' => 'Lungo termine (Lifetime)',
			'createGoal.dueLifetime' => 'Tutta la vita',
			'createGoal.dueByYear' => ({required Object year}) => 'Entro il ${year}',
			'createGoal.defaultCategory' => 'Obiettivo',
			'createHabit.title' => 'Nuova Abitudine',
			'createHabit.subtitle' => 'Definisci la tua nuova abitudine.',
			'createHabit.titleHint' => 'es. Meditazione',
			'createHabit.categoryHint' => 'es. Benessere',
			'createHabit.weeklyFrequency' => 'Frequenza settimanale',
			'createHabit.defaultCategory' => 'Generale',
			'macroGoals.types.annual' => 'Annuale',
			'macroGoals.types.quarterly' => 'Trimestrale',
			'macroGoals.types.monthly' => 'Mensile',
			'macroGoals.types.weekly' => 'Settimanale',
			'macroGoals.types.lifetime' => 'Lifetime',
			'macroGoals.quarterNumber' => ({required Object quarter}) => 'Trimestre ${quarter}',
			'macroGoals.addLifetimeGoal' => 'Aggiungi obiettivo lifetime...',
			'macroGoals.addAnnualGoal' => 'Aggiungi obiettivo annuale...',
			'macroGoals.addQuarterlyGoal' => 'Aggiungi obiettivo trimestrale...',
			'macroGoals.addMonthlyGoal' => 'Aggiungi obiettivo mensile...',
			'macroGoals.addWeeklyGoal' => 'Aggiungi obiettivo settimanale...',
			'macroGoals.completed' => 'COMPLETATI',
			'macroGoals.failed' => 'FALLITI',
			'macroGoals.create' => 'Crea',
			'macroGoals.strength' => 'Punto di Forza',
			'macroGoals.bestMonth' => 'Mese Migliore',
			'macroGoals.successRate2' => 'di successo',
			'macroGoals.effectiveType' => 'Tipologia Efficace',
			'macroGoals.historicalTotal' => 'Totale Storico',
			'macroGoals.from_' => 'dal',
			'macroGoals.globalSuccess' => 'Successo Globale',
			'macroGoals.completedGoals' => 'obiettivi completati',
			'macroGoals.bestYear' => 'Anno Migliore',
			'macroGoals.mostProductiveYear' => 'Anno Più Produttivo',
			'macroGoals.totalGoals' => 'obiettivi totali',
			'macroGoals.allYears' => 'Tutti gli anni',
			'macroGoals.selectYearHeader' => 'SELEZIONA ANNO',
			'macroGoals.completions' => 'Completamenti',
			'macroGoals.success2' => 'Successo',
			'macroGoals.archiveCategory2' => 'Archiviare categoria?',
			'macroGoals.categoryUnavailableLinked' => ({required Object label, required Object count}) => 'La categoria "${label}" non sarà più disponibile per nuovi obiettivi, ma resterà collegata a ${count} obiettivi storici e alle statistiche.',
			'macroGoals.categoryUnavailableArchived' => ({required Object label}) => 'La categoria "${label}" non sarà più disponibile per nuovi obiettivi, ma resterà nello storico.',
			'macroGoals.archive' => 'Archivia',
			'macroGoals.createNewCategory' => 'Crea nuova categoria',
			'statistics.completed2' => 'Completato',
			'statistics.notCompleted' => 'Non completato',
			'statistics.ofCompletion' => 'di completamento',
			'statistics.growth' => 'Crescita',
			'statistics.decline' => 'Calo',
			'statistics.strongestDay' => 'Giorno più forte',
			'statistics.weakestDay' => 'Giorno più debole',
			'statistics.worstNegativeStreak' => 'Serie Negativa Peggiore',
			'statistics.missedConsecutiveDays' => 'giorni consecutivi mancati',
			'statistics.brokenStreaks' => 'Streak Interrotti',
			'statistics.noBrokenStreaks' => 'Nessun streak interrotto registrato',
			'statistics.startedOn' => 'Iniziata il',
			'statistics.moodCorrelation' => 'Correlazione Mood',
			'statistics.avgMood' => 'Mood Medio (✓)',
			'statistics.avgEnergy' => 'Energia Media (✓)',
			'statistics.onCompletedDays' => 'nei giorni completati',
			'statistics.resilient' => 'Resiliente',
			'statistics.completedVsMissed' => 'Completato vs Mancato',
			'statistics.mood2' => 'Umore',
			'statistics.energy' => 'Energia',
			'statistics.performancePerLevel' => 'Performance per Livello',
			'statistics.withHighMood' => 'Con Mood Alto',
			'statistics.withLowMood' => 'Con Mood Basso',
			'statistics.moodEnergyAnalysis' => 'L\'analisi mostra come la tua costanza è influenzata dal tuo stato d\'animo ed energia.',
			'statistics.missed2' => 'Mancato',
			'statistics.positive' => 'positiva',
			'statistics.neutral' => 'neutra',
			'statistics.high' => 'alta',
			'statistics.low' => 'bassa',
			'statistics.skipped' => 'Saltato',
			'statistics.criticalHabits' => 'Abitudini Critiche',
			'statistics.bestHabitsTitle' => 'Abitudini Migliori',
			'statistics.worseningHabitsDescription' => 'Le abitudini che stanno peggiorando di più.',
			'statistics.everythingIsGreat' => 'Tutto alla grande!',
			'statistics.allHabitsStableDescription' => 'Tutte le tue abitudini stanno mantenendo o migliorando il loro trend. Continua così.',
			'statistics.habitCompletionPeriodDescription' => ({required Object rate}) => 'Hai completato questa abitudine il ${rate}% delle volte nel periodo selezionato.',
			'statistics.habitLostConsistencyDescription' => ({required Object drop}) => 'Questa abitudine ha perso il ${drop}% di costanza nell’ultima settimana rispetto alla precedente.',
			'statistics.negativeStreak' => 'Streak Negativa',
			'statistics.currentStreak2' => 'Serie Attuale',
			'statistics.improvementAreas' => 'Aree di Miglioramento',
			'statistics.habitsRequiringMoreAttention' => 'Abitudini che richiedono più attenzione.',
			'statistics.failureAnalysis' => 'Analisi Fallimenti',
			'statistics.missedDaysPattern' => 'Frequenza e pattern dei tuoi giorni mancati.',
			'statistics.recoveryPatterns' => 'Pattern di Recupero',
			'statistics.recoverySpeed' => 'Quanto velocemente torni in carreggiata dopo un errore.',
			'statistics.avgRecoveryTime' => 'Tempo Medio Recupero',
			'statistics.worstStreak' => 'WORST STREAK',
			'statistics.frequency' => 'FREQUENZA',
			'statistics.daysShortUnit' => 'gg',
			'statistics.perMonthUnit' => 'mese',
			'statistics.succ' => 'succ.',
			'statistics.blackDay' => 'GIORNO NERO',
			'statistics.correlationsWith' => 'Correlazioni con',
			'statistics.howThisHabitRelatesToOthers' => 'Come questa abitudine si relaziona con le altre',
			'statistics.positiveCorrelations' => 'Correlazioni Positive',
			'statistics.negativeCorrelations' => 'Correlazioni Negative',
			'statistics.noSignificantPositiveCorrelation' => 'Nessuna correlazione positiva significativa',
			'statistics.noSignificantNegativeCorrelation' => 'Nessuna correlazione negativa significativa',
			'statistics.habitTogetherPercent' => ({required Object percentage}) => '${percentage}% insieme',
			'statistics.habitPositiveCorrelationDescription' => ({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'Quando completi "${currentGoal}", hai una probabilità del ${percentage}% di completare anche "${otherGoal}".',
			'statistics.habitNegativeCorrelationDescription' => ({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'Quando completi "${currentGoal}", hai solo una probabilità del ${percentage}% di completare anche "${otherGoal}".',
			'statistics.weeklyTrend' => 'Trend Settimanale',
			'statistics.monthlyTrend' => 'Trend Mensile',
			'statistics.yearlyTrend' => 'Trend Annuale',
			'statistics.performanceEvolution' => 'Evoluzione Performance',
			'statistics.globalTrend' => 'Trend Globale',
			'statistics.total' => 'Totale',
			'statistics.all' => 'Tutto',
			'statistics.noDataForAlerts' => 'Nessun dato sufficiente per generare alert.',
			'statistics.missed' => 'Mancati',
			'goalState.active' => 'In corso',
			'dueLabel.lifetime' => 'Obiettivo di vita',
			'dueLabel.annual' => 'Obiettivo annuale',
			'dueLabel.quarter' => 'Trimestre',
			'dashboard.mood' => 'Umore',
			'dashboard.energy' => 'Energia',
			'dashboard.goodMorning' => 'Buongiorno',
			'dashboard.goodAfternoon' => 'Buon pomeriggio',
			'dashboard.goodEvening' => 'Buonasera',
			'dashboard.manager' => 'Gestione',
			'dashboard.aiChat' => 'AI Chat',
			'dashboard.consecutiveDays' => 'giorni consecutivi',
			'dashboard.welcomeTitle' => 'Benvenuto in Evolve',
			'dashboard.welcomeSubtitle' => 'Inizia il tuo percorso di crescita personale.',
			'dashboard.welcomeBody' => 'Questa applicazione ti aiuta a costruire buone abitudini e raggiungere i tuoi obiettivi a lungo termine.',
			'dashboard.welcomeStart' => 'Inizia',
			'dashboard.subtitle' => 'Mantieni il ritmo. Ogni piccola azione consolida la persona che stai costruendo.',
			'dashboard.completionToday' => 'Completamento oggi',
			'dashboard.habitsCount' => ({required Object done, required Object total}) => '${done}/${total} abitudini',
			'dashboard.bestStreak' => 'Migliore serie',
			'dashboard.activeGoals' => 'Obiettivi attivi',
			'dashboard.avgProgress' => ({required Object pct}) => '${pct}% progresso medio',
			'dashboard.momentum' => 'Momentum',
			'dashboard.vsLastWeek' => 'rispetto alla scorsa settimana',
			'dashboard.weeklyTrend' => 'Andamento settimanale',
			'dashboard.weeklyTrendSubtitle' => 'Percentuale di completamento delle tue abitudini',
			'dashboard.thisWeekPill' => ({required Object value}) => '${value} questa settimana',
			'dashboard.todayProtocol' => 'Protocollo di oggi',
			'dashboard.todayProtocolSubtitle' => 'Completa le azioni essenziali prima di aggiungere altro',
			'dashboard.actionsCount' => ({required Object count}) => '${count} azioni',
			'dashboard.emptyHabits' => 'Il tuo canvas è vuoto. Crea la tua prima abitudine.',
			'dashboard.streakDaysShort' => ({required Object n}) => '${n} gg',
			'dashboard.checkInDone' => 'Check-in registrato',
			'dashboard.checkInPrompt' => 'Come ti senti oggi?',
			'dashboard.moodEnergyValue' => ({required Object mood, required Object energy}) => 'Umore ${mood}/10 · Energia ${energy}/10',
			'dashboard.checkInHint' => 'Registra umore ed energia per migliorare le analisi dei tuoi pattern.',
			'dashboard.updateCheckIn' => 'Aggiorna check-in',
			'dashboard.doCheckIn' => 'Fai il check-in',
			'dashboard.dailyCheckIn' => 'Check-in quotidiano',
			'dashboard.dailyCheckInSubtitle' => 'Una rilevazione rapida aiuta Evolve a leggere meglio i tuoi pattern.',
			'dashboard.record' => 'Registra',
			'dashboard.focusGoals' => 'Obiettivi in focus',
			'dashboard.currentPriorities' => 'Priorità correnti',
			'dashboard.goalLimitReached' => 'Limite di 100 obiettivi raggiunto. Passa a Pro per crearne altri.',
			'dashboard.emptyFocusGoals' => 'Nessun obiettivo in focus. Aggiungine uno.',
			'dashboard.weekToStart' => 'Settimana da avviare',
			'dashboard.weekGrowing' => 'Settimana in crescita',
			'dashboard.weekToRecover' => 'Settimana da recuperare',
			'dashboard.vsPreviousWeek' => ({required Object value}) => '${value} rispetto alla settimana precedente.',
			'stats.title' => 'Statistiche',
			'stats.global' => 'Globale',
			'stats.resilience' => 'Resilienza',
			'stats.tabHabits' => 'Abitudini',
			'stats.tabMood' => 'Umore',
			'stats.last30Days' => 'Ultimi 30 giorni',
			'stats.singleHabit' => 'Singola abitudine',
			'stats.noHabit' => 'Nessuna abitudine',
			'stats.completionToday' => 'Completamento oggi',
			'stats.bestStreakLabel' => 'Serie migliore',
			'stats.criticalDay' => 'Giorno critico',
			'stats.completePrioritiesFirst' => 'Completa prima le priorità',
			'stats.recentActivity' => 'Attività recente',
			'stats.recentActivitySubtitle' => 'Intensità di completamento negli ultimi 90 giorni',
			'stats.trendGlobal' => 'Trend globale',
			'stats.trendGlobalSubtitle' => 'Confronto temporale del protocollo',
			'stats.vsPrevDay' => ({required Object value}) => '${value}% vs giorno precedente',
			'stats.bestHabit' => 'Abitudine migliore',
			'stats.criticalArea' => 'Area critica',
			'stats.streakAtRisk' => 'Serie a rischio',
			'stats.streakAtRiskDetail' => ({required Object habit}) => '${habit} richiede attenzione nei prossimi check-in.',
			'stats.patternToConsolidate' => 'Pattern da consolidare',
			'stats.checkLowMoodDays' => 'Controlla i giorni con umore basso e mantieni il protocollo essenziale.',
			'stats.goalDue' => 'Obiettivo in scadenza',
			'stats.noGoalNeedsIntervention' => 'Nessun obiettivo attivo richiede un intervento.',
			'stats.performancePerHabit' => 'Performance per abitudine',
			'stats.performancePerHabitSubtitle' => 'Classifica calcolata dai log sincronizzati per consistenza settimanale',
			'stats.avgMood' => 'Umore medio',
			'stats.avgEnergy' => 'Energia media',
			'stats.checkInsAvailable' => ({required Object count}) => '${count} check-in disponibili',
			'stats.resilientHabit' => 'Abitudine resiliente',
			'stats.completedEvenHardDays' => 'Completata anche nei giorni difficili',
			'stats.moodEnergy' => 'Umore ed energia',
			'stats.moodEnergySubtitle' => 'Media dei check-in disponibili negli ultimi 90 giorni',
			'stats.completion' => 'Completamento',
			'stats.currentWeek' => 'Settimana corrente',
			'stats.currentStreak' => 'Serie corrente',
			'stats.currentStreakDetail' => 'Serie sincronizzata dai log disponibili',
			'stats.trend30' => 'Trend 30 giorni',
			'stats.trend30Detail' => 'Completamento negli ultimi 30 giorni',
			'stats.yearlyCalendar' => 'Calendario annuale',
			'stats.yearlyCalendarSubtitle' => ({required Object habit}) => 'Distribuzione dei completamenti di ${habit}',
			'stats.performancePerDay' => 'Performance per giorno',
			'stats.performancePerDaySubtitle' => 'Giorni forti e giorni deboli della settimana',
			'stats.protectStreak' => ({required Object days}) => 'Proteggi la serie di ${days} giorni',
			'stats.keepSameSlot' => 'Mantieni la stessa fascia oraria per ridurre la frizione nei giorni più intensi.',
			'stats.worstNegativeSeq' => ({required Object days}) => 'La peggiore sequenza negativa è durata ${days} giorni.',
			'stats.positiveLever' => 'Leva positiva rilevata',
			'stats.bestHabitRegularity' => ({required Object habit}) => '${habit} mantiene la migliore regolarità recente.',
			'stats.moodSensitivity' => 'Sensibilità all\'umore',
			'stats.lowEnergyCompletion' => 'Completamento con energia bassa',
			'stats.moodOutputCorrelation' => 'Correlazione umore-output',
			'stats.moodOutputSubtitle' => 'Completamenti disponibili nei giorni con check-in',
			'stats.keyCorrelations' => 'Correlazioni chiave',
			'stats.keyCorrelationsSubtitle' => 'Pattern che influenzano maggiormente il protocollo',
			'stats.moreLogsNeeded' => 'Servono più log per calcolare correlazioni utili.',
			'stats.createHabitForAnalysis' => 'Crea almeno un\'abitudine per visualizzare l\'analisi granulare.',
			'stats.noData' => 'Nessun dato',
			'stats.tabInfo' => 'Info',
			'stats.tabTrend' => 'Trend',
			'stats.tabAlerts' => 'Alert',
			'stats.tabOverview' => 'Overview',
			'stats.tabCalendar' => 'Calendario',
			'stats.tabPerformance' => 'Performance',
			'stats.tabImprovement' => 'Miglioramento',
			'stats.pageSubtitle' => 'Identifica i pattern che sostengono la crescita e intervieni sulle aree critiche.',
			'stats.actionsFraction' => ({required Object done, required Object total}) => '${done}/${total} azioni',
			'stats.affectedByHardDays' => ({required Object habit}) => '${habit} risente dei giorni difficili',
			'stats.last30DaysTrend' => 'Trend Ultimi 30 Giorni',
			'stats.strongestDayDetail' => ({required Object pct, required Object done, required Object total}) => 'Ben fatto, ${pct}% di completamento (${done}/${total})',
			'stats.weakestDayDetail' => ({required Object pct, required Object done, required Object total}) => 'Solo ${pct}% di completamento (${done}/${total})',
			'stats.brokenStreakItem' => ({required Object days}) => 'Streak di ${days} giorni interrotto',
			'stats.togetherProbability' => ({required Object percentage}) => '${percentage}% insieme',
			'stats.criticalHabitsSubtitle' => 'Le abitudini che stanno peggiorando di più.',
			'stats.bestHabitsSubtitle' => 'Le abitudini in cui sei piu costante.',
			'stats.timeframeWeek' => 'Settimana',
			'stats.timeframeMonth' => 'Mese',
			'stats.timeframeYear' => 'Anno',
			'stats.timeframeAll' => 'Tutto',
			'stats.negativeStreakDays' => ({required Object days}) => '${days} giorni senza completamento',
			'stats.dropPercent' => ({required Object drop}) => '-${drop}%',
			'stats.blackDayDetail' => ({required Object day}) => 'Giorno nero: ${day}',
			'stats.failureDetail' => ({required Object streak, required Object frequency}) => 'Serie peggiore: ${streak}g · ~${frequency}/mese mancati',
			'stats.recoveryDetail' => ({required Object days}) => 'Tempo medio di recupero: ${days} giorni',
			'stats.successRate' => ({required Object rate}) => '${rate}% successo',
			'stats.sortRate' => 'Percentuale',
			'stats.sortStreak' => 'Serie',
			'stats.sortName' => 'Nome',
			'stats.worstStreakLabel' => 'Peggiore',
			'habitsPage.today' => 'Oggi',
			'habitsPage.subtitle' => 'Costruisci il protocollo quotidiano e osserva la consistenza nel tempo.',
			'habitsPage.tabProtocol' => 'Protocollo',
			'habitsPage.tabCalendar' => 'Calendario',
			'habitsPage.deleteHabitTitle' => 'Elimina abitudine',
			'habitsPage.deleteHabitConfirm' => ({required Object title}) => 'Vuoi rimuovere "${title}" dal protocollo?',
			'habitsPage.activeProtocol' => 'Protocollo attivo',
			'habitsPage.completedToday' => 'Completate oggi',
			'habitsPage.dailyProtocol' => 'Protocollo quotidiano',
			'habitsPage.protocolSubtitle' => 'Panoramica settimanale, reminder e azioni rapide',
			'habitsPage.colHabit' => 'ABITUDINE',
			'habitsPage.colStreak' => 'SERIE',
			'habitsPage.colLast7Days' => 'ULTIMI 7 GIORNI',
			'habitsPage.colReminder' => 'REMINDER',
			'habitsPage.streakDays' => ({required Object n}) => '${n} giorni',
			'habitsPage.prevPeriod' => 'Periodo precedente',
			'habitsPage.nextPeriod' => 'Periodo successivo',
			'habitsPage.weekdayAbbrevUpper.0' => 'LUN',
			'habitsPage.weekdayAbbrevUpper.1' => 'MAR',
			'habitsPage.weekdayAbbrevUpper.2' => 'MER',
			'habitsPage.weekdayAbbrevUpper.3' => 'GIO',
			'habitsPage.weekdayAbbrevUpper.4' => 'VEN',
			'habitsPage.weekdayAbbrevUpper.5' => 'SAB',
			'habitsPage.weekdayAbbrevUpper.6' => 'DOM',
			'habitsPage.lifeView' => 'Vista vita',
			'habitsPage.lifeViewSubtitle' => 'Una cella rappresenta un mese del percorso fino a 85 anni.',
			'habitsPage.monthsLived' => 'Mesi vissuti',
			'habitsPage.currentAge' => 'Età attuale',
			'habitsPage.monthsRemaining' => 'Mesi rimanenti',
			'habitsPage.dayDetail' => ({required Object day, required Object month}) => 'Dettaglio ${day} ${month}',
			'habitsPage.dayDetailSubtitle' => 'Aggiorna lo stato delle abitudini per questo giorno.',
			'habitsPage.editHabit' => 'Modifica abitudine',
			'habitsPage.newHabit' => 'Nuova abitudine',
			'habitsPage.optionalReminder' => 'Promemoria opzionale',
			'habitsPage.reminderHint' => 'es. 08:30',
			'habitsPage.close' => 'Chiudi',
			'habitsPage.statusDone' => ({required Object category}) => '${category} · Completata',
			'habitsPage.statusSkipped' => ({required Object category}) => '${category} · Saltata',
			'habitsPage.statusUnrecorded' => ({required Object category}) => '${category} · Non registrata',
			'habitsPage.weekOf' => ({required Object day, required Object month}) => 'Settimana del ${day} ${month}',
			'habitsPage.lifeWeeks' => 'Settimane del tuo percorso',
			'habitsPage.catWellness' => 'Benessere',
			'habitsPage.catProductivity' => 'Produttività',
			'habitsPage.catEducation' => 'Formazione',
			'habitsPage.catHealth' => 'Salute',
			'habitsPage.catMindfulness' => 'Mindfulness',
			'habitsPage.editableHint' => 'Puoi modificare solo oggi e ieri.',
			'lavoro' => 'Lavoro',
			'salute' => 'Salute',
			'finanza' => 'Finanza',
			'relazioni' => 'Relazioni',
			'formazione' => 'Formazione',
			'hobby' => 'Hobby',
			'spirituale' => 'Spirituale',
			'altro' => 'Altro',
			'goalsPage.title' => 'Macro Obiettivi',
			'goalsPage.subtitle' => 'Pianificazione a lungo termine.',
			'goalsPage.sampleGoal' => 'Obiettivo di esempio',
			'goalsPage.periodLifetime' => 'Obiettivi di vita',
			'goalsPage.subtitleLifetime' => 'Obiettivi Lifetime',
			'goalsPage.subtitleAnnual' => 'Obiettivi Annuali',
			'goalsPage.subtitleQuarterly' => 'Obiettivi Trimestrali',
			'goalsPage.subtitleMonthly' => 'Obiettivi Mensili',
			'goalsPage.subtitleWeekly' => 'Obiettivi Settimanali',
			'goalsPage.statsTab' => 'Stats',
			'goalsPage.fullView' => 'Visione completa',
			'goalsPage.categoriesTitle' => 'Categorie obiettivi',
			'goalsPage.defaultPill' => 'Predefinita',
			'goalsPage.editCategory' => 'Modifica categoria',
			'goalsPage.archiveCategory' => 'Archivia categoria',
			'goalsPage.categoryCreateFailed' => 'Creazione categoria non riuscita.',
			'goalsPage.categoryArchiveFailed' => 'Archivio categoria non riuscito.',
			'goalsPage.categoryEditFailed' => 'Modifica categoria non riuscita.',
			'goalsPage.addCategory' => 'Aggiungi categoria',
			'goalsPage.back' => 'Indietro',
			'goalsPage.finish' => 'Fine',
			'goalsPage.next' => 'Avanti',
			'goalsPage.categoriesTooltip' => 'Categorie',
			'goalsPage.rescheduleTooltip' => 'Riprogramma al periodo successivo',
			'goalsPage.defaultCategory' => 'Default',
			'goalsPage.emptyActive' => 'Nessun obiettivo attivo in questo periodo.',
			'goalsPage.emptyAdd' => 'Aggiungi il primo obiettivo per questo periodo.',
			'goalsPage.newGoal' => 'Nuovo obiettivo',
			'goalsPage.editGoal' => 'Modifica obiettivo',
			'goalsPage.horizonLabel' => 'Orizzonte',
			'goalsPage.newCategory' => 'Nuova categoria',
			'goalsPage.nameLabel' => 'Nome',
			'goalsPage.weekPeriodLabel' => ({required Object week, required Object month, required Object year}) => 'Settimana ${week}, ${month} ${year}',
			'goalsPage.currentQuarter' => 'Trimestre corrente',
			'goalsPage.currentMonth' => 'Mese corrente',
			'goalsPage.tutPlanningTitle' => 'Tipo di pianificazione',
			'goalsPage.tutPlanningDesc' => 'Qui puoi selezionare l\'orizzonte temporale dei tuoi obiettivi.',
			'goalsPage.tutNewGoalDesc' => 'Da qui puoi inserire rapidamente un nuovo obiettivo.',
			'goalsPage.tutCompleteTitle' => 'Completa o fallisci',
			'goalsPage.tutCompleteDesc' => 'Segna l\'obiettivo come completato o fallito con un semplice clic.',
			'goalsPage.tutCategoryDesc' => 'Gestisci le categorie e associale ai tuoi obiettivi.',
			'goalsPage.tutRescheduleTitle' => 'Riprogramma',
			'goalsPage.tutRescheduleDesc' => 'Sposta l\'obiettivo al periodo successivo se non sei riuscito a completarlo.',
			'goalsPage.tutEditDesc' => 'Modifica i dettagli del tuo obiettivo.',
			'goalsPage.tutDeleteDesc' => 'Elimina un obiettivo se non è più rilevante.',
			'goalsPage.tutStatsTitle' => 'Analisi e statistiche',
			'goalsPage.tutStatsDesc' => 'Passa alla vista statistiche per analizzare il tuo rendimento nel tempo.',
			'goalsStats.proRequired' => 'Funzione Pro richiesta',
			'goalsStats.active' => 'Attivi',
			'goalsStats.failed' => 'Falliti',
			'goalsStats.complAbbr' => 'Compl.',
			'goalsStats.seasonality' => 'Stagionalità',
			'goalsStats.interestEvolution' => 'Evoluzione Interessi',
			'ai.coach' => 'AI Coach',
			'ai.dailyHabits' => 'Abitudini giornaliere',
			'ai.macroGoals' => 'Macro obiettivi',
			'ai.openRouter.apiKeyMissingFull' => '⚠️ Errore: chiave API di OpenRouter non configurata.\n\nInserisci la chiave API nel file `lib/core/openrouter_config.dart`.',
			'ai.openRouter.apiKeyMissingShort' => '⚠️ Errore: chiave API di OpenRouter non configurata.',
			'ai.openRouter.defaultSystemPrompt' => 'Sei il "Coach di Disciplina", un assistente virtuale focalizzato sull’aiutare la persona a mantenere la disciplina, raggiungere i propri obiettivi e costruire abitudini sane. Sii motivante ma concreto, diretto e pratico. Usa un tono professionale ma amichevole.',
			'ai.openRouter.communicationError' => ({required Object code}) => '❌ Errore nella comunicazione con l’AI. (Codice: ${code})',
			'ai.openRouter.connectionError' => '❌ Errore di connessione. Assicurati di essere online e riprova.',
			'ai.openRouter.connectionErrorShort' => '❌ Errore di connessione.',
			'ai.openRouter.connectionCheckTimeout' => '❌ Errore: la verifica della connessione ha impiegato troppo tempo.',
			'ai.openRouter.contextTooLong' => '⚠️ Limite di memoria superato o richiesta non valida. La conversazione potrebbe essere troppo lunga o complessa. Usa l’icona del cestino in alto per svuotare la chat e ricominciare.',
			'ai.openRouter.noInternet' => '❌ Errore: nessuna connessione a internet. Verifica la rete.',
			'ai.openRouter.serverTimeout' => '❌ Errore: il server sta impiegando troppo tempo a rispondere. Riprova.',
			'ai.openRouter.apiError' => ({required Object code}) => '❌ Errore API: ${code} (verifica Sentry per i dettagli)',
			'ai.suggestions.morningBoost' => '🔥 Dammi la carica per iniziare!',
			'ai.suggestions.avoidDistractions' => '🧠 Come evitare le distrazioni?',
			'ai.suggestions.lowEnergy' => '⚡ Ho un calo di energia, cosa faccio?',
			'ai.suggestions.stayFocused' => '💪 Un consiglio per rimanere focalizzato',
			'ai.suggestions.prepareTomorrow' => '🛌 Come prepararsi per un domani produttivo?',
			'ai.suggestions.disciplineReflection' => '📝 Riflessione sulla disciplina di oggi',
			'ai.suggestions.analyzeActiveGoals' => '🎯 Analizza i miei obiettivi attivi',
			'ai.suggestions.planMacroGoals' => '🗺️ Come pianificare i miei macro obiettivi?',
			'ai.suggestions.goalObstacles' => '🛑 Quali ostacoli bloccano i miei obiettivi?',
			'ai.suggestions.reachMilestones' => '📈 Un consiglio per raggiungere i miei traguardi',
			'ai.suggestions.consistencyStatus' => '📈 Come sta andando la mia costanza?',
			'ai.suggestions.weeklyStats' => '📊 Le mie statistiche settimanali',
			'ai.suggestions.planDay' => '🌅 Pianifica la mia giornata',
			'ai.suggestions.raiseBar' => '🚀 Come posso alzare l’asticella?',
			'ai.suggestions.recoverProcrastination' => '🤕 Come recuperare se ho procrastinato?',
			'ai.suggestions.connectHabitsGoals' => '🔗 Come legare le abitudini agli obiettivi?',
			'ai.suggestions.reviewGoalsHabits' => '📊 Review di obiettivi e abitudini',
			'ai.suggestions.disciplineAdvice' => '🔥 Consiglio sulla disciplina',
			'ai.suggestions.createNewHabit' => '💡 Come creare una nuova abitudine?',
			'aiCoach.greeting' => 'Ciao! Sono Evolve AI Coach. Sono qui per aiutarti a ottimizzare il tuo protocollo e raggiungere i tuoi obiettivi. Come posso esserti utile oggi?',
			'aiCoach.systemPersona' => 'Sei Evolve AI Coach, un assistente virtuale per la disciplina personale.',
			'aiCoach.habitsHeader' => 'ABITUDINI ATTIVE:',
			'aiCoach.noActiveHabits' => 'Nessuna abitudine attiva.',
			_ => null,
		} ?? switch (path) {
			'aiCoach.habitLine' => ({required Object title, required Object done, required Object streak}) => '${title} (Completata oggi: ${done}, Streak: ${streak})',
			'aiCoach.goalsHeader' => 'OBIETTIVI:',
			'aiCoach.noActiveGoals' => 'Nessun obiettivo a lungo termine attivo.',
			'aiCoach.goalLine' => ({required Object title, required Object due}) => '${title} (Scadenza: ${due})',
			'aiCoach.contextTitle' => 'Contesto AI',
			'aiCoach.contextBody' => 'Scegli quali dati condividere con il Coach AI per ricevere consigli personalizzati.',
			'aiCoach.shareHabitsDesc' => 'Condivide le abitudini attive, le serie e lo stato di completamento di oggi.',
			'aiCoach.shareGoalsDesc' => 'Condivide i tuoi obiettivi attivi a lungo termine.',
			'aiCoach.saveClose' => 'Salva e Chiudi',
			'aiCoach.subtitle' => 'Ragiona sui pattern con un coach contestuale basato sui dati del percorso.',
			'aiCoach.contextButton' => 'Contesto',
			'aiCoach.typing' => 'AI Coach sta scrivendo...',
			'aiCoach.inputHint' => 'Chiedi consigli al tuo Coach...',
			'aiCoach.defaultUserName' => 'utente',
			'aiCoach.userNameLine' => ({required Object userName}) => '- Nome: ${userName}',
			'aiCoach.activeGoalsCount' => ({required Object count}) => '- Obiettivi attivi: ${count}',
			'aiCoach.completedGoalsCount' => ({required Object count}) => '- Obiettivi completati: ${count}',
			'aiCoach.todayCompletion' => ({required Object completed, required Object total}) => '- Abitudini oggi: ${completed} completate su ${total} totali.',
			'settingsPage.account' => 'Account',
			'settingsPage.notifications' => 'Notifiche',
			'settingsPage.language' => 'Lingua',
			'settingsPage.timeFormat24h' => 'Formato 24h',
			'settingsPage.subscription' => 'Abbonamento',
			'settingsPage.proName' => 'Evolve Pro',
			'settingsPage.planMonthly' => 'Mensile',
			'settingsPage.planAnnual' => 'Annuale',
			'settingsPage.restorePurchases' => 'Ripristina acquisti',
			'settingsPage.deletePrivateData' => 'Elimina dati privati',
			'settingsPage.importInProgress' => 'Importazione in corso...',
			'settingsPage.passwordsDontMatch' => 'Le password non coincidono.',
			'settingsPage.email' => 'Email',
			'settingsPage.cancel' => 'Annulla',
			'settingsPage.confirm' => 'Conferma',
			'settingsPage.save' => 'Salva',
			'settingsPage.pageTitle' => 'Impostazioni',
			'settingsPage.pageSubtitle' => 'Gestisci profilo, comportamento desktop, privacy e piano Evolve.',
			'settingsPage.profileLabel' => 'Profilo',
			'settingsPage.profileSubtitle' => 'Informazioni personali e stato sincronizzazione',
			'settingsPage.accountAndOnboarding' => 'Account e onboarding',
			'settingsPage.privateMode' => 'Modalità Privata',
			'settingsPage.sessionUnavailable' => 'Sessione non disponibile',
			'settingsPage.dataRepository' => 'Repository dati',
			'settingsPage.encryptedLocalDatabase' => 'Database locale crittografato',
			'settingsPage.supabaseWithEncryptedCache' => 'Supabase con cache cifrata',
			'settingsPage.personalInfo' => 'Informazioni personali',
			'settingsPage.personalInfoDetail' => 'Nome, cognome, email e data di nascita',
			'settingsPage.updateAvatar' => 'Aggiorna avatar',
			'settingsPage.updateAvatarDetail' => 'Scegli un immagine locale per il profilo desktop.',
			'settingsPage.reviewInitialConsent' => 'Rivedi consenso iniziale',
			'settingsPage.reviewInitialConsentDetail' => 'Termini, privacy, notifiche e crash reporting',
			'settingsPage.signOut' => 'Esci dall\'account',
			'settingsPage.signOutDetailActive' => 'Chiudi la sessione su questo dispositivo',
			'settingsPage.availableWithActiveSession' => 'Disponibile con una sessione Supabase attiva',
			'settingsPage.goToLogin' => 'Vai al Login',
			'settingsPage.goToLoginDetail' => 'Sospendi la modalità privata e accedi a Supabase.',
			'settingsPage.appearanceTitle' => 'Aspetto e applicazione',
			'settingsPage.appearanceSubtitle' => 'Preferenze locali adattate al desktop',
			'settingsPage.appearanceAndVisual' => 'Aspetto e visual',
			'settingsPage.darkMode' => 'Modalita scura',
			'settingsPage.darkModeDetail' => 'Usa il tema scuro in bianco e nero.',
			'settingsPage.calendarExperienceLanguage' => 'Calendario, esperienza e lingua',
			'settingsPage.accentColor' => 'Colore accento',
			'settingsPage.accentColorDetail' => 'Palette estesa riservata a Evolve Pro.',
			'settingsPage.defaultCalendarView' => 'Vista calendario predefinita',
			'settingsPage.timeFormat24hDetail' => 'Usa orari come 20:30 invece di 8:30 PM.',
			'settingsPage.hapticFeedback' => 'Feedback aptico',
			'settingsPage.hapticFeedbackDetail' => 'Il desktop conserva la preferenza ma non genera vibrazioni.',
			'settingsPage.resetTutorial' => 'Ripristina tutorial',
			'settingsPage.resetTutorialDetail' => 'Riapre i walkthrough di dashboard e obiettivi.',
			'settingsPage.notificationsSubtitle' => 'Promemoria operativi del client desktop',
			'settingsPage.operationalReminders' => 'Promemoria operativi',
			'settingsPage.habitReminders' => 'Promemoria abitudini',
			'settingsPage.habitRemindersDetail' => 'Invia il morning briefing giornaliero.',
			'settingsPage.morningBriefTime' => 'Orario morning brief',
			'settingsPage.eveningReview' => 'Review serale',
			'settingsPage.eveningReviewDetail' => 'Ricorda di consolidare la giornata.',
			'settingsPage.eveningReviewTime' => 'Orario review serale',
			'settingsPage.requestNotificationPermissions' => 'Richiedi permessi notifiche',
			'settingsPage.requestNotificationPermissionsDetail' => 'Apre il prompt nativo sul target supportato.',
			'settingsPage.nativeDeliveryTitle' => 'Delivery nativo per sistema operativo',
			'settingsPage.privacyTitle' => 'Privacy e sicurezza',
			'settingsPage.privacySubtitle' => 'Protezione accesso, consensi e gestione dati',
			'settingsPage.accessProtection' => 'Protezione accesso',
			'settingsPage.biometricLock' => 'Blocco biometrico',
			'settingsPage.biometricLockDetail' => 'Disponibile con adapter nativo su macOS e Windows; non supportato su Linux.',
			'settingsPage.changePassword' => 'Cambia password',
			'settingsPage.changePasswordDetail' => 'Aggiornamento credenziali tramite Supabase Auth.',
			'settingsPage.dataAndConsents' => 'Dati e consensi',
			'settingsPage.sendCrashReports' => 'Invia segnalazioni crash',
			'settingsPage.sendCrashReportsDetail' => 'Consenso separato per Sentry.',
			'settingsPage.exportData' => 'Esporta dati',
			'settingsPage.exportDataDetail' => 'Condivide un export JSON completo dei dati disponibili.',
			'settingsPage.importData' => 'Importa dati',
			'settingsPage.importDataDetail' => 'Ripristina un backup (formato .zip) di Evolve.',
			'settingsPage.systemPermissionsManagement' => 'Gestione permessi di sistema',
			'settingsPage.systemPermissionsManagementDetail' => 'Notifiche, calendario e sicurezza.',
			'settingsPage.deletePrivateDataDetail' => 'Cancella definitivamente il database locale crittografato.',
			'settingsPage.deleteAccountAndData' => 'Elimina account e dati',
			'settingsPage.deleteAccountAndDataDetail' => 'Operazione irreversibile protetta da conferma.',
			'settingsPage.exportPrivateShareText' => 'I miei dati privati esportati da Evolve',
			'settingsPage.exportShareText' => 'I miei dati esportati da Evolve',
			'settingsPage.exportDoneTitle' => 'Export completato',
			'settingsPage.exportDoneClipboard' => 'Il JSON e negli appunti: Linux non supporta la condivisione file.',
			'settingsPage.exportDoneShare' => 'Il JSON e stato inviato al selettore di condivisione.',
			'settingsPage.avatarGateTitle' => 'Avatar',
			'settingsPage.avatarPickFailed' => 'Selezione immagine non riuscita.',
			'settingsPage.confirmSignOutTitle' => 'Conferma uscita',
			'settingsPage.confirmSignOutMessage' => 'Sei sicuro di voler uscire? Dovrai reinserire le credenziali per accedere nuovamente.',
			'settingsPage.gateProfile' => 'Profilo',
			'settingsPage.gateLogout' => 'Logout',
			'settingsPage.gateChangePassword' => 'Cambio password',
			'settingsPage.gateRequiresActiveSession' => 'Richiede una sessione Supabase attiva.',
			'settingsPage.biometricActivationCancelled' => 'Attivazione annullata.',
			'settingsPage.notificationPermissionsTitle' => 'Permessi notifiche',
			'settingsPage.notificationPermissionsGranted' => 'Permessi disponibili per questo sistema.',
			'settingsPage.notificationPermissionsDenied' => 'Permesso non concesso. Puoi modificarlo dalle impostazioni di sistema.',
			'settingsPage.systemPermissionsTitle' => 'Permessi di sistema',
			'settingsPage.systemPermissionsOpenFailed' => 'Impossibile aprire le impostazioni.',
			'settingsPage.tutorialResetTitle' => 'Tutorial ripristinati',
			'settingsPage.tutorialResetMessage' => 'Le guide verranno mostrate nuovamente nelle relative sezioni.',
			'settingsPage.accountDataManagementTitle' => 'Gestione account e dati',
			'settingsPage.accountDataManagementContent' => 'Scegli se eliminare i dati mantenendo attivo l account oppure cancellare definitivamente l account.',
			'settingsPage.resetDataAction' => 'Resetta i dati',
			'settingsPage.deleteAccountAction' => 'Elimina account',
			'settingsPage.confirmResetDataTitle' => 'Conferma reset dati',
			'settingsPage.confirmResetDataMessage' => 'Verranno eliminate abitudini, obiettivi e preferenze. L account restera attivo. Questa azione non puo essere annullata.',
			'settingsPage.confirmDeleteAccountTitle' => 'Conferma eliminazione account',
			'settingsPage.confirmDeleteAccountMessage' => 'L account e tutti i dati associati verranno eliminati definitivamente. Questa azione e irreversibile.',
			'settingsPage.resetDataTitle' => 'Reset dati',
			'settingsPage.resetDataSuccess' => 'Dati eliminati con successo.',
			'settingsPage.operationFailed' => 'Operazione non riuscita.',
			'settingsPage.deleteAccountGateTitle' => 'Elimina account',
			'settingsPage.accountDeleted' => 'Account eliminato.',
			'settingsPage.importDataGateTitle' => 'Importa dati',
			'settingsPage.importPrivateOnly' => 'La funzione di importazione è attualmente disponibile solo in Modalità Privata (Locale).',
			'settingsPage.importSummaryTitle' => 'Riepilogo Importazione',
			'settingsPage.importHabitsCount' => ({required Object count}) => '${count} Abitudini',
			'settingsPage.importLogsCount' => ({required Object count}) => '${count} Check-in (Log)',
			'settingsPage.importMacroGoalsCount' => ({required Object count}) => '${count} Obiettivi Macro',
			'settingsPage.importCategoriesCount' => ({required Object count}) => '${count} Categorie',
			'settingsPage.importMoodsCount' => ({required Object count}) => '${count} Registrazioni Umore',
			'settingsPage.importReplaceTitle' => 'Sostituisci i dati attuali',
			'settingsPage.importReplaceSubtitle' => 'Elimina tutti i dati locali esistenti prima di importare. (Consigliato)',
			'settingsPage.importMergeTitle' => 'Unisci ai dati attuali',
			'settingsPage.importMergeSubtitle' => 'Aggiunge i dati importati senza eliminare nulla. Potrebbe causare duplicati.',
			'settingsPage.importConfirmButton' => 'Conferma Importazione',
			'settingsPage.importSuccess' => 'Importazione completata con successo!',
			'settingsPage.importError' => ({required Object error}) => 'Errore durante importazione: ${error}',
			'settingsPage.proTitle' => 'Evolve Pro',
			'settingsPage.proSubtitle' => 'Piano, ripristino acquisti e gestione abbonamento',
			'settingsPage.revenueCatMacos' => 'RevenueCat macOS',
			'settingsPage.commercialChannelRequired' => 'Canale commerciale richiesto',
			'settingsPage.revenueCatOffersRead' => 'Offerte e stato entitlement vengono letti da RevenueCat.',
			'settingsPage.revenueCatConfigureKey' => 'Configura la public key RevenueCat del client desktop.',
			'settingsPage.revenueCatNotSupported' => 'RevenueCat Flutter non espone acquisti in-app su Windows e Linux.',
			'settingsPage.bestValue' => 'Miglior valore',
			'settingsPage.planManagement' => 'Gestione piano',
			'settingsPage.activateEvolvePro' => 'Attiva Evolve Pro',
			'settingsPage.activateEvolveProActive' => 'Entitlement Evolve Pro attivo.',
			'settingsPage.activateEvolveProStart' => 'Avvia il checkout StoreKit nativo su macOS.',
			'settingsPage.restorePurchasesDetail' => 'Recupera lo stato entitlement dal provider.',
			'settingsPage.manageSubscription' => 'Gestisci abbonamento',
			'settingsPage.manageSubscriptionDetail' => 'Apre la gestione abbonamenti dell account Apple.',
			'settingsPage.notAuthenticated' => 'Non autenticato',
			'settingsPage.verified' => 'Verificato',
			'settingsPage.privateModeDataProtected' => 'I tuoi dati sono protetti e salvati unicamente su questo dispositivo.',
			'settingsPage.profileFallback' => 'Profilo',
			'settingsPage.fullName' => 'Nome completo',
			'settingsPage.dateOfBirth' => 'Data di nascita',
			'settingsPage.dateOfBirthHint' => 'AAAA-MM-GG',
			'settingsPage.currentPassword' => 'Password attuale',
			'settingsPage.newPassword' => 'Nuova password',
			'settingsPage.confirmNewPassword' => 'Conferma nuova password',
			'settingsPage.updatePassword' => 'Aggiorna password',
			'settingsPage.enterCurrentPassword' => 'Inserisci la password attuale.',
			'settingsPage.newPasswordMinLength' => 'La nuova password deve avere almeno 8 caratteri.',
			'settingsPage.passwordUpdateFailed' => 'Aggiornamento non riuscito. Verifica la password attuale.',
			'settingsPage.sectionApplication' => 'Applicazione',
			'settingsPage.sectionPrivacy' => 'Privacy',
			'settingsPage.customColor' => 'Colore personalizzato',
			'settingsPage.applyAction' => 'Applica',
			'settingsPage.useAccent' => ({required Object hex}) => 'Usa accento ${hex}',
			'settingsPage.proUpsellTitle' => 'Passa a Evolve Pro',
			'settingsPage.proUpsellSubtitle' => 'Sblocca tutte le funzionalità e accelera la tua crescita.',
			'settingsPage.proWelcomeTitle' => 'Benvenuto in Evolve Pro!',
			'settingsPage.proActiveMessage' => 'La tua iscrizione è attiva. Ora hai accesso completo ed illimitato all\'AI Coach personalizzato, alle statistiche avanzate dei trend e a tutti gli strumenti di crescita personale di Evolve.',
			'settingsPage.proStartJourney' => 'Inizia il tuo Percorso',
			'settingsPage.systemSection' => 'Sistema',
			'settingsPage.appLogsTitle' => 'Log dell\'app',
			'settingsPage.appLogsDetail' => 'Visualizza i log diagnostici di questa sessione',
			'consent.onboardingTitle' => 'La tua Privacy è Importante',
			'consent.continueButton' => 'Continua',
			'notifications.actionDone' => 'Fatto',
			'notifications.actionSkip' => 'Salta',
			'notifications.actionSnooze' => 'Posticipa',
			'notifications.morningBrief' => 'Morning Brief',
			'notifications.eveningReview' => 'Review Serale',
			'notifications.morningBriefBody' => 'È il momento di plasmare la tua giornata. Controlla i tuoi obiettivi.',
			'notifications.eveningReviewBody' => 'Com’è andata oggi? Traccia i tuoi progressi e aggiorna il Diario di Bordo.',
			'privacy.biometricAuthReason' => 'Autenticati per abilitare la protezione dell\'app.',
			'privacy.biometricUnlockReason' => 'Sblocca l\'app per continuare.',
			'consentPage.subtitle' => 'Prima di usare Evolve Desktop conferma termini, privacy policy e trattamento dei dati necessari alla sincronizzazione.',
			'consentPage.acceptTerms' => 'Accetto termini e privacy policy',
			'consentPage.termsSubtitle' => 'Confermo di aver letto i documenti e di avere almeno 14 anni.',
			'consentPage.crashDiagnostics' => 'Diagnostica crash',
			'consentPage.crashSubtitle' => 'Consenti l\'invio di segnalazioni tecniche anonimizzate.',
			'consentPage.openPrivacy' => 'Apri la privacy policy',
			'consentPage.openTerms' => 'Termini di servizio',
			'consentPage.notificationsTitle' => 'Abilita le notifiche',
			'consentPage.notificationsSubtitle' => 'Ricevi promemoria delle abitudini e riepiloghi giornalieri.',
			'consentPage.enableNotifications' => 'Abilita',
			'consentPage.notificationsEnabled' => 'Attive',
			'notif.macScheduling' => 'Scheduling giornaliero attivo su macOS.',
			'notif.linuxImmediate' => 'Linux mostra notifiche immediate, ma non supporta lo scheduling.',
			'notif.openEvolve' => 'Apri Evolve',
			'notif.windowsScheduling' => 'Windows pianifica la prossima occorrenza a ogni avvio.',
			'notif.morningBody' => 'Rivedi le abitudini di oggi e scegli da dove iniziare.',
			'notif.habitReminderBody' => 'È il momento di completare la tua abitudine.',
			'notif.eveningBody' => 'Consolida la giornata e aggiorna i progressi.',
			'biometricGate.appLocked' => 'App bloccata',
			'biometricGate.unlockPrompt' => 'Sblocca con l\'autenticazione locale per continuare.',
			'biometricGate.verifying' => 'Verifica...',
			'biometricGate.unlock' => 'Sblocca',
			'biometricGate.notSupportedLinux' => 'Il blocco biometrico non è supportato su Linux.',
			'biometricGate.noLocalAuth' => 'Nessun metodo di autenticazione locale disponibile.',
			'biometricGate.authFailed' => 'Autenticazione non riuscita.',
			'biometricGate.authUnavailable' => 'Autenticazione locale non disponibile.',
			'sync.syncFailed' => 'Sincronizzazione non riuscita. Dati locali mantenuti.',
			'sync.editSavedLocally' => 'Modifica salvata localmente. Sincronizzazione da riprovare.',
			'subscriptionCtrl.purchaseComplete' => 'Acquisto completato: sincronizzazione entitlement in corso.',
			'subscriptionCtrl.purchaseIncomplete' => 'Acquisto non completato.',
			'subscriptionCtrl.cantOpenApple' => 'Impossibile aprire la gestione abbonamenti Apple.',
			'subscriptionCtrl.macOnly' => 'Gli acquisti in-app sono disponibili nel client macOS.',
			'subscriptionCtrl.loadOffersFailed' => 'Impossibile caricare le offerte RevenueCat.',
			'subscriptionCtrl.proActivated' => 'Evolve Pro attivato.',
			'subscriptionCtrl.purchasesRestored' => 'Acquisti ripristinati.',
			'subscriptionCtrl.noActiveSub' => 'Nessun abbonamento Pro attivo trovato.',
			'subscriptionCtrl.restoreFailed' => 'Ripristino acquisti non riuscito.',
			'subscriptionCtrl.configKey' => 'Configura la public key RevenueCat del client desktop.',
			'subscriptionCtrl.loginFirst' => 'Accedi prima di gestire Evolve Pro.',
			'authCtrl.appleNoToken' => 'Apple non ha restituito un identity token.',
			'authCtrl.appleAuthFailed' => 'Autenticazione Apple non riuscita.',
			'authCtrl.cantOpenBrowser' => 'Impossibile aprire il browser di sistema.',
			'authCtrl.accessNotCompleted' => ({required Object provider}) => 'Accesso ${provider} non completato.',
			'authCtrl.providerAuthFailed' => ({required Object provider}) => 'Autenticazione ${provider} non riuscita.',
			'authCtrl.operationFailed' => 'Operazione non riuscita. Riprova tra poco.',
			'proModal.title' => 'Sblocca Evolve Pro',
			'proModal.subtitle' => 'Porta il tuo sistema di abitudini al livello successivo',
			'proModal.featuresHeader' => 'COSA INCLUDE IL PIANO PRO',
			'proModal.aiCoachTitle' => 'AI Coach Personalizzato',
			'proModal.aiCoachDesc' => 'Analisi avanzata dei trend e suggerimenti intelligenti generati dall\'AI.',
			'proModal.statsTitle' => 'Statistiche Specifiche Per Abitudine',
			'proModal.statsDesc' => 'Informazioni chiave per aumentare la tua produttività.',
			'proModal.metricsTitle' => 'Metriche Avanzate Obiettivi',
			'proModal.metricsDesc' => 'Visualizza grafici dettagliati e statistiche di performance profonde per ogni anno.',
			'proModal.unlimitedTitle' => 'Abitudini Illimitate',
			'proModal.unlimitedDesc' => 'Crea e traccia tutti gli habits che desideri senza alcun limite.',
			'proModal.maybeLater' => 'Forse più tardi',
			'proModal.viewPlans' => 'Vedi i piani Pro',
			'tutorial.back' => 'Indietro',
			'tutorial.next' => 'Avanti',
			'tutorial.finish' => 'Fine',
			'tutorial.dailyCheckIn' => 'Daily Check-in',
			'tutorial.dailyCheckinDesc' => 'Qui puoi registrare il tuo stato d\'animo quotidiano per tracciare il tuo benessere nel tempo e soprattutto correlarlo con il completamento dei tuoi obiettivi.',
			'tutorial.manageHabits' => 'Gestione Abitudini',
			'tutorial.addEditOrDeleteDailyHabits' => 'Aggiungi, modifica o elimina le tue abitudini quotidiane che vuoi rispettare in modo semplice e veloce.',
			'tutorial.movingToGoals' => 'Passiamo agli Obiettivi',
			'tutorial.goalsPageDesc' => 'La pagina dove puoi gestire i tuoi obiettivi a lungo termine e le relative performance.',
			'tutorial.filterByHabit' => 'Filtra per Abitudine',
			'tutorial.filterHabitDesc' => 'Da qui puoi selezionare una specifica abitudine per vederne i dettagli, oppure \'Tutti gli Habits\' per una panoramica globale.',
			'tutorial.statisticsSections' => 'Sezioni Statistiche',
			'tutorial.statsSectionsDesc' => 'Naviga tra le varie schede per vedere i Trend, gli Alert sulle performance, l\'andamento delle Abitudini e il tuo Mood.',
			'appLogs.title' => 'Log App',
			'appLogs.copiedToClipboard' => 'Log copiati negli appunti',
			'appLogs.clearLogsTitle' => 'Cancella Log',
			'appLogs.clearLogsConfirm' => 'Sei sicuro di voler cancellare tutte le voci di log? Questa azione non può essere annullata.',
			'appLogs.clearLogsAction' => 'Cancella Tutto',
			'appLogs.copyAll' => 'Copia Tutti i Log',
			'appLogs.searchPlaceholder' => 'Cerca nei log...',
			'appLogs.filterAll' => 'Tutti',
			'appLogs.filterErrors' => 'Errori',
			'appLogs.filterWarnings' => 'Avvisi',
			'appLogs.filterInfo' => 'Info',
			'appLogs.emptyTitle' => 'Nessun Log',
			'appLogs.emptySubtitle' => 'I log appariranno qui durante l\'uso dell\'app',
			'appLogs.stackTraceAvailable' => 'Tocca per visualizzare lo stack trace',
			'appLogs.detailMessage' => 'MESSAGGIO',
			'appLogs.detailError' => 'ERRORE',
			'appLogs.detailExtras' => 'CONTESTO AGGIUNTIVO',
			'appLogs.detailStackTrace' => 'STACK TRACE',
			'appLogs.shareLogs' => 'Condividi file dei log',
			'appLogs.exportDone' => 'Log esportati',
			_ => null,
		};
	}
}
