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
class TranslationsEs extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsEs({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.es,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <es>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsEs _root = this; // ignore: unused_field

	@override 
	TranslationsEs $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsEs(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$macroTargets$es macroTargets = _Translations$macroTargets$es._(_root);
	@override late final _Translations$auth$es auth = _Translations$auth$es._(_root);
	@override late final _Translations$privateData$es privateData = _Translations$privateData$es._(_root);
	@override late final _Translations$icloudSync$es icloudSync = _Translations$icloudSync$es._(_root);
	@override late final _Translations$privateRecovery$es privateRecovery = _Translations$privateRecovery$es._(_root);
	@override late final _Translations$namePrompt$es namePrompt = _Translations$namePrompt$es._(_root);
	@override late final _Translations$nav$es nav = _Translations$nav$es._(_root);
	@override late final _Translations$shell$es shell = _Translations$shell$es._(_root);
	@override late final _Translations$common$es common = _Translations$common$es._(_root);
	@override late final _Translations$form$es form = _Translations$form$es._(_root);
	@override late final _Translations$createGoal$es createGoal = _Translations$createGoal$es._(_root);
	@override late final _Translations$createHabit$es createHabit = _Translations$createHabit$es._(_root);
	@override late final _Translations$macroGoals$es macroGoals = _Translations$macroGoals$es._(_root);
	@override late final _Translations$statistics$es statistics = _Translations$statistics$es._(_root);
	@override late final _Translations$goalState$es goalState = _Translations$goalState$es._(_root);
	@override late final _Translations$dueLabel$es dueLabel = _Translations$dueLabel$es._(_root);
	@override late final _Translations$dashboard$es dashboard = _Translations$dashboard$es._(_root);
	@override late final _Translations$stats$es stats = _Translations$stats$es._(_root);
	@override late final _Translations$habitsPage$es habitsPage = _Translations$habitsPage$es._(_root);
	@override String get lavoro => 'Trabajo';
	@override String get salute => 'Salud';
	@override String get finanza => 'Finanzas';
	@override String get relazioni => 'Relaciones';
	@override String get formazione => 'Formación';
	@override String get hobby => 'Hobby';
	@override String get spirituale => 'Espiritualidad';
	@override String get altro => 'Otro';
	@override late final _Translations$goalsPage$es goalsPage = _Translations$goalsPage$es._(_root);
	@override late final _Translations$goalsStats$es goalsStats = _Translations$goalsStats$es._(_root);
	@override late final _Translations$ai$es ai = _Translations$ai$es._(_root);
	@override late final _Translations$aiCoach$es aiCoach = _Translations$aiCoach$es._(_root);
	@override late final _Translations$settingsPage$es settingsPage = _Translations$settingsPage$es._(_root);
	@override late final _Translations$consent$es consent = _Translations$consent$es._(_root);
	@override late final _Translations$notifications$es notifications = _Translations$notifications$es._(_root);
	@override late final _Translations$privacy$es privacy = _Translations$privacy$es._(_root);
	@override late final _Translations$consentPage$es consentPage = _Translations$consentPage$es._(_root);
	@override late final _Translations$notif$es notif = _Translations$notif$es._(_root);
	@override late final _Translations$biometricGate$es biometricGate = _Translations$biometricGate$es._(_root);
	@override late final _Translations$sync$es sync = _Translations$sync$es._(_root);
	@override late final _Translations$subscriptionCtrl$es subscriptionCtrl = _Translations$subscriptionCtrl$es._(_root);
	@override late final _Translations$authCtrl$es authCtrl = _Translations$authCtrl$es._(_root);
	@override late final _Translations$proModal$es proModal = _Translations$proModal$es._(_root);
	@override late final _Translations$appLogs$es appLogs = _Translations$appLogs$es._(_root);
	@override late final _Translations$coachSettings$es coachSettings = _Translations$coachSettings$es._(_root);
	@override late final _Translations$tour$es tour = _Translations$tour$es._(_root);
	@override late final _Translations$palette$es palette = _Translations$palette$es._(_root);
	@override late final _Translations$targets$es targets = _Translations$targets$es._(_root);
}

// Path: macroTargets
class _Translations$macroTargets$es extends Translations$macroTargets$en {
	_Translations$macroTargets$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get sectionTitle => 'Objetivo numérico';
	@override String get none => 'Ninguno';
	@override String get amountLabel => 'Valor objetivo';
	@override String get linkLabel => 'Vincular un hábito';
	@override String get manual => 'Manual';
	@override String get unitCount => 'recuento';
	@override String get reached => 'Alcanzado';
}

// Path: auth
class _Translations$auth$es extends Translations$auth$en {
	_Translations$auth$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get continuePrivately => 'Continúa en modo privado en este Mac';
	@override String get signIn => 'Iniciar sesión';
	@override String get register => 'Regístrate';
	@override String get or => 'O';
	@override String get password => 'Contraseña';
	@override String get forgotPassword => '¿Olvidaste tu contraseña?';
	@override String get haveAccount => '¿Ya tienes una cuenta?';
	@override String get noAccount => '¿No tienes una cuenta?';
	@override String get continueWithApple => 'Continuar con Apple';
	@override String get continueWithGoogle => 'Continuar con Google';
	@override String get readPrivacyPolicy => 'Leer política de privacidad';
	@override String get nameLabel => 'Nombre';
	@override String get invalidEmail => 'Introduce un email válido';
	@override String get confirmEmail => 'Revisa tu email para confirmar el registro.';
	@override String get resetSent => 'Email enviado. Revisa tu bandeja de entrada.';
	@override String get signInTitle => 'Inicia sesión en Evolve';
	@override String get signUpTitle => 'Crea tu cuenta';
	@override String get resetTitle => 'Recuperar contraseña';
	@override String get emailLabel => 'Correo electrónico';
	@override String get passwordMin8 => 'Usa al menos 8 caracteres.';
	@override String get sendResetLink => 'Enviar enlace de recuperación';
}

// Path: privateData
class _Translations$privateData$es extends Translations$privateData$en {
	_Translations$privateData$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get deleteTitle => 'Eliminar datos privados';
	@override String get deleteMessage => '¿Seguro que quieres eliminar toda la base de datos local cifrada? Esta acción es irreversible y los datos no se podrán recuperar.';
	@override String get deleteSuccess => 'Datos privados eliminados.';
	@override String get deleteFailed => 'La operación ha fallado.';
	@override String get exportDoneTitle => 'Exportación completada';
	@override String get exportDoneClipboard => 'El JSON está en el portapapeles: Linux no admite compartir archivos.';
	@override String get exportDoneShare => 'El JSON se envió al selector de uso compartido.';
}

// Path: icloudSync
class _Translations$icloudSync$es extends Translations$icloudSync$en {
	_Translations$icloudSync$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sincronización de iCloud';
	@override String get enableTitle => 'Activar sincronización de iCloud';
	@override String get syncNow => 'Sincronizar ahora';
	@override String get disclosureTitle => 'Cifrado de extremo a extremo';
	@override String get disclosureBody => 'Tus datos privados se sincronizan únicamente a través de tu propia cuenta de iCloud, con cifrado de extremo a extremo, nunca a través de nuestros servidores. La clave de cifrado reside en tu Llavero de iCloud; si desactivas el Llavero de iCloud, los datos sincronizados no podrán recuperarse.';
	@override String get disclosureAccept => 'Activar';
	@override String get statusIdle => 'Actualizado';
	@override String get statusNotSynced => 'No se ha sincronizado todo';
	@override String get statusSyncing => 'Sincronizando…';
	@override String get statusOff => 'Sincronización desactivada';
	@override String get statusNoAccount => 'Inicia sesión en iCloud para sincronizar';
	@override String get statusUnavailable => 'iCloud no está disponible ahora';
	@override String get statusWaitingKeychain => 'Esperando el Llavero de iCloud — asegúrate de que la app de tu iPhone esté actualizada';
	@override String get lastSyncedNever => 'Nunca sincronizado';
	@override String lastSyncedAt({required Object time}) => 'Última sincronización ${time}';
	@override String get deleteSyncNote => 'La sincronización de iCloud está activada: también se eliminará la copia sincronizada de tu iCloud y se desactivará la sincronización. Los demás dispositivos conservan su copia local — ejecuta esta acción en cada dispositivo para borrarlo todo en todas partes.';
	@override String get bannerText => 'La sincronización con iCloud está desactivada: tus hábitos solo están en este dispositivo y se perderán si lo restableces o lo reemplazas.';
	@override String get bannerAction => 'Activar';
	@override String get detailsTitle => 'Detalles de sincronización';
	@override String get detailsAllSynced => 'Todo subido';
	@override String detailsPending({required Object count}) => '${count} elementos pendientes de subir';
	@override String detailsFailed({required Object count}) => '${count} elementos no se han subido';
	@override String get detailsCopy => 'Copiar informe';
	@override String get detailsCopied => 'Informe copiado';
	@override String get keySplitTitle => 'Algunos datos de iCloud no se pueden leer';
	@override String keySplitBody({required Object count}) => '${count} registros en iCloud se cifraron en otro dispositivo con una clave distinta, por lo que este dispositivo no puede leerlos. Restablece la sincronización desde el dispositivo que tenga los datos que quieres conservar.';
	@override String get resetFromDevice => 'Restablecer la sincronización desde este dispositivo';
	@override String get resetFromDeviceDetail => 'Sustituir todo lo que hay en iCloud por los datos de este dispositivo';
	@override String get resetFromDeviceConfirm => 'Esto borra todo lo almacenado actualmente en iCloud y sube en su lugar los datos de este dispositivo. Tus otros dispositivos descargarán después esta copia. Hazlo solo desde el dispositivo que tenga los datos que quieres conservar. No se puede deshacer.';
	@override String get resetFromDeviceDone => 'Sincronización restablecida. Los datos de este dispositivo son ahora la copia en iCloud.';
	@override String get statusWaitingKey => 'Esperando la clave de cifrado de tu otro dispositivo';
	@override String get forceEnableTitle => 'Empezar de cero desde este dispositivo';
	@override String get forceEnableBody => 'Los datos de otro dispositivo ya están en iCloud, pero su clave de cifrado aún no ha llegado a este dispositivo. Normalmente basta con esperar unos minutos. Empezar de cero borra lo que hay en iCloud y lo sustituye por los datos de este dispositivo. No se puede deshacer.';
	@override String get forceEnable => 'Empezar de cero';
}

// Path: privateRecovery
class _Translations$privateRecovery$es extends Translations$privateRecovery$en {
	_Translations$privateRecovery$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get preparing => 'Preparando tu espacio privado…';
	@override String get restoredFromCloudToast => 'No se pudo desbloquear la base de datos local: tus datos se restauraron desde iCloud.';
	@override String get waitingTitle => 'Esperando a iCloud';
	@override String get waitingMessage => 'La sincronización está activada, pero tu clave de cifrado aún no ha llegado desde el Llavero de iCloud. Espera un momento y vuelve a intentarlo.';
	@override String get lockedTitle => 'No se pueden desbloquear los datos privados';
	@override String get lockedMessageLocalOnly => 'Este dispositivo no puede desbloquear tu base de datos privada local —falta su clave de cifrado— y la sincronización de iCloud está desactivada, así que no hay copia en la nube para restaurar. Puedes restablecer y empezar de nuevo.';
	@override String get lockedMessageICloudUnavailable => 'Este dispositivo no puede desbloquear tu base de datos privada local. La sincronización de iCloud está activada, pero la cuenta no está disponible: inicia sesión en iCloud y vuelve a intentarlo.';
	@override String get errorTitle => 'No se pudo abrir el modo privado';
	@override String get errorMessage => 'Algo salió mal al abrir tu base de datos privada. Vuelve a intentarlo o restablécela y empieza de nuevo.';
	@override String get enableSyncHint => '¿Tienes estos datos en otro dispositivo? Activa la sincronización de iCloud en Ajustes después de restablecer para traerlos aquí.';
	@override String get retry => 'Reintentar';
	@override String get resetFresh => 'Restablecer y empezar de nuevo';
	@override String get backToSignIn => 'Volver al inicio de sesión';
}

// Path: namePrompt
class _Translations$namePrompt$es extends Translations$namePrompt$en {
	_Translations$namePrompt$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => '¿Cómo te llamas?';
	@override String get subtitle => 'Introduce tu nombre para personalizar el panel.';
	@override String get hint => 'Ej. Simo';
	@override String get save => 'Guardar y continuar';
}

// Path: nav
class _Translations$nav$es extends Translations$nav$en {
	_Translations$nav$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get overview => 'Resumen';
	@override String get habits => 'Hábitos';
	@override String get insights => 'Estadísticas';
	@override String get goals => 'Objetivos';
	@override String get coach => 'Coach AI';
	@override String get settings => 'Ajustes';
}

// Path: shell
class _Translations$shell$es extends Translations$shell$en {
	_Translations$shell$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get syncPending => 'Sincronización pendiente';
	@override String get syncing => 'Sincronizando';
	@override String get synced => 'Sincronizado';
	@override String get syncTooltip => 'Sincronizar';
	@override String get searchHint => 'Buscar o navegar';
	@override String get searchSectionHint => 'Buscar una sección...';
}

// Path: common
class _Translations$common$es extends Translations$common$en {
	_Translations$common$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$common$actions$es actions = _Translations$common$actions$es._(_root);
	@override List<String> get months => [
		'Enero',
		'Febrero',
		'Marzo',
		'Abril',
		'Mayo',
		'Junio',
		'Julio',
		'Agosto',
		'Septiembre',
		'Octubre',
		'Noviembre',
		'Diciembre',
	];
	@override List<String> get weekdayInitials => [
		'L',
		'M',
		'X',
		'J',
		'V',
		'S',
		'D',
	];
	@override late final _Translations$common$calendarView$es calendarView = _Translations$common$calendarView$es._(_root);
	@override List<String> get weekdaysLong => [
		'Lunes',
		'Martes',
		'Miércoles',
		'Jueves',
		'Viernes',
		'Sábado',
		'Domingo',
	];
	@override String get none => 'Ninguno';
	@override String get habits => 'Hábitos';
	@override late final _Translations$common$status$es status = _Translations$common$status$es._(_root);
	@override String get total => 'Total';
	@override String get completed => 'Completados';
	@override String get unexpectedErrorTitle => 'Algo salió mal';
	@override String get unexpectedErrorMessage => 'Se ha producido un error inesperado. Inténtalo de nuevo.';
}

// Path: form
class _Translations$form$es extends Translations$form$en {
	_Translations$form$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Título';
	@override String get category => 'Categoría';
	@override String get color => 'Color';
	@override String get add => 'Añadir';
}

// Path: createGoal
class _Translations$createGoal$es extends Translations$createGoal$en {
	_Translations$createGoal$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Nuevo objetivo';
	@override String get subtitle => 'Define tu próximo objetivo.';
	@override String get titleHint => 'p. ej. Lanzar el nuevo producto';
	@override String get categoryHint => 'p. ej. Trabajo';
	@override String get timeline => 'Cronología';
	@override String get thisWeek => 'Esta semana';
	@override String get thisMonth => 'Este mes';
	@override String get thisQuarter => 'Este trimestre';
	@override String get thisYear => 'Este año';
	@override String get longTerm => 'A largo plazo (Lifetime)';
	@override String get dueLifetime => 'Toda la vida';
	@override String dueByYear({required Object year}) => 'Antes de ${year}';
	@override String get defaultCategory => 'Objetivo';
	@override String get periodWhen => 'Cuándo';
}

// Path: createHabit
class _Translations$createHabit$es extends Translations$createHabit$en {
	_Translations$createHabit$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Nuevo hábito';
	@override String get subtitle => 'Define tu nuevo hábito.';
	@override String get titleHint => 'p. ej. Meditación';
	@override String get weeklyFrequency => 'Frecuencia semanal';
}

// Path: macroGoals
class _Translations$macroGoals$es extends Translations$macroGoals$en {
	_Translations$macroGoals$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$macroGoals$types$es types = _Translations$macroGoals$types$es._(_root);
	@override String quarterNumber({required Object quarter}) => 'Trimestre ${quarter}';
	@override String get addLifetimeGoal => 'Añadir objetivo de por vida...';
	@override String get addAnnualGoal => 'Añadir objetivo anual...';
	@override String get addQuarterlyGoal => 'Añadir objetivo trimestral...';
	@override String get addMonthlyGoal => 'Agregar objetivo mensual...';
	@override String get addWeeklyGoal => 'Añadir objetivo semanal...';
	@override String get completed => 'TERMINADO';
	@override String get failed => 'FALLIDO';
	@override String get create => 'Crear';
	@override String get strength => 'Punto fuerte';
	@override String get bestMonth => 'Mejor mes';
	@override String get successRate2 => 'tasa de éxito';
	@override String get effectiveType => 'Tipología eficaz';
	@override String get historicalTotal => 'Total histórico';
	@override String get from_ => 'de';
	@override String get globalSuccess => 'Éxito global';
	@override String get completedGoals => 'Objetivos completados';
	@override String get bestYear => 'Mejor año';
	@override String get mostProductiveYear => 'Año más productivo';
	@override String get totalGoals => 'Objetivos totales';
	@override String get allYears => 'Todos los años';
	@override String get selectYearHeader => 'Seleccionar año';
	@override String get completions => 'Completados';
	@override String get success2 => 'Éxito';
	@override String get archiveCategory2 => 'Archivar categoría';
	@override String categoryUnavailableLinked({required Object label, required Object count}) => 'La categoría "${label}" ya no estará disponible para nuevos objetivos, pero seguirá vinculada a ${count} objetivos históricos y a tus estadísticas.';
	@override String categoryUnavailableArchived({required Object label}) => 'La categoría "${label}" ya no estará disponible para nuevos objetivos, pero permanecerá en tu historial.';
	@override String get archive => 'Archivar';
	@override String get createNewCategory => 'Crear nueva categoría';
}

// Path: statistics
class _Translations$statistics$es extends Translations$statistics$en {
	_Translations$statistics$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get completed2 => 'Completado';
	@override String get notCompleted => 'No completado';
	@override String get ofCompletion => 'de completitud';
	@override String get growth => 'Crecimiento';
	@override String get decline => 'Descenso';
	@override String get strongestDay => 'Día más fuerte';
	@override String get weakestDay => 'Día más débil';
	@override String get worstNegativeStreak => 'Peor racha negativa';
	@override String get missedConsecutiveDays => 'días consecutivos fallados';
	@override String get brokenStreaks => 'Rachas interrumpidas';
	@override String get noBrokenStreaks => 'No se registraron rachas interrumpidas';
	@override String get startedOn => 'iniciada el';
	@override String get moodCorrelation => 'Correlación con el ánimo';
	@override String get avgMood => 'Ánimo medio (✓)';
	@override String get avgEnergy => 'Energía media (✓)';
	@override String get onCompletedDays => 'en los días completados';
	@override String get resilient => 'Resiliente';
	@override String get completedVsMissed => 'Completado vs fallado';
	@override String get mood2 => 'Estado de ánimo';
	@override String get energy => 'Energía';
	@override String get performancePerLevel => 'Rendimiento por nivel';
	@override String get withHighMood => 'Con ánimo alto';
	@override String get withLowMood => 'Con ánimo bajo';
	@override String get moodEnergyAnalysis => 'El análisis muestra cómo tu constancia se ve influida por tu estado de ánimo y energía.';
	@override String get missed2 => 'Fallado';
	@override String get positive => 'positiva';
	@override String get neutral => 'neutra';
	@override String get high => 'alta';
	@override String get low => 'baja';
	@override String get skipped => 'Omitido';
	@override String get criticalHabits => 'Hábitos críticos';
	@override String get bestHabitsTitle => 'Mejores hábitos';
	@override String get worseningHabitsDescription => 'Hábitos que están empeorando.';
	@override String get everythingIsGreat => 'Todo va bien';
	@override String get allHabitsStableDescription => 'Todos tus hábitos mantienen o mejoran su tendencia. Sigue avanzando.';
	@override String habitCompletionPeriodDescription({required Object rate}) => 'Completaste este hábito el ${rate}% de las veces en el periodo seleccionado.';
	@override String habitLostConsistencyDescription({required Object drop}) => 'Este hábito perdió un ${drop}% de constancia en la última semana respecto a la anterior.';
	@override String get negativeStreak => 'Racha negativa';
	@override String get currentStreak2 => 'Racha actual';
	@override String get improvementAreas => 'Áreas de mejora';
	@override String get habitsRequiringMoreAttention => 'Hábitos que requieren más atención.';
	@override String get failureAnalysis => 'Análisis de fallos';
	@override String get missedDaysPattern => 'Frecuencia y patrones de tus días fallados.';
	@override String get recoveryPatterns => 'Patrones de recuperación';
	@override String get recoverySpeed => 'Qué tan rápido vuelves al camino tras un fallo.';
	@override String get avgRecoveryTime => 'Tiempo medio de recuperación';
	@override String get worstStreak => 'Peor racha';
	@override String get frequency => 'FRECUENCIA';
	@override String get daysShortUnit => 'd';
	@override String get perMonthUnit => 'mes';
	@override String get succ => 'éxito';
	@override String get blackDay => 'DÍA CRÍTICO';
	@override String get correlationsWith => 'Correlaciones con';
	@override String get howThisHabitRelatesToOthers => 'Cómo se relaciona este hábito con los demás';
	@override String get positiveCorrelations => 'Correlaciones positivas';
	@override String get negativeCorrelations => 'Correlaciones negativas';
	@override String get noSignificantPositiveCorrelation => 'Sin correlación positiva significativa';
	@override String get noSignificantNegativeCorrelation => 'Sin correlación negativa significativa';
	@override String habitTogetherPercent({required Object percentage}) => '${percentage}% juntas';
	@override String habitPositiveCorrelationDescription({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'Cuando completas "${currentGoal}", tienes un ${percentage}% de probabilidad de completar también "${otherGoal}".';
	@override String habitNegativeCorrelationDescription({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'Cuando completas "${currentGoal}", solo tienes un ${percentage}% de probabilidad de completar también "${otherGoal}".';
	@override String get weeklyTrend => 'Tendencia semanal';
	@override String get monthlyTrend => 'Tendencia mensual';
	@override String get yearlyTrend => 'Tendencia anual';
	@override String get performanceEvolution => 'Evolución del rendimiento';
	@override String get globalTrend => 'Tendencia mundial';
	@override String get total => 'Total';
	@override String get all => 'Todo';
	@override String get noDataForAlerts => 'No hay datos suficientes para generar alertas.';
	@override String get missed => 'Fallados';
}

// Path: goalState
class _Translations$goalState$es extends Translations$goalState$en {
	_Translations$goalState$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get active => 'En curso';
}

// Path: dueLabel
class _Translations$dueLabel$es extends Translations$dueLabel$en {
	_Translations$dueLabel$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get lifetime => 'Objetivo de vida';
	@override String get annual => 'Objetivo anual';
	@override String get quarter => 'Trimestre';
}

// Path: dashboard
class _Translations$dashboard$es extends Translations$dashboard$en {
	_Translations$dashboard$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get mood => 'Estado de ánimo';
	@override String get energy => 'Energía';
	@override String get goodMorning => 'Buenos días';
	@override String get goodAfternoon => 'Buenas tardes';
	@override String get goodEvening => 'Buenas noches';
	@override String get manager => 'Gestión';
	@override String get aiChat => 'Chat AI';
	@override String get consecutiveDays => 'días consecutivos';
	@override String get welcomeTitle => 'Bienvenido a Evolve';
	@override String get welcomeSubtitle => 'Comienza tu camino de crecimiento personal.';
	@override String get welcomeBody => 'Esta aplicación te ayuda a crear buenos hábitos y alcanzar tus objetivos a largo plazo.';
	@override String get welcomeStart => 'Comenzar';
	@override String get subtitle => 'Mantén el ritmo. Cada pequeña acción refuerza a la persona que estás construyendo.';
	@override String get completionToday => 'Completado hoy';
	@override String habitsCount({required Object done, required Object total}) => '${done}/${total} hábitos';
	@override String get bestStreak => 'Mejor racha';
	@override String get activeGoals => 'Objetivos activos';
	@override String avgProgress({required Object pct}) => '${pct}% progreso medio';
	@override String get momentum => 'Momentum';
	@override String get vsLastWeek => 'respecto a la semana pasada';
	@override String get weeklyTrend => 'Tendencia semanal';
	@override String get weeklyTrendSubtitle => 'Porcentaje de finalización de tus hábitos';
	@override String thisWeekPill({required Object value}) => '${value} esta semana';
	@override String get todayProtocol => 'Protocolo de hoy';
	@override String get todayProtocolSubtitle => 'Completa las acciones esenciales antes de añadir más';
	@override String actionsCount({required Object count}) => '${count} acciones';
	@override String get emptyHabits => 'Tu lienzo está vacío. Crea tu primer hábito.';
	@override String streakDaysShort({required Object n}) => '${n} d';
	@override String get checkInDone => 'Registro guardado';
	@override String get checkInPrompt => '¿Cómo te sientes hoy?';
	@override String moodEnergyValue({required Object mood, required Object energy}) => 'Ánimo ${mood}/10 · Energía ${energy}/10';
	@override String get checkInHint => 'Registra el ánimo y la energía para mejorar el análisis de tus patrones.';
	@override String get updateCheckIn => 'Actualizar registro';
	@override String get doCheckIn => 'Hacer el registro';
	@override String get dailyCheckIn => 'Registro diario';
	@override String get dailyCheckInSubtitle => 'Una medición rápida ayuda a Evolve a entender mejor tus patrones.';
	@override String get record => 'Guardar';
	@override String get focusGoals => 'Objetivos en foco';
	@override String get currentPriorities => 'Prioridades actuales';
	@override String get goalLimitReached => 'Límite de 100 objetivos alcanzado. Pasa a Pro para crear más.';
	@override String get emptyFocusGoals => 'No hay objetivos en foco. Añade uno.';
	@override String get weekToStart => 'Semana por empezar';
	@override String get weekGrowing => 'Semana en crecimiento';
	@override String get weekToRecover => 'Semana por recuperar';
	@override String vsPreviousWeek({required Object value}) => '${value} respecto a la semana anterior.';
}

// Path: stats
class _Translations$stats$es extends Translations$stats$en {
	_Translations$stats$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Estadísticas';
	@override String get global => 'Global';
	@override String get resilience => 'Resiliencia';
	@override String get tabHabits => 'Hábitos';
	@override String get tabMood => 'Estado de ánimo';
	@override String get last30Days => 'Últimos 30 días';
	@override String get singleHabit => 'Hábito individual';
	@override String get noHabit => 'Sin hábito';
	@override String get completionToday => 'Completado hoy';
	@override String get bestStreakLabel => 'Mejor racha';
	@override String get criticalDay => 'Día crítico';
	@override String get completePrioritiesFirst => 'Completa primero las prioridades';
	@override String get recentActivity => 'Actividad reciente';
	@override String get recentActivitySubtitle => 'Intensidad de finalización en los últimos 90 días';
	@override String get trendGlobal => 'Tendencia global';
	@override String get trendGlobalSubtitle => 'Comparación temporal del protocolo';
	@override String vsPrevDay({required Object value}) => '${value}% vs día anterior';
	@override String get bestHabit => 'Mejor hábito';
	@override String get criticalArea => 'Área crítica';
	@override String get streakAtRisk => 'Racha en riesgo';
	@override String streakAtRiskDetail({required Object habit}) => '${habit} requiere atención en los próximos registros.';
	@override String get patternToConsolidate => 'Patrón por consolidar';
	@override String get checkLowMoodDays => 'Revisa los días de ánimo bajo y mantén el protocolo esencial.';
	@override String get goalDue => 'Objetivo por vencer';
	@override String get noGoalNeedsIntervention => 'Ningún objetivo activo requiere intervención.';
	@override String get performancePerHabit => 'Rendimiento por hábito';
	@override String get performancePerHabitSubtitle => 'Clasificación calculada a partir de los registros sincronizados por consistencia semanal';
	@override String get avgMood => 'Ánimo medio';
	@override String get avgEnergy => 'Energía media';
	@override String checkInsAvailable({required Object count}) => '${count} registros disponibles';
	@override String get resilientHabit => 'Hábito resiliente';
	@override String get completedEvenHardDays => 'Completada incluso en días difíciles';
	@override String get moodEnergy => 'Ánimo y energía';
	@override String get moodEnergySubtitle => 'Promedio de los registros disponibles en los últimos 90 días';
	@override String get completion => 'Finalización';
	@override String get currentWeek => 'Semana actual';
	@override String get currentStreak => 'Racha actual';
	@override String get currentStreakDetail => 'Racha sincronizada de los registros disponibles';
	@override String get trend30 => 'Tendencia 30 días';
	@override String get trend30Detail => 'Finalización en los últimos 30 días';
	@override String get yearlyCalendar => 'Calendario anual';
	@override String yearlyCalendarSubtitle({required Object habit}) => 'Distribución de finalizaciones de ${habit}';
	@override String get performancePerDay => 'Rendimiento por día';
	@override String get performancePerDaySubtitle => 'Días fuertes y débiles de la semana';
	@override String protectStreak({required Object days}) => 'Protege la racha de ${days} días';
	@override String get keepSameSlot => 'Mantén la misma franja horaria para reducir la fricción en los días más intensos.';
	@override String worstNegativeSeq({required Object days}) => 'La peor racha negativa duró ${days} días.';
	@override String get positiveLever => 'Palanca positiva detectada';
	@override String bestHabitRegularity({required Object habit}) => '${habit} mantiene la mejor regularidad reciente.';
	@override String get moodSensitivity => 'Sensibilidad al ánimo';
	@override String get lowEnergyCompletion => 'Finalización con energía baja';
	@override String get moodOutputCorrelation => 'Correlación ánimo-rendimiento';
	@override String get moodOutputSubtitle => 'Finalizaciones disponibles en los días con registro';
	@override String get keyCorrelations => 'Correlaciones clave';
	@override String get keyCorrelationsSubtitle => 'Patrones que más influyen en el protocolo';
	@override String get moreLogsNeeded => 'Se necesitan más registros para calcular correlaciones útiles.';
	@override String get createHabitForAnalysis => 'Crea al menos un hábito para ver el análisis granular.';
	@override String get noData => 'Sin datos';
	@override String get tabInfo => 'Info';
	@override String get tabTrend => 'Tendencia';
	@override String get tabAlerts => 'Alertas';
	@override String get tabOverview => 'Resumen';
	@override String get tabCalendar => 'Calendario';
	@override String get tabPerformance => 'Rendimiento';
	@override String get tabImprovement => 'Mejora';
	@override String get pageSubtitle => 'Identifica los patrones que impulsan el crecimiento y actúa en las áreas críticas.';
	@override String actionsFraction({required Object done, required Object total}) => '${done}/${total} acciones';
	@override String affectedByHardDays({required Object habit}) => '${habit} se ve afectado por los días difíciles';
	@override String get last30DaysTrend => 'Tendencia de los últimos 30 días';
	@override String strongestDayDetail({required Object pct, required Object done, required Object total}) => 'Bien hecho, ${pct}% de finalizacion (${done}/${total})';
	@override String weakestDayDetail({required Object pct, required Object done, required Object total}) => 'Solo ${pct}% de finalizacion (${done}/${total})';
	@override String brokenStreakItem({required Object days}) => 'Racha de ${days} dias interrumpida';
	@override String togetherProbability({required Object percentage}) => '${percentage}% juntos';
	@override String get criticalHabitsSubtitle => 'Hábitos que están empeorando.';
	@override String get bestHabitsSubtitle => 'Los habitos en los que eres mas constante.';
	@override String get timeframeWeek => 'Semana';
	@override String get timeframeMonth => 'Mes';
	@override String get timeframeYear => 'Año';
	@override String get timeframeAll => 'Todo';
	@override String negativeStreakDays({required Object days}) => '${days} dias sin completar';
	@override String dropPercent({required Object drop}) => '-${drop}%';
	@override String blackDayDetail({required Object day}) => 'Dia negro: ${day}';
	@override String failureDetail({required Object streak, required Object frequency}) => 'Peor racha: ${streak}d · ~${frequency}/mes perdidos';
	@override String recoveryDetail({required Object days}) => 'Tiempo medio de recuperacion: ${days} dias';
	@override String successRate({required Object rate}) => '${rate}% exito';
	@override String get sortRate => 'Porcentaje';
	@override String get sortStreak => 'Racha';
	@override String get sortName => 'Nombre';
	@override String get filterActive => 'Activos';
	@override String get filterAll => 'Todos';
	@override String get noActiveHabits => 'No hay hábitos activos. Cambia a Todos para ver los finalizados.';
	@override String get worstStreakLabel => 'Peor';
	@override String get momentumTitle => 'Impulso';
	@override String get momentumSubtitle => 'Tu forma actual';
	@override String get momentumForm => 'FORMA';
	@override String get momentumRate => '7 días';
	@override String get momentumStreakHealth => 'Rachas';
	@override String get momentumTrend => 'Tendencia';
	@override String get rollingImproving => 'Mejorando';
	@override String get rollingDeclining => 'Bajando';
	@override String get rollingSteady => 'Estable';
	@override String get lifetimeConsistency => 'Constancia';
	@override String get lifetimeConsistencyDetail => 'Completado histórico';
	@override String get lifetimeTotalDone => 'Total completado';
	@override String get lifetimeTotalDoneDetail => 'Hábitos marcados';
	@override String get lifetimePerfectDays => 'Días perfectos';
	@override String get lifetimePerfectDaysDetail => 'Todo completado';
	@override String get lifetimeDaysTracked => 'Días registrados';
	@override String get lifetimeDaysTrackedDetail => 'Desde que empezaste';
	@override String get keystoneTitle => 'HÁBITO CLAVE';
	@override String keystoneImpact({required Object withPct, required Object withoutPct}) => 'En sus días completas el ${withPct}% de tus otros hábitos, frente al ${withoutPct}%.';
	@override String get yearActivity => 'Actividad de 365 días';
	@override String get yearActivitySubtitle => 'Cada hábito, cada día';
	@override String activeDaysCount({required Object count}) => '${count} días activos';
	@override String get heatmapLess => 'Menos';
	@override String get heatmapMore => 'Más';
	@override String get bestHabitsTitle => 'Mejores hábitos';
	@override String get criticalHabitsTitle => 'Requiere atención';
	@override String criticalStalled({required Object days}) => '${days}d parado';
	@override String get rollingTitle => 'Completado móvil';
	@override String get rollingSubtitle => 'Tasa de 7 y 30 días';
	@override String get rolling7 => '7 días';
	@override String get rolling30 => '30 días';
	@override String get weekVsAvgTitle => 'Esta semana vs media';
	@override String get weekVsAvgSubtitle => 'Cómo va esta semana';
	@override String get thisWeek => 'Esta semana';
	@override String get yourAverage => 'Tu media';
	@override String get weekdayShapeTitle => 'Ritmo semanal';
	@override String get weekdayShapeSubtitle => 'Completado por día';
	@override String get weekdayWeekendTitle => 'Semana vs fin de semana';
	@override String get weekdayWeekendSubtitle => 'Dónde eres más fuerte';
	@override String get weekdaysLabel => 'Entre semana';
	@override String get weekendLabel => 'Fin de semana';
	@override String get seasonalityTitle => 'Estacionalidad';
	@override String get seasonalitySubtitle => 'Completado por mes';
	@override String get bounceBackTitle => 'Tasa de recuperación';
	@override String get bounceBackSubtitle => 'Recuperación tras un fallo';
	@override String bounceBackDetail({required Object recoveries, required Object opportunities}) => 'Recuperado ${recoveries} de ${opportunities} veces';
	@override String get dangerZoneTitle => 'Zona de peligro';
	@override String get dangerZoneSubtitle => 'Cuándo se rompen las rachas';
	@override String get dangerZoneNone => 'Aún no hay rachas rotas';
	@override String dangerZoneDetail({required Object breaks, required Object total}) => '${breaks} de ${total} rupturas aquí';
	@override String get performanceComparisonTitle => 'Comparación de rendimiento';
	@override String get performanceComparisonSubtitle => 'Mejor vs peor racha';
	@override String perfCompGap({required Object pct}) => '${pct}% de diferencia';
	@override String get perfCompBest => 'Mejor';
	@override String get perfCompWorst => 'Peor';
	@override String get consistencyTitle => 'Constancia';
	@override String get consistencySubtitle => 'Hábitos más regulares';
	@override String get consistencySteadiest => 'Más constantes';
	@override String get consistencyErratic => 'Más irregulares';
	@override String get medalsTitle => 'Clasificación de rachas';
	@override String get medalsSubtitle => 'Rachas actuales más largas';
	@override String get neverMissedTitle => 'Nunca fallado';
	@override String get neverMissedEmpty => 'Aún no hay hábitos perfectos';
	@override String get distributionTitle => 'Distribución';
	@override String get distributionSubtitle => 'Hábitos por tasa de éxito';
	@override String get synergyTitle => 'Sinergia de hábitos';
	@override String get synergySubtitle => 'Qué hábitos van juntos';
	@override String get moodSensitiveTitle => 'Sensibles al ánimo';
	@override String get moodSensitiveSubtitle => 'Más influidos por tu ánimo';
	@override String get resilientHabitsTitle => 'Hábitos resilientes';
	@override String get resilientHabitsSubtitle => 'Hechos incluso en días bajos';
	@override String get correlationAnalysisTitle => 'Correlación de ánimo';
	@override String get correlationAnalysisSubtitle => 'Completado con ánimo bajo vs alto';
	@override String get moodEnergyTrendTitle => 'Ánimo y energía';
	@override String moodEnergyTrendSubtitle({required Object days}) => 'Últimos ${days} días';
	@override String get allTimeBest => 'Récord histórico';
	@override String get topPerformerLabel => 'El mejor';
	@override String get currentStreakShort => 'Ahora';
	@override String get recordLabel => 'Récord';
	@override String get recordDetail => 'Mejor racha de siempre';
	@override String get adherenceTitle => 'Adherencia al plan';
	@override String get adherenceSubtitle => 'De los días programados';
	@override String adherenceDetail({required Object done, required Object scheduled}) => '${done} de ${scheduled} días programados';
	@override String get atRiskTitle => 'En riesgo';
	@override String get atRiskYes => 'Sí';
	@override String get atRiskNo => 'En marcha';
	@override String atRiskDetail({required Object days}) => '${days} días desde la última vez';
	@override String get daysUnit => 'd';
	@override String get gapTitle => 'Intervalos';
	@override String get gapSubtitle => 'Días entre completados';
	@override String get gapAvg => 'Media';
	@override String get gapLongest => 'Máximo';
	@override String get gapSince => 'Desde el último';
	@override String get habitBounceBackShort => 'Recuperación';
	@override String get habitConsistencyDetail => 'Puntuación de regularidad';
	@override String habitPercentile({required Object pct}) => 'Mejor que el ${pct}% de tus hábitos';
	@override String get monthVsTitle => 'Este mes vs anterior';
	@override String get monthVsSubtitle => 'Completado mes a mes';
	@override String get thisMonthLabel => 'Este mes';
	@override String get lastMonthLabel => 'Mes pasado';
	@override String get nextDayMoodTitle => 'Impacto en el ánimo del día siguiente';
	@override String get nextDayMoodSubtitle => 'Ánimo y energía al día siguiente';
	@override String get nextDayAfterDone => 'Tras hacerlo';
	@override String get nextDayAfterMissed => 'Tras fallarlo';
	@override String nextDayMoodLift({required Object value}) => '${value} más de ánimo';
	@override String get streakHistoryTitle => 'Historial de rachas';
	@override String get streakHistorySubtitle => 'Cada serie de días consecutivos';
	@override String streakHistoryDetail({required Object count, required Object longest}) => '${count} rachas · la más larga ${longest} días';
}

// Path: habitsPage
class _Translations$habitsPage$es extends Translations$habitsPage$en {
	_Translations$habitsPage$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get today => 'Hoy';
	@override String get subtitle => 'Construye tu protocolo diario y observa la constancia a lo largo del tiempo.';
	@override String get tabProtocol => 'Protocolo';
	@override String get tabCalendar => 'Calendario';
	@override String get deleteHabitTitle => 'Eliminar hábito';
	@override String deleteHabitConfirm({required Object title}) => '¿Quitar "${title}" del protocolo?';
	@override String get activeProtocol => 'Protocolo activo';
	@override String get completedToday => 'Completadas hoy';
	@override String get dailyProtocol => 'Protocolo diario';
	@override String get protocolSubtitle => 'Resumen semanal, recordatorios y acciones rápidas';
	@override String get colHabit => 'HÁBITO';
	@override String get colStreak => 'RACHA';
	@override String get colLast7Days => 'ÚLTIMOS 7 DÍAS';
	@override String get colReminder => 'RECORDATORIO';
	@override String streakDays({required Object n}) => '${n} días';
	@override String get prevPeriod => 'Período anterior';
	@override String get nextPeriod => 'Período siguiente';
	@override List<String> get weekdayAbbrevUpper => [
		'LUN',
		'MAR',
		'MIÉ',
		'JUE',
		'VIE',
		'SÁB',
		'DOM',
	];
	@override String get lifeView => 'Vista de vida';
	@override String get lifeViewSubtitle => 'Una celda representa un mes del camino hasta los 85 años.';
	@override String get monthsLived => 'Meses vividos';
	@override String get currentAge => 'Edad actual';
	@override String get monthsRemaining => 'Meses restantes';
	@override String dayDetail({required Object day, required Object month}) => 'Detalle ${day} ${month}';
	@override String get dayDetailSubtitle => 'Actualiza el estado de los hábitos para este día.';
	@override String get editHabit => 'Editar hábito';
	@override String get newHabit => 'Nuevo hábito';
	@override String get optionalReminder => 'Recordatorio opcional';
	@override String get reminderHint => 'p. ej. 08:30';
	@override String get close => 'Cerrar';
	@override String get statusDone => 'Completada';
	@override String get statusSkipped => 'Omitida';
	@override String get statusUnrecorded => 'No registrada';
	@override String weekOf({required Object day, required Object month}) => 'Semana del ${day} ${month}';
	@override String get lifeWeeks => 'Semanas de tu camino';
	@override String get catMindfulness => 'Mindfulness';
	@override String get editableHint => 'Solo se pueden editar hoy y ayer.';
}

// Path: goalsPage
class _Translations$goalsPage$es extends Translations$goalsPage$en {
	_Translations$goalsPage$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Macroobjetivos';
	@override String get subtitle => 'Planificación a largo plazo.';
	@override String get sampleGoal => 'Objetivo de ejemplo';
	@override String get periodLifetime => 'Objetivos de vida';
	@override String get subtitleLifetime => 'Objetivos Lifetime';
	@override String get subtitleAnnual => 'Objetivos anuales';
	@override String get subtitleQuarterly => 'Objetivos trimestrales';
	@override String get subtitleMonthly => 'Objetivos mensuales';
	@override String get subtitleWeekly => 'Objetivos semanales';
	@override String get statsTab => 'Stats';
	@override String get fullView => 'Vista completa';
	@override String get categoriesTitle => 'Categorías de objetivos';
	@override String get defaultPill => 'Predeterminada';
	@override String get editCategory => 'Editar categoría';
	@override String get archiveCategory => 'Archivar categoría';
	@override String get categoryCreateFailed => 'No se pudo crear la categoría.';
	@override String get categoryArchiveFailed => 'No se pudo archivar la categoría.';
	@override String get categoryEditFailed => 'No se pudo editar la categoría.';
	@override String get addCategory => 'Añadir categoría';
	@override String get back => 'Atrás';
	@override String get finish => 'Finalizar';
	@override String get next => 'Siguiente';
	@override String get categoriesTooltip => 'Categorías';
	@override String get rescheduleTooltip => 'Reprogramar al período siguiente';
	@override String get defaultCategory => 'Predeterminada';
	@override String get emptyActive => 'Ningún objetivo activo en este período.';
	@override String get emptyAdd => 'Añade el primer objetivo para este período.';
	@override String get newGoal => 'Nuevo objetivo';
	@override String get editGoal => 'Editar objetivo';
	@override String get horizonLabel => 'Horizonte';
	@override String get newCategory => 'Nueva categoría';
	@override String get nameLabel => 'Nombre';
	@override String weekPeriodLabel({required Object week, required Object month, required Object year}) => 'Semana ${week}, ${month} ${year}';
	@override String get currentQuarter => 'Trimestre actual';
	@override String get currentMonth => 'Mes actual';
}

// Path: goalsStats
class _Translations$goalsStats$es extends Translations$goalsStats$en {
	_Translations$goalsStats$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get proRequired => 'Función Pro requerida';
	@override String get active => 'Activos';
	@override String get failed => 'Fallidos';
	@override String get complAbbr => 'Compl.';
	@override String get seasonality => 'Estacionalidad';
	@override String get interestEvolution => 'Evolución de intereses';
}

// Path: ai
class _Translations$ai$es extends Translations$ai$en {
	_Translations$ai$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get coach => 'Coach AI';
	@override String get dailyHabits => 'Hábitos diarios';
	@override String get macroGoals => 'Macroobjetivos';
	@override late final _Translations$ai$openRouter$es openRouter = _Translations$ai$openRouter$es._(_root);
	@override late final _Translations$ai$apiKey$es apiKey = _Translations$ai$apiKey$es._(_root);
	@override late final _Translations$ai$coachPrompts$es coachPrompts = _Translations$ai$coachPrompts$es._(_root);
	@override late final _Translations$ai$local$es local = _Translations$ai$local$es._(_root);
	@override late final _Translations$ai$standard$es standard = _Translations$ai$standard$es._(_root);
	@override late final _Translations$ai$consent$es consent = _Translations$ai$consent$es._(_root);
}

// Path: aiCoach
class _Translations$aiCoach$es extends Translations$aiCoach$en {
	_Translations$aiCoach$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get greeting => '¡Hola! Soy Evolve AI Coach. Estoy aquí para ayudarte a optimizar tu protocolo y alcanzar tus objetivos. ¿Cómo puedo ayudarte hoy?';
	@override String get systemPersona => 'Eres Evolve AI Coach, un asistente virtual para la disciplina personal.';
	@override String get habitsHeader => 'HÁBITOS ACTIVOS:';
	@override String get noActiveHabits => 'Sin hábitos activos.';
	@override String habitLine({required Object title, required Object done, required Object streak}) => '${title} (Completado hoy: ${done}, Racha: ${streak})';
	@override String get goalsHeader => 'OBJETIVOS:';
	@override String get noActiveGoals => 'Sin objetivos a largo plazo activos.';
	@override String goalLine({required Object title, required Object due}) => '${title} (Vence: ${due})';
	@override String get contextTitle => 'Contexto de IA';
	@override String get contextBody => 'Elige qué datos compartir con el Coach de IA para recibir consejos personalizados.';
	@override String get shareHabitsDesc => 'Comparte tus hábitos activos, las rachas y el estado de finalización de hoy.';
	@override String get shareGoalsDesc => 'Comparte tus objetivos activos a largo plazo.';
	@override String get saveClose => 'Guardar y cerrar';
	@override String get subtitle => 'Razona sobre los patrones con un coach contextual basado en los datos de tu camino.';
	@override String get contextButton => 'Contexto';
	@override String get typing => 'AI Coach está escribiendo...';
	@override String get inputHint => 'Pide consejos a tu Coach...';
	@override String get defaultUserName => 'Usuario';
	@override String userNameLine({required Object userName}) => '- Nombre: ${userName}';
	@override String activeGoalsCount({required Object count}) => '- Objetivos activos: ${count}';
	@override String completedGoalsCount({required Object count}) => '- Objetivos completados: ${count}';
	@override String todayCompletion({required Object completed, required Object total}) => '- Hábitos de hoy: ${completed} completados de ${total} en total.';
	@override String get newChatTooltip => 'Nuevo chat';
	@override String get clearConfirmTitle => '¿Iniciar un nuevo chat?';
	@override String get clearConfirmBody => 'Esto borra la conversación actual — no se guarda.';
	@override String get clearConfirmCancel => 'Cancelar';
	@override String get clearConfirmAccept => 'Nuevo chat';
	@override String get copyTooltip => 'Copiar';
	@override String get copiedToast => 'Copiado al portapapeles';
	@override String get linkOpenFailed => 'No se pudo abrir el enlace.';
}

// Path: settingsPage
class _Translations$settingsPage$es extends Translations$settingsPage$en {
	_Translations$settingsPage$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get account => 'Cuenta';
	@override String get notifications => 'Notificaciones';
	@override String get language => 'Idioma';
	@override String get timeFormat24h => 'Formato 24h';
	@override String get subscription => 'Suscripción';
	@override String get proName => 'Evolve PRO';
	@override String get planMonthly => 'Mensual';
	@override String get planAnnual => 'Anual';
	@override String get restorePurchases => 'Restaurar compras';
	@override String get deletePrivateData => 'eliminar datos privados';
	@override String get importInProgress => 'Importando datos...';
	@override String get passwordsDontMatch => 'Las contraseñas no coinciden';
	@override String get email => 'Email';
	@override String get cancel => 'Cancelar';
	@override String get confirm => 'Confirmar';
	@override String get save => 'Guardar';
	@override String get pageTitle => 'Ajustes';
	@override String get pageSubtitle => 'Gestiona tu perfil, el comportamiento del escritorio, la privacidad y el plan Evolve.';
	@override String get profileLabel => 'Perfil';
	@override String get profileSubtitle => 'Información personal y estado de sincronización';
	@override String get accountAndOnboarding => 'Cuenta e incorporación';
	@override String get privateMode => 'Modo Privado';
	@override String get sessionUnavailable => 'Sesión no disponible';
	@override String get dataRepository => 'Repositorio de datos';
	@override String get encryptedLocalDatabase => 'Base de datos local cifrada';
	@override String get supabaseWithEncryptedCache => 'Supabase con caché cifrada';
	@override String get personalInfo => 'Información personal';
	@override String get personalInfoDetail => 'Nombre, apellido, correo electrónico y fecha de nacimiento';
	@override String get updateAvatar => 'Actualizar avatar';
	@override String get updateAvatarDetail => 'Elige una imagen local para el perfil de escritorio.';
	@override String get reviewInitialConsent => 'Revisar consentimiento inicial';
	@override String get reviewInitialConsentDetail => 'Términos, privacidad, notificaciones e informes de fallos';
	@override String get signOut => 'Cerrar sesión en tu cuenta';
	@override String get signOutDetailActive => 'Cierra la sesión en este dispositivo';
	@override String get availableWithActiveSession => 'Disponible con una sesión de Supabase activa';
	@override String get goToLogin => 'Ir al inicio de sesión';
	@override String get goToLoginDetail => 'Suspende el modo privado e inicia sesión en Supabase.';
	@override String get appearanceTitle => 'Apariencia y aplicación';
	@override String get appearanceSubtitle => 'Preferencias locales adaptadas al escritorio';
	@override String get appearanceAndVisual => 'Apariencia y aspecto visual';
	@override String get themeMode => 'Tema';
	@override String get themeLight => 'Claro';
	@override String get themeDark => 'Oscuro';
	@override String get themeSystem => 'Seguir al sistema';
	@override String get calendarExperienceLanguage => 'Calendario, experiencia e idioma';
	@override String get accentColor => 'Color de acento';
	@override String get accentColorDetail => 'Paleta ampliada reservada para Evolve Pro.';
	@override String get defaultCalendarView => 'Vista de calendario predeterminada';
	@override late final _Translations$settingsPage$calendarViewOptions$es calendarViewOptions = _Translations$settingsPage$calendarViewOptions$es._(_root);
	@override late final _Translations$settingsPage$languageOptions$es languageOptions = _Translations$settingsPage$languageOptions$es._(_root);
	@override String get timeFormat24hDetail => 'Usa horas como 20:30 en lugar de 8:30 PM.';
	@override String get hapticFeedback => 'Respuesta háptica';
	@override String get hapticFeedbackDetail => 'El escritorio conserva la preferencia pero no genera vibraciones.';
	@override String get aiAndSystem => 'IA Y SISTEMA';
	@override String get aiSuggestions => 'Sugerencias de IA';
	@override String get aiSuggestionsDetail => 'Análisis inteligente de hábitos';
	@override String get focusMode => 'Modo enfoque';
	@override String get focusModeDetail => 'Pausa todos los recordatorios y las notificaciones.';
	@override String get milestones => 'Hitos';
	@override String get milestonesDetail => 'Celebraciones al alcanzar hitos clave.';
	@override String get deepWorkInsights => 'Insights de trabajo profundo';
	@override String get deepWorkInsightsDetail => 'Análisis avanzado de tus sesiones de concentración.';
	@override String get resetTutorial => 'Restablecer tutorial';
	@override String get resetTutorialDetail => 'Vuelve a abrir los tutoriales del panel y de los objetivos.';
	@override String get notificationsSubtitle => 'Recordatorios operativos del cliente de escritorio';
	@override String get operationalReminders => 'Recordatorios operativos';
	@override String get habitReminders => 'Recordatorios de hábitos';
	@override String get habitRemindersDetail => 'Envía el resumen matutino diario.';
	@override String get morningBriefTime => 'Hora del resumen matutino';
	@override String get eveningReview => 'Repaso nocturno';
	@override String get eveningReviewDetail => 'Te recuerda consolidar tu día.';
	@override String get eveningReviewTime => 'Hora del repaso nocturno';
	@override String get insightsAndReports => 'Insights e informes';
	@override String get aiInsights => 'Insights de IA';
	@override String get aiInsightsDetail => 'Análisis y consejos personalizados de la IA.';
	@override String get weeklyReports => 'Informes semanales';
	@override String get weeklyReportsDetail => 'Un resumen semanal de tu progreso.';
	@override String get requestNotificationPermissions => 'Solicitar permisos de notificación';
	@override String get requestNotificationPermissionsDetail => 'Abre el aviso nativo en la plataforma compatible.';
	@override String get nativeDeliveryTitle => 'Entrega nativa según el sistema operativo';
	@override String get privacyTitle => 'Privacidad y seguridad';
	@override String get privacySubtitle => 'Protección de acceso, consentimientos y gestión de datos';
	@override String get accessProtection => 'Protección de acceso';
	@override String get biometricLock => 'Bloqueo biométrico';
	@override String get biometricLockDetail => 'Disponible con el adaptador nativo en macOS y Windows; no compatible con Linux.';
	@override String get changePassword => 'Cambiar contraseña';
	@override String get changePasswordDetail => 'Actualización de credenciales mediante Supabase Auth.';
	@override String get dataAndConsents => 'Datos y consentimientos';
	@override String get sendCrashReports => 'Enviar informes de fallos';
	@override String get sendCrashReportsDetail => 'Consentimiento independiente para Sentry.';
	@override String get exportData => 'Exportar datos';
	@override String get exportDataDetail => 'Comparte una exportación JSON completa de los datos disponibles.';
	@override String get importData => 'Importar datos';
	@override String get importDataDetail => 'Restaura una copia de seguridad (JSON o ZIP) de Evolve.';
	@override String get systemPermissionsManagement => 'Gestión de permisos del sistema';
	@override String get systemPermissionsManagementDetail => 'Notificaciones, calendario y seguridad.';
	@override String get deletePrivateDataDetail => 'Elimina permanentemente la base de datos local cifrada.';
	@override String get deleteAccountAndData => 'Eliminar cuenta y datos';
	@override String get deleteAccountAndDataDetail => 'Operación irreversible protegida por confirmación.';
	@override String get exportPrivateShareText => 'Mis datos privados exportados desde Evolve';
	@override String get exportShareText => 'Mis datos exportados desde Evolve';
	@override String get exportDoneTitle => 'Exportación completada';
	@override String get exportDoneClipboard => 'El JSON está en el portapapeles: Linux no admite compartir archivos.';
	@override String get exportDoneShare => 'El JSON se envió al selector de uso compartido.';
	@override String get avatarGateTitle => 'Avatar';
	@override String get avatarPickFailed => 'No se pudo seleccionar la imagen.';
	@override String get confirmSignOutTitle => 'Confirmar cierre de sesión';
	@override String get confirmSignOutMessage => '¿Seguro que quieres cerrar sesión? Deberás volver a introducir tus credenciales para iniciar sesión de nuevo.';
	@override String get gateProfile => 'Perfil';
	@override String get gateLogout => 'Cerrar sesión';
	@override String get gateChangePassword => 'Cambio de contraseña';
	@override String get gateRequiresActiveSession => 'Requiere una sesión de Supabase activa.';
	@override String get biometricActivationCancelled => 'Activación cancelada.';
	@override String get notificationPermissionsTitle => 'Permisos de notificación';
	@override String get notificationPermissionsGranted => 'Permisos disponibles para este sistema.';
	@override String get notificationPermissionsDenied => 'Permiso no concedido. Puedes cambiarlo desde los ajustes del sistema.';
	@override String get systemPermissionsTitle => 'Permisos del sistema';
	@override String get systemPermissionsOpenFailed => 'No se pudieron abrir los ajustes.';
	@override String get tutorialResetTitle => 'Tutoriales restablecidos';
	@override String get tutorialResetMessage => 'Las guías se mostrarán de nuevo en las secciones correspondientes.';
	@override String get accountDataManagementTitle => 'Gestión de cuenta y datos';
	@override String get accountDataManagementContent => 'Elige si deseas eliminar los datos manteniendo la cuenta activa o eliminar la cuenta de forma permanente.';
	@override String get resetDataAction => 'Restablecer datos';
	@override String get deleteAccountAction => 'Eliminar cuenta';
	@override String get confirmResetDataTitle => 'Confirmar restablecimiento de datos';
	@override String get confirmResetDataMessage => 'Se eliminarán hábitos, objetivos y preferencias. La cuenta permanecerá activa. Esta acción no se puede deshacer.';
	@override String get confirmDeleteAccountTitle => 'Confirmar eliminación de la cuenta';
	@override String get confirmDeleteAccountMessage => 'La cuenta y todos los datos asociados se eliminarán de forma permanente. Esta acción es irreversible.';
	@override String get resetDataTitle => 'Restablecer datos';
	@override String get resetDataSuccess => 'Datos eliminados correctamente.';
	@override String get operationFailed => 'La operación falló.';
	@override String get settingSaveFailed => 'No se pudo guardar ese ajuste. Se ha restaurado su valor anterior.';
	@override String get deleteAccountGateTitle => 'Eliminar cuenta';
	@override String get accountDeleted => 'Cuenta eliminada.';
	@override String get importDataGateTitle => 'Importar datos';
	@override String get importPrivateOnly => 'La función de importación solo está disponible actualmente en el Modo Privado (Local).';
	@override String get importSummaryTitle => 'Resumen de importación';
	@override String importHabitsCount({required Object count}) => '${count} Hábitos';
	@override String importLogsCount({required Object count}) => '${count} Registros (Log)';
	@override String importMacroGoalsCount({required Object count}) => '${count} Objetivos Macro';
	@override String importCategoriesCount({required Object count}) => '${count} Categorías';
	@override String importMoodsCount({required Object count}) => '${count} Registros de Estado de Ánimo';
	@override String get importReplaceTitle => 'Reemplazar los datos actuales';
	@override String get importReplaceSubtitle => 'Elimina permanentemente todos los registros existentes que no estén en esta copia.';
	@override String get importMergeTitle => 'Combinar con los datos actuales';
	@override String get importMergeSubtitle => 'Combina con tus datos, conservando la versión más reciente de cada elemento.';
	@override String get importReplaceConfirmTitle => '¿Reemplazar todos los datos?';
	@override String importReplaceConfirmMessage({required Object count}) => 'Esto elimina permanentemente tus datos actuales (unos ${count} registros) y conserva solo lo que hay en esta copia. No se puede deshacer.';
	@override String get importReplaceConfirmButton => 'Eliminar y reemplazar';
	@override String get importConfirmButton => 'Confirmar importación';
	@override String get importSuccess => '¡Importación completada correctamente!';
	@override String importError({required Object error}) => 'Error durante la importación: ${error}';
	@override String get importLockedTitle => '¿Restablecer la base de datos privada bloqueada?';
	@override String get importLockedMessage => 'Este dispositivo no puede desbloquear tu base de datos privada local: falta su clave de cifrado (ocurre tras cambiar de Mac o modificar la firma de la app). Los datos locales existentes no se pueden recuperar, pero puedes restablecerlos e importar esta copia de seguridad en una base de datos nueva y vacía. Esta acción no se puede deshacer.';
	@override String get importLockedResetButton => 'Restablecer e importar';
	@override String importPreviewSkipped({required Object count}) => '⚠ Se omitirán ${count} registros no válidos';
	@override String get importCompletedTitle => 'Importación completada';
	@override String get importSummaryReplaced => 'Tus datos se reemplazaron con la copia de seguridad. Resumen:';
	@override String get importSummaryMerged => 'Tus datos se fusionaron con la copia de seguridad. Resumen:';
	@override String get importSummaryDone => '¡Genial!';
	@override String get importEntityHabits => 'Hábitos';
	@override String get importEntityLogs => 'Registros de hábitos';
	@override String get importEntityMacroGoals => 'Macro objetivos';
	@override String get importEntityCategories => 'Categorías';
	@override String get importEntityMoods => 'Registros de ánimo';
	@override String importRowReplace({required Object count, required Object label}) => '${count} ${label}';
	@override String importRowMerge({required Object label, required Object added, required Object updated, required Object unchanged}) => '${label}: ${added} añadidos, ${updated} actualizados, ${unchanged} sin cambios';
	@override String importRowSkipped({required Object count}) => ', ${count} omitidos';
	@override String get exportDoneSaved => 'El archivo JSON se guardó en la ubicación elegida.';
	@override String get proTitle => 'Evolve Pro';
	@override String get proSubtitle => 'Plan, restauración de compras y gestión de suscripción';
	@override String get billingAppleTitle => 'Facturado a través de Apple';
	@override String get commercialChannelRequired => 'Compras no disponibles';
	@override String get billingAppleDetail => 'Tu suscripción se compra y gestiona con tu cuenta de Apple.';
	@override String get billingUnavailableDetail => 'Las suscripciones no están disponibles temporalmente. Inténtalo de nuevo más tarde.';
	@override String get billingPlatformUnsupported => 'Las compras dentro de la aplicación no están disponibles en esta plataforma.';
	@override String get bestValue => 'Mejor valor';
	@override String get priceUnavailable => 'Precio no disponible';
	@override String get renewalDisclaimer => 'La suscripción se renueva automáticamente a menos que se desactive la renovación automática en la configuración de la cuenta de Apple al menos 24 horas antes del final del período.';
	@override String get privacyPolicy => 'Política de privacidad';
	@override String get termsEula => 'Términos de uso (EULA)';
	@override String get planManagement => 'Gestión del plan';
	@override String get activateEvolvePro => 'Activar Evolve Pro';
	@override String get activateEvolveProActive => 'Derecho de Evolve Pro activo.';
	@override String get activateEvolveProStart => 'Suscríbete con tu cuenta de Apple.';
	@override String get restorePurchasesDetail => 'Restaura una suscripción que ya compraste.';
	@override String get manageSubscription => 'Gestionar suscripción';
	@override String get manageSubscriptionDetail => 'Abre la gestión de suscripciones de la cuenta de Apple.';
	@override String get notAuthenticated => 'No autenticado';
	@override String get verified => 'Verificado';
	@override String get privateModeDataProtected => 'Tus datos están protegidos y se guardan únicamente en este dispositivo.';
	@override String get profileFallback => 'Perfil';
	@override String get fullName => 'Nombre completo';
	@override String get dateOfBirth => 'Fecha de nacimiento';
	@override String get dateOfBirthHint => 'AAAA-MM-DD';
	@override String get currentPassword => 'Contraseña actual';
	@override String get newPassword => 'Nueva contraseña';
	@override String get confirmNewPassword => 'Confirmar nueva contraseña';
	@override String get updatePassword => 'Actualizar contraseña';
	@override String get enterCurrentPassword => 'Introduce tu contraseña actual.';
	@override String get newPasswordMinLength => 'La nueva contraseña debe tener al menos 8 caracteres.';
	@override String get passwordUpdateFailed => 'La actualización falló. Comprueba tu contraseña actual.';
	@override String get sectionApplication => 'Aplicación';
	@override String get sectionPrivacy => 'Privacidad';
	@override String get customColor => 'Color personalizado';
	@override String get applyAction => 'Aplicar';
	@override String useAccent({required Object hex}) => 'Usar acento ${hex}';
	@override String get proUpsellTitle => 'Pasa a Evolve PRO';
	@override String get proUpsellSubtitle => 'Desbloquea todas las funciones y acelera tu crecimiento.';
	@override String get proWelcomeTitle => 'Bienvenido a Evolve PRO';
	@override String get proActiveMessage => 'Tu suscripción está activa. El AI Coach está incluido — sin cuenta de OpenRouter ni clave API — junto con las estadísticas avanzadas de tendencias y todas las herramientas de crecimiento personal de Evolve.';
	@override String get proStartJourney => 'Empieza tu recorrido';
	@override String get systemSection => 'Sistema';
	@override String get appLogsTitle => 'Registros de la app';
	@override String get appLogsDetail => 'Ver los registros de diagnóstico de esta sesión';
	@override String perMonth({required Object price}) => '${price} al mes';
	@override String perMonthWithSavings({required Object price, required Object percent}) => '${price} al mes · Ahorra un ${percent}%';
	@override String get detailsHeader => 'Detalles de la suscripción';
	@override String get statusLabel => 'Estado';
	@override String get statusActive => 'Activo';
	@override String get planLabel => 'Plan';
	@override String get nextRenewal => 'Próxima renovación';
	@override String get expiresOn => 'Caduca el';
	@override String get paymentMethod => 'Método de pago';
	@override String get paymentMethodValue => 'Apple Pay / App Store';
	@override String get proActiveName => 'Evolve PRO activo';
	@override String get youArePro => 'Eres usuario PRO';
	@override String get proThankYou => 'Gracias por apoyar el desarrollo de Evolve.';
}

// Path: consent
class _Translations$consent$es extends Translations$consent$en {
	_Translations$consent$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get onboardingTitle => 'Tu privacidad importa';
	@override String get continueButton => 'Continuar';
}

// Path: notifications
class _Translations$notifications$es extends Translations$notifications$en {
	_Translations$notifications$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get actionDone => 'Hecho';
	@override String get actionSkip => 'Omitir';
	@override String get actionSnooze => 'Posponer';
	@override String get morningBrief => 'Resumen matutino';
	@override String get eveningReview => 'Revisión nocturna';
	@override String get morningBriefBody => 'Es hora de estructurar tu día. Revisa tus objetivos.';
	@override String get eveningReviewBody => '¿Cómo fue el día? Registra tu progreso y actualiza el historial.';
}

// Path: privacy
class _Translations$privacy$es extends Translations$privacy$en {
	_Translations$privacy$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get biometricAuthReason => 'Autentícate para activar la protección de la app.';
	@override String get biometricUnlockReason => 'Desbloquea la app para continuar.';
}

// Path: consentPage
class _Translations$consentPage$es extends Translations$consentPage$en {
	_Translations$consentPage$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get subtitle => 'Antes de usar Evolve Desktop, confirma los términos, la política de privacidad y el tratamiento de datos necesario para la sincronización.';
	@override String get acceptTerms => 'Acepto los términos y la política de privacidad';
	@override String get termsSubtitle => 'Confirmo que he leído los documentos y que tengo al menos 14 años.';
	@override String get crashDiagnostics => 'Diagnóstico de fallos';
	@override String get crashSubtitle => 'Permite el envío de informes técnicos anonimizados.';
	@override String get openPrivacy => 'Abrir la política de privacidad';
	@override String get openTerms => 'Términos del servicio';
	@override String get notificationsTitle => 'Activar notificaciones';
	@override String get notificationsSubtitle => 'Recibe recordatorios de hábitos y resúmenes diarios.';
	@override String get enableNotifications => 'Activar';
	@override String get notificationsEnabled => 'Activadas';
}

// Path: notif
class _Translations$notif$es extends Translations$notif$en {
	_Translations$notif$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get macScheduling => 'Programación diaria activa en macOS.';
	@override String get linuxImmediate => 'Linux muestra notificaciones inmediatas, pero no admite la programación.';
	@override String get openEvolve => 'Abrir Evolve';
	@override String get windowsScheduling => 'Windows programa la próxima aparición en cada inicio.';
	@override String get morningBody => 'Revisa los hábitos de hoy y elige por dónde empezar.';
	@override String get habitReminderBody => 'Es hora de completar tu hábito.';
	@override String get limitReminderBody => '¿Te mantienes dentro de tu límite hoy? Revísalo cuando puedas.';
	@override String get eveningBody => 'Cierra el día y actualiza tu progreso.';
}

// Path: biometricGate
class _Translations$biometricGate$es extends Translations$biometricGate$en {
	_Translations$biometricGate$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get appLocked => 'App bloqueada';
	@override String get unlockPrompt => 'Desbloquea con la autenticación local para continuar.';
	@override String get verifying => 'Verificando...';
	@override String get unlock => 'Desbloquear';
	@override String get notSupportedLinux => 'El bloqueo biométrico no es compatible con Linux.';
	@override String get noLocalAuth => 'No hay ningún método de autenticación local disponible.';
	@override String get authFailed => 'Error de autenticación.';
	@override String get authUnavailable => 'Autenticación local no disponible.';
}

// Path: sync
class _Translations$sync$es extends Translations$sync$en {
	_Translations$sync$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get syncFailed => 'Sincronización fallida. Datos locales conservados.';
	@override String get editSavedLocally => 'Cambio guardado localmente. Se reintentará la sincronización.';
}

// Path: subscriptionCtrl
class _Translations$subscriptionCtrl$es extends Translations$subscriptionCtrl$en {
	_Translations$subscriptionCtrl$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get purchaseComplete => 'Compra completada: sincronizando la suscripción.';
	@override String get purchaseIncomplete => 'Compra no completada.';
	@override String get cantOpenApple => 'No se pudo abrir la gestión de suscripciones de Apple.';
	@override String get macOnly => 'Las compras dentro de la app están disponibles en el cliente de macOS.';
	@override String get loadOffersFailed => 'No se pudieron cargar los planes de suscripción. Comprueba tu conexión e inténtalo de nuevo.';
	@override String get proActivated => 'Evolve Pro activado.';
	@override String get purchasesRestored => 'Compras restauradas.';
	@override String get noActiveSub => 'No se encontró ninguna suscripción Pro activa.';
	@override String get restoreFailed => 'No se pudieron restaurar las compras.';
	@override String get configKey => 'Las compras dentro de la app no están disponibles temporalmente.';
	@override String get loginFirst => 'Inicia sesión antes de gestionar Evolve Pro.';
	@override String get paidAppsAgreement => 'El acuerdo de aplicaciones pagas no está activo. El titular de la cuenta debe aceptar el acuerdo de aplicaciones pagas en App Store Connect.';
	@override String get alreadyPurchased => 'Esta suscripción ya está comprada. Utilice Restaurar compras para reactivar el acceso Pro.';
	@override String get purchasesNotAllowed => 'No se permiten compras dentro de la aplicación en este dispositivo ni en la cuenta de Apple.';
	@override String get planUnavailable => 'El plan seleccionado no está disponible para su compra. Vuelve a intentarlo más tarde.';
	@override String get paymentPending => 'El pago está pendiente. El acceso Pro se activará cuando Apple confirme la transacción.';
	@override String get connectionUnavailable => 'Conexión no disponible. Verifique su red e inténtelo nuevamente.';
	@override String get linkedToAnotherAccount => 'Esta compra ya está vinculada a otra cuenta de Evolve. Inicie sesión con esa cuenta o comuníquese con el soporte.';
	@override String get purchaseInProgress => 'Ya hay una operación de compra en curso. Espere unos segundos.';
	@override String get restoreInProgress => 'Ya hay una restauración en curso. Espere unos segundos.';
	@override String get purchaseFailedMessage => 'No se pudo completar la compra. Vuelve a intentarlo en breve.';
	@override String get restoreFailedMessage => 'No se pudieron restaurar las compras. Vuelve a intentarlo en breve.';
	@override String get purchaseRegisteredNotActive => 'Compra registrada, pero la suscripción Pro aún no está activa. Espere unos segundos y use Restaurar compras.';
	@override String get noActiveSubscription => 'No se encontró ninguna suscripción activa a Evolve PRO en este Apple ID. Asegúrate de usar el mismo Apple ID de la compra.';
	@override String get invalidConfig => 'Configuración de compras no válida. Inténtalo de nuevo más tarde o contacta con soporte.';
}

// Path: authCtrl
class _Translations$authCtrl$es extends Translations$authCtrl$en {
	_Translations$authCtrl$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get appleNoToken => 'Apple no devolvió un token de identidad.';
	@override String get appleAuthFailed => 'Error de autenticación de Apple.';
	@override String get cantOpenBrowser => 'No se pudo abrir el navegador del sistema.';
	@override String accessNotCompleted({required Object provider}) => 'Inicio de sesión con ${provider} no completado.';
	@override String providerAuthFailed({required Object provider}) => 'Error de autenticación de ${provider}.';
	@override String get operationFailed => 'Operación fallida. Inténtalo de nuevo en breve.';
}

// Path: proModal
class _Translations$proModal$es extends Translations$proModal$en {
	_Translations$proModal$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Desbloquea Evolve PRO';
	@override String get subtitle => 'Lleva tu sistema de hábitos al siguiente nivel';
	@override String get featuresHeader => 'Qué incluye el plan PRO';
	@override String get aiCoachTitle => 'AI Coach, sin configuración';
	@override String get aiCoachDesc => 'Lo ejecutamos nosotros con nuestra clave: sin clave API que buscar, sin segunda cuenta. ¿Prefieres tu propia cuenta de OpenRouter? También es gratis.';
	@override String get statsTitle => 'Estadísticas específicas por hábito';
	@override String get statsDesc => 'Información clave para aumentar su productividad.';
	@override String get metricsTitle => 'Métricas avanzadas de objetivos';
	@override String get metricsDesc => 'Vea gráficos detallados y estadísticas detalladas de rendimiento para cada año.';
	@override String get unlimitedTitle => 'Hábitos ilimitados';
	@override String get unlimitedDesc => 'Crea y rastrea todos los hábitos que quieras sin límites.';
	@override String get maybeLater => 'Quizá más tarde';
	@override String get viewPlans => 'Ver planes Pro';
}

// Path: appLogs
class _Translations$appLogs$es extends Translations$appLogs$en {
	_Translations$appLogs$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Registros de la App';
	@override String get copiedToClipboard => 'Registros copiados al portapapeles';
	@override String get clearLogsTitle => 'Borrar Registros';
	@override String get clearLogsConfirm => '¿Estás seguro de que deseas borrar todas las entradas del registro? Esta acción no se puede deshacer.';
	@override String get clearLogsAction => 'Borrar Todo';
	@override String get copyAll => 'Copiar Todos los Registros';
	@override String get searchPlaceholder => 'Buscar en registros...';
	@override String get filterAll => 'Todo';
	@override String get filterErrors => 'Errores';
	@override String get filterWarnings => 'Advertencias';
	@override String get filterInfo => 'Info';
	@override String get emptyTitle => 'Sin Registros';
	@override String get emptySubtitle => 'Los registros aparecerán aquí mientras la app se ejecuta';
	@override String get stackTraceAvailable => 'Toca para ver el stack trace';
	@override String get detailMessage => 'MENSAJE';
	@override String get detailError => 'ERROR';
	@override String get detailExtras => 'Contexto adicional';
	@override String get detailStackTrace => 'STACK TRACE';
	@override String get shareLogs => 'Compartir archivo de registros';
	@override String get exportDone => 'Registros exportados';
}

// Path: coachSettings
class _Translations$coachSettings$es extends Translations$coachSettings$en {
	_Translations$coachSettings$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Motor del Coach de IA';
	@override String get subtitle => 'Elige dónde se ejecuta el coach. Los modelos locales mantienen cada mensaje en este dispositivo.';
	@override String get backendCloud => 'Tu OpenRouter';
	@override String get backendLocal => 'Local · privado';
	@override String get cloudDesc => 'Conecta tu propia cuenta de OpenRouter y paga directamente al proveedor. Gratis: no necesitas suscripción. El contexto que compartes se envía al proveedor.';
	@override String get localDesc => 'Tu propio modelo vía Ollama, LM Studio o cualquier servidor compatible con OpenAI. Nada sale de este dispositivo.';
	@override String get presetLabel => 'Servidor';
	@override String get presetOllama => 'Ollama';
	@override String get presetLmStudio => 'LM Studio';
	@override String get presetCustom => 'Personalizado…';
	@override String get baseUrlLabel => 'URL base';
	@override String get modelLabel => 'Modelo';
	@override String get refreshModels => 'Actualizar modelos';
	@override String get discovering => 'Buscando modelos…';
	@override String get noModelsFound => 'No se encontraron modelos — escribe un id de modelo manualmente abajo.';
	@override String get manualModelLabel => 'Id del modelo';
	@override String get manualModelAdd => 'Usar este modelo';
	@override String get statusConnected => 'Conectado';
	@override String get statusOffline => 'Servidor sin conexión';
	@override String get statusChecking => 'Comprobando…';
	@override String get remoteBadge => 'Remoto';
	@override String get remoteWarning => 'Este endpoint no es una dirección local — los mensajes saldrán de este dispositivo.';
	@override String get advanced => 'Avanzado';
	@override String get systemPromptLabel => 'Prompt del sistema';
	@override String get systemPromptHint => 'Reemplaza la persona del coach (déjalo vacío para la predeterminada)';
	@override String get systemPromptReset => 'Restablecer';
	@override String get temperatureLabel => 'Temperatura';
	@override String get save => 'Listo';
	@override String detectedTitle({required Object app}) => '${app} detectado';
	@override String detectedBody({required Object app}) => '${app} se está ejecutando en este Mac. ¿Ejecutar el coach de forma 100 % privada?';
	@override String get detectedAction => 'Usar local';
	@override String get detectedDismiss => 'Ahora no';
	@override String activeCloud({required Object model}) => 'Nube · ${model}';
	@override String activeLocal({required Object model}) => 'Local · ${model}';
	@override String get activeLocalNoModel => 'Local · elige un modelo';
	@override String get cloudSection => 'Tu OpenRouter';
	@override String get serverSettings => 'Ajustes del servidor…';
	@override String get settingsSectionLabel => 'Coach de IA';
	@override String get settingsTitle => 'Coach de IA';
	@override String get settingsSubtitle => 'Elige el motor que impulsa tu coach y conéctalo a un servidor local para máxima privacidad.';
	@override String get settingsRowStatus => 'Motor activo';
	@override String get settingsRowConfigure => 'Motor y servidor local';
	@override String get cloudKeyMissing => 'Aún no hay clave: este motor no responderá. Conecta abajo tu cuenta de OpenRouter, cambia a Evolve AI o usa un servidor local.';
	@override String get temperatureLower => 'Bajar la temperatura';
	@override String get temperatureRaise => 'Subir la temperatura';
	@override String get sendMessage => 'Enviar';
	@override String get stopResponse => 'Detener';
	@override String startLocalServer({required Object app}) => 'Iniciar ${app}';
	@override String getLocalServer({required Object app}) => 'Obtener ${app}';
	@override String startingLocalServer({required Object app}) => 'Iniciando ${app}…';
	@override String localServerOfflineTitle({required Object app}) => '${app} no está en ejecución';
	@override String get localServerOfflineBody => 'Inicia tu servidor local para chatear en privado — sin terminal.';
	@override String localServerNotInstalledTitle({required Object app}) => '${app} no está instalado';
	@override String localServerNotInstalledBody({required Object app}) => 'Instala la app gratuita de ${app} y luego pulsa Iniciar.';
	@override String get localServerStartingBody => 'Esto puede tardar unos segundos…';
	@override String localServerStartFailed({required Object app}) => 'No se pudo iniciar ${app} — prueba a abrirlo desde la carpeta Aplicaciones.';
	@override String localServerDownloadFailed({required Object url}) => 'No se pudo abrir el navegador — visita ${url}';
	@override String get ollamaStartTimeout => 'Está tardando más de lo esperado — revisa el icono de Ollama en la barra de menús (el primer inicio puede requerir aprobación).';
	@override String get ollamaServerOffTitle => 'Ollama está en ejecución pero no atiende peticiones';
	@override String get ollamaServerOffBody => 'Ollama está abierto, pero no responde en su puerto. Ciérralo desde la barra de menús y luego pulsa Iniciar de nuevo.';
	@override String get lmStudioStartTimeout => 'Está tardando más de lo esperado — abre LM Studio y comprueba que haya terminado de iniciarse.';
	@override String get lmStudioServerOffTitle => 'El servidor de LM Studio no está en ejecución';
	@override String get lmStudioServerOffBody => 'LM Studio está abierto, pero su servidor local está apagado. Actívalo con Developer → Start Server, o marca Settings → Run the LLM server on login.';
	@override String get lmStudioNoModelsJit => 'LM Studio no está mostrando ningún modelo. Solo muestra los modelos cargados cuando la carga Just-In-Time está desactivada — carga un modelo en LM Studio o activa Developer → Server Settings → Just In Time Model Loading.';
	@override String get backendStandard => 'Evolve AI';
	@override String get standardDesc => 'Incluido en Evolve Pro. Ejecutamos por ti un modelo gratuito de Google (Gemma): sin claves, sin configuración. Tus mensajes van al plan gratuito de Google, que puede usarlos para mejorar sus servicios.';
	@override String activeStandard({required Object model}) => 'Evolve AI · ${model}';
	@override String get standardSection => 'Evolve AI';
	@override String get standardStatusReady => 'Incluido en Pro';
	@override String get standardStatusNeedsPro => 'Requiere Pro';
	@override String get standardStatusNeedsSignIn => 'Inicia sesión';
	@override String get standardStatusUnavailable => 'No disponible';
	@override String get standardNeedsProNote => 'Evolve AI forma parte de Evolve Pro. Suscríbete para desbloquearlo.';
	@override String get standardNeedsSignInNote => 'Inicia sesión para usar Evolve AI. Tu suscripción lo desbloquea en todos tus dispositivos.';
	@override String get standardUnavailableNote => 'Evolve AI no está disponible en esta versión. Conecta tu cuenta de OpenRouter o usa un modelo local.';
	@override String get standardPrivateNote => 'Evolve AI necesita una cuenta de Evolve, y el modo Privado no guarda ninguna. Conecta tu cuenta de OpenRouter o usa un modelo local: aquí ambos siguen funcionando.';
	@override String get accountModeNote => '¿Prefieres tu propia clave de OpenRouter o un modelo local? Están disponibles en el modo Privado.';
	@override String get localGroupLabel => 'Local — en este Mac';
	@override String get useCustomServer => 'Usar un servidor personalizado…';
	@override String get cardLive => 'Activo';
	@override String get cardOff => 'Apagado';
	@override String get engineOpenRouter => 'OpenRouter';
	@override String get engineOpenRouterHint => 'Tu propia clave · gratis';
}

// Path: tour
class _Translations$tour$es extends Translations$tour$en {
	_Translations$tour$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get back => 'Atrás';
	@override String get next => 'Siguiente';
	@override String get continueLabel => 'Continuar';
	@override String get finish => 'Finalizar';
	@override String get welcomeTitle => 'Bienvenido a Evolve';
	@override String get welcomeBody => 'Hagamos un recorrido rápido por tu espacio — desde tu resumen diario hasta tu coach de IA. Solo toma un momento.';
	@override String get welcomeStart => 'Iniciar recorrido';
	@override String get welcomeSkip => 'Omitir tutorial';
	@override String get doneTitle => 'Todo listo';
	@override String get doneBody => 'Esta es toda la app. Empieza donde quieras desde la barra lateral — y puedes repetir el recorrido cuando quieras desde Ajustes.';
	@override String get doneButton => 'Empezar';
	@override String get overviewOrientationTitle => 'Tu Resumen';
	@override String get overviewOrientationDesc => 'Es tu base diaria — una vista de hoy en cuanto abres Evolve.';
	@override String get overviewCheckinTitle => 'Registro diario';
	@override String get overviewCheckinDesc => 'Anota cómo va tu día. Con el tiempo revela cómo tu estado de ánimo se relaciona con tus hábitos y metas.';
	@override String get overviewHabitsTitle => 'Hábitos de hoy';
	@override String get overviewHabitsDesc => 'Los hábitos que planificaste para hoy están aquí — márcalos a medida que avanzas.';
	@override String get overviewGoalsTitle => 'Metas en foco';
	@override String get overviewGoalsDesc => 'Las metas en las que te concentras aparecen aquí para que nada se te escape.';
	@override String get habitsOrientationTitle => 'La página de Hábitos';
	@override String get habitsOrientationDesc => 'Aquí construyes tu protocolo diario y controlas tu constancia.';
	@override String get habitsAddTitle => 'Añadir un hábito';
	@override String get habitsAddDesc => 'Crea un nuevo hábito aquí — dale nombre, categoría, color y un recordatorio opcional.';
	@override String get habitsCheckoffTitle => 'Márcalo como hecho';
	@override String get habitsCheckoffDesc => 'Marca esta casilla para completar un hábito hoy. Con eso basta para mantener viva una racha.';
	@override String get habitsStreakTitle => 'Rachas e historial';
	@override String get habitsStreakDesc => 'Observa crecer tu racha y ve tus últimos siete días de un vistazo.';
	@override String get habitsCalendarTitle => 'Vista de calendario';
	@override String get habitsCalendarDesc => 'Cambia al Calendario para revisar tu historial por semana, mes, año — o toda tu vida.';
	@override String get insightsOrientationTitle => 'Tus Estadísticas';
	@override String get insightsOrientationDesc => 'Observa la evolución de tus hábitos y metas en el tiempo y dónde te desvías.';
	@override String get insightsFilterTitle => 'Filtrar por hábito';
	@override String get insightsFilterDesc => 'Enfoca las estadísticas en un solo hábito o mantén la vista global.';
	@override String get insightsTabsTitle => 'Secciones de estadísticas';
	@override String get insightsTabsDesc => 'Cambia entre las secciones para tendencias, alertas, progreso de hábitos y tu ánimo.';
	@override String get goalsOrientationTitle => 'La página de Metas';
	@override String get goalsOrientationDesc => 'Define y controla tus objetivos más grandes — aquello hacia lo que construyen tus hábitos diarios.';
	@override String get goalsPlanTitle => 'Tipo de planificación';
	@override String get goalsPlanDesc => 'Elige cómo planificas — diaria, semanal o más larga — según cómo pienses tus metas.';
	@override String get goalsAddTitle => 'Añadir una meta';
	@override String get goalsAddDesc => 'Crea aquí una nueva meta y dale un objetivo por alcanzar.';
	@override String get goalsCheckTitle => 'Completar o fallar';
	@override String get goalsCheckDesc => 'Marca una meta como cumplida o fallada. Cada resultado alimenta tu rendimiento con el tiempo.';
	@override String get goalsStatsTitle => 'Rendimiento';
	@override String get goalsStatsDesc => 'Activa las estadísticas de rendimiento para ver cómo vas con tus metas.';
	@override String get coachOrientationTitle => 'Tu Coach de IA';
	@override String get coachOrientationDesc => 'Orientación personalizada basada en tus hábitos y metas reales — aquí en tu Mac.';
	@override String get coachModelTitle => 'Elige el motor';
	@override String get coachModelDesc => 'Elige el modelo de IA — nuestra nube o un modelo local que se ejecuta de forma privada en tu Mac. Los ajustes del servidor también están aquí.';
	@override String get coachContextTitle => 'Lo que ve el coach';
	@override String get coachContextDesc => 'Controla si el coach puede usar tus hábitos y metas para adaptar sus consejos.';
	@override String get coachSuggestionsTitle => 'Sugerencias iniciales';
	@override String get coachSuggestionsDesc => '¿No sabes por dónde empezar? Toca una de estas sugerencias para arrancar.';
	@override String get coachInputTitle => 'Pregunta lo que sea';
	@override String get coachInputDesc => 'Escribe aquí tu pregunta y pulsa enviar. Aquí termina el recorrido — ¡disfruta Evolve!';
}

// Path: palette
class _Translations$palette$es extends Translations$palette$en {
	_Translations$palette$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get searchHint => 'Busca objetivos, hábitos, acciones…';
	@override String get groupSuggested => 'Sugeridos';
	@override String get groupThisWeek => 'Esta semana';
	@override String get groupGoals => 'Objetivos';
	@override String get groupHabits => 'Hábitos';
	@override String get groupActions => 'Acciones';
	@override String get groupSections => 'Ir a';
	@override String get goToThisWeek => 'Ir a esta semana';
	@override String get createGoalBlank => 'Crear objetivo';
	@override String createGoal({required Object title}) => 'Crear objetivo «${title}»';
	@override String createHabit({required Object title}) => 'Crear hábito «${title}»';
	@override String goToPeriod({required Object period}) => 'Ir a ${period}';
	@override String get switchToDark => 'Cambiar a tema oscuro';
	@override String get switchToLight => 'Cambiar a tema claro';
	@override String get manageCategories => 'Gestionar categorías de objetivos';
	@override String get replayTour => 'Repetir el tour guiado';
	@override String noResults({required Object query}) => 'Sin resultados para «${query}»';
	@override String get rowOpen => 'Abrir';
	@override String get rowComplete => 'Marcar como completado';
	@override String get rowReschedule => 'Reprogramar al siguiente periodo';
	@override String get deleteGoalTitle => '¿Eliminar objetivo?';
	@override String deleteGoalMessage({required Object title}) => '«${title}» se eliminará permanentemente.';
	@override String get deleteHabitTitle => '¿Eliminar hábito?';
	@override String deleteHabitMessage({required Object title}) => '«${title}» se eliminará permanentemente.';
	@override String get footerNavigate => 'navegar';
	@override String get footerOpen => 'abrir';
	@override String get footerMenu => 'menú';
	@override String get footerClose => 'cerrar';
}

// Path: targets
class _Translations$targets$es extends Translations$targets$en {
	_Translations$targets$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get sectionTitle => 'Objetivo';
	@override String get none => 'Simple';
	@override String get atLeastLabel => 'Alcanza';
	@override String get atMostLabel => 'Mantente bajo';
	@override late final _Translations$targets$presets$es presets = _Translations$targets$presets$es._(_root);
	@override late final _Translations$targets$units$es units = _Translations$targets$units$es._(_root);
	@override late final _Translations$targets$entry$es entry = _Translations$targets$entry$es._(_root);
}

// Path: common.actions
class _Translations$common$actions$es extends Translations$common$actions$en {
	_Translations$common$actions$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get cancel => 'Cancelar';
	@override String get save => 'Guardar';
	@override String get delete => 'Eliminar';
	@override String get edit => 'Editar';
	@override String get pick => 'Elegir';
	@override String get gotIt => 'Entendido';
	@override String get done => 'Hecho';
}

// Path: common.calendarView
class _Translations$common$calendarView$es extends Translations$common$calendarView$en {
	_Translations$common$calendarView$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get year => 'Año';
	@override String get month => 'Mes';
	@override String get week => 'Semana';
	@override String get life => 'Vida';
}

// Path: common.status
class _Translations$common$status$es extends Translations$common$status$en {
	_Translations$common$status$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get error => 'Error';
}

// Path: macroGoals.types
class _Translations$macroGoals$types$es extends Translations$macroGoals$types$en {
	_Translations$macroGoals$types$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get annual => 'Anual';
	@override String get quarterly => 'Trimestral';
	@override String get monthly => 'Mensual';
	@override String get weekly => 'Semanal';
	@override String get lifetime => 'De por vida';
}

// Path: ai.openRouter
class _Translations$ai$openRouter$es extends Translations$ai$openRouter$en {
	_Translations$ai$openRouter$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get apiKeyMissingShort => '⚠️ El Coach AI necesita tu propia clave de API de OpenRouter. Añádela en los ajustes para empezar a chatear.';
	@override String get apiKeyInvalid => '⚠️ OpenRouter ha rechazado esta clave de API. Revísala en los ajustes o crea una nueva en openrouter.ai/keys.';
	@override String get defaultSystemPrompt => 'Eres el "Coach de Disciplina", un asistente virtual centrado en ayudar al usuario a mantener la disciplina, alcanzar objetivos y construir hábitos saludables. Sé motivador pero concreto, directo y práctico. Usa un tono profesional pero cercano.';
	@override String communicationError({required Object code}) => '❌ Error al comunicarse con la IA. (Código: ${code})';
	@override String get connectionError => '❌ Error de conexión. Asegúrate de estar online e inténtalo de nuevo.';
	@override String get connectionErrorShort => '❌ Error de conexión.';
	@override String get connectionCheckTimeout => '❌ Error: la comprobación de conexión tardó demasiado.';
	@override String get contextTooLong => '⚠️ Esta conversación se volvió demasiado larga para el modelo. Inicia un nuevo chat (arriba a la derecha) para continuar.';
	@override String get noInternet => '❌ Error: no hay conexión a internet. Revisa tu red.';
	@override String get serverTimeout => '❌ Error: el servidor tarda demasiado en responder. Inténtalo de nuevo.';
	@override String apiError({required Object code}) => '❌ Error de API: ${code} (consulta Sentry para más detalles)';
}

// Path: ai.apiKey
class _Translations$ai$apiKey$es extends Translations$ai$apiKey$en {
	_Translations$ai$apiKey$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get rowTitle => 'Tu cuenta de OpenRouter';
	@override String get description => '¿Prefieres ejecutar el coach en tu propia cuenta? Conecta una clave de OpenRouter y pagarás directamente al proveedor, sin suscripción a Evolve. Crea una en openrouter.ai/keys: se guarda en el llavero de este dispositivo y solo se envía a OpenRouter.';
	@override String get fieldLabel => 'Clave de API';
	@override String get hint => 'sk-or-v1-…';
	@override String get save => 'Guardar clave';
	@override String get saved => 'Clave de API guardada';
	@override String get remove => 'Eliminar clave';
	@override String get removed => 'Clave de API eliminada';
	@override String get removeConfirmTitle => '¿Eliminar la clave de API?';
	@override String get removeConfirmBody => 'Este motor dejará de responder hasta que vuelvas a conectar una cuenta. Evolve AI y los modelos locales no se ven afectados.';
	@override String get statusSet => 'Guardada';
	@override String get statusMissing => 'Sin configurar';
	@override String get saveFailed => 'No se ha podido guardar la clave en el llavero. Inténtalo de nuevo.';
	@override String get setupTitle => 'Conecta tu cuenta de OpenRouter';
	@override String get setupBody => 'Este motor funciona con tu propia cuenta de OpenRouter. Conéctala para empezar a chatear o cambia a Evolve AI, incluido en Pro.';
	@override String get setupAction => 'Conectar cuenta';
}

// Path: ai.coachPrompts
class _Translations$ai$coachPrompts$es extends Translations$ai$coachPrompts$en {
	_Translations$ai$coachPrompts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$ai$coachPrompts$diagnoseWeakestHabit$es diagnoseWeakestHabit = _Translations$ai$coachPrompts$diagnoseWeakestHabit$es._(_root);
	@override late final _Translations$ai$coachPrompts$goalOnTrack$es goalOnTrack = _Translations$ai$coachPrompts$goalOnTrack$es._(_root);
	@override late final _Translations$ai$coachPrompts$weeklyReviewDown$es weeklyReviewDown = _Translations$ai$coachPrompts$weeklyReviewDown$es._(_root);
	@override late final _Translations$ai$coachPrompts$weeklyReviewUp$es weeklyReviewUp = _Translations$ai$coachPrompts$weeklyReviewUp$es._(_root);
	@override late final _Translations$ai$coachPrompts$protectStreak$es protectStreak = _Translations$ai$coachPrompts$protectStreak$es._(_root);
	@override late final _Translations$ai$coachPrompts$alignHabitsToGoal$es alignHabitsToGoal = _Translations$ai$coachPrompts$alignHabitsToGoal$es._(_root);
	@override late final _Translations$ai$coachPrompts$designHabitForGoal$es designHabitForGoal = _Translations$ai$coachPrompts$designHabitForGoal$es._(_root);
	@override late final _Translations$ai$coachPrompts$raiseTheBar$es raiseTheBar = _Translations$ai$coachPrompts$raiseTheBar$es._(_root);
	@override late final _Translations$ai$coachPrompts$firstStep$es firstStep = _Translations$ai$coachPrompts$firstStep$es._(_root);
	@override late final _Translations$ai$coachPrompts$whatCanYouHelp$es whatCanYouHelp = _Translations$ai$coachPrompts$whatCanYouHelp$es._(_root);
}

// Path: ai.local
class _Translations$ai$local$es extends Translations$ai$local$en {
	_Translations$ai$local$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String notReachable({required Object url}) => '❌ No se puede acceder al servidor de IA local en ${url}. Asegúrate de que Ollama o LM Studio esté en ejecución.';
	@override String get modelMissing => '⚠️ Elige primero un modelo local — abre el selector de modelos arriba.';
	@override String requestFailed({required Object code}) => '❌ Error del modelo local (código: ${code}).';
	@override String get streamError => '❌ Error de conexión con el modelo local.';
	@override String get timeout => '❌ El modelo local está tardando demasiado — puede que aún se esté cargando. Inténtalo de nuevo.';
	@override String get modelNotFound => '❌ Ese modelo no está disponible en el servidor. Abre el selector para elegir o cargar uno.';
	@override String authRequired({required Object app}) => '❌ ${app} está rechazando la conexión — requiere un token de API. Desactiva la autenticación en los ajustes de su servidor o apunta Evolve a un servidor que no lo requiera.';
	@override String get stillLoading => 'El modelo aún se está cargando — un arranque en frío puede tardar un poco.';
}

// Path: ai.standard
class _Translations$ai$standard$es extends Translations$ai$standard$en {
	_Translations$ai$standard$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get sessionExpired => '⚠️ Tu sesión ha caducado. Inicia sesión de nuevo para seguir usando Evolve AI.';
	@override String get needsPro => '⚠️ Evolve AI forma parte de Evolve Pro. Suscríbete en Ajustes o cambia el motor a tu propia cuenta de OpenRouter, que es gratis.';
	@override String get rateLimited => '⚠️ Has alcanzado el límite de uso razonable de Evolve AI por ahora. Inténtalo más tarde o cambia el motor a tu propia cuenta de OpenRouter.';
	@override String get unavailable => '❌ Evolve AI no está disponible ahora mismo. Es cosa nuestra: inténtalo de nuevo en un momento.';
}

// Path: ai.consent
class _Translations$ai$consent$es extends Translations$ai$consent$en {
	_Translations$ai$consent$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get standardTitle => '¿Enviar tus mensajes a la IA?';
	@override String get standardBody => 'Para responder, el AI Coach envía tu mensaje, tu nombre y el contexto que elijas compartir a OpenRouter, Inc., que lo dirige a Google LLC (Google AI Studio) para ejecutar el modelo. Al tratarse del plan gratuito de Google, Google puede conservar el texto durante un tiempo limitado y usarlo para mejorar sus servicios: no es tan privado como un plan de pago. Puedes retirar el consentimiento cuando quieras en Ajustes, y todo lo demás de Evolve sigue funcionando.';
	@override String get byokTitle => '¿Enviar tus mensajes a OpenRouter?';
	@override String get byokBody => 'Para responder, el AI Coach envía tu mensaje, tu nombre y el contexto que elijas compartir a OpenRouter, Inc. usando tu propia cuenta de OpenRouter. OpenRouter lo dirige a un proveedor de modelos según los ajustes de tu cuenta. Puedes retirar el consentimiento cuando quieras en Ajustes, y todo lo demás de Evolve sigue funcionando.';
	@override String get privateNote => 'Tu base de datos privada permanece en este dispositivo: solo sale lo que envías en el chat.';
	@override String get allow => 'Permitir';
	@override String get decline => 'Ahora no';
	@override String get rowTitle => 'Compartir datos con la IA';
	@override String get statusGranted => 'Permitido';
	@override String get statusNone => 'No permitido';
	@override String get revokeTitle => '¿Dejar de compartir con la IA?';
	@override String get revokeBody => 'El AI Coach volverá a pedir permiso antes de enviar nada. No cambia nada más.';
	@override String get revokeAction => 'Dejar de compartir';
}

// Path: settingsPage.calendarViewOptions
class _Translations$settingsPage$calendarViewOptions$es extends Translations$settingsPage$calendarViewOptions$en {
	_Translations$settingsPage$calendarViewOptions$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get month => 'Mes';
	@override String get week => 'Semana';
	@override String get year => 'Año';
	@override String get life => 'Vida';
}

// Path: settingsPage.languageOptions
class _Translations$settingsPage$languageOptions$es extends Translations$settingsPage$languageOptions$en {
	_Translations$settingsPage$languageOptions$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get system => 'Sistema';
	@override String get italian => 'Italiano';
	@override String get english => 'Inglés';
	@override String get spanish => 'Español';
	@override String get german => 'Alemán';
	@override String get arabic => 'Árabe';
}

// Path: targets.presets
class _Translations$targets$presets$es extends Translations$targets$presets$en {
	_Translations$targets$presets$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$targets$presets$countDaily$es countDaily = _Translations$targets$presets$countDaily$es._(_root);
	@override late final _Translations$targets$presets$durationDaily$es durationDaily = _Translations$targets$presets$durationDaily$es._(_root);
	@override late final _Translations$targets$presets$limitCountDaily$es limitCountDaily = _Translations$targets$presets$limitCountDaily$es._(_root);
	@override late final _Translations$targets$presets$limitDurationDaily$es limitDurationDaily = _Translations$targets$presets$limitDurationDaily$es._(_root);
}

// Path: targets.units
class _Translations$targets$units$es extends Translations$targets$units$en {
	_Translations$targets$units$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get min => 'min';
	@override String get hour => 'h';
	@override String get kcal => 'kcal';
	@override String get km => 'km';
}

// Path: targets.entry
class _Translations$targets$entry$es extends Translations$targets$entry$en {
	_Translations$targets$entry$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get keepGoing => 'Sigue así';
	@override String get withinLimit => 'Dentro de tu límite';
	@override String get overLimit => 'Por encima de tu límite';
}

// Path: ai.coachPrompts.diagnoseWeakestHabit
class _Translations$ai$coachPrompts$diagnoseWeakestHabit$es extends Translations$ai$coachPrompts$diagnoseWeakestHabit$en {
	_Translations$ai$coachPrompts$diagnoseWeakestHabit$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get label => '🩺 Arregla mi hábito más débil';
	@override String payload({required Object habit, required Object done, required Object scheduled}) => '\'${habit}\' es mi hábito más débil esta semana — ${done}/${scheduled} días cumplidos. ¿Cuál es la razón más probable por la que me lo salto y dos soluciones concretas que pueda aplicar esta semana?';
}

// Path: ai.coachPrompts.goalOnTrack
class _Translations$ai$coachPrompts$goalOnTrack$es extends Translations$ai$coachPrompts$goalOnTrack$en {
	_Translations$ai$coachPrompts$goalOnTrack$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get label => '🎯 ¿Voy por buen camino?';
	@override String payload({required Object goal}) => 'Sé sincero sobre mi objetivo \'${goal}\': ¿voy por buen camino para lograrlo y cuál es el único cambio que más mejoraría mis probabilidades?';
}

// Path: ai.coachPrompts.weeklyReviewDown
class _Translations$ai$coachPrompts$weeklyReviewDown$es extends Translations$ai$coachPrompts$weeklyReviewDown$en {
	_Translations$ai$coachPrompts$weeklyReviewDown$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get label => '📉 Analiza mi semana';
	@override String payload({required Object thisPct, required Object lastPct}) => 'Mi constancia bajó al ${thisPct}% esta semana desde el ${lastPct}% de la anterior. ¿Cuál es la causa más probable y el único cambio que debería hacer la próxima semana?';
}

// Path: ai.coachPrompts.weeklyReviewUp
class _Translations$ai$coachPrompts$weeklyReviewUp$es extends Translations$ai$coachPrompts$weeklyReviewUp$en {
	_Translations$ai$coachPrompts$weeklyReviewUp$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get label => '📊 Analiza mi semana';
	@override String payload({required Object thisPct, required Object lastPct}) => 'Mi constancia está en el ${thisPct}% esta semana frente al ${lastPct}% de la anterior. ¿Qué está funcionando y qué es lo único que debería impulsar más la próxima semana?';
}

// Path: ai.coachPrompts.protectStreak
class _Translations$ai$coachPrompts$protectStreak$es extends Translations$ai$coachPrompts$protectStreak$en {
	_Translations$ai$coachPrompts$protectStreak$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get label => '🛡️ Protege mi racha';
	@override String payload({required Object habit, required Object days}) => 'Mi racha activa más larga es \'${habit}\' con ${days} días. ¿Cuál es el mayor riesgo de romperla y cómo la protejo esta semana?';
}

// Path: ai.coachPrompts.alignHabitsToGoal
class _Translations$ai$coachPrompts$alignHabitsToGoal$es extends Translations$ai$coachPrompts$alignHabitsToGoal$en {
	_Translations$ai$coachPrompts$alignHabitsToGoal$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get label => '🔗 ¿Qué hábitos sirven a mis objetivos?';
	@override String payload({required Object goal}) => 'Mirando mis hábitos frente a mi objetivo \'${goal}\', ¿cuáles lo hacen avanzar de verdad y cuáles son solo ruido? Sé específico e indica un hábito que quizá me falte.';
}

// Path: ai.coachPrompts.designHabitForGoal
class _Translations$ai$coachPrompts$designHabitForGoal$es extends Translations$ai$coachPrompts$designHabitForGoal$en {
	_Translations$ai$coachPrompts$designHabitForGoal$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get label => '💡 Convierte un objetivo en hábito';
	@override String payload({required Object goal}) => 'Quiero alcanzar mi objetivo \'${goal}\'. ¿Qué único hábito diario marcaría la mayor diferencia? Dame un hábito concreto que pueda empezar mañana.';
}

// Path: ai.coachPrompts.raiseTheBar
class _Translations$ai$coachPrompts$raiseTheBar$es extends Translations$ai$coachPrompts$raiseTheBar$en {
	_Translations$ai$coachPrompts$raiseTheBar$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get label => '🚀 Sube el listón';
	@override String get payload => 'Estoy cumpliendo todos mis hábitos y mis objetivos van por buen camino. ¿Dónde podría estar acomodándome y cuál es una forma de subir el listón sin quemarme?';
}

// Path: ai.coachPrompts.firstStep
class _Translations$ai$coachPrompts$firstStep$es extends Translations$ai$coachPrompts$firstStep$en {
	_Translations$ai$coachPrompts$firstStep$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get label => '🌱 ¿Por dónde empiezo?';
	@override String get payload => 'Estoy empezando y aún no he configurado objetivos ni hábitos. Sugiéreme un primer objetivo realista y un pequeño hábito diario para lograrlo, y explica por qué esa combinación funciona.';
}

// Path: ai.coachPrompts.whatCanYouHelp
class _Translations$ai$coachPrompts$whatCanYouHelp$es extends Translations$ai$coachPrompts$whatCanYouHelp$en {
	_Translations$ai$coachPrompts$whatCanYouHelp$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get label => '💬 ¿En qué puedes ayudarme?';
	@override String get payload => 'Según mis hábitos y objetivos en esta app, dame tres ejemplos concretos de cómo puedes ayudarme — no consejos genéricos, sino cosas ligadas a mis datos reales.';
}

// Path: targets.presets.countDaily
class _Translations$targets$presets$countDaily$es extends Translations$targets$presets$countDaily$en {
	_Translations$targets$presets$countDaily$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get label => 'Recuento';
	@override String get description => 'Hazlo un número determinado de veces al día.';
}

// Path: targets.presets.durationDaily
class _Translations$targets$presets$durationDaily$es extends Translations$targets$presets$durationDaily$en {
	_Translations$targets$presets$durationDaily$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get label => 'Duración';
	@override String get description => 'Dedica un número determinado de minutos al día.';
}

// Path: targets.presets.limitCountDaily
class _Translations$targets$presets$limitCountDaily$es extends Translations$targets$presets$limitCountDaily$en {
	_Translations$targets$presets$limitCountDaily$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get label => 'Límite';
	@override String get description => 'Mantente por debajo de un número cada día.';
}

// Path: targets.presets.limitDurationDaily
class _Translations$targets$presets$limitDurationDaily$es extends Translations$targets$presets$limitDurationDaily$en {
	_Translations$targets$presets$limitDurationDaily$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get label => 'Límite de tiempo';
	@override String get description => 'Mantente bajo un número de minutos al día.';
}

/// The flat map containing all translations for locale <es>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEs {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'macroTargets.sectionTitle' => 'Objetivo numérico',
			'macroTargets.none' => 'Ninguno',
			'macroTargets.amountLabel' => 'Valor objetivo',
			'macroTargets.linkLabel' => 'Vincular un hábito',
			'macroTargets.manual' => 'Manual',
			'macroTargets.unitCount' => 'recuento',
			'macroTargets.reached' => 'Alcanzado',
			'auth.continuePrivately' => 'Continúa en modo privado en este Mac',
			'auth.signIn' => 'Iniciar sesión',
			'auth.register' => 'Regístrate',
			'auth.or' => 'O',
			'auth.password' => 'Contraseña',
			'auth.forgotPassword' => '¿Olvidaste tu contraseña?',
			'auth.haveAccount' => '¿Ya tienes una cuenta?',
			'auth.noAccount' => '¿No tienes una cuenta?',
			'auth.continueWithApple' => 'Continuar con Apple',
			'auth.continueWithGoogle' => 'Continuar con Google',
			'auth.readPrivacyPolicy' => 'Leer política de privacidad',
			'auth.nameLabel' => 'Nombre',
			'auth.invalidEmail' => 'Introduce un email válido',
			'auth.confirmEmail' => 'Revisa tu email para confirmar el registro.',
			'auth.resetSent' => 'Email enviado. Revisa tu bandeja de entrada.',
			'auth.signInTitle' => 'Inicia sesión en Evolve',
			'auth.signUpTitle' => 'Crea tu cuenta',
			'auth.resetTitle' => 'Recuperar contraseña',
			'auth.emailLabel' => 'Correo electrónico',
			'auth.passwordMin8' => 'Usa al menos 8 caracteres.',
			'auth.sendResetLink' => 'Enviar enlace de recuperación',
			'privateData.deleteTitle' => 'Eliminar datos privados',
			'privateData.deleteMessage' => '¿Seguro que quieres eliminar toda la base de datos local cifrada? Esta acción es irreversible y los datos no se podrán recuperar.',
			'privateData.deleteSuccess' => 'Datos privados eliminados.',
			'privateData.deleteFailed' => 'La operación ha fallado.',
			'privateData.exportDoneTitle' => 'Exportación completada',
			'privateData.exportDoneClipboard' => 'El JSON está en el portapapeles: Linux no admite compartir archivos.',
			'privateData.exportDoneShare' => 'El JSON se envió al selector de uso compartido.',
			'icloudSync.title' => 'Sincronización de iCloud',
			'icloudSync.enableTitle' => 'Activar sincronización de iCloud',
			'icloudSync.syncNow' => 'Sincronizar ahora',
			'icloudSync.disclosureTitle' => 'Cifrado de extremo a extremo',
			'icloudSync.disclosureBody' => 'Tus datos privados se sincronizan únicamente a través de tu propia cuenta de iCloud, con cifrado de extremo a extremo, nunca a través de nuestros servidores. La clave de cifrado reside en tu Llavero de iCloud; si desactivas el Llavero de iCloud, los datos sincronizados no podrán recuperarse.',
			'icloudSync.disclosureAccept' => 'Activar',
			'icloudSync.statusIdle' => 'Actualizado',
			'icloudSync.statusNotSynced' => 'No se ha sincronizado todo',
			'icloudSync.statusSyncing' => 'Sincronizando…',
			'icloudSync.statusOff' => 'Sincronización desactivada',
			'icloudSync.statusNoAccount' => 'Inicia sesión en iCloud para sincronizar',
			'icloudSync.statusUnavailable' => 'iCloud no está disponible ahora',
			'icloudSync.statusWaitingKeychain' => 'Esperando el Llavero de iCloud — asegúrate de que la app de tu iPhone esté actualizada',
			'icloudSync.lastSyncedNever' => 'Nunca sincronizado',
			'icloudSync.lastSyncedAt' => ({required Object time}) => 'Última sincronización ${time}',
			'icloudSync.deleteSyncNote' => 'La sincronización de iCloud está activada: también se eliminará la copia sincronizada de tu iCloud y se desactivará la sincronización. Los demás dispositivos conservan su copia local — ejecuta esta acción en cada dispositivo para borrarlo todo en todas partes.',
			'icloudSync.bannerText' => 'La sincronización con iCloud está desactivada: tus hábitos solo están en este dispositivo y se perderán si lo restableces o lo reemplazas.',
			'icloudSync.bannerAction' => 'Activar',
			'icloudSync.detailsTitle' => 'Detalles de sincronización',
			'icloudSync.detailsAllSynced' => 'Todo subido',
			'icloudSync.detailsPending' => ({required Object count}) => '${count} elementos pendientes de subir',
			'icloudSync.detailsFailed' => ({required Object count}) => '${count} elementos no se han subido',
			'icloudSync.detailsCopy' => 'Copiar informe',
			'icloudSync.detailsCopied' => 'Informe copiado',
			'icloudSync.keySplitTitle' => 'Algunos datos de iCloud no se pueden leer',
			'icloudSync.keySplitBody' => ({required Object count}) => '${count} registros en iCloud se cifraron en otro dispositivo con una clave distinta, por lo que este dispositivo no puede leerlos. Restablece la sincronización desde el dispositivo que tenga los datos que quieres conservar.',
			'icloudSync.resetFromDevice' => 'Restablecer la sincronización desde este dispositivo',
			'icloudSync.resetFromDeviceDetail' => 'Sustituir todo lo que hay en iCloud por los datos de este dispositivo',
			'icloudSync.resetFromDeviceConfirm' => 'Esto borra todo lo almacenado actualmente en iCloud y sube en su lugar los datos de este dispositivo. Tus otros dispositivos descargarán después esta copia. Hazlo solo desde el dispositivo que tenga los datos que quieres conservar. No se puede deshacer.',
			'icloudSync.resetFromDeviceDone' => 'Sincronización restablecida. Los datos de este dispositivo son ahora la copia en iCloud.',
			'icloudSync.statusWaitingKey' => 'Esperando la clave de cifrado de tu otro dispositivo',
			'icloudSync.forceEnableTitle' => 'Empezar de cero desde este dispositivo',
			'icloudSync.forceEnableBody' => 'Los datos de otro dispositivo ya están en iCloud, pero su clave de cifrado aún no ha llegado a este dispositivo. Normalmente basta con esperar unos minutos. Empezar de cero borra lo que hay en iCloud y lo sustituye por los datos de este dispositivo. No se puede deshacer.',
			'icloudSync.forceEnable' => 'Empezar de cero',
			'privateRecovery.preparing' => 'Preparando tu espacio privado…',
			'privateRecovery.restoredFromCloudToast' => 'No se pudo desbloquear la base de datos local: tus datos se restauraron desde iCloud.',
			'privateRecovery.waitingTitle' => 'Esperando a iCloud',
			'privateRecovery.waitingMessage' => 'La sincronización está activada, pero tu clave de cifrado aún no ha llegado desde el Llavero de iCloud. Espera un momento y vuelve a intentarlo.',
			'privateRecovery.lockedTitle' => 'No se pueden desbloquear los datos privados',
			'privateRecovery.lockedMessageLocalOnly' => 'Este dispositivo no puede desbloquear tu base de datos privada local —falta su clave de cifrado— y la sincronización de iCloud está desactivada, así que no hay copia en la nube para restaurar. Puedes restablecer y empezar de nuevo.',
			'privateRecovery.lockedMessageICloudUnavailable' => 'Este dispositivo no puede desbloquear tu base de datos privada local. La sincronización de iCloud está activada, pero la cuenta no está disponible: inicia sesión en iCloud y vuelve a intentarlo.',
			'privateRecovery.errorTitle' => 'No se pudo abrir el modo privado',
			'privateRecovery.errorMessage' => 'Algo salió mal al abrir tu base de datos privada. Vuelve a intentarlo o restablécela y empieza de nuevo.',
			'privateRecovery.enableSyncHint' => '¿Tienes estos datos en otro dispositivo? Activa la sincronización de iCloud en Ajustes después de restablecer para traerlos aquí.',
			'privateRecovery.retry' => 'Reintentar',
			'privateRecovery.resetFresh' => 'Restablecer y empezar de nuevo',
			'privateRecovery.backToSignIn' => 'Volver al inicio de sesión',
			'namePrompt.title' => '¿Cómo te llamas?',
			'namePrompt.subtitle' => 'Introduce tu nombre para personalizar el panel.',
			'namePrompt.hint' => 'Ej. Simo',
			'namePrompt.save' => 'Guardar y continuar',
			'nav.overview' => 'Resumen',
			'nav.habits' => 'Hábitos',
			'nav.insights' => 'Estadísticas',
			'nav.goals' => 'Objetivos',
			'nav.coach' => 'Coach AI',
			'nav.settings' => 'Ajustes',
			'shell.syncPending' => 'Sincronización pendiente',
			'shell.syncing' => 'Sincronizando',
			'shell.synced' => 'Sincronizado',
			'shell.syncTooltip' => 'Sincronizar',
			'shell.searchHint' => 'Buscar o navegar',
			'shell.searchSectionHint' => 'Buscar una sección...',
			'common.actions.cancel' => 'Cancelar',
			'common.actions.save' => 'Guardar',
			'common.actions.delete' => 'Eliminar',
			'common.actions.edit' => 'Editar',
			'common.actions.pick' => 'Elegir',
			'common.actions.gotIt' => 'Entendido',
			'common.actions.done' => 'Hecho',
			'common.months.0' => 'Enero',
			'common.months.1' => 'Febrero',
			'common.months.2' => 'Marzo',
			'common.months.3' => 'Abril',
			'common.months.4' => 'Mayo',
			'common.months.5' => 'Junio',
			'common.months.6' => 'Julio',
			'common.months.7' => 'Agosto',
			'common.months.8' => 'Septiembre',
			'common.months.9' => 'Octubre',
			'common.months.10' => 'Noviembre',
			'common.months.11' => 'Diciembre',
			'common.weekdayInitials.0' => 'L',
			'common.weekdayInitials.1' => 'M',
			'common.weekdayInitials.2' => 'X',
			'common.weekdayInitials.3' => 'J',
			'common.weekdayInitials.4' => 'V',
			'common.weekdayInitials.5' => 'S',
			'common.weekdayInitials.6' => 'D',
			'common.calendarView.year' => 'Año',
			'common.calendarView.month' => 'Mes',
			'common.calendarView.week' => 'Semana',
			'common.calendarView.life' => 'Vida',
			'common.weekdaysLong.0' => 'Lunes',
			'common.weekdaysLong.1' => 'Martes',
			'common.weekdaysLong.2' => 'Miércoles',
			'common.weekdaysLong.3' => 'Jueves',
			'common.weekdaysLong.4' => 'Viernes',
			'common.weekdaysLong.5' => 'Sábado',
			'common.weekdaysLong.6' => 'Domingo',
			'common.none' => 'Ninguno',
			'common.habits' => 'Hábitos',
			'common.status.error' => 'Error',
			'common.total' => 'Total',
			'common.completed' => 'Completados',
			'common.unexpectedErrorTitle' => 'Algo salió mal',
			'common.unexpectedErrorMessage' => 'Se ha producido un error inesperado. Inténtalo de nuevo.',
			'form.title' => 'Título',
			'form.category' => 'Categoría',
			'form.color' => 'Color',
			'form.add' => 'Añadir',
			'createGoal.title' => 'Nuevo objetivo',
			'createGoal.subtitle' => 'Define tu próximo objetivo.',
			'createGoal.titleHint' => 'p. ej. Lanzar el nuevo producto',
			'createGoal.categoryHint' => 'p. ej. Trabajo',
			'createGoal.timeline' => 'Cronología',
			'createGoal.thisWeek' => 'Esta semana',
			'createGoal.thisMonth' => 'Este mes',
			'createGoal.thisQuarter' => 'Este trimestre',
			'createGoal.thisYear' => 'Este año',
			'createGoal.longTerm' => 'A largo plazo (Lifetime)',
			'createGoal.dueLifetime' => 'Toda la vida',
			'createGoal.dueByYear' => ({required Object year}) => 'Antes de ${year}',
			'createGoal.defaultCategory' => 'Objetivo',
			'createGoal.periodWhen' => 'Cuándo',
			'createHabit.title' => 'Nuevo hábito',
			'createHabit.subtitle' => 'Define tu nuevo hábito.',
			'createHabit.titleHint' => 'p. ej. Meditación',
			'createHabit.weeklyFrequency' => 'Frecuencia semanal',
			'macroGoals.types.annual' => 'Anual',
			'macroGoals.types.quarterly' => 'Trimestral',
			'macroGoals.types.monthly' => 'Mensual',
			'macroGoals.types.weekly' => 'Semanal',
			'macroGoals.types.lifetime' => 'De por vida',
			'macroGoals.quarterNumber' => ({required Object quarter}) => 'Trimestre ${quarter}',
			'macroGoals.addLifetimeGoal' => 'Añadir objetivo de por vida...',
			'macroGoals.addAnnualGoal' => 'Añadir objetivo anual...',
			'macroGoals.addQuarterlyGoal' => 'Añadir objetivo trimestral...',
			'macroGoals.addMonthlyGoal' => 'Agregar objetivo mensual...',
			'macroGoals.addWeeklyGoal' => 'Añadir objetivo semanal...',
			'macroGoals.completed' => 'TERMINADO',
			'macroGoals.failed' => 'FALLIDO',
			'macroGoals.create' => 'Crear',
			'macroGoals.strength' => 'Punto fuerte',
			'macroGoals.bestMonth' => 'Mejor mes',
			'macroGoals.successRate2' => 'tasa de éxito',
			'macroGoals.effectiveType' => 'Tipología eficaz',
			'macroGoals.historicalTotal' => 'Total histórico',
			'macroGoals.from_' => 'de',
			'macroGoals.globalSuccess' => 'Éxito global',
			'macroGoals.completedGoals' => 'Objetivos completados',
			'macroGoals.bestYear' => 'Mejor año',
			'macroGoals.mostProductiveYear' => 'Año más productivo',
			'macroGoals.totalGoals' => 'Objetivos totales',
			'macroGoals.allYears' => 'Todos los años',
			'macroGoals.selectYearHeader' => 'Seleccionar año',
			'macroGoals.completions' => 'Completados',
			'macroGoals.success2' => 'Éxito',
			'macroGoals.archiveCategory2' => 'Archivar categoría',
			'macroGoals.categoryUnavailableLinked' => ({required Object label, required Object count}) => 'La categoría "${label}" ya no estará disponible para nuevos objetivos, pero seguirá vinculada a ${count} objetivos históricos y a tus estadísticas.',
			'macroGoals.categoryUnavailableArchived' => ({required Object label}) => 'La categoría "${label}" ya no estará disponible para nuevos objetivos, pero permanecerá en tu historial.',
			'macroGoals.archive' => 'Archivar',
			'macroGoals.createNewCategory' => 'Crear nueva categoría',
			'statistics.completed2' => 'Completado',
			'statistics.notCompleted' => 'No completado',
			'statistics.ofCompletion' => 'de completitud',
			'statistics.growth' => 'Crecimiento',
			'statistics.decline' => 'Descenso',
			'statistics.strongestDay' => 'Día más fuerte',
			'statistics.weakestDay' => 'Día más débil',
			'statistics.worstNegativeStreak' => 'Peor racha negativa',
			'statistics.missedConsecutiveDays' => 'días consecutivos fallados',
			'statistics.brokenStreaks' => 'Rachas interrumpidas',
			'statistics.noBrokenStreaks' => 'No se registraron rachas interrumpidas',
			'statistics.startedOn' => 'iniciada el',
			'statistics.moodCorrelation' => 'Correlación con el ánimo',
			'statistics.avgMood' => 'Ánimo medio (✓)',
			'statistics.avgEnergy' => 'Energía media (✓)',
			'statistics.onCompletedDays' => 'en los días completados',
			'statistics.resilient' => 'Resiliente',
			'statistics.completedVsMissed' => 'Completado vs fallado',
			'statistics.mood2' => 'Estado de ánimo',
			'statistics.energy' => 'Energía',
			'statistics.performancePerLevel' => 'Rendimiento por nivel',
			'statistics.withHighMood' => 'Con ánimo alto',
			'statistics.withLowMood' => 'Con ánimo bajo',
			'statistics.moodEnergyAnalysis' => 'El análisis muestra cómo tu constancia se ve influida por tu estado de ánimo y energía.',
			'statistics.missed2' => 'Fallado',
			'statistics.positive' => 'positiva',
			'statistics.neutral' => 'neutra',
			'statistics.high' => 'alta',
			'statistics.low' => 'baja',
			'statistics.skipped' => 'Omitido',
			'statistics.criticalHabits' => 'Hábitos críticos',
			'statistics.bestHabitsTitle' => 'Mejores hábitos',
			'statistics.worseningHabitsDescription' => 'Hábitos que están empeorando.',
			'statistics.everythingIsGreat' => 'Todo va bien',
			'statistics.allHabitsStableDescription' => 'Todos tus hábitos mantienen o mejoran su tendencia. Sigue avanzando.',
			'statistics.habitCompletionPeriodDescription' => ({required Object rate}) => 'Completaste este hábito el ${rate}% de las veces en el periodo seleccionado.',
			'statistics.habitLostConsistencyDescription' => ({required Object drop}) => 'Este hábito perdió un ${drop}% de constancia en la última semana respecto a la anterior.',
			'statistics.negativeStreak' => 'Racha negativa',
			'statistics.currentStreak2' => 'Racha actual',
			'statistics.improvementAreas' => 'Áreas de mejora',
			'statistics.habitsRequiringMoreAttention' => 'Hábitos que requieren más atención.',
			'statistics.failureAnalysis' => 'Análisis de fallos',
			'statistics.missedDaysPattern' => 'Frecuencia y patrones de tus días fallados.',
			'statistics.recoveryPatterns' => 'Patrones de recuperación',
			'statistics.recoverySpeed' => 'Qué tan rápido vuelves al camino tras un fallo.',
			'statistics.avgRecoveryTime' => 'Tiempo medio de recuperación',
			'statistics.worstStreak' => 'Peor racha',
			'statistics.frequency' => 'FRECUENCIA',
			'statistics.daysShortUnit' => 'd',
			'statistics.perMonthUnit' => 'mes',
			'statistics.succ' => 'éxito',
			'statistics.blackDay' => 'DÍA CRÍTICO',
			'statistics.correlationsWith' => 'Correlaciones con',
			'statistics.howThisHabitRelatesToOthers' => 'Cómo se relaciona este hábito con los demás',
			'statistics.positiveCorrelations' => 'Correlaciones positivas',
			'statistics.negativeCorrelations' => 'Correlaciones negativas',
			'statistics.noSignificantPositiveCorrelation' => 'Sin correlación positiva significativa',
			'statistics.noSignificantNegativeCorrelation' => 'Sin correlación negativa significativa',
			'statistics.habitTogetherPercent' => ({required Object percentage}) => '${percentage}% juntas',
			'statistics.habitPositiveCorrelationDescription' => ({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'Cuando completas "${currentGoal}", tienes un ${percentage}% de probabilidad de completar también "${otherGoal}".',
			'statistics.habitNegativeCorrelationDescription' => ({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'Cuando completas "${currentGoal}", solo tienes un ${percentage}% de probabilidad de completar también "${otherGoal}".',
			'statistics.weeklyTrend' => 'Tendencia semanal',
			'statistics.monthlyTrend' => 'Tendencia mensual',
			'statistics.yearlyTrend' => 'Tendencia anual',
			'statistics.performanceEvolution' => 'Evolución del rendimiento',
			'statistics.globalTrend' => 'Tendencia mundial',
			'statistics.total' => 'Total',
			'statistics.all' => 'Todo',
			'statistics.noDataForAlerts' => 'No hay datos suficientes para generar alertas.',
			'statistics.missed' => 'Fallados',
			'goalState.active' => 'En curso',
			'dueLabel.lifetime' => 'Objetivo de vida',
			'dueLabel.annual' => 'Objetivo anual',
			'dueLabel.quarter' => 'Trimestre',
			'dashboard.mood' => 'Estado de ánimo',
			'dashboard.energy' => 'Energía',
			'dashboard.goodMorning' => 'Buenos días',
			'dashboard.goodAfternoon' => 'Buenas tardes',
			'dashboard.goodEvening' => 'Buenas noches',
			'dashboard.manager' => 'Gestión',
			'dashboard.aiChat' => 'Chat AI',
			'dashboard.consecutiveDays' => 'días consecutivos',
			'dashboard.welcomeTitle' => 'Bienvenido a Evolve',
			'dashboard.welcomeSubtitle' => 'Comienza tu camino de crecimiento personal.',
			'dashboard.welcomeBody' => 'Esta aplicación te ayuda a crear buenos hábitos y alcanzar tus objetivos a largo plazo.',
			'dashboard.welcomeStart' => 'Comenzar',
			'dashboard.subtitle' => 'Mantén el ritmo. Cada pequeña acción refuerza a la persona que estás construyendo.',
			'dashboard.completionToday' => 'Completado hoy',
			'dashboard.habitsCount' => ({required Object done, required Object total}) => '${done}/${total} hábitos',
			'dashboard.bestStreak' => 'Mejor racha',
			'dashboard.activeGoals' => 'Objetivos activos',
			'dashboard.avgProgress' => ({required Object pct}) => '${pct}% progreso medio',
			'dashboard.momentum' => 'Momentum',
			'dashboard.vsLastWeek' => 'respecto a la semana pasada',
			'dashboard.weeklyTrend' => 'Tendencia semanal',
			'dashboard.weeklyTrendSubtitle' => 'Porcentaje de finalización de tus hábitos',
			'dashboard.thisWeekPill' => ({required Object value}) => '${value} esta semana',
			'dashboard.todayProtocol' => 'Protocolo de hoy',
			'dashboard.todayProtocolSubtitle' => 'Completa las acciones esenciales antes de añadir más',
			'dashboard.actionsCount' => ({required Object count}) => '${count} acciones',
			'dashboard.emptyHabits' => 'Tu lienzo está vacío. Crea tu primer hábito.',
			'dashboard.streakDaysShort' => ({required Object n}) => '${n} d',
			'dashboard.checkInDone' => 'Registro guardado',
			'dashboard.checkInPrompt' => '¿Cómo te sientes hoy?',
			'dashboard.moodEnergyValue' => ({required Object mood, required Object energy}) => 'Ánimo ${mood}/10 · Energía ${energy}/10',
			'dashboard.checkInHint' => 'Registra el ánimo y la energía para mejorar el análisis de tus patrones.',
			'dashboard.updateCheckIn' => 'Actualizar registro',
			'dashboard.doCheckIn' => 'Hacer el registro',
			'dashboard.dailyCheckIn' => 'Registro diario',
			'dashboard.dailyCheckInSubtitle' => 'Una medición rápida ayuda a Evolve a entender mejor tus patrones.',
			'dashboard.record' => 'Guardar',
			'dashboard.focusGoals' => 'Objetivos en foco',
			'dashboard.currentPriorities' => 'Prioridades actuales',
			'dashboard.goalLimitReached' => 'Límite de 100 objetivos alcanzado. Pasa a Pro para crear más.',
			'dashboard.emptyFocusGoals' => 'No hay objetivos en foco. Añade uno.',
			'dashboard.weekToStart' => 'Semana por empezar',
			'dashboard.weekGrowing' => 'Semana en crecimiento',
			'dashboard.weekToRecover' => 'Semana por recuperar',
			'dashboard.vsPreviousWeek' => ({required Object value}) => '${value} respecto a la semana anterior.',
			'stats.title' => 'Estadísticas',
			'stats.global' => 'Global',
			'stats.resilience' => 'Resiliencia',
			'stats.tabHabits' => 'Hábitos',
			'stats.tabMood' => 'Estado de ánimo',
			'stats.last30Days' => 'Últimos 30 días',
			'stats.singleHabit' => 'Hábito individual',
			'stats.noHabit' => 'Sin hábito',
			'stats.completionToday' => 'Completado hoy',
			'stats.bestStreakLabel' => 'Mejor racha',
			'stats.criticalDay' => 'Día crítico',
			'stats.completePrioritiesFirst' => 'Completa primero las prioridades',
			'stats.recentActivity' => 'Actividad reciente',
			'stats.recentActivitySubtitle' => 'Intensidad de finalización en los últimos 90 días',
			'stats.trendGlobal' => 'Tendencia global',
			'stats.trendGlobalSubtitle' => 'Comparación temporal del protocolo',
			'stats.vsPrevDay' => ({required Object value}) => '${value}% vs día anterior',
			'stats.bestHabit' => 'Mejor hábito',
			'stats.criticalArea' => 'Área crítica',
			'stats.streakAtRisk' => 'Racha en riesgo',
			'stats.streakAtRiskDetail' => ({required Object habit}) => '${habit} requiere atención en los próximos registros.',
			'stats.patternToConsolidate' => 'Patrón por consolidar',
			'stats.checkLowMoodDays' => 'Revisa los días de ánimo bajo y mantén el protocolo esencial.',
			'stats.goalDue' => 'Objetivo por vencer',
			'stats.noGoalNeedsIntervention' => 'Ningún objetivo activo requiere intervención.',
			'stats.performancePerHabit' => 'Rendimiento por hábito',
			'stats.performancePerHabitSubtitle' => 'Clasificación calculada a partir de los registros sincronizados por consistencia semanal',
			'stats.avgMood' => 'Ánimo medio',
			'stats.avgEnergy' => 'Energía media',
			'stats.checkInsAvailable' => ({required Object count}) => '${count} registros disponibles',
			'stats.resilientHabit' => 'Hábito resiliente',
			'stats.completedEvenHardDays' => 'Completada incluso en días difíciles',
			'stats.moodEnergy' => 'Ánimo y energía',
			'stats.moodEnergySubtitle' => 'Promedio de los registros disponibles en los últimos 90 días',
			'stats.completion' => 'Finalización',
			'stats.currentWeek' => 'Semana actual',
			'stats.currentStreak' => 'Racha actual',
			'stats.currentStreakDetail' => 'Racha sincronizada de los registros disponibles',
			'stats.trend30' => 'Tendencia 30 días',
			'stats.trend30Detail' => 'Finalización en los últimos 30 días',
			'stats.yearlyCalendar' => 'Calendario anual',
			'stats.yearlyCalendarSubtitle' => ({required Object habit}) => 'Distribución de finalizaciones de ${habit}',
			'stats.performancePerDay' => 'Rendimiento por día',
			'stats.performancePerDaySubtitle' => 'Días fuertes y débiles de la semana',
			'stats.protectStreak' => ({required Object days}) => 'Protege la racha de ${days} días',
			'stats.keepSameSlot' => 'Mantén la misma franja horaria para reducir la fricción en los días más intensos.',
			'stats.worstNegativeSeq' => ({required Object days}) => 'La peor racha negativa duró ${days} días.',
			'stats.positiveLever' => 'Palanca positiva detectada',
			'stats.bestHabitRegularity' => ({required Object habit}) => '${habit} mantiene la mejor regularidad reciente.',
			'stats.moodSensitivity' => 'Sensibilidad al ánimo',
			'stats.lowEnergyCompletion' => 'Finalización con energía baja',
			'stats.moodOutputCorrelation' => 'Correlación ánimo-rendimiento',
			'stats.moodOutputSubtitle' => 'Finalizaciones disponibles en los días con registro',
			'stats.keyCorrelations' => 'Correlaciones clave',
			'stats.keyCorrelationsSubtitle' => 'Patrones que más influyen en el protocolo',
			'stats.moreLogsNeeded' => 'Se necesitan más registros para calcular correlaciones útiles.',
			'stats.createHabitForAnalysis' => 'Crea al menos un hábito para ver el análisis granular.',
			'stats.noData' => 'Sin datos',
			'stats.tabInfo' => 'Info',
			'stats.tabTrend' => 'Tendencia',
			'stats.tabAlerts' => 'Alertas',
			'stats.tabOverview' => 'Resumen',
			'stats.tabCalendar' => 'Calendario',
			'stats.tabPerformance' => 'Rendimiento',
			'stats.tabImprovement' => 'Mejora',
			'stats.pageSubtitle' => 'Identifica los patrones que impulsan el crecimiento y actúa en las áreas críticas.',
			'stats.actionsFraction' => ({required Object done, required Object total}) => '${done}/${total} acciones',
			'stats.affectedByHardDays' => ({required Object habit}) => '${habit} se ve afectado por los días difíciles',
			'stats.last30DaysTrend' => 'Tendencia de los últimos 30 días',
			'stats.strongestDayDetail' => ({required Object pct, required Object done, required Object total}) => 'Bien hecho, ${pct}% de finalizacion (${done}/${total})',
			'stats.weakestDayDetail' => ({required Object pct, required Object done, required Object total}) => 'Solo ${pct}% de finalizacion (${done}/${total})',
			'stats.brokenStreakItem' => ({required Object days}) => 'Racha de ${days} dias interrumpida',
			'stats.togetherProbability' => ({required Object percentage}) => '${percentage}% juntos',
			'stats.criticalHabitsSubtitle' => 'Hábitos que están empeorando.',
			'stats.bestHabitsSubtitle' => 'Los habitos en los que eres mas constante.',
			'stats.timeframeWeek' => 'Semana',
			'stats.timeframeMonth' => 'Mes',
			'stats.timeframeYear' => 'Año',
			'stats.timeframeAll' => 'Todo',
			'stats.negativeStreakDays' => ({required Object days}) => '${days} dias sin completar',
			'stats.dropPercent' => ({required Object drop}) => '-${drop}%',
			'stats.blackDayDetail' => ({required Object day}) => 'Dia negro: ${day}',
			'stats.failureDetail' => ({required Object streak, required Object frequency}) => 'Peor racha: ${streak}d · ~${frequency}/mes perdidos',
			'stats.recoveryDetail' => ({required Object days}) => 'Tiempo medio de recuperacion: ${days} dias',
			'stats.successRate' => ({required Object rate}) => '${rate}% exito',
			'stats.sortRate' => 'Porcentaje',
			'stats.sortStreak' => 'Racha',
			'stats.sortName' => 'Nombre',
			'stats.filterActive' => 'Activos',
			'stats.filterAll' => 'Todos',
			'stats.noActiveHabits' => 'No hay hábitos activos. Cambia a Todos para ver los finalizados.',
			'stats.worstStreakLabel' => 'Peor',
			'stats.momentumTitle' => 'Impulso',
			'stats.momentumSubtitle' => 'Tu forma actual',
			'stats.momentumForm' => 'FORMA',
			'stats.momentumRate' => '7 días',
			'stats.momentumStreakHealth' => 'Rachas',
			'stats.momentumTrend' => 'Tendencia',
			'stats.rollingImproving' => 'Mejorando',
			'stats.rollingDeclining' => 'Bajando',
			'stats.rollingSteady' => 'Estable',
			'stats.lifetimeConsistency' => 'Constancia',
			'stats.lifetimeConsistencyDetail' => 'Completado histórico',
			'stats.lifetimeTotalDone' => 'Total completado',
			'stats.lifetimeTotalDoneDetail' => 'Hábitos marcados',
			'stats.lifetimePerfectDays' => 'Días perfectos',
			'stats.lifetimePerfectDaysDetail' => 'Todo completado',
			'stats.lifetimeDaysTracked' => 'Días registrados',
			'stats.lifetimeDaysTrackedDetail' => 'Desde que empezaste',
			'stats.keystoneTitle' => 'HÁBITO CLAVE',
			'stats.keystoneImpact' => ({required Object withPct, required Object withoutPct}) => 'En sus días completas el ${withPct}% de tus otros hábitos, frente al ${withoutPct}%.',
			'stats.yearActivity' => 'Actividad de 365 días',
			'stats.yearActivitySubtitle' => 'Cada hábito, cada día',
			'stats.activeDaysCount' => ({required Object count}) => '${count} días activos',
			'stats.heatmapLess' => 'Menos',
			'stats.heatmapMore' => 'Más',
			'stats.bestHabitsTitle' => 'Mejores hábitos',
			'stats.criticalHabitsTitle' => 'Requiere atención',
			'stats.criticalStalled' => ({required Object days}) => '${days}d parado',
			'stats.rollingTitle' => 'Completado móvil',
			'stats.rollingSubtitle' => 'Tasa de 7 y 30 días',
			'stats.rolling7' => '7 días',
			'stats.rolling30' => '30 días',
			'stats.weekVsAvgTitle' => 'Esta semana vs media',
			'stats.weekVsAvgSubtitle' => 'Cómo va esta semana',
			'stats.thisWeek' => 'Esta semana',
			'stats.yourAverage' => 'Tu media',
			'stats.weekdayShapeTitle' => 'Ritmo semanal',
			'stats.weekdayShapeSubtitle' => 'Completado por día',
			'stats.weekdayWeekendTitle' => 'Semana vs fin de semana',
			'stats.weekdayWeekendSubtitle' => 'Dónde eres más fuerte',
			'stats.weekdaysLabel' => 'Entre semana',
			'stats.weekendLabel' => 'Fin de semana',
			'stats.seasonalityTitle' => 'Estacionalidad',
			'stats.seasonalitySubtitle' => 'Completado por mes',
			'stats.bounceBackTitle' => 'Tasa de recuperación',
			'stats.bounceBackSubtitle' => 'Recuperación tras un fallo',
			'stats.bounceBackDetail' => ({required Object recoveries, required Object opportunities}) => 'Recuperado ${recoveries} de ${opportunities} veces',
			'stats.dangerZoneTitle' => 'Zona de peligro',
			'stats.dangerZoneSubtitle' => 'Cuándo se rompen las rachas',
			'stats.dangerZoneNone' => 'Aún no hay rachas rotas',
			'stats.dangerZoneDetail' => ({required Object breaks, required Object total}) => '${breaks} de ${total} rupturas aquí',
			'stats.performanceComparisonTitle' => 'Comparación de rendimiento',
			'stats.performanceComparisonSubtitle' => 'Mejor vs peor racha',
			'stats.perfCompGap' => ({required Object pct}) => '${pct}% de diferencia',
			'stats.perfCompBest' => 'Mejor',
			'stats.perfCompWorst' => 'Peor',
			'stats.consistencyTitle' => 'Constancia',
			'stats.consistencySubtitle' => 'Hábitos más regulares',
			'stats.consistencySteadiest' => 'Más constantes',
			'stats.consistencyErratic' => 'Más irregulares',
			'stats.medalsTitle' => 'Clasificación de rachas',
			'stats.medalsSubtitle' => 'Rachas actuales más largas',
			'stats.neverMissedTitle' => 'Nunca fallado',
			'stats.neverMissedEmpty' => 'Aún no hay hábitos perfectos',
			'stats.distributionTitle' => 'Distribución',
			'stats.distributionSubtitle' => 'Hábitos por tasa de éxito',
			'stats.synergyTitle' => 'Sinergia de hábitos',
			'stats.synergySubtitle' => 'Qué hábitos van juntos',
			'stats.moodSensitiveTitle' => 'Sensibles al ánimo',
			'stats.moodSensitiveSubtitle' => 'Más influidos por tu ánimo',
			'stats.resilientHabitsTitle' => 'Hábitos resilientes',
			'stats.resilientHabitsSubtitle' => 'Hechos incluso en días bajos',
			'stats.correlationAnalysisTitle' => 'Correlación de ánimo',
			'stats.correlationAnalysisSubtitle' => 'Completado con ánimo bajo vs alto',
			'stats.moodEnergyTrendTitle' => 'Ánimo y energía',
			'stats.moodEnergyTrendSubtitle' => ({required Object days}) => 'Últimos ${days} días',
			'stats.allTimeBest' => 'Récord histórico',
			'stats.topPerformerLabel' => 'El mejor',
			'stats.currentStreakShort' => 'Ahora',
			'stats.recordLabel' => 'Récord',
			'stats.recordDetail' => 'Mejor racha de siempre',
			'stats.adherenceTitle' => 'Adherencia al plan',
			'stats.adherenceSubtitle' => 'De los días programados',
			'stats.adherenceDetail' => ({required Object done, required Object scheduled}) => '${done} de ${scheduled} días programados',
			'stats.atRiskTitle' => 'En riesgo',
			'stats.atRiskYes' => 'Sí',
			'stats.atRiskNo' => 'En marcha',
			'stats.atRiskDetail' => ({required Object days}) => '${days} días desde la última vez',
			'stats.daysUnit' => 'd',
			'stats.gapTitle' => 'Intervalos',
			'stats.gapSubtitle' => 'Días entre completados',
			'stats.gapAvg' => 'Media',
			'stats.gapLongest' => 'Máximo',
			'stats.gapSince' => 'Desde el último',
			'stats.habitBounceBackShort' => 'Recuperación',
			'stats.habitConsistencyDetail' => 'Puntuación de regularidad',
			'stats.habitPercentile' => ({required Object pct}) => 'Mejor que el ${pct}% de tus hábitos',
			'stats.monthVsTitle' => 'Este mes vs anterior',
			'stats.monthVsSubtitle' => 'Completado mes a mes',
			'stats.thisMonthLabel' => 'Este mes',
			'stats.lastMonthLabel' => 'Mes pasado',
			'stats.nextDayMoodTitle' => 'Impacto en el ánimo del día siguiente',
			'stats.nextDayMoodSubtitle' => 'Ánimo y energía al día siguiente',
			'stats.nextDayAfterDone' => 'Tras hacerlo',
			_ => null,
		} ?? switch (path) {
			'stats.nextDayAfterMissed' => 'Tras fallarlo',
			'stats.nextDayMoodLift' => ({required Object value}) => '${value} más de ánimo',
			'stats.streakHistoryTitle' => 'Historial de rachas',
			'stats.streakHistorySubtitle' => 'Cada serie de días consecutivos',
			'stats.streakHistoryDetail' => ({required Object count, required Object longest}) => '${count} rachas · la más larga ${longest} días',
			'habitsPage.today' => 'Hoy',
			'habitsPage.subtitle' => 'Construye tu protocolo diario y observa la constancia a lo largo del tiempo.',
			'habitsPage.tabProtocol' => 'Protocolo',
			'habitsPage.tabCalendar' => 'Calendario',
			'habitsPage.deleteHabitTitle' => 'Eliminar hábito',
			'habitsPage.deleteHabitConfirm' => ({required Object title}) => '¿Quitar "${title}" del protocolo?',
			'habitsPage.activeProtocol' => 'Protocolo activo',
			'habitsPage.completedToday' => 'Completadas hoy',
			'habitsPage.dailyProtocol' => 'Protocolo diario',
			'habitsPage.protocolSubtitle' => 'Resumen semanal, recordatorios y acciones rápidas',
			'habitsPage.colHabit' => 'HÁBITO',
			'habitsPage.colStreak' => 'RACHA',
			'habitsPage.colLast7Days' => 'ÚLTIMOS 7 DÍAS',
			'habitsPage.colReminder' => 'RECORDATORIO',
			'habitsPage.streakDays' => ({required Object n}) => '${n} días',
			'habitsPage.prevPeriod' => 'Período anterior',
			'habitsPage.nextPeriod' => 'Período siguiente',
			'habitsPage.weekdayAbbrevUpper.0' => 'LUN',
			'habitsPage.weekdayAbbrevUpper.1' => 'MAR',
			'habitsPage.weekdayAbbrevUpper.2' => 'MIÉ',
			'habitsPage.weekdayAbbrevUpper.3' => 'JUE',
			'habitsPage.weekdayAbbrevUpper.4' => 'VIE',
			'habitsPage.weekdayAbbrevUpper.5' => 'SÁB',
			'habitsPage.weekdayAbbrevUpper.6' => 'DOM',
			'habitsPage.lifeView' => 'Vista de vida',
			'habitsPage.lifeViewSubtitle' => 'Una celda representa un mes del camino hasta los 85 años.',
			'habitsPage.monthsLived' => 'Meses vividos',
			'habitsPage.currentAge' => 'Edad actual',
			'habitsPage.monthsRemaining' => 'Meses restantes',
			'habitsPage.dayDetail' => ({required Object day, required Object month}) => 'Detalle ${day} ${month}',
			'habitsPage.dayDetailSubtitle' => 'Actualiza el estado de los hábitos para este día.',
			'habitsPage.editHabit' => 'Editar hábito',
			'habitsPage.newHabit' => 'Nuevo hábito',
			'habitsPage.optionalReminder' => 'Recordatorio opcional',
			'habitsPage.reminderHint' => 'p. ej. 08:30',
			'habitsPage.close' => 'Cerrar',
			'habitsPage.statusDone' => 'Completada',
			'habitsPage.statusSkipped' => 'Omitida',
			'habitsPage.statusUnrecorded' => 'No registrada',
			'habitsPage.weekOf' => ({required Object day, required Object month}) => 'Semana del ${day} ${month}',
			'habitsPage.lifeWeeks' => 'Semanas de tu camino',
			'habitsPage.catMindfulness' => 'Mindfulness',
			'habitsPage.editableHint' => 'Solo se pueden editar hoy y ayer.',
			'lavoro' => 'Trabajo',
			'salute' => 'Salud',
			'finanza' => 'Finanzas',
			'relazioni' => 'Relaciones',
			'formazione' => 'Formación',
			'hobby' => 'Hobby',
			'spirituale' => 'Espiritualidad',
			'altro' => 'Otro',
			'goalsPage.title' => 'Macroobjetivos',
			'goalsPage.subtitle' => 'Planificación a largo plazo.',
			'goalsPage.sampleGoal' => 'Objetivo de ejemplo',
			'goalsPage.periodLifetime' => 'Objetivos de vida',
			'goalsPage.subtitleLifetime' => 'Objetivos Lifetime',
			'goalsPage.subtitleAnnual' => 'Objetivos anuales',
			'goalsPage.subtitleQuarterly' => 'Objetivos trimestrales',
			'goalsPage.subtitleMonthly' => 'Objetivos mensuales',
			'goalsPage.subtitleWeekly' => 'Objetivos semanales',
			'goalsPage.statsTab' => 'Stats',
			'goalsPage.fullView' => 'Vista completa',
			'goalsPage.categoriesTitle' => 'Categorías de objetivos',
			'goalsPage.defaultPill' => 'Predeterminada',
			'goalsPage.editCategory' => 'Editar categoría',
			'goalsPage.archiveCategory' => 'Archivar categoría',
			'goalsPage.categoryCreateFailed' => 'No se pudo crear la categoría.',
			'goalsPage.categoryArchiveFailed' => 'No se pudo archivar la categoría.',
			'goalsPage.categoryEditFailed' => 'No se pudo editar la categoría.',
			'goalsPage.addCategory' => 'Añadir categoría',
			'goalsPage.back' => 'Atrás',
			'goalsPage.finish' => 'Finalizar',
			'goalsPage.next' => 'Siguiente',
			'goalsPage.categoriesTooltip' => 'Categorías',
			'goalsPage.rescheduleTooltip' => 'Reprogramar al período siguiente',
			'goalsPage.defaultCategory' => 'Predeterminada',
			'goalsPage.emptyActive' => 'Ningún objetivo activo en este período.',
			'goalsPage.emptyAdd' => 'Añade el primer objetivo para este período.',
			'goalsPage.newGoal' => 'Nuevo objetivo',
			'goalsPage.editGoal' => 'Editar objetivo',
			'goalsPage.horizonLabel' => 'Horizonte',
			'goalsPage.newCategory' => 'Nueva categoría',
			'goalsPage.nameLabel' => 'Nombre',
			'goalsPage.weekPeriodLabel' => ({required Object week, required Object month, required Object year}) => 'Semana ${week}, ${month} ${year}',
			'goalsPage.currentQuarter' => 'Trimestre actual',
			'goalsPage.currentMonth' => 'Mes actual',
			'goalsStats.proRequired' => 'Función Pro requerida',
			'goalsStats.active' => 'Activos',
			'goalsStats.failed' => 'Fallidos',
			'goalsStats.complAbbr' => 'Compl.',
			'goalsStats.seasonality' => 'Estacionalidad',
			'goalsStats.interestEvolution' => 'Evolución de intereses',
			'ai.coach' => 'Coach AI',
			'ai.dailyHabits' => 'Hábitos diarios',
			'ai.macroGoals' => 'Macroobjetivos',
			'ai.openRouter.apiKeyMissingShort' => '⚠️ El Coach AI necesita tu propia clave de API de OpenRouter. Añádela en los ajustes para empezar a chatear.',
			'ai.openRouter.apiKeyInvalid' => '⚠️ OpenRouter ha rechazado esta clave de API. Revísala en los ajustes o crea una nueva en openrouter.ai/keys.',
			'ai.openRouter.defaultSystemPrompt' => 'Eres el "Coach de Disciplina", un asistente virtual centrado en ayudar al usuario a mantener la disciplina, alcanzar objetivos y construir hábitos saludables. Sé motivador pero concreto, directo y práctico. Usa un tono profesional pero cercano.',
			'ai.openRouter.communicationError' => ({required Object code}) => '❌ Error al comunicarse con la IA. (Código: ${code})',
			'ai.openRouter.connectionError' => '❌ Error de conexión. Asegúrate de estar online e inténtalo de nuevo.',
			'ai.openRouter.connectionErrorShort' => '❌ Error de conexión.',
			'ai.openRouter.connectionCheckTimeout' => '❌ Error: la comprobación de conexión tardó demasiado.',
			'ai.openRouter.contextTooLong' => '⚠️ Esta conversación se volvió demasiado larga para el modelo. Inicia un nuevo chat (arriba a la derecha) para continuar.',
			'ai.openRouter.noInternet' => '❌ Error: no hay conexión a internet. Revisa tu red.',
			'ai.openRouter.serverTimeout' => '❌ Error: el servidor tarda demasiado en responder. Inténtalo de nuevo.',
			'ai.openRouter.apiError' => ({required Object code}) => '❌ Error de API: ${code} (consulta Sentry para más detalles)',
			'ai.apiKey.rowTitle' => 'Tu cuenta de OpenRouter',
			'ai.apiKey.description' => '¿Prefieres ejecutar el coach en tu propia cuenta? Conecta una clave de OpenRouter y pagarás directamente al proveedor, sin suscripción a Evolve. Crea una en openrouter.ai/keys: se guarda en el llavero de este dispositivo y solo se envía a OpenRouter.',
			'ai.apiKey.fieldLabel' => 'Clave de API',
			'ai.apiKey.hint' => 'sk-or-v1-…',
			'ai.apiKey.save' => 'Guardar clave',
			'ai.apiKey.saved' => 'Clave de API guardada',
			'ai.apiKey.remove' => 'Eliminar clave',
			'ai.apiKey.removed' => 'Clave de API eliminada',
			'ai.apiKey.removeConfirmTitle' => '¿Eliminar la clave de API?',
			'ai.apiKey.removeConfirmBody' => 'Este motor dejará de responder hasta que vuelvas a conectar una cuenta. Evolve AI y los modelos locales no se ven afectados.',
			'ai.apiKey.statusSet' => 'Guardada',
			'ai.apiKey.statusMissing' => 'Sin configurar',
			'ai.apiKey.saveFailed' => 'No se ha podido guardar la clave en el llavero. Inténtalo de nuevo.',
			'ai.apiKey.setupTitle' => 'Conecta tu cuenta de OpenRouter',
			'ai.apiKey.setupBody' => 'Este motor funciona con tu propia cuenta de OpenRouter. Conéctala para empezar a chatear o cambia a Evolve AI, incluido en Pro.',
			'ai.apiKey.setupAction' => 'Conectar cuenta',
			'ai.coachPrompts.diagnoseWeakestHabit.label' => '🩺 Arregla mi hábito más débil',
			'ai.coachPrompts.diagnoseWeakestHabit.payload' => ({required Object habit, required Object done, required Object scheduled}) => '\'${habit}\' es mi hábito más débil esta semana — ${done}/${scheduled} días cumplidos. ¿Cuál es la razón más probable por la que me lo salto y dos soluciones concretas que pueda aplicar esta semana?',
			'ai.coachPrompts.goalOnTrack.label' => '🎯 ¿Voy por buen camino?',
			'ai.coachPrompts.goalOnTrack.payload' => ({required Object goal}) => 'Sé sincero sobre mi objetivo \'${goal}\': ¿voy por buen camino para lograrlo y cuál es el único cambio que más mejoraría mis probabilidades?',
			'ai.coachPrompts.weeklyReviewDown.label' => '📉 Analiza mi semana',
			'ai.coachPrompts.weeklyReviewDown.payload' => ({required Object thisPct, required Object lastPct}) => 'Mi constancia bajó al ${thisPct}% esta semana desde el ${lastPct}% de la anterior. ¿Cuál es la causa más probable y el único cambio que debería hacer la próxima semana?',
			'ai.coachPrompts.weeklyReviewUp.label' => '📊 Analiza mi semana',
			'ai.coachPrompts.weeklyReviewUp.payload' => ({required Object thisPct, required Object lastPct}) => 'Mi constancia está en el ${thisPct}% esta semana frente al ${lastPct}% de la anterior. ¿Qué está funcionando y qué es lo único que debería impulsar más la próxima semana?',
			'ai.coachPrompts.protectStreak.label' => '🛡️ Protege mi racha',
			'ai.coachPrompts.protectStreak.payload' => ({required Object habit, required Object days}) => 'Mi racha activa más larga es \'${habit}\' con ${days} días. ¿Cuál es el mayor riesgo de romperla y cómo la protejo esta semana?',
			'ai.coachPrompts.alignHabitsToGoal.label' => '🔗 ¿Qué hábitos sirven a mis objetivos?',
			'ai.coachPrompts.alignHabitsToGoal.payload' => ({required Object goal}) => 'Mirando mis hábitos frente a mi objetivo \'${goal}\', ¿cuáles lo hacen avanzar de verdad y cuáles son solo ruido? Sé específico e indica un hábito que quizá me falte.',
			'ai.coachPrompts.designHabitForGoal.label' => '💡 Convierte un objetivo en hábito',
			'ai.coachPrompts.designHabitForGoal.payload' => ({required Object goal}) => 'Quiero alcanzar mi objetivo \'${goal}\'. ¿Qué único hábito diario marcaría la mayor diferencia? Dame un hábito concreto que pueda empezar mañana.',
			'ai.coachPrompts.raiseTheBar.label' => '🚀 Sube el listón',
			'ai.coachPrompts.raiseTheBar.payload' => 'Estoy cumpliendo todos mis hábitos y mis objetivos van por buen camino. ¿Dónde podría estar acomodándome y cuál es una forma de subir el listón sin quemarme?',
			'ai.coachPrompts.firstStep.label' => '🌱 ¿Por dónde empiezo?',
			'ai.coachPrompts.firstStep.payload' => 'Estoy empezando y aún no he configurado objetivos ni hábitos. Sugiéreme un primer objetivo realista y un pequeño hábito diario para lograrlo, y explica por qué esa combinación funciona.',
			'ai.coachPrompts.whatCanYouHelp.label' => '💬 ¿En qué puedes ayudarme?',
			'ai.coachPrompts.whatCanYouHelp.payload' => 'Según mis hábitos y objetivos en esta app, dame tres ejemplos concretos de cómo puedes ayudarme — no consejos genéricos, sino cosas ligadas a mis datos reales.',
			'ai.local.notReachable' => ({required Object url}) => '❌ No se puede acceder al servidor de IA local en ${url}. Asegúrate de que Ollama o LM Studio esté en ejecución.',
			'ai.local.modelMissing' => '⚠️ Elige primero un modelo local — abre el selector de modelos arriba.',
			'ai.local.requestFailed' => ({required Object code}) => '❌ Error del modelo local (código: ${code}).',
			'ai.local.streamError' => '❌ Error de conexión con el modelo local.',
			'ai.local.timeout' => '❌ El modelo local está tardando demasiado — puede que aún se esté cargando. Inténtalo de nuevo.',
			'ai.local.modelNotFound' => '❌ Ese modelo no está disponible en el servidor. Abre el selector para elegir o cargar uno.',
			'ai.local.authRequired' => ({required Object app}) => '❌ ${app} está rechazando la conexión — requiere un token de API. Desactiva la autenticación en los ajustes de su servidor o apunta Evolve a un servidor que no lo requiera.',
			'ai.local.stillLoading' => 'El modelo aún se está cargando — un arranque en frío puede tardar un poco.',
			'ai.standard.sessionExpired' => '⚠️ Tu sesión ha caducado. Inicia sesión de nuevo para seguir usando Evolve AI.',
			'ai.standard.needsPro' => '⚠️ Evolve AI forma parte de Evolve Pro. Suscríbete en Ajustes o cambia el motor a tu propia cuenta de OpenRouter, que es gratis.',
			'ai.standard.rateLimited' => '⚠️ Has alcanzado el límite de uso razonable de Evolve AI por ahora. Inténtalo más tarde o cambia el motor a tu propia cuenta de OpenRouter.',
			'ai.standard.unavailable' => '❌ Evolve AI no está disponible ahora mismo. Es cosa nuestra: inténtalo de nuevo en un momento.',
			'ai.consent.standardTitle' => '¿Enviar tus mensajes a la IA?',
			'ai.consent.standardBody' => 'Para responder, el AI Coach envía tu mensaje, tu nombre y el contexto que elijas compartir a OpenRouter, Inc., que lo dirige a Google LLC (Google AI Studio) para ejecutar el modelo. Al tratarse del plan gratuito de Google, Google puede conservar el texto durante un tiempo limitado y usarlo para mejorar sus servicios: no es tan privado como un plan de pago. Puedes retirar el consentimiento cuando quieras en Ajustes, y todo lo demás de Evolve sigue funcionando.',
			'ai.consent.byokTitle' => '¿Enviar tus mensajes a OpenRouter?',
			'ai.consent.byokBody' => 'Para responder, el AI Coach envía tu mensaje, tu nombre y el contexto que elijas compartir a OpenRouter, Inc. usando tu propia cuenta de OpenRouter. OpenRouter lo dirige a un proveedor de modelos según los ajustes de tu cuenta. Puedes retirar el consentimiento cuando quieras en Ajustes, y todo lo demás de Evolve sigue funcionando.',
			'ai.consent.privateNote' => 'Tu base de datos privada permanece en este dispositivo: solo sale lo que envías en el chat.',
			'ai.consent.allow' => 'Permitir',
			'ai.consent.decline' => 'Ahora no',
			'ai.consent.rowTitle' => 'Compartir datos con la IA',
			'ai.consent.statusGranted' => 'Permitido',
			'ai.consent.statusNone' => 'No permitido',
			'ai.consent.revokeTitle' => '¿Dejar de compartir con la IA?',
			'ai.consent.revokeBody' => 'El AI Coach volverá a pedir permiso antes de enviar nada. No cambia nada más.',
			'ai.consent.revokeAction' => 'Dejar de compartir',
			'aiCoach.greeting' => '¡Hola! Soy Evolve AI Coach. Estoy aquí para ayudarte a optimizar tu protocolo y alcanzar tus objetivos. ¿Cómo puedo ayudarte hoy?',
			'aiCoach.systemPersona' => 'Eres Evolve AI Coach, un asistente virtual para la disciplina personal.',
			'aiCoach.habitsHeader' => 'HÁBITOS ACTIVOS:',
			'aiCoach.noActiveHabits' => 'Sin hábitos activos.',
			'aiCoach.habitLine' => ({required Object title, required Object done, required Object streak}) => '${title} (Completado hoy: ${done}, Racha: ${streak})',
			'aiCoach.goalsHeader' => 'OBJETIVOS:',
			'aiCoach.noActiveGoals' => 'Sin objetivos a largo plazo activos.',
			'aiCoach.goalLine' => ({required Object title, required Object due}) => '${title} (Vence: ${due})',
			'aiCoach.contextTitle' => 'Contexto de IA',
			'aiCoach.contextBody' => 'Elige qué datos compartir con el Coach de IA para recibir consejos personalizados.',
			'aiCoach.shareHabitsDesc' => 'Comparte tus hábitos activos, las rachas y el estado de finalización de hoy.',
			'aiCoach.shareGoalsDesc' => 'Comparte tus objetivos activos a largo plazo.',
			'aiCoach.saveClose' => 'Guardar y cerrar',
			'aiCoach.subtitle' => 'Razona sobre los patrones con un coach contextual basado en los datos de tu camino.',
			'aiCoach.contextButton' => 'Contexto',
			'aiCoach.typing' => 'AI Coach está escribiendo...',
			'aiCoach.inputHint' => 'Pide consejos a tu Coach...',
			'aiCoach.defaultUserName' => 'Usuario',
			'aiCoach.userNameLine' => ({required Object userName}) => '- Nombre: ${userName}',
			'aiCoach.activeGoalsCount' => ({required Object count}) => '- Objetivos activos: ${count}',
			'aiCoach.completedGoalsCount' => ({required Object count}) => '- Objetivos completados: ${count}',
			'aiCoach.todayCompletion' => ({required Object completed, required Object total}) => '- Hábitos de hoy: ${completed} completados de ${total} en total.',
			'aiCoach.newChatTooltip' => 'Nuevo chat',
			'aiCoach.clearConfirmTitle' => '¿Iniciar un nuevo chat?',
			'aiCoach.clearConfirmBody' => 'Esto borra la conversación actual — no se guarda.',
			'aiCoach.clearConfirmCancel' => 'Cancelar',
			'aiCoach.clearConfirmAccept' => 'Nuevo chat',
			'aiCoach.copyTooltip' => 'Copiar',
			'aiCoach.copiedToast' => 'Copiado al portapapeles',
			'aiCoach.linkOpenFailed' => 'No se pudo abrir el enlace.',
			'settingsPage.account' => 'Cuenta',
			'settingsPage.notifications' => 'Notificaciones',
			'settingsPage.language' => 'Idioma',
			'settingsPage.timeFormat24h' => 'Formato 24h',
			'settingsPage.subscription' => 'Suscripción',
			'settingsPage.proName' => 'Evolve PRO',
			'settingsPage.planMonthly' => 'Mensual',
			'settingsPage.planAnnual' => 'Anual',
			'settingsPage.restorePurchases' => 'Restaurar compras',
			'settingsPage.deletePrivateData' => 'eliminar datos privados',
			'settingsPage.importInProgress' => 'Importando datos...',
			'settingsPage.passwordsDontMatch' => 'Las contraseñas no coinciden',
			'settingsPage.email' => 'Email',
			'settingsPage.cancel' => 'Cancelar',
			'settingsPage.confirm' => 'Confirmar',
			'settingsPage.save' => 'Guardar',
			'settingsPage.pageTitle' => 'Ajustes',
			'settingsPage.pageSubtitle' => 'Gestiona tu perfil, el comportamiento del escritorio, la privacidad y el plan Evolve.',
			'settingsPage.profileLabel' => 'Perfil',
			'settingsPage.profileSubtitle' => 'Información personal y estado de sincronización',
			'settingsPage.accountAndOnboarding' => 'Cuenta e incorporación',
			'settingsPage.privateMode' => 'Modo Privado',
			'settingsPage.sessionUnavailable' => 'Sesión no disponible',
			'settingsPage.dataRepository' => 'Repositorio de datos',
			'settingsPage.encryptedLocalDatabase' => 'Base de datos local cifrada',
			'settingsPage.supabaseWithEncryptedCache' => 'Supabase con caché cifrada',
			'settingsPage.personalInfo' => 'Información personal',
			'settingsPage.personalInfoDetail' => 'Nombre, apellido, correo electrónico y fecha de nacimiento',
			'settingsPage.updateAvatar' => 'Actualizar avatar',
			'settingsPage.updateAvatarDetail' => 'Elige una imagen local para el perfil de escritorio.',
			'settingsPage.reviewInitialConsent' => 'Revisar consentimiento inicial',
			'settingsPage.reviewInitialConsentDetail' => 'Términos, privacidad, notificaciones e informes de fallos',
			'settingsPage.signOut' => 'Cerrar sesión en tu cuenta',
			'settingsPage.signOutDetailActive' => 'Cierra la sesión en este dispositivo',
			'settingsPage.availableWithActiveSession' => 'Disponible con una sesión de Supabase activa',
			'settingsPage.goToLogin' => 'Ir al inicio de sesión',
			'settingsPage.goToLoginDetail' => 'Suspende el modo privado e inicia sesión en Supabase.',
			'settingsPage.appearanceTitle' => 'Apariencia y aplicación',
			'settingsPage.appearanceSubtitle' => 'Preferencias locales adaptadas al escritorio',
			'settingsPage.appearanceAndVisual' => 'Apariencia y aspecto visual',
			'settingsPage.themeMode' => 'Tema',
			'settingsPage.themeLight' => 'Claro',
			'settingsPage.themeDark' => 'Oscuro',
			'settingsPage.themeSystem' => 'Seguir al sistema',
			'settingsPage.calendarExperienceLanguage' => 'Calendario, experiencia e idioma',
			'settingsPage.accentColor' => 'Color de acento',
			'settingsPage.accentColorDetail' => 'Paleta ampliada reservada para Evolve Pro.',
			'settingsPage.defaultCalendarView' => 'Vista de calendario predeterminada',
			'settingsPage.calendarViewOptions.month' => 'Mes',
			'settingsPage.calendarViewOptions.week' => 'Semana',
			'settingsPage.calendarViewOptions.year' => 'Año',
			'settingsPage.calendarViewOptions.life' => 'Vida',
			'settingsPage.languageOptions.system' => 'Sistema',
			'settingsPage.languageOptions.italian' => 'Italiano',
			'settingsPage.languageOptions.english' => 'Inglés',
			'settingsPage.languageOptions.spanish' => 'Español',
			'settingsPage.languageOptions.german' => 'Alemán',
			'settingsPage.languageOptions.arabic' => 'Árabe',
			'settingsPage.timeFormat24hDetail' => 'Usa horas como 20:30 en lugar de 8:30 PM.',
			'settingsPage.hapticFeedback' => 'Respuesta háptica',
			'settingsPage.hapticFeedbackDetail' => 'El escritorio conserva la preferencia pero no genera vibraciones.',
			'settingsPage.aiAndSystem' => 'IA Y SISTEMA',
			'settingsPage.aiSuggestions' => 'Sugerencias de IA',
			'settingsPage.aiSuggestionsDetail' => 'Análisis inteligente de hábitos',
			'settingsPage.focusMode' => 'Modo enfoque',
			'settingsPage.focusModeDetail' => 'Pausa todos los recordatorios y las notificaciones.',
			'settingsPage.milestones' => 'Hitos',
			'settingsPage.milestonesDetail' => 'Celebraciones al alcanzar hitos clave.',
			'settingsPage.deepWorkInsights' => 'Insights de trabajo profundo',
			'settingsPage.deepWorkInsightsDetail' => 'Análisis avanzado de tus sesiones de concentración.',
			'settingsPage.resetTutorial' => 'Restablecer tutorial',
			'settingsPage.resetTutorialDetail' => 'Vuelve a abrir los tutoriales del panel y de los objetivos.',
			'settingsPage.notificationsSubtitle' => 'Recordatorios operativos del cliente de escritorio',
			'settingsPage.operationalReminders' => 'Recordatorios operativos',
			'settingsPage.habitReminders' => 'Recordatorios de hábitos',
			'settingsPage.habitRemindersDetail' => 'Envía el resumen matutino diario.',
			'settingsPage.morningBriefTime' => 'Hora del resumen matutino',
			'settingsPage.eveningReview' => 'Repaso nocturno',
			'settingsPage.eveningReviewDetail' => 'Te recuerda consolidar tu día.',
			'settingsPage.eveningReviewTime' => 'Hora del repaso nocturno',
			'settingsPage.insightsAndReports' => 'Insights e informes',
			'settingsPage.aiInsights' => 'Insights de IA',
			'settingsPage.aiInsightsDetail' => 'Análisis y consejos personalizados de la IA.',
			'settingsPage.weeklyReports' => 'Informes semanales',
			'settingsPage.weeklyReportsDetail' => 'Un resumen semanal de tu progreso.',
			'settingsPage.requestNotificationPermissions' => 'Solicitar permisos de notificación',
			'settingsPage.requestNotificationPermissionsDetail' => 'Abre el aviso nativo en la plataforma compatible.',
			'settingsPage.nativeDeliveryTitle' => 'Entrega nativa según el sistema operativo',
			'settingsPage.privacyTitle' => 'Privacidad y seguridad',
			'settingsPage.privacySubtitle' => 'Protección de acceso, consentimientos y gestión de datos',
			'settingsPage.accessProtection' => 'Protección de acceso',
			'settingsPage.biometricLock' => 'Bloqueo biométrico',
			'settingsPage.biometricLockDetail' => 'Disponible con el adaptador nativo en macOS y Windows; no compatible con Linux.',
			'settingsPage.changePassword' => 'Cambiar contraseña',
			'settingsPage.changePasswordDetail' => 'Actualización de credenciales mediante Supabase Auth.',
			'settingsPage.dataAndConsents' => 'Datos y consentimientos',
			'settingsPage.sendCrashReports' => 'Enviar informes de fallos',
			'settingsPage.sendCrashReportsDetail' => 'Consentimiento independiente para Sentry.',
			'settingsPage.exportData' => 'Exportar datos',
			'settingsPage.exportDataDetail' => 'Comparte una exportación JSON completa de los datos disponibles.',
			'settingsPage.importData' => 'Importar datos',
			'settingsPage.importDataDetail' => 'Restaura una copia de seguridad (JSON o ZIP) de Evolve.',
			'settingsPage.systemPermissionsManagement' => 'Gestión de permisos del sistema',
			'settingsPage.systemPermissionsManagementDetail' => 'Notificaciones, calendario y seguridad.',
			'settingsPage.deletePrivateDataDetail' => 'Elimina permanentemente la base de datos local cifrada.',
			'settingsPage.deleteAccountAndData' => 'Eliminar cuenta y datos',
			'settingsPage.deleteAccountAndDataDetail' => 'Operación irreversible protegida por confirmación.',
			'settingsPage.exportPrivateShareText' => 'Mis datos privados exportados desde Evolve',
			'settingsPage.exportShareText' => 'Mis datos exportados desde Evolve',
			'settingsPage.exportDoneTitle' => 'Exportación completada',
			'settingsPage.exportDoneClipboard' => 'El JSON está en el portapapeles: Linux no admite compartir archivos.',
			'settingsPage.exportDoneShare' => 'El JSON se envió al selector de uso compartido.',
			'settingsPage.avatarGateTitle' => 'Avatar',
			'settingsPage.avatarPickFailed' => 'No se pudo seleccionar la imagen.',
			'settingsPage.confirmSignOutTitle' => 'Confirmar cierre de sesión',
			'settingsPage.confirmSignOutMessage' => '¿Seguro que quieres cerrar sesión? Deberás volver a introducir tus credenciales para iniciar sesión de nuevo.',
			'settingsPage.gateProfile' => 'Perfil',
			'settingsPage.gateLogout' => 'Cerrar sesión',
			'settingsPage.gateChangePassword' => 'Cambio de contraseña',
			'settingsPage.gateRequiresActiveSession' => 'Requiere una sesión de Supabase activa.',
			'settingsPage.biometricActivationCancelled' => 'Activación cancelada.',
			'settingsPage.notificationPermissionsTitle' => 'Permisos de notificación',
			'settingsPage.notificationPermissionsGranted' => 'Permisos disponibles para este sistema.',
			'settingsPage.notificationPermissionsDenied' => 'Permiso no concedido. Puedes cambiarlo desde los ajustes del sistema.',
			'settingsPage.systemPermissionsTitle' => 'Permisos del sistema',
			'settingsPage.systemPermissionsOpenFailed' => 'No se pudieron abrir los ajustes.',
			'settingsPage.tutorialResetTitle' => 'Tutoriales restablecidos',
			'settingsPage.tutorialResetMessage' => 'Las guías se mostrarán de nuevo en las secciones correspondientes.',
			'settingsPage.accountDataManagementTitle' => 'Gestión de cuenta y datos',
			'settingsPage.accountDataManagementContent' => 'Elige si deseas eliminar los datos manteniendo la cuenta activa o eliminar la cuenta de forma permanente.',
			'settingsPage.resetDataAction' => 'Restablecer datos',
			'settingsPage.deleteAccountAction' => 'Eliminar cuenta',
			'settingsPage.confirmResetDataTitle' => 'Confirmar restablecimiento de datos',
			'settingsPage.confirmResetDataMessage' => 'Se eliminarán hábitos, objetivos y preferencias. La cuenta permanecerá activa. Esta acción no se puede deshacer.',
			'settingsPage.confirmDeleteAccountTitle' => 'Confirmar eliminación de la cuenta',
			'settingsPage.confirmDeleteAccountMessage' => 'La cuenta y todos los datos asociados se eliminarán de forma permanente. Esta acción es irreversible.',
			'settingsPage.resetDataTitle' => 'Restablecer datos',
			'settingsPage.resetDataSuccess' => 'Datos eliminados correctamente.',
			'settingsPage.operationFailed' => 'La operación falló.',
			'settingsPage.settingSaveFailed' => 'No se pudo guardar ese ajuste. Se ha restaurado su valor anterior.',
			'settingsPage.deleteAccountGateTitle' => 'Eliminar cuenta',
			'settingsPage.accountDeleted' => 'Cuenta eliminada.',
			'settingsPage.importDataGateTitle' => 'Importar datos',
			'settingsPage.importPrivateOnly' => 'La función de importación solo está disponible actualmente en el Modo Privado (Local).',
			'settingsPage.importSummaryTitle' => 'Resumen de importación',
			'settingsPage.importHabitsCount' => ({required Object count}) => '${count} Hábitos',
			'settingsPage.importLogsCount' => ({required Object count}) => '${count} Registros (Log)',
			'settingsPage.importMacroGoalsCount' => ({required Object count}) => '${count} Objetivos Macro',
			'settingsPage.importCategoriesCount' => ({required Object count}) => '${count} Categorías',
			'settingsPage.importMoodsCount' => ({required Object count}) => '${count} Registros de Estado de Ánimo',
			'settingsPage.importReplaceTitle' => 'Reemplazar los datos actuales',
			'settingsPage.importReplaceSubtitle' => 'Elimina permanentemente todos los registros existentes que no estén en esta copia.',
			'settingsPage.importMergeTitle' => 'Combinar con los datos actuales',
			'settingsPage.importMergeSubtitle' => 'Combina con tus datos, conservando la versión más reciente de cada elemento.',
			'settingsPage.importReplaceConfirmTitle' => '¿Reemplazar todos los datos?',
			'settingsPage.importReplaceConfirmMessage' => ({required Object count}) => 'Esto elimina permanentemente tus datos actuales (unos ${count} registros) y conserva solo lo que hay en esta copia. No se puede deshacer.',
			'settingsPage.importReplaceConfirmButton' => 'Eliminar y reemplazar',
			'settingsPage.importConfirmButton' => 'Confirmar importación',
			'settingsPage.importSuccess' => '¡Importación completada correctamente!',
			'settingsPage.importError' => ({required Object error}) => 'Error durante la importación: ${error}',
			'settingsPage.importLockedTitle' => '¿Restablecer la base de datos privada bloqueada?',
			'settingsPage.importLockedMessage' => 'Este dispositivo no puede desbloquear tu base de datos privada local: falta su clave de cifrado (ocurre tras cambiar de Mac o modificar la firma de la app). Los datos locales existentes no se pueden recuperar, pero puedes restablecerlos e importar esta copia de seguridad en una base de datos nueva y vacía. Esta acción no se puede deshacer.',
			'settingsPage.importLockedResetButton' => 'Restablecer e importar',
			'settingsPage.importPreviewSkipped' => ({required Object count}) => '⚠ Se omitirán ${count} registros no válidos',
			'settingsPage.importCompletedTitle' => 'Importación completada',
			'settingsPage.importSummaryReplaced' => 'Tus datos se reemplazaron con la copia de seguridad. Resumen:',
			'settingsPage.importSummaryMerged' => 'Tus datos se fusionaron con la copia de seguridad. Resumen:',
			'settingsPage.importSummaryDone' => '¡Genial!',
			'settingsPage.importEntityHabits' => 'Hábitos',
			'settingsPage.importEntityLogs' => 'Registros de hábitos',
			'settingsPage.importEntityMacroGoals' => 'Macro objetivos',
			'settingsPage.importEntityCategories' => 'Categorías',
			'settingsPage.importEntityMoods' => 'Registros de ánimo',
			'settingsPage.importRowReplace' => ({required Object count, required Object label}) => '${count} ${label}',
			'settingsPage.importRowMerge' => ({required Object label, required Object added, required Object updated, required Object unchanged}) => '${label}: ${added} añadidos, ${updated} actualizados, ${unchanged} sin cambios',
			'settingsPage.importRowSkipped' => ({required Object count}) => ', ${count} omitidos',
			'settingsPage.exportDoneSaved' => 'El archivo JSON se guardó en la ubicación elegida.',
			'settingsPage.proTitle' => 'Evolve Pro',
			'settingsPage.proSubtitle' => 'Plan, restauración de compras y gestión de suscripción',
			'settingsPage.billingAppleTitle' => 'Facturado a través de Apple',
			'settingsPage.commercialChannelRequired' => 'Compras no disponibles',
			'settingsPage.billingAppleDetail' => 'Tu suscripción se compra y gestiona con tu cuenta de Apple.',
			'settingsPage.billingUnavailableDetail' => 'Las suscripciones no están disponibles temporalmente. Inténtalo de nuevo más tarde.',
			'settingsPage.billingPlatformUnsupported' => 'Las compras dentro de la aplicación no están disponibles en esta plataforma.',
			'settingsPage.bestValue' => 'Mejor valor',
			'settingsPage.priceUnavailable' => 'Precio no disponible',
			'settingsPage.renewalDisclaimer' => 'La suscripción se renueva automáticamente a menos que se desactive la renovación automática en la configuración de la cuenta de Apple al menos 24 horas antes del final del período.',
			'settingsPage.privacyPolicy' => 'Política de privacidad',
			'settingsPage.termsEula' => 'Términos de uso (EULA)',
			'settingsPage.planManagement' => 'Gestión del plan',
			'settingsPage.activateEvolvePro' => 'Activar Evolve Pro',
			'settingsPage.activateEvolveProActive' => 'Derecho de Evolve Pro activo.',
			'settingsPage.activateEvolveProStart' => 'Suscríbete con tu cuenta de Apple.',
			'settingsPage.restorePurchasesDetail' => 'Restaura una suscripción que ya compraste.',
			'settingsPage.manageSubscription' => 'Gestionar suscripción',
			'settingsPage.manageSubscriptionDetail' => 'Abre la gestión de suscripciones de la cuenta de Apple.',
			'settingsPage.notAuthenticated' => 'No autenticado',
			'settingsPage.verified' => 'Verificado',
			'settingsPage.privateModeDataProtected' => 'Tus datos están protegidos y se guardan únicamente en este dispositivo.',
			'settingsPage.profileFallback' => 'Perfil',
			'settingsPage.fullName' => 'Nombre completo',
			'settingsPage.dateOfBirth' => 'Fecha de nacimiento',
			'settingsPage.dateOfBirthHint' => 'AAAA-MM-DD',
			'settingsPage.currentPassword' => 'Contraseña actual',
			'settingsPage.newPassword' => 'Nueva contraseña',
			'settingsPage.confirmNewPassword' => 'Confirmar nueva contraseña',
			'settingsPage.updatePassword' => 'Actualizar contraseña',
			'settingsPage.enterCurrentPassword' => 'Introduce tu contraseña actual.',
			'settingsPage.newPasswordMinLength' => 'La nueva contraseña debe tener al menos 8 caracteres.',
			'settingsPage.passwordUpdateFailed' => 'La actualización falló. Comprueba tu contraseña actual.',
			'settingsPage.sectionApplication' => 'Aplicación',
			'settingsPage.sectionPrivacy' => 'Privacidad',
			'settingsPage.customColor' => 'Color personalizado',
			'settingsPage.applyAction' => 'Aplicar',
			'settingsPage.useAccent' => ({required Object hex}) => 'Usar acento ${hex}',
			'settingsPage.proUpsellTitle' => 'Pasa a Evolve PRO',
			'settingsPage.proUpsellSubtitle' => 'Desbloquea todas las funciones y acelera tu crecimiento.',
			'settingsPage.proWelcomeTitle' => 'Bienvenido a Evolve PRO',
			'settingsPage.proActiveMessage' => 'Tu suscripción está activa. El AI Coach está incluido — sin cuenta de OpenRouter ni clave API — junto con las estadísticas avanzadas de tendencias y todas las herramientas de crecimiento personal de Evolve.',
			'settingsPage.proStartJourney' => 'Empieza tu recorrido',
			'settingsPage.systemSection' => 'Sistema',
			'settingsPage.appLogsTitle' => 'Registros de la app',
			'settingsPage.appLogsDetail' => 'Ver los registros de diagnóstico de esta sesión',
			'settingsPage.perMonth' => ({required Object price}) => '${price} al mes',
			'settingsPage.perMonthWithSavings' => ({required Object price, required Object percent}) => '${price} al mes · Ahorra un ${percent}%',
			'settingsPage.detailsHeader' => 'Detalles de la suscripción',
			'settingsPage.statusLabel' => 'Estado',
			'settingsPage.statusActive' => 'Activo',
			'settingsPage.planLabel' => 'Plan',
			'settingsPage.nextRenewal' => 'Próxima renovación',
			'settingsPage.expiresOn' => 'Caduca el',
			'settingsPage.paymentMethod' => 'Método de pago',
			'settingsPage.paymentMethodValue' => 'Apple Pay / App Store',
			'settingsPage.proActiveName' => 'Evolve PRO activo',
			'settingsPage.youArePro' => 'Eres usuario PRO',
			'settingsPage.proThankYou' => 'Gracias por apoyar el desarrollo de Evolve.',
			'consent.onboardingTitle' => 'Tu privacidad importa',
			'consent.continueButton' => 'Continuar',
			'notifications.actionDone' => 'Hecho',
			'notifications.actionSkip' => 'Omitir',
			'notifications.actionSnooze' => 'Posponer',
			'notifications.morningBrief' => 'Resumen matutino',
			'notifications.eveningReview' => 'Revisión nocturna',
			'notifications.morningBriefBody' => 'Es hora de estructurar tu día. Revisa tus objetivos.',
			'notifications.eveningReviewBody' => '¿Cómo fue el día? Registra tu progreso y actualiza el historial.',
			'privacy.biometricAuthReason' => 'Autentícate para activar la protección de la app.',
			'privacy.biometricUnlockReason' => 'Desbloquea la app para continuar.',
			'consentPage.subtitle' => 'Antes de usar Evolve Desktop, confirma los términos, la política de privacidad y el tratamiento de datos necesario para la sincronización.',
			'consentPage.acceptTerms' => 'Acepto los términos y la política de privacidad',
			'consentPage.termsSubtitle' => 'Confirmo que he leído los documentos y que tengo al menos 14 años.',
			'consentPage.crashDiagnostics' => 'Diagnóstico de fallos',
			'consentPage.crashSubtitle' => 'Permite el envío de informes técnicos anonimizados.',
			'consentPage.openPrivacy' => 'Abrir la política de privacidad',
			'consentPage.openTerms' => 'Términos del servicio',
			'consentPage.notificationsTitle' => 'Activar notificaciones',
			'consentPage.notificationsSubtitle' => 'Recibe recordatorios de hábitos y resúmenes diarios.',
			'consentPage.enableNotifications' => 'Activar',
			'consentPage.notificationsEnabled' => 'Activadas',
			'notif.macScheduling' => 'Programación diaria activa en macOS.',
			'notif.linuxImmediate' => 'Linux muestra notificaciones inmediatas, pero no admite la programación.',
			'notif.openEvolve' => 'Abrir Evolve',
			'notif.windowsScheduling' => 'Windows programa la próxima aparición en cada inicio.',
			'notif.morningBody' => 'Revisa los hábitos de hoy y elige por dónde empezar.',
			'notif.habitReminderBody' => 'Es hora de completar tu hábito.',
			'notif.limitReminderBody' => '¿Te mantienes dentro de tu límite hoy? Revísalo cuando puedas.',
			'notif.eveningBody' => 'Cierra el día y actualiza tu progreso.',
			'biometricGate.appLocked' => 'App bloqueada',
			'biometricGate.unlockPrompt' => 'Desbloquea con la autenticación local para continuar.',
			'biometricGate.verifying' => 'Verificando...',
			'biometricGate.unlock' => 'Desbloquear',
			'biometricGate.notSupportedLinux' => 'El bloqueo biométrico no es compatible con Linux.',
			'biometricGate.noLocalAuth' => 'No hay ningún método de autenticación local disponible.',
			'biometricGate.authFailed' => 'Error de autenticación.',
			'biometricGate.authUnavailable' => 'Autenticación local no disponible.',
			'sync.syncFailed' => 'Sincronización fallida. Datos locales conservados.',
			'sync.editSavedLocally' => 'Cambio guardado localmente. Se reintentará la sincronización.',
			'subscriptionCtrl.purchaseComplete' => 'Compra completada: sincronizando la suscripción.',
			'subscriptionCtrl.purchaseIncomplete' => 'Compra no completada.',
			'subscriptionCtrl.cantOpenApple' => 'No se pudo abrir la gestión de suscripciones de Apple.',
			'subscriptionCtrl.macOnly' => 'Las compras dentro de la app están disponibles en el cliente de macOS.',
			'subscriptionCtrl.loadOffersFailed' => 'No se pudieron cargar los planes de suscripción. Comprueba tu conexión e inténtalo de nuevo.',
			'subscriptionCtrl.proActivated' => 'Evolve Pro activado.',
			'subscriptionCtrl.purchasesRestored' => 'Compras restauradas.',
			'subscriptionCtrl.noActiveSub' => 'No se encontró ninguna suscripción Pro activa.',
			'subscriptionCtrl.restoreFailed' => 'No se pudieron restaurar las compras.',
			'subscriptionCtrl.configKey' => 'Las compras dentro de la app no están disponibles temporalmente.',
			'subscriptionCtrl.loginFirst' => 'Inicia sesión antes de gestionar Evolve Pro.',
			'subscriptionCtrl.paidAppsAgreement' => 'El acuerdo de aplicaciones pagas no está activo. El titular de la cuenta debe aceptar el acuerdo de aplicaciones pagas en App Store Connect.',
			'subscriptionCtrl.alreadyPurchased' => 'Esta suscripción ya está comprada. Utilice Restaurar compras para reactivar el acceso Pro.',
			'subscriptionCtrl.purchasesNotAllowed' => 'No se permiten compras dentro de la aplicación en este dispositivo ni en la cuenta de Apple.',
			'subscriptionCtrl.planUnavailable' => 'El plan seleccionado no está disponible para su compra. Vuelve a intentarlo más tarde.',
			'subscriptionCtrl.paymentPending' => 'El pago está pendiente. El acceso Pro se activará cuando Apple confirme la transacción.',
			'subscriptionCtrl.connectionUnavailable' => 'Conexión no disponible. Verifique su red e inténtelo nuevamente.',
			'subscriptionCtrl.linkedToAnotherAccount' => 'Esta compra ya está vinculada a otra cuenta de Evolve. Inicie sesión con esa cuenta o comuníquese con el soporte.',
			'subscriptionCtrl.purchaseInProgress' => 'Ya hay una operación de compra en curso. Espere unos segundos.',
			'subscriptionCtrl.restoreInProgress' => 'Ya hay una restauración en curso. Espere unos segundos.',
			'subscriptionCtrl.purchaseFailedMessage' => 'No se pudo completar la compra. Vuelve a intentarlo en breve.',
			'subscriptionCtrl.restoreFailedMessage' => 'No se pudieron restaurar las compras. Vuelve a intentarlo en breve.',
			'subscriptionCtrl.purchaseRegisteredNotActive' => 'Compra registrada, pero la suscripción Pro aún no está activa. Espere unos segundos y use Restaurar compras.',
			'subscriptionCtrl.noActiveSubscription' => 'No se encontró ninguna suscripción activa a Evolve PRO en este Apple ID. Asegúrate de usar el mismo Apple ID de la compra.',
			'subscriptionCtrl.invalidConfig' => 'Configuración de compras no válida. Inténtalo de nuevo más tarde o contacta con soporte.',
			'authCtrl.appleNoToken' => 'Apple no devolvió un token de identidad.',
			'authCtrl.appleAuthFailed' => 'Error de autenticación de Apple.',
			'authCtrl.cantOpenBrowser' => 'No se pudo abrir el navegador del sistema.',
			'authCtrl.accessNotCompleted' => ({required Object provider}) => 'Inicio de sesión con ${provider} no completado.',
			'authCtrl.providerAuthFailed' => ({required Object provider}) => 'Error de autenticación de ${provider}.',
			'authCtrl.operationFailed' => 'Operación fallida. Inténtalo de nuevo en breve.',
			'proModal.title' => 'Desbloquea Evolve PRO',
			'proModal.subtitle' => 'Lleva tu sistema de hábitos al siguiente nivel',
			'proModal.featuresHeader' => 'Qué incluye el plan PRO',
			_ => null,
		} ?? switch (path) {
			'proModal.aiCoachTitle' => 'AI Coach, sin configuración',
			'proModal.aiCoachDesc' => 'Lo ejecutamos nosotros con nuestra clave: sin clave API que buscar, sin segunda cuenta. ¿Prefieres tu propia cuenta de OpenRouter? También es gratis.',
			'proModal.statsTitle' => 'Estadísticas específicas por hábito',
			'proModal.statsDesc' => 'Información clave para aumentar su productividad.',
			'proModal.metricsTitle' => 'Métricas avanzadas de objetivos',
			'proModal.metricsDesc' => 'Vea gráficos detallados y estadísticas detalladas de rendimiento para cada año.',
			'proModal.unlimitedTitle' => 'Hábitos ilimitados',
			'proModal.unlimitedDesc' => 'Crea y rastrea todos los hábitos que quieras sin límites.',
			'proModal.maybeLater' => 'Quizá más tarde',
			'proModal.viewPlans' => 'Ver planes Pro',
			'appLogs.title' => 'Registros de la App',
			'appLogs.copiedToClipboard' => 'Registros copiados al portapapeles',
			'appLogs.clearLogsTitle' => 'Borrar Registros',
			'appLogs.clearLogsConfirm' => '¿Estás seguro de que deseas borrar todas las entradas del registro? Esta acción no se puede deshacer.',
			'appLogs.clearLogsAction' => 'Borrar Todo',
			'appLogs.copyAll' => 'Copiar Todos los Registros',
			'appLogs.searchPlaceholder' => 'Buscar en registros...',
			'appLogs.filterAll' => 'Todo',
			'appLogs.filterErrors' => 'Errores',
			'appLogs.filterWarnings' => 'Advertencias',
			'appLogs.filterInfo' => 'Info',
			'appLogs.emptyTitle' => 'Sin Registros',
			'appLogs.emptySubtitle' => 'Los registros aparecerán aquí mientras la app se ejecuta',
			'appLogs.stackTraceAvailable' => 'Toca para ver el stack trace',
			'appLogs.detailMessage' => 'MENSAJE',
			'appLogs.detailError' => 'ERROR',
			'appLogs.detailExtras' => 'Contexto adicional',
			'appLogs.detailStackTrace' => 'STACK TRACE',
			'appLogs.shareLogs' => 'Compartir archivo de registros',
			'appLogs.exportDone' => 'Registros exportados',
			'coachSettings.title' => 'Motor del Coach de IA',
			'coachSettings.subtitle' => 'Elige dónde se ejecuta el coach. Los modelos locales mantienen cada mensaje en este dispositivo.',
			'coachSettings.backendCloud' => 'Tu OpenRouter',
			'coachSettings.backendLocal' => 'Local · privado',
			'coachSettings.cloudDesc' => 'Conecta tu propia cuenta de OpenRouter y paga directamente al proveedor. Gratis: no necesitas suscripción. El contexto que compartes se envía al proveedor.',
			'coachSettings.localDesc' => 'Tu propio modelo vía Ollama, LM Studio o cualquier servidor compatible con OpenAI. Nada sale de este dispositivo.',
			'coachSettings.presetLabel' => 'Servidor',
			'coachSettings.presetOllama' => 'Ollama',
			'coachSettings.presetLmStudio' => 'LM Studio',
			'coachSettings.presetCustom' => 'Personalizado…',
			'coachSettings.baseUrlLabel' => 'URL base',
			'coachSettings.modelLabel' => 'Modelo',
			'coachSettings.refreshModels' => 'Actualizar modelos',
			'coachSettings.discovering' => 'Buscando modelos…',
			'coachSettings.noModelsFound' => 'No se encontraron modelos — escribe un id de modelo manualmente abajo.',
			'coachSettings.manualModelLabel' => 'Id del modelo',
			'coachSettings.manualModelAdd' => 'Usar este modelo',
			'coachSettings.statusConnected' => 'Conectado',
			'coachSettings.statusOffline' => 'Servidor sin conexión',
			'coachSettings.statusChecking' => 'Comprobando…',
			'coachSettings.remoteBadge' => 'Remoto',
			'coachSettings.remoteWarning' => 'Este endpoint no es una dirección local — los mensajes saldrán de este dispositivo.',
			'coachSettings.advanced' => 'Avanzado',
			'coachSettings.systemPromptLabel' => 'Prompt del sistema',
			'coachSettings.systemPromptHint' => 'Reemplaza la persona del coach (déjalo vacío para la predeterminada)',
			'coachSettings.systemPromptReset' => 'Restablecer',
			'coachSettings.temperatureLabel' => 'Temperatura',
			'coachSettings.save' => 'Listo',
			'coachSettings.detectedTitle' => ({required Object app}) => '${app} detectado',
			'coachSettings.detectedBody' => ({required Object app}) => '${app} se está ejecutando en este Mac. ¿Ejecutar el coach de forma 100 % privada?',
			'coachSettings.detectedAction' => 'Usar local',
			'coachSettings.detectedDismiss' => 'Ahora no',
			'coachSettings.activeCloud' => ({required Object model}) => 'Nube · ${model}',
			'coachSettings.activeLocal' => ({required Object model}) => 'Local · ${model}',
			'coachSettings.activeLocalNoModel' => 'Local · elige un modelo',
			'coachSettings.cloudSection' => 'Tu OpenRouter',
			'coachSettings.serverSettings' => 'Ajustes del servidor…',
			'coachSettings.settingsSectionLabel' => 'Coach de IA',
			'coachSettings.settingsTitle' => 'Coach de IA',
			'coachSettings.settingsSubtitle' => 'Elige el motor que impulsa tu coach y conéctalo a un servidor local para máxima privacidad.',
			'coachSettings.settingsRowStatus' => 'Motor activo',
			'coachSettings.settingsRowConfigure' => 'Motor y servidor local',
			'coachSettings.cloudKeyMissing' => 'Aún no hay clave: este motor no responderá. Conecta abajo tu cuenta de OpenRouter, cambia a Evolve AI o usa un servidor local.',
			'coachSettings.temperatureLower' => 'Bajar la temperatura',
			'coachSettings.temperatureRaise' => 'Subir la temperatura',
			'coachSettings.sendMessage' => 'Enviar',
			'coachSettings.stopResponse' => 'Detener',
			'coachSettings.startLocalServer' => ({required Object app}) => 'Iniciar ${app}',
			'coachSettings.getLocalServer' => ({required Object app}) => 'Obtener ${app}',
			'coachSettings.startingLocalServer' => ({required Object app}) => 'Iniciando ${app}…',
			'coachSettings.localServerOfflineTitle' => ({required Object app}) => '${app} no está en ejecución',
			'coachSettings.localServerOfflineBody' => 'Inicia tu servidor local para chatear en privado — sin terminal.',
			'coachSettings.localServerNotInstalledTitle' => ({required Object app}) => '${app} no está instalado',
			'coachSettings.localServerNotInstalledBody' => ({required Object app}) => 'Instala la app gratuita de ${app} y luego pulsa Iniciar.',
			'coachSettings.localServerStartingBody' => 'Esto puede tardar unos segundos…',
			'coachSettings.localServerStartFailed' => ({required Object app}) => 'No se pudo iniciar ${app} — prueba a abrirlo desde la carpeta Aplicaciones.',
			'coachSettings.localServerDownloadFailed' => ({required Object url}) => 'No se pudo abrir el navegador — visita ${url}',
			'coachSettings.ollamaStartTimeout' => 'Está tardando más de lo esperado — revisa el icono de Ollama en la barra de menús (el primer inicio puede requerir aprobación).',
			'coachSettings.ollamaServerOffTitle' => 'Ollama está en ejecución pero no atiende peticiones',
			'coachSettings.ollamaServerOffBody' => 'Ollama está abierto, pero no responde en su puerto. Ciérralo desde la barra de menús y luego pulsa Iniciar de nuevo.',
			'coachSettings.lmStudioStartTimeout' => 'Está tardando más de lo esperado — abre LM Studio y comprueba que haya terminado de iniciarse.',
			'coachSettings.lmStudioServerOffTitle' => 'El servidor de LM Studio no está en ejecución',
			'coachSettings.lmStudioServerOffBody' => 'LM Studio está abierto, pero su servidor local está apagado. Actívalo con Developer → Start Server, o marca Settings → Run the LLM server on login.',
			'coachSettings.lmStudioNoModelsJit' => 'LM Studio no está mostrando ningún modelo. Solo muestra los modelos cargados cuando la carga Just-In-Time está desactivada — carga un modelo en LM Studio o activa Developer → Server Settings → Just In Time Model Loading.',
			'coachSettings.backendStandard' => 'Evolve AI',
			'coachSettings.standardDesc' => 'Incluido en Evolve Pro. Ejecutamos por ti un modelo gratuito de Google (Gemma): sin claves, sin configuración. Tus mensajes van al plan gratuito de Google, que puede usarlos para mejorar sus servicios.',
			'coachSettings.activeStandard' => ({required Object model}) => 'Evolve AI · ${model}',
			'coachSettings.standardSection' => 'Evolve AI',
			'coachSettings.standardStatusReady' => 'Incluido en Pro',
			'coachSettings.standardStatusNeedsPro' => 'Requiere Pro',
			'coachSettings.standardStatusNeedsSignIn' => 'Inicia sesión',
			'coachSettings.standardStatusUnavailable' => 'No disponible',
			'coachSettings.standardNeedsProNote' => 'Evolve AI forma parte de Evolve Pro. Suscríbete para desbloquearlo.',
			'coachSettings.standardNeedsSignInNote' => 'Inicia sesión para usar Evolve AI. Tu suscripción lo desbloquea en todos tus dispositivos.',
			'coachSettings.standardUnavailableNote' => 'Evolve AI no está disponible en esta versión. Conecta tu cuenta de OpenRouter o usa un modelo local.',
			'coachSettings.standardPrivateNote' => 'Evolve AI necesita una cuenta de Evolve, y el modo Privado no guarda ninguna. Conecta tu cuenta de OpenRouter o usa un modelo local: aquí ambos siguen funcionando.',
			'coachSettings.accountModeNote' => '¿Prefieres tu propia clave de OpenRouter o un modelo local? Están disponibles en el modo Privado.',
			'coachSettings.localGroupLabel' => 'Local — en este Mac',
			'coachSettings.useCustomServer' => 'Usar un servidor personalizado…',
			'coachSettings.cardLive' => 'Activo',
			'coachSettings.cardOff' => 'Apagado',
			'coachSettings.engineOpenRouter' => 'OpenRouter',
			'coachSettings.engineOpenRouterHint' => 'Tu propia clave · gratis',
			'tour.back' => 'Atrás',
			'tour.next' => 'Siguiente',
			'tour.continueLabel' => 'Continuar',
			'tour.finish' => 'Finalizar',
			'tour.welcomeTitle' => 'Bienvenido a Evolve',
			'tour.welcomeBody' => 'Hagamos un recorrido rápido por tu espacio — desde tu resumen diario hasta tu coach de IA. Solo toma un momento.',
			'tour.welcomeStart' => 'Iniciar recorrido',
			'tour.welcomeSkip' => 'Omitir tutorial',
			'tour.doneTitle' => 'Todo listo',
			'tour.doneBody' => 'Esta es toda la app. Empieza donde quieras desde la barra lateral — y puedes repetir el recorrido cuando quieras desde Ajustes.',
			'tour.doneButton' => 'Empezar',
			'tour.overviewOrientationTitle' => 'Tu Resumen',
			'tour.overviewOrientationDesc' => 'Es tu base diaria — una vista de hoy en cuanto abres Evolve.',
			'tour.overviewCheckinTitle' => 'Registro diario',
			'tour.overviewCheckinDesc' => 'Anota cómo va tu día. Con el tiempo revela cómo tu estado de ánimo se relaciona con tus hábitos y metas.',
			'tour.overviewHabitsTitle' => 'Hábitos de hoy',
			'tour.overviewHabitsDesc' => 'Los hábitos que planificaste para hoy están aquí — márcalos a medida que avanzas.',
			'tour.overviewGoalsTitle' => 'Metas en foco',
			'tour.overviewGoalsDesc' => 'Las metas en las que te concentras aparecen aquí para que nada se te escape.',
			'tour.habitsOrientationTitle' => 'La página de Hábitos',
			'tour.habitsOrientationDesc' => 'Aquí construyes tu protocolo diario y controlas tu constancia.',
			'tour.habitsAddTitle' => 'Añadir un hábito',
			'tour.habitsAddDesc' => 'Crea un nuevo hábito aquí — dale nombre, categoría, color y un recordatorio opcional.',
			'tour.habitsCheckoffTitle' => 'Márcalo como hecho',
			'tour.habitsCheckoffDesc' => 'Marca esta casilla para completar un hábito hoy. Con eso basta para mantener viva una racha.',
			'tour.habitsStreakTitle' => 'Rachas e historial',
			'tour.habitsStreakDesc' => 'Observa crecer tu racha y ve tus últimos siete días de un vistazo.',
			'tour.habitsCalendarTitle' => 'Vista de calendario',
			'tour.habitsCalendarDesc' => 'Cambia al Calendario para revisar tu historial por semana, mes, año — o toda tu vida.',
			'tour.insightsOrientationTitle' => 'Tus Estadísticas',
			'tour.insightsOrientationDesc' => 'Observa la evolución de tus hábitos y metas en el tiempo y dónde te desvías.',
			'tour.insightsFilterTitle' => 'Filtrar por hábito',
			'tour.insightsFilterDesc' => 'Enfoca las estadísticas en un solo hábito o mantén la vista global.',
			'tour.insightsTabsTitle' => 'Secciones de estadísticas',
			'tour.insightsTabsDesc' => 'Cambia entre las secciones para tendencias, alertas, progreso de hábitos y tu ánimo.',
			'tour.goalsOrientationTitle' => 'La página de Metas',
			'tour.goalsOrientationDesc' => 'Define y controla tus objetivos más grandes — aquello hacia lo que construyen tus hábitos diarios.',
			'tour.goalsPlanTitle' => 'Tipo de planificación',
			'tour.goalsPlanDesc' => 'Elige cómo planificas — diaria, semanal o más larga — según cómo pienses tus metas.',
			'tour.goalsAddTitle' => 'Añadir una meta',
			'tour.goalsAddDesc' => 'Crea aquí una nueva meta y dale un objetivo por alcanzar.',
			'tour.goalsCheckTitle' => 'Completar o fallar',
			'tour.goalsCheckDesc' => 'Marca una meta como cumplida o fallada. Cada resultado alimenta tu rendimiento con el tiempo.',
			'tour.goalsStatsTitle' => 'Rendimiento',
			'tour.goalsStatsDesc' => 'Activa las estadísticas de rendimiento para ver cómo vas con tus metas.',
			'tour.coachOrientationTitle' => 'Tu Coach de IA',
			'tour.coachOrientationDesc' => 'Orientación personalizada basada en tus hábitos y metas reales — aquí en tu Mac.',
			'tour.coachModelTitle' => 'Elige el motor',
			'tour.coachModelDesc' => 'Elige el modelo de IA — nuestra nube o un modelo local que se ejecuta de forma privada en tu Mac. Los ajustes del servidor también están aquí.',
			'tour.coachContextTitle' => 'Lo que ve el coach',
			'tour.coachContextDesc' => 'Controla si el coach puede usar tus hábitos y metas para adaptar sus consejos.',
			'tour.coachSuggestionsTitle' => 'Sugerencias iniciales',
			'tour.coachSuggestionsDesc' => '¿No sabes por dónde empezar? Toca una de estas sugerencias para arrancar.',
			'tour.coachInputTitle' => 'Pregunta lo que sea',
			'tour.coachInputDesc' => 'Escribe aquí tu pregunta y pulsa enviar. Aquí termina el recorrido — ¡disfruta Evolve!',
			'palette.searchHint' => 'Busca objetivos, hábitos, acciones…',
			'palette.groupSuggested' => 'Sugeridos',
			'palette.groupThisWeek' => 'Esta semana',
			'palette.groupGoals' => 'Objetivos',
			'palette.groupHabits' => 'Hábitos',
			'palette.groupActions' => 'Acciones',
			'palette.groupSections' => 'Ir a',
			'palette.goToThisWeek' => 'Ir a esta semana',
			'palette.createGoalBlank' => 'Crear objetivo',
			'palette.createGoal' => ({required Object title}) => 'Crear objetivo «${title}»',
			'palette.createHabit' => ({required Object title}) => 'Crear hábito «${title}»',
			'palette.goToPeriod' => ({required Object period}) => 'Ir a ${period}',
			'palette.switchToDark' => 'Cambiar a tema oscuro',
			'palette.switchToLight' => 'Cambiar a tema claro',
			'palette.manageCategories' => 'Gestionar categorías de objetivos',
			'palette.replayTour' => 'Repetir el tour guiado',
			'palette.noResults' => ({required Object query}) => 'Sin resultados para «${query}»',
			'palette.rowOpen' => 'Abrir',
			'palette.rowComplete' => 'Marcar como completado',
			'palette.rowReschedule' => 'Reprogramar al siguiente periodo',
			'palette.deleteGoalTitle' => '¿Eliminar objetivo?',
			'palette.deleteGoalMessage' => ({required Object title}) => '«${title}» se eliminará permanentemente.',
			'palette.deleteHabitTitle' => '¿Eliminar hábito?',
			'palette.deleteHabitMessage' => ({required Object title}) => '«${title}» se eliminará permanentemente.',
			'palette.footerNavigate' => 'navegar',
			'palette.footerOpen' => 'abrir',
			'palette.footerMenu' => 'menú',
			'palette.footerClose' => 'cerrar',
			'targets.sectionTitle' => 'Objetivo',
			'targets.none' => 'Simple',
			'targets.atLeastLabel' => 'Alcanza',
			'targets.atMostLabel' => 'Mantente bajo',
			'targets.presets.countDaily.label' => 'Recuento',
			'targets.presets.countDaily.description' => 'Hazlo un número determinado de veces al día.',
			'targets.presets.durationDaily.label' => 'Duración',
			'targets.presets.durationDaily.description' => 'Dedica un número determinado de minutos al día.',
			'targets.presets.limitCountDaily.label' => 'Límite',
			'targets.presets.limitCountDaily.description' => 'Mantente por debajo de un número cada día.',
			'targets.presets.limitDurationDaily.label' => 'Límite de tiempo',
			'targets.presets.limitDurationDaily.description' => 'Mantente bajo un número de minutos al día.',
			'targets.units.min' => 'min',
			'targets.units.hour' => 'h',
			'targets.units.kcal' => 'kcal',
			'targets.units.km' => 'km',
			'targets.entry.keepGoing' => 'Sigue así',
			'targets.entry.withinLimit' => 'Dentro de tu límite',
			'targets.entry.overLimit' => 'Por encima de tu límite',
			_ => null,
		};
	}
}
