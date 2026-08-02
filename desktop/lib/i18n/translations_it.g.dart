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
	@override late final _Translations$verification$it verification = _Translations$verification$it._(_root);
	@override late final _Translations$macroTargets$it macroTargets = _Translations$macroTargets$it._(_root);
	@override late final _Translations$auth$it auth = _Translations$auth$it._(_root);
	@override late final _Translations$privateData$it privateData = _Translations$privateData$it._(_root);
	@override late final _Translations$icloudSync$it icloudSync = _Translations$icloudSync$it._(_root);
	@override late final _Translations$privateRecovery$it privateRecovery = _Translations$privateRecovery$it._(_root);
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
	@override late final _Translations$appLogs$it appLogs = _Translations$appLogs$it._(_root);
	@override late final _Translations$coachSettings$it coachSettings = _Translations$coachSettings$it._(_root);
	@override late final _Translations$tour$it tour = _Translations$tour$it._(_root);
	@override late final _Translations$palette$it palette = _Translations$palette$it._(_root);
	@override late final _Translations$targets$it targets = _Translations$targets$it._(_root);
	@override late final _Translations$trackingMode$it trackingMode = _Translations$trackingMode$it._(_root);
}

// Path: verification
class _Translations$verification$it extends Translations$verification$en {
	_Translations$verification$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get autoVerified => 'Verificato automaticamente';
	@override late final _Translations$verification$compound$it compound = _Translations$verification$compound$it._(_root);
	@override late final _Translations$verification$templates$it templates = _Translations$verification$templates$it._(_root);
	@override late final _Translations$verification$units$it units = _Translations$verification$units$it._(_root);
}

// Path: macroTargets
class _Translations$macroTargets$it extends Translations$macroTargets$en {
	_Translations$macroTargets$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get sectionTitle => 'Obiettivo numerico';
	@override String get none => 'Nessuno';
	@override String get amountLabel => 'Valore obiettivo';
	@override String get linkLabel => 'Collega un\'abitudine';
	@override String get manual => 'Manuale';
	@override String get unitCount => 'conteggio';
	@override String get reached => 'Raggiunto';
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
	@override String get bannerAction => 'Attiva';
	@override String get bannerText => 'La sincronizzazione iCloud è disattivata: le tue abitudini sono solo su questo dispositivo e vanno perse se lo ripristini o lo sostituisci.';
	@override String get deleteSyncNote => 'La sincronizzazione iCloud è attiva: verrà eliminata anche la copia sincronizzata nel tuo iCloud e la sincronizzazione verrà disattivata. Gli altri dispositivi conservano la loro copia locale — esegui questa operazione su ciascun dispositivo per eliminare tutto ovunque.';
	@override String get detailsAllSynced => 'Tutto caricato';
	@override String get detailsCopied => 'Report copiato';
	@override String get detailsCopy => 'Copia report';
	@override String detailsFailed({required Object count}) => '${count} elementi non caricati';
	@override String detailsPending({required Object count}) => '${count} elementi in attesa di caricamento';
	@override String get detailsTitle => 'Dettagli sincronizzazione';
	@override String get disclosureAccept => 'Abilita';
	@override String get disclosureBody => 'I tuoi dati privati si sincronizzano solo tramite il tuo account iCloud, con crittografia end-to-end — mai attraverso i nostri server. La chiave di crittografia risiede nel tuo Portachiavi iCloud; se disattivi il Portachiavi iCloud, i dati sincronizzati non potranno essere recuperati.';
	@override String get disclosureTitle => 'Crittografia end-to-end';
	@override String get enableTitle => 'Abilita sincronizzazione iCloud';
	@override String get forceEnable => 'Riparti da zero';
	@override String get forceEnableBody => 'I dati di un altro dispositivo sono già in iCloud, ma la chiave di cifratura non è ancora arrivata su questo dispositivo. Di solito basta attendere qualche minuto. Ripartire da zero cancella ciò che è in iCloud e lo sostituisce con i dati di questo dispositivo. L\'operazione non è reversibile.';
	@override String get forceEnableTitle => 'Riparti da questo dispositivo';
	@override String keySplitBody({required Object count}) => '${count} record in iCloud sono stati cifrati su un altro dispositivo con una chiave diversa, quindi questo dispositivo non può leggerli. Reimposta la sincronizzazione dal dispositivo che contiene i dati che vuoi conservare.';
	@override String get keySplitTitle => 'Alcuni dati iCloud non sono leggibili';
	@override String lastSyncedAt({required Object time}) => 'Ultima sincronizzazione ${time}';
	@override String get lastSyncedNever => 'Mai sincronizzato';
	@override String get resetFromDevice => 'Reimposta la sincronizzazione da questo dispositivo';
	@override String get resetFromDeviceConfirm => 'Questa operazione cancella tutto ciò che è attualmente in iCloud e carica al suo posto i dati di questo dispositivo. Gli altri dispositivi scaricheranno poi questa copia. Eseguila solo dal dispositivo che contiene i dati che vuoi conservare. L\'operazione non è reversibile.';
	@override String get resetFromDeviceDetail => 'Sostituisci tutto ciò che è in iCloud con i dati di questo dispositivo';
	@override String get resetFromDeviceDone => 'Sincronizzazione reimpostata. I dati di questo dispositivo sono ora la copia in iCloud.';
	@override String get statusIdle => 'Aggiornato';
	@override String get statusNoAccount => 'Accedi a iCloud per sincronizzare';
	@override String get statusNotSynced => 'Non è stato sincronizzato tutto';
	@override String get statusOff => 'Sincronizzazione disattivata';
	@override String get statusSyncing => 'Sincronizzazione…';
	@override String get statusUnavailable => 'iCloud non è disponibile al momento';
	@override String get statusWaitingKey => 'In attesa della chiave di cifratura dall\'altro dispositivo';
	@override String get statusWaitingKeychain => 'In attesa del Portachiavi iCloud — assicurati che l\'app sul tuo iPhone sia aggiornata';
	@override String get syncNow => 'Sincronizza ora';
	@override String get syncNowNeedsSync => 'Attiva prima la sincronizzazione iCloud.';
	@override String get title => 'Sincronizzazione iCloud';
	@override String get unavailablePlatform => 'Non disponibile su questo dispositivo';
}

// Path: privateRecovery
class _Translations$privateRecovery$it extends Translations$privateRecovery$en {
	_Translations$privateRecovery$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get preparing => 'Preparazione del tuo spazio privato…';
	@override String get restoredFromCloudToast => 'Impossibile sbloccare il database locale: i tuoi dati sono stati ripristinati da iCloud.';
	@override String get waitingTitle => 'In attesa di iCloud';
	@override String get waitingMessage => 'La sincronizzazione è attiva, ma la tua chiave di crittografia non è ancora arrivata dal Portachiavi iCloud. Attendi un momento e riprova.';
	@override String get lockedTitle => 'Impossibile sbloccare i dati privati';
	@override String get lockedMessageLocalOnly => 'Questo dispositivo non può sbloccare il database privato locale — la chiave di crittografia è mancante — e la sincronizzazione iCloud è disattivata, quindi non c\'è una copia cloud da ripristinare. Puoi reimpostare e ricominciare.';
	@override String get lockedMessageICloudUnavailable => 'Questo dispositivo non può sbloccare il database privato locale. La sincronizzazione iCloud è attiva ma l\'account non è disponibile: accedi a iCloud e riprova.';
	@override String get errorTitle => 'Impossibile aprire la modalità privata';
	@override String get errorMessage => 'Si è verificato un problema durante l\'apertura del database privato. Riprova oppure torna all\'accesso.';
	@override String get enableSyncHint => 'Hai questi dati su un altro dispositivo? Attiva la sincronizzazione iCloud nelle Impostazioni dopo la reimpostazione per recuperarli qui.';
	@override String get retry => 'Riprova';
	@override String get resetFresh => 'Reimposta e ricomincia';
	@override String get backToSignIn => 'Torna all\'accesso';
	@override String get undecryptableTitle => 'I tuoi dati sono al sicuro, ma questa copia dell\'app non può sbloccarli';
	@override String get undecryptableMessage => 'Il database privato su questo Mac è intatto: è semplicemente cifrato con una chiave diversa da quella di questa build. Non è stato modificato né eliminato nulla. Di solito significa che è stato creato da un\'altra build di Evolve (per esempio una build di sviluppo). Apri quella build per accedere ai dati, oppure ripristina da iCloud con un\'installazione pulita.';
	@override String get schemaTooNewTitle => 'Questo database proviene da una versione più recente';
	@override String get schemaTooNewMessage => 'I tuoi dati privati sono stati aperti l\'ultima volta da una versione più recente di Evolve e sono perfettamente intatti. Questa versione più vecchia non può leggerli in sicurezza. Aggiorna all\'ultima versione — o riapri la build più recente — e ritroverai tutto.';
	@override String get copyDiagnostics => 'Copia diagnostica';
	@override String get diagnosticsCopied => 'Diagnostica copiata negli appunti';
	@override String get resetConfirmTitle => 'Spostare da parte questo database?';
	@override String get resetConfirmBody => 'Evolve ripartirà con un database privato vuoto. Il file cifrato esistente viene conservato su questo Mac, non eliminato, quindi è ancora recuperabile.';
	@override String resetConfirmBodySized({required Object size}) => 'Evolve ripartirà con un database privato vuoto. Il file cifrato esistente (${size}) viene conservato su questo Mac, non eliminato, quindi è ancora recuperabile.';
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
	@override String get unexpectedErrorTitle => 'Qualcosa è andato storto';
	@override String get unexpectedErrorMessage => 'Si è verificato un errore imprevisto. Riprova.';
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
	@override String get periodWhen => 'Quando';
}

// Path: createHabit
class _Translations$createHabit$it extends Translations$createHabit$en {
	_Translations$createHabit$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Nuova Abitudine';
	@override String get subtitle => 'Definisci la tua nuova abitudine.';
	@override String get titleHint => 'es. Meditazione';
	@override String get weeklyFrequency => 'Frequenza settimanale';
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
	@override String get filterActive => 'Attive';
	@override String get filterAll => 'Tutte';
	@override String get noActiveHabits => 'Nessuna abitudine attiva: passa a Tutte per vedere quelle terminate.';
	@override String get worstStreakLabel => 'Peggiore';
	@override String get momentumTitle => 'Momentum';
	@override String get momentumSubtitle => 'La tua forma attuale';
	@override String get momentumForm => 'FORMA';
	@override String get momentumRate => '7 giorni';
	@override String get momentumStreakHealth => 'Serie';
	@override String get momentumTrend => 'Trend';
	@override String get rollingImproving => 'In crescita';
	@override String get rollingDeclining => 'In calo';
	@override String get rollingSteady => 'Stabile';
	@override String get lifetimeConsistency => 'Costanza';
	@override String get lifetimeConsistencyDetail => 'Completamento totale';
	@override String get lifetimeTotalDone => 'Totale completati';
	@override String get lifetimeTotalDoneDetail => 'Abitudini spuntate';
	@override String get lifetimePerfectDays => 'Giorni perfetti';
	@override String get lifetimePerfectDaysDetail => 'Tutto completato';
	@override String get lifetimeDaysTracked => 'Giorni monitorati';
	@override String get lifetimeDaysTrackedDetail => 'Da quando hai iniziato';
	@override String get keystoneTitle => 'ABITUDINE CHIAVE';
	@override String keystoneImpact({required Object withPct, required Object withoutPct}) => 'Nei suoi giorni completi il ${withPct}% delle altre abitudini, contro il ${withoutPct}%.';
	@override String get yearActivity => 'Attività di 365 giorni';
	@override String get yearActivitySubtitle => 'Ogni abitudine, ogni giorno';
	@override String activeDaysCount({required Object count}) => '${count} giorni attivi';
	@override String get heatmapLess => 'Meno';
	@override String get heatmapMore => 'Più';
	@override String get bestHabitsTitle => 'Migliori abitudini';
	@override String get criticalHabitsTitle => 'Da tenere d\'occhio';
	@override String criticalStalled({required Object days}) => '${days}g ferma';
	@override String get rollingTitle => 'Completamento mobile';
	@override String get rollingSubtitle => 'Tasso a 7 e 30 giorni';
	@override String get rolling7 => '7 giorni';
	@override String get rolling30 => '30 giorni';
	@override String get weekVsAvgTitle => 'Settimana vs media';
	@override String get weekVsAvgSubtitle => 'Come va questa settimana';
	@override String get thisWeek => 'Questa settimana';
	@override String get yourAverage => 'La tua media';
	@override String get weekdayShapeTitle => 'Ritmo settimanale';
	@override String get weekdayShapeSubtitle => 'Completamento per giorno';
	@override String get weekdayWeekendTitle => 'Settimana vs weekend';
	@override String get weekdayWeekendSubtitle => 'Dove sei più forte';
	@override String get weekdaysLabel => 'Feriali';
	@override String get weekendLabel => 'Weekend';
	@override String get seasonalityTitle => 'Stagionalità';
	@override String get seasonalitySubtitle => 'Completamento per mese';
	@override String get bounceBackTitle => 'Tasso di ripresa';
	@override String get bounceBackSubtitle => 'Recupero dopo un salto';
	@override String bounceBackDetail({required Object recoveries, required Object opportunities}) => 'Recuperato ${recoveries} volte su ${opportunities}';
	@override String get dangerZoneTitle => 'Zona di rischio';
	@override String get dangerZoneSubtitle => 'Quando le serie si spezzano';
	@override String get dangerZoneNone => 'Nessuna serie spezzata';
	@override String dangerZoneDetail({required Object breaks, required Object total}) => '${breaks} rotture su ${total} qui';
	@override String get performanceComparisonTitle => 'Confronto performance';
	@override String get performanceComparisonSubtitle => 'Serie migliore vs peggiore';
	@override String perfCompGap({required Object pct}) => '${pct}% divario';
	@override String get perfCompBest => 'Migliore';
	@override String get perfCompWorst => 'Peggiore';
	@override String get consistencyTitle => 'Costanza';
	@override String get consistencySubtitle => 'Abitudini più regolari';
	@override String get consistencySteadiest => 'Più costanti';
	@override String get consistencyErratic => 'Più irregolari';
	@override String get medalsTitle => 'Classifica serie';
	@override String get medalsSubtitle => 'Serie attuali più lunghe';
	@override String get neverMissedTitle => 'Mai saltata';
	@override String get neverMissedEmpty => 'Nessuna abitudine perfetta';
	@override String get distributionTitle => 'Distribuzione';
	@override String get distributionSubtitle => 'Abitudini per tasso di successo';
	@override String get synergyTitle => 'Sinergia abitudini';
	@override String get synergySubtitle => 'Quali abitudini vanno insieme';
	@override String get moodSensitiveTitle => 'Sensibili all\'umore';
	@override String get moodSensitiveSubtitle => 'Più influenzate dall\'umore';
	@override String get resilientHabitsTitle => 'Abitudini resilienti';
	@override String get resilientHabitsSubtitle => 'Fatte anche nei giorni no';
	@override String get correlationAnalysisTitle => 'Correlazione umore';
	@override String get correlationAnalysisSubtitle => 'Completamento umore basso vs alto';
	@override String get moodEnergyTrendTitle => 'Umore ed energia';
	@override String moodEnergyTrendSubtitle({required Object days}) => 'Ultimi ${days} giorni';
	@override String get allTimeBest => 'Record assoluto';
	@override String get topPerformerLabel => 'Migliore';
	@override String get currentStreakShort => 'Ora';
	@override String get recordLabel => 'Record';
	@override String get recordDetail => 'Serie record';
	@override String get adherenceTitle => 'Aderenza al piano';
	@override String get adherenceSubtitle => 'Dei giorni previsti';
	@override String adherenceDetail({required Object done, required Object scheduled}) => '${done} di ${scheduled} giorni previsti';
	@override String get atRiskTitle => 'A rischio';
	@override String get atRiskYes => 'Sì';
	@override String get atRiskNo => 'In linea';
	@override String atRiskDetail({required Object days}) => '${days} giorni dall\'ultima volta';
	@override String get daysUnit => 'g';
	@override String get gapTitle => 'Intervalli';
	@override String get gapSubtitle => 'Giorni tra un completamento e l\'altro';
	@override String get gapAvg => 'Media';
	@override String get gapLongest => 'Massimo';
	@override String get gapSince => 'Dall\'ultimo';
	@override String get habitBounceBackShort => 'Ripresa';
	@override String get habitConsistencyDetail => 'Punteggio regolarità';
	@override String habitPercentile({required Object pct}) => 'Meglio del ${pct}% delle tue abitudini';
	@override String get monthVsTitle => 'Questo mese vs scorso';
	@override String get monthVsSubtitle => 'Completamento mese su mese';
	@override String get thisMonthLabel => 'Questo mese';
	@override String get lastMonthLabel => 'Mese scorso';
	@override String get nextDayMoodTitle => 'Impatto sull\'umore del giorno dopo';
	@override String get nextDayMoodSubtitle => 'Umore ed energia il giorno seguente';
	@override String get nextDayAfterDone => 'Dopo averla fatta';
	@override String get nextDayAfterMissed => 'Dopo averla saltata';
	@override String nextDayMoodLift({required Object value}) => '${value} di umore in più';
	@override String get streakHistoryTitle => 'Cronologia serie';
	@override String get streakHistorySubtitle => 'Ogni sequenza di giorni consecutivi';
	@override String streakHistoryDetail({required Object count, required Object longest}) => '${count} serie · più lunga ${longest} giorni';
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
	@override String dayDotTooltip({required Object day, required Object month, required Object status}) => '${day} ${month} · ${status}';
	@override String dayDotTooltipToday({required Object status}) => 'Oggi · ${status}';
	@override String get editHabit => 'Modifica abitudine';
	@override String get newHabit => 'Nuova abitudine';
	@override String get optionalReminder => 'Promemoria opzionale';
	@override String get reminderHint => 'es. 08:30';
	@override String get close => 'Chiudi';
	@override String get statusDone => 'Completata';
	@override String get statusSkipped => 'Saltata';
	@override String get statusUnrecorded => 'Non registrata';
	@override String weekOf({required Object day, required Object month}) => 'Settimana del ${day} ${month}';
	@override String get lifeWeeks => 'Settimane del tuo percorso';
	@override String get catMindfulness => 'Mindfulness';
	@override String get editableHint => 'Puoi modificare solo oggi e ieri.';
	@override String get titleRequired => 'Il titolo è obbligatorio';
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
	@override late final _Translations$ai$apiKey$it apiKey = _Translations$ai$apiKey$it._(_root);
	@override late final _Translations$ai$coachPrompts$it coachPrompts = _Translations$ai$coachPrompts$it._(_root);
	@override late final _Translations$ai$local$it local = _Translations$ai$local$it._(_root);
	@override late final _Translations$ai$standard$it standard = _Translations$ai$standard$it._(_root);
	@override late final _Translations$ai$consent$it consent = _Translations$ai$consent$it._(_root);
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
	@override String get newChatTooltip => 'Nuova chat';
	@override String get clearConfirmTitle => 'Iniziare una nuova chat?';
	@override String get clearConfirmBody => 'Questo cancella la conversazione attuale — non viene salvata.';
	@override String get clearConfirmCancel => 'Annulla';
	@override String get clearConfirmAccept => 'Nuova chat';
	@override String get copyTooltip => 'Copia';
	@override String get copiedToast => 'Copiato negli appunti';
	@override String get linkOpenFailed => 'Impossibile aprire il link.';
}

// Path: settingsPage
class _Translations$settingsPage$it extends Translations$settingsPage$en {
	_Translations$settingsPage$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get aboutCopied => 'Dettagli della versione copiati';
	@override String get aboutCopyTooltip => 'Copia i dettagli della versione';
	@override String aboutVersion({required Object version, required Object build}) => 'Versione ${version} (${build})';
	@override String get accentColor => 'Colore accento';
	@override String get accentColorDetail => 'Palette estesa riservata a Evolve Pro.';
	@override String get accessProtection => 'Protezione accesso';
	@override String get account => 'Account';
	@override String get accountAndOnboarding => 'Account e onboarding';
	@override String get accountDataManagementContent => 'Scegli se eliminare i dati mantenendo attivo l account oppure cancellare definitivamente l account.';
	@override String get accountDataManagementTitle => 'Gestione account e dati';
	@override String get accountDeleted => 'Account eliminato.';
	@override String get accountPaneSubtitle => 'Con quale account hai effettuato l\'accesso e dove risiedono i tuoi dati.';
	@override String get accountSyncOn => 'Attiva — tramite il tuo account';
	@override String get activateEvolveProStart => 'Abbonati con il tuo account Apple.';
	@override String get advancedPaneSubtitle => 'Impostazioni avanzate e diagnostica.';
	@override String get aiAndSystem => 'AI & SISTEMA';
	@override String get aiInsights => 'Insight AI';
	@override String get aiInsightsDetail => 'Analisi e consigli personalizzati dall\'AI.';
	@override String get aiSuggestions => 'Suggerimenti AI';
	@override String get aiSuggestionsDetail => 'Analisi intelligente delle abitudini';
	@override String get appLogsDetail => 'Visualizza i log diagnostici di questa sessione';
	@override String get appLogsTitle => 'Log dell\'app';
	@override String get appearanceAndVisual => 'Aspetto e visual';
	@override String get appearanceSubtitle => 'Preferenze locali adattate al desktop';
	@override String get appearanceTitle => 'Aspetto e applicazione';
	@override String get applyAction => 'Applica';
	@override String get availableWithActiveSession => 'Disponibile con una sessione Supabase attiva';
	@override String get avatarGateTitle => 'Avatar';
	@override String get avatarPickFailed => 'Selezione immagine non riuscita.';
	@override String get bestValue => 'Miglior valore';
	@override String get billingAppleDetail => 'Il tuo abbonamento viene acquistato e gestito con il tuo account Apple.';
	@override String get billingAppleTitle => 'Fatturato tramite Apple';
	@override String get billingPlatformUnsupported => 'Gli acquisti in-app non sono disponibili su questa piattaforma.';
	@override String get billingUnavailableDetail => 'Gli abbonamenti non sono momentaneamente disponibili. Riprova più tardi.';
	@override String get biometricActivationCancelled => 'Attivazione annullata.';
	@override String get biometricLock => 'Blocco biometrico';
	@override String get biometricLockDetail => 'Disponibile con adapter nativo su macOS e Windows; non supportato su Linux.';
	@override String get calendarExperienceLanguage => 'Calendario, esperienza e lingua';
	@override late final _Translations$settingsPage$calendarViewOptions$it calendarViewOptions = _Translations$settingsPage$calendarViewOptions$it._(_root);
	@override String get cancel => 'Annulla';
	@override String get changePassword => 'Cambia password';
	@override String get changePasswordDetail => 'Aggiornamento credenziali tramite Supabase Auth.';
	@override String get commercialChannelRequired => 'Acquisti non disponibili';
	@override String get confirm => 'Conferma';
	@override String get confirmDeleteAccountMessage => 'L account e tutti i dati associati verranno eliminati definitivamente. Questa azione e irreversibile.';
	@override String get confirmDeleteAccountTitle => 'Conferma eliminazione account';
	@override String get confirmNewPassword => 'Conferma nuova password';
	@override String get confirmResetDataMessage => 'Verranno eliminate abitudini, obiettivi e preferenze. L account restera attivo. Questa azione non puo essere annullata.';
	@override String get confirmResetDataTitle => 'Conferma reset dati';
	@override String get confirmSignOutMessage => 'Sei sicuro di voler uscire? Dovrai reinserire le credenziali per accedere nuovamente.';
	@override String get confirmSignOutTitle => 'Conferma uscita';
	@override String get currentPassword => 'Password attuale';
	@override String get customColor => 'Colore personalizzato';
	@override String get dataAndConsents => 'Dati e consensi';
	@override String get dataBackupPaneSubtitle => 'Dove vengono copiati i tuoi dati, come importarli ed esportarli e come cancellarli.';
	@override String get dataRepository => 'Repository dati';
	@override String get dataStorage => 'Archiviazione dei dati';
	@override String get dataStorageAccount => 'Il tuo account Evolve';
	@override String get dataStorageThisMac => 'Solo su questo Mac, cifrati';
	@override String get dateOfBirth => 'Data di nascita';
	@override String get dateOfBirthHint => 'AAAA-MM-GG';
	@override String get deepWorkInsights => 'Deep Work Insights';
	@override String get deepWorkInsightsDetail => 'Analisi avanzata delle tue sessioni di concentrazione.';
	@override String get defaultCalendarView => 'Vista calendario predefinita';
	@override String get deleteAccountAction => 'Elimina account';
	@override String get deleteAccountAndData => 'Elimina account e dati';
	@override String get deleteAccountAndDataDetail => 'Operazione irreversibile protetta da conferma.';
	@override String get deleteAccountGateTitle => 'Elimina account';
	@override String get deletePrivateData => 'Elimina dati privati';
	@override String get deletePrivateDataDetail => 'Cancella definitivamente il database locale crittografato.';
	@override String get detailsHeader => 'DETTAGLI ABBONAMENTO';
	@override String get disabledTurnOnFirst => 'Attiva il promemoria per impostare un orario.';
	@override String get email => 'Email';
	@override String get encryptedLocalDatabase => 'Database locale crittografato';
	@override String get enterCurrentPassword => 'Inserisci la password attuale.';
	@override String get eveningReview => 'Review serale';
	@override String get eveningReviewDetail => 'Ricorda di consolidare la giornata.';
	@override String get eveningReviewTime => 'Orario review serale';
	@override String get expiresOn => 'Scade Il';
	@override String get exportData => 'Esporta dati';
	@override String get exportDataDetail => 'Condivide un export JSON completo dei dati disponibili.';
	@override String get exportDoneClipboard => 'Il JSON e negli appunti: Linux non supporta la condivisione file.';
	@override String get exportDoneSaved => 'Il file JSON è stato salvato nella posizione scelta.';
	@override String get exportDoneShare => 'Il JSON e stato inviato al selettore di condivisione.';
	@override String get exportDoneTitle => 'Export completato';
	@override String get exportPrivateShareText => 'I miei dati privati esportati da Evolve';
	@override String get exportShareText => 'I miei dati esportati da Evolve';
	@override String get focusMode => 'Modalità Focus';
	@override String get focusModeDetail => 'Sospende tutti i promemoria e le notifiche.';
	@override String get focusModeOnBody => 'Questi promemoria sono in pausa finché non la disattivi.';
	@override String get focusModeOnTitle => 'Concentrazione attiva';
	@override String get fullName => 'Nome completo';
	@override String get gateChangePassword => 'Cambio password';
	@override String get gateLogout => 'Logout';
	@override String get gateProfile => 'Profilo';
	@override String get gateRequiresActiveSession => 'Richiede una sessione Supabase attiva.';
	@override String get generalPaneSubtitle => 'Aspetto e lingua di Evolve.';
	@override String get goToLogin => 'Vai al Login';
	@override String get goToLoginDetail => 'Sospendi la modalità privata e accedi a Supabase.';
	@override String get groupAppLock => 'Blocco app';
	@override String get groupAppearance => 'Aspetto';
	@override String get groupBackups => 'Backup';
	@override String get groupDailyReminders => 'Promemoria giornalieri';
	@override String get groupDataStorage => 'Archiviazione dei dati';
	@override String get groupDelivery => 'Consegna';
	@override String get groupDiagnostics => 'Diagnostica';
	@override String get groupDiagnosticsConsent => 'Diagnostica e consensi';
	@override String get groupFocus => 'Concentrazione';
	@override String get groupGettingStarted => 'Per iniziare';
	@override String get groupLanguageFormats => 'Lingua e formati';
	@override String get groupLegal => 'Note legali';
	@override String get groupSignIn => 'Accesso';
	@override String get habitReminders => 'Promemoria abitudini';
	@override String get habitRemindersDetail => 'Invia il morning briefing giornaliero.';
	@override String get hapticFeedback => 'Feedback aptico';
	@override String get hapticFeedbackDetail => 'Il desktop conserva la preferenza ma non genera vibrazioni.';
	@override String importCategoriesCount({required Object count}) => '${count} Categorie';
	@override String get importCompletedTitle => 'Importazione completata';
	@override String get importConfirmButton => 'Conferma Importazione';
	@override String get importData => 'Importa dati';
	@override String get importDataDetail => 'Ripristina un backup (JSON o ZIP) di Evolve.';
	@override String get importDataGateTitle => 'Importa dati';
	@override String get importEntityCategories => 'Categorie';
	@override String get importEntityHabits => 'Abitudini';
	@override String get importEntityLogs => 'Log abitudini';
	@override String get importEntityMacroGoals => 'Macro obiettivi';
	@override String get importEntityMoods => 'Registri umore';
	@override String importError({required Object error}) => 'Errore durante importazione: ${error}';
	@override String importHabitsCount({required Object count}) => '${count} Abitudini';
	@override String get importInProgress => 'Importazione in corso...';
	@override String get importLockedMessage => 'Questo dispositivo non riesce a sbloccare il database privato locale: la sua chiave di crittografia è mancante (succede dopo il passaggio a un nuovo Mac o una modifica alla firma dell\'app). I dati locali esistenti non sono recuperabili, ma puoi ripristinarli e importare questo backup su un database nuovo e vuoto. L\'operazione non può essere annullata.';
	@override String get importLockedResetButton => 'Ripristina e importa';
	@override String get importLockedTitle => 'Ripristinare il database privato bloccato?';
	@override String importLogsCount({required Object count}) => '${count} Check-in (Log)';
	@override String importMacroGoalsCount({required Object count}) => '${count} Obiettivi Macro';
	@override String get importMergeSubtitle => 'Combina con i tuoi dati, mantenendo la versione più recente di ogni elemento.';
	@override String get importMergeTitle => 'Unisci ai dati attuali';
	@override String importMoodsCount({required Object count}) => '${count} Registrazioni Umore';
	@override String importPreviewSkipped({required Object count}) => '⚠ ${count} record non validi verranno ignorati';
	@override String get importPrivateOnly => 'La funzione di importazione è attualmente disponibile solo in Modalità Privata (Locale).';
	@override String get importReplaceConfirmButton => 'Elimina e sostituisci';
	@override String importReplaceConfirmMessage({required Object count}) => 'Questa operazione elimina definitivamente i tuoi dati attuali (circa ${count} registrazioni) e mantiene solo ciò che è in questo backup. Non è reversibile.';
	@override String get importReplaceConfirmTitle => 'Sostituire tutti i dati?';
	@override String get importReplaceSubtitle => 'Elimina definitivamente ogni record esistente che non è in questo backup.';
	@override String get importReplaceTitle => 'Sostituisci i dati attuali';
	@override String importRowMerge({required Object label, required Object added, required Object updated, required Object unchanged}) => '${label}: ${added} aggiunti, ${updated} aggiornati, ${unchanged} invariati';
	@override String importRowReplace({required Object count, required Object label}) => '${count} ${label}';
	@override String importRowSkipped({required Object count}) => ', ${count} ignorati';
	@override String get importSuccess => 'Importazione completata con successo!';
	@override String get importSummaryDone => 'Fantastico!';
	@override String get importSummaryMerged => 'I tuoi dati sono stati uniti al backup. Riepilogo:';
	@override String get importSummaryReplaced => 'I tuoi dati sono stati sostituiti con il backup. Riepilogo:';
	@override String get importSummaryTitle => 'Riepilogo Importazione';
	@override String get insightsAndReports => 'Insight e resoconti';
	@override String get language => 'Lingua';
	@override late final _Translations$settingsPage$languageOptions$it languageOptions = _Translations$settingsPage$languageOptions$it._(_root);
	@override String get manageSubscription => 'Gestisci abbonamento';
	@override String get manageSubscriptionDetail => 'Apre la gestione abbonamenti dell account Apple.';
	@override String get milestones => 'Milestones';
	@override String get milestonesDetail => 'Celebrazioni al raggiungimento dei traguardi chiave.';
	@override String get morningBriefTime => 'Orario morning brief';
	@override String get nativeDeliveryTitle => 'Delivery nativo per sistema operativo';
	@override String get newPassword => 'Nuova password';
	@override String get newPasswordMinLength => 'La nuova password deve avere almeno 8 caratteri.';
	@override String get nextRenewal => 'Prossimo Rinnovo';
	@override String get notAuthenticated => 'Non autenticato';
	@override String get notificationPermissionsDenied => 'Permesso non concesso. Puoi modificarlo dalle impostazioni di sistema.';
	@override String get notificationPermissionsGranted => 'Permessi disponibili per questo sistema.';
	@override String get notificationPermissionsTitle => 'Permessi notifiche';
	@override String get notifications => 'Notifiche';
	@override String get notificationsPaneSubtitle => 'Tutto ciò che può interromperti.';
	@override String get notificationsSubtitle => 'Promemoria operativi del client desktop';
	@override String get operationFailed => 'Operazione non riuscita.';
	@override String get operationalReminders => 'Promemoria operativi';
	@override String get pageSubtitle => 'Gestisci profilo, comportamento desktop, privacy e piano Evolve.';
	@override String get pageTitle => 'Impostazioni';
	@override String get passwordUpdateFailed => 'Aggiornamento non riuscito. Verifica la password attuale.';
	@override String get passwordsDontMatch => 'Le password non coincidono.';
	@override String get paymentMethod => 'Metodo di Pagamento';
	@override String get paymentMethodValue => 'Apple Pay / App Store';
	@override String get perHabitRemindersNote => 'I promemoria delle singole abitudini si impostano su ciascuna abitudine e non dipendono da questi interruttori.';
	@override String perMonth({required Object price}) => '${price} al mese';
	@override String perMonthWithSavings({required Object price, required Object percent}) => '${price} al mese · Risparmi il ${percent}%';
	@override String get personalInfo => 'Informazioni personali';
	@override String get personalInfoDetail => 'Nome, cognome, email e data di nascita';
	@override String get planAnnual => 'Annuale';
	@override String get planLabel => 'Piano';
	@override String get planManagement => 'Gestione piano';
	@override String get planMonthly => 'Mensile';
	@override String get priceUnavailable => 'Prezzo non disponibile';
	@override String get privacyPaneSubtitle => 'Cosa può vedere Evolve e chi altro può aprirlo.';
	@override String get privacyPolicy => 'Privacy Policy';
	@override String get privacySubtitle => 'Protezione accesso, consensi e gestione dati';
	@override String get privacyTitle => 'Privacy e sicurezza';
	@override String get privateMode => 'Modalità Privata';
	@override String get privateModeDataProtected => 'I tuoi dati sono protetti e salvati unicamente su questo dispositivo.';
	@override String get proActiveMessage => 'La tua iscrizione è attiva. L\'AI Coach è incluso — senza account OpenRouter né chiave API — insieme alle statistiche avanzate dei trend e a tutti gli strumenti di crescita personale di Evolve.';
	@override String get proActiveName => 'Evolve Pro Attivo';
	@override String get proName => 'Evolve Pro';
	@override String get proStartJourney => 'Inizia il tuo Percorso';
	@override String get proSubtitle => 'Piano, ripristino acquisti e gestione abbonamento';
	@override String get proThankYou => 'Grazie per sostenere lo sviluppo di Evolve.';
	@override String get proTitle => 'Evolve Pro';
	@override String get proUpsellSubtitle => 'Sblocca tutte le funzionalità e accelera la tua crescita.';
	@override String get proUpsellTitle => 'Passa a Evolve Pro';
	@override String get proWelcomeTitle => 'Benvenuto in Evolve Pro!';
	@override String get profileFallback => 'Profilo';
	@override String get profileLabel => 'Profilo';
	@override String get profileSubtitle => 'Informazioni personali e stato sincronizzazione';
	@override String get railGroupApp => 'App';
	@override String get railGroupData => 'Dati';
	@override String get railGroupYou => 'Tu';
	@override String get renewalDisclaimer => 'L\'abbonamento si rinnova automaticamente a meno che l\'autorinnovamento non venga disattivato nelle impostazioni dell\'account Apple almeno 24 ore prima della scadenza.';
	@override String get requestNotificationPermissions => 'Richiedi permessi notifiche';
	@override String get requestNotificationPermissionsDetail => 'Apre il prompt nativo sul target supportato.';
	@override String get resetDataAction => 'Resetta i dati';
	@override String get resetDataSuccess => 'Dati eliminati con successo.';
	@override String get resetDataTitle => 'Reset dati';
	@override String get resetTutorial => 'Ripristina tutorial';
	@override String get resetTutorialDetail => 'Riapre i walkthrough di dashboard e obiettivi.';
	@override String get restoreDefaults => 'Ripristina le impostazioni predefinite…';
	@override String get restoreDefaultsDetail => 'Le tue abitudini, i tuoi obiettivi, l\'account e il blocco app non vengono toccati.';
	@override String get restorePurchases => 'Ripristina acquisti';
	@override String get restorePurchasesDetail => 'Ripristina un abbonamento già acquistato.';
	@override String get reviewInitialConsent => 'Rivedi consenso iniziale';
	@override String get reviewInitialConsentDetail => 'Termini, privacy, notifiche e crash reporting';
	@override String get save => 'Salva';
	@override String get searchClear => 'Cancella la ricerca';
	@override String get searchNoResults => 'Nessuna impostazione corrisponde';
	@override String get searchPlaceholder => 'Cerca nelle impostazioni';
	@override String get sectionAccount => 'Account';
	@override String get sectionAdvanced => 'Avanzate';
	@override String get sectionApplication => 'Applicazione';
	@override String get sectionDataBackup => 'Dati e backup';
	@override String get sectionGeneral => 'Generale';
	@override String get sectionPrivacy => 'Privacy';
	@override String get sectionPrivacySecurity => 'Privacy e sicurezza';
	@override String get sendCrashReports => 'Invia segnalazioni crash';
	@override String get sendCrashReportsDetail => 'Consenso separato per Sentry.';
	@override String get sessionUnavailable => 'Sessione non disponibile';
	@override String get settingSaveFailed => 'Impossibile salvare l\'impostazione. È stata ripristinata al valore precedente.';
	@override String get signOut => 'Esci dall\'account';
	@override String get signOutDetailActive => 'Chiudi la sessione su questo dispositivo';
	@override String get statusActive => 'Attivo';
	@override String get statusLabel => 'Stato';
	@override String subscribeCta({required Object plan, required Object price}) => 'Abbonati — ${plan} · ${price}';
	@override String subscribeCtaNoPrice({required Object plan}) => 'Abbonati — ${plan}';
	@override String get subscription => 'Abbonamento';
	@override String get supabaseWithEncryptedCache => 'Supabase con cache cifrata';
	@override String get syncsToIPhoneNote => 'Queste impostazioni valgono anche sul tuo iPhone.';
	@override String get systemPermissionsManagement => 'Gestione permessi di sistema';
	@override String get systemPermissionsManagementDetail => 'Notifiche, calendario e sicurezza.';
	@override String get systemPermissionsOpenFailed => 'Impossibile aprire le impostazioni.';
	@override String get systemPermissionsTitle => 'Permessi di sistema';
	@override String get systemSection => 'Sistema';
	@override String get termsEula => 'Termini d\'Uso (EULA)';
	@override String get themeDark => 'Scuro';
	@override String get themeLight => 'Chiaro';
	@override String get themeMode => 'Tema';
	@override String get themeSystem => 'Segui il sistema';
	@override String get timeFormat24h => 'Formato 24h';
	@override String get timeFormat24hDetail => 'Usa orari come 20:30 invece di 8:30 PM.';
	@override String get tutorialResetMessage => 'Le guide verranno mostrate nuovamente nelle relative sezioni.';
	@override String get tutorialResetTitle => 'Tutorial ripristinati';
	@override String get updateAvatar => 'Aggiorna avatar';
	@override String get updateAvatarDetail => 'Scegli un immagine locale per il profilo desktop.';
	@override String get updatePassword => 'Aggiorna password';
	@override String useAccent({required Object hex}) => 'Usa accento ${hex}';
	@override String get verified => 'Verificato';
	@override String get weeklyReports => 'Resoconti Settimanali';
	@override String get weeklyReportsDetail => 'Un riepilogo settimanale dei tuoi progressi.';
	@override String get youArePro => 'Sei un utente Pro!';
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
	@override String get subtitle => 'Evolve carica i tuoi dati personali su un server solo dopo il tuo consenso qui.';
	@override String get uploadTitle => 'Cosa esce da questo Mac';
	@override String get uploadAccountTitle => 'Con un account Evolve';
	@override String get uploadAccountBody => 'obiettivi, abitudini, check-in dell\'umore, le impostazioni dell\'app e il profilo (nome, email, data di nascita) vengono caricati sui server di Evolve per sincronizzare i tuoi dispositivi. La foto del profilo resta su questo Mac.';
	@override String get uploadPrivateTitle => 'In privato su questo Mac';
	@override String get uploadPrivateBody => 'non ci viene caricato nulla; la sincronizzazione iCloud facoltativa è cifrata end-to-end e raggiunge solo il tuo account iCloud.';
	@override String get uploadNeverTitle => 'Mai consultati';
	@override String get uploadNeverBody => 'contatti, calendario, fotocamera, microfono, posizione.';
	@override String get acceptTerms => 'Accetto termini e privacy policy';
	@override String get termsSubtitle => 'Ho letto i documenti, ho almeno 14 anni e acconsento al caricamento descritto sopra.';
	@override String get crashDiagnostics => 'Diagnostica crash';
	@override String get crashSubtitle => 'Disattivata per impostazione predefinita. Se attiva, invia segnalazioni anonimizzate di crash al nostro fornitore di diagnostica, Sentry.';
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
	@override String get limitReminderBody => 'Stai rimanendo entro il tuo limite oggi? Fai un controllo quando puoi.';
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
	@override String get loadOffersFailed => 'Impossibile caricare i piani di abbonamento. Controlla la connessione e riprova.';
	@override String get proActivated => 'Evolve Pro attivato.';
	@override String get purchasesRestored => 'Acquisti ripristinati.';
	@override String get noActiveSub => 'Nessun abbonamento Pro attivo trovato.';
	@override String get restoreFailed => 'Ripristino acquisti non riuscito.';
	@override String get configKey => 'Gli acquisti in-app non sono momentaneamente disponibili.';
	@override String get loginFirst => 'Accedi prima di gestire Evolve Pro.';
	@override String get paidAppsAgreement => 'Contratto Paid Apps non attivo. L\'Account Holder deve accettare l\'accordo Paid Apps in App Store Connect.';
	@override String get alreadyPurchased => 'Questo abbonamento risulta già acquistato. Usa Ripristina acquisti per riattivare l\'accesso Pro.';
	@override String get purchasesNotAllowed => 'Gli acquisti in-app non sono consentiti su questo dispositivo o account Apple.';
	@override String get planUnavailable => 'Il piano selezionato non è disponibile per l\'acquisto. Riprova più tardi.';
	@override String get paymentPending => 'Il pagamento è in sospeso. L\'accesso Pro verrà attivato quando Apple confermerà la transazione.';
	@override String get connectionUnavailable => 'Connessione non disponibile. Controlla la rete e riprova.';
	@override String get linkedToAnotherAccount => 'Questo acquisto è già collegato a un altro account Evolve. Accedi con quell\'account o contatta il supporto.';
	@override String get purchaseInProgress => 'Un\'operazione di acquisto è già in corso. Attendi qualche secondo.';
	@override String get restoreInProgress => 'Un ripristino è già in corso. Attendi qualche secondo.';
	@override String get purchaseFailedMessage => 'Non siamo riusciti a completare l\'acquisto. Riprova tra poco.';
	@override String get restoreFailedMessage => 'Non siamo riusciti a ripristinare gli acquisti. Riprova tra poco.';
	@override String get purchaseRegisteredNotActive => 'L\'acquisto è registrato, ma l\'abbonamento Pro non risulta ancora attivo. Attendi qualche secondo e usa Ripristina acquisti.';
	@override String get noActiveSubscription => 'Nessun abbonamento Evolve Pro attivo è stato trovato su questo Apple ID. Assicurati di usare lo stesso Apple ID dell\'acquisto.';
	@override String get invalidConfig => 'Configurazione degli acquisti non valida. Riprova più tardi o contatta l\'assistenza.';
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
	@override String get aiCoachTitle => 'AI Coach, senza configurazione';
	@override String get aiCoachDesc => 'Lo eseguiamo noi con la nostra chiave: nessuna chiave API da recuperare, nessun secondo account. Preferisci il tuo account OpenRouter? È gratis anche così.';
	@override String get statsTitle => 'Statistiche Specifiche Per Abitudine';
	@override String get statsDesc => 'Informazioni chiave per aumentare la tua produttività.';
	@override String get metricsTitle => 'Metriche Avanzate Obiettivi';
	@override String get metricsDesc => 'Visualizza grafici dettagliati e statistiche di performance profonde per ogni anno.';
	@override String get unlimitedTitle => 'Abitudini Illimitate';
	@override String get unlimitedDesc => 'Crea e traccia tutti gli habits che desideri senza alcun limite.';
	@override String get maybeLater => 'Forse più tardi';
	@override String get viewPlans => 'Vedi i piani Pro';
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
	@override String get detailExtras => 'Contesto aggiuntivo';
	@override String get detailStackTrace => 'STACK TRACE';
	@override String get shareLogs => 'Condividi file dei log';
	@override String get exportDone => 'Log esportati';
}

// Path: coachSettings
class _Translations$coachSettings$it extends Translations$coachSettings$en {
	_Translations$coachSettings$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get accountModeNote => 'Preferisci la tua chiave OpenRouter o un modello locale? Sono disponibili nella modalità Privata.';
	@override String activeCloud({required Object model}) => 'Cloud · ${model}';
	@override String activeLocal({required Object model}) => 'Locale · ${model}';
	@override String get activeLocalNoModel => 'Locale · scegli un modello';
	@override String activeStandard({required Object model}) => 'Evolve AI · ${model}';
	@override String get backendStandard => 'Evolve AI';
	@override String get baseUrlLabel => 'URL di base';
	@override String get cardLive => 'Attivo';
	@override String get cardOff => 'Spento';
	@override String get cloudKeyMissing => 'Nessuna chiave — questo motore non risponderà. Collega qui sotto il tuo account OpenRouter, passa a Evolve AI oppure usa un server locale.';
	@override String get detectedAction => 'Usa locale';
	@override String detectedBody({required Object app}) => '${app} è in esecuzione su questo Mac. Vuoi usare il coach in modo 100% privato?';
	@override String get detectedDismiss => 'Non ora';
	@override String detectedTitle({required Object app}) => '${app} rilevato';
	@override String get discovering => 'Ricerca dei modelli…';
	@override String get engineOpenRouter => 'OpenRouter';
	@override String get engineOpenRouterHint => 'La tua chiave · gratis';
	@override String getLocalServer({required Object app}) => 'Ottieni ${app}';
	@override String get groupEngine => 'Motore';
	@override String get groupPrivacy => 'Privacy';
	@override String get groupTuning => 'Regolazione AI Coach';
	@override String get lmStudioNoModelsJit => 'LM Studio non elenca alcun modello. Quando il caricamento Just-In-Time è disattivato, elenca solo i modelli già caricati — carica un modello in LM Studio, oppure attiva Developer → Server Settings → Just In Time Model Loading.';
	@override String get lmStudioServerOffBody => 'LM Studio è aperto, ma il suo server locale è spento. Attivalo con Developer → Start Server, oppure spunta Settings → Run the LLM server on login.';
	@override String get lmStudioServerOffTitle => 'Il server di LM Studio non è in esecuzione';
	@override String get lmStudioStartTimeout => 'Sta impiegando più tempo del previsto — apri LM Studio e controlla che abbia terminato l\'avvio.';
	@override String get localGroupLabel => 'Locale — su questo Mac';
	@override String localServerDownloadFailed({required Object url}) => 'Impossibile aprire il browser — visita ${url}';
	@override String localServerNotInstalledBody({required Object app}) => 'Installa l\'app gratuita ${app}, poi premi Avvia.';
	@override String localServerNotInstalledTitle({required Object app}) => '${app} non è installato';
	@override String get localServerOfflineBody => 'Avvia il server locale per chattare in privato — senza terminale.';
	@override String localServerOfflineTitle({required Object app}) => '${app} non è in esecuzione';
	@override String localServerStartFailed({required Object app}) => 'Impossibile avviare ${app} — prova ad aprirlo dalla cartella Applicazioni.';
	@override String get localServerStartingBody => 'Può richiedere qualche secondo…';
	@override String get manualModelAdd => 'Usa questo modello';
	@override String get manualModelLabel => 'Id modello';
	@override String get modelLabel => 'Modello';
	@override String get noModelsFound => 'Nessun modello trovato — inserisci manualmente un id modello qui sotto.';
	@override String get ollamaServerOffBody => 'Ollama è aperto, ma non risponde sulla sua porta. Chiudilo dalla barra dei menu, poi premi di nuovo Avvia.';
	@override String get ollamaServerOffTitle => 'Ollama è avviato ma non è in ascolto';
	@override String get ollamaStartTimeout => 'Sta impiegando più tempo del previsto — controlla l\'icona di Ollama nella barra dei menu (il primo avvio potrebbe richiedere un\'autorizzazione).';
	@override String get presetLmStudio => 'LM Studio';
	@override String get presetOllama => 'Ollama';
	@override String get refreshModels => 'Aggiorna modelli';
	@override String get remoteBadge => 'Remoto';
	@override String get remoteWarning => 'Questo endpoint non è un indirizzo locale — i messaggi lasceranno questo dispositivo.';
	@override String get sendMessage => 'Invia';
	@override String get settingsRowConfigure => 'Motore e server locale';
	@override String get settingsRowStatus => 'Motore attivo';
	@override String get settingsSectionLabel => 'AI Coach';
	@override String get settingsSubtitle => 'Scegli il motore che alimenta il coach e collegalo a un server locale per la massima privacy.';
	@override String get standardNeedsProNote => 'Evolve AI fa parte di Evolve Pro. Abbonati per sbloccarlo.';
	@override String get standardNeedsSignInNote => 'Accedi per usare Evolve AI. L\'abbonamento lo sblocca su ogni dispositivo.';
	@override String get standardPrivateNote => 'Evolve AI richiede un account Evolve, e la modalità Privata non ne conserva uno. Collega il tuo account OpenRouter oppure usa un modello locale: qui funzionano entrambi.';
	@override String get standardStatusNeedsPro => 'Richiede Pro';
	@override String get standardStatusNeedsSignIn => 'Accesso richiesto';
	@override String get standardStatusReady => 'Incluso in Pro';
	@override String get standardStatusUnavailable => 'Non disponibile';
	@override String get standardUnavailableNote => 'Evolve AI non è disponibile in questa build. Collega il tuo account OpenRouter oppure usa un modello locale.';
	@override String startLocalServer({required Object app}) => 'Avvia ${app}';
	@override String startingLocalServer({required Object app}) => 'Avvio di ${app}…';
	@override String get statusChecking => 'Verifica…';
	@override String get statusConnected => 'Connesso';
	@override String get statusOffline => 'Server offline';
	@override String get stopResponse => 'Ferma';
	@override String get systemPromptHint => 'Sostituisci la persona del coach (lascia vuoto per quella predefinita)';
	@override String get systemPromptLabel => 'Prompt di sistema';
	@override String get systemPromptReset => 'Ripristina';
	@override String get temperatureLabel => 'Temperatura';
	@override String get temperatureLower => 'Riduci la temperatura';
	@override String get temperatureRaise => 'Aumenta la temperatura';
	@override String get tuningFootnote => 'Valgono per ogni motore, incluso Evolve AI.';
	@override String get useCustomServer => 'Usa un server personalizzato…';
}

// Path: tour
class _Translations$tour$it extends Translations$tour$en {
	_Translations$tour$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get back => 'Indietro';
	@override String get next => 'Avanti';
	@override String get continueLabel => 'Continua';
	@override String get finish => 'Fine';
	@override String get welcomeTitle => 'Benvenuto in Evolve';
	@override String get welcomeBody => 'Facciamo un rapido tour del tuo spazio di lavoro — dalla panoramica quotidiana fino al tuo AI coach. Bastano pochi istanti.';
	@override String get welcomeStart => 'Inizia il tour';
	@override String get welcomeSkip => 'Salta tutorial';
	@override String get doneTitle => 'Tutto pronto';
	@override String get doneBody => 'Questa è tutta l\'app. Parti da dove vuoi dalla barra laterale — e puoi rivedere il tour quando vuoi dalle Impostazioni.';
	@override String get doneButton => 'Inizia';
	@override String get overviewOrientationTitle => 'La tua Panoramica';
	@override String get overviewOrientationDesc => 'È la tua base quotidiana — un riepilogo della giornata appena apri Evolve.';
	@override String get overviewCheckinTitle => 'Check-in giornaliero';
	@override String get overviewCheckinDesc => 'Registra come sta andando la giornata. Col tempo mostra come il tuo umore si lega ad abitudini e obiettivi.';
	@override String get overviewHabitsTitle => 'Abitudini di oggi';
	@override String get overviewHabitsDesc => 'Le abitudini che hai pianificato per oggi sono qui — spuntale man mano.';
	@override String get overviewGoalsTitle => 'Obiettivi in focus';
	@override String get overviewGoalsDesc => 'Gli obiettivi su cui ti stai concentrando compaiono qui, così non ti sfugge nulla.';
	@override String get habitsOrientationTitle => 'La pagina Abitudini';
	@override String get habitsOrientationDesc => 'Qui costruisci il tuo protocollo quotidiano e monitori la tua costanza.';
	@override String get habitsAddTitle => 'Aggiungi un\'abitudine';
	@override String get habitsAddDesc => 'Crea una nuova abitudine qui — nome, categoria, colore e un promemoria opzionale.';
	@override String get habitsCheckoffTitle => 'Segnala come fatta';
	@override String get habitsCheckoffDesc => 'Spunta questa casella per completare un\'abitudine oggi. Basta questo per mantenere viva una serie.';
	@override String get habitsStreakTitle => 'Serie e cronologia';
	@override String get habitsStreakDesc => 'Guarda crescere la tua serie e vedi gli ultimi sette giorni a colpo d\'occhio.';
	@override String get habitsCalendarTitle => 'Vista Calendario';
	@override String get habitsCalendarDesc => 'Passa al Calendario per rivedere la cronologia per settimana, mese, anno — o tutta la vita.';
	@override String get insightsOrientationTitle => 'Le tue Statistiche';
	@override String get insightsOrientationDesc => 'Osserva l\'andamento di abitudini e obiettivi nel tempo e dove stai perdendo il ritmo.';
	@override String get insightsFilterTitle => 'Filtra per abitudine';
	@override String get insightsFilterDesc => 'Concentra le statistiche su una singola abitudine o mantieni la vista globale.';
	@override String get insightsTabsTitle => 'Sezioni statistiche';
	@override String get insightsTabsDesc => 'Passa tra le sezioni per tendenze, avvisi, progressi delle abitudini e umore.';
	@override String get goalsOrientationTitle => 'La pagina Obiettivi';
	@override String get goalsOrientationDesc => 'Imposta e monitora i tuoi obiettivi più grandi — ciò a cui puntano le tue abitudini quotidiane.';
	@override String get goalsPlanTitle => 'Tipo di pianificazione';
	@override String get goalsPlanDesc => 'Scegli come pianificare — giornaliera, settimanale o più lunga — in base a come pensi i tuoi obiettivi.';
	@override String get goalsAddTitle => 'Aggiungi un obiettivo';
	@override String get goalsAddDesc => 'Crea qui un nuovo obiettivo e dagli un traguardo da raggiungere.';
	@override String get goalsCheckTitle => 'Completa o manca';
	@override String get goalsCheckDesc => 'Segna un obiettivo come completato o mancato. Ogni esito alimenta le tue performance nel tempo.';
	@override String get goalsStatsTitle => 'Performance';
	@override String get goalsStatsDesc => 'Attiva le statistiche di performance per vedere come stai andando rispetto ai tuoi obiettivi.';
	@override String get coachOrientationTitle => 'Il tuo AI Coach';
	@override String get coachOrientationDesc => 'Consigli personalizzati basati sulle tue abitudini e obiettivi reali — qui sul tuo Mac.';
	@override String get coachModelTitle => 'Scegli il motore';
	@override String get coachModelDesc => 'Scegli il modello AI — il nostro cloud o un modello locale in esecuzione in privato sul tuo Mac. Anche le impostazioni del server sono qui.';
	@override String get coachContextTitle => 'Cosa vede il coach';
	@override String get coachContextDesc => 'Decidi se il coach può usare le tue abitudini e i tuoi obiettivi per personalizzare i consigli.';
	@override String get coachSuggestionsTitle => 'Spunti iniziali';
	@override String get coachSuggestionsDesc => 'Non sai da dove iniziare? Tocca uno di questi suggerimenti per partire.';
	@override String get coachInputTitle => 'Chiedi qualsiasi cosa';
	@override String get coachInputDesc => 'Scrivi qui la tua domanda e premi invia. Il tour finisce qui — buon Evolve!';
}

// Path: palette
class _Translations$palette$it extends Translations$palette$en {
	_Translations$palette$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get searchHint => 'Cerca obiettivi, abitudini, impostazioni, azioni…';
	@override String get groupSuggested => 'Suggeriti';
	@override String get groupThisWeek => 'Questa settimana';
	@override String get groupGoals => 'Obiettivi';
	@override String get groupHabits => 'Abitudini';
	@override String get groupActions => 'Azioni';
	@override String get groupSections => 'Vai a';
	@override String get groupSettings => 'Impostazioni';
	@override String get goToThisWeek => 'Vai a questa settimana';
	@override String get createGoalBlank => 'Crea obiettivo';
	@override String createGoal({required Object title}) => 'Crea obiettivo «${title}»';
	@override String createHabit({required Object title}) => 'Crea abitudine «${title}»';
	@override String goToPeriod({required Object period}) => 'Vai a ${period}';
	@override String get switchToDark => 'Passa al tema scuro';
	@override String get switchToLight => 'Passa al tema chiaro';
	@override String get manageCategories => 'Gestisci categorie obiettivi';
	@override String get replayTour => 'Rivedi il tour guidato';
	@override String noResults({required Object query}) => 'Nessun risultato per «${query}»';
	@override String get rowOpen => 'Apri';
	@override String get rowComplete => 'Segna come completato';
	@override String get rowReschedule => 'Riprogramma al periodo successivo';
	@override String get deleteGoalTitle => 'Eliminare l\'obiettivo?';
	@override String deleteGoalMessage({required Object title}) => '«${title}» verrà eliminato definitivamente.';
	@override String get deleteHabitTitle => 'Eliminare l\'abitudine?';
	@override String deleteHabitMessage({required Object title}) => '«${title}» verrà eliminata definitivamente.';
	@override String get footerNavigate => 'naviga';
	@override String get footerOpen => 'apri';
	@override String get footerMenu => 'menu';
	@override String get footerClose => 'chiudi';
}

// Path: targets
class _Translations$targets$it extends Translations$targets$en {
	_Translations$targets$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get sectionTitle => 'Obiettivo';
	@override String get none => 'Semplice';
	@override String get atLeastLabel => 'Raggiungi';
	@override String get atMostLabel => 'Resta sotto';
	@override late final _Translations$targets$presets$it presets = _Translations$targets$presets$it._(_root);
	@override late final _Translations$targets$units$it units = _Translations$targets$units$it._(_root);
	@override late final _Translations$targets$entry$it entry = _Translations$targets$entry$it._(_root);
	@override String get amountLabel => 'Raggiungi';
	@override String get amountLabelAtMost => 'Resta sotto';
	@override String get stepLabel => 'Passo';
	@override String stepHint({required Object step}) => 'Ogni + aggiunge ${step}';
	@override String rangeError({required Object min, required Object max}) => 'Inserisci un numero tra ${min} e ${max}';
	@override String get stepPositiveError => 'Il passo deve essere maggiore di 0';
	@override String get stepExceedsWarning => 'Un solo tocco supererebbe l\'intero obiettivo';
	@override String notDivisibleWarning({required Object amount, required Object below, required Object above}) => 'Non puoi arrivare esattamente a ${amount} — i tocchi raggiungono ${below} poi ${above}';
	@override String notDivisibleWarningNoBelow({required Object amount, required Object above}) => 'Non puoi arrivare esattamente a ${amount} — il primo tocco raggiunge ${above}';
	@override String tooManyTapsWarning({required Object taps}) => 'Servono ${taps} tocchi per completare un giorno';
	@override String get confirmTitle => 'Controlla il tuo obiettivo';
	@override String get confirmAdjust => 'Modifica';
	@override String get confirmSaveAnyway => 'Salva comunque';
}

// Path: trackingMode
class _Translations$trackingMode$it extends Translations$trackingMode$en {
	_Translations$trackingMode$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Come viene monitorata?';
	@override String get checkbox => 'Spunta';
	@override String get number => 'Numero';
	@override String get automatic => 'Automatica';
	@override String get automaticLocked => 'Verificata — modifica su iPhone';
}

// Path: verification.compound
class _Translations$verification$compound$it extends Translations$verification$compound$en {
	_Translations$verification$compound$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String summaryAll({required Object count}) => 'Tutte le ${count} condizioni';
	@override String summaryAny({required Object count}) => 'Almeno 1 di ${count} condizioni';
}

// Path: verification.templates
class _Translations$verification$templates$it extends Translations$verification$templates$en {
	_Translations$verification$templates$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get steps => 'Passi';
	@override String get exerciseMinutes => 'Minuti di attività';
	@override String get activeEnergy => 'Energia attiva';
	@override String get standHours => 'Ore in piedi';
	@override String get distance => 'Distanza';
	@override String get mindfulMinutes => 'Minuti di mindfulness';
	@override String get sleepHours => 'Ore di sonno';
	@override String get workout => 'Allenamento';
	@override String get screenTimeTotal => 'Utilizzo totale del dispositivo';
	@override String get screenTimeApps => 'Tempo nelle app scelte';
}

// Path: verification.units
class _Translations$verification$units$it extends Translations$verification$units$en {
	_Translations$verification$units$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get minutes => 'min';
	@override String get hours => 'h';
	@override String get kilocalories => 'kcal';
	@override String get kilometers => 'km';
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
	@override String get pick => 'Scegli';
	@override String get gotIt => 'Ho capito';
	@override String get done => 'Fatto';
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
	@override String get apiKeyMissingShort => '⚠️ L\'AI Coach ha bisogno della tua chiave API di OpenRouter. Aggiungila nelle Impostazioni per iniziare a chattare.';
	@override String get apiKeyInvalid => '⚠️ OpenRouter ha rifiutato questa chiave API. Controllala nelle Impostazioni o creane una nuova su openrouter.ai/keys.';
	@override String get defaultSystemPrompt => 'Sei il "Coach di Disciplina", un assistente virtuale focalizzato sull’aiutare la persona a mantenere la disciplina, raggiungere i propri obiettivi e costruire abitudini sane. Sii motivante ma concreto, diretto e pratico. Usa un tono professionale ma amichevole.';
	@override String communicationError({required Object code}) => '❌ Errore nella comunicazione con l’AI. (Codice: ${code})';
	@override String get connectionError => '❌ Errore di connessione. Assicurati di essere online e riprova.';
	@override String get connectionErrorShort => '❌ Errore di connessione.';
	@override String get connectionCheckTimeout => '❌ Errore: la verifica della connessione ha impiegato troppo tempo.';
	@override String get contextTooLong => '⚠️ Questa conversazione è diventata troppo lunga per il modello. Inizia una nuova chat (in alto a destra) per continuare.';
	@override String get noInternet => '❌ Errore: nessuna connessione a internet. Verifica la rete.';
	@override String get serverTimeout => '❌ Errore: il server sta impiegando troppo tempo a rispondere. Riprova.';
	@override String apiError({required Object code}) => '❌ Errore API: ${code} (verifica Sentry per i dettagli)';
}

// Path: ai.apiKey
class _Translations$ai$apiKey$it extends Translations$ai$apiKey$en {
	_Translations$ai$apiKey$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get rowTitle => 'Il tuo account OpenRouter';
	@override String get description => 'Preferisci far girare il coach sul tuo account? Collega una chiave OpenRouter e paghi direttamente il provider — nessun abbonamento Evolve richiesto. Creane una su openrouter.ai/keys: viene salvata nel portachiavi di questo dispositivo e inviata solo a OpenRouter.';
	@override String get fieldLabel => 'Chiave API';
	@override String get hint => 'sk-or-v1-…';
	@override String get save => 'Salva chiave';
	@override String get saved => 'Chiave API salvata';
	@override String get remove => 'Rimuovi chiave';
	@override String get removed => 'Chiave API rimossa';
	@override String get removeConfirmTitle => 'Rimuovere la chiave API?';
	@override String get removeConfirmBody => 'Questo motore smetterà di rispondere finché non colleghi di nuovo un account. Evolve AI e i modelli locali non sono interessati.';
	@override String get statusSet => 'Salvata';
	@override String get statusMissing => 'Non impostata';
	@override String get saveFailed => 'Impossibile salvare la chiave nel portachiavi. Riprova.';
	@override String get setupTitle => 'Collega il tuo account OpenRouter';
	@override String get setupBody => 'Questo motore funziona con il tuo account OpenRouter. Collegalo per iniziare a chattare — oppure passa a Evolve AI, incluso in Pro.';
	@override String get setupAction => 'Collega account';
}

// Path: ai.coachPrompts
class _Translations$ai$coachPrompts$it extends Translations$ai$coachPrompts$en {
	_Translations$ai$coachPrompts$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override late final _Translations$ai$coachPrompts$diagnoseWeakestHabit$it diagnoseWeakestHabit = _Translations$ai$coachPrompts$diagnoseWeakestHabit$it._(_root);
	@override late final _Translations$ai$coachPrompts$goalOnTrack$it goalOnTrack = _Translations$ai$coachPrompts$goalOnTrack$it._(_root);
	@override late final _Translations$ai$coachPrompts$weeklyReviewDown$it weeklyReviewDown = _Translations$ai$coachPrompts$weeklyReviewDown$it._(_root);
	@override late final _Translations$ai$coachPrompts$weeklyReviewUp$it weeklyReviewUp = _Translations$ai$coachPrompts$weeklyReviewUp$it._(_root);
	@override late final _Translations$ai$coachPrompts$protectStreak$it protectStreak = _Translations$ai$coachPrompts$protectStreak$it._(_root);
	@override late final _Translations$ai$coachPrompts$alignHabitsToGoal$it alignHabitsToGoal = _Translations$ai$coachPrompts$alignHabitsToGoal$it._(_root);
	@override late final _Translations$ai$coachPrompts$designHabitForGoal$it designHabitForGoal = _Translations$ai$coachPrompts$designHabitForGoal$it._(_root);
	@override late final _Translations$ai$coachPrompts$raiseTheBar$it raiseTheBar = _Translations$ai$coachPrompts$raiseTheBar$it._(_root);
	@override late final _Translations$ai$coachPrompts$firstStep$it firstStep = _Translations$ai$coachPrompts$firstStep$it._(_root);
	@override late final _Translations$ai$coachPrompts$whatCanYouHelp$it whatCanYouHelp = _Translations$ai$coachPrompts$whatCanYouHelp$it._(_root);
}

// Path: ai.local
class _Translations$ai$local$it extends Translations$ai$local$en {
	_Translations$ai$local$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String notReachable({required Object url}) => '❌ Server AI locale non raggiungibile su ${url}. Assicurati che Ollama o LM Studio sia in esecuzione.';
	@override String get modelMissing => '⚠️ Scegli prima un modello locale — apri il selettore in alto.';
	@override String requestFailed({required Object code}) => '❌ Errore del modello locale (codice: ${code}).';
	@override String get streamError => '❌ Connessione al modello locale non riuscita.';
	@override String get timeout => '❌ Il modello locale sta impiegando troppo tempo — potrebbe essere ancora in caricamento. Riprova.';
	@override String get modelNotFound => '❌ Quel modello non è disponibile sul server. Apri il selettore per sceglierne o caricarne uno.';
	@override String authRequired({required Object app}) => '❌ ${app} rifiuta la connessione — richiede un token API. Disattiva l\'autenticazione nelle impostazioni del suo server, oppure punta Evolve su un server che non lo richiede.';
	@override String get stillLoading => 'Il modello è ancora in caricamento — un avvio a freddo può richiedere un po\' di tempo.';
}

// Path: ai.standard
class _Translations$ai$standard$it extends Translations$ai$standard$en {
	_Translations$ai$standard$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get sessionExpired => '⚠️ La sessione è scaduta. Accedi di nuovo per continuare a usare Evolve AI.';
	@override String get needsPro => '⚠️ Evolve AI fa parte di Evolve Pro. Abbonati nelle Impostazioni — oppure passa al tuo account OpenRouter, che è gratis.';
	@override String get rateLimited => '⚠️ Hai raggiunto il limite di uso corretto di Evolve AI per ora. Riprova più tardi oppure passa al tuo account OpenRouter.';
	@override String get unavailable => '❌ Evolve AI non è disponibile in questo momento. È un problema nostro: riprova tra poco.';
}

// Path: ai.consent
class _Translations$ai$consent$it extends Translations$ai$consent$en {
	_Translations$ai$consent$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get allow => 'Consenti';
	@override String get byokBody => 'Per rispondere, l\'AI Coach invia il tuo messaggio, il tuo nome e il contesto che scegli di condividere a OpenRouter, Inc. usando il tuo account OpenRouter. OpenRouter lo instrada a un provider di modelli in base alle impostazioni del tuo account. Puoi revocare il consenso in qualsiasi momento dalle Impostazioni e tutto il resto di Evolve continua a funzionare.';
	@override String get byokTitle => 'Inviare i tuoi messaggi a OpenRouter?';
	@override String get consentStatusRevoked => 'Non consentito';
	@override String get consentStopSharing => 'Interrompi la condivisione…';
	@override String get decline => 'Non ora';
	@override String get privateNote => 'Il tuo database privato resta su questo dispositivo: esce solo ciò che invii in chat.';
	@override String get revokeAction => 'Interrompi condivisione';
	@override String get revokeBody => 'L\'AI Coach chiederà di nuovo il consenso prima di inviare qualcosa. Nient\'altro cambia.';
	@override String get revokeTitle => 'Interrompere la condivisione con l\'AI?';
	@override String get rowTitle => 'Condivisione dati con l\'AI';
	@override String get standardBody => 'Per rispondere, l\'AI Coach invia il tuo messaggio, il tuo nome e il contesto che scegli di condividere a OpenRouter, Inc., che li instrada a Google LLC (Google AI Studio) per eseguire il modello. Trattandosi del piano gratuito di Google, Google può conservare il testo per un periodo limitato e usarlo per migliorare i propri servizi — non è privato come un piano a pagamento. Puoi revocare il consenso in qualsiasi momento dalle Impostazioni e tutto il resto di Evolve continua a funzionare.';
	@override String get standardTitle => 'Inviare i tuoi messaggi all\'AI?';
	@override String get statusGranted => 'Consentita';
	@override String get statusNone => 'Non consentita';
}

// Path: settingsPage.calendarViewOptions
class _Translations$settingsPage$calendarViewOptions$it extends Translations$settingsPage$calendarViewOptions$en {
	_Translations$settingsPage$calendarViewOptions$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get month => 'Mese';
	@override String get week => 'Settimana';
	@override String get year => 'Anno';
	@override String get life => 'Vita';
}

// Path: settingsPage.languageOptions
class _Translations$settingsPage$languageOptions$it extends Translations$settingsPage$languageOptions$en {
	_Translations$settingsPage$languageOptions$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get system => 'Sistema';
	@override String get italian => 'Italiano';
	@override String get english => 'English';
	@override String get spanish => 'Spagnolo';
	@override String get german => 'Tedesco';
	@override String get arabic => 'العربية';
}

// Path: targets.presets
class _Translations$targets$presets$it extends Translations$targets$presets$en {
	_Translations$targets$presets$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override late final _Translations$targets$presets$countDaily$it countDaily = _Translations$targets$presets$countDaily$it._(_root);
	@override late final _Translations$targets$presets$durationDaily$it durationDaily = _Translations$targets$presets$durationDaily$it._(_root);
	@override late final _Translations$targets$presets$limitCountDaily$it limitCountDaily = _Translations$targets$presets$limitCountDaily$it._(_root);
	@override late final _Translations$targets$presets$limitDurationDaily$it limitDurationDaily = _Translations$targets$presets$limitDurationDaily$it._(_root);
}

// Path: targets.units
class _Translations$targets$units$it extends Translations$targets$units$en {
	_Translations$targets$units$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get min => 'min';
	@override String get hour => 'h';
	@override String get kcal => 'kcal';
	@override String get km => 'km';
}

// Path: targets.entry
class _Translations$targets$entry$it extends Translations$targets$entry$en {
	_Translations$targets$entry$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get keepGoing => 'Continua così';
	@override String get withinLimit => 'Entro il limite';
	@override String get overLimit => 'Oltre il limite';
}

// Path: ai.coachPrompts.diagnoseWeakestHabit
class _Translations$ai$coachPrompts$diagnoseWeakestHabit$it extends Translations$ai$coachPrompts$diagnoseWeakestHabit$en {
	_Translations$ai$coachPrompts$diagnoseWeakestHabit$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get label => '🩺 Sistema la mia abitudine più debole';
	@override String payload({required Object habit, required Object done, required Object scheduled}) => '\'${habit}\' è la mia abitudine più debole questa settimana — ${done}/${scheduled} giorni completati. Qual è il motivo più probabile per cui la salto, e due correzioni concrete che posso applicare questa settimana?';
}

// Path: ai.coachPrompts.goalOnTrack
class _Translations$ai$coachPrompts$goalOnTrack$it extends Translations$ai$coachPrompts$goalOnTrack$en {
	_Translations$ai$coachPrompts$goalOnTrack$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get label => '🎯 Sono in linea?';
	@override String payload({required Object goal}) => 'Sii sincero sul mio obiettivo \'${goal}\': sono sulla buona strada per raggiungerlo, e qual è l\'unica cosa da cambiare per migliorare di più le mie probabilità?';
}

// Path: ai.coachPrompts.weeklyReviewDown
class _Translations$ai$coachPrompts$weeklyReviewDown$it extends Translations$ai$coachPrompts$weeklyReviewDown$en {
	_Translations$ai$coachPrompts$weeklyReviewDown$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get label => '📉 Analizza la mia settimana';
	@override String payload({required Object thisPct, required Object lastPct}) => 'La mia costanza è scesa al ${thisPct}% questa settimana dal ${lastPct}% della scorsa. Qual è la causa più probabile e l\'unica cosa da cambiare la prossima settimana?';
}

// Path: ai.coachPrompts.weeklyReviewUp
class _Translations$ai$coachPrompts$weeklyReviewUp$it extends Translations$ai$coachPrompts$weeklyReviewUp$en {
	_Translations$ai$coachPrompts$weeklyReviewUp$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get label => '📊 Analizza la mia settimana';
	@override String payload({required Object thisPct, required Object lastPct}) => 'La mia costanza è al ${thisPct}% questa settimana contro il ${lastPct}% della scorsa. Cosa sta funzionando e qual è l\'unica cosa su cui spingere di più la prossima settimana?';
}

// Path: ai.coachPrompts.protectStreak
class _Translations$ai$coachPrompts$protectStreak$it extends Translations$ai$coachPrompts$protectStreak$en {
	_Translations$ai$coachPrompts$protectStreak$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get label => '🛡️ Proteggi la mia serie';
	@override String payload({required Object habit, required Object days}) => 'La mia serie attiva più lunga è \'${habit}\' a ${days} giorni. Qual è il rischio più grande di interromperla e come la proteggo questa settimana?';
}

// Path: ai.coachPrompts.alignHabitsToGoal
class _Translations$ai$coachPrompts$alignHabitsToGoal$it extends Translations$ai$coachPrompts$alignHabitsToGoal$en {
	_Translations$ai$coachPrompts$alignHabitsToGoal$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get label => '🔗 Quali abitudini servono ai miei obiettivi?';
	@override String payload({required Object goal}) => 'Guardando le mie abitudini rispetto all\'obiettivo \'${goal}\', quali lo fanno davvero avanzare e quali sono solo rumore? Sii specifico e indica un\'abitudine che potrebbe mancarmi.';
}

// Path: ai.coachPrompts.designHabitForGoal
class _Translations$ai$coachPrompts$designHabitForGoal$it extends Translations$ai$coachPrompts$designHabitForGoal$en {
	_Translations$ai$coachPrompts$designHabitForGoal$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get label => '💡 Trasforma un obiettivo in abitudine';
	@override String payload({required Object goal}) => 'Voglio raggiungere il mio obiettivo \'${goal}\'. Quale singola abitudine quotidiana farebbe la differenza maggiore? Dammi un\'abitudine concreta da iniziare domani.';
}

// Path: ai.coachPrompts.raiseTheBar
class _Translations$ai$coachPrompts$raiseTheBar$it extends Translations$ai$coachPrompts$raiseTheBar$en {
	_Translations$ai$coachPrompts$raiseTheBar$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get label => '🚀 Alza l\'asticella';
	@override String get payload => 'Sto rispettando tutte le mie abitudini e i miei obiettivi sono in linea. Dove rischio di adagiarmi e qual è un modo per alzare l\'asticella senza esaurirmi?';
}

// Path: ai.coachPrompts.firstStep
class _Translations$ai$coachPrompts$firstStep$it extends Translations$ai$coachPrompts$firstStep$en {
	_Translations$ai$coachPrompts$firstStep$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get label => '🌱 Da dove comincio?';
	@override String get payload => 'Sto appena iniziando e non ho ancora impostato obiettivi o abitudini. Suggeriscimi un primo obiettivo realistico e una piccola abitudine quotidiana per raggiungerlo, e spiega perché questa coppia funziona.';
}

// Path: ai.coachPrompts.whatCanYouHelp
class _Translations$ai$coachPrompts$whatCanYouHelp$it extends Translations$ai$coachPrompts$whatCanYouHelp$en {
	_Translations$ai$coachPrompts$whatCanYouHelp$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get label => '💬 Con cosa puoi aiutarmi?';
	@override String get payload => 'In base alle mie abitudini e ai miei obiettivi in questa app, dammi tre esempi concreti di come puoi aiutarmi — non consigli generici, ma cose legate ai miei dati reali.';
}

// Path: targets.presets.countDaily
class _Translations$targets$presets$countDaily$it extends Translations$targets$presets$countDaily$en {
	_Translations$targets$presets$countDaily$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get label => 'Conteggio';
	@override String get description => 'Fallo un certo numero di volte al giorno.';
}

// Path: targets.presets.durationDaily
class _Translations$targets$presets$durationDaily$it extends Translations$targets$presets$durationDaily$en {
	_Translations$targets$presets$durationDaily$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get label => 'Durata';
	@override String get description => 'Dedica un certo numero di minuti al giorno.';
}

// Path: targets.presets.limitCountDaily
class _Translations$targets$presets$limitCountDaily$it extends Translations$targets$presets$limitCountDaily$en {
	_Translations$targets$presets$limitCountDaily$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get label => 'Limite';
	@override String get description => 'Resta sotto un certo numero ogni giorno.';
}

// Path: targets.presets.limitDurationDaily
class _Translations$targets$presets$limitDurationDaily$it extends Translations$targets$presets$limitDurationDaily$en {
	_Translations$targets$presets$limitDurationDaily$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get label => 'Limite di tempo';
	@override String get description => 'Resta sotto un certo numero di minuti al giorno.';
}

/// The flat map containing all translations for locale <it>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsIt {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'verification.autoVerified' => 'Verificato automaticamente',
			'verification.compound.summaryAll' => ({required Object count}) => 'Tutte le ${count} condizioni',
			'verification.compound.summaryAny' => ({required Object count}) => 'Almeno 1 di ${count} condizioni',
			'verification.templates.steps' => 'Passi',
			'verification.templates.exerciseMinutes' => 'Minuti di attività',
			'verification.templates.activeEnergy' => 'Energia attiva',
			'verification.templates.standHours' => 'Ore in piedi',
			'verification.templates.distance' => 'Distanza',
			'verification.templates.mindfulMinutes' => 'Minuti di mindfulness',
			'verification.templates.sleepHours' => 'Ore di sonno',
			'verification.templates.workout' => 'Allenamento',
			'verification.templates.screenTimeTotal' => 'Utilizzo totale del dispositivo',
			'verification.templates.screenTimeApps' => 'Tempo nelle app scelte',
			'verification.units.minutes' => 'min',
			'verification.units.hours' => 'h',
			'verification.units.kilocalories' => 'kcal',
			'verification.units.kilometers' => 'km',
			'macroTargets.sectionTitle' => 'Obiettivo numerico',
			'macroTargets.none' => 'Nessuno',
			'macroTargets.amountLabel' => 'Valore obiettivo',
			'macroTargets.linkLabel' => 'Collega un\'abitudine',
			'macroTargets.manual' => 'Manuale',
			'macroTargets.unitCount' => 'conteggio',
			'macroTargets.reached' => 'Raggiunto',
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
			'privateData.deleteTitle' => 'Elimina dati privati',
			'privateData.deleteMessage' => 'Sei sicuro di voler eliminare tutto il database locale crittografato? Questa operazione è irreversibile e i dati non potranno essere recuperati.',
			'privateData.deleteSuccess' => 'Dati privati eliminati.',
			'privateData.deleteFailed' => 'Operazione non riuscita.',
			'privateData.exportDoneTitle' => 'Export completato',
			'privateData.exportDoneClipboard' => 'Il JSON è negli appunti: Linux non supporta la condivisione file.',
			'privateData.exportDoneShare' => 'Il JSON è stato inviato al selettore di condivisione.',
			'icloudSync.bannerAction' => 'Attiva',
			'icloudSync.bannerText' => 'La sincronizzazione iCloud è disattivata: le tue abitudini sono solo su questo dispositivo e vanno perse se lo ripristini o lo sostituisci.',
			'icloudSync.deleteSyncNote' => 'La sincronizzazione iCloud è attiva: verrà eliminata anche la copia sincronizzata nel tuo iCloud e la sincronizzazione verrà disattivata. Gli altri dispositivi conservano la loro copia locale — esegui questa operazione su ciascun dispositivo per eliminare tutto ovunque.',
			'icloudSync.detailsAllSynced' => 'Tutto caricato',
			'icloudSync.detailsCopied' => 'Report copiato',
			'icloudSync.detailsCopy' => 'Copia report',
			'icloudSync.detailsFailed' => ({required Object count}) => '${count} elementi non caricati',
			'icloudSync.detailsPending' => ({required Object count}) => '${count} elementi in attesa di caricamento',
			'icloudSync.detailsTitle' => 'Dettagli sincronizzazione',
			'icloudSync.disclosureAccept' => 'Abilita',
			'icloudSync.disclosureBody' => 'I tuoi dati privati si sincronizzano solo tramite il tuo account iCloud, con crittografia end-to-end — mai attraverso i nostri server. La chiave di crittografia risiede nel tuo Portachiavi iCloud; se disattivi il Portachiavi iCloud, i dati sincronizzati non potranno essere recuperati.',
			'icloudSync.disclosureTitle' => 'Crittografia end-to-end',
			'icloudSync.enableTitle' => 'Abilita sincronizzazione iCloud',
			'icloudSync.forceEnable' => 'Riparti da zero',
			'icloudSync.forceEnableBody' => 'I dati di un altro dispositivo sono già in iCloud, ma la chiave di cifratura non è ancora arrivata su questo dispositivo. Di solito basta attendere qualche minuto. Ripartire da zero cancella ciò che è in iCloud e lo sostituisce con i dati di questo dispositivo. L\'operazione non è reversibile.',
			'icloudSync.forceEnableTitle' => 'Riparti da questo dispositivo',
			'icloudSync.keySplitBody' => ({required Object count}) => '${count} record in iCloud sono stati cifrati su un altro dispositivo con una chiave diversa, quindi questo dispositivo non può leggerli. Reimposta la sincronizzazione dal dispositivo che contiene i dati che vuoi conservare.',
			'icloudSync.keySplitTitle' => 'Alcuni dati iCloud non sono leggibili',
			'icloudSync.lastSyncedAt' => ({required Object time}) => 'Ultima sincronizzazione ${time}',
			'icloudSync.lastSyncedNever' => 'Mai sincronizzato',
			'icloudSync.resetFromDevice' => 'Reimposta la sincronizzazione da questo dispositivo',
			'icloudSync.resetFromDeviceConfirm' => 'Questa operazione cancella tutto ciò che è attualmente in iCloud e carica al suo posto i dati di questo dispositivo. Gli altri dispositivi scaricheranno poi questa copia. Eseguila solo dal dispositivo che contiene i dati che vuoi conservare. L\'operazione non è reversibile.',
			'icloudSync.resetFromDeviceDetail' => 'Sostituisci tutto ciò che è in iCloud con i dati di questo dispositivo',
			'icloudSync.resetFromDeviceDone' => 'Sincronizzazione reimpostata. I dati di questo dispositivo sono ora la copia in iCloud.',
			'icloudSync.statusIdle' => 'Aggiornato',
			'icloudSync.statusNoAccount' => 'Accedi a iCloud per sincronizzare',
			'icloudSync.statusNotSynced' => 'Non è stato sincronizzato tutto',
			'icloudSync.statusOff' => 'Sincronizzazione disattivata',
			'icloudSync.statusSyncing' => 'Sincronizzazione…',
			'icloudSync.statusUnavailable' => 'iCloud non è disponibile al momento',
			'icloudSync.statusWaitingKey' => 'In attesa della chiave di cifratura dall\'altro dispositivo',
			'icloudSync.statusWaitingKeychain' => 'In attesa del Portachiavi iCloud — assicurati che l\'app sul tuo iPhone sia aggiornata',
			'icloudSync.syncNow' => 'Sincronizza ora',
			'icloudSync.syncNowNeedsSync' => 'Attiva prima la sincronizzazione iCloud.',
			'icloudSync.title' => 'Sincronizzazione iCloud',
			'icloudSync.unavailablePlatform' => 'Non disponibile su questo dispositivo',
			'privateRecovery.preparing' => 'Preparazione del tuo spazio privato…',
			'privateRecovery.restoredFromCloudToast' => 'Impossibile sbloccare il database locale: i tuoi dati sono stati ripristinati da iCloud.',
			'privateRecovery.waitingTitle' => 'In attesa di iCloud',
			'privateRecovery.waitingMessage' => 'La sincronizzazione è attiva, ma la tua chiave di crittografia non è ancora arrivata dal Portachiavi iCloud. Attendi un momento e riprova.',
			'privateRecovery.lockedTitle' => 'Impossibile sbloccare i dati privati',
			'privateRecovery.lockedMessageLocalOnly' => 'Questo dispositivo non può sbloccare il database privato locale — la chiave di crittografia è mancante — e la sincronizzazione iCloud è disattivata, quindi non c\'è una copia cloud da ripristinare. Puoi reimpostare e ricominciare.',
			'privateRecovery.lockedMessageICloudUnavailable' => 'Questo dispositivo non può sbloccare il database privato locale. La sincronizzazione iCloud è attiva ma l\'account non è disponibile: accedi a iCloud e riprova.',
			'privateRecovery.errorTitle' => 'Impossibile aprire la modalità privata',
			'privateRecovery.errorMessage' => 'Si è verificato un problema durante l\'apertura del database privato. Riprova oppure torna all\'accesso.',
			'privateRecovery.enableSyncHint' => 'Hai questi dati su un altro dispositivo? Attiva la sincronizzazione iCloud nelle Impostazioni dopo la reimpostazione per recuperarli qui.',
			'privateRecovery.retry' => 'Riprova',
			'privateRecovery.resetFresh' => 'Reimposta e ricomincia',
			'privateRecovery.backToSignIn' => 'Torna all\'accesso',
			'privateRecovery.undecryptableTitle' => 'I tuoi dati sono al sicuro, ma questa copia dell\'app non può sbloccarli',
			'privateRecovery.undecryptableMessage' => 'Il database privato su questo Mac è intatto: è semplicemente cifrato con una chiave diversa da quella di questa build. Non è stato modificato né eliminato nulla. Di solito significa che è stato creato da un\'altra build di Evolve (per esempio una build di sviluppo). Apri quella build per accedere ai dati, oppure ripristina da iCloud con un\'installazione pulita.',
			'privateRecovery.schemaTooNewTitle' => 'Questo database proviene da una versione più recente',
			'privateRecovery.schemaTooNewMessage' => 'I tuoi dati privati sono stati aperti l\'ultima volta da una versione più recente di Evolve e sono perfettamente intatti. Questa versione più vecchia non può leggerli in sicurezza. Aggiorna all\'ultima versione — o riapri la build più recente — e ritroverai tutto.',
			'privateRecovery.copyDiagnostics' => 'Copia diagnostica',
			'privateRecovery.diagnosticsCopied' => 'Diagnostica copiata negli appunti',
			'privateRecovery.resetConfirmTitle' => 'Spostare da parte questo database?',
			'privateRecovery.resetConfirmBody' => 'Evolve ripartirà con un database privato vuoto. Il file cifrato esistente viene conservato su questo Mac, non eliminato, quindi è ancora recuperabile.',
			'privateRecovery.resetConfirmBodySized' => ({required Object size}) => 'Evolve ripartirà con un database privato vuoto. Il file cifrato esistente (${size}) viene conservato su questo Mac, non eliminato, quindi è ancora recuperabile.',
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
			'common.actions.pick' => 'Scegli',
			'common.actions.gotIt' => 'Ho capito',
			'common.actions.done' => 'Fatto',
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
			'common.unexpectedErrorTitle' => 'Qualcosa è andato storto',
			'common.unexpectedErrorMessage' => 'Si è verificato un errore imprevisto. Riprova.',
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
			'createGoal.periodWhen' => 'Quando',
			'createHabit.title' => 'Nuova Abitudine',
			'createHabit.subtitle' => 'Definisci la tua nuova abitudine.',
			'createHabit.titleHint' => 'es. Meditazione',
			'createHabit.weeklyFrequency' => 'Frequenza settimanale',
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
			'stats.filterActive' => 'Attive',
			'stats.filterAll' => 'Tutte',
			'stats.noActiveHabits' => 'Nessuna abitudine attiva: passa a Tutte per vedere quelle terminate.',
			'stats.worstStreakLabel' => 'Peggiore',
			'stats.momentumTitle' => 'Momentum',
			'stats.momentumSubtitle' => 'La tua forma attuale',
			'stats.momentumForm' => 'FORMA',
			'stats.momentumRate' => '7 giorni',
			'stats.momentumStreakHealth' => 'Serie',
			'stats.momentumTrend' => 'Trend',
			'stats.rollingImproving' => 'In crescita',
			'stats.rollingDeclining' => 'In calo',
			'stats.rollingSteady' => 'Stabile',
			'stats.lifetimeConsistency' => 'Costanza',
			'stats.lifetimeConsistencyDetail' => 'Completamento totale',
			'stats.lifetimeTotalDone' => 'Totale completati',
			'stats.lifetimeTotalDoneDetail' => 'Abitudini spuntate',
			'stats.lifetimePerfectDays' => 'Giorni perfetti',
			'stats.lifetimePerfectDaysDetail' => 'Tutto completato',
			'stats.lifetimeDaysTracked' => 'Giorni monitorati',
			'stats.lifetimeDaysTrackedDetail' => 'Da quando hai iniziato',
			'stats.keystoneTitle' => 'ABITUDINE CHIAVE',
			'stats.keystoneImpact' => ({required Object withPct, required Object withoutPct}) => 'Nei suoi giorni completi il ${withPct}% delle altre abitudini, contro il ${withoutPct}%.',
			'stats.yearActivity' => 'Attività di 365 giorni',
			'stats.yearActivitySubtitle' => 'Ogni abitudine, ogni giorno',
			'stats.activeDaysCount' => ({required Object count}) => '${count} giorni attivi',
			'stats.heatmapLess' => 'Meno',
			'stats.heatmapMore' => 'Più',
			'stats.bestHabitsTitle' => 'Migliori abitudini',
			'stats.criticalHabitsTitle' => 'Da tenere d\'occhio',
			'stats.criticalStalled' => ({required Object days}) => '${days}g ferma',
			'stats.rollingTitle' => 'Completamento mobile',
			'stats.rollingSubtitle' => 'Tasso a 7 e 30 giorni',
			'stats.rolling7' => '7 giorni',
			'stats.rolling30' => '30 giorni',
			'stats.weekVsAvgTitle' => 'Settimana vs media',
			'stats.weekVsAvgSubtitle' => 'Come va questa settimana',
			'stats.thisWeek' => 'Questa settimana',
			'stats.yourAverage' => 'La tua media',
			'stats.weekdayShapeTitle' => 'Ritmo settimanale',
			'stats.weekdayShapeSubtitle' => 'Completamento per giorno',
			'stats.weekdayWeekendTitle' => 'Settimana vs weekend',
			'stats.weekdayWeekendSubtitle' => 'Dove sei più forte',
			'stats.weekdaysLabel' => 'Feriali',
			'stats.weekendLabel' => 'Weekend',
			'stats.seasonalityTitle' => 'Stagionalità',
			'stats.seasonalitySubtitle' => 'Completamento per mese',
			'stats.bounceBackTitle' => 'Tasso di ripresa',
			'stats.bounceBackSubtitle' => 'Recupero dopo un salto',
			'stats.bounceBackDetail' => ({required Object recoveries, required Object opportunities}) => 'Recuperato ${recoveries} volte su ${opportunities}',
			'stats.dangerZoneTitle' => 'Zona di rischio',
			'stats.dangerZoneSubtitle' => 'Quando le serie si spezzano',
			'stats.dangerZoneNone' => 'Nessuna serie spezzata',
			'stats.dangerZoneDetail' => ({required Object breaks, required Object total}) => '${breaks} rotture su ${total} qui',
			'stats.performanceComparisonTitle' => 'Confronto performance',
			'stats.performanceComparisonSubtitle' => 'Serie migliore vs peggiore',
			'stats.perfCompGap' => ({required Object pct}) => '${pct}% divario',
			'stats.perfCompBest' => 'Migliore',
			'stats.perfCompWorst' => 'Peggiore',
			'stats.consistencyTitle' => 'Costanza',
			'stats.consistencySubtitle' => 'Abitudini più regolari',
			'stats.consistencySteadiest' => 'Più costanti',
			'stats.consistencyErratic' => 'Più irregolari',
			'stats.medalsTitle' => 'Classifica serie',
			'stats.medalsSubtitle' => 'Serie attuali più lunghe',
			'stats.neverMissedTitle' => 'Mai saltata',
			'stats.neverMissedEmpty' => 'Nessuna abitudine perfetta',
			'stats.distributionTitle' => 'Distribuzione',
			'stats.distributionSubtitle' => 'Abitudini per tasso di successo',
			'stats.synergyTitle' => 'Sinergia abitudini',
			'stats.synergySubtitle' => 'Quali abitudini vanno insieme',
			'stats.moodSensitiveTitle' => 'Sensibili all\'umore',
			'stats.moodSensitiveSubtitle' => 'Più influenzate dall\'umore',
			'stats.resilientHabitsTitle' => 'Abitudini resilienti',
			'stats.resilientHabitsSubtitle' => 'Fatte anche nei giorni no',
			'stats.correlationAnalysisTitle' => 'Correlazione umore',
			'stats.correlationAnalysisSubtitle' => 'Completamento umore basso vs alto',
			'stats.moodEnergyTrendTitle' => 'Umore ed energia',
			'stats.moodEnergyTrendSubtitle' => ({required Object days}) => 'Ultimi ${days} giorni',
			_ => null,
		} ?? switch (path) {
			'stats.allTimeBest' => 'Record assoluto',
			'stats.topPerformerLabel' => 'Migliore',
			'stats.currentStreakShort' => 'Ora',
			'stats.recordLabel' => 'Record',
			'stats.recordDetail' => 'Serie record',
			'stats.adherenceTitle' => 'Aderenza al piano',
			'stats.adherenceSubtitle' => 'Dei giorni previsti',
			'stats.adherenceDetail' => ({required Object done, required Object scheduled}) => '${done} di ${scheduled} giorni previsti',
			'stats.atRiskTitle' => 'A rischio',
			'stats.atRiskYes' => 'Sì',
			'stats.atRiskNo' => 'In linea',
			'stats.atRiskDetail' => ({required Object days}) => '${days} giorni dall\'ultima volta',
			'stats.daysUnit' => 'g',
			'stats.gapTitle' => 'Intervalli',
			'stats.gapSubtitle' => 'Giorni tra un completamento e l\'altro',
			'stats.gapAvg' => 'Media',
			'stats.gapLongest' => 'Massimo',
			'stats.gapSince' => 'Dall\'ultimo',
			'stats.habitBounceBackShort' => 'Ripresa',
			'stats.habitConsistencyDetail' => 'Punteggio regolarità',
			'stats.habitPercentile' => ({required Object pct}) => 'Meglio del ${pct}% delle tue abitudini',
			'stats.monthVsTitle' => 'Questo mese vs scorso',
			'stats.monthVsSubtitle' => 'Completamento mese su mese',
			'stats.thisMonthLabel' => 'Questo mese',
			'stats.lastMonthLabel' => 'Mese scorso',
			'stats.nextDayMoodTitle' => 'Impatto sull\'umore del giorno dopo',
			'stats.nextDayMoodSubtitle' => 'Umore ed energia il giorno seguente',
			'stats.nextDayAfterDone' => 'Dopo averla fatta',
			'stats.nextDayAfterMissed' => 'Dopo averla saltata',
			'stats.nextDayMoodLift' => ({required Object value}) => '${value} di umore in più',
			'stats.streakHistoryTitle' => 'Cronologia serie',
			'stats.streakHistorySubtitle' => 'Ogni sequenza di giorni consecutivi',
			'stats.streakHistoryDetail' => ({required Object count, required Object longest}) => '${count} serie · più lunga ${longest} giorni',
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
			'habitsPage.dayDotTooltip' => ({required Object day, required Object month, required Object status}) => '${day} ${month} · ${status}',
			'habitsPage.dayDotTooltipToday' => ({required Object status}) => 'Oggi · ${status}',
			'habitsPage.editHabit' => 'Modifica abitudine',
			'habitsPage.newHabit' => 'Nuova abitudine',
			'habitsPage.optionalReminder' => 'Promemoria opzionale',
			'habitsPage.reminderHint' => 'es. 08:30',
			'habitsPage.close' => 'Chiudi',
			'habitsPage.statusDone' => 'Completata',
			'habitsPage.statusSkipped' => 'Saltata',
			'habitsPage.statusUnrecorded' => 'Non registrata',
			'habitsPage.weekOf' => ({required Object day, required Object month}) => 'Settimana del ${day} ${month}',
			'habitsPage.lifeWeeks' => 'Settimane del tuo percorso',
			'habitsPage.catMindfulness' => 'Mindfulness',
			'habitsPage.editableHint' => 'Puoi modificare solo oggi e ieri.',
			'habitsPage.titleRequired' => 'Il titolo è obbligatorio',
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
			'goalsStats.proRequired' => 'Funzione Pro richiesta',
			'goalsStats.active' => 'Attivi',
			'goalsStats.failed' => 'Falliti',
			'goalsStats.complAbbr' => 'Compl.',
			'goalsStats.seasonality' => 'Stagionalità',
			'goalsStats.interestEvolution' => 'Evoluzione Interessi',
			'ai.coach' => 'AI Coach',
			'ai.dailyHabits' => 'Abitudini giornaliere',
			'ai.macroGoals' => 'Macro obiettivi',
			'ai.openRouter.apiKeyMissingShort' => '⚠️ L\'AI Coach ha bisogno della tua chiave API di OpenRouter. Aggiungila nelle Impostazioni per iniziare a chattare.',
			'ai.openRouter.apiKeyInvalid' => '⚠️ OpenRouter ha rifiutato questa chiave API. Controllala nelle Impostazioni o creane una nuova su openrouter.ai/keys.',
			'ai.openRouter.defaultSystemPrompt' => 'Sei il "Coach di Disciplina", un assistente virtuale focalizzato sull’aiutare la persona a mantenere la disciplina, raggiungere i propri obiettivi e costruire abitudini sane. Sii motivante ma concreto, diretto e pratico. Usa un tono professionale ma amichevole.',
			'ai.openRouter.communicationError' => ({required Object code}) => '❌ Errore nella comunicazione con l’AI. (Codice: ${code})',
			'ai.openRouter.connectionError' => '❌ Errore di connessione. Assicurati di essere online e riprova.',
			'ai.openRouter.connectionErrorShort' => '❌ Errore di connessione.',
			'ai.openRouter.connectionCheckTimeout' => '❌ Errore: la verifica della connessione ha impiegato troppo tempo.',
			'ai.openRouter.contextTooLong' => '⚠️ Questa conversazione è diventata troppo lunga per il modello. Inizia una nuova chat (in alto a destra) per continuare.',
			'ai.openRouter.noInternet' => '❌ Errore: nessuna connessione a internet. Verifica la rete.',
			'ai.openRouter.serverTimeout' => '❌ Errore: il server sta impiegando troppo tempo a rispondere. Riprova.',
			'ai.openRouter.apiError' => ({required Object code}) => '❌ Errore API: ${code} (verifica Sentry per i dettagli)',
			'ai.apiKey.rowTitle' => 'Il tuo account OpenRouter',
			'ai.apiKey.description' => 'Preferisci far girare il coach sul tuo account? Collega una chiave OpenRouter e paghi direttamente il provider — nessun abbonamento Evolve richiesto. Creane una su openrouter.ai/keys: viene salvata nel portachiavi di questo dispositivo e inviata solo a OpenRouter.',
			'ai.apiKey.fieldLabel' => 'Chiave API',
			'ai.apiKey.hint' => 'sk-or-v1-…',
			'ai.apiKey.save' => 'Salva chiave',
			'ai.apiKey.saved' => 'Chiave API salvata',
			'ai.apiKey.remove' => 'Rimuovi chiave',
			'ai.apiKey.removed' => 'Chiave API rimossa',
			'ai.apiKey.removeConfirmTitle' => 'Rimuovere la chiave API?',
			'ai.apiKey.removeConfirmBody' => 'Questo motore smetterà di rispondere finché non colleghi di nuovo un account. Evolve AI e i modelli locali non sono interessati.',
			'ai.apiKey.statusSet' => 'Salvata',
			'ai.apiKey.statusMissing' => 'Non impostata',
			'ai.apiKey.saveFailed' => 'Impossibile salvare la chiave nel portachiavi. Riprova.',
			'ai.apiKey.setupTitle' => 'Collega il tuo account OpenRouter',
			'ai.apiKey.setupBody' => 'Questo motore funziona con il tuo account OpenRouter. Collegalo per iniziare a chattare — oppure passa a Evolve AI, incluso in Pro.',
			'ai.apiKey.setupAction' => 'Collega account',
			'ai.coachPrompts.diagnoseWeakestHabit.label' => '🩺 Sistema la mia abitudine più debole',
			'ai.coachPrompts.diagnoseWeakestHabit.payload' => ({required Object habit, required Object done, required Object scheduled}) => '\'${habit}\' è la mia abitudine più debole questa settimana — ${done}/${scheduled} giorni completati. Qual è il motivo più probabile per cui la salto, e due correzioni concrete che posso applicare questa settimana?',
			'ai.coachPrompts.goalOnTrack.label' => '🎯 Sono in linea?',
			'ai.coachPrompts.goalOnTrack.payload' => ({required Object goal}) => 'Sii sincero sul mio obiettivo \'${goal}\': sono sulla buona strada per raggiungerlo, e qual è l\'unica cosa da cambiare per migliorare di più le mie probabilità?',
			'ai.coachPrompts.weeklyReviewDown.label' => '📉 Analizza la mia settimana',
			'ai.coachPrompts.weeklyReviewDown.payload' => ({required Object thisPct, required Object lastPct}) => 'La mia costanza è scesa al ${thisPct}% questa settimana dal ${lastPct}% della scorsa. Qual è la causa più probabile e l\'unica cosa da cambiare la prossima settimana?',
			'ai.coachPrompts.weeklyReviewUp.label' => '📊 Analizza la mia settimana',
			'ai.coachPrompts.weeklyReviewUp.payload' => ({required Object thisPct, required Object lastPct}) => 'La mia costanza è al ${thisPct}% questa settimana contro il ${lastPct}% della scorsa. Cosa sta funzionando e qual è l\'unica cosa su cui spingere di più la prossima settimana?',
			'ai.coachPrompts.protectStreak.label' => '🛡️ Proteggi la mia serie',
			'ai.coachPrompts.protectStreak.payload' => ({required Object habit, required Object days}) => 'La mia serie attiva più lunga è \'${habit}\' a ${days} giorni. Qual è il rischio più grande di interromperla e come la proteggo questa settimana?',
			'ai.coachPrompts.alignHabitsToGoal.label' => '🔗 Quali abitudini servono ai miei obiettivi?',
			'ai.coachPrompts.alignHabitsToGoal.payload' => ({required Object goal}) => 'Guardando le mie abitudini rispetto all\'obiettivo \'${goal}\', quali lo fanno davvero avanzare e quali sono solo rumore? Sii specifico e indica un\'abitudine che potrebbe mancarmi.',
			'ai.coachPrompts.designHabitForGoal.label' => '💡 Trasforma un obiettivo in abitudine',
			'ai.coachPrompts.designHabitForGoal.payload' => ({required Object goal}) => 'Voglio raggiungere il mio obiettivo \'${goal}\'. Quale singola abitudine quotidiana farebbe la differenza maggiore? Dammi un\'abitudine concreta da iniziare domani.',
			'ai.coachPrompts.raiseTheBar.label' => '🚀 Alza l\'asticella',
			'ai.coachPrompts.raiseTheBar.payload' => 'Sto rispettando tutte le mie abitudini e i miei obiettivi sono in linea. Dove rischio di adagiarmi e qual è un modo per alzare l\'asticella senza esaurirmi?',
			'ai.coachPrompts.firstStep.label' => '🌱 Da dove comincio?',
			'ai.coachPrompts.firstStep.payload' => 'Sto appena iniziando e non ho ancora impostato obiettivi o abitudini. Suggeriscimi un primo obiettivo realistico e una piccola abitudine quotidiana per raggiungerlo, e spiega perché questa coppia funziona.',
			'ai.coachPrompts.whatCanYouHelp.label' => '💬 Con cosa puoi aiutarmi?',
			'ai.coachPrompts.whatCanYouHelp.payload' => 'In base alle mie abitudini e ai miei obiettivi in questa app, dammi tre esempi concreti di come puoi aiutarmi — non consigli generici, ma cose legate ai miei dati reali.',
			'ai.local.notReachable' => ({required Object url}) => '❌ Server AI locale non raggiungibile su ${url}. Assicurati che Ollama o LM Studio sia in esecuzione.',
			'ai.local.modelMissing' => '⚠️ Scegli prima un modello locale — apri il selettore in alto.',
			'ai.local.requestFailed' => ({required Object code}) => '❌ Errore del modello locale (codice: ${code}).',
			'ai.local.streamError' => '❌ Connessione al modello locale non riuscita.',
			'ai.local.timeout' => '❌ Il modello locale sta impiegando troppo tempo — potrebbe essere ancora in caricamento. Riprova.',
			'ai.local.modelNotFound' => '❌ Quel modello non è disponibile sul server. Apri il selettore per sceglierne o caricarne uno.',
			'ai.local.authRequired' => ({required Object app}) => '❌ ${app} rifiuta la connessione — richiede un token API. Disattiva l\'autenticazione nelle impostazioni del suo server, oppure punta Evolve su un server che non lo richiede.',
			'ai.local.stillLoading' => 'Il modello è ancora in caricamento — un avvio a freddo può richiedere un po\' di tempo.',
			'ai.standard.sessionExpired' => '⚠️ La sessione è scaduta. Accedi di nuovo per continuare a usare Evolve AI.',
			'ai.standard.needsPro' => '⚠️ Evolve AI fa parte di Evolve Pro. Abbonati nelle Impostazioni — oppure passa al tuo account OpenRouter, che è gratis.',
			'ai.standard.rateLimited' => '⚠️ Hai raggiunto il limite di uso corretto di Evolve AI per ora. Riprova più tardi oppure passa al tuo account OpenRouter.',
			'ai.standard.unavailable' => '❌ Evolve AI non è disponibile in questo momento. È un problema nostro: riprova tra poco.',
			'ai.consent.allow' => 'Consenti',
			'ai.consent.byokBody' => 'Per rispondere, l\'AI Coach invia il tuo messaggio, il tuo nome e il contesto che scegli di condividere a OpenRouter, Inc. usando il tuo account OpenRouter. OpenRouter lo instrada a un provider di modelli in base alle impostazioni del tuo account. Puoi revocare il consenso in qualsiasi momento dalle Impostazioni e tutto il resto di Evolve continua a funzionare.',
			'ai.consent.byokTitle' => 'Inviare i tuoi messaggi a OpenRouter?',
			'ai.consent.consentStatusRevoked' => 'Non consentito',
			'ai.consent.consentStopSharing' => 'Interrompi la condivisione…',
			'ai.consent.decline' => 'Non ora',
			'ai.consent.privateNote' => 'Il tuo database privato resta su questo dispositivo: esce solo ciò che invii in chat.',
			'ai.consent.revokeAction' => 'Interrompi condivisione',
			'ai.consent.revokeBody' => 'L\'AI Coach chiederà di nuovo il consenso prima di inviare qualcosa. Nient\'altro cambia.',
			'ai.consent.revokeTitle' => 'Interrompere la condivisione con l\'AI?',
			'ai.consent.rowTitle' => 'Condivisione dati con l\'AI',
			'ai.consent.standardBody' => 'Per rispondere, l\'AI Coach invia il tuo messaggio, il tuo nome e il contesto che scegli di condividere a OpenRouter, Inc., che li instrada a Google LLC (Google AI Studio) per eseguire il modello. Trattandosi del piano gratuito di Google, Google può conservare il testo per un periodo limitato e usarlo per migliorare i propri servizi — non è privato come un piano a pagamento. Puoi revocare il consenso in qualsiasi momento dalle Impostazioni e tutto il resto di Evolve continua a funzionare.',
			'ai.consent.standardTitle' => 'Inviare i tuoi messaggi all\'AI?',
			'ai.consent.statusGranted' => 'Consentita',
			'ai.consent.statusNone' => 'Non consentita',
			'aiCoach.greeting' => 'Ciao! Sono Evolve AI Coach. Sono qui per aiutarti a ottimizzare il tuo protocollo e raggiungere i tuoi obiettivi. Come posso esserti utile oggi?',
			'aiCoach.systemPersona' => 'Sei Evolve AI Coach, un assistente virtuale per la disciplina personale.',
			'aiCoach.habitsHeader' => 'ABITUDINI ATTIVE:',
			'aiCoach.noActiveHabits' => 'Nessuna abitudine attiva.',
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
			'aiCoach.newChatTooltip' => 'Nuova chat',
			'aiCoach.clearConfirmTitle' => 'Iniziare una nuova chat?',
			'aiCoach.clearConfirmBody' => 'Questo cancella la conversazione attuale — non viene salvata.',
			'aiCoach.clearConfirmCancel' => 'Annulla',
			'aiCoach.clearConfirmAccept' => 'Nuova chat',
			'aiCoach.copyTooltip' => 'Copia',
			'aiCoach.copiedToast' => 'Copiato negli appunti',
			'aiCoach.linkOpenFailed' => 'Impossibile aprire il link.',
			'settingsPage.aboutCopied' => 'Dettagli della versione copiati',
			'settingsPage.aboutCopyTooltip' => 'Copia i dettagli della versione',
			'settingsPage.aboutVersion' => ({required Object version, required Object build}) => 'Versione ${version} (${build})',
			'settingsPage.accentColor' => 'Colore accento',
			'settingsPage.accentColorDetail' => 'Palette estesa riservata a Evolve Pro.',
			'settingsPage.accessProtection' => 'Protezione accesso',
			'settingsPage.account' => 'Account',
			'settingsPage.accountAndOnboarding' => 'Account e onboarding',
			'settingsPage.accountDataManagementContent' => 'Scegli se eliminare i dati mantenendo attivo l account oppure cancellare definitivamente l account.',
			'settingsPage.accountDataManagementTitle' => 'Gestione account e dati',
			'settingsPage.accountDeleted' => 'Account eliminato.',
			'settingsPage.accountPaneSubtitle' => 'Con quale account hai effettuato l\'accesso e dove risiedono i tuoi dati.',
			'settingsPage.accountSyncOn' => 'Attiva — tramite il tuo account',
			'settingsPage.activateEvolveProStart' => 'Abbonati con il tuo account Apple.',
			'settingsPage.advancedPaneSubtitle' => 'Impostazioni avanzate e diagnostica.',
			'settingsPage.aiAndSystem' => 'AI & SISTEMA',
			'settingsPage.aiInsights' => 'Insight AI',
			'settingsPage.aiInsightsDetail' => 'Analisi e consigli personalizzati dall\'AI.',
			'settingsPage.aiSuggestions' => 'Suggerimenti AI',
			'settingsPage.aiSuggestionsDetail' => 'Analisi intelligente delle abitudini',
			'settingsPage.appLogsDetail' => 'Visualizza i log diagnostici di questa sessione',
			'settingsPage.appLogsTitle' => 'Log dell\'app',
			'settingsPage.appearanceAndVisual' => 'Aspetto e visual',
			'settingsPage.appearanceSubtitle' => 'Preferenze locali adattate al desktop',
			'settingsPage.appearanceTitle' => 'Aspetto e applicazione',
			'settingsPage.applyAction' => 'Applica',
			'settingsPage.availableWithActiveSession' => 'Disponibile con una sessione Supabase attiva',
			'settingsPage.avatarGateTitle' => 'Avatar',
			'settingsPage.avatarPickFailed' => 'Selezione immagine non riuscita.',
			'settingsPage.bestValue' => 'Miglior valore',
			'settingsPage.billingAppleDetail' => 'Il tuo abbonamento viene acquistato e gestito con il tuo account Apple.',
			'settingsPage.billingAppleTitle' => 'Fatturato tramite Apple',
			'settingsPage.billingPlatformUnsupported' => 'Gli acquisti in-app non sono disponibili su questa piattaforma.',
			'settingsPage.billingUnavailableDetail' => 'Gli abbonamenti non sono momentaneamente disponibili. Riprova più tardi.',
			'settingsPage.biometricActivationCancelled' => 'Attivazione annullata.',
			'settingsPage.biometricLock' => 'Blocco biometrico',
			'settingsPage.biometricLockDetail' => 'Disponibile con adapter nativo su macOS e Windows; non supportato su Linux.',
			'settingsPage.calendarExperienceLanguage' => 'Calendario, esperienza e lingua',
			'settingsPage.calendarViewOptions.month' => 'Mese',
			'settingsPage.calendarViewOptions.week' => 'Settimana',
			'settingsPage.calendarViewOptions.year' => 'Anno',
			'settingsPage.calendarViewOptions.life' => 'Vita',
			'settingsPage.cancel' => 'Annulla',
			'settingsPage.changePassword' => 'Cambia password',
			'settingsPage.changePasswordDetail' => 'Aggiornamento credenziali tramite Supabase Auth.',
			'settingsPage.commercialChannelRequired' => 'Acquisti non disponibili',
			'settingsPage.confirm' => 'Conferma',
			'settingsPage.confirmDeleteAccountMessage' => 'L account e tutti i dati associati verranno eliminati definitivamente. Questa azione e irreversibile.',
			'settingsPage.confirmDeleteAccountTitle' => 'Conferma eliminazione account',
			'settingsPage.confirmNewPassword' => 'Conferma nuova password',
			'settingsPage.confirmResetDataMessage' => 'Verranno eliminate abitudini, obiettivi e preferenze. L account restera attivo. Questa azione non puo essere annullata.',
			'settingsPage.confirmResetDataTitle' => 'Conferma reset dati',
			'settingsPage.confirmSignOutMessage' => 'Sei sicuro di voler uscire? Dovrai reinserire le credenziali per accedere nuovamente.',
			'settingsPage.confirmSignOutTitle' => 'Conferma uscita',
			'settingsPage.currentPassword' => 'Password attuale',
			'settingsPage.customColor' => 'Colore personalizzato',
			'settingsPage.dataAndConsents' => 'Dati e consensi',
			'settingsPage.dataBackupPaneSubtitle' => 'Dove vengono copiati i tuoi dati, come importarli ed esportarli e come cancellarli.',
			'settingsPage.dataRepository' => 'Repository dati',
			'settingsPage.dataStorage' => 'Archiviazione dei dati',
			'settingsPage.dataStorageAccount' => 'Il tuo account Evolve',
			'settingsPage.dataStorageThisMac' => 'Solo su questo Mac, cifrati',
			'settingsPage.dateOfBirth' => 'Data di nascita',
			'settingsPage.dateOfBirthHint' => 'AAAA-MM-GG',
			'settingsPage.deepWorkInsights' => 'Deep Work Insights',
			'settingsPage.deepWorkInsightsDetail' => 'Analisi avanzata delle tue sessioni di concentrazione.',
			'settingsPage.defaultCalendarView' => 'Vista calendario predefinita',
			'settingsPage.deleteAccountAction' => 'Elimina account',
			'settingsPage.deleteAccountAndData' => 'Elimina account e dati',
			'settingsPage.deleteAccountAndDataDetail' => 'Operazione irreversibile protetta da conferma.',
			'settingsPage.deleteAccountGateTitle' => 'Elimina account',
			'settingsPage.deletePrivateData' => 'Elimina dati privati',
			'settingsPage.deletePrivateDataDetail' => 'Cancella definitivamente il database locale crittografato.',
			'settingsPage.detailsHeader' => 'DETTAGLI ABBONAMENTO',
			'settingsPage.disabledTurnOnFirst' => 'Attiva il promemoria per impostare un orario.',
			'settingsPage.email' => 'Email',
			'settingsPage.encryptedLocalDatabase' => 'Database locale crittografato',
			'settingsPage.enterCurrentPassword' => 'Inserisci la password attuale.',
			'settingsPage.eveningReview' => 'Review serale',
			'settingsPage.eveningReviewDetail' => 'Ricorda di consolidare la giornata.',
			'settingsPage.eveningReviewTime' => 'Orario review serale',
			'settingsPage.expiresOn' => 'Scade Il',
			'settingsPage.exportData' => 'Esporta dati',
			'settingsPage.exportDataDetail' => 'Condivide un export JSON completo dei dati disponibili.',
			'settingsPage.exportDoneClipboard' => 'Il JSON e negli appunti: Linux non supporta la condivisione file.',
			'settingsPage.exportDoneSaved' => 'Il file JSON è stato salvato nella posizione scelta.',
			'settingsPage.exportDoneShare' => 'Il JSON e stato inviato al selettore di condivisione.',
			'settingsPage.exportDoneTitle' => 'Export completato',
			'settingsPage.exportPrivateShareText' => 'I miei dati privati esportati da Evolve',
			'settingsPage.exportShareText' => 'I miei dati esportati da Evolve',
			'settingsPage.focusMode' => 'Modalità Focus',
			'settingsPage.focusModeDetail' => 'Sospende tutti i promemoria e le notifiche.',
			'settingsPage.focusModeOnBody' => 'Questi promemoria sono in pausa finché non la disattivi.',
			'settingsPage.focusModeOnTitle' => 'Concentrazione attiva',
			'settingsPage.fullName' => 'Nome completo',
			'settingsPage.gateChangePassword' => 'Cambio password',
			'settingsPage.gateLogout' => 'Logout',
			'settingsPage.gateProfile' => 'Profilo',
			'settingsPage.gateRequiresActiveSession' => 'Richiede una sessione Supabase attiva.',
			'settingsPage.generalPaneSubtitle' => 'Aspetto e lingua di Evolve.',
			'settingsPage.goToLogin' => 'Vai al Login',
			'settingsPage.goToLoginDetail' => 'Sospendi la modalità privata e accedi a Supabase.',
			'settingsPage.groupAppLock' => 'Blocco app',
			'settingsPage.groupAppearance' => 'Aspetto',
			'settingsPage.groupBackups' => 'Backup',
			'settingsPage.groupDailyReminders' => 'Promemoria giornalieri',
			'settingsPage.groupDataStorage' => 'Archiviazione dei dati',
			'settingsPage.groupDelivery' => 'Consegna',
			'settingsPage.groupDiagnostics' => 'Diagnostica',
			'settingsPage.groupDiagnosticsConsent' => 'Diagnostica e consensi',
			'settingsPage.groupFocus' => 'Concentrazione',
			'settingsPage.groupGettingStarted' => 'Per iniziare',
			'settingsPage.groupLanguageFormats' => 'Lingua e formati',
			'settingsPage.groupLegal' => 'Note legali',
			'settingsPage.groupSignIn' => 'Accesso',
			'settingsPage.habitReminders' => 'Promemoria abitudini',
			'settingsPage.habitRemindersDetail' => 'Invia il morning briefing giornaliero.',
			'settingsPage.hapticFeedback' => 'Feedback aptico',
			'settingsPage.hapticFeedbackDetail' => 'Il desktop conserva la preferenza ma non genera vibrazioni.',
			'settingsPage.importCategoriesCount' => ({required Object count}) => '${count} Categorie',
			'settingsPage.importCompletedTitle' => 'Importazione completata',
			'settingsPage.importConfirmButton' => 'Conferma Importazione',
			'settingsPage.importData' => 'Importa dati',
			'settingsPage.importDataDetail' => 'Ripristina un backup (JSON o ZIP) di Evolve.',
			'settingsPage.importDataGateTitle' => 'Importa dati',
			'settingsPage.importEntityCategories' => 'Categorie',
			'settingsPage.importEntityHabits' => 'Abitudini',
			'settingsPage.importEntityLogs' => 'Log abitudini',
			'settingsPage.importEntityMacroGoals' => 'Macro obiettivi',
			'settingsPage.importEntityMoods' => 'Registri umore',
			'settingsPage.importError' => ({required Object error}) => 'Errore durante importazione: ${error}',
			'settingsPage.importHabitsCount' => ({required Object count}) => '${count} Abitudini',
			'settingsPage.importInProgress' => 'Importazione in corso...',
			'settingsPage.importLockedMessage' => 'Questo dispositivo non riesce a sbloccare il database privato locale: la sua chiave di crittografia è mancante (succede dopo il passaggio a un nuovo Mac o una modifica alla firma dell\'app). I dati locali esistenti non sono recuperabili, ma puoi ripristinarli e importare questo backup su un database nuovo e vuoto. L\'operazione non può essere annullata.',
			'settingsPage.importLockedResetButton' => 'Ripristina e importa',
			'settingsPage.importLockedTitle' => 'Ripristinare il database privato bloccato?',
			'settingsPage.importLogsCount' => ({required Object count}) => '${count} Check-in (Log)',
			'settingsPage.importMacroGoalsCount' => ({required Object count}) => '${count} Obiettivi Macro',
			'settingsPage.importMergeSubtitle' => 'Combina con i tuoi dati, mantenendo la versione più recente di ogni elemento.',
			'settingsPage.importMergeTitle' => 'Unisci ai dati attuali',
			'settingsPage.importMoodsCount' => ({required Object count}) => '${count} Registrazioni Umore',
			'settingsPage.importPreviewSkipped' => ({required Object count}) => '⚠ ${count} record non validi verranno ignorati',
			'settingsPage.importPrivateOnly' => 'La funzione di importazione è attualmente disponibile solo in Modalità Privata (Locale).',
			'settingsPage.importReplaceConfirmButton' => 'Elimina e sostituisci',
			'settingsPage.importReplaceConfirmMessage' => ({required Object count}) => 'Questa operazione elimina definitivamente i tuoi dati attuali (circa ${count} registrazioni) e mantiene solo ciò che è in questo backup. Non è reversibile.',
			'settingsPage.importReplaceConfirmTitle' => 'Sostituire tutti i dati?',
			'settingsPage.importReplaceSubtitle' => 'Elimina definitivamente ogni record esistente che non è in questo backup.',
			'settingsPage.importReplaceTitle' => 'Sostituisci i dati attuali',
			'settingsPage.importRowMerge' => ({required Object label, required Object added, required Object updated, required Object unchanged}) => '${label}: ${added} aggiunti, ${updated} aggiornati, ${unchanged} invariati',
			'settingsPage.importRowReplace' => ({required Object count, required Object label}) => '${count} ${label}',
			'settingsPage.importRowSkipped' => ({required Object count}) => ', ${count} ignorati',
			'settingsPage.importSuccess' => 'Importazione completata con successo!',
			'settingsPage.importSummaryDone' => 'Fantastico!',
			'settingsPage.importSummaryMerged' => 'I tuoi dati sono stati uniti al backup. Riepilogo:',
			'settingsPage.importSummaryReplaced' => 'I tuoi dati sono stati sostituiti con il backup. Riepilogo:',
			'settingsPage.importSummaryTitle' => 'Riepilogo Importazione',
			'settingsPage.insightsAndReports' => 'Insight e resoconti',
			'settingsPage.language' => 'Lingua',
			'settingsPage.languageOptions.system' => 'Sistema',
			'settingsPage.languageOptions.italian' => 'Italiano',
			'settingsPage.languageOptions.english' => 'English',
			'settingsPage.languageOptions.spanish' => 'Spagnolo',
			'settingsPage.languageOptions.german' => 'Tedesco',
			'settingsPage.languageOptions.arabic' => 'العربية',
			'settingsPage.manageSubscription' => 'Gestisci abbonamento',
			'settingsPage.manageSubscriptionDetail' => 'Apre la gestione abbonamenti dell account Apple.',
			'settingsPage.milestones' => 'Milestones',
			'settingsPage.milestonesDetail' => 'Celebrazioni al raggiungimento dei traguardi chiave.',
			'settingsPage.morningBriefTime' => 'Orario morning brief',
			'settingsPage.nativeDeliveryTitle' => 'Delivery nativo per sistema operativo',
			'settingsPage.newPassword' => 'Nuova password',
			'settingsPage.newPasswordMinLength' => 'La nuova password deve avere almeno 8 caratteri.',
			'settingsPage.nextRenewal' => 'Prossimo Rinnovo',
			'settingsPage.notAuthenticated' => 'Non autenticato',
			'settingsPage.notificationPermissionsDenied' => 'Permesso non concesso. Puoi modificarlo dalle impostazioni di sistema.',
			'settingsPage.notificationPermissionsGranted' => 'Permessi disponibili per questo sistema.',
			'settingsPage.notificationPermissionsTitle' => 'Permessi notifiche',
			'settingsPage.notifications' => 'Notifiche',
			'settingsPage.notificationsPaneSubtitle' => 'Tutto ciò che può interromperti.',
			'settingsPage.notificationsSubtitle' => 'Promemoria operativi del client desktop',
			'settingsPage.operationFailed' => 'Operazione non riuscita.',
			'settingsPage.operationalReminders' => 'Promemoria operativi',
			'settingsPage.pageSubtitle' => 'Gestisci profilo, comportamento desktop, privacy e piano Evolve.',
			'settingsPage.pageTitle' => 'Impostazioni',
			'settingsPage.passwordUpdateFailed' => 'Aggiornamento non riuscito. Verifica la password attuale.',
			'settingsPage.passwordsDontMatch' => 'Le password non coincidono.',
			'settingsPage.paymentMethod' => 'Metodo di Pagamento',
			'settingsPage.paymentMethodValue' => 'Apple Pay / App Store',
			'settingsPage.perHabitRemindersNote' => 'I promemoria delle singole abitudini si impostano su ciascuna abitudine e non dipendono da questi interruttori.',
			'settingsPage.perMonth' => ({required Object price}) => '${price} al mese',
			'settingsPage.perMonthWithSavings' => ({required Object price, required Object percent}) => '${price} al mese · Risparmi il ${percent}%',
			'settingsPage.personalInfo' => 'Informazioni personali',
			'settingsPage.personalInfoDetail' => 'Nome, cognome, email e data di nascita',
			'settingsPage.planAnnual' => 'Annuale',
			'settingsPage.planLabel' => 'Piano',
			'settingsPage.planManagement' => 'Gestione piano',
			'settingsPage.planMonthly' => 'Mensile',
			'settingsPage.priceUnavailable' => 'Prezzo non disponibile',
			'settingsPage.privacyPaneSubtitle' => 'Cosa può vedere Evolve e chi altro può aprirlo.',
			'settingsPage.privacyPolicy' => 'Privacy Policy',
			'settingsPage.privacySubtitle' => 'Protezione accesso, consensi e gestione dati',
			'settingsPage.privacyTitle' => 'Privacy e sicurezza',
			'settingsPage.privateMode' => 'Modalità Privata',
			'settingsPage.privateModeDataProtected' => 'I tuoi dati sono protetti e salvati unicamente su questo dispositivo.',
			'settingsPage.proActiveMessage' => 'La tua iscrizione è attiva. L\'AI Coach è incluso — senza account OpenRouter né chiave API — insieme alle statistiche avanzate dei trend e a tutti gli strumenti di crescita personale di Evolve.',
			'settingsPage.proActiveName' => 'Evolve Pro Attivo',
			'settingsPage.proName' => 'Evolve Pro',
			'settingsPage.proStartJourney' => 'Inizia il tuo Percorso',
			'settingsPage.proSubtitle' => 'Piano, ripristino acquisti e gestione abbonamento',
			'settingsPage.proThankYou' => 'Grazie per sostenere lo sviluppo di Evolve.',
			'settingsPage.proTitle' => 'Evolve Pro',
			'settingsPage.proUpsellSubtitle' => 'Sblocca tutte le funzionalità e accelera la tua crescita.',
			'settingsPage.proUpsellTitle' => 'Passa a Evolve Pro',
			'settingsPage.proWelcomeTitle' => 'Benvenuto in Evolve Pro!',
			'settingsPage.profileFallback' => 'Profilo',
			'settingsPage.profileLabel' => 'Profilo',
			'settingsPage.profileSubtitle' => 'Informazioni personali e stato sincronizzazione',
			'settingsPage.railGroupApp' => 'App',
			'settingsPage.railGroupData' => 'Dati',
			'settingsPage.railGroupYou' => 'Tu',
			'settingsPage.renewalDisclaimer' => 'L\'abbonamento si rinnova automaticamente a meno che l\'autorinnovamento non venga disattivato nelle impostazioni dell\'account Apple almeno 24 ore prima della scadenza.',
			'settingsPage.requestNotificationPermissions' => 'Richiedi permessi notifiche',
			'settingsPage.requestNotificationPermissionsDetail' => 'Apre il prompt nativo sul target supportato.',
			'settingsPage.resetDataAction' => 'Resetta i dati',
			'settingsPage.resetDataSuccess' => 'Dati eliminati con successo.',
			'settingsPage.resetDataTitle' => 'Reset dati',
			'settingsPage.resetTutorial' => 'Ripristina tutorial',
			'settingsPage.resetTutorialDetail' => 'Riapre i walkthrough di dashboard e obiettivi.',
			'settingsPage.restoreDefaults' => 'Ripristina le impostazioni predefinite…',
			'settingsPage.restoreDefaultsDetail' => 'Le tue abitudini, i tuoi obiettivi, l\'account e il blocco app non vengono toccati.',
			'settingsPage.restorePurchases' => 'Ripristina acquisti',
			'settingsPage.restorePurchasesDetail' => 'Ripristina un abbonamento già acquistato.',
			'settingsPage.reviewInitialConsent' => 'Rivedi consenso iniziale',
			'settingsPage.reviewInitialConsentDetail' => 'Termini, privacy, notifiche e crash reporting',
			'settingsPage.save' => 'Salva',
			'settingsPage.searchClear' => 'Cancella la ricerca',
			'settingsPage.searchNoResults' => 'Nessuna impostazione corrisponde',
			'settingsPage.searchPlaceholder' => 'Cerca nelle impostazioni',
			'settingsPage.sectionAccount' => 'Account',
			'settingsPage.sectionAdvanced' => 'Avanzate',
			'settingsPage.sectionApplication' => 'Applicazione',
			'settingsPage.sectionDataBackup' => 'Dati e backup',
			'settingsPage.sectionGeneral' => 'Generale',
			'settingsPage.sectionPrivacy' => 'Privacy',
			'settingsPage.sectionPrivacySecurity' => 'Privacy e sicurezza',
			'settingsPage.sendCrashReports' => 'Invia segnalazioni crash',
			'settingsPage.sendCrashReportsDetail' => 'Consenso separato per Sentry.',
			'settingsPage.sessionUnavailable' => 'Sessione non disponibile',
			'settingsPage.settingSaveFailed' => 'Impossibile salvare l\'impostazione. È stata ripristinata al valore precedente.',
			'settingsPage.signOut' => 'Esci dall\'account',
			'settingsPage.signOutDetailActive' => 'Chiudi la sessione su questo dispositivo',
			'settingsPage.statusActive' => 'Attivo',
			'settingsPage.statusLabel' => 'Stato',
			'settingsPage.subscribeCta' => ({required Object plan, required Object price}) => 'Abbonati — ${plan} · ${price}',
			'settingsPage.subscribeCtaNoPrice' => ({required Object plan}) => 'Abbonati — ${plan}',
			'settingsPage.subscription' => 'Abbonamento',
			'settingsPage.supabaseWithEncryptedCache' => 'Supabase con cache cifrata',
			'settingsPage.syncsToIPhoneNote' => 'Queste impostazioni valgono anche sul tuo iPhone.',
			'settingsPage.systemPermissionsManagement' => 'Gestione permessi di sistema',
			'settingsPage.systemPermissionsManagementDetail' => 'Notifiche, calendario e sicurezza.',
			'settingsPage.systemPermissionsOpenFailed' => 'Impossibile aprire le impostazioni.',
			'settingsPage.systemPermissionsTitle' => 'Permessi di sistema',
			'settingsPage.systemSection' => 'Sistema',
			'settingsPage.termsEula' => 'Termini d\'Uso (EULA)',
			'settingsPage.themeDark' => 'Scuro',
			'settingsPage.themeLight' => 'Chiaro',
			'settingsPage.themeMode' => 'Tema',
			'settingsPage.themeSystem' => 'Segui il sistema',
			'settingsPage.timeFormat24h' => 'Formato 24h',
			'settingsPage.timeFormat24hDetail' => 'Usa orari come 20:30 invece di 8:30 PM.',
			'settingsPage.tutorialResetMessage' => 'Le guide verranno mostrate nuovamente nelle relative sezioni.',
			'settingsPage.tutorialResetTitle' => 'Tutorial ripristinati',
			'settingsPage.updateAvatar' => 'Aggiorna avatar',
			'settingsPage.updateAvatarDetail' => 'Scegli un immagine locale per il profilo desktop.',
			'settingsPage.updatePassword' => 'Aggiorna password',
			'settingsPage.useAccent' => ({required Object hex}) => 'Usa accento ${hex}',
			'settingsPage.verified' => 'Verificato',
			_ => null,
		} ?? switch (path) {
			'settingsPage.weeklyReports' => 'Resoconti Settimanali',
			'settingsPage.weeklyReportsDetail' => 'Un riepilogo settimanale dei tuoi progressi.',
			'settingsPage.youArePro' => 'Sei un utente Pro!',
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
			'consentPage.subtitle' => 'Evolve carica i tuoi dati personali su un server solo dopo il tuo consenso qui.',
			'consentPage.uploadTitle' => 'Cosa esce da questo Mac',
			'consentPage.uploadAccountTitle' => 'Con un account Evolve',
			'consentPage.uploadAccountBody' => 'obiettivi, abitudini, check-in dell\'umore, le impostazioni dell\'app e il profilo (nome, email, data di nascita) vengono caricati sui server di Evolve per sincronizzare i tuoi dispositivi. La foto del profilo resta su questo Mac.',
			'consentPage.uploadPrivateTitle' => 'In privato su questo Mac',
			'consentPage.uploadPrivateBody' => 'non ci viene caricato nulla; la sincronizzazione iCloud facoltativa è cifrata end-to-end e raggiunge solo il tuo account iCloud.',
			'consentPage.uploadNeverTitle' => 'Mai consultati',
			'consentPage.uploadNeverBody' => 'contatti, calendario, fotocamera, microfono, posizione.',
			'consentPage.acceptTerms' => 'Accetto termini e privacy policy',
			'consentPage.termsSubtitle' => 'Ho letto i documenti, ho almeno 14 anni e acconsento al caricamento descritto sopra.',
			'consentPage.crashDiagnostics' => 'Diagnostica crash',
			'consentPage.crashSubtitle' => 'Disattivata per impostazione predefinita. Se attiva, invia segnalazioni anonimizzate di crash al nostro fornitore di diagnostica, Sentry.',
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
			'notif.limitReminderBody' => 'Stai rimanendo entro il tuo limite oggi? Fai un controllo quando puoi.',
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
			'subscriptionCtrl.loadOffersFailed' => 'Impossibile caricare i piani di abbonamento. Controlla la connessione e riprova.',
			'subscriptionCtrl.proActivated' => 'Evolve Pro attivato.',
			'subscriptionCtrl.purchasesRestored' => 'Acquisti ripristinati.',
			'subscriptionCtrl.noActiveSub' => 'Nessun abbonamento Pro attivo trovato.',
			'subscriptionCtrl.restoreFailed' => 'Ripristino acquisti non riuscito.',
			'subscriptionCtrl.configKey' => 'Gli acquisti in-app non sono momentaneamente disponibili.',
			'subscriptionCtrl.loginFirst' => 'Accedi prima di gestire Evolve Pro.',
			'subscriptionCtrl.paidAppsAgreement' => 'Contratto Paid Apps non attivo. L\'Account Holder deve accettare l\'accordo Paid Apps in App Store Connect.',
			'subscriptionCtrl.alreadyPurchased' => 'Questo abbonamento risulta già acquistato. Usa Ripristina acquisti per riattivare l\'accesso Pro.',
			'subscriptionCtrl.purchasesNotAllowed' => 'Gli acquisti in-app non sono consentiti su questo dispositivo o account Apple.',
			'subscriptionCtrl.planUnavailable' => 'Il piano selezionato non è disponibile per l\'acquisto. Riprova più tardi.',
			'subscriptionCtrl.paymentPending' => 'Il pagamento è in sospeso. L\'accesso Pro verrà attivato quando Apple confermerà la transazione.',
			'subscriptionCtrl.connectionUnavailable' => 'Connessione non disponibile. Controlla la rete e riprova.',
			'subscriptionCtrl.linkedToAnotherAccount' => 'Questo acquisto è già collegato a un altro account Evolve. Accedi con quell\'account o contatta il supporto.',
			'subscriptionCtrl.purchaseInProgress' => 'Un\'operazione di acquisto è già in corso. Attendi qualche secondo.',
			'subscriptionCtrl.restoreInProgress' => 'Un ripristino è già in corso. Attendi qualche secondo.',
			'subscriptionCtrl.purchaseFailedMessage' => 'Non siamo riusciti a completare l\'acquisto. Riprova tra poco.',
			'subscriptionCtrl.restoreFailedMessage' => 'Non siamo riusciti a ripristinare gli acquisti. Riprova tra poco.',
			'subscriptionCtrl.purchaseRegisteredNotActive' => 'L\'acquisto è registrato, ma l\'abbonamento Pro non risulta ancora attivo. Attendi qualche secondo e usa Ripristina acquisti.',
			'subscriptionCtrl.noActiveSubscription' => 'Nessun abbonamento Evolve Pro attivo è stato trovato su questo Apple ID. Assicurati di usare lo stesso Apple ID dell\'acquisto.',
			'subscriptionCtrl.invalidConfig' => 'Configurazione degli acquisti non valida. Riprova più tardi o contatta l\'assistenza.',
			'authCtrl.appleNoToken' => 'Apple non ha restituito un identity token.',
			'authCtrl.appleAuthFailed' => 'Autenticazione Apple non riuscita.',
			'authCtrl.cantOpenBrowser' => 'Impossibile aprire il browser di sistema.',
			'authCtrl.accessNotCompleted' => ({required Object provider}) => 'Accesso ${provider} non completato.',
			'authCtrl.providerAuthFailed' => ({required Object provider}) => 'Autenticazione ${provider} non riuscita.',
			'authCtrl.operationFailed' => 'Operazione non riuscita. Riprova tra poco.',
			'proModal.title' => 'Sblocca Evolve Pro',
			'proModal.subtitle' => 'Porta il tuo sistema di abitudini al livello successivo',
			'proModal.featuresHeader' => 'COSA INCLUDE IL PIANO PRO',
			'proModal.aiCoachTitle' => 'AI Coach, senza configurazione',
			'proModal.aiCoachDesc' => 'Lo eseguiamo noi con la nostra chiave: nessuna chiave API da recuperare, nessun secondo account. Preferisci il tuo account OpenRouter? È gratis anche così.',
			'proModal.statsTitle' => 'Statistiche Specifiche Per Abitudine',
			'proModal.statsDesc' => 'Informazioni chiave per aumentare la tua produttività.',
			'proModal.metricsTitle' => 'Metriche Avanzate Obiettivi',
			'proModal.metricsDesc' => 'Visualizza grafici dettagliati e statistiche di performance profonde per ogni anno.',
			'proModal.unlimitedTitle' => 'Abitudini Illimitate',
			'proModal.unlimitedDesc' => 'Crea e traccia tutti gli habits che desideri senza alcun limite.',
			'proModal.maybeLater' => 'Forse più tardi',
			'proModal.viewPlans' => 'Vedi i piani Pro',
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
			'appLogs.detailExtras' => 'Contesto aggiuntivo',
			'appLogs.detailStackTrace' => 'STACK TRACE',
			'appLogs.shareLogs' => 'Condividi file dei log',
			'appLogs.exportDone' => 'Log esportati',
			'coachSettings.accountModeNote' => 'Preferisci la tua chiave OpenRouter o un modello locale? Sono disponibili nella modalità Privata.',
			'coachSettings.activeCloud' => ({required Object model}) => 'Cloud · ${model}',
			'coachSettings.activeLocal' => ({required Object model}) => 'Locale · ${model}',
			'coachSettings.activeLocalNoModel' => 'Locale · scegli un modello',
			'coachSettings.activeStandard' => ({required Object model}) => 'Evolve AI · ${model}',
			'coachSettings.backendStandard' => 'Evolve AI',
			'coachSettings.baseUrlLabel' => 'URL di base',
			'coachSettings.cardLive' => 'Attivo',
			'coachSettings.cardOff' => 'Spento',
			'coachSettings.cloudKeyMissing' => 'Nessuna chiave — questo motore non risponderà. Collega qui sotto il tuo account OpenRouter, passa a Evolve AI oppure usa un server locale.',
			'coachSettings.detectedAction' => 'Usa locale',
			'coachSettings.detectedBody' => ({required Object app}) => '${app} è in esecuzione su questo Mac. Vuoi usare il coach in modo 100% privato?',
			'coachSettings.detectedDismiss' => 'Non ora',
			'coachSettings.detectedTitle' => ({required Object app}) => '${app} rilevato',
			'coachSettings.discovering' => 'Ricerca dei modelli…',
			'coachSettings.engineOpenRouter' => 'OpenRouter',
			'coachSettings.engineOpenRouterHint' => 'La tua chiave · gratis',
			'coachSettings.getLocalServer' => ({required Object app}) => 'Ottieni ${app}',
			'coachSettings.groupEngine' => 'Motore',
			'coachSettings.groupPrivacy' => 'Privacy',
			'coachSettings.groupTuning' => 'Regolazione AI Coach',
			'coachSettings.lmStudioNoModelsJit' => 'LM Studio non elenca alcun modello. Quando il caricamento Just-In-Time è disattivato, elenca solo i modelli già caricati — carica un modello in LM Studio, oppure attiva Developer → Server Settings → Just In Time Model Loading.',
			'coachSettings.lmStudioServerOffBody' => 'LM Studio è aperto, ma il suo server locale è spento. Attivalo con Developer → Start Server, oppure spunta Settings → Run the LLM server on login.',
			'coachSettings.lmStudioServerOffTitle' => 'Il server di LM Studio non è in esecuzione',
			'coachSettings.lmStudioStartTimeout' => 'Sta impiegando più tempo del previsto — apri LM Studio e controlla che abbia terminato l\'avvio.',
			'coachSettings.localGroupLabel' => 'Locale — su questo Mac',
			'coachSettings.localServerDownloadFailed' => ({required Object url}) => 'Impossibile aprire il browser — visita ${url}',
			'coachSettings.localServerNotInstalledBody' => ({required Object app}) => 'Installa l\'app gratuita ${app}, poi premi Avvia.',
			'coachSettings.localServerNotInstalledTitle' => ({required Object app}) => '${app} non è installato',
			'coachSettings.localServerOfflineBody' => 'Avvia il server locale per chattare in privato — senza terminale.',
			'coachSettings.localServerOfflineTitle' => ({required Object app}) => '${app} non è in esecuzione',
			'coachSettings.localServerStartFailed' => ({required Object app}) => 'Impossibile avviare ${app} — prova ad aprirlo dalla cartella Applicazioni.',
			'coachSettings.localServerStartingBody' => 'Può richiedere qualche secondo…',
			'coachSettings.manualModelAdd' => 'Usa questo modello',
			'coachSettings.manualModelLabel' => 'Id modello',
			'coachSettings.modelLabel' => 'Modello',
			'coachSettings.noModelsFound' => 'Nessun modello trovato — inserisci manualmente un id modello qui sotto.',
			'coachSettings.ollamaServerOffBody' => 'Ollama è aperto, ma non risponde sulla sua porta. Chiudilo dalla barra dei menu, poi premi di nuovo Avvia.',
			'coachSettings.ollamaServerOffTitle' => 'Ollama è avviato ma non è in ascolto',
			'coachSettings.ollamaStartTimeout' => 'Sta impiegando più tempo del previsto — controlla l\'icona di Ollama nella barra dei menu (il primo avvio potrebbe richiedere un\'autorizzazione).',
			'coachSettings.presetLmStudio' => 'LM Studio',
			'coachSettings.presetOllama' => 'Ollama',
			'coachSettings.refreshModels' => 'Aggiorna modelli',
			'coachSettings.remoteBadge' => 'Remoto',
			'coachSettings.remoteWarning' => 'Questo endpoint non è un indirizzo locale — i messaggi lasceranno questo dispositivo.',
			'coachSettings.sendMessage' => 'Invia',
			'coachSettings.settingsRowConfigure' => 'Motore e server locale',
			'coachSettings.settingsRowStatus' => 'Motore attivo',
			'coachSettings.settingsSectionLabel' => 'AI Coach',
			'coachSettings.settingsSubtitle' => 'Scegli il motore che alimenta il coach e collegalo a un server locale per la massima privacy.',
			'coachSettings.standardNeedsProNote' => 'Evolve AI fa parte di Evolve Pro. Abbonati per sbloccarlo.',
			'coachSettings.standardNeedsSignInNote' => 'Accedi per usare Evolve AI. L\'abbonamento lo sblocca su ogni dispositivo.',
			'coachSettings.standardPrivateNote' => 'Evolve AI richiede un account Evolve, e la modalità Privata non ne conserva uno. Collega il tuo account OpenRouter oppure usa un modello locale: qui funzionano entrambi.',
			'coachSettings.standardStatusNeedsPro' => 'Richiede Pro',
			'coachSettings.standardStatusNeedsSignIn' => 'Accesso richiesto',
			'coachSettings.standardStatusReady' => 'Incluso in Pro',
			'coachSettings.standardStatusUnavailable' => 'Non disponibile',
			'coachSettings.standardUnavailableNote' => 'Evolve AI non è disponibile in questa build. Collega il tuo account OpenRouter oppure usa un modello locale.',
			'coachSettings.startLocalServer' => ({required Object app}) => 'Avvia ${app}',
			'coachSettings.startingLocalServer' => ({required Object app}) => 'Avvio di ${app}…',
			'coachSettings.statusChecking' => 'Verifica…',
			'coachSettings.statusConnected' => 'Connesso',
			'coachSettings.statusOffline' => 'Server offline',
			'coachSettings.stopResponse' => 'Ferma',
			'coachSettings.systemPromptHint' => 'Sostituisci la persona del coach (lascia vuoto per quella predefinita)',
			'coachSettings.systemPromptLabel' => 'Prompt di sistema',
			'coachSettings.systemPromptReset' => 'Ripristina',
			'coachSettings.temperatureLabel' => 'Temperatura',
			'coachSettings.temperatureLower' => 'Riduci la temperatura',
			'coachSettings.temperatureRaise' => 'Aumenta la temperatura',
			'coachSettings.tuningFootnote' => 'Valgono per ogni motore, incluso Evolve AI.',
			'coachSettings.useCustomServer' => 'Usa un server personalizzato…',
			'tour.back' => 'Indietro',
			'tour.next' => 'Avanti',
			'tour.continueLabel' => 'Continua',
			'tour.finish' => 'Fine',
			'tour.welcomeTitle' => 'Benvenuto in Evolve',
			'tour.welcomeBody' => 'Facciamo un rapido tour del tuo spazio di lavoro — dalla panoramica quotidiana fino al tuo AI coach. Bastano pochi istanti.',
			'tour.welcomeStart' => 'Inizia il tour',
			'tour.welcomeSkip' => 'Salta tutorial',
			'tour.doneTitle' => 'Tutto pronto',
			'tour.doneBody' => 'Questa è tutta l\'app. Parti da dove vuoi dalla barra laterale — e puoi rivedere il tour quando vuoi dalle Impostazioni.',
			'tour.doneButton' => 'Inizia',
			'tour.overviewOrientationTitle' => 'La tua Panoramica',
			'tour.overviewOrientationDesc' => 'È la tua base quotidiana — un riepilogo della giornata appena apri Evolve.',
			'tour.overviewCheckinTitle' => 'Check-in giornaliero',
			'tour.overviewCheckinDesc' => 'Registra come sta andando la giornata. Col tempo mostra come il tuo umore si lega ad abitudini e obiettivi.',
			'tour.overviewHabitsTitle' => 'Abitudini di oggi',
			'tour.overviewHabitsDesc' => 'Le abitudini che hai pianificato per oggi sono qui — spuntale man mano.',
			'tour.overviewGoalsTitle' => 'Obiettivi in focus',
			'tour.overviewGoalsDesc' => 'Gli obiettivi su cui ti stai concentrando compaiono qui, così non ti sfugge nulla.',
			'tour.habitsOrientationTitle' => 'La pagina Abitudini',
			'tour.habitsOrientationDesc' => 'Qui costruisci il tuo protocollo quotidiano e monitori la tua costanza.',
			'tour.habitsAddTitle' => 'Aggiungi un\'abitudine',
			'tour.habitsAddDesc' => 'Crea una nuova abitudine qui — nome, categoria, colore e un promemoria opzionale.',
			'tour.habitsCheckoffTitle' => 'Segnala come fatta',
			'tour.habitsCheckoffDesc' => 'Spunta questa casella per completare un\'abitudine oggi. Basta questo per mantenere viva una serie.',
			'tour.habitsStreakTitle' => 'Serie e cronologia',
			'tour.habitsStreakDesc' => 'Guarda crescere la tua serie e vedi gli ultimi sette giorni a colpo d\'occhio.',
			'tour.habitsCalendarTitle' => 'Vista Calendario',
			'tour.habitsCalendarDesc' => 'Passa al Calendario per rivedere la cronologia per settimana, mese, anno — o tutta la vita.',
			'tour.insightsOrientationTitle' => 'Le tue Statistiche',
			'tour.insightsOrientationDesc' => 'Osserva l\'andamento di abitudini e obiettivi nel tempo e dove stai perdendo il ritmo.',
			'tour.insightsFilterTitle' => 'Filtra per abitudine',
			'tour.insightsFilterDesc' => 'Concentra le statistiche su una singola abitudine o mantieni la vista globale.',
			'tour.insightsTabsTitle' => 'Sezioni statistiche',
			'tour.insightsTabsDesc' => 'Passa tra le sezioni per tendenze, avvisi, progressi delle abitudini e umore.',
			'tour.goalsOrientationTitle' => 'La pagina Obiettivi',
			'tour.goalsOrientationDesc' => 'Imposta e monitora i tuoi obiettivi più grandi — ciò a cui puntano le tue abitudini quotidiane.',
			'tour.goalsPlanTitle' => 'Tipo di pianificazione',
			'tour.goalsPlanDesc' => 'Scegli come pianificare — giornaliera, settimanale o più lunga — in base a come pensi i tuoi obiettivi.',
			'tour.goalsAddTitle' => 'Aggiungi un obiettivo',
			'tour.goalsAddDesc' => 'Crea qui un nuovo obiettivo e dagli un traguardo da raggiungere.',
			'tour.goalsCheckTitle' => 'Completa o manca',
			'tour.goalsCheckDesc' => 'Segna un obiettivo come completato o mancato. Ogni esito alimenta le tue performance nel tempo.',
			'tour.goalsStatsTitle' => 'Performance',
			'tour.goalsStatsDesc' => 'Attiva le statistiche di performance per vedere come stai andando rispetto ai tuoi obiettivi.',
			'tour.coachOrientationTitle' => 'Il tuo AI Coach',
			'tour.coachOrientationDesc' => 'Consigli personalizzati basati sulle tue abitudini e obiettivi reali — qui sul tuo Mac.',
			'tour.coachModelTitle' => 'Scegli il motore',
			'tour.coachModelDesc' => 'Scegli il modello AI — il nostro cloud o un modello locale in esecuzione in privato sul tuo Mac. Anche le impostazioni del server sono qui.',
			'tour.coachContextTitle' => 'Cosa vede il coach',
			'tour.coachContextDesc' => 'Decidi se il coach può usare le tue abitudini e i tuoi obiettivi per personalizzare i consigli.',
			'tour.coachSuggestionsTitle' => 'Spunti iniziali',
			'tour.coachSuggestionsDesc' => 'Non sai da dove iniziare? Tocca uno di questi suggerimenti per partire.',
			'tour.coachInputTitle' => 'Chiedi qualsiasi cosa',
			'tour.coachInputDesc' => 'Scrivi qui la tua domanda e premi invia. Il tour finisce qui — buon Evolve!',
			'palette.searchHint' => 'Cerca obiettivi, abitudini, impostazioni, azioni…',
			'palette.groupSuggested' => 'Suggeriti',
			'palette.groupThisWeek' => 'Questa settimana',
			'palette.groupGoals' => 'Obiettivi',
			'palette.groupHabits' => 'Abitudini',
			'palette.groupActions' => 'Azioni',
			'palette.groupSections' => 'Vai a',
			'palette.groupSettings' => 'Impostazioni',
			'palette.goToThisWeek' => 'Vai a questa settimana',
			'palette.createGoalBlank' => 'Crea obiettivo',
			'palette.createGoal' => ({required Object title}) => 'Crea obiettivo «${title}»',
			'palette.createHabit' => ({required Object title}) => 'Crea abitudine «${title}»',
			'palette.goToPeriod' => ({required Object period}) => 'Vai a ${period}',
			'palette.switchToDark' => 'Passa al tema scuro',
			'palette.switchToLight' => 'Passa al tema chiaro',
			'palette.manageCategories' => 'Gestisci categorie obiettivi',
			'palette.replayTour' => 'Rivedi il tour guidato',
			'palette.noResults' => ({required Object query}) => 'Nessun risultato per «${query}»',
			'palette.rowOpen' => 'Apri',
			'palette.rowComplete' => 'Segna come completato',
			'palette.rowReschedule' => 'Riprogramma al periodo successivo',
			'palette.deleteGoalTitle' => 'Eliminare l\'obiettivo?',
			'palette.deleteGoalMessage' => ({required Object title}) => '«${title}» verrà eliminato definitivamente.',
			'palette.deleteHabitTitle' => 'Eliminare l\'abitudine?',
			'palette.deleteHabitMessage' => ({required Object title}) => '«${title}» verrà eliminata definitivamente.',
			'palette.footerNavigate' => 'naviga',
			'palette.footerOpen' => 'apri',
			'palette.footerMenu' => 'menu',
			'palette.footerClose' => 'chiudi',
			'targets.sectionTitle' => 'Obiettivo',
			'targets.none' => 'Semplice',
			'targets.atLeastLabel' => 'Raggiungi',
			'targets.atMostLabel' => 'Resta sotto',
			'targets.presets.countDaily.label' => 'Conteggio',
			'targets.presets.countDaily.description' => 'Fallo un certo numero di volte al giorno.',
			'targets.presets.durationDaily.label' => 'Durata',
			'targets.presets.durationDaily.description' => 'Dedica un certo numero di minuti al giorno.',
			'targets.presets.limitCountDaily.label' => 'Limite',
			'targets.presets.limitCountDaily.description' => 'Resta sotto un certo numero ogni giorno.',
			'targets.presets.limitDurationDaily.label' => 'Limite di tempo',
			'targets.presets.limitDurationDaily.description' => 'Resta sotto un certo numero di minuti al giorno.',
			'targets.units.min' => 'min',
			'targets.units.hour' => 'h',
			'targets.units.kcal' => 'kcal',
			'targets.units.km' => 'km',
			'targets.entry.keepGoing' => 'Continua così',
			'targets.entry.withinLimit' => 'Entro il limite',
			'targets.entry.overLimit' => 'Oltre il limite',
			'targets.amountLabel' => 'Raggiungi',
			'targets.amountLabelAtMost' => 'Resta sotto',
			'targets.stepLabel' => 'Passo',
			'targets.stepHint' => ({required Object step}) => 'Ogni + aggiunge ${step}',
			'targets.rangeError' => ({required Object min, required Object max}) => 'Inserisci un numero tra ${min} e ${max}',
			'targets.stepPositiveError' => 'Il passo deve essere maggiore di 0',
			'targets.stepExceedsWarning' => 'Un solo tocco supererebbe l\'intero obiettivo',
			'targets.notDivisibleWarning' => ({required Object amount, required Object below, required Object above}) => 'Non puoi arrivare esattamente a ${amount} — i tocchi raggiungono ${below} poi ${above}',
			'targets.notDivisibleWarningNoBelow' => ({required Object amount, required Object above}) => 'Non puoi arrivare esattamente a ${amount} — il primo tocco raggiunge ${above}',
			'targets.tooManyTapsWarning' => ({required Object taps}) => 'Servono ${taps} tocchi per completare un giorno',
			'targets.confirmTitle' => 'Controlla il tuo obiettivo',
			'targets.confirmAdjust' => 'Modifica',
			'targets.confirmSaveAnyway' => 'Salva comunque',
			'trackingMode.title' => 'Come viene monitorata?',
			'trackingMode.checkbox' => 'Spunta',
			'trackingMode.number' => 'Numero',
			'trackingMode.automatic' => 'Automatica',
			'trackingMode.automaticLocked' => 'Verificata — modifica su iPhone',
			_ => null,
		};
	}
}
