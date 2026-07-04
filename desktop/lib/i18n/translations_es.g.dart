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
	@override late final _Translations$auth$es auth = _Translations$auth$es._(_root);
	@override late final _Translations$privateAi$es privateAi = _Translations$privateAi$es._(_root);
	@override late final _Translations$privateData$es privateData = _Translations$privateData$es._(_root);
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

// Path: privateAi
class _Translations$privateAi$es extends Translations$privateAi$en {
	_Translations$privateAi$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get consentTitle => 'Permitir el envío a la IA';
	@override String get consentBody => 'En el modo privado tus datos permanecen en tu dispositivo. Para usar el Coach de IA, los hábitos y objetivos que elijas compartir se envían a un proveedor de IA externo (OpenRouter). ¿Quieres continuar?';
	@override String get cancel => 'Cancelar';
	@override String get accept => 'Acepto';
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
}

// Path: createHabit
class _Translations$createHabit$es extends Translations$createHabit$en {
	_Translations$createHabit$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Nuevo hábito';
	@override String get subtitle => 'Define tu nuevo hábito.';
	@override String get titleHint => 'p. ej. Meditación';
	@override String get categoryHint => 'p. ej. Bienestar';
	@override String get weeklyFrequency => 'Frecuencia semanal';
	@override String get defaultCategory => 'General';
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
	@override String statusDone({required Object category}) => '${category} · Completada';
	@override String statusSkipped({required Object category}) => '${category} · Omitida';
	@override String statusUnrecorded({required Object category}) => '${category} · No registrada';
	@override String weekOf({required Object day, required Object month}) => 'Semana del ${day} ${month}';
	@override String get lifeWeeks => 'Semanas de tu camino';
	@override String get catWellness => 'Bienestar';
	@override String get catProductivity => 'Productividad';
	@override String get catEducation => 'Formación';
	@override String get catHealth => 'Salud';
	@override String get catMindfulness => 'Mindfulness';
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
	@override String get tutPlanningTitle => 'Tipo de planificación';
	@override String get tutPlanningDesc => 'Aquí puedes seleccionar el horizonte temporal de tus objetivos.';
	@override String get tutNewGoalDesc => 'Desde aquí puedes añadir rápidamente un nuevo objetivo.';
	@override String get tutCompleteTitle => 'Completa o falla';
	@override String get tutCompleteDesc => 'Marca el objetivo como completado o fallido con un solo clic.';
	@override String get tutCategoryDesc => 'Gestiona las categorías y asócialas a tus objetivos.';
	@override String get tutRescheduleTitle => 'Reprogramar';
	@override String get tutRescheduleDesc => 'Mueve el objetivo al siguiente período si no pudiste completarlo.';
	@override String get tutEditDesc => 'Edita los detalles de tu objetivo.';
	@override String get tutDeleteDesc => 'Elimina un objetivo si ya no es relevante.';
	@override String get tutStatsTitle => 'Análisis y estadísticas';
	@override String get tutStatsDesc => 'Cambia a la vista de estadísticas para analizar tu rendimiento a lo largo del tiempo.';
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
	@override String get darkMode => 'Modo oscuro';
	@override String get darkModeDetail => 'Usa el tema oscuro en blanco y negro.';
	@override String get calendarExperienceLanguage => 'Calendario, experiencia e idioma';
	@override String get accentColor => 'Color de acento';
	@override String get accentColorDetail => 'Paleta ampliada reservada para Evolve Pro.';
	@override String get defaultCalendarView => 'Vista de calendario predeterminada';
	@override String get timeFormat24hDetail => 'Usa horas como 20:30 en lugar de 8:30 PM.';
	@override String get hapticFeedback => 'Respuesta háptica';
	@override String get hapticFeedbackDetail => 'El escritorio conserva la preferencia pero no genera vibraciones.';
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
	@override String get importDataDetail => 'Restaura una copia de seguridad (formato .zip) de Evolve.';
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
	@override String get importReplaceSubtitle => 'Elimina todos los datos locales existentes antes de importar. (Recomendado)';
	@override String get importMergeTitle => 'Combinar con los datos actuales';
	@override String get importMergeSubtitle => 'Añade los datos importados sin eliminar nada. Puede causar duplicados.';
	@override String get importConfirmButton => 'Confirmar importación';
	@override String get importSuccess => '¡Importación completada correctamente!';
	@override String importError({required Object error}) => 'Error durante la importación: ${error}';
	@override String get proTitle => 'Evolve Pro';
	@override String get proSubtitle => 'Plan, restauración de compras y gestión de suscripción';
	@override String get revenueCatMacos => 'RevenueCat macOS';
	@override String get commercialChannelRequired => 'Se requiere un canal comercial';
	@override String get revenueCatOffersRead => 'Las ofertas y el estado de los derechos se leen desde RevenueCat.';
	@override String get revenueCatConfigureKey => 'Configura la clave pública de RevenueCat del cliente de escritorio.';
	@override String get revenueCatNotSupported => 'RevenueCat Flutter no admite compras dentro de la aplicación en Windows y Linux.';
	@override String get bestValue => 'Mejor valor';
	@override String get planManagement => 'Gestión del plan';
	@override String get activateEvolvePro => 'Activar Evolve Pro';
	@override String get activateEvolveProActive => 'Derecho de Evolve Pro activo.';
	@override String get activateEvolveProStart => 'Inicia el proceso de pago nativo de StoreKit en macOS.';
	@override String get restorePurchasesDetail => 'Recupera el estado de los derechos desde el proveedor.';
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
	@override String get proActiveMessage => 'Tu suscripción está activa. Ahora tiene acceso completo e ilimitado al Entrenador de IA personalizado, estadísticas de tendencias avanzadas y todas las herramientas de crecimiento personal de Evolve.';
	@override String get proStartJourney => 'Empieza tu recorrido';
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
	@override String get loadOffersFailed => 'No se pudieron cargar las ofertas de RevenueCat.';
	@override String get proActivated => 'Evolve Pro activado.';
	@override String get purchasesRestored => 'Compras restauradas.';
	@override String get noActiveSub => 'No se encontró ninguna suscripción Pro activa.';
	@override String get restoreFailed => 'No se pudieron restaurar las compras.';
	@override String get configKey => 'Configura la clave pública de RevenueCat del cliente de escritorio.';
	@override String get loginFirst => 'Inicia sesión antes de gestionar Evolve Pro.';
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
	@override String get aiCoachTitle => 'Coach AI personalizado';
	@override String get aiCoachDesc => 'Análisis de tendencias avanzado y sugerencias inteligentes generadas por IA.';
	@override String get statsTitle => 'Estadísticas específicas por hábito';
	@override String get statsDesc => 'Información clave para aumentar su productividad.';
	@override String get metricsTitle => 'Métricas avanzadas de objetivos';
	@override String get metricsDesc => 'Vea gráficos detallados y estadísticas detalladas de rendimiento para cada año.';
	@override String get unlimitedTitle => 'Hábitos ilimitados';
	@override String get unlimitedDesc => 'Crea y rastrea todos los hábitos que quieras sin límites.';
	@override String get maybeLater => 'Quizá más tarde';
	@override String get viewPlans => 'Ver planes Pro';
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
	@override String get apiKeyMissingFull => '⚠️ Error: la clave API de OpenRouter no está configurada.\n\nAñade tu clave API en `lib/core/openrouter_config.dart`.';
	@override String get apiKeyMissingShort => '⚠️ Error: la clave API de OpenRouter no está configurada.';
	@override String get defaultSystemPrompt => 'Eres el "Coach de Disciplina", un asistente virtual centrado en ayudar al usuario a mantener la disciplina, alcanzar objetivos y construir hábitos saludables. Sé motivador pero concreto, directo y práctico. Usa un tono profesional pero cercano.';
	@override String communicationError({required Object code}) => '❌ Error al comunicarse con la IA. (Código: ${code})';
	@override String get connectionError => '❌ Error de conexión. Asegúrate de estar online e inténtalo de nuevo.';
	@override String get connectionErrorShort => '❌ Error de conexión.';
	@override String get connectionCheckTimeout => '❌ Error: la comprobación de conexión tardó demasiado.';
	@override String get contextTooLong => '⚠️ Límite de memoria superado o solicitud no válida. La conversación puede ser demasiado larga o compleja. Usa el icono de papelera arriba para borrar el chat y empezar de nuevo.';
	@override String get noInternet => '❌ Error: no hay conexión a internet. Revisa tu red.';
	@override String get serverTimeout => '❌ Error: el servidor tarda demasiado en responder. Inténtalo de nuevo.';
	@override String apiError({required Object code}) => '❌ Error de API: ${code} (consulta Sentry para más detalles)';
}

/// The flat map containing all translations for locale <es>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEs {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
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
			'privateAi.consentTitle' => 'Permitir el envío a la IA',
			'privateAi.consentBody' => 'En el modo privado tus datos permanecen en tu dispositivo. Para usar el Coach de IA, los hábitos y objetivos que elijas compartir se envían a un proveedor de IA externo (OpenRouter). ¿Quieres continuar?',
			'privateAi.cancel' => 'Cancelar',
			'privateAi.accept' => 'Acepto',
			'privateData.deleteTitle' => 'Eliminar datos privados',
			'privateData.deleteMessage' => '¿Seguro que quieres eliminar toda la base de datos local cifrada? Esta acción es irreversible y los datos no se podrán recuperar.',
			'privateData.deleteSuccess' => 'Datos privados eliminados.',
			'privateData.deleteFailed' => 'La operación ha fallado.',
			'privateData.exportDoneTitle' => 'Exportación completada',
			'privateData.exportDoneClipboard' => 'El JSON está en el portapapeles: Linux no admite compartir archivos.',
			'privateData.exportDoneShare' => 'El JSON se envió al selector de uso compartido.',
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
			'createHabit.title' => 'Nuevo hábito',
			'createHabit.subtitle' => 'Define tu nuevo hábito.',
			'createHabit.titleHint' => 'p. ej. Meditación',
			'createHabit.categoryHint' => 'p. ej. Bienestar',
			'createHabit.weeklyFrequency' => 'Frecuencia semanal',
			'createHabit.defaultCategory' => 'General',
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
			'habitsPage.statusDone' => ({required Object category}) => '${category} · Completada',
			'habitsPage.statusSkipped' => ({required Object category}) => '${category} · Omitida',
			'habitsPage.statusUnrecorded' => ({required Object category}) => '${category} · No registrada',
			'habitsPage.weekOf' => ({required Object day, required Object month}) => 'Semana del ${day} ${month}',
			'habitsPage.lifeWeeks' => 'Semanas de tu camino',
			'habitsPage.catWellness' => 'Bienestar',
			'habitsPage.catProductivity' => 'Productividad',
			'habitsPage.catEducation' => 'Formación',
			'habitsPage.catHealth' => 'Salud',
			'habitsPage.catMindfulness' => 'Mindfulness',
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
			'goalsPage.tutPlanningTitle' => 'Tipo de planificación',
			'goalsPage.tutPlanningDesc' => 'Aquí puedes seleccionar el horizonte temporal de tus objetivos.',
			'goalsPage.tutNewGoalDesc' => 'Desde aquí puedes añadir rápidamente un nuevo objetivo.',
			'goalsPage.tutCompleteTitle' => 'Completa o falla',
			'goalsPage.tutCompleteDesc' => 'Marca el objetivo como completado o fallido con un solo clic.',
			'goalsPage.tutCategoryDesc' => 'Gestiona las categorías y asócialas a tus objetivos.',
			'goalsPage.tutRescheduleTitle' => 'Reprogramar',
			'goalsPage.tutRescheduleDesc' => 'Mueve el objetivo al siguiente período si no pudiste completarlo.',
			'goalsPage.tutEditDesc' => 'Edita los detalles de tu objetivo.',
			'goalsPage.tutDeleteDesc' => 'Elimina un objetivo si ya no es relevante.',
			'goalsPage.tutStatsTitle' => 'Análisis y estadísticas',
			'goalsPage.tutStatsDesc' => 'Cambia a la vista de estadísticas para analizar tu rendimiento a lo largo del tiempo.',
			'goalsStats.proRequired' => 'Función Pro requerida',
			'goalsStats.active' => 'Activos',
			'goalsStats.failed' => 'Fallidos',
			'goalsStats.complAbbr' => 'Compl.',
			'goalsStats.seasonality' => 'Estacionalidad',
			'goalsStats.interestEvolution' => 'Evolución de intereses',
			'ai.coach' => 'Coach AI',
			'ai.dailyHabits' => 'Hábitos diarios',
			'ai.macroGoals' => 'Macroobjetivos',
			'ai.openRouter.apiKeyMissingFull' => '⚠️ Error: la clave API de OpenRouter no está configurada.\n\nAñade tu clave API en `lib/core/openrouter_config.dart`.',
			'ai.openRouter.apiKeyMissingShort' => '⚠️ Error: la clave API de OpenRouter no está configurada.',
			'ai.openRouter.defaultSystemPrompt' => 'Eres el "Coach de Disciplina", un asistente virtual centrado en ayudar al usuario a mantener la disciplina, alcanzar objetivos y construir hábitos saludables. Sé motivador pero concreto, directo y práctico. Usa un tono profesional pero cercano.',
			'ai.openRouter.communicationError' => ({required Object code}) => '❌ Error al comunicarse con la IA. (Código: ${code})',
			'ai.openRouter.connectionError' => '❌ Error de conexión. Asegúrate de estar online e inténtalo de nuevo.',
			'ai.openRouter.connectionErrorShort' => '❌ Error de conexión.',
			'ai.openRouter.connectionCheckTimeout' => '❌ Error: la comprobación de conexión tardó demasiado.',
			'ai.openRouter.contextTooLong' => '⚠️ Límite de memoria superado o solicitud no válida. La conversación puede ser demasiado larga o compleja. Usa el icono de papelera arriba para borrar el chat y empezar de nuevo.',
			'ai.openRouter.noInternet' => '❌ Error: no hay conexión a internet. Revisa tu red.',
			'ai.openRouter.serverTimeout' => '❌ Error: el servidor tarda demasiado en responder. Inténtalo de nuevo.',
			'ai.openRouter.apiError' => ({required Object code}) => '❌ Error de API: ${code} (consulta Sentry para más detalles)',
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
			_ => null,
		} ?? switch (path) {
			'settingsPage.goToLogin' => 'Ir al inicio de sesión',
			'settingsPage.goToLoginDetail' => 'Suspende el modo privado e inicia sesión en Supabase.',
			'settingsPage.appearanceTitle' => 'Apariencia y aplicación',
			'settingsPage.appearanceSubtitle' => 'Preferencias locales adaptadas al escritorio',
			'settingsPage.appearanceAndVisual' => 'Apariencia y aspecto visual',
			'settingsPage.darkMode' => 'Modo oscuro',
			'settingsPage.darkModeDetail' => 'Usa el tema oscuro en blanco y negro.',
			'settingsPage.calendarExperienceLanguage' => 'Calendario, experiencia e idioma',
			'settingsPage.accentColor' => 'Color de acento',
			'settingsPage.accentColorDetail' => 'Paleta ampliada reservada para Evolve Pro.',
			'settingsPage.defaultCalendarView' => 'Vista de calendario predeterminada',
			'settingsPage.timeFormat24hDetail' => 'Usa horas como 20:30 en lugar de 8:30 PM.',
			'settingsPage.hapticFeedback' => 'Respuesta háptica',
			'settingsPage.hapticFeedbackDetail' => 'El escritorio conserva la preferencia pero no genera vibraciones.',
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
			'settingsPage.importDataDetail' => 'Restaura una copia de seguridad (formato .zip) de Evolve.',
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
			'settingsPage.importReplaceSubtitle' => 'Elimina todos los datos locales existentes antes de importar. (Recomendado)',
			'settingsPage.importMergeTitle' => 'Combinar con los datos actuales',
			'settingsPage.importMergeSubtitle' => 'Añade los datos importados sin eliminar nada. Puede causar duplicados.',
			'settingsPage.importConfirmButton' => 'Confirmar importación',
			'settingsPage.importSuccess' => '¡Importación completada correctamente!',
			'settingsPage.importError' => ({required Object error}) => 'Error durante la importación: ${error}',
			'settingsPage.proTitle' => 'Evolve Pro',
			'settingsPage.proSubtitle' => 'Plan, restauración de compras y gestión de suscripción',
			'settingsPage.revenueCatMacos' => 'RevenueCat macOS',
			'settingsPage.commercialChannelRequired' => 'Se requiere un canal comercial',
			'settingsPage.revenueCatOffersRead' => 'Las ofertas y el estado de los derechos se leen desde RevenueCat.',
			'settingsPage.revenueCatConfigureKey' => 'Configura la clave pública de RevenueCat del cliente de escritorio.',
			'settingsPage.revenueCatNotSupported' => 'RevenueCat Flutter no admite compras dentro de la aplicación en Windows y Linux.',
			'settingsPage.bestValue' => 'Mejor valor',
			'settingsPage.planManagement' => 'Gestión del plan',
			'settingsPage.activateEvolvePro' => 'Activar Evolve Pro',
			'settingsPage.activateEvolveProActive' => 'Derecho de Evolve Pro activo.',
			'settingsPage.activateEvolveProStart' => 'Inicia el proceso de pago nativo de StoreKit en macOS.',
			'settingsPage.restorePurchasesDetail' => 'Recupera el estado de los derechos desde el proveedor.',
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
			'settingsPage.proActiveMessage' => 'Tu suscripción está activa. Ahora tiene acceso completo e ilimitado al Entrenador de IA personalizado, estadísticas de tendencias avanzadas y todas las herramientas de crecimiento personal de Evolve.',
			'settingsPage.proStartJourney' => 'Empieza tu recorrido',
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
			'notif.macScheduling' => 'Programación diaria activa en macOS.',
			'notif.linuxImmediate' => 'Linux muestra notificaciones inmediatas, pero no admite la programación.',
			'notif.openEvolve' => 'Abrir Evolve',
			'notif.windowsScheduling' => 'Windows programa la próxima aparición en cada inicio.',
			'notif.morningBody' => 'Revisa los hábitos de hoy y elige por dónde empezar.',
			'notif.habitReminderBody' => 'Es hora de completar tu hábito.',
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
			'subscriptionCtrl.loadOffersFailed' => 'No se pudieron cargar las ofertas de RevenueCat.',
			'subscriptionCtrl.proActivated' => 'Evolve Pro activado.',
			'subscriptionCtrl.purchasesRestored' => 'Compras restauradas.',
			'subscriptionCtrl.noActiveSub' => 'No se encontró ninguna suscripción Pro activa.',
			'subscriptionCtrl.restoreFailed' => 'No se pudieron restaurar las compras.',
			'subscriptionCtrl.configKey' => 'Configura la clave pública de RevenueCat del cliente de escritorio.',
			'subscriptionCtrl.loginFirst' => 'Inicia sesión antes de gestionar Evolve Pro.',
			'authCtrl.appleNoToken' => 'Apple no devolvió un token de identidad.',
			'authCtrl.appleAuthFailed' => 'Error de autenticación de Apple.',
			'authCtrl.cantOpenBrowser' => 'No se pudo abrir el navegador del sistema.',
			'authCtrl.accessNotCompleted' => ({required Object provider}) => 'Inicio de sesión con ${provider} no completado.',
			'authCtrl.providerAuthFailed' => ({required Object provider}) => 'Error de autenticación de ${provider}.',
			'authCtrl.operationFailed' => 'Operación fallida. Inténtalo de nuevo en breve.',
			'proModal.title' => 'Desbloquea Evolve PRO',
			'proModal.subtitle' => 'Lleva tu sistema de hábitos al siguiente nivel',
			'proModal.featuresHeader' => 'Qué incluye el plan PRO',
			'proModal.aiCoachTitle' => 'Coach AI personalizado',
			'proModal.aiCoachDesc' => 'Análisis de tendencias avanzado y sugerencias inteligentes generadas por IA.',
			'proModal.statsTitle' => 'Estadísticas específicas por hábito',
			'proModal.statsDesc' => 'Información clave para aumentar su productividad.',
			'proModal.metricsTitle' => 'Métricas avanzadas de objetivos',
			'proModal.metricsDesc' => 'Vea gráficos detallados y estadísticas detalladas de rendimiento para cada año.',
			'proModal.unlimitedTitle' => 'Hábitos ilimitados',
			'proModal.unlimitedDesc' => 'Crea y rastrea todos los hábitos que quieras sin límites.',
			'proModal.maybeLater' => 'Quizá más tarde',
			'proModal.viewPlans' => 'Ver planes Pro',
			_ => null,
		};
	}
}
