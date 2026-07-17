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
class TranslationsAr extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsAr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ar,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ar>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsAr _root = this; // ignore: unused_field

	@override 
	TranslationsAr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsAr(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$auth$ar auth = _Translations$auth$ar._(_root);
	@override late final _Translations$privateAi$ar privateAi = _Translations$privateAi$ar._(_root);
	@override late final _Translations$privateData$ar privateData = _Translations$privateData$ar._(_root);
	@override late final _Translations$icloudSync$ar icloudSync = _Translations$icloudSync$ar._(_root);
	@override late final _Translations$privateRecovery$ar privateRecovery = _Translations$privateRecovery$ar._(_root);
	@override late final _Translations$namePrompt$ar namePrompt = _Translations$namePrompt$ar._(_root);
	@override late final _Translations$nav$ar nav = _Translations$nav$ar._(_root);
	@override late final _Translations$shell$ar shell = _Translations$shell$ar._(_root);
	@override late final _Translations$common$ar common = _Translations$common$ar._(_root);
	@override late final _Translations$form$ar form = _Translations$form$ar._(_root);
	@override late final _Translations$createGoal$ar createGoal = _Translations$createGoal$ar._(_root);
	@override late final _Translations$createHabit$ar createHabit = _Translations$createHabit$ar._(_root);
	@override late final _Translations$macroGoals$ar macroGoals = _Translations$macroGoals$ar._(_root);
	@override late final _Translations$statistics$ar statistics = _Translations$statistics$ar._(_root);
	@override late final _Translations$goalState$ar goalState = _Translations$goalState$ar._(_root);
	@override late final _Translations$dueLabel$ar dueLabel = _Translations$dueLabel$ar._(_root);
	@override late final _Translations$dashboard$ar dashboard = _Translations$dashboard$ar._(_root);
	@override late final _Translations$stats$ar stats = _Translations$stats$ar._(_root);
	@override late final _Translations$habitsPage$ar habitsPage = _Translations$habitsPage$ar._(_root);
	@override String get lavoro => 'العمل';
	@override String get salute => 'الصحة';
	@override String get finanza => 'المال';
	@override String get relazioni => 'العلاقات';
	@override String get formazione => 'التعليم';
	@override String get hobby => 'الهوايات';
	@override String get spirituale => 'الروحانية';
	@override String get altro => 'أخرى';
	@override late final _Translations$goalsPage$ar goalsPage = _Translations$goalsPage$ar._(_root);
	@override late final _Translations$goalsStats$ar goalsStats = _Translations$goalsStats$ar._(_root);
	@override late final _Translations$ai$ar ai = _Translations$ai$ar._(_root);
	@override late final _Translations$aiCoach$ar aiCoach = _Translations$aiCoach$ar._(_root);
	@override late final _Translations$settingsPage$ar settingsPage = _Translations$settingsPage$ar._(_root);
	@override late final _Translations$consent$ar consent = _Translations$consent$ar._(_root);
	@override late final _Translations$notifications$ar notifications = _Translations$notifications$ar._(_root);
	@override late final _Translations$privacy$ar privacy = _Translations$privacy$ar._(_root);
	@override late final _Translations$consentPage$ar consentPage = _Translations$consentPage$ar._(_root);
	@override late final _Translations$notif$ar notif = _Translations$notif$ar._(_root);
	@override late final _Translations$biometricGate$ar biometricGate = _Translations$biometricGate$ar._(_root);
	@override late final _Translations$sync$ar sync = _Translations$sync$ar._(_root);
	@override late final _Translations$subscriptionCtrl$ar subscriptionCtrl = _Translations$subscriptionCtrl$ar._(_root);
	@override late final _Translations$authCtrl$ar authCtrl = _Translations$authCtrl$ar._(_root);
	@override late final _Translations$proModal$ar proModal = _Translations$proModal$ar._(_root);
	@override late final _Translations$appLogs$ar appLogs = _Translations$appLogs$ar._(_root);
	@override late final _Translations$coachSettings$ar coachSettings = _Translations$coachSettings$ar._(_root);
	@override late final _Translations$tour$ar tour = _Translations$tour$ar._(_root);
	@override late final _Translations$palette$ar palette = _Translations$palette$ar._(_root);
}

// Path: auth
class _Translations$auth$ar extends Translations$auth$en {
	_Translations$auth$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get continuePrivately => 'المتابعة في الوضع الخاص على هذا الـ Mac';
	@override String get signIn => 'تسجيل الدخول';
	@override String get register => 'التسجيل';
	@override String get or => 'أو';
	@override String get password => 'كلمة المرور';
	@override String get forgotPassword => 'هل نسيت كلمة المرور؟';
	@override String get haveAccount => 'هل لديك حساب بالفعل؟';
	@override String get noAccount => 'ليس لديك حساب؟';
	@override String get continueWithApple => 'المتابعة باستخدام Apple';
	@override String get continueWithGoogle => 'المتابعة باستخدام Google';
	@override String get readPrivacyPolicy => 'اقرأ سياسة الخصوصية';
	@override String get nameLabel => 'الاسم الأول';
	@override String get invalidEmail => 'أدخل بريداً إلكترونياً صالحاً';
	@override String get confirmEmail => 'تحقّق من بريدك الإلكتروني لتأكيد تسجيلك.';
	@override String get resetSent => 'تم إرسال البريد الإلكتروني. تحقّق من صندوق الوارد.';
	@override String get signInTitle => 'تسجيل الدخول إلى Evolve';
	@override String get signUpTitle => 'أنشئ حسابك';
	@override String get resetTitle => 'استعادة كلمة المرور';
	@override String get emailLabel => 'البريد الإلكتروني';
	@override String get passwordMin8 => 'استخدم 8 أحرف على الأقل.';
	@override String get sendResetLink => 'إرسال رابط الاستعادة';
}

// Path: privateAi
class _Translations$privateAi$ar extends Translations$privateAi$en {
	_Translations$privateAi$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get consentTitle => 'السماح بالإرسال إلى الذكاء الاصطناعي';
	@override String get consentBody => 'في الوضع الخاص تبقى بياناتك على جهازك. لاستخدام مدرب الذكاء الاصطناعي، تُرسَل العادات والأهداف التي تختار مشاركتها إلى مزوّد ذكاء اصطناعي خارجي (OpenRouter). هل تريد المتابعة؟';
	@override String get cancel => 'إلغاء';
	@override String get accept => 'أوافق';
}

// Path: privateData
class _Translations$privateData$ar extends Translations$privateData$en {
	_Translations$privateData$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get deleteTitle => 'حذف البيانات الخاصة';
	@override String get deleteMessage => 'هل أنت متأكد أنك تريد حذف كامل قاعدة البيانات المحلية المشفّرة؟ هذا الإجراء لا يمكن التراجع عنه ولا يمكن استرجاع البيانات.';
	@override String get deleteSuccess => 'تم حذف البيانات الخاصة.';
	@override String get deleteFailed => 'فشلت العملية.';
	@override String get exportDoneTitle => 'اكتمل التصدير';
	@override String get exportDoneClipboard => 'ملف JSON في الحافظة: لا يدعم لينكس مشاركة الملفات.';
	@override String get exportDoneShare => 'تم إرسال ملف JSON إلى أداة المشاركة.';
}

// Path: icloudSync
class _Translations$icloudSync$ar extends Translations$icloudSync$en {
	_Translations$icloudSync$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'مزامنة iCloud';
	@override String get enableTitle => 'تفعيل مزامنة iCloud';
	@override String get syncNow => 'مزامنة الآن';
	@override String get disclosureTitle => 'تشفير تام بين الطرفين';
	@override String get disclosureBody => 'تتم مزامنة بياناتك الخاصة فقط عبر حساب iCloud الخاص بك، بتشفير تام بين الطرفين — وليس عبر خوادمنا أبدًا. يُحفظ مفتاح التشفير في سلسلة مفاتيح iCloud الخاصة بك؛ إذا أوقفت سلسلة مفاتيح iCloud، فلن يمكن استرداد البيانات المتزامنة.';
	@override String get disclosureAccept => 'تفعيل';
	@override String get statusIdle => 'مُحدَّث';
	@override String get statusSyncing => 'جارٍ المزامنة…';
	@override String get statusOff => 'المزامنة متوقفة';
	@override String get statusNoAccount => 'سجّل الدخول إلى iCloud للمزامنة';
	@override String get statusUnavailable => 'iCloud غير متاح حاليًا';
	@override String get statusWaitingKeychain => 'في انتظار سلسلة مفاتيح iCloud — تأكد من تحديث التطبيق على iPhone الخاص بك';
	@override String get lastSyncedNever => 'لم تتم المزامنة مطلقًا';
	@override String lastSyncedAt({required Object time}) => 'آخر مزامنة ${time}';
	@override String get deleteSyncNote => 'مزامنة iCloud مفعّلة: سيؤدي هذا أيضًا إلى حذف النسخة المتزامنة من iCloud الخاص بك وإيقاف المزامنة. تحتفظ الأجهزة الأخرى بنسختها المحلية — نفّذ هذا الإجراء على كل جهاز للحذف في كل مكان.';
	@override String get bannerText => 'مزامنة iCloud متوقفة — عاداتك موجودة فقط على هذا الجهاز وستُفقد إذا أعدت ضبطه أو استبدلته.';
	@override String get bannerAction => 'تفعيل';
}

// Path: privateRecovery
class _Translations$privateRecovery$ar extends Translations$privateRecovery$en {
	_Translations$privateRecovery$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get preparing => 'جارٍ تجهيز مساحتك الخاصة…';
	@override String get restoredFromCloudToast => 'تعذّر فتح قاعدة البيانات المحلية — تمت استعادة بياناتك من iCloud.';
	@override String get waitingTitle => 'بانتظار iCloud';
	@override String get waitingMessage => 'المزامنة مفعّلة، لكن مفتاح التشفير لم يصل بعد من سلسلة مفاتيح iCloud. انتظر لحظة ثم أعد المحاولة.';
	@override String get lockedTitle => 'تعذّر فتح البيانات الخاصة';
	@override String get lockedMessageLocalOnly => 'لا يستطيع هذا الجهاز فتح قاعدة بياناتك الخاصة المحلية — مفتاح التشفير مفقود — ومزامنة iCloud متوقّفة، لذا لا توجد نسخة سحابية للاستعادة. يمكنك إعادة التعيين والبدء من جديد.';
	@override String get lockedMessageICloudUnavailable => 'لا يستطيع هذا الجهاز فتح قاعدة بياناتك الخاصة المحلية. مزامنة iCloud مفعّلة لكن الحساب غير متاح — سجّل الدخول إلى iCloud ثم أعد المحاولة.';
	@override String get errorTitle => 'تعذّر فتح الوضع الخاص';
	@override String get errorMessage => 'حدث خطأ أثناء فتح قاعدة بياناتك الخاصة. أعد المحاولة، أو أعد تعيينها وابدأ من جديد.';
	@override String get enableSyncHint => 'هل لديك هذه البيانات على جهاز آخر؟ فعّل مزامنة iCloud من الإعدادات بعد إعادة التعيين لجلبها إلى هنا.';
	@override String get retry => 'إعادة المحاولة';
	@override String get resetFresh => 'إعادة التعيين والبدء من جديد';
	@override String get backToSignIn => 'العودة إلى تسجيل الدخول';
}

// Path: namePrompt
class _Translations$namePrompt$ar extends Translations$namePrompt$en {
	_Translations$namePrompt$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'ما اسمك؟';
	@override String get subtitle => 'أدخل اسمك لتخصيص لوحة المعلومات.';
	@override String get hint => 'مثال: Simo';
	@override String get save => 'حفظ ومتابعة';
}

// Path: nav
class _Translations$nav$ar extends Translations$nav$en {
	_Translations$nav$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get overview => 'نظرة عامة';
	@override String get habits => 'العادات';
	@override String get insights => 'الإحصاءات';
	@override String get goals => 'الأهداف';
	@override String get coach => 'مدرّب AI';
	@override String get settings => 'الإعدادات';
}

// Path: shell
class _Translations$shell$ar extends Translations$shell$en {
	_Translations$shell$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get syncPending => 'المزامنة معلّقة';
	@override String get syncing => 'جارٍ المزامنة';
	@override String get synced => 'تمت المزامنة';
	@override String get syncTooltip => 'مزامنة';
	@override String get searchHint => 'ابحث أو تنقّل';
	@override String get searchSectionHint => 'ابحث عن قسم...';
}

// Path: common
class _Translations$common$ar extends Translations$common$en {
	_Translations$common$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override late final _Translations$common$actions$ar actions = _Translations$common$actions$ar._(_root);
	@override List<String> get months => [
		'يناير',
		'فبراير',
		'مارس',
		'أبريل',
		'مايو',
		'يونيو',
		'يوليو',
		'أغسطس',
		'سبتمبر',
		'أكتوبر',
		'نوفمبر',
		'ديسمبر',
	];
	@override List<String> get weekdayInitials => [
		'ن',
		'ث',
		'ر',
		'خ',
		'ج',
		'س',
		'ح',
	];
	@override late final _Translations$common$calendarView$ar calendarView = _Translations$common$calendarView$ar._(_root);
	@override List<String> get weekdaysLong => [
		'الاثنين',
		'الثلاثاء',
		'الأربعاء',
		'الخميس',
		'الجمعة',
		'السبت',
		'الأحد',
	];
	@override String get none => 'لا شيء';
	@override String get habits => 'العادات';
	@override late final _Translations$common$status$ar status = _Translations$common$status$ar._(_root);
	@override String get total => 'الإجمالي';
	@override String get completed => 'مكتمل';
	@override String get unexpectedErrorTitle => 'حدث خطأ ما';
	@override String get unexpectedErrorMessage => 'حدث خطأ غير متوقع. حاول مرة أخرى.';
}

// Path: form
class _Translations$form$ar extends Translations$form$en {
	_Translations$form$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'العنوان';
	@override String get category => 'الفئة';
	@override String get color => 'اللون';
	@override String get add => 'إضافة';
}

// Path: createGoal
class _Translations$createGoal$ar extends Translations$createGoal$en {
	_Translations$createGoal$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'هدف جديد';
	@override String get subtitle => 'حدّد هدفك التالي.';
	@override String get titleHint => 'مثال: إطلاق المنتج الجديد';
	@override String get categoryHint => 'مثال: العمل';
	@override String get timeline => 'الجدول الزمني';
	@override String get thisWeek => 'هذا الأسبوع';
	@override String get thisMonth => 'هذا الشهر';
	@override String get thisQuarter => 'هذا الربع';
	@override String get thisYear => 'هذه السنة';
	@override String get longTerm => 'طويل الأمد (Lifetime)';
	@override String get dueLifetime => 'مدى الحياة';
	@override String dueByYear({required Object year}) => 'بحلول ${year}';
	@override String get defaultCategory => 'هدف';
	@override String get periodWhen => 'متى';
}

// Path: createHabit
class _Translations$createHabit$ar extends Translations$createHabit$en {
	_Translations$createHabit$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'عادة جديدة';
	@override String get subtitle => 'حدّد عادتك الجديدة.';
	@override String get titleHint => 'مثال: التأمل';
	@override String get weeklyFrequency => 'التكرار الأسبوعي';
}

// Path: macroGoals
class _Translations$macroGoals$ar extends Translations$macroGoals$en {
	_Translations$macroGoals$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override late final _Translations$macroGoals$types$ar types = _Translations$macroGoals$types$ar._(_root);
	@override String quarterNumber({required Object quarter}) => 'الربع ${quarter}';
	@override String get addLifetimeGoal => 'أضف هدف العُمر...';
	@override String get addAnnualGoal => 'أضف هدفاً سنوياً...';
	@override String get addQuarterlyGoal => 'أضف هدفاً ربع سنوي...';
	@override String get addMonthlyGoal => 'أضف هدفاً شهرياً...';
	@override String get addWeeklyGoal => 'أضف هدفاً أسبوعياً...';
	@override String get completed => 'مكتملة';
	@override String get failed => 'فاشلة';
	@override String get create => 'إنشاء';
	@override String get strength => 'نقطة القوة';
	@override String get bestMonth => 'أفضل شهر';
	@override String get successRate2 => 'معدل النجاح';
	@override String get effectiveType => 'النوع الفعّال';
	@override String get historicalTotal => 'الإجمالي التاريخي';
	@override String get from_ => 'من';
	@override String get globalSuccess => 'النجاح الإجمالي';
	@override String get completedGoals => 'أهداف مكتملة';
	@override String get bestYear => 'أفضل سنة';
	@override String get mostProductiveYear => 'أكثر سنة إنتاجية';
	@override String get totalGoals => 'إجمالي الأهداف';
	@override String get allYears => 'كل السنوات';
	@override String get selectYearHeader => 'اختر السنة';
	@override String get completions => 'الإنجازات';
	@override String get success2 => 'النجاح';
	@override String get archiveCategory2 => 'أرشفة الفئة؟';
	@override String categoryUnavailableLinked({required Object label, required Object count}) => 'لن تعود الفئة "${label}" متاحة للأهداف الجديدة، لكنها ستبقى مرتبطة بـ ${count} أهداف سابقة وبإحصاءاتك.';
	@override String categoryUnavailableArchived({required Object label}) => 'لن تعود الفئة "${label}" متاحة للأهداف الجديدة، لكنها ستبقى في سجلّك.';
	@override String get archive => 'أرشفة';
	@override String get createNewCategory => 'إنشاء فئة جديدة';
}

// Path: statistics
class _Translations$statistics$ar extends Translations$statistics$en {
	_Translations$statistics$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get completed2 => 'مكتمل';
	@override String get notCompleted => 'غير مكتملة';
	@override String get ofCompletion => 'من الإكمال';
	@override String get growth => 'نمو';
	@override String get decline => 'انخفاض';
	@override String get strongestDay => 'أقوى يوم';
	@override String get weakestDay => 'أضعف يوم';
	@override String get worstNegativeStreak => 'أسوأ سلسلة سلبية';
	@override String get missedConsecutiveDays => 'أيام متتالية فائتة';
	@override String get brokenStreaks => 'السلاسل المنقطعة';
	@override String get noBrokenStreaks => 'لم تُسجَّل أي سلاسل منقطعة';
	@override String get startedOn => 'بدأت في';
	@override String get moodCorrelation => 'ارتباط المزاج';
	@override String get avgMood => 'متوسط المزاج (✓)';
	@override String get avgEnergy => 'متوسط الطاقة (✓)';
	@override String get onCompletedDays => 'في الأيام المكتملة';
	@override String get resilient => 'مرنة';
	@override String get completedVsMissed => 'مكتملة مقابل فائتة';
	@override String get mood2 => 'المزاج';
	@override String get energy => 'الطاقة';
	@override String get performancePerLevel => 'الأداء حسب المستوى';
	@override String get withHighMood => 'مع مزاج مرتفع';
	@override String get withLowMood => 'مع مزاج منخفض';
	@override String get moodEnergyAnalysis => 'يوضّح التحليل كيف تتأثّر مواظبتك بمزاجك وطاقتك.';
	@override String get missed2 => 'فائت';
	@override String get positive => 'إيجابي';
	@override String get neutral => 'محايد';
	@override String get high => 'مرتفع';
	@override String get low => 'منخفض';
	@override String get skipped => 'متخطّاة';
	@override String get criticalHabits => 'العادات الحرجة';
	@override String get bestHabitsTitle => 'أفضل العادات';
	@override String get worseningHabitsDescription => 'العادات الأكثر تراجعاً.';
	@override String get everythingIsGreat => 'كل شيء على ما يُرام!';
	@override String get allHabitsStableDescription => 'جميع عاداتك تحافظ على اتجاهها أو تحسّنه. واصل التقدّم.';
	@override String habitCompletionPeriodDescription({required Object rate}) => 'أكملت هذه العادة ${rate}% من الوقت خلال الفترة المحدّدة.';
	@override String habitLostConsistencyDescription({required Object drop}) => 'فقدت هذه العادة ${drop}% من المواظبة في الأسبوع الماضي مقارنةً بالذي قبله.';
	@override String get negativeStreak => 'السلسلة السلبية';
	@override String get currentStreak2 => 'السلسلة الحالية';
	@override String get improvementAreas => 'مجالات التحسين';
	@override String get habitsRequiringMoreAttention => 'عادات تتطلّب مزيداً من الاهتمام.';
	@override String get failureAnalysis => 'تحليل الإخفاقات';
	@override String get missedDaysPattern => 'تكرار وأنماط أيامك الفائتة.';
	@override String get recoveryPatterns => 'أنماط التعافي';
	@override String get recoverySpeed => 'مدى سرعة عودتك إلى المسار بعد تعثّر.';
	@override String get avgRecoveryTime => 'متوسط وقت التعافي';
	@override String get worstStreak => 'أسوأ سلسلة';
	@override String get frequency => 'التكرار';
	@override String get daysShortUnit => 'ي';
	@override String get perMonthUnit => 'شهر';
	@override String get succ => 'نجاح';
	@override String get blackDay => 'يوم أسود';
	@override String get correlationsWith => 'الارتباطات مع';
	@override String get howThisHabitRelatesToOthers => 'كيف ترتبط هذه العادة بالعادات الأخرى';
	@override String get positiveCorrelations => 'ارتباطات إيجابية';
	@override String get negativeCorrelations => 'ارتباطات سلبية';
	@override String get noSignificantPositiveCorrelation => 'لا يوجد ارتباط إيجابي مهم';
	@override String get noSignificantNegativeCorrelation => 'لا يوجد ارتباط سلبي مهم';
	@override String habitTogetherPercent({required Object percentage}) => '${percentage}% معاً';
	@override String habitPositiveCorrelationDescription({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'عندما تُكمل "${currentGoal}"، تكون لديك فرصة بنسبة ${percentage}% لإكمال "${otherGoal}" أيضاً.';
	@override String habitNegativeCorrelationDescription({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'عندما تُكمل "${currentGoal}"، تكون لديك فرصة بنسبة ${percentage}% فقط لإكمال "${otherGoal}" أيضاً.';
	@override String get weeklyTrend => 'الاتجاه الأسبوعي';
	@override String get monthlyTrend => 'الاتجاه الشهري';
	@override String get yearlyTrend => 'الاتجاه السنوي';
	@override String get performanceEvolution => 'تطوّر الأداء';
	@override String get globalTrend => 'الاتجاه الإجمالي';
	@override String get total => 'الإجمالي';
	@override String get all => 'الكل';
	@override String get noDataForAlerts => 'لا توجد بيانات كافية لإنشاء تنبيهات.';
	@override String get missed => 'فائتة';
}

// Path: goalState
class _Translations$goalState$ar extends Translations$goalState$en {
	_Translations$goalState$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get active => 'قيد التنفيذ';
}

// Path: dueLabel
class _Translations$dueLabel$ar extends Translations$dueLabel$en {
	_Translations$dueLabel$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get lifetime => 'هدف الحياة';
	@override String get annual => 'هدف سنوي';
	@override String get quarter => 'ربع';
}

// Path: dashboard
class _Translations$dashboard$ar extends Translations$dashboard$en {
	_Translations$dashboard$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get mood => 'المزاج';
	@override String get energy => 'الطاقة';
	@override String get goodMorning => 'صباح الخير';
	@override String get goodAfternoon => 'مساء الخير';
	@override String get goodEvening => 'مساء الخير';
	@override String get manager => 'الإدارة';
	@override String get aiChat => 'محادثة AI';
	@override String get consecutiveDays => 'أيام متتالية';
	@override String get welcomeTitle => 'مرحبًا بك في Evolve';
	@override String get welcomeSubtitle => 'ابدأ رحلة نموّك الشخصي.';
	@override String get welcomeBody => 'يساعدك هذا التطبيق على بناء عادات جيدة وتحقيق أهدافك طويلة المدى.';
	@override String get welcomeStart => 'ابدأ';
	@override String get subtitle => 'حافظ على الإيقاع. كل فعل صغير يعزّز الشخص الذي تبنيه.';
	@override String get completionToday => 'إنجاز اليوم';
	@override String habitsCount({required Object done, required Object total}) => '${done}/${total} عادات';
	@override String get bestStreak => 'أفضل سلسلة';
	@override String get activeGoals => 'الأهداف النشطة';
	@override String avgProgress({required Object pct}) => '${pct}% متوسط التقدّم';
	@override String get momentum => 'الزخم';
	@override String get vsLastWeek => 'مقارنةً بالأسبوع الماضي';
	@override String get weeklyTrend => 'الاتجاه الأسبوعي';
	@override String get weeklyTrendSubtitle => 'نسبة إنجاز عاداتك';
	@override String thisWeekPill({required Object value}) => '${value} هذا الأسبوع';
	@override String get todayProtocol => 'بروتوكول اليوم';
	@override String get todayProtocolSubtitle => 'أكمل الإجراءات الأساسية قبل إضافة المزيد';
	@override String actionsCount({required Object count}) => '${count} إجراءات';
	@override String get emptyHabits => 'لوحتك فارغة. أنشئ عادتك الأولى.';
	@override String streakDaysShort({required Object n}) => '${n} ي';
	@override String get checkInDone => 'تم تسجيل المتابعة';
	@override String get checkInPrompt => 'كيف تشعر اليوم؟';
	@override String moodEnergyValue({required Object mood, required Object energy}) => 'المزاج ${mood}/10 · الطاقة ${energy}/10';
	@override String get checkInHint => 'سجّل المزاج والطاقة لتحسين تحليل أنماطك.';
	@override String get updateCheckIn => 'تحديث المتابعة';
	@override String get doCheckIn => 'قم بالمتابعة';
	@override String get dailyCheckIn => 'المتابعة اليومية';
	@override String get dailyCheckInSubtitle => 'قياس سريع يساعد Evolve على فهم أنماطك بشكل أفضل.';
	@override String get record => 'تسجيل';
	@override String get focusGoals => 'الأهداف قيد التركيز';
	@override String get currentPriorities => 'الأولويات الحالية';
	@override String get goalLimitReached => 'تم بلوغ حدّ 100 هدف. اشترك في Pro لإنشاء المزيد.';
	@override String get emptyFocusGoals => 'لا أهداف قيد التركيز. أضف واحدًا.';
	@override String get weekToStart => 'أسبوع للانطلاق';
	@override String get weekGrowing => 'أسبوع في تصاعد';
	@override String get weekToRecover => 'أسبوع للتعافي';
	@override String vsPreviousWeek({required Object value}) => '${value} مقارنةً بالأسبوع السابق.';
}

// Path: stats
class _Translations$stats$ar extends Translations$stats$en {
	_Translations$stats$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'الإحصاءات';
	@override String get global => 'إجمالي';
	@override String get resilience => 'المرونة';
	@override String get tabHabits => 'العادات';
	@override String get tabMood => 'المزاج';
	@override String get last30Days => 'آخر 30 يومًا';
	@override String get singleHabit => 'عادة واحدة';
	@override String get noHabit => 'لا توجد عادة';
	@override String get completionToday => 'إنجاز اليوم';
	@override String get bestStreakLabel => 'أفضل سلسلة';
	@override String get criticalDay => 'يوم حرج';
	@override String get completePrioritiesFirst => 'أكمل الأولويات أولًا';
	@override String get recentActivity => 'النشاط الأخير';
	@override String get recentActivitySubtitle => 'كثافة الإنجاز خلال آخر 90 يومًا';
	@override String get trendGlobal => 'الاتجاه العام';
	@override String get trendGlobalSubtitle => 'مقارنة زمنية للبروتوكول';
	@override String vsPrevDay({required Object value}) => '${value}% مقارنةً باليوم السابق';
	@override String get bestHabit => 'أفضل عادة';
	@override String get criticalArea => 'منطقة حرجة';
	@override String get streakAtRisk => 'سلسلة في خطر';
	@override String streakAtRiskDetail({required Object habit}) => '${habit} يحتاج إلى انتباه في المتابعات القادمة.';
	@override String get patternToConsolidate => 'نمط للترسيخ';
	@override String get checkLowMoodDays => 'راجع أيام المزاج المنخفض وحافظ على البروتوكول الأساسي.';
	@override String get goalDue => 'هدف قارب على الاستحقاق';
	@override String get noGoalNeedsIntervention => 'لا يوجد هدف نشط يحتاج إلى تدخل.';
	@override String get performancePerHabit => 'الأداء لكل عادة';
	@override String get performancePerHabitSubtitle => 'ترتيب محسوب من السجلات المتزامنة حسب الاتساق الأسبوعي';
	@override String get avgMood => 'متوسط المزاج';
	@override String get avgEnergy => 'متوسط الطاقة';
	@override String checkInsAvailable({required Object count}) => '${count} متابعات متاحة';
	@override String get resilientHabit => 'عادة مرنة';
	@override String get completedEvenHardDays => 'أُنجزت حتى في الأيام الصعبة';
	@override String get moodEnergy => 'المزاج والطاقة';
	@override String get moodEnergySubtitle => 'متوسط المتابعات المتاحة خلال آخر 90 يومًا';
	@override String get completion => 'الإنجاز';
	@override String get currentWeek => 'الأسبوع الحالي';
	@override String get currentStreak => 'السلسلة الحالية';
	@override String get currentStreakDetail => 'سلسلة متزامنة من السجلات المتاحة';
	@override String get trend30 => 'اتجاه 30 يومًا';
	@override String get trend30Detail => 'الإنجاز خلال آخر 30 يومًا';
	@override String get yearlyCalendar => 'التقويم السنوي';
	@override String yearlyCalendarSubtitle({required Object habit}) => 'توزيع إنجازات ${habit}';
	@override String get performancePerDay => 'الأداء لكل يوم';
	@override String get performancePerDaySubtitle => 'أيام الأسبوع القوية والضعيفة';
	@override String protectStreak({required Object days}) => 'احمِ سلسلة ${days} أيام';
	@override String get keepSameSlot => 'حافظ على نفس الفترة الزمنية لتقليل الاحتكاك في أكثر الأيام ازدحامًا.';
	@override String worstNegativeSeq({required Object days}) => 'استمرت أسوأ سلسلة سلبية ${days} يومًا.';
	@override String get positiveLever => 'رافعة إيجابية مكتشفة';
	@override String bestHabitRegularity({required Object habit}) => '${habit} يحافظ على أفضل انتظام حديث.';
	@override String get moodSensitivity => 'الحساسية للمزاج';
	@override String get lowEnergyCompletion => 'الإنجاز مع طاقة منخفضة';
	@override String get moodOutputCorrelation => 'الارتباط بين المزاج والأداء';
	@override String get moodOutputSubtitle => 'الإنجازات المتاحة في أيام المتابعة';
	@override String get keyCorrelations => 'الارتباطات الرئيسية';
	@override String get keyCorrelationsSubtitle => 'الأنماط الأكثر تأثيرًا على البروتوكول';
	@override String get moreLogsNeeded => 'يلزم المزيد من السجلات لحساب ارتباطات مفيدة.';
	@override String get createHabitForAnalysis => 'أنشئ عادة واحدة على الأقل لعرض التحليل التفصيلي.';
	@override String get noData => 'لا توجد بيانات';
	@override String get tabInfo => 'معلومات';
	@override String get tabTrend => 'الاتجاه';
	@override String get tabAlerts => 'تنبيهات';
	@override String get tabOverview => 'نظرة عامة';
	@override String get tabCalendar => 'التقويم';
	@override String get tabPerformance => 'الأداء';
	@override String get tabImprovement => 'تحسين';
	@override String get pageSubtitle => 'حدّد الأنماط التي تدعم النمو وتدخّل في المناطق الحرجة.';
	@override String actionsFraction({required Object done, required Object total}) => '${done}/${total} إجراءات';
	@override String affectedByHardDays({required Object habit}) => '${habit} يتأثر بالأيام الصعبة';
	@override String get last30DaysTrend => 'اتجاه آخر 30 يوماً';
	@override String strongestDayDetail({required Object pct, required Object done, required Object total}) => 'احسنت، ${pct}% اكتمال (${done}/${total})';
	@override String weakestDayDetail({required Object pct, required Object done, required Object total}) => 'فقط ${pct}% اكتمال (${done}/${total})';
	@override String brokenStreakItem({required Object days}) => 'سلسلة من ${days} يوم انقطعت';
	@override String togetherProbability({required Object percentage}) => '${percentage}% معا';
	@override String get criticalHabitsSubtitle => 'العادات الأكثر تراجعاً.';
	@override String get bestHabitsSubtitle => 'العادات التي تكون فيها الاكثر ثباتا.';
	@override String get timeframeWeek => 'أسبوع';
	@override String get timeframeMonth => 'شهر';
	@override String get timeframeYear => 'سنة';
	@override String get timeframeAll => 'الكل';
	@override String negativeStreakDays({required Object days}) => '${days} يوم دون اكمال';
	@override String dropPercent({required Object drop}) => '-${drop}%';
	@override String blackDayDetail({required Object day}) => 'يوم اسود: ${day}';
	@override String failureDetail({required Object streak, required Object frequency}) => 'اسوأ سلسلة: ${streak}ي · ~${frequency}/شهر فائتة';
	@override String recoveryDetail({required Object days}) => 'متوسط وقت التعافي: ${days} يوم';
	@override String successRate({required Object rate}) => '${rate}% نجاح';
	@override String get sortRate => 'النسبة';
	@override String get sortStreak => 'التتابع';
	@override String get sortName => 'الاسم';
	@override String get worstStreakLabel => 'الأسوأ';
	@override String get momentumTitle => 'الزخم';
	@override String get momentumSubtitle => 'حالتك الحالية';
	@override String get momentumForm => 'الحالة';
	@override String get momentumRate => '7 أيام';
	@override String get momentumStreakHealth => 'السلاسل';
	@override String get momentumTrend => 'الاتجاه';
	@override String get rollingImproving => 'في تحسّن';
	@override String get rollingDeclining => 'في تراجع';
	@override String get rollingSteady => 'ثابت';
	@override String get lifetimeConsistency => 'الانتظام';
	@override String get lifetimeConsistencyDetail => 'الإنجاز الإجمالي';
	@override String get lifetimeTotalDone => 'إجمالي المنجز';
	@override String get lifetimeTotalDoneDetail => 'العادات المكتملة';
	@override String get lifetimePerfectDays => 'أيام مثالية';
	@override String get lifetimePerfectDaysDetail => 'كل شيء مكتمل';
	@override String get lifetimeDaysTracked => 'الأيام المتتبعة';
	@override String get lifetimeDaysTrackedDetail => 'منذ أن بدأت';
	@override String get keystoneTitle => 'العادة المحورية';
	@override String keystoneImpact({required Object withPct, required Object withoutPct}) => 'في أيامها تنجز ${withPct}% من عاداتك الأخرى، مقابل ${withoutPct}%.';
	@override String get yearActivity => 'نشاط 365 يومًا';
	@override String get yearActivitySubtitle => 'كل عادة، كل يوم';
	@override String activeDaysCount({required Object count}) => '${count} يوم نشط';
	@override String get heatmapLess => 'أقل';
	@override String get heatmapMore => 'أكثر';
	@override String get bestHabitsTitle => 'أفضل العادات';
	@override String get criticalHabitsTitle => 'تحتاج انتباهًا';
	@override String criticalStalled({required Object days}) => 'متوقفة ${days}ي';
	@override String get rollingTitle => 'الإنجاز المتحرك';
	@override String get rollingSubtitle => 'معدل 7 و30 يومًا';
	@override String get rolling7 => '7 أيام';
	@override String get rolling30 => '30 يومًا';
	@override String get weekVsAvgTitle => 'هذا الأسبوع مقابل المتوسط';
	@override String get weekVsAvgSubtitle => 'كيف يقارن هذا الأسبوع';
	@override String get thisWeek => 'هذا الأسبوع';
	@override String get yourAverage => 'متوسطك';
	@override String get weekdayShapeTitle => 'الإيقاع الأسبوعي';
	@override String get weekdayShapeSubtitle => 'الإنجاز حسب اليوم';
	@override String get weekdayWeekendTitle => 'أيام العمل مقابل العطلة';
	@override String get weekdayWeekendSubtitle => 'أين أنت الأقوى';
	@override String get weekdaysLabel => 'أيام العمل';
	@override String get weekendLabel => 'عطلة الأسبوع';
	@override String get seasonalityTitle => 'الموسمية';
	@override String get seasonalitySubtitle => 'الإنجاز حسب الشهر';
	@override String get bounceBackTitle => 'معدل التعافي';
	@override String get bounceBackSubtitle => 'التعافي بعد الإخفاق';
	@override String bounceBackDetail({required Object recoveries, required Object opportunities}) => 'تعافيت ${recoveries} من ${opportunities} مرة';
	@override String get dangerZoneTitle => 'منطقة الخطر';
	@override String get dangerZoneSubtitle => 'متى تنكسر السلاسل';
	@override String get dangerZoneNone => 'لا سلاسل مكسورة بعد';
	@override String dangerZoneDetail({required Object breaks, required Object total}) => '${breaks} من ${total} انكسار هنا';
	@override String get performanceComparisonTitle => 'مقارنة الأداء';
	@override String get performanceComparisonSubtitle => 'أفضل سلسلة مقابل أسوأ';
	@override String perfCompGap({required Object pct}) => 'فارق ${pct}%';
	@override String get perfCompBest => 'الأفضل';
	@override String get perfCompWorst => 'الأسوأ';
	@override String get consistencyTitle => 'الانتظام';
	@override String get consistencySubtitle => 'أكثر العادات انتظامًا';
	@override String get consistencySteadiest => 'الأكثر ثباتًا';
	@override String get consistencyErratic => 'الأكثر تذبذبًا';
	@override String get medalsTitle => 'ترتيب السلاسل';
	@override String get medalsSubtitle => 'أطول السلاسل الحالية';
	@override String get neverMissedTitle => 'لم تُفوَّت';
	@override String get neverMissedEmpty => 'لا عادات مثالية بعد';
	@override String get distributionTitle => 'التوزيع';
	@override String get distributionSubtitle => 'العادات حسب معدل النجاح';
	@override String get synergyTitle => 'تآزر العادات';
	@override String get synergySubtitle => 'أي العادات تسير معًا';
	@override String get moodSensitiveTitle => 'حساسة للمزاج';
	@override String get moodSensitiveSubtitle => 'الأكثر تأثرًا بمزاجك';
	@override String get resilientHabitsTitle => 'عادات صامدة';
	@override String get resilientHabitsSubtitle => 'تُنجَز حتى في الأيام الصعبة';
	@override String get correlationAnalysisTitle => 'ارتباط المزاج';
	@override String get correlationAnalysisSubtitle => 'الإنجاز عند المزاج المنخفض مقابل المرتفع';
	@override String get moodEnergyTrendTitle => 'المزاج والطاقة';
	@override String moodEnergyTrendSubtitle({required Object days}) => 'آخر ${days} يومًا';
	@override String get allTimeBest => 'الرقم القياسي';
	@override String get topPerformerLabel => 'الأفضل';
	@override String get currentStreakShort => 'الآن';
	@override String get recordLabel => 'الرقم القياسي';
	@override String get recordDetail => 'أطول سلسلة على الإطلاق';
	@override String get adherenceTitle => 'الالتزام بالجدول';
	@override String get adherenceSubtitle => 'من الأيام المقررة';
	@override String adherenceDetail({required Object done, required Object scheduled}) => '${done} من ${scheduled} يومًا مقررًا';
	@override String get atRiskTitle => 'في خطر';
	@override String get atRiskYes => 'نعم';
	@override String get atRiskNo => 'على المسار';
	@override String atRiskDetail({required Object days}) => '${days} يومًا منذ آخر مرة';
	@override String get daysUnit => 'ي';
	@override String get gapTitle => 'الفواصل';
	@override String get gapSubtitle => 'الأيام بين الإنجازات';
	@override String get gapAvg => 'المتوسط';
	@override String get gapLongest => 'الأطول';
	@override String get gapSince => 'منذ الأخير';
	@override String get habitBounceBackShort => 'التعافي';
	@override String get habitConsistencyDetail => 'درجة الانتظام';
	@override String habitPercentile({required Object pct}) => 'أفضل من ${pct}% من عاداتك';
	@override String get monthVsTitle => 'هذا الشهر مقابل السابق';
	@override String get monthVsSubtitle => 'الإنجاز شهرًا بشهر';
	@override String get thisMonthLabel => 'هذا الشهر';
	@override String get lastMonthLabel => 'الشهر الماضي';
	@override String get nextDayMoodTitle => 'تأثير مزاج اليوم التالي';
	@override String get nextDayMoodSubtitle => 'المزاج والطاقة في اليوم التالي';
	@override String get nextDayAfterDone => 'بعد فعلها';
	@override String get nextDayAfterMissed => 'بعد تفويتها';
	@override String nextDayMoodLift({required Object value}) => '${value} تحسّن في المزاج';
	@override String get streakHistoryTitle => 'سجل السلاسل';
	@override String get streakHistorySubtitle => 'كل سلسلة أيام متتالية';
	@override String streakHistoryDetail({required Object count, required Object longest}) => '${count} سلسلة · الأطول ${longest} يومًا';
}

// Path: habitsPage
class _Translations$habitsPage$ar extends Translations$habitsPage$en {
	_Translations$habitsPage$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get today => 'اليوم';
	@override String get subtitle => 'ابنِ بروتوكولك اليومي وراقب الاتساق عبر الزمن.';
	@override String get tabProtocol => 'البروتوكول';
	@override String get tabCalendar => 'التقويم';
	@override String get deleteHabitTitle => 'حذف العادة';
	@override String deleteHabitConfirm({required Object title}) => 'هل تريد إزالة "${title}" من البروتوكول؟';
	@override String get activeProtocol => 'البروتوكول النشط';
	@override String get completedToday => 'أُنجزت اليوم';
	@override String get dailyProtocol => 'البروتوكول اليومي';
	@override String get protocolSubtitle => 'نظرة أسبوعية وتذكيرات وإجراءات سريعة';
	@override String get colHabit => 'العادة';
	@override String get colStreak => 'السلسلة';
	@override String get colLast7Days => 'آخر 7 أيام';
	@override String get colReminder => 'تذكير';
	@override String streakDays({required Object n}) => '${n} أيام';
	@override String get prevPeriod => 'الفترة السابقة';
	@override String get nextPeriod => 'الفترة التالية';
	@override List<String> get weekdayAbbrevUpper => [
		'اثن',
		'ثلا',
		'أرب',
		'خمي',
		'جمع',
		'سبت',
		'أحد',
	];
	@override String get lifeView => 'عرض الحياة';
	@override String get lifeViewSubtitle => 'تمثّل كل خلية شهرًا من المسار حتى سن 85.';
	@override String get monthsLived => 'الأشهر المُعاشة';
	@override String get currentAge => 'العمر الحالي';
	@override String get monthsRemaining => 'الأشهر المتبقية';
	@override String dayDetail({required Object day, required Object month}) => 'تفاصيل ${day} ${month}';
	@override String get dayDetailSubtitle => 'حدّث حالة العادات لهذا اليوم.';
	@override String get editHabit => 'تعديل العادة';
	@override String get newHabit => 'عادة جديدة';
	@override String get optionalReminder => 'تذكير اختياري';
	@override String get reminderHint => 'مثال: 08:30';
	@override String get close => 'إغلاق';
	@override String get statusDone => 'مكتملة';
	@override String get statusSkipped => 'متخطاة';
	@override String get statusUnrecorded => 'غير مسجلة';
	@override String weekOf({required Object day, required Object month}) => 'أسبوع ${day} ${month}';
	@override String get lifeWeeks => 'أسابيع مسارك';
	@override String get catMindfulness => 'اليقظة الذهنية';
	@override String get editableHint => 'يمكن تعديل اليوم والأمس فقط.';
}

// Path: goalsPage
class _Translations$goalsPage$ar extends Translations$goalsPage$en {
	_Translations$goalsPage$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'الأهداف الكبرى';
	@override String get subtitle => 'التخطيط طويل المدى.';
	@override String get sampleGoal => 'هدف نموذجي';
	@override String get periodLifetime => 'أهداف الحياة';
	@override String get subtitleLifetime => 'أهداف مدى الحياة';
	@override String get subtitleAnnual => 'الأهداف السنوية';
	@override String get subtitleQuarterly => 'الأهداف الربع سنوية';
	@override String get subtitleMonthly => 'الأهداف الشهرية';
	@override String get subtitleWeekly => 'الأهداف الأسبوعية';
	@override String get statsTab => 'إحصاء';
	@override String get fullView => 'العرض الكامل';
	@override String get categoriesTitle => 'فئات الأهداف';
	@override String get defaultPill => 'افتراضية';
	@override String get editCategory => 'تعديل الفئة';
	@override String get archiveCategory => 'أرشفة الفئة';
	@override String get categoryCreateFailed => 'فشل إنشاء الفئة.';
	@override String get categoryArchiveFailed => 'فشلت أرشفة الفئة.';
	@override String get categoryEditFailed => 'فشل تعديل الفئة.';
	@override String get addCategory => 'إضافة فئة';
	@override String get back => 'رجوع';
	@override String get finish => 'إنهاء';
	@override String get next => 'التالي';
	@override String get categoriesTooltip => 'الفئات';
	@override String get rescheduleTooltip => 'إعادة الجدولة للفترة التالية';
	@override String get defaultCategory => 'افتراضي';
	@override String get emptyActive => 'لا يوجد هدف نشط في هذه الفترة.';
	@override String get emptyAdd => 'أضف أول هدف لهذه الفترة.';
	@override String get newGoal => 'هدف جديد';
	@override String get editGoal => 'تعديل الهدف';
	@override String get horizonLabel => 'الأفق';
	@override String get newCategory => 'فئة جديدة';
	@override String get nameLabel => 'الاسم';
	@override String weekPeriodLabel({required Object week, required Object month, required Object year}) => 'الأسبوع ${week}، ${month} ${year}';
	@override String get currentQuarter => 'الربع الحالي';
	@override String get currentMonth => 'الشهر الحالي';
}

// Path: goalsStats
class _Translations$goalsStats$ar extends Translations$goalsStats$en {
	_Translations$goalsStats$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get proRequired => 'ميزة Pro مطلوبة';
	@override String get active => 'نشطة';
	@override String get failed => 'فاشلة';
	@override String get complAbbr => 'مكت.';
	@override String get seasonality => 'الموسمية';
	@override String get interestEvolution => 'تطور الاهتمامات';
}

// Path: ai
class _Translations$ai$ar extends Translations$ai$en {
	_Translations$ai$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get coach => 'مدرّب AI';
	@override String get dailyHabits => 'العادات اليومية';
	@override String get macroGoals => 'الأهداف الكبرى';
	@override late final _Translations$ai$openRouter$ar openRouter = _Translations$ai$openRouter$ar._(_root);
	@override late final _Translations$ai$apiKey$ar apiKey = _Translations$ai$apiKey$ar._(_root);
	@override late final _Translations$ai$suggestions$ar suggestions = _Translations$ai$suggestions$ar._(_root);
	@override late final _Translations$ai$local$ar local = _Translations$ai$local$ar._(_root);
	@override late final _Translations$ai$standard$ar standard = _Translations$ai$standard$ar._(_root);
}

// Path: aiCoach
class _Translations$aiCoach$ar extends Translations$aiCoach$en {
	_Translations$aiCoach$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get greeting => 'مرحبًا! أنا Evolve AI Coach. أنا هنا لمساعدتك على تحسين بروتوكولك وتحقيق أهدافك. كيف يمكنني مساعدتك اليوم؟';
	@override String get systemPersona => 'أنت Evolve AI Coach، مساعد افتراضي للانضباط الشخصي.';
	@override String get habitsHeader => 'العادات النشطة:';
	@override String get noActiveHabits => 'لا توجد عادات نشطة.';
	@override String habitLine({required Object title, required Object done, required Object streak}) => '${title} (أُنجزت اليوم: ${done}، السلسلة: ${streak})';
	@override String get goalsHeader => 'الأهداف:';
	@override String get noActiveGoals => 'لا توجد أهداف طويلة المدى نشطة.';
	@override String goalLine({required Object title, required Object due}) => '${title} (الاستحقاق: ${due})';
	@override String get contextTitle => 'سياق الذكاء الاصطناعي';
	@override String get contextBody => 'اختر البيانات التي تريد مشاركتها مع مدرّب الذكاء الاصطناعي للحصول على نصائح مخصّصة.';
	@override String get shareHabitsDesc => 'يشارك عاداتك النشطة والسلاسل وحالة الإنجاز اليوم.';
	@override String get shareGoalsDesc => 'يشارك أهدافك النشطة طويلة المدى.';
	@override String get saveClose => 'حفظ وإغلاق';
	@override String get subtitle => 'حلّل الأنماط مع مدرّب سياقي مبني على بيانات مسارك.';
	@override String get contextButton => 'السياق';
	@override String get typing => 'يكتب AI Coach...';
	@override String get inputHint => 'اطلب النصيحة من مدرّبك...';
	@override String get defaultUserName => 'المستخدم';
	@override String userNameLine({required Object userName}) => '- الاسم: ${userName}';
	@override String activeGoalsCount({required Object count}) => '- الأهداف النشطة: ${count}';
	@override String completedGoalsCount({required Object count}) => '- الأهداف المكتملة: ${count}';
	@override String todayCompletion({required Object completed, required Object total}) => '- عادات اليوم: ${completed} مكتملة من أصل ${total}.';
	@override String get newChatTooltip => 'محادثة جديدة';
	@override String get clearConfirmTitle => 'بدء محادثة جديدة؟';
	@override String get clearConfirmBody => 'سيؤدي ذلك إلى مسح المحادثة الحالية — لا يتم حفظها.';
	@override String get clearConfirmCancel => 'إلغاء';
	@override String get clearConfirmAccept => 'محادثة جديدة';
	@override String get copyTooltip => 'نسخ';
	@override String get copiedToast => 'تم النسخ إلى الحافظة';
	@override String get linkOpenFailed => 'تعذّر فتح الرابط.';
}

// Path: settingsPage
class _Translations$settingsPage$ar extends Translations$settingsPage$en {
	_Translations$settingsPage$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get account => 'الحساب';
	@override String get notifications => 'الإشعارات';
	@override String get language => 'اللغة';
	@override String get timeFormat24h => 'تنسيق 24 ساعة';
	@override String get subscription => 'الاشتراك';
	@override String get proName => 'Evolve Pro';
	@override String get planMonthly => 'شهري';
	@override String get planAnnual => 'سنوي';
	@override String get restorePurchases => 'استعادة المشتريات';
	@override String get deletePrivateData => 'حذف البيانات الخاصة';
	@override String get importInProgress => 'جاري استيراد البيانات...';
	@override String get passwordsDontMatch => 'كلمتا المرور غير متطابقتين.';
	@override String get email => 'البريد الإلكتروني';
	@override String get cancel => 'إلغاء';
	@override String get confirm => 'تأكيد';
	@override String get save => 'حفظ';
	@override String get pageTitle => 'الإعدادات';
	@override String get pageSubtitle => 'أدر ملفك الشخصي وسلوك سطح المكتب والخصوصية وخطة Evolve.';
	@override String get profileLabel => 'الملف الشخصي';
	@override String get profileSubtitle => 'المعلومات الشخصية وحالة المزامنة';
	@override String get accountAndOnboarding => 'الحساب والإعداد الأولي';
	@override String get privateMode => 'الوضع الخاص';
	@override String get sessionUnavailable => 'الجلسة غير متاحة';
	@override String get dataRepository => 'مستودع البيانات';
	@override String get encryptedLocalDatabase => 'قاعدة بيانات محلية مشفرة';
	@override String get supabaseWithEncryptedCache => 'Supabase مع ذاكرة تخزين مؤقت مشفرة';
	@override String get personalInfo => 'المعلومات الشخصية';
	@override String get personalInfoDetail => 'الاسم واللقب والبريد الإلكتروني وتاريخ الميلاد';
	@override String get updateAvatar => 'تحديث الصورة الرمزية';
	@override String get updateAvatarDetail => 'اختر صورة محلية للملف الشخصي على سطح المكتب.';
	@override String get reviewInitialConsent => 'مراجعة الموافقة الأولية';
	@override String get reviewInitialConsentDetail => 'الشروط والخصوصية والإشعارات وتقارير الأعطال';
	@override String get signOut => 'تسجيل الخروج من حسابك';
	@override String get signOutDetailActive => 'إغلاق الجلسة على هذا الجهاز';
	@override String get availableWithActiveSession => 'متاح مع جلسة Supabase نشطة';
	@override String get goToLogin => 'الذهاب إلى تسجيل الدخول';
	@override String get goToLoginDetail => 'علّق الوضع الخاص وسجّل الدخول إلى Supabase.';
	@override String get appearanceTitle => 'المظهر والتطبيق';
	@override String get appearanceSubtitle => 'التفضيلات المحلية المكيَّفة لسطح المكتب';
	@override String get appearanceAndVisual => 'المظهر والعناصر المرئية';
	@override String get darkMode => 'الوضع الداكن';
	@override String get darkModeDetail => 'استخدم السمة الداكنة بالأبيض والأسود.';
	@override String get calendarExperienceLanguage => 'التقويم والتجربة واللغة';
	@override String get accentColor => 'لون التمييز';
	@override String get accentColorDetail => 'لوحة ألوان موسّعة مخصّصة لـ Evolve Pro.';
	@override String get defaultCalendarView => 'عرض التقويم الافتراضي';
	@override late final _Translations$settingsPage$calendarViewOptions$ar calendarViewOptions = _Translations$settingsPage$calendarViewOptions$ar._(_root);
	@override late final _Translations$settingsPage$languageOptions$ar languageOptions = _Translations$settingsPage$languageOptions$ar._(_root);
	@override String get timeFormat24hDetail => 'استخدم أوقاتاً مثل 20:30 بدلاً من 8:30 مساءً.';
	@override String get hapticFeedback => 'الاستجابة اللمسية';
	@override String get hapticFeedbackDetail => 'يحتفظ سطح المكتب بالتفضيل لكنه لا يولّد اهتزازات.';
	@override String get aiAndSystem => 'AI والنظام';
	@override String get aiSuggestions => 'اقتراحات AI';
	@override String get aiSuggestionsDetail => 'تحليل ذكي للعادات';
	@override String get focusMode => 'وضع التركيز';
	@override String get focusModeDetail => 'يوقف مؤقتًا جميع التذكيرات والإشعارات.';
	@override String get milestones => 'مراحل الإنجاز';
	@override String get milestonesDetail => 'احتفالات عند الوصول إلى مراحل الإنجاز الرئيسية.';
	@override String get deepWorkInsights => 'رؤى العمل العميق';
	@override String get deepWorkInsightsDetail => 'تحليل متقدم لجلسات تركيزك.';
	@override String get resetTutorial => 'إعادة تعيين البرنامج التعليمي';
	@override String get resetTutorialDetail => 'يعيد فتح الجولات التعريفية للوحة التحكم والأهداف.';
	@override String get notificationsSubtitle => 'تذكيرات تشغيلية من تطبيق سطح المكتب';
	@override String get operationalReminders => 'التذكيرات التشغيلية';
	@override String get habitReminders => 'تذكيرات العادات';
	@override String get habitRemindersDetail => 'يرسل الموجز الصباحي اليومي.';
	@override String get morningBriefTime => 'وقت الموجز الصباحي';
	@override String get eveningReview => 'المراجعة المسائية';
	@override String get eveningReviewDetail => 'يذكّرك بتلخيص يومك.';
	@override String get eveningReviewTime => 'وقت المراجعة المسائية';
	@override String get insightsAndReports => 'الرؤى والتقارير';
	@override String get aiInsights => 'رؤى AI';
	@override String get aiInsightsDetail => 'تحليلات ونصائح مخصصة من الذكاء الاصطناعي.';
	@override String get weeklyReports => 'تقارير أسبوعية';
	@override String get weeklyReportsDetail => 'ملخص أسبوعي لتقدمك.';
	@override String get requestNotificationPermissions => 'طلب أذونات الإشعارات';
	@override String get requestNotificationPermissionsDetail => 'يفتح النافذة الأصلية على المنصة المدعومة.';
	@override String get nativeDeliveryTitle => 'التسليم الأصلي حسب نظام التشغيل';
	@override String get privacyTitle => 'الخصوصية والأمان';
	@override String get privacySubtitle => 'حماية الوصول والموافقات وإدارة البيانات';
	@override String get accessProtection => 'حماية الوصول';
	@override String get biometricLock => 'القفل البيومتري';
	@override String get biometricLockDetail => 'متاح عبر المحول الأصلي على macOS وWindows؛ غير مدعوم على Linux.';
	@override String get changePassword => 'تغيير كلمة المرور';
	@override String get changePasswordDetail => 'تحديث بيانات الاعتماد عبر Supabase Auth.';
	@override String get dataAndConsents => 'البيانات والموافقات';
	@override String get sendCrashReports => 'إرسال تقارير الأعطال';
	@override String get sendCrashReportsDetail => 'موافقة منفصلة لـ Sentry.';
	@override String get exportData => 'تصدير البيانات';
	@override String get exportDataDetail => 'يشارك تصديراً كاملاً بصيغة JSON للبيانات المتاحة.';
	@override String get importData => 'استيراد البيانات';
	@override String get importDataDetail => 'يستعيد نسخة احتياطية (JSON أو ZIP) من Evolve.';
	@override String get systemPermissionsManagement => 'إدارة أذونات النظام';
	@override String get systemPermissionsManagementDetail => 'الإشعارات والتقويم والأمان.';
	@override String get deletePrivateDataDetail => 'يحذف نهائياً قاعدة البيانات المحلية المشفرة.';
	@override String get deleteAccountAndData => 'حذف الحساب والبيانات';
	@override String get deleteAccountAndDataDetail => 'عملية لا رجعة فيها محمية بتأكيد.';
	@override String get exportPrivateShareText => 'بياناتي الخاصة المصدّرة من Evolve';
	@override String get exportShareText => 'بياناتي المصدّرة من Evolve';
	@override String get exportDoneTitle => 'اكتمل التصدير';
	@override String get exportDoneClipboard => 'ملف JSON في الحافظة: لا يدعم Linux مشاركة الملفات.';
	@override String get exportDoneShare => 'تم إرسال ملف JSON إلى محدد المشاركة.';
	@override String get avatarGateTitle => 'الصورة الرمزية';
	@override String get avatarPickFailed => 'فشل اختيار الصورة.';
	@override String get confirmSignOutTitle => 'تأكيد تسجيل الخروج';
	@override String get confirmSignOutMessage => 'هل أنت متأكد أنك تريد تسجيل الخروج؟ ستحتاج إلى إعادة إدخال بيانات الاعتماد لتسجيل الدخول مجدداً.';
	@override String get gateProfile => 'الملف الشخصي';
	@override String get gateLogout => 'تسجيل الخروج';
	@override String get gateChangePassword => 'تغيير كلمة المرور';
	@override String get gateRequiresActiveSession => 'يتطلب جلسة Supabase نشطة.';
	@override String get biometricActivationCancelled => 'تم إلغاء التفعيل.';
	@override String get notificationPermissionsTitle => 'أذونات الإشعارات';
	@override String get notificationPermissionsGranted => 'الأذونات متاحة لهذا النظام.';
	@override String get notificationPermissionsDenied => 'لم يتم منح الإذن. يمكنك تغييره من إعدادات النظام.';
	@override String get systemPermissionsTitle => 'أذونات النظام';
	@override String get systemPermissionsOpenFailed => 'تعذّر فتح الإعدادات.';
	@override String get tutorialResetTitle => 'تمت إعادة تعيين البرامج التعليمية';
	@override String get tutorialResetMessage => 'ستظهر الأدلة مجدداً في الأقسام ذات الصلة.';
	@override String get accountDataManagementTitle => 'إدارة الحساب والبيانات';
	@override String get accountDataManagementContent => 'اختر ما إذا كنت تريد حذف البيانات مع إبقاء الحساب نشطاً أو حذف الحساب نهائياً.';
	@override String get resetDataAction => 'إعادة تعيين البيانات';
	@override String get deleteAccountAction => 'حذف الحساب';
	@override String get confirmResetDataTitle => 'تأكيد إعادة تعيين البيانات';
	@override String get confirmResetDataMessage => 'سيتم حذف العادات والأهداف والتفضيلات. سيبقى الحساب نشطاً. لا يمكن التراجع عن هذا الإجراء.';
	@override String get confirmDeleteAccountTitle => 'تأكيد حذف الحساب';
	@override String get confirmDeleteAccountMessage => 'سيتم حذف الحساب وجميع البيانات المرتبطة به نهائياً. هذا الإجراء لا رجعة فيه.';
	@override String get resetDataTitle => 'إعادة تعيين البيانات';
	@override String get resetDataSuccess => 'تم حذف البيانات بنجاح.';
	@override String get operationFailed => 'فشلت العملية.';
	@override String get deleteAccountGateTitle => 'حذف الحساب';
	@override String get accountDeleted => 'تم حذف الحساب.';
	@override String get importDataGateTitle => 'استيراد البيانات';
	@override String get importPrivateOnly => 'ميزة الاستيراد متاحة حالياً في الوضع الخاص (المحلي) فقط.';
	@override String get importSummaryTitle => 'ملخص الاستيراد';
	@override String importHabitsCount({required Object count}) => '${count} عادات';
	@override String importLogsCount({required Object count}) => '${count} تسجيلات دخول (سجل)';
	@override String importMacroGoalsCount({required Object count}) => '${count} أهداف كبرى';
	@override String importCategoriesCount({required Object count}) => '${count} فئات';
	@override String importMoodsCount({required Object count}) => '${count} سجلات المزاج';
	@override String get importReplaceTitle => 'استبدال البيانات الحالية';
	@override String get importReplaceSubtitle => 'يحذف نهائياً كل سجل موجود غير مُضمَّن في هذه النسخة الاحتياطية.';
	@override String get importMergeTitle => 'دمج مع البيانات الحالية';
	@override String get importMergeSubtitle => 'يدمج مع بياناتك مع الاحتفاظ بأحدث نسخة من كل عنصر.';
	@override String get importReplaceConfirmTitle => 'استبدال جميع البيانات؟';
	@override String importReplaceConfirmMessage({required Object count}) => 'سيؤدي هذا إلى حذف بياناتك الحالية نهائيًا (حوالي ${count} سجل) والاحتفاظ فقط بما في هذه النسخة الاحتياطية. لا يمكن التراجع عن ذلك.';
	@override String get importReplaceConfirmButton => 'حذف واستبدال';
	@override String get importConfirmButton => 'تأكيد الاستيراد';
	@override String get importSuccess => 'اكتمل الاستيراد بنجاح!';
	@override String importError({required Object error}) => 'خطأ أثناء الاستيراد: ${error}';
	@override String get importLockedTitle => 'إعادة تعيين قاعدة البيانات الخاصة المقفلة؟';
	@override String get importLockedMessage => 'لا يستطيع هذا الجهاز فتح قاعدة بياناتك الخاصة المحلية — مفتاح التشفير الخاص بها مفقود (يحدث هذا بعد الانتقال إلى جهاز Mac جديد أو تغيير توقيع التطبيق). لا يمكن استرداد البيانات المحلية الحالية، لكن يمكنك إعادة تعيينها واستيراد هذه النسخة الاحتياطية إلى قاعدة بيانات جديدة فارغة. لا يمكن التراجع عن هذا الإجراء.';
	@override String get importLockedResetButton => 'إعادة التعيين والاستيراد';
	@override String importPreviewSkipped({required Object count}) => '⚠ سيتم تجاوز ${count} سجلات غير صالحة';
	@override String get importCompletedTitle => 'اكتمل الاستيراد';
	@override String get importSummaryReplaced => 'تم استبدال بياناتك بالنسخة الاحتياطية. الملخص:';
	@override String get importSummaryMerged => 'تم دمج بياناتك مع النسخة الاحتياطية. الملخص:';
	@override String get importSummaryDone => 'رائع!';
	@override String get importEntityHabits => 'العادات';
	@override String get importEntityLogs => 'سجلات العادات';
	@override String get importEntityMacroGoals => 'الأهداف الكبيرة';
	@override String get importEntityCategories => 'الفئات';
	@override String get importEntityMoods => 'سجلات المزاج';
	@override String importRowReplace({required Object count, required Object label}) => '${count} ${label}';
	@override String importRowMerge({required Object label, required Object added, required Object updated, required Object unchanged}) => '${label}: ${added} مضافة، ${updated} محدّثة، ${unchanged} دون تغيير';
	@override String importRowSkipped({required Object count}) => '، ${count} تم تجاوزها';
	@override String get exportDoneSaved => 'تم حفظ ملف JSON في الموقع المحدد.';
	@override String get proTitle => 'Evolve Pro';
	@override String get proSubtitle => 'الخطة واستعادة المشتريات وإدارة الاشتراك';
	@override String get billingAppleTitle => 'الفوترة عبر Apple';
	@override String get commercialChannelRequired => 'الشراء غير متاح';
	@override String get billingAppleDetail => 'يتم شراء اشتراكك وإدارته باستخدام حساب Apple الخاص بك.';
	@override String get billingUnavailableDetail => 'الاشتراكات غير متاحة مؤقتاً. يرجى المحاولة لاحقاً.';
	@override String get billingPlatformUnsupported => 'عمليات الشراء داخل التطبيق غير متاحة على هذه المنصة.';
	@override String get bestValue => 'أفضل قيمة';
	@override String get priceUnavailable => 'السعر غير متاح';
	@override String get renewalDisclaimer => 'يتجدّد الاشتراك تلقائياً ما لم يتم إيقاف التجديد التلقائي في إعدادات حساب Apple قبل 24 ساعة على الأقل من نهاية الفترة.';
	@override String get privacyPolicy => 'سياسة الخصوصية';
	@override String get termsEula => 'شروط الاستخدام (EULA)';
	@override String get planManagement => 'إدارة الخطة';
	@override String get activateEvolvePro => 'تفعيل Evolve Pro';
	@override String get activateEvolveProActive => 'استحقاق Evolve Pro نشط.';
	@override String get activateEvolveProStart => 'اشترك باستخدام حساب Apple الخاص بك.';
	@override String get restorePurchasesDetail => 'يستعيد اشتراكاً سبق أن اشتريته.';
	@override String get manageSubscription => 'إدارة الاشتراك';
	@override String get manageSubscriptionDetail => 'يفتح إدارة الاشتراكات لحساب Apple.';
	@override String get notAuthenticated => 'غير مُصادق عليه';
	@override String get verified => 'موثّق';
	@override String get privateModeDataProtected => 'بياناتك محمية ومحفوظة على هذا الجهاز فقط.';
	@override String get profileFallback => 'الملف الشخصي';
	@override String get fullName => 'الاسم الكامل';
	@override String get dateOfBirth => 'تاريخ الميلاد';
	@override String get dateOfBirthHint => 'سنة-شهر-يوم';
	@override String get currentPassword => 'كلمة المرور الحالية';
	@override String get newPassword => 'كلمة المرور الجديدة';
	@override String get confirmNewPassword => 'تأكيد كلمة المرور الجديدة';
	@override String get updatePassword => 'تحديث كلمة المرور';
	@override String get enterCurrentPassword => 'أدخل كلمة المرور الحالية.';
	@override String get newPasswordMinLength => 'يجب أن تتكون كلمة المرور الجديدة من 8 أحرف على الأقل.';
	@override String get passwordUpdateFailed => 'فشل التحديث. تحقق من كلمة المرور الحالية.';
	@override String get sectionApplication => 'التطبيق';
	@override String get sectionPrivacy => 'الخصوصية';
	@override String get customColor => 'لون مخصص';
	@override String get applyAction => 'تطبيق';
	@override String useAccent({required Object hex}) => 'استخدم التمييز ${hex}';
	@override String get proUpsellTitle => 'الترقية إلى Evolve Pro';
	@override String get proUpsellSubtitle => 'افتح جميع الميزات وسرّع نموّك.';
	@override String get proWelcomeTitle => 'مرحباً بك في Evolve Pro!';
	@override String get proActiveMessage => 'اشتراكك نشط. مدرّب الذكاء الاصطناعي مُضمَّن — بلا حساب OpenRouter وبلا مفتاح API — إلى جانب إحصاءات الاتجاهات المتقدمة وكل أدوات النمو الشخصي في Evolve.';
	@override String get proStartJourney => 'ابدأ رحلتك';
	@override String get systemSection => 'النظام';
	@override String get appLogsTitle => 'سجلات التطبيق';
	@override String get appLogsDetail => 'عرض سجلّات التشخيص لهذه الجلسة';
}

// Path: consent
class _Translations$consent$ar extends Translations$consent$en {
	_Translations$consent$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get onboardingTitle => 'خصوصيتك تهمّنا';
	@override String get continueButton => 'متابعة';
}

// Path: notifications
class _Translations$notifications$ar extends Translations$notifications$en {
	_Translations$notifications$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get actionDone => 'تم';
	@override String get actionSkip => 'تخطّي';
	@override String get actionSnooze => 'تأجيل';
	@override String get morningBrief => 'موجز الصباح';
	@override String get eveningReview => 'المراجعة المسائية';
	@override String get morningBriefBody => 'حان وقت تشكيل يومك. راجع أهدافك.';
	@override String get eveningReviewBody => 'كيف كان يومك؟ تتبّع تقدّمك وحدّث سجلّك.';
}

// Path: privacy
class _Translations$privacy$ar extends Translations$privacy$en {
	_Translations$privacy$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get biometricAuthReason => 'تحقّق من هويتك لتفعيل حماية التطبيق.';
	@override String get biometricUnlockReason => 'افتح قفل التطبيق للمتابعة.';
}

// Path: consentPage
class _Translations$consentPage$ar extends Translations$consentPage$en {
	_Translations$consentPage$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get subtitle => 'قبل استخدام Evolve Desktop، أكّد الشروط وسياسة الخصوصية ومعالجة البيانات اللازمة للمزامنة.';
	@override String get acceptTerms => 'أوافق على الشروط وسياسة الخصوصية';
	@override String get termsSubtitle => 'أؤكّد أنني قرأت المستندات وأن عمري 14 عامًا على الأقل.';
	@override String get crashDiagnostics => 'تشخيص الأعطال';
	@override String get crashSubtitle => 'اسمح بإرسال تقارير تقنية مجهّلة الهوية.';
	@override String get openPrivacy => 'افتح سياسة الخصوصية';
	@override String get openTerms => 'شروط الخدمة';
	@override String get notificationsTitle => 'تفعيل الإشعارات';
	@override String get notificationsSubtitle => 'احصل على تذكيرات العادات والملخصات اليومية.';
	@override String get enableNotifications => 'تفعيل';
	@override String get notificationsEnabled => 'مُفعّلة';
}

// Path: notif
class _Translations$notif$ar extends Translations$notif$en {
	_Translations$notif$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get macScheduling => 'الجدولة اليومية مفعّلة على macOS.';
	@override String get linuxImmediate => 'يعرض Linux إشعارات فورية لكنه لا يدعم الجدولة.';
	@override String get openEvolve => 'افتح Evolve';
	@override String get windowsScheduling => 'يجدول Windows الحدث التالي عند كل تشغيل.';
	@override String get morningBody => 'راجع عادات اليوم واختر من أين تبدأ.';
	@override String get habitReminderBody => 'حان وقت إتمام عادتك.';
	@override String get eveningBody => 'اختم يومك وحدّث تقدّمك.';
}

// Path: biometricGate
class _Translations$biometricGate$ar extends Translations$biometricGate$en {
	_Translations$biometricGate$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get appLocked => 'التطبيق مقفل';
	@override String get unlockPrompt => 'افتح القفل بالمصادقة المحلية للمتابعة.';
	@override String get verifying => 'جارٍ التحقق...';
	@override String get unlock => 'فتح القفل';
	@override String get notSupportedLinux => 'القفل البيومتري غير مدعوم على Linux.';
	@override String get noLocalAuth => 'لا تتوفر طريقة مصادقة محلية.';
	@override String get authFailed => 'فشلت المصادقة.';
	@override String get authUnavailable => 'المصادقة المحلية غير متاحة.';
}

// Path: sync
class _Translations$sync$ar extends Translations$sync$en {
	_Translations$sync$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get syncFailed => 'فشلت المزامنة. تم الاحتفاظ بالبيانات المحلية.';
	@override String get editSavedLocally => 'تم حفظ التعديل محليًا. ستتم إعادة محاولة المزامنة.';
}

// Path: subscriptionCtrl
class _Translations$subscriptionCtrl$ar extends Translations$subscriptionCtrl$en {
	_Translations$subscriptionCtrl$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get purchaseComplete => 'اكتمل الشراء: جارٍ مزامنة الاشتراك.';
	@override String get purchaseIncomplete => 'لم يكتمل الشراء.';
	@override String get cantOpenApple => 'تعذّر فتح إدارة اشتراكات Apple.';
	@override String get macOnly => 'تتوفر عمليات الشراء داخل التطبيق في تطبيق macOS.';
	@override String get loadOffersFailed => 'تعذّر تحميل عروض RevenueCat.';
	@override String get proActivated => 'تم تفعيل Evolve Pro.';
	@override String get purchasesRestored => 'تمت استعادة المشتريات.';
	@override String get noActiveSub => 'لم يُعثر على اشتراك Pro نشط.';
	@override String get restoreFailed => 'فشلت استعادة المشتريات.';
	@override String get configKey => 'اضبط مفتاح RevenueCat العام لتطبيق سطح المكتب.';
	@override String get loginFirst => 'سجّل الدخول قبل إدارة Evolve Pro.';
}

// Path: authCtrl
class _Translations$authCtrl$ar extends Translations$authCtrl$en {
	_Translations$authCtrl$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get appleNoToken => 'لم يُرجع Apple رمز هوية.';
	@override String get appleAuthFailed => 'فشلت مصادقة Apple.';
	@override String get cantOpenBrowser => 'تعذّر فتح متصفح النظام.';
	@override String accessNotCompleted({required Object provider}) => 'لم يكتمل تسجيل الدخول عبر ${provider}.';
	@override String providerAuthFailed({required Object provider}) => 'فشلت مصادقة ${provider}.';
	@override String get operationFailed => 'فشلت العملية. أعد المحاولة بعد قليل.';
}

// Path: proModal
class _Translations$proModal$ar extends Translations$proModal$en {
	_Translations$proModal$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'افتح Evolve Pro';
	@override String get subtitle => 'ارتقِ بنظام عاداتك إلى المستوى التالي';
	@override String get featuresHeader => 'ما الذي تتضمّنه خطة PRO';
	@override String get aiCoachTitle => 'AI Coach بلا إعداد';
	@override String get aiCoachDesc => 'نشغّله نحن بمفتاحنا: لا مفتاح API تبحث عنه، ولا حساب ثانٍ. تفضّل حساب OpenRouter الخاص بك؟ هذا مجاني أيضًا.';
	@override String get statsTitle => 'إحصاءات خاصة بكل عادة';
	@override String get statsDesc => 'رؤى أساسية لتعزيز إنتاجيتك.';
	@override String get metricsTitle => 'مقاييس متقدّمة للأهداف';
	@override String get metricsDesc => 'اعرض رسوماً بيانية مفصّلة وإحصاءات أداء معمّقة لكل سنة.';
	@override String get unlimitedTitle => 'عادات غير محدودة';
	@override String get unlimitedDesc => 'أنشئ وتتبّع كل العادات التي تريدها دون أي حدود.';
	@override String get maybeLater => 'ربما لاحقاً';
	@override String get viewPlans => 'عرض خطط Pro';
}

// Path: appLogs
class _Translations$appLogs$ar extends Translations$appLogs$en {
	_Translations$appLogs$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'سجلات التطبيق';
	@override String get copiedToClipboard => 'تم نسخ السجلات إلى الحافظة';
	@override String get clearLogsTitle => 'مسح السجلات';
	@override String get clearLogsConfirm => 'هل أنت متأكد من رغبتك في مسح جميع إدخالات السجل؟ لا يمكن التراجع عن هذا الإجراء.';
	@override String get clearLogsAction => 'مسح الكل';
	@override String get copyAll => 'نسخ جميع السجلات';
	@override String get searchPlaceholder => 'البحث في السجلات...';
	@override String get filterAll => 'الكل';
	@override String get filterErrors => 'أخطاء';
	@override String get filterWarnings => 'تحذيرات';
	@override String get filterInfo => 'معلومات';
	@override String get emptyTitle => 'لا توجد سجلات';
	@override String get emptySubtitle => 'ستظهر السجلات هنا أثناء تشغيل التطبيق';
	@override String get stackTraceAvailable => 'انقر لعرض تتبع المكدس';
	@override String get detailMessage => 'الرسالة';
	@override String get detailError => 'الخطأ';
	@override String get detailExtras => 'سياق إضافي';
	@override String get detailStackTrace => 'تتبع المكدس';
	@override String get shareLogs => 'مشاركة ملف السجلات';
	@override String get exportDone => 'تم تصدير السجلات';
}

// Path: coachSettings
class _Translations$coachSettings$ar extends Translations$coachSettings$en {
	_Translations$coachSettings$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'محرّك مدرّب الذكاء الاصطناعي';
	@override String get subtitle => 'اختر مكان تشغيل المدرّب. تُبقي النماذج المحلية كل رسالة على هذا الجهاز.';
	@override String get backendCloud => 'OpenRouter الخاص بك';
	@override String get backendLocal => 'محلي · خاص';
	@override String get cloudDesc => 'اربط حساب OpenRouter الخاص بك وادفع للمزوّد مباشرةً. مجاني — لا يتطلب اشتراكًا. يُرسَل السياق الذي تشاركه إلى المزوّد.';
	@override String get localDesc => 'نموذجك الخاص عبر Ollama أو LM Studio أو أي خادم متوافق مع OpenAI. لا شيء يغادر هذا الجهاز.';
	@override String get presetLabel => 'الخادم';
	@override String get presetOllama => 'Ollama';
	@override String get presetLmStudio => 'LM Studio';
	@override String get presetCustom => 'مخصّص…';
	@override String get baseUrlLabel => 'عنوان URL الأساسي';
	@override String get baseUrlHint => 'http://localhost:11434/v1';
	@override String get modelLabel => 'النموذج';
	@override String get modelHint => 'مثال: llama3.1:8b';
	@override String get refreshModels => 'تحديث النماذج';
	@override String get discovering => 'جارٍ البحث عن النماذج…';
	@override String get noModelsFound => 'لم يُعثَر على نماذج — اكتب معرّف نموذج يدويًا أدناه.';
	@override String get manualModelLabel => 'معرّف النموذج';
	@override String get manualModelAdd => 'استخدام هذا النموذج';
	@override String get statusConnected => 'متّصل';
	@override String get statusOffline => 'الخادم غير متّصل';
	@override String get statusChecking => 'جارٍ التحقّق…';
	@override String get remoteBadge => 'بعيد';
	@override String get remoteWarning => 'هذا الـ endpoint ليس عنوانًا محليًا — ستغادر الرسائل هذا الجهاز.';
	@override String get advanced => 'متقدّم';
	@override String get systemPromptLabel => 'موجّه النظام';
	@override String get systemPromptHint => 'استبدل شخصية المدرّب (اتركه فارغًا للوضع الافتراضي)';
	@override String get systemPromptReset => 'إعادة تعيين';
	@override String get temperatureLabel => 'درجة الحرارة';
	@override String get save => 'تم';
	@override String get detectedTitle => 'تم اكتشاف نموذج محلي';
	@override String get detectedBody => 'يعمل خادم ذكاء اصطناعي محلي على هذا الـ Mac. هل تريد تشغيل المدرّب بخصوصية كاملة؟';
	@override String get detectedAction => 'استخدام المحلي';
	@override String get detectedDismiss => 'ليس الآن';
	@override String activeCloud({required Object model}) => 'السحابة · ${model}';
	@override String activeLocal({required Object model}) => 'محلي · ${model}';
	@override String get activeLocalNoModel => 'محلي · اختر نموذجًا';
	@override String get cloudSection => 'OpenRouter الخاص بك';
	@override String get serverSettings => 'إعدادات الخادم…';
	@override String get settingsSectionLabel => 'مدرّب الذكاء الاصطناعي';
	@override String get settingsTitle => 'مدرّب الذكاء الاصطناعي';
	@override String get settingsSubtitle => 'اختر المحرّك الذي يشغّل مدرّبك ووجّهه إلى خادم محلي لخصوصية كاملة.';
	@override String get settingsRowStatus => 'المحرّك النشط';
	@override String get settingsRowConfigure => 'المحرّك والخادم المحلي';
	@override String get cloudKeyMissing => 'لا يوجد مفتاح بعد — لن يردّ هذا المحرّك. اربط حساب OpenRouter الخاص بك أدناه، أو انتقل إلى Evolve AI، أو استخدم خادمًا محليًا.';
	@override String get temperatureLower => 'خفض درجة الحرارة';
	@override String get temperatureRaise => 'رفع درجة الحرارة';
	@override String get sendMessage => 'إرسال';
	@override String get stopResponse => 'إيقاف';
	@override String get startOllama => 'تشغيل Ollama';
	@override String get getOllama => 'الحصول على Ollama';
	@override String get startingOllama => 'جارٍ تشغيل Ollama…';
	@override String get ollamaOfflineTitle => 'Ollama غير مُشغّل';
	@override String get ollamaOfflineBody => 'شغّل خادمك المحلي للدردشة بخصوصية — دون الحاجة إلى الطرفية.';
	@override String get ollamaNotInstalledTitle => 'Ollama غير مُثبَّت';
	@override String get ollamaNotInstalledBody => 'ثبّت تطبيق Ollama المجاني ثم اضغط تشغيل.';
	@override String get ollamaStartTimeout => 'يستغرق وقتًا أطول من المتوقع — تحقّق من أيقونة Ollama في شريط القوائم (قد يتطلب التشغيل الأول موافقة).';
	@override String get ollamaStartingBody => 'قد يستغرق ذلك بضع ثوانٍ…';
	@override String get ollamaStartFailed => 'تعذّر تشغيل Ollama — جرّب فتحه من مجلد التطبيقات.';
	@override String get ollamaDownloadFailed => 'تعذّر فتح المتصفح — تفضّل بزيارة ollama.com/download';
	@override String get backendStandard => 'Evolve AI';
	@override String get standardDesc => 'مُضمَّن في Evolve Pro. نشغّل Gemini 2.5 Flash نيابةً عنك — بلا مفاتيح وبلا إعداد. يُرسَل السياق الذي تشاركه إلى المزوّد.';
	@override String activeStandard({required Object model}) => 'Evolve AI · ${model}';
	@override String get standardSection => 'Evolve AI';
	@override String get standardStatusReady => 'مُضمَّن في Pro';
	@override String get standardStatusNeedsPro => 'يتطلب Pro';
	@override String get standardStatusNeedsSignIn => 'يلزم تسجيل الدخول';
	@override String get standardStatusUnavailable => 'غير متاح';
	@override String get standardNeedsProNote => 'Evolve AI جزء من Evolve Pro. اشترك لاستخدامه — أو اربط حساب OpenRouter الخاص بك، وهو مجاني.';
	@override String get standardNeedsSignInNote => 'سجّل الدخول لاستخدام Evolve AI. اشتراكك يفتحه على كل أجهزتك.';
	@override String get standardUnavailableNote => 'Evolve AI غير متاح في هذه النسخة. اربط حساب OpenRouter الخاص بك أو استخدم نموذجًا محليًا.';
	@override String get standardPrivateNote => 'يحتاج Evolve AI إلى حساب Evolve، والوضع الخاص لا يحتفظ بحساب. اربط حساب OpenRouter الخاص بك أو استخدم نموذجًا محليًا — كلاهما يعمل هنا.';
}

// Path: tour
class _Translations$tour$ar extends Translations$tour$en {
	_Translations$tour$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get back => 'رجوع';
	@override String get next => 'التالي';
	@override String get continueLabel => 'متابعة';
	@override String get finish => 'إنهاء';
	@override String get welcomeTitle => 'مرحبًا بك في Evolve';
	@override String get welcomeBody => 'لنقم بجولة سريعة في مساحة عملك — من نظرتك اليومية العامة وصولًا إلى مدرّب الذكاء الاصطناعي. لن يستغرق الأمر سوى لحظات.';
	@override String get welcomeStart => 'ابدأ الجولة';
	@override String get doneTitle => 'كل شيء جاهز';
	@override String get doneBody => 'هذا كل التطبيق. ابدأ من أي مكان عبر الشريط الجانبي — ويمكنك إعادة الجولة في أي وقت من الإعدادات.';
	@override String get doneButton => 'ابدأ الآن';
	@override String get overviewOrientationTitle => 'نظرتك العامة';
	@override String get overviewOrientationDesc => 'هذه قاعدتك اليومية — لمحة عن يومك بمجرد فتح Evolve.';
	@override String get overviewCheckinTitle => 'تسجيل الوصول اليومي';
	@override String get overviewCheckinDesc => 'سجّل كيف يسير يومك. مع الوقت يكشف كيف ترتبط حالتك المزاجية بعاداتك وأهدافك.';
	@override String get overviewHabitsTitle => 'عادات اليوم';
	@override String get overviewHabitsDesc => 'العادات التي خططت لها اليوم موجودة هنا — علّمها عند إنجازها.';
	@override String get overviewGoalsTitle => 'الأهداف قيد التركيز';
	@override String get overviewGoalsDesc => 'تظهر هنا الأهداف التي تركّز عليها حتى لا يفوتك شيء.';
	@override String get habitsOrientationTitle => 'صفحة العادات';
	@override String get habitsOrientationDesc => 'هنا تبني بروتوكولك اليومي وتتابع مدى انتظامك.';
	@override String get habitsAddTitle => 'أضف عادة';
	@override String get habitsAddDesc => 'أنشئ عادة جديدة هنا — بالاسم والفئة واللون وتذكير اختياري.';
	@override String get habitsCheckoffTitle => 'علّمها كمنجزة';
	@override String get habitsCheckoffDesc => 'علّم هذا المربع لإكمال عادة اليوم. هذا كل ما يلزم للحفاظ على السلسلة.';
	@override String get habitsStreakTitle => 'السلاسل والسجل';
	@override String get habitsStreakDesc => 'شاهد سلسلتك تنمو وألقِ نظرة على آخر سبعة أيام دفعة واحدة.';
	@override String get habitsCalendarTitle => 'عرض التقويم';
	@override String get habitsCalendarDesc => 'انتقل إلى التقويم لمراجعة سجلك حسب الأسبوع أو الشهر أو السنة — أو حياتك كلها.';
	@override String get insightsOrientationTitle => 'إحصاءاتك';
	@override String get insightsOrientationDesc => 'تابع اتجاه عاداتك وأهدافك عبر الزمن وأين تنحرف.';
	@override String get insightsFilterTitle => 'التصفية حسب العادة';
	@override String get insightsFilterDesc => 'ركّز الإحصاءات على عادة واحدة أو أبقِ النظرة الشاملة.';
	@override String get insightsTabsTitle => 'أقسام الإحصاءات';
	@override String get insightsTabsDesc => 'بدّل بين الأقسام للاتجاهات والتنبيهات وتقدّم العادات ومزاجك.';
	@override String get goalsOrientationTitle => 'صفحة الأهداف';
	@override String get goalsOrientationDesc => 'حدّد وتابع أهدافك الأكبر — ما تبني نحوه عاداتك اليومية.';
	@override String get goalsPlanTitle => 'نوع التخطيط';
	@override String get goalsPlanDesc => 'اختر كيف تخطّط — يوميًا أو أسبوعيًا أو لمدى أطول — بما يناسب طريقة تفكيرك في أهدافك.';
	@override String get goalsAddTitle => 'أضف هدفًا';
	@override String get goalsAddDesc => 'أنشئ هدفًا جديدًا هنا وامنحه غاية تسعى إليها.';
	@override String get goalsCheckTitle => 'إنجاز أو إخفاق';
	@override String get goalsCheckDesc => 'علّم الهدف كمنجز أو فائت. كل نتيجة تغذّي أداءك مع الوقت.';
	@override String get goalsStatsTitle => 'الأداء';
	@override String get goalsStatsDesc => 'فعّل إحصاءات الأداء لترى مستواك مقابل أهدافك.';
	@override String get coachOrientationTitle => 'مدرّبك بالذكاء الاصطناعي';
	@override String get coachOrientationDesc => 'إرشاد مخصّص مبني على عاداتك وأهدافك الحقيقية — هنا على جهاز Mac الخاص بك.';
	@override String get coachModelTitle => 'اختر المحرّك';
	@override String get coachModelDesc => 'اختر نموذج الذكاء الاصطناعي — سحابتنا أو نموذج محلي يعمل بخصوصية على جهاز Mac. إعدادات الخادم هنا أيضًا.';
	@override String get coachContextTitle => 'ما يراه المدرّب';
	@override String get coachContextDesc => 'تحكّم في ما إذا كان بإمكان المدرّب استخدام عاداتك وأهدافك لتخصيص نصائحه.';
	@override String get coachSuggestionsTitle => 'مقترحات للبدء';
	@override String get coachSuggestionsDesc => 'لا تعرف من أين تبدأ؟ اضغط أحد هذه الاقتراحات للانطلاق.';
	@override String get coachInputTitle => 'اسأل أي شيء';
	@override String get coachInputDesc => 'اكتب سؤالك هنا واضغط إرسال. بهذا تنتهي الجولة — استمتع بـ Evolve!';
}

// Path: palette
class _Translations$palette$ar extends Translations$palette$en {
	_Translations$palette$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get searchHint => 'ابحث عن الأهداف والعادات والإجراءات…';
	@override String get groupSuggested => 'مقترحات';
	@override String get groupThisWeek => 'هذا الأسبوع';
	@override String get groupGoals => 'الأهداف';
	@override String get groupHabits => 'العادات';
	@override String get groupActions => 'إجراءات';
	@override String get groupSections => 'الانتقال إلى';
	@override String get goToThisWeek => 'الانتقال إلى هذا الأسبوع';
	@override String get createGoalBlank => 'إنشاء هدف';
	@override String createGoal({required Object title}) => 'إنشاء هدف «${title}»';
	@override String createHabit({required Object title}) => 'إنشاء عادة «${title}»';
	@override String goToPeriod({required Object period}) => 'الانتقال إلى ${period}';
	@override String get switchToDark => 'التبديل إلى المظهر الداكن';
	@override String get switchToLight => 'التبديل إلى المظهر الفاتح';
	@override String get manageCategories => 'إدارة فئات الأهداف';
	@override String get replayTour => 'إعادة الجولة التعريفية';
	@override String noResults({required Object query}) => 'لا نتائج لـ «${query}»';
	@override String get rowOpen => 'فتح';
	@override String get rowComplete => 'وضع علامة مكتمل';
	@override String get rowReschedule => 'إعادة الجدولة للفترة التالية';
	@override String get deleteGoalTitle => 'حذف الهدف؟';
	@override String deleteGoalMessage({required Object title}) => 'سيتم حذف «${title}» نهائيًا.';
	@override String get deleteHabitTitle => 'حذف العادة؟';
	@override String deleteHabitMessage({required Object title}) => 'سيتم حذف «${title}» نهائيًا.';
	@override String get footerNavigate => 'تنقل';
	@override String get footerOpen => 'فتح';
	@override String get footerMenu => 'قائمة';
	@override String get footerClose => 'إغلاق';
}

// Path: common.actions
class _Translations$common$actions$ar extends Translations$common$actions$en {
	_Translations$common$actions$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get cancel => 'إلغاء';
	@override String get save => 'حفظ';
	@override String get delete => 'حذف';
	@override String get edit => 'تعديل';
	@override String get pick => 'اختيار';
	@override String get gotIt => 'حسناً';
}

// Path: common.calendarView
class _Translations$common$calendarView$ar extends Translations$common$calendarView$en {
	_Translations$common$calendarView$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get year => 'سنة';
	@override String get month => 'شهر';
	@override String get week => 'أسبوع';
	@override String get life => 'الحياة';
}

// Path: common.status
class _Translations$common$status$ar extends Translations$common$status$en {
	_Translations$common$status$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get error => 'خطأ';
}

// Path: macroGoals.types
class _Translations$macroGoals$types$ar extends Translations$macroGoals$types$en {
	_Translations$macroGoals$types$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get annual => 'سنوي';
	@override String get quarterly => 'ربع سنوي';
	@override String get monthly => 'شهري';
	@override String get weekly => 'أسبوعي';
	@override String get lifetime => 'مدى الحياة';
}

// Path: ai.openRouter
class _Translations$ai$openRouter$ar extends Translations$ai$openRouter$en {
	_Translations$ai$openRouter$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get apiKeyMissingShort => '⚠️ يحتاج مدرّب AI إلى مفتاح OpenRouter API خاص بك. أضِفه من الإعدادات لبدء المحادثة.';
	@override String get apiKeyInvalid => '⚠️ رفض OpenRouter مفتاح API هذا. تحقّق منه في الإعدادات أو أنشئ مفتاحًا جديدًا على openrouter.ai/keys.';
	@override String get defaultSystemPrompt => 'أنت "مدرّب الانضباط"، مساعد افتراضي يركّز على مساعدة المستخدم على الالتزام بالانضباط وتحقيق أهدافه وبناء عادات صحية. كن محفّزاً لكن واقعياً ومباشراً وعملياً. استخدم نبرة احترافية وودودة.';
	@override String communicationError({required Object code}) => '❌ خطأ في الاتصال بالـ AI. (الرمز: ${code})';
	@override String get connectionError => '❌ خطأ في الاتصال. تأكّد من اتصالك بالإنترنت وحاول مرة أخرى.';
	@override String get connectionErrorShort => '❌ خطأ في الاتصال.';
	@override String get connectionCheckTimeout => '❌ خطأ: استغرق فحص الاتصال وقتاً طويلاً.';
	@override String get contextTooLong => '⚠️ أصبحت هذه المحادثة أطول من اللازم بالنسبة للنموذج. ابدأ محادثة جديدة من أعلى الصفحة للمتابعة.';
	@override String get noInternet => '❌ خطأ: لا يوجد اتصال بالإنترنت. تحقّق من شبكتك.';
	@override String get serverTimeout => '❌ خطأ: يستغرق الخادم وقتاً طويلاً للرد. حاول مرة أخرى.';
	@override String apiError({required Object code}) => '❌ خطأ في API: ${code} (راجع Sentry للتفاصيل)';
}

// Path: ai.apiKey
class _Translations$ai$apiKey$ar extends Translations$ai$apiKey$en {
	_Translations$ai$apiKey$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get rowTitle => 'حساب OpenRouter الخاص بك';
	@override String get description => 'تفضّل تشغيل الكوتش على حسابك؟ اربط مفتاح OpenRouter وستدفع للمزوّد مباشرةً — بلا اشتراك في Evolve. أنشئ مفتاحًا على openrouter.ai/keys: يُحفَظ في سلسلة مفاتيح هذا الجهاز ولا يُرسَل إلا إلى OpenRouter.';
	@override String get fieldLabel => 'مفتاح API';
	@override String get hint => 'sk-or-v1-…';
	@override String get save => 'حفظ المفتاح';
	@override String get saved => 'تم حفظ مفتاح API';
	@override String get remove => 'إزالة المفتاح';
	@override String get removed => 'تمت إزالة مفتاح API';
	@override String get removeConfirmTitle => 'إزالة مفتاح API؟';
	@override String get removeConfirmBody => 'سيتوقف هذا المحرّك عن الردّ حتى تربط حسابًا مرة أخرى. لا يتأثر Evolve AI ولا النماذج المحلية.';
	@override String get statusSet => 'محفوظ';
	@override String get statusMissing => 'غير مُعيَّن';
	@override String get saveFailed => 'تعذّر حفظ المفتاح في سلسلة المفاتيح. حاول مرة أخرى.';
	@override String get setupTitle => 'اربط حساب OpenRouter الخاص بك';
	@override String get setupBody => 'يعمل هذا المحرّك عبر حساب OpenRouter الخاص بك. اربطه لبدء المحادثة — أو انتقل إلى Evolve AI المُضمَّن في Pro.';
	@override String get setupAction => 'ربط الحساب';
}

// Path: ai.suggestions
class _Translations$ai$suggestions$ar extends Translations$ai$suggestions$en {
	_Translations$ai$suggestions$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get morningBoost => '🔥 امنحني دفعة للبدء!';
	@override String get avoidDistractions => '🧠 كيف أتجنّب المشتّتات؟';
	@override String get lowEnergy => '⚡ طاقتي تتراجع. ماذا أفعل؟';
	@override String get stayFocused => '💪 امنحني نصيحة واحدة للبقاء مركّزاً';
	@override String get prepareTomorrow => '🛌 كيف أستعد ليوم غدٍ منتج؟';
	@override String get disciplineReflection => '📝 تأمّل في انضباط اليوم';
	@override String get analyzeActiveGoals => '🎯 حلّل أهدافي النشطة';
	@override String get planMacroGoals => '🗺️ كيف أخطّط لأهدافي الكبرى؟';
	@override String get goalObstacles => '🛑 ما العقبات التي تعيق أهدافي؟';
	@override String get reachMilestones => '📈 امنحني نصيحة واحدة لبلوغ مراحل إنجازي';
	@override String get consistencyStatus => '📈 كيف هو مستوى مواظبتي؟';
	@override String get weeklyStats => '📊 إحصاءاتي الأسبوعية';
	@override String get planDay => '🌅 خطّط ليومي';
	@override String get raiseBar => '🚀 كيف أرفع مستوى طموحي؟';
	@override String get recoverProcrastination => '🤕 كيف أتعافى بعد التسويف؟';
	@override String get connectHabitsGoals => '🔗 كيف أربط العادات بالأهداف؟';
	@override String get reviewGoalsHabits => '📊 راجع أهدافي وعاداتي';
	@override String get disciplineAdvice => '🔥 نصيحة عن الانضباط';
	@override String get createNewHabit => '💡 كيف أنشئ عادة جديدة؟';
}

// Path: ai.local
class _Translations$ai$local$ar extends Translations$ai$local$en {
	_Translations$ai$local$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String notReachable({required Object url}) => '❌ تعذّر الوصول إلى خادم الذكاء الاصطناعي المحلي على ${url}. تأكّد من تشغيل Ollama أو LM Studio.';
	@override String get modelMissing => '⚠️ اختر نموذجًا محليًا أولًا — افتح مُحدِّد النماذج في الأعلى.';
	@override String requestFailed({required Object code}) => '❌ خطأ في النموذج المحلي (الرمز: ${code}).';
	@override String get streamError => '❌ فشل الاتصال بالنموذج المحلي.';
	@override String get timeout => '❌ النموذج المحلي يستغرق وقتًا طويلًا — قد يكون ما زال قيد التحميل. حاول مرة أخرى.';
	@override String get modelNotFound => '❌ هذا النموذج غير متوفر على الخادم. افتح مُحدِّد النماذج لاختيار نموذج أو تحميله.';
}

// Path: ai.standard
class _Translations$ai$standard$ar extends Translations$ai$standard$en {
	_Translations$ai$standard$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get sessionExpired => '⚠️ انتهت صلاحية جلستك. سجّل الدخول مجددًا لمتابعة استخدام Evolve AI.';
	@override String get needsPro => '⚠️ Evolve AI جزء من Evolve Pro. اشترك من الإعدادات — أو بدّل المحرّك إلى حساب OpenRouter الخاص بك، وهو مجاني.';
	@override String get rateLimited => '⚠️ لقد بلغت حد الاستخدام العادل لـ Evolve AI في الوقت الحالي. حاول لاحقًا أو بدّل المحرّك إلى حساب OpenRouter الخاص بك.';
	@override String get unavailable => '❌ Evolve AI غير متاح الآن. المشكلة من جانبنا — حاول مرة أخرى بعد قليل.';
}

// Path: settingsPage.calendarViewOptions
class _Translations$settingsPage$calendarViewOptions$ar extends Translations$settingsPage$calendarViewOptions$en {
	_Translations$settingsPage$calendarViewOptions$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get month => 'شهر';
	@override String get week => 'أسبوع';
	@override String get year => 'سنة';
	@override String get life => 'الحياة';
}

// Path: settingsPage.languageOptions
class _Translations$settingsPage$languageOptions$ar extends Translations$settingsPage$languageOptions$en {
	_Translations$settingsPage$languageOptions$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get system => 'النظام';
	@override String get italian => 'الإيطالية';
	@override String get english => 'الإنجليزية';
	@override String get spanish => 'الإسبانية';
	@override String get german => 'الألمانية';
	@override String get arabic => 'العربية';
}

/// The flat map containing all translations for locale <ar>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsAr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'auth.continuePrivately' => 'المتابعة في الوضع الخاص على هذا الـ Mac',
			'auth.signIn' => 'تسجيل الدخول',
			'auth.register' => 'التسجيل',
			'auth.or' => 'أو',
			'auth.password' => 'كلمة المرور',
			'auth.forgotPassword' => 'هل نسيت كلمة المرور؟',
			'auth.haveAccount' => 'هل لديك حساب بالفعل؟',
			'auth.noAccount' => 'ليس لديك حساب؟',
			'auth.continueWithApple' => 'المتابعة باستخدام Apple',
			'auth.continueWithGoogle' => 'المتابعة باستخدام Google',
			'auth.readPrivacyPolicy' => 'اقرأ سياسة الخصوصية',
			'auth.nameLabel' => 'الاسم الأول',
			'auth.invalidEmail' => 'أدخل بريداً إلكترونياً صالحاً',
			'auth.confirmEmail' => 'تحقّق من بريدك الإلكتروني لتأكيد تسجيلك.',
			'auth.resetSent' => 'تم إرسال البريد الإلكتروني. تحقّق من صندوق الوارد.',
			'auth.signInTitle' => 'تسجيل الدخول إلى Evolve',
			'auth.signUpTitle' => 'أنشئ حسابك',
			'auth.resetTitle' => 'استعادة كلمة المرور',
			'auth.emailLabel' => 'البريد الإلكتروني',
			'auth.passwordMin8' => 'استخدم 8 أحرف على الأقل.',
			'auth.sendResetLink' => 'إرسال رابط الاستعادة',
			'privateAi.consentTitle' => 'السماح بالإرسال إلى الذكاء الاصطناعي',
			'privateAi.consentBody' => 'في الوضع الخاص تبقى بياناتك على جهازك. لاستخدام مدرب الذكاء الاصطناعي، تُرسَل العادات والأهداف التي تختار مشاركتها إلى مزوّد ذكاء اصطناعي خارجي (OpenRouter). هل تريد المتابعة؟',
			'privateAi.cancel' => 'إلغاء',
			'privateAi.accept' => 'أوافق',
			'privateData.deleteTitle' => 'حذف البيانات الخاصة',
			'privateData.deleteMessage' => 'هل أنت متأكد أنك تريد حذف كامل قاعدة البيانات المحلية المشفّرة؟ هذا الإجراء لا يمكن التراجع عنه ولا يمكن استرجاع البيانات.',
			'privateData.deleteSuccess' => 'تم حذف البيانات الخاصة.',
			'privateData.deleteFailed' => 'فشلت العملية.',
			'privateData.exportDoneTitle' => 'اكتمل التصدير',
			'privateData.exportDoneClipboard' => 'ملف JSON في الحافظة: لا يدعم لينكس مشاركة الملفات.',
			'privateData.exportDoneShare' => 'تم إرسال ملف JSON إلى أداة المشاركة.',
			'icloudSync.title' => 'مزامنة iCloud',
			'icloudSync.enableTitle' => 'تفعيل مزامنة iCloud',
			'icloudSync.syncNow' => 'مزامنة الآن',
			'icloudSync.disclosureTitle' => 'تشفير تام بين الطرفين',
			'icloudSync.disclosureBody' => 'تتم مزامنة بياناتك الخاصة فقط عبر حساب iCloud الخاص بك، بتشفير تام بين الطرفين — وليس عبر خوادمنا أبدًا. يُحفظ مفتاح التشفير في سلسلة مفاتيح iCloud الخاصة بك؛ إذا أوقفت سلسلة مفاتيح iCloud، فلن يمكن استرداد البيانات المتزامنة.',
			'icloudSync.disclosureAccept' => 'تفعيل',
			'icloudSync.statusIdle' => 'مُحدَّث',
			'icloudSync.statusSyncing' => 'جارٍ المزامنة…',
			'icloudSync.statusOff' => 'المزامنة متوقفة',
			'icloudSync.statusNoAccount' => 'سجّل الدخول إلى iCloud للمزامنة',
			'icloudSync.statusUnavailable' => 'iCloud غير متاح حاليًا',
			'icloudSync.statusWaitingKeychain' => 'في انتظار سلسلة مفاتيح iCloud — تأكد من تحديث التطبيق على iPhone الخاص بك',
			'icloudSync.lastSyncedNever' => 'لم تتم المزامنة مطلقًا',
			'icloudSync.lastSyncedAt' => ({required Object time}) => 'آخر مزامنة ${time}',
			'icloudSync.deleteSyncNote' => 'مزامنة iCloud مفعّلة: سيؤدي هذا أيضًا إلى حذف النسخة المتزامنة من iCloud الخاص بك وإيقاف المزامنة. تحتفظ الأجهزة الأخرى بنسختها المحلية — نفّذ هذا الإجراء على كل جهاز للحذف في كل مكان.',
			'icloudSync.bannerText' => 'مزامنة iCloud متوقفة — عاداتك موجودة فقط على هذا الجهاز وستُفقد إذا أعدت ضبطه أو استبدلته.',
			'icloudSync.bannerAction' => 'تفعيل',
			'privateRecovery.preparing' => 'جارٍ تجهيز مساحتك الخاصة…',
			'privateRecovery.restoredFromCloudToast' => 'تعذّر فتح قاعدة البيانات المحلية — تمت استعادة بياناتك من iCloud.',
			'privateRecovery.waitingTitle' => 'بانتظار iCloud',
			'privateRecovery.waitingMessage' => 'المزامنة مفعّلة، لكن مفتاح التشفير لم يصل بعد من سلسلة مفاتيح iCloud. انتظر لحظة ثم أعد المحاولة.',
			'privateRecovery.lockedTitle' => 'تعذّر فتح البيانات الخاصة',
			'privateRecovery.lockedMessageLocalOnly' => 'لا يستطيع هذا الجهاز فتح قاعدة بياناتك الخاصة المحلية — مفتاح التشفير مفقود — ومزامنة iCloud متوقّفة، لذا لا توجد نسخة سحابية للاستعادة. يمكنك إعادة التعيين والبدء من جديد.',
			'privateRecovery.lockedMessageICloudUnavailable' => 'لا يستطيع هذا الجهاز فتح قاعدة بياناتك الخاصة المحلية. مزامنة iCloud مفعّلة لكن الحساب غير متاح — سجّل الدخول إلى iCloud ثم أعد المحاولة.',
			'privateRecovery.errorTitle' => 'تعذّر فتح الوضع الخاص',
			'privateRecovery.errorMessage' => 'حدث خطأ أثناء فتح قاعدة بياناتك الخاصة. أعد المحاولة، أو أعد تعيينها وابدأ من جديد.',
			'privateRecovery.enableSyncHint' => 'هل لديك هذه البيانات على جهاز آخر؟ فعّل مزامنة iCloud من الإعدادات بعد إعادة التعيين لجلبها إلى هنا.',
			'privateRecovery.retry' => 'إعادة المحاولة',
			'privateRecovery.resetFresh' => 'إعادة التعيين والبدء من جديد',
			'privateRecovery.backToSignIn' => 'العودة إلى تسجيل الدخول',
			'namePrompt.title' => 'ما اسمك؟',
			'namePrompt.subtitle' => 'أدخل اسمك لتخصيص لوحة المعلومات.',
			'namePrompt.hint' => 'مثال: Simo',
			'namePrompt.save' => 'حفظ ومتابعة',
			'nav.overview' => 'نظرة عامة',
			'nav.habits' => 'العادات',
			'nav.insights' => 'الإحصاءات',
			'nav.goals' => 'الأهداف',
			'nav.coach' => 'مدرّب AI',
			'nav.settings' => 'الإعدادات',
			'shell.syncPending' => 'المزامنة معلّقة',
			'shell.syncing' => 'جارٍ المزامنة',
			'shell.synced' => 'تمت المزامنة',
			'shell.syncTooltip' => 'مزامنة',
			'shell.searchHint' => 'ابحث أو تنقّل',
			'shell.searchSectionHint' => 'ابحث عن قسم...',
			'common.actions.cancel' => 'إلغاء',
			'common.actions.save' => 'حفظ',
			'common.actions.delete' => 'حذف',
			'common.actions.edit' => 'تعديل',
			'common.actions.pick' => 'اختيار',
			'common.actions.gotIt' => 'حسناً',
			'common.months.0' => 'يناير',
			'common.months.1' => 'فبراير',
			'common.months.2' => 'مارس',
			'common.months.3' => 'أبريل',
			'common.months.4' => 'مايو',
			'common.months.5' => 'يونيو',
			'common.months.6' => 'يوليو',
			'common.months.7' => 'أغسطس',
			'common.months.8' => 'سبتمبر',
			'common.months.9' => 'أكتوبر',
			'common.months.10' => 'نوفمبر',
			'common.months.11' => 'ديسمبر',
			'common.weekdayInitials.0' => 'ن',
			'common.weekdayInitials.1' => 'ث',
			'common.weekdayInitials.2' => 'ر',
			'common.weekdayInitials.3' => 'خ',
			'common.weekdayInitials.4' => 'ج',
			'common.weekdayInitials.5' => 'س',
			'common.weekdayInitials.6' => 'ح',
			'common.calendarView.year' => 'سنة',
			'common.calendarView.month' => 'شهر',
			'common.calendarView.week' => 'أسبوع',
			'common.calendarView.life' => 'الحياة',
			'common.weekdaysLong.0' => 'الاثنين',
			'common.weekdaysLong.1' => 'الثلاثاء',
			'common.weekdaysLong.2' => 'الأربعاء',
			'common.weekdaysLong.3' => 'الخميس',
			'common.weekdaysLong.4' => 'الجمعة',
			'common.weekdaysLong.5' => 'السبت',
			'common.weekdaysLong.6' => 'الأحد',
			'common.none' => 'لا شيء',
			'common.habits' => 'العادات',
			'common.status.error' => 'خطأ',
			'common.total' => 'الإجمالي',
			'common.completed' => 'مكتمل',
			'common.unexpectedErrorTitle' => 'حدث خطأ ما',
			'common.unexpectedErrorMessage' => 'حدث خطأ غير متوقع. حاول مرة أخرى.',
			'form.title' => 'العنوان',
			'form.category' => 'الفئة',
			'form.color' => 'اللون',
			'form.add' => 'إضافة',
			'createGoal.title' => 'هدف جديد',
			'createGoal.subtitle' => 'حدّد هدفك التالي.',
			'createGoal.titleHint' => 'مثال: إطلاق المنتج الجديد',
			'createGoal.categoryHint' => 'مثال: العمل',
			'createGoal.timeline' => 'الجدول الزمني',
			'createGoal.thisWeek' => 'هذا الأسبوع',
			'createGoal.thisMonth' => 'هذا الشهر',
			'createGoal.thisQuarter' => 'هذا الربع',
			'createGoal.thisYear' => 'هذه السنة',
			'createGoal.longTerm' => 'طويل الأمد (Lifetime)',
			'createGoal.dueLifetime' => 'مدى الحياة',
			'createGoal.dueByYear' => ({required Object year}) => 'بحلول ${year}',
			'createGoal.defaultCategory' => 'هدف',
			'createGoal.periodWhen' => 'متى',
			'createHabit.title' => 'عادة جديدة',
			'createHabit.subtitle' => 'حدّد عادتك الجديدة.',
			'createHabit.titleHint' => 'مثال: التأمل',
			'createHabit.weeklyFrequency' => 'التكرار الأسبوعي',
			'macroGoals.types.annual' => 'سنوي',
			'macroGoals.types.quarterly' => 'ربع سنوي',
			'macroGoals.types.monthly' => 'شهري',
			'macroGoals.types.weekly' => 'أسبوعي',
			'macroGoals.types.lifetime' => 'مدى الحياة',
			'macroGoals.quarterNumber' => ({required Object quarter}) => 'الربع ${quarter}',
			'macroGoals.addLifetimeGoal' => 'أضف هدف العُمر...',
			'macroGoals.addAnnualGoal' => 'أضف هدفاً سنوياً...',
			'macroGoals.addQuarterlyGoal' => 'أضف هدفاً ربع سنوي...',
			'macroGoals.addMonthlyGoal' => 'أضف هدفاً شهرياً...',
			'macroGoals.addWeeklyGoal' => 'أضف هدفاً أسبوعياً...',
			'macroGoals.completed' => 'مكتملة',
			'macroGoals.failed' => 'فاشلة',
			'macroGoals.create' => 'إنشاء',
			'macroGoals.strength' => 'نقطة القوة',
			'macroGoals.bestMonth' => 'أفضل شهر',
			'macroGoals.successRate2' => 'معدل النجاح',
			'macroGoals.effectiveType' => 'النوع الفعّال',
			'macroGoals.historicalTotal' => 'الإجمالي التاريخي',
			'macroGoals.from_' => 'من',
			'macroGoals.globalSuccess' => 'النجاح الإجمالي',
			'macroGoals.completedGoals' => 'أهداف مكتملة',
			'macroGoals.bestYear' => 'أفضل سنة',
			'macroGoals.mostProductiveYear' => 'أكثر سنة إنتاجية',
			'macroGoals.totalGoals' => 'إجمالي الأهداف',
			'macroGoals.allYears' => 'كل السنوات',
			'macroGoals.selectYearHeader' => 'اختر السنة',
			'macroGoals.completions' => 'الإنجازات',
			'macroGoals.success2' => 'النجاح',
			'macroGoals.archiveCategory2' => 'أرشفة الفئة؟',
			'macroGoals.categoryUnavailableLinked' => ({required Object label, required Object count}) => 'لن تعود الفئة "${label}" متاحة للأهداف الجديدة، لكنها ستبقى مرتبطة بـ ${count} أهداف سابقة وبإحصاءاتك.',
			'macroGoals.categoryUnavailableArchived' => ({required Object label}) => 'لن تعود الفئة "${label}" متاحة للأهداف الجديدة، لكنها ستبقى في سجلّك.',
			'macroGoals.archive' => 'أرشفة',
			'macroGoals.createNewCategory' => 'إنشاء فئة جديدة',
			'statistics.completed2' => 'مكتمل',
			'statistics.notCompleted' => 'غير مكتملة',
			'statistics.ofCompletion' => 'من الإكمال',
			'statistics.growth' => 'نمو',
			'statistics.decline' => 'انخفاض',
			'statistics.strongestDay' => 'أقوى يوم',
			'statistics.weakestDay' => 'أضعف يوم',
			'statistics.worstNegativeStreak' => 'أسوأ سلسلة سلبية',
			'statistics.missedConsecutiveDays' => 'أيام متتالية فائتة',
			'statistics.brokenStreaks' => 'السلاسل المنقطعة',
			'statistics.noBrokenStreaks' => 'لم تُسجَّل أي سلاسل منقطعة',
			'statistics.startedOn' => 'بدأت في',
			'statistics.moodCorrelation' => 'ارتباط المزاج',
			'statistics.avgMood' => 'متوسط المزاج (✓)',
			'statistics.avgEnergy' => 'متوسط الطاقة (✓)',
			'statistics.onCompletedDays' => 'في الأيام المكتملة',
			'statistics.resilient' => 'مرنة',
			'statistics.completedVsMissed' => 'مكتملة مقابل فائتة',
			'statistics.mood2' => 'المزاج',
			'statistics.energy' => 'الطاقة',
			'statistics.performancePerLevel' => 'الأداء حسب المستوى',
			'statistics.withHighMood' => 'مع مزاج مرتفع',
			'statistics.withLowMood' => 'مع مزاج منخفض',
			'statistics.moodEnergyAnalysis' => 'يوضّح التحليل كيف تتأثّر مواظبتك بمزاجك وطاقتك.',
			'statistics.missed2' => 'فائت',
			'statistics.positive' => 'إيجابي',
			'statistics.neutral' => 'محايد',
			'statistics.high' => 'مرتفع',
			'statistics.low' => 'منخفض',
			'statistics.skipped' => 'متخطّاة',
			'statistics.criticalHabits' => 'العادات الحرجة',
			'statistics.bestHabitsTitle' => 'أفضل العادات',
			'statistics.worseningHabitsDescription' => 'العادات الأكثر تراجعاً.',
			'statistics.everythingIsGreat' => 'كل شيء على ما يُرام!',
			'statistics.allHabitsStableDescription' => 'جميع عاداتك تحافظ على اتجاهها أو تحسّنه. واصل التقدّم.',
			'statistics.habitCompletionPeriodDescription' => ({required Object rate}) => 'أكملت هذه العادة ${rate}% من الوقت خلال الفترة المحدّدة.',
			'statistics.habitLostConsistencyDescription' => ({required Object drop}) => 'فقدت هذه العادة ${drop}% من المواظبة في الأسبوع الماضي مقارنةً بالذي قبله.',
			'statistics.negativeStreak' => 'السلسلة السلبية',
			'statistics.currentStreak2' => 'السلسلة الحالية',
			'statistics.improvementAreas' => 'مجالات التحسين',
			'statistics.habitsRequiringMoreAttention' => 'عادات تتطلّب مزيداً من الاهتمام.',
			'statistics.failureAnalysis' => 'تحليل الإخفاقات',
			'statistics.missedDaysPattern' => 'تكرار وأنماط أيامك الفائتة.',
			'statistics.recoveryPatterns' => 'أنماط التعافي',
			'statistics.recoverySpeed' => 'مدى سرعة عودتك إلى المسار بعد تعثّر.',
			'statistics.avgRecoveryTime' => 'متوسط وقت التعافي',
			'statistics.worstStreak' => 'أسوأ سلسلة',
			'statistics.frequency' => 'التكرار',
			'statistics.daysShortUnit' => 'ي',
			'statistics.perMonthUnit' => 'شهر',
			'statistics.succ' => 'نجاح',
			'statistics.blackDay' => 'يوم أسود',
			'statistics.correlationsWith' => 'الارتباطات مع',
			'statistics.howThisHabitRelatesToOthers' => 'كيف ترتبط هذه العادة بالعادات الأخرى',
			'statistics.positiveCorrelations' => 'ارتباطات إيجابية',
			'statistics.negativeCorrelations' => 'ارتباطات سلبية',
			'statistics.noSignificantPositiveCorrelation' => 'لا يوجد ارتباط إيجابي مهم',
			'statistics.noSignificantNegativeCorrelation' => 'لا يوجد ارتباط سلبي مهم',
			'statistics.habitTogetherPercent' => ({required Object percentage}) => '${percentage}% معاً',
			'statistics.habitPositiveCorrelationDescription' => ({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'عندما تُكمل "${currentGoal}"، تكون لديك فرصة بنسبة ${percentage}% لإكمال "${otherGoal}" أيضاً.',
			'statistics.habitNegativeCorrelationDescription' => ({required Object currentGoal, required Object percentage, required Object otherGoal}) => 'عندما تُكمل "${currentGoal}"، تكون لديك فرصة بنسبة ${percentage}% فقط لإكمال "${otherGoal}" أيضاً.',
			'statistics.weeklyTrend' => 'الاتجاه الأسبوعي',
			'statistics.monthlyTrend' => 'الاتجاه الشهري',
			'statistics.yearlyTrend' => 'الاتجاه السنوي',
			'statistics.performanceEvolution' => 'تطوّر الأداء',
			'statistics.globalTrend' => 'الاتجاه الإجمالي',
			'statistics.total' => 'الإجمالي',
			'statistics.all' => 'الكل',
			'statistics.noDataForAlerts' => 'لا توجد بيانات كافية لإنشاء تنبيهات.',
			'statistics.missed' => 'فائتة',
			'goalState.active' => 'قيد التنفيذ',
			'dueLabel.lifetime' => 'هدف الحياة',
			'dueLabel.annual' => 'هدف سنوي',
			'dueLabel.quarter' => 'ربع',
			'dashboard.mood' => 'المزاج',
			'dashboard.energy' => 'الطاقة',
			'dashboard.goodMorning' => 'صباح الخير',
			'dashboard.goodAfternoon' => 'مساء الخير',
			'dashboard.goodEvening' => 'مساء الخير',
			'dashboard.manager' => 'الإدارة',
			'dashboard.aiChat' => 'محادثة AI',
			'dashboard.consecutiveDays' => 'أيام متتالية',
			'dashboard.welcomeTitle' => 'مرحبًا بك في Evolve',
			'dashboard.welcomeSubtitle' => 'ابدأ رحلة نموّك الشخصي.',
			'dashboard.welcomeBody' => 'يساعدك هذا التطبيق على بناء عادات جيدة وتحقيق أهدافك طويلة المدى.',
			'dashboard.welcomeStart' => 'ابدأ',
			'dashboard.subtitle' => 'حافظ على الإيقاع. كل فعل صغير يعزّز الشخص الذي تبنيه.',
			'dashboard.completionToday' => 'إنجاز اليوم',
			'dashboard.habitsCount' => ({required Object done, required Object total}) => '${done}/${total} عادات',
			'dashboard.bestStreak' => 'أفضل سلسلة',
			'dashboard.activeGoals' => 'الأهداف النشطة',
			'dashboard.avgProgress' => ({required Object pct}) => '${pct}% متوسط التقدّم',
			'dashboard.momentum' => 'الزخم',
			'dashboard.vsLastWeek' => 'مقارنةً بالأسبوع الماضي',
			'dashboard.weeklyTrend' => 'الاتجاه الأسبوعي',
			'dashboard.weeklyTrendSubtitle' => 'نسبة إنجاز عاداتك',
			'dashboard.thisWeekPill' => ({required Object value}) => '${value} هذا الأسبوع',
			'dashboard.todayProtocol' => 'بروتوكول اليوم',
			'dashboard.todayProtocolSubtitle' => 'أكمل الإجراءات الأساسية قبل إضافة المزيد',
			'dashboard.actionsCount' => ({required Object count}) => '${count} إجراءات',
			'dashboard.emptyHabits' => 'لوحتك فارغة. أنشئ عادتك الأولى.',
			'dashboard.streakDaysShort' => ({required Object n}) => '${n} ي',
			'dashboard.checkInDone' => 'تم تسجيل المتابعة',
			'dashboard.checkInPrompt' => 'كيف تشعر اليوم؟',
			'dashboard.moodEnergyValue' => ({required Object mood, required Object energy}) => 'المزاج ${mood}/10 · الطاقة ${energy}/10',
			'dashboard.checkInHint' => 'سجّل المزاج والطاقة لتحسين تحليل أنماطك.',
			'dashboard.updateCheckIn' => 'تحديث المتابعة',
			'dashboard.doCheckIn' => 'قم بالمتابعة',
			'dashboard.dailyCheckIn' => 'المتابعة اليومية',
			'dashboard.dailyCheckInSubtitle' => 'قياس سريع يساعد Evolve على فهم أنماطك بشكل أفضل.',
			'dashboard.record' => 'تسجيل',
			'dashboard.focusGoals' => 'الأهداف قيد التركيز',
			'dashboard.currentPriorities' => 'الأولويات الحالية',
			'dashboard.goalLimitReached' => 'تم بلوغ حدّ 100 هدف. اشترك في Pro لإنشاء المزيد.',
			'dashboard.emptyFocusGoals' => 'لا أهداف قيد التركيز. أضف واحدًا.',
			'dashboard.weekToStart' => 'أسبوع للانطلاق',
			'dashboard.weekGrowing' => 'أسبوع في تصاعد',
			'dashboard.weekToRecover' => 'أسبوع للتعافي',
			'dashboard.vsPreviousWeek' => ({required Object value}) => '${value} مقارنةً بالأسبوع السابق.',
			'stats.title' => 'الإحصاءات',
			'stats.global' => 'إجمالي',
			'stats.resilience' => 'المرونة',
			'stats.tabHabits' => 'العادات',
			'stats.tabMood' => 'المزاج',
			'stats.last30Days' => 'آخر 30 يومًا',
			'stats.singleHabit' => 'عادة واحدة',
			'stats.noHabit' => 'لا توجد عادة',
			'stats.completionToday' => 'إنجاز اليوم',
			'stats.bestStreakLabel' => 'أفضل سلسلة',
			'stats.criticalDay' => 'يوم حرج',
			'stats.completePrioritiesFirst' => 'أكمل الأولويات أولًا',
			'stats.recentActivity' => 'النشاط الأخير',
			'stats.recentActivitySubtitle' => 'كثافة الإنجاز خلال آخر 90 يومًا',
			'stats.trendGlobal' => 'الاتجاه العام',
			'stats.trendGlobalSubtitle' => 'مقارنة زمنية للبروتوكول',
			'stats.vsPrevDay' => ({required Object value}) => '${value}% مقارنةً باليوم السابق',
			'stats.bestHabit' => 'أفضل عادة',
			'stats.criticalArea' => 'منطقة حرجة',
			'stats.streakAtRisk' => 'سلسلة في خطر',
			'stats.streakAtRiskDetail' => ({required Object habit}) => '${habit} يحتاج إلى انتباه في المتابعات القادمة.',
			'stats.patternToConsolidate' => 'نمط للترسيخ',
			'stats.checkLowMoodDays' => 'راجع أيام المزاج المنخفض وحافظ على البروتوكول الأساسي.',
			'stats.goalDue' => 'هدف قارب على الاستحقاق',
			'stats.noGoalNeedsIntervention' => 'لا يوجد هدف نشط يحتاج إلى تدخل.',
			'stats.performancePerHabit' => 'الأداء لكل عادة',
			'stats.performancePerHabitSubtitle' => 'ترتيب محسوب من السجلات المتزامنة حسب الاتساق الأسبوعي',
			'stats.avgMood' => 'متوسط المزاج',
			'stats.avgEnergy' => 'متوسط الطاقة',
			'stats.checkInsAvailable' => ({required Object count}) => '${count} متابعات متاحة',
			'stats.resilientHabit' => 'عادة مرنة',
			'stats.completedEvenHardDays' => 'أُنجزت حتى في الأيام الصعبة',
			'stats.moodEnergy' => 'المزاج والطاقة',
			'stats.moodEnergySubtitle' => 'متوسط المتابعات المتاحة خلال آخر 90 يومًا',
			'stats.completion' => 'الإنجاز',
			'stats.currentWeek' => 'الأسبوع الحالي',
			'stats.currentStreak' => 'السلسلة الحالية',
			'stats.currentStreakDetail' => 'سلسلة متزامنة من السجلات المتاحة',
			'stats.trend30' => 'اتجاه 30 يومًا',
			'stats.trend30Detail' => 'الإنجاز خلال آخر 30 يومًا',
			'stats.yearlyCalendar' => 'التقويم السنوي',
			'stats.yearlyCalendarSubtitle' => ({required Object habit}) => 'توزيع إنجازات ${habit}',
			'stats.performancePerDay' => 'الأداء لكل يوم',
			'stats.performancePerDaySubtitle' => 'أيام الأسبوع القوية والضعيفة',
			'stats.protectStreak' => ({required Object days}) => 'احمِ سلسلة ${days} أيام',
			'stats.keepSameSlot' => 'حافظ على نفس الفترة الزمنية لتقليل الاحتكاك في أكثر الأيام ازدحامًا.',
			'stats.worstNegativeSeq' => ({required Object days}) => 'استمرت أسوأ سلسلة سلبية ${days} يومًا.',
			'stats.positiveLever' => 'رافعة إيجابية مكتشفة',
			'stats.bestHabitRegularity' => ({required Object habit}) => '${habit} يحافظ على أفضل انتظام حديث.',
			'stats.moodSensitivity' => 'الحساسية للمزاج',
			'stats.lowEnergyCompletion' => 'الإنجاز مع طاقة منخفضة',
			'stats.moodOutputCorrelation' => 'الارتباط بين المزاج والأداء',
			'stats.moodOutputSubtitle' => 'الإنجازات المتاحة في أيام المتابعة',
			'stats.keyCorrelations' => 'الارتباطات الرئيسية',
			'stats.keyCorrelationsSubtitle' => 'الأنماط الأكثر تأثيرًا على البروتوكول',
			'stats.moreLogsNeeded' => 'يلزم المزيد من السجلات لحساب ارتباطات مفيدة.',
			'stats.createHabitForAnalysis' => 'أنشئ عادة واحدة على الأقل لعرض التحليل التفصيلي.',
			'stats.noData' => 'لا توجد بيانات',
			'stats.tabInfo' => 'معلومات',
			'stats.tabTrend' => 'الاتجاه',
			'stats.tabAlerts' => 'تنبيهات',
			'stats.tabOverview' => 'نظرة عامة',
			'stats.tabCalendar' => 'التقويم',
			'stats.tabPerformance' => 'الأداء',
			'stats.tabImprovement' => 'تحسين',
			'stats.pageSubtitle' => 'حدّد الأنماط التي تدعم النمو وتدخّل في المناطق الحرجة.',
			'stats.actionsFraction' => ({required Object done, required Object total}) => '${done}/${total} إجراءات',
			'stats.affectedByHardDays' => ({required Object habit}) => '${habit} يتأثر بالأيام الصعبة',
			'stats.last30DaysTrend' => 'اتجاه آخر 30 يوماً',
			'stats.strongestDayDetail' => ({required Object pct, required Object done, required Object total}) => 'احسنت، ${pct}% اكتمال (${done}/${total})',
			'stats.weakestDayDetail' => ({required Object pct, required Object done, required Object total}) => 'فقط ${pct}% اكتمال (${done}/${total})',
			'stats.brokenStreakItem' => ({required Object days}) => 'سلسلة من ${days} يوم انقطعت',
			'stats.togetherProbability' => ({required Object percentage}) => '${percentage}% معا',
			'stats.criticalHabitsSubtitle' => 'العادات الأكثر تراجعاً.',
			'stats.bestHabitsSubtitle' => 'العادات التي تكون فيها الاكثر ثباتا.',
			'stats.timeframeWeek' => 'أسبوع',
			'stats.timeframeMonth' => 'شهر',
			'stats.timeframeYear' => 'سنة',
			'stats.timeframeAll' => 'الكل',
			'stats.negativeStreakDays' => ({required Object days}) => '${days} يوم دون اكمال',
			'stats.dropPercent' => ({required Object drop}) => '-${drop}%',
			'stats.blackDayDetail' => ({required Object day}) => 'يوم اسود: ${day}',
			'stats.failureDetail' => ({required Object streak, required Object frequency}) => 'اسوأ سلسلة: ${streak}ي · ~${frequency}/شهر فائتة',
			'stats.recoveryDetail' => ({required Object days}) => 'متوسط وقت التعافي: ${days} يوم',
			'stats.successRate' => ({required Object rate}) => '${rate}% نجاح',
			'stats.sortRate' => 'النسبة',
			'stats.sortStreak' => 'التتابع',
			'stats.sortName' => 'الاسم',
			'stats.worstStreakLabel' => 'الأسوأ',
			'stats.momentumTitle' => 'الزخم',
			'stats.momentumSubtitle' => 'حالتك الحالية',
			'stats.momentumForm' => 'الحالة',
			'stats.momentumRate' => '7 أيام',
			'stats.momentumStreakHealth' => 'السلاسل',
			'stats.momentumTrend' => 'الاتجاه',
			'stats.rollingImproving' => 'في تحسّن',
			'stats.rollingDeclining' => 'في تراجع',
			'stats.rollingSteady' => 'ثابت',
			'stats.lifetimeConsistency' => 'الانتظام',
			'stats.lifetimeConsistencyDetail' => 'الإنجاز الإجمالي',
			'stats.lifetimeTotalDone' => 'إجمالي المنجز',
			'stats.lifetimeTotalDoneDetail' => 'العادات المكتملة',
			'stats.lifetimePerfectDays' => 'أيام مثالية',
			'stats.lifetimePerfectDaysDetail' => 'كل شيء مكتمل',
			'stats.lifetimeDaysTracked' => 'الأيام المتتبعة',
			'stats.lifetimeDaysTrackedDetail' => 'منذ أن بدأت',
			'stats.keystoneTitle' => 'العادة المحورية',
			'stats.keystoneImpact' => ({required Object withPct, required Object withoutPct}) => 'في أيامها تنجز ${withPct}% من عاداتك الأخرى، مقابل ${withoutPct}%.',
			'stats.yearActivity' => 'نشاط 365 يومًا',
			'stats.yearActivitySubtitle' => 'كل عادة، كل يوم',
			'stats.activeDaysCount' => ({required Object count}) => '${count} يوم نشط',
			'stats.heatmapLess' => 'أقل',
			'stats.heatmapMore' => 'أكثر',
			'stats.bestHabitsTitle' => 'أفضل العادات',
			'stats.criticalHabitsTitle' => 'تحتاج انتباهًا',
			'stats.criticalStalled' => ({required Object days}) => 'متوقفة ${days}ي',
			'stats.rollingTitle' => 'الإنجاز المتحرك',
			'stats.rollingSubtitle' => 'معدل 7 و30 يومًا',
			'stats.rolling7' => '7 أيام',
			'stats.rolling30' => '30 يومًا',
			'stats.weekVsAvgTitle' => 'هذا الأسبوع مقابل المتوسط',
			'stats.weekVsAvgSubtitle' => 'كيف يقارن هذا الأسبوع',
			'stats.thisWeek' => 'هذا الأسبوع',
			'stats.yourAverage' => 'متوسطك',
			'stats.weekdayShapeTitle' => 'الإيقاع الأسبوعي',
			'stats.weekdayShapeSubtitle' => 'الإنجاز حسب اليوم',
			'stats.weekdayWeekendTitle' => 'أيام العمل مقابل العطلة',
			'stats.weekdayWeekendSubtitle' => 'أين أنت الأقوى',
			'stats.weekdaysLabel' => 'أيام العمل',
			'stats.weekendLabel' => 'عطلة الأسبوع',
			'stats.seasonalityTitle' => 'الموسمية',
			'stats.seasonalitySubtitle' => 'الإنجاز حسب الشهر',
			'stats.bounceBackTitle' => 'معدل التعافي',
			'stats.bounceBackSubtitle' => 'التعافي بعد الإخفاق',
			'stats.bounceBackDetail' => ({required Object recoveries, required Object opportunities}) => 'تعافيت ${recoveries} من ${opportunities} مرة',
			'stats.dangerZoneTitle' => 'منطقة الخطر',
			'stats.dangerZoneSubtitle' => 'متى تنكسر السلاسل',
			'stats.dangerZoneNone' => 'لا سلاسل مكسورة بعد',
			'stats.dangerZoneDetail' => ({required Object breaks, required Object total}) => '${breaks} من ${total} انكسار هنا',
			'stats.performanceComparisonTitle' => 'مقارنة الأداء',
			'stats.performanceComparisonSubtitle' => 'أفضل سلسلة مقابل أسوأ',
			'stats.perfCompGap' => ({required Object pct}) => 'فارق ${pct}%',
			'stats.perfCompBest' => 'الأفضل',
			'stats.perfCompWorst' => 'الأسوأ',
			'stats.consistencyTitle' => 'الانتظام',
			'stats.consistencySubtitle' => 'أكثر العادات انتظامًا',
			'stats.consistencySteadiest' => 'الأكثر ثباتًا',
			'stats.consistencyErratic' => 'الأكثر تذبذبًا',
			'stats.medalsTitle' => 'ترتيب السلاسل',
			'stats.medalsSubtitle' => 'أطول السلاسل الحالية',
			'stats.neverMissedTitle' => 'لم تُفوَّت',
			'stats.neverMissedEmpty' => 'لا عادات مثالية بعد',
			'stats.distributionTitle' => 'التوزيع',
			'stats.distributionSubtitle' => 'العادات حسب معدل النجاح',
			'stats.synergyTitle' => 'تآزر العادات',
			'stats.synergySubtitle' => 'أي العادات تسير معًا',
			'stats.moodSensitiveTitle' => 'حساسة للمزاج',
			'stats.moodSensitiveSubtitle' => 'الأكثر تأثرًا بمزاجك',
			'stats.resilientHabitsTitle' => 'عادات صامدة',
			'stats.resilientHabitsSubtitle' => 'تُنجَز حتى في الأيام الصعبة',
			'stats.correlationAnalysisTitle' => 'ارتباط المزاج',
			'stats.correlationAnalysisSubtitle' => 'الإنجاز عند المزاج المنخفض مقابل المرتفع',
			'stats.moodEnergyTrendTitle' => 'المزاج والطاقة',
			'stats.moodEnergyTrendSubtitle' => ({required Object days}) => 'آخر ${days} يومًا',
			'stats.allTimeBest' => 'الرقم القياسي',
			'stats.topPerformerLabel' => 'الأفضل',
			'stats.currentStreakShort' => 'الآن',
			'stats.recordLabel' => 'الرقم القياسي',
			'stats.recordDetail' => 'أطول سلسلة على الإطلاق',
			'stats.adherenceTitle' => 'الالتزام بالجدول',
			'stats.adherenceSubtitle' => 'من الأيام المقررة',
			'stats.adherenceDetail' => ({required Object done, required Object scheduled}) => '${done} من ${scheduled} يومًا مقررًا',
			'stats.atRiskTitle' => 'في خطر',
			'stats.atRiskYes' => 'نعم',
			'stats.atRiskNo' => 'على المسار',
			'stats.atRiskDetail' => ({required Object days}) => '${days} يومًا منذ آخر مرة',
			'stats.daysUnit' => 'ي',
			'stats.gapTitle' => 'الفواصل',
			'stats.gapSubtitle' => 'الأيام بين الإنجازات',
			'stats.gapAvg' => 'المتوسط',
			'stats.gapLongest' => 'الأطول',
			'stats.gapSince' => 'منذ الأخير',
			'stats.habitBounceBackShort' => 'التعافي',
			'stats.habitConsistencyDetail' => 'درجة الانتظام',
			'stats.habitPercentile' => ({required Object pct}) => 'أفضل من ${pct}% من عاداتك',
			'stats.monthVsTitle' => 'هذا الشهر مقابل السابق',
			'stats.monthVsSubtitle' => 'الإنجاز شهرًا بشهر',
			'stats.thisMonthLabel' => 'هذا الشهر',
			'stats.lastMonthLabel' => 'الشهر الماضي',
			'stats.nextDayMoodTitle' => 'تأثير مزاج اليوم التالي',
			'stats.nextDayMoodSubtitle' => 'المزاج والطاقة في اليوم التالي',
			'stats.nextDayAfterDone' => 'بعد فعلها',
			'stats.nextDayAfterMissed' => 'بعد تفويتها',
			'stats.nextDayMoodLift' => ({required Object value}) => '${value} تحسّن في المزاج',
			'stats.streakHistoryTitle' => 'سجل السلاسل',
			'stats.streakHistorySubtitle' => 'كل سلسلة أيام متتالية',
			'stats.streakHistoryDetail' => ({required Object count, required Object longest}) => '${count} سلسلة · الأطول ${longest} يومًا',
			'habitsPage.today' => 'اليوم',
			'habitsPage.subtitle' => 'ابنِ بروتوكولك اليومي وراقب الاتساق عبر الزمن.',
			'habitsPage.tabProtocol' => 'البروتوكول',
			'habitsPage.tabCalendar' => 'التقويم',
			'habitsPage.deleteHabitTitle' => 'حذف العادة',
			'habitsPage.deleteHabitConfirm' => ({required Object title}) => 'هل تريد إزالة "${title}" من البروتوكول؟',
			'habitsPage.activeProtocol' => 'البروتوكول النشط',
			'habitsPage.completedToday' => 'أُنجزت اليوم',
			'habitsPage.dailyProtocol' => 'البروتوكول اليومي',
			'habitsPage.protocolSubtitle' => 'نظرة أسبوعية وتذكيرات وإجراءات سريعة',
			'habitsPage.colHabit' => 'العادة',
			'habitsPage.colStreak' => 'السلسلة',
			'habitsPage.colLast7Days' => 'آخر 7 أيام',
			'habitsPage.colReminder' => 'تذكير',
			'habitsPage.streakDays' => ({required Object n}) => '${n} أيام',
			'habitsPage.prevPeriod' => 'الفترة السابقة',
			'habitsPage.nextPeriod' => 'الفترة التالية',
			'habitsPage.weekdayAbbrevUpper.0' => 'اثن',
			'habitsPage.weekdayAbbrevUpper.1' => 'ثلا',
			_ => null,
		} ?? switch (path) {
			'habitsPage.weekdayAbbrevUpper.2' => 'أرب',
			'habitsPage.weekdayAbbrevUpper.3' => 'خمي',
			'habitsPage.weekdayAbbrevUpper.4' => 'جمع',
			'habitsPage.weekdayAbbrevUpper.5' => 'سبت',
			'habitsPage.weekdayAbbrevUpper.6' => 'أحد',
			'habitsPage.lifeView' => 'عرض الحياة',
			'habitsPage.lifeViewSubtitle' => 'تمثّل كل خلية شهرًا من المسار حتى سن 85.',
			'habitsPage.monthsLived' => 'الأشهر المُعاشة',
			'habitsPage.currentAge' => 'العمر الحالي',
			'habitsPage.monthsRemaining' => 'الأشهر المتبقية',
			'habitsPage.dayDetail' => ({required Object day, required Object month}) => 'تفاصيل ${day} ${month}',
			'habitsPage.dayDetailSubtitle' => 'حدّث حالة العادات لهذا اليوم.',
			'habitsPage.editHabit' => 'تعديل العادة',
			'habitsPage.newHabit' => 'عادة جديدة',
			'habitsPage.optionalReminder' => 'تذكير اختياري',
			'habitsPage.reminderHint' => 'مثال: 08:30',
			'habitsPage.close' => 'إغلاق',
			'habitsPage.statusDone' => 'مكتملة',
			'habitsPage.statusSkipped' => 'متخطاة',
			'habitsPage.statusUnrecorded' => 'غير مسجلة',
			'habitsPage.weekOf' => ({required Object day, required Object month}) => 'أسبوع ${day} ${month}',
			'habitsPage.lifeWeeks' => 'أسابيع مسارك',
			'habitsPage.catMindfulness' => 'اليقظة الذهنية',
			'habitsPage.editableHint' => 'يمكن تعديل اليوم والأمس فقط.',
			'lavoro' => 'العمل',
			'salute' => 'الصحة',
			'finanza' => 'المال',
			'relazioni' => 'العلاقات',
			'formazione' => 'التعليم',
			'hobby' => 'الهوايات',
			'spirituale' => 'الروحانية',
			'altro' => 'أخرى',
			'goalsPage.title' => 'الأهداف الكبرى',
			'goalsPage.subtitle' => 'التخطيط طويل المدى.',
			'goalsPage.sampleGoal' => 'هدف نموذجي',
			'goalsPage.periodLifetime' => 'أهداف الحياة',
			'goalsPage.subtitleLifetime' => 'أهداف مدى الحياة',
			'goalsPage.subtitleAnnual' => 'الأهداف السنوية',
			'goalsPage.subtitleQuarterly' => 'الأهداف الربع سنوية',
			'goalsPage.subtitleMonthly' => 'الأهداف الشهرية',
			'goalsPage.subtitleWeekly' => 'الأهداف الأسبوعية',
			'goalsPage.statsTab' => 'إحصاء',
			'goalsPage.fullView' => 'العرض الكامل',
			'goalsPage.categoriesTitle' => 'فئات الأهداف',
			'goalsPage.defaultPill' => 'افتراضية',
			'goalsPage.editCategory' => 'تعديل الفئة',
			'goalsPage.archiveCategory' => 'أرشفة الفئة',
			'goalsPage.categoryCreateFailed' => 'فشل إنشاء الفئة.',
			'goalsPage.categoryArchiveFailed' => 'فشلت أرشفة الفئة.',
			'goalsPage.categoryEditFailed' => 'فشل تعديل الفئة.',
			'goalsPage.addCategory' => 'إضافة فئة',
			'goalsPage.back' => 'رجوع',
			'goalsPage.finish' => 'إنهاء',
			'goalsPage.next' => 'التالي',
			'goalsPage.categoriesTooltip' => 'الفئات',
			'goalsPage.rescheduleTooltip' => 'إعادة الجدولة للفترة التالية',
			'goalsPage.defaultCategory' => 'افتراضي',
			'goalsPage.emptyActive' => 'لا يوجد هدف نشط في هذه الفترة.',
			'goalsPage.emptyAdd' => 'أضف أول هدف لهذه الفترة.',
			'goalsPage.newGoal' => 'هدف جديد',
			'goalsPage.editGoal' => 'تعديل الهدف',
			'goalsPage.horizonLabel' => 'الأفق',
			'goalsPage.newCategory' => 'فئة جديدة',
			'goalsPage.nameLabel' => 'الاسم',
			'goalsPage.weekPeriodLabel' => ({required Object week, required Object month, required Object year}) => 'الأسبوع ${week}، ${month} ${year}',
			'goalsPage.currentQuarter' => 'الربع الحالي',
			'goalsPage.currentMonth' => 'الشهر الحالي',
			'goalsStats.proRequired' => 'ميزة Pro مطلوبة',
			'goalsStats.active' => 'نشطة',
			'goalsStats.failed' => 'فاشلة',
			'goalsStats.complAbbr' => 'مكت.',
			'goalsStats.seasonality' => 'الموسمية',
			'goalsStats.interestEvolution' => 'تطور الاهتمامات',
			'ai.coach' => 'مدرّب AI',
			'ai.dailyHabits' => 'العادات اليومية',
			'ai.macroGoals' => 'الأهداف الكبرى',
			'ai.openRouter.apiKeyMissingShort' => '⚠️ يحتاج مدرّب AI إلى مفتاح OpenRouter API خاص بك. أضِفه من الإعدادات لبدء المحادثة.',
			'ai.openRouter.apiKeyInvalid' => '⚠️ رفض OpenRouter مفتاح API هذا. تحقّق منه في الإعدادات أو أنشئ مفتاحًا جديدًا على openrouter.ai/keys.',
			'ai.openRouter.defaultSystemPrompt' => 'أنت "مدرّب الانضباط"، مساعد افتراضي يركّز على مساعدة المستخدم على الالتزام بالانضباط وتحقيق أهدافه وبناء عادات صحية. كن محفّزاً لكن واقعياً ومباشراً وعملياً. استخدم نبرة احترافية وودودة.',
			'ai.openRouter.communicationError' => ({required Object code}) => '❌ خطأ في الاتصال بالـ AI. (الرمز: ${code})',
			'ai.openRouter.connectionError' => '❌ خطأ في الاتصال. تأكّد من اتصالك بالإنترنت وحاول مرة أخرى.',
			'ai.openRouter.connectionErrorShort' => '❌ خطأ في الاتصال.',
			'ai.openRouter.connectionCheckTimeout' => '❌ خطأ: استغرق فحص الاتصال وقتاً طويلاً.',
			'ai.openRouter.contextTooLong' => '⚠️ أصبحت هذه المحادثة أطول من اللازم بالنسبة للنموذج. ابدأ محادثة جديدة من أعلى الصفحة للمتابعة.',
			'ai.openRouter.noInternet' => '❌ خطأ: لا يوجد اتصال بالإنترنت. تحقّق من شبكتك.',
			'ai.openRouter.serverTimeout' => '❌ خطأ: يستغرق الخادم وقتاً طويلاً للرد. حاول مرة أخرى.',
			'ai.openRouter.apiError' => ({required Object code}) => '❌ خطأ في API: ${code} (راجع Sentry للتفاصيل)',
			'ai.apiKey.rowTitle' => 'حساب OpenRouter الخاص بك',
			'ai.apiKey.description' => 'تفضّل تشغيل الكوتش على حسابك؟ اربط مفتاح OpenRouter وستدفع للمزوّد مباشرةً — بلا اشتراك في Evolve. أنشئ مفتاحًا على openrouter.ai/keys: يُحفَظ في سلسلة مفاتيح هذا الجهاز ولا يُرسَل إلا إلى OpenRouter.',
			'ai.apiKey.fieldLabel' => 'مفتاح API',
			'ai.apiKey.hint' => 'sk-or-v1-…',
			'ai.apiKey.save' => 'حفظ المفتاح',
			'ai.apiKey.saved' => 'تم حفظ مفتاح API',
			'ai.apiKey.remove' => 'إزالة المفتاح',
			'ai.apiKey.removed' => 'تمت إزالة مفتاح API',
			'ai.apiKey.removeConfirmTitle' => 'إزالة مفتاح API؟',
			'ai.apiKey.removeConfirmBody' => 'سيتوقف هذا المحرّك عن الردّ حتى تربط حسابًا مرة أخرى. لا يتأثر Evolve AI ولا النماذج المحلية.',
			'ai.apiKey.statusSet' => 'محفوظ',
			'ai.apiKey.statusMissing' => 'غير مُعيَّن',
			'ai.apiKey.saveFailed' => 'تعذّر حفظ المفتاح في سلسلة المفاتيح. حاول مرة أخرى.',
			'ai.apiKey.setupTitle' => 'اربط حساب OpenRouter الخاص بك',
			'ai.apiKey.setupBody' => 'يعمل هذا المحرّك عبر حساب OpenRouter الخاص بك. اربطه لبدء المحادثة — أو انتقل إلى Evolve AI المُضمَّن في Pro.',
			'ai.apiKey.setupAction' => 'ربط الحساب',
			'ai.suggestions.morningBoost' => '🔥 امنحني دفعة للبدء!',
			'ai.suggestions.avoidDistractions' => '🧠 كيف أتجنّب المشتّتات؟',
			'ai.suggestions.lowEnergy' => '⚡ طاقتي تتراجع. ماذا أفعل؟',
			'ai.suggestions.stayFocused' => '💪 امنحني نصيحة واحدة للبقاء مركّزاً',
			'ai.suggestions.prepareTomorrow' => '🛌 كيف أستعد ليوم غدٍ منتج؟',
			'ai.suggestions.disciplineReflection' => '📝 تأمّل في انضباط اليوم',
			'ai.suggestions.analyzeActiveGoals' => '🎯 حلّل أهدافي النشطة',
			'ai.suggestions.planMacroGoals' => '🗺️ كيف أخطّط لأهدافي الكبرى؟',
			'ai.suggestions.goalObstacles' => '🛑 ما العقبات التي تعيق أهدافي؟',
			'ai.suggestions.reachMilestones' => '📈 امنحني نصيحة واحدة لبلوغ مراحل إنجازي',
			'ai.suggestions.consistencyStatus' => '📈 كيف هو مستوى مواظبتي؟',
			'ai.suggestions.weeklyStats' => '📊 إحصاءاتي الأسبوعية',
			'ai.suggestions.planDay' => '🌅 خطّط ليومي',
			'ai.suggestions.raiseBar' => '🚀 كيف أرفع مستوى طموحي؟',
			'ai.suggestions.recoverProcrastination' => '🤕 كيف أتعافى بعد التسويف؟',
			'ai.suggestions.connectHabitsGoals' => '🔗 كيف أربط العادات بالأهداف؟',
			'ai.suggestions.reviewGoalsHabits' => '📊 راجع أهدافي وعاداتي',
			'ai.suggestions.disciplineAdvice' => '🔥 نصيحة عن الانضباط',
			'ai.suggestions.createNewHabit' => '💡 كيف أنشئ عادة جديدة؟',
			'ai.local.notReachable' => ({required Object url}) => '❌ تعذّر الوصول إلى خادم الذكاء الاصطناعي المحلي على ${url}. تأكّد من تشغيل Ollama أو LM Studio.',
			'ai.local.modelMissing' => '⚠️ اختر نموذجًا محليًا أولًا — افتح مُحدِّد النماذج في الأعلى.',
			'ai.local.requestFailed' => ({required Object code}) => '❌ خطأ في النموذج المحلي (الرمز: ${code}).',
			'ai.local.streamError' => '❌ فشل الاتصال بالنموذج المحلي.',
			'ai.local.timeout' => '❌ النموذج المحلي يستغرق وقتًا طويلًا — قد يكون ما زال قيد التحميل. حاول مرة أخرى.',
			'ai.local.modelNotFound' => '❌ هذا النموذج غير متوفر على الخادم. افتح مُحدِّد النماذج لاختيار نموذج أو تحميله.',
			'ai.standard.sessionExpired' => '⚠️ انتهت صلاحية جلستك. سجّل الدخول مجددًا لمتابعة استخدام Evolve AI.',
			'ai.standard.needsPro' => '⚠️ Evolve AI جزء من Evolve Pro. اشترك من الإعدادات — أو بدّل المحرّك إلى حساب OpenRouter الخاص بك، وهو مجاني.',
			'ai.standard.rateLimited' => '⚠️ لقد بلغت حد الاستخدام العادل لـ Evolve AI في الوقت الحالي. حاول لاحقًا أو بدّل المحرّك إلى حساب OpenRouter الخاص بك.',
			'ai.standard.unavailable' => '❌ Evolve AI غير متاح الآن. المشكلة من جانبنا — حاول مرة أخرى بعد قليل.',
			'aiCoach.greeting' => 'مرحبًا! أنا Evolve AI Coach. أنا هنا لمساعدتك على تحسين بروتوكولك وتحقيق أهدافك. كيف يمكنني مساعدتك اليوم؟',
			'aiCoach.systemPersona' => 'أنت Evolve AI Coach، مساعد افتراضي للانضباط الشخصي.',
			'aiCoach.habitsHeader' => 'العادات النشطة:',
			'aiCoach.noActiveHabits' => 'لا توجد عادات نشطة.',
			'aiCoach.habitLine' => ({required Object title, required Object done, required Object streak}) => '${title} (أُنجزت اليوم: ${done}، السلسلة: ${streak})',
			'aiCoach.goalsHeader' => 'الأهداف:',
			'aiCoach.noActiveGoals' => 'لا توجد أهداف طويلة المدى نشطة.',
			'aiCoach.goalLine' => ({required Object title, required Object due}) => '${title} (الاستحقاق: ${due})',
			'aiCoach.contextTitle' => 'سياق الذكاء الاصطناعي',
			'aiCoach.contextBody' => 'اختر البيانات التي تريد مشاركتها مع مدرّب الذكاء الاصطناعي للحصول على نصائح مخصّصة.',
			'aiCoach.shareHabitsDesc' => 'يشارك عاداتك النشطة والسلاسل وحالة الإنجاز اليوم.',
			'aiCoach.shareGoalsDesc' => 'يشارك أهدافك النشطة طويلة المدى.',
			'aiCoach.saveClose' => 'حفظ وإغلاق',
			'aiCoach.subtitle' => 'حلّل الأنماط مع مدرّب سياقي مبني على بيانات مسارك.',
			'aiCoach.contextButton' => 'السياق',
			'aiCoach.typing' => 'يكتب AI Coach...',
			'aiCoach.inputHint' => 'اطلب النصيحة من مدرّبك...',
			'aiCoach.defaultUserName' => 'المستخدم',
			'aiCoach.userNameLine' => ({required Object userName}) => '- الاسم: ${userName}',
			'aiCoach.activeGoalsCount' => ({required Object count}) => '- الأهداف النشطة: ${count}',
			'aiCoach.completedGoalsCount' => ({required Object count}) => '- الأهداف المكتملة: ${count}',
			'aiCoach.todayCompletion' => ({required Object completed, required Object total}) => '- عادات اليوم: ${completed} مكتملة من أصل ${total}.',
			'aiCoach.newChatTooltip' => 'محادثة جديدة',
			'aiCoach.clearConfirmTitle' => 'بدء محادثة جديدة؟',
			'aiCoach.clearConfirmBody' => 'سيؤدي ذلك إلى مسح المحادثة الحالية — لا يتم حفظها.',
			'aiCoach.clearConfirmCancel' => 'إلغاء',
			'aiCoach.clearConfirmAccept' => 'محادثة جديدة',
			'aiCoach.copyTooltip' => 'نسخ',
			'aiCoach.copiedToast' => 'تم النسخ إلى الحافظة',
			'aiCoach.linkOpenFailed' => 'تعذّر فتح الرابط.',
			'settingsPage.account' => 'الحساب',
			'settingsPage.notifications' => 'الإشعارات',
			'settingsPage.language' => 'اللغة',
			'settingsPage.timeFormat24h' => 'تنسيق 24 ساعة',
			'settingsPage.subscription' => 'الاشتراك',
			'settingsPage.proName' => 'Evolve Pro',
			'settingsPage.planMonthly' => 'شهري',
			'settingsPage.planAnnual' => 'سنوي',
			'settingsPage.restorePurchases' => 'استعادة المشتريات',
			'settingsPage.deletePrivateData' => 'حذف البيانات الخاصة',
			'settingsPage.importInProgress' => 'جاري استيراد البيانات...',
			'settingsPage.passwordsDontMatch' => 'كلمتا المرور غير متطابقتين.',
			'settingsPage.email' => 'البريد الإلكتروني',
			'settingsPage.cancel' => 'إلغاء',
			'settingsPage.confirm' => 'تأكيد',
			'settingsPage.save' => 'حفظ',
			'settingsPage.pageTitle' => 'الإعدادات',
			'settingsPage.pageSubtitle' => 'أدر ملفك الشخصي وسلوك سطح المكتب والخصوصية وخطة Evolve.',
			'settingsPage.profileLabel' => 'الملف الشخصي',
			'settingsPage.profileSubtitle' => 'المعلومات الشخصية وحالة المزامنة',
			'settingsPage.accountAndOnboarding' => 'الحساب والإعداد الأولي',
			'settingsPage.privateMode' => 'الوضع الخاص',
			'settingsPage.sessionUnavailable' => 'الجلسة غير متاحة',
			'settingsPage.dataRepository' => 'مستودع البيانات',
			'settingsPage.encryptedLocalDatabase' => 'قاعدة بيانات محلية مشفرة',
			'settingsPage.supabaseWithEncryptedCache' => 'Supabase مع ذاكرة تخزين مؤقت مشفرة',
			'settingsPage.personalInfo' => 'المعلومات الشخصية',
			'settingsPage.personalInfoDetail' => 'الاسم واللقب والبريد الإلكتروني وتاريخ الميلاد',
			'settingsPage.updateAvatar' => 'تحديث الصورة الرمزية',
			'settingsPage.updateAvatarDetail' => 'اختر صورة محلية للملف الشخصي على سطح المكتب.',
			'settingsPage.reviewInitialConsent' => 'مراجعة الموافقة الأولية',
			'settingsPage.reviewInitialConsentDetail' => 'الشروط والخصوصية والإشعارات وتقارير الأعطال',
			'settingsPage.signOut' => 'تسجيل الخروج من حسابك',
			'settingsPage.signOutDetailActive' => 'إغلاق الجلسة على هذا الجهاز',
			'settingsPage.availableWithActiveSession' => 'متاح مع جلسة Supabase نشطة',
			'settingsPage.goToLogin' => 'الذهاب إلى تسجيل الدخول',
			'settingsPage.goToLoginDetail' => 'علّق الوضع الخاص وسجّل الدخول إلى Supabase.',
			'settingsPage.appearanceTitle' => 'المظهر والتطبيق',
			'settingsPage.appearanceSubtitle' => 'التفضيلات المحلية المكيَّفة لسطح المكتب',
			'settingsPage.appearanceAndVisual' => 'المظهر والعناصر المرئية',
			'settingsPage.darkMode' => 'الوضع الداكن',
			'settingsPage.darkModeDetail' => 'استخدم السمة الداكنة بالأبيض والأسود.',
			'settingsPage.calendarExperienceLanguage' => 'التقويم والتجربة واللغة',
			'settingsPage.accentColor' => 'لون التمييز',
			'settingsPage.accentColorDetail' => 'لوحة ألوان موسّعة مخصّصة لـ Evolve Pro.',
			'settingsPage.defaultCalendarView' => 'عرض التقويم الافتراضي',
			'settingsPage.calendarViewOptions.month' => 'شهر',
			'settingsPage.calendarViewOptions.week' => 'أسبوع',
			'settingsPage.calendarViewOptions.year' => 'سنة',
			'settingsPage.calendarViewOptions.life' => 'الحياة',
			'settingsPage.languageOptions.system' => 'النظام',
			'settingsPage.languageOptions.italian' => 'الإيطالية',
			'settingsPage.languageOptions.english' => 'الإنجليزية',
			'settingsPage.languageOptions.spanish' => 'الإسبانية',
			'settingsPage.languageOptions.german' => 'الألمانية',
			'settingsPage.languageOptions.arabic' => 'العربية',
			'settingsPage.timeFormat24hDetail' => 'استخدم أوقاتاً مثل 20:30 بدلاً من 8:30 مساءً.',
			'settingsPage.hapticFeedback' => 'الاستجابة اللمسية',
			'settingsPage.hapticFeedbackDetail' => 'يحتفظ سطح المكتب بالتفضيل لكنه لا يولّد اهتزازات.',
			'settingsPage.aiAndSystem' => 'AI والنظام',
			'settingsPage.aiSuggestions' => 'اقتراحات AI',
			'settingsPage.aiSuggestionsDetail' => 'تحليل ذكي للعادات',
			'settingsPage.focusMode' => 'وضع التركيز',
			'settingsPage.focusModeDetail' => 'يوقف مؤقتًا جميع التذكيرات والإشعارات.',
			'settingsPage.milestones' => 'مراحل الإنجاز',
			'settingsPage.milestonesDetail' => 'احتفالات عند الوصول إلى مراحل الإنجاز الرئيسية.',
			'settingsPage.deepWorkInsights' => 'رؤى العمل العميق',
			'settingsPage.deepWorkInsightsDetail' => 'تحليل متقدم لجلسات تركيزك.',
			'settingsPage.resetTutorial' => 'إعادة تعيين البرنامج التعليمي',
			'settingsPage.resetTutorialDetail' => 'يعيد فتح الجولات التعريفية للوحة التحكم والأهداف.',
			'settingsPage.notificationsSubtitle' => 'تذكيرات تشغيلية من تطبيق سطح المكتب',
			'settingsPage.operationalReminders' => 'التذكيرات التشغيلية',
			'settingsPage.habitReminders' => 'تذكيرات العادات',
			'settingsPage.habitRemindersDetail' => 'يرسل الموجز الصباحي اليومي.',
			'settingsPage.morningBriefTime' => 'وقت الموجز الصباحي',
			'settingsPage.eveningReview' => 'المراجعة المسائية',
			'settingsPage.eveningReviewDetail' => 'يذكّرك بتلخيص يومك.',
			'settingsPage.eveningReviewTime' => 'وقت المراجعة المسائية',
			'settingsPage.insightsAndReports' => 'الرؤى والتقارير',
			'settingsPage.aiInsights' => 'رؤى AI',
			'settingsPage.aiInsightsDetail' => 'تحليلات ونصائح مخصصة من الذكاء الاصطناعي.',
			'settingsPage.weeklyReports' => 'تقارير أسبوعية',
			'settingsPage.weeklyReportsDetail' => 'ملخص أسبوعي لتقدمك.',
			'settingsPage.requestNotificationPermissions' => 'طلب أذونات الإشعارات',
			'settingsPage.requestNotificationPermissionsDetail' => 'يفتح النافذة الأصلية على المنصة المدعومة.',
			'settingsPage.nativeDeliveryTitle' => 'التسليم الأصلي حسب نظام التشغيل',
			'settingsPage.privacyTitle' => 'الخصوصية والأمان',
			'settingsPage.privacySubtitle' => 'حماية الوصول والموافقات وإدارة البيانات',
			'settingsPage.accessProtection' => 'حماية الوصول',
			'settingsPage.biometricLock' => 'القفل البيومتري',
			'settingsPage.biometricLockDetail' => 'متاح عبر المحول الأصلي على macOS وWindows؛ غير مدعوم على Linux.',
			'settingsPage.changePassword' => 'تغيير كلمة المرور',
			'settingsPage.changePasswordDetail' => 'تحديث بيانات الاعتماد عبر Supabase Auth.',
			'settingsPage.dataAndConsents' => 'البيانات والموافقات',
			'settingsPage.sendCrashReports' => 'إرسال تقارير الأعطال',
			'settingsPage.sendCrashReportsDetail' => 'موافقة منفصلة لـ Sentry.',
			'settingsPage.exportData' => 'تصدير البيانات',
			'settingsPage.exportDataDetail' => 'يشارك تصديراً كاملاً بصيغة JSON للبيانات المتاحة.',
			'settingsPage.importData' => 'استيراد البيانات',
			'settingsPage.importDataDetail' => 'يستعيد نسخة احتياطية (JSON أو ZIP) من Evolve.',
			'settingsPage.systemPermissionsManagement' => 'إدارة أذونات النظام',
			'settingsPage.systemPermissionsManagementDetail' => 'الإشعارات والتقويم والأمان.',
			'settingsPage.deletePrivateDataDetail' => 'يحذف نهائياً قاعدة البيانات المحلية المشفرة.',
			'settingsPage.deleteAccountAndData' => 'حذف الحساب والبيانات',
			'settingsPage.deleteAccountAndDataDetail' => 'عملية لا رجعة فيها محمية بتأكيد.',
			'settingsPage.exportPrivateShareText' => 'بياناتي الخاصة المصدّرة من Evolve',
			'settingsPage.exportShareText' => 'بياناتي المصدّرة من Evolve',
			'settingsPage.exportDoneTitle' => 'اكتمل التصدير',
			'settingsPage.exportDoneClipboard' => 'ملف JSON في الحافظة: لا يدعم Linux مشاركة الملفات.',
			'settingsPage.exportDoneShare' => 'تم إرسال ملف JSON إلى محدد المشاركة.',
			'settingsPage.avatarGateTitle' => 'الصورة الرمزية',
			'settingsPage.avatarPickFailed' => 'فشل اختيار الصورة.',
			'settingsPage.confirmSignOutTitle' => 'تأكيد تسجيل الخروج',
			'settingsPage.confirmSignOutMessage' => 'هل أنت متأكد أنك تريد تسجيل الخروج؟ ستحتاج إلى إعادة إدخال بيانات الاعتماد لتسجيل الدخول مجدداً.',
			'settingsPage.gateProfile' => 'الملف الشخصي',
			'settingsPage.gateLogout' => 'تسجيل الخروج',
			'settingsPage.gateChangePassword' => 'تغيير كلمة المرور',
			'settingsPage.gateRequiresActiveSession' => 'يتطلب جلسة Supabase نشطة.',
			'settingsPage.biometricActivationCancelled' => 'تم إلغاء التفعيل.',
			'settingsPage.notificationPermissionsTitle' => 'أذونات الإشعارات',
			'settingsPage.notificationPermissionsGranted' => 'الأذونات متاحة لهذا النظام.',
			'settingsPage.notificationPermissionsDenied' => 'لم يتم منح الإذن. يمكنك تغييره من إعدادات النظام.',
			'settingsPage.systemPermissionsTitle' => 'أذونات النظام',
			'settingsPage.systemPermissionsOpenFailed' => 'تعذّر فتح الإعدادات.',
			'settingsPage.tutorialResetTitle' => 'تمت إعادة تعيين البرامج التعليمية',
			'settingsPage.tutorialResetMessage' => 'ستظهر الأدلة مجدداً في الأقسام ذات الصلة.',
			'settingsPage.accountDataManagementTitle' => 'إدارة الحساب والبيانات',
			'settingsPage.accountDataManagementContent' => 'اختر ما إذا كنت تريد حذف البيانات مع إبقاء الحساب نشطاً أو حذف الحساب نهائياً.',
			'settingsPage.resetDataAction' => 'إعادة تعيين البيانات',
			'settingsPage.deleteAccountAction' => 'حذف الحساب',
			'settingsPage.confirmResetDataTitle' => 'تأكيد إعادة تعيين البيانات',
			'settingsPage.confirmResetDataMessage' => 'سيتم حذف العادات والأهداف والتفضيلات. سيبقى الحساب نشطاً. لا يمكن التراجع عن هذا الإجراء.',
			'settingsPage.confirmDeleteAccountTitle' => 'تأكيد حذف الحساب',
			'settingsPage.confirmDeleteAccountMessage' => 'سيتم حذف الحساب وجميع البيانات المرتبطة به نهائياً. هذا الإجراء لا رجعة فيه.',
			'settingsPage.resetDataTitle' => 'إعادة تعيين البيانات',
			'settingsPage.resetDataSuccess' => 'تم حذف البيانات بنجاح.',
			'settingsPage.operationFailed' => 'فشلت العملية.',
			'settingsPage.deleteAccountGateTitle' => 'حذف الحساب',
			'settingsPage.accountDeleted' => 'تم حذف الحساب.',
			'settingsPage.importDataGateTitle' => 'استيراد البيانات',
			'settingsPage.importPrivateOnly' => 'ميزة الاستيراد متاحة حالياً في الوضع الخاص (المحلي) فقط.',
			'settingsPage.importSummaryTitle' => 'ملخص الاستيراد',
			'settingsPage.importHabitsCount' => ({required Object count}) => '${count} عادات',
			'settingsPage.importLogsCount' => ({required Object count}) => '${count} تسجيلات دخول (سجل)',
			'settingsPage.importMacroGoalsCount' => ({required Object count}) => '${count} أهداف كبرى',
			'settingsPage.importCategoriesCount' => ({required Object count}) => '${count} فئات',
			'settingsPage.importMoodsCount' => ({required Object count}) => '${count} سجلات المزاج',
			'settingsPage.importReplaceTitle' => 'استبدال البيانات الحالية',
			'settingsPage.importReplaceSubtitle' => 'يحذف نهائياً كل سجل موجود غير مُضمَّن في هذه النسخة الاحتياطية.',
			'settingsPage.importMergeTitle' => 'دمج مع البيانات الحالية',
			'settingsPage.importMergeSubtitle' => 'يدمج مع بياناتك مع الاحتفاظ بأحدث نسخة من كل عنصر.',
			'settingsPage.importReplaceConfirmTitle' => 'استبدال جميع البيانات؟',
			'settingsPage.importReplaceConfirmMessage' => ({required Object count}) => 'سيؤدي هذا إلى حذف بياناتك الحالية نهائيًا (حوالي ${count} سجل) والاحتفاظ فقط بما في هذه النسخة الاحتياطية. لا يمكن التراجع عن ذلك.',
			'settingsPage.importReplaceConfirmButton' => 'حذف واستبدال',
			'settingsPage.importConfirmButton' => 'تأكيد الاستيراد',
			'settingsPage.importSuccess' => 'اكتمل الاستيراد بنجاح!',
			'settingsPage.importError' => ({required Object error}) => 'خطأ أثناء الاستيراد: ${error}',
			'settingsPage.importLockedTitle' => 'إعادة تعيين قاعدة البيانات الخاصة المقفلة؟',
			'settingsPage.importLockedMessage' => 'لا يستطيع هذا الجهاز فتح قاعدة بياناتك الخاصة المحلية — مفتاح التشفير الخاص بها مفقود (يحدث هذا بعد الانتقال إلى جهاز Mac جديد أو تغيير توقيع التطبيق). لا يمكن استرداد البيانات المحلية الحالية، لكن يمكنك إعادة تعيينها واستيراد هذه النسخة الاحتياطية إلى قاعدة بيانات جديدة فارغة. لا يمكن التراجع عن هذا الإجراء.',
			'settingsPage.importLockedResetButton' => 'إعادة التعيين والاستيراد',
			'settingsPage.importPreviewSkipped' => ({required Object count}) => '⚠ سيتم تجاوز ${count} سجلات غير صالحة',
			'settingsPage.importCompletedTitle' => 'اكتمل الاستيراد',
			'settingsPage.importSummaryReplaced' => 'تم استبدال بياناتك بالنسخة الاحتياطية. الملخص:',
			'settingsPage.importSummaryMerged' => 'تم دمج بياناتك مع النسخة الاحتياطية. الملخص:',
			'settingsPage.importSummaryDone' => 'رائع!',
			'settingsPage.importEntityHabits' => 'العادات',
			'settingsPage.importEntityLogs' => 'سجلات العادات',
			'settingsPage.importEntityMacroGoals' => 'الأهداف الكبيرة',
			'settingsPage.importEntityCategories' => 'الفئات',
			'settingsPage.importEntityMoods' => 'سجلات المزاج',
			'settingsPage.importRowReplace' => ({required Object count, required Object label}) => '${count} ${label}',
			'settingsPage.importRowMerge' => ({required Object label, required Object added, required Object updated, required Object unchanged}) => '${label}: ${added} مضافة، ${updated} محدّثة، ${unchanged} دون تغيير',
			'settingsPage.importRowSkipped' => ({required Object count}) => '، ${count} تم تجاوزها',
			'settingsPage.exportDoneSaved' => 'تم حفظ ملف JSON في الموقع المحدد.',
			'settingsPage.proTitle' => 'Evolve Pro',
			'settingsPage.proSubtitle' => 'الخطة واستعادة المشتريات وإدارة الاشتراك',
			'settingsPage.billingAppleTitle' => 'الفوترة عبر Apple',
			'settingsPage.commercialChannelRequired' => 'الشراء غير متاح',
			'settingsPage.billingAppleDetail' => 'يتم شراء اشتراكك وإدارته باستخدام حساب Apple الخاص بك.',
			'settingsPage.billingUnavailableDetail' => 'الاشتراكات غير متاحة مؤقتاً. يرجى المحاولة لاحقاً.',
			'settingsPage.billingPlatformUnsupported' => 'عمليات الشراء داخل التطبيق غير متاحة على هذه المنصة.',
			'settingsPage.bestValue' => 'أفضل قيمة',
			'settingsPage.priceUnavailable' => 'السعر غير متاح',
			'settingsPage.renewalDisclaimer' => 'يتجدّد الاشتراك تلقائياً ما لم يتم إيقاف التجديد التلقائي في إعدادات حساب Apple قبل 24 ساعة على الأقل من نهاية الفترة.',
			'settingsPage.privacyPolicy' => 'سياسة الخصوصية',
			'settingsPage.termsEula' => 'شروط الاستخدام (EULA)',
			'settingsPage.planManagement' => 'إدارة الخطة',
			'settingsPage.activateEvolvePro' => 'تفعيل Evolve Pro',
			'settingsPage.activateEvolveProActive' => 'استحقاق Evolve Pro نشط.',
			'settingsPage.activateEvolveProStart' => 'اشترك باستخدام حساب Apple الخاص بك.',
			'settingsPage.restorePurchasesDetail' => 'يستعيد اشتراكاً سبق أن اشتريته.',
			'settingsPage.manageSubscription' => 'إدارة الاشتراك',
			'settingsPage.manageSubscriptionDetail' => 'يفتح إدارة الاشتراكات لحساب Apple.',
			'settingsPage.notAuthenticated' => 'غير مُصادق عليه',
			'settingsPage.verified' => 'موثّق',
			'settingsPage.privateModeDataProtected' => 'بياناتك محمية ومحفوظة على هذا الجهاز فقط.',
			'settingsPage.profileFallback' => 'الملف الشخصي',
			'settingsPage.fullName' => 'الاسم الكامل',
			'settingsPage.dateOfBirth' => 'تاريخ الميلاد',
			'settingsPage.dateOfBirthHint' => 'سنة-شهر-يوم',
			'settingsPage.currentPassword' => 'كلمة المرور الحالية',
			'settingsPage.newPassword' => 'كلمة المرور الجديدة',
			'settingsPage.confirmNewPassword' => 'تأكيد كلمة المرور الجديدة',
			'settingsPage.updatePassword' => 'تحديث كلمة المرور',
			'settingsPage.enterCurrentPassword' => 'أدخل كلمة المرور الحالية.',
			'settingsPage.newPasswordMinLength' => 'يجب أن تتكون كلمة المرور الجديدة من 8 أحرف على الأقل.',
			'settingsPage.passwordUpdateFailed' => 'فشل التحديث. تحقق من كلمة المرور الحالية.',
			'settingsPage.sectionApplication' => 'التطبيق',
			'settingsPage.sectionPrivacy' => 'الخصوصية',
			'settingsPage.customColor' => 'لون مخصص',
			'settingsPage.applyAction' => 'تطبيق',
			'settingsPage.useAccent' => ({required Object hex}) => 'استخدم التمييز ${hex}',
			'settingsPage.proUpsellTitle' => 'الترقية إلى Evolve Pro',
			'settingsPage.proUpsellSubtitle' => 'افتح جميع الميزات وسرّع نموّك.',
			'settingsPage.proWelcomeTitle' => 'مرحباً بك في Evolve Pro!',
			'settingsPage.proActiveMessage' => 'اشتراكك نشط. مدرّب الذكاء الاصطناعي مُضمَّن — بلا حساب OpenRouter وبلا مفتاح API — إلى جانب إحصاءات الاتجاهات المتقدمة وكل أدوات النمو الشخصي في Evolve.',
			'settingsPage.proStartJourney' => 'ابدأ رحلتك',
			'settingsPage.systemSection' => 'النظام',
			'settingsPage.appLogsTitle' => 'سجلات التطبيق',
			'settingsPage.appLogsDetail' => 'عرض سجلّات التشخيص لهذه الجلسة',
			'consent.onboardingTitle' => 'خصوصيتك تهمّنا',
			'consent.continueButton' => 'متابعة',
			'notifications.actionDone' => 'تم',
			'notifications.actionSkip' => 'تخطّي',
			'notifications.actionSnooze' => 'تأجيل',
			'notifications.morningBrief' => 'موجز الصباح',
			'notifications.eveningReview' => 'المراجعة المسائية',
			'notifications.morningBriefBody' => 'حان وقت تشكيل يومك. راجع أهدافك.',
			'notifications.eveningReviewBody' => 'كيف كان يومك؟ تتبّع تقدّمك وحدّث سجلّك.',
			'privacy.biometricAuthReason' => 'تحقّق من هويتك لتفعيل حماية التطبيق.',
			'privacy.biometricUnlockReason' => 'افتح قفل التطبيق للمتابعة.',
			'consentPage.subtitle' => 'قبل استخدام Evolve Desktop، أكّد الشروط وسياسة الخصوصية ومعالجة البيانات اللازمة للمزامنة.',
			'consentPage.acceptTerms' => 'أوافق على الشروط وسياسة الخصوصية',
			'consentPage.termsSubtitle' => 'أؤكّد أنني قرأت المستندات وأن عمري 14 عامًا على الأقل.',
			'consentPage.crashDiagnostics' => 'تشخيص الأعطال',
			'consentPage.crashSubtitle' => 'اسمح بإرسال تقارير تقنية مجهّلة الهوية.',
			'consentPage.openPrivacy' => 'افتح سياسة الخصوصية',
			'consentPage.openTerms' => 'شروط الخدمة',
			'consentPage.notificationsTitle' => 'تفعيل الإشعارات',
			'consentPage.notificationsSubtitle' => 'احصل على تذكيرات العادات والملخصات اليومية.',
			'consentPage.enableNotifications' => 'تفعيل',
			'consentPage.notificationsEnabled' => 'مُفعّلة',
			'notif.macScheduling' => 'الجدولة اليومية مفعّلة على macOS.',
			'notif.linuxImmediate' => 'يعرض Linux إشعارات فورية لكنه لا يدعم الجدولة.',
			'notif.openEvolve' => 'افتح Evolve',
			'notif.windowsScheduling' => 'يجدول Windows الحدث التالي عند كل تشغيل.',
			'notif.morningBody' => 'راجع عادات اليوم واختر من أين تبدأ.',
			'notif.habitReminderBody' => 'حان وقت إتمام عادتك.',
			'notif.eveningBody' => 'اختم يومك وحدّث تقدّمك.',
			'biometricGate.appLocked' => 'التطبيق مقفل',
			'biometricGate.unlockPrompt' => 'افتح القفل بالمصادقة المحلية للمتابعة.',
			'biometricGate.verifying' => 'جارٍ التحقق...',
			'biometricGate.unlock' => 'فتح القفل',
			'biometricGate.notSupportedLinux' => 'القفل البيومتري غير مدعوم على Linux.',
			'biometricGate.noLocalAuth' => 'لا تتوفر طريقة مصادقة محلية.',
			'biometricGate.authFailed' => 'فشلت المصادقة.',
			'biometricGate.authUnavailable' => 'المصادقة المحلية غير متاحة.',
			'sync.syncFailed' => 'فشلت المزامنة. تم الاحتفاظ بالبيانات المحلية.',
			'sync.editSavedLocally' => 'تم حفظ التعديل محليًا. ستتم إعادة محاولة المزامنة.',
			'subscriptionCtrl.purchaseComplete' => 'اكتمل الشراء: جارٍ مزامنة الاشتراك.',
			'subscriptionCtrl.purchaseIncomplete' => 'لم يكتمل الشراء.',
			'subscriptionCtrl.cantOpenApple' => 'تعذّر فتح إدارة اشتراكات Apple.',
			'subscriptionCtrl.macOnly' => 'تتوفر عمليات الشراء داخل التطبيق في تطبيق macOS.',
			'subscriptionCtrl.loadOffersFailed' => 'تعذّر تحميل عروض RevenueCat.',
			'subscriptionCtrl.proActivated' => 'تم تفعيل Evolve Pro.',
			'subscriptionCtrl.purchasesRestored' => 'تمت استعادة المشتريات.',
			'subscriptionCtrl.noActiveSub' => 'لم يُعثر على اشتراك Pro نشط.',
			'subscriptionCtrl.restoreFailed' => 'فشلت استعادة المشتريات.',
			'subscriptionCtrl.configKey' => 'اضبط مفتاح RevenueCat العام لتطبيق سطح المكتب.',
			'subscriptionCtrl.loginFirst' => 'سجّل الدخول قبل إدارة Evolve Pro.',
			'authCtrl.appleNoToken' => 'لم يُرجع Apple رمز هوية.',
			'authCtrl.appleAuthFailed' => 'فشلت مصادقة Apple.',
			'authCtrl.cantOpenBrowser' => 'تعذّر فتح متصفح النظام.',
			'authCtrl.accessNotCompleted' => ({required Object provider}) => 'لم يكتمل تسجيل الدخول عبر ${provider}.',
			'authCtrl.providerAuthFailed' => ({required Object provider}) => 'فشلت مصادقة ${provider}.',
			'authCtrl.operationFailed' => 'فشلت العملية. أعد المحاولة بعد قليل.',
			'proModal.title' => 'افتح Evolve Pro',
			'proModal.subtitle' => 'ارتقِ بنظام عاداتك إلى المستوى التالي',
			'proModal.featuresHeader' => 'ما الذي تتضمّنه خطة PRO',
			'proModal.aiCoachTitle' => 'AI Coach بلا إعداد',
			'proModal.aiCoachDesc' => 'نشغّله نحن بمفتاحنا: لا مفتاح API تبحث عنه، ولا حساب ثانٍ. تفضّل حساب OpenRouter الخاص بك؟ هذا مجاني أيضًا.',
			'proModal.statsTitle' => 'إحصاءات خاصة بكل عادة',
			'proModal.statsDesc' => 'رؤى أساسية لتعزيز إنتاجيتك.',
			'proModal.metricsTitle' => 'مقاييس متقدّمة للأهداف',
			'proModal.metricsDesc' => 'اعرض رسوماً بيانية مفصّلة وإحصاءات أداء معمّقة لكل سنة.',
			'proModal.unlimitedTitle' => 'عادات غير محدودة',
			'proModal.unlimitedDesc' => 'أنشئ وتتبّع كل العادات التي تريدها دون أي حدود.',
			'proModal.maybeLater' => 'ربما لاحقاً',
			'proModal.viewPlans' => 'عرض خطط Pro',
			'appLogs.title' => 'سجلات التطبيق',
			'appLogs.copiedToClipboard' => 'تم نسخ السجلات إلى الحافظة',
			'appLogs.clearLogsTitle' => 'مسح السجلات',
			'appLogs.clearLogsConfirm' => 'هل أنت متأكد من رغبتك في مسح جميع إدخالات السجل؟ لا يمكن التراجع عن هذا الإجراء.',
			'appLogs.clearLogsAction' => 'مسح الكل',
			'appLogs.copyAll' => 'نسخ جميع السجلات',
			'appLogs.searchPlaceholder' => 'البحث في السجلات...',
			'appLogs.filterAll' => 'الكل',
			'appLogs.filterErrors' => 'أخطاء',
			'appLogs.filterWarnings' => 'تحذيرات',
			'appLogs.filterInfo' => 'معلومات',
			'appLogs.emptyTitle' => 'لا توجد سجلات',
			'appLogs.emptySubtitle' => 'ستظهر السجلات هنا أثناء تشغيل التطبيق',
			'appLogs.stackTraceAvailable' => 'انقر لعرض تتبع المكدس',
			'appLogs.detailMessage' => 'الرسالة',
			'appLogs.detailError' => 'الخطأ',
			'appLogs.detailExtras' => 'سياق إضافي',
			'appLogs.detailStackTrace' => 'تتبع المكدس',
			'appLogs.shareLogs' => 'مشاركة ملف السجلات',
			'appLogs.exportDone' => 'تم تصدير السجلات',
			'coachSettings.title' => 'محرّك مدرّب الذكاء الاصطناعي',
			'coachSettings.subtitle' => 'اختر مكان تشغيل المدرّب. تُبقي النماذج المحلية كل رسالة على هذا الجهاز.',
			'coachSettings.backendCloud' => 'OpenRouter الخاص بك',
			'coachSettings.backendLocal' => 'محلي · خاص',
			'coachSettings.cloudDesc' => 'اربط حساب OpenRouter الخاص بك وادفع للمزوّد مباشرةً. مجاني — لا يتطلب اشتراكًا. يُرسَل السياق الذي تشاركه إلى المزوّد.',
			'coachSettings.localDesc' => 'نموذجك الخاص عبر Ollama أو LM Studio أو أي خادم متوافق مع OpenAI. لا شيء يغادر هذا الجهاز.',
			'coachSettings.presetLabel' => 'الخادم',
			'coachSettings.presetOllama' => 'Ollama',
			'coachSettings.presetLmStudio' => 'LM Studio',
			'coachSettings.presetCustom' => 'مخصّص…',
			'coachSettings.baseUrlLabel' => 'عنوان URL الأساسي',
			'coachSettings.baseUrlHint' => 'http://localhost:11434/v1',
			'coachSettings.modelLabel' => 'النموذج',
			'coachSettings.modelHint' => 'مثال: llama3.1:8b',
			'coachSettings.refreshModels' => 'تحديث النماذج',
			'coachSettings.discovering' => 'جارٍ البحث عن النماذج…',
			'coachSettings.noModelsFound' => 'لم يُعثَر على نماذج — اكتب معرّف نموذج يدويًا أدناه.',
			'coachSettings.manualModelLabel' => 'معرّف النموذج',
			'coachSettings.manualModelAdd' => 'استخدام هذا النموذج',
			'coachSettings.statusConnected' => 'متّصل',
			'coachSettings.statusOffline' => 'الخادم غير متّصل',
			'coachSettings.statusChecking' => 'جارٍ التحقّق…',
			'coachSettings.remoteBadge' => 'بعيد',
			'coachSettings.remoteWarning' => 'هذا الـ endpoint ليس عنوانًا محليًا — ستغادر الرسائل هذا الجهاز.',
			'coachSettings.advanced' => 'متقدّم',
			'coachSettings.systemPromptLabel' => 'موجّه النظام',
			'coachSettings.systemPromptHint' => 'استبدل شخصية المدرّب (اتركه فارغًا للوضع الافتراضي)',
			'coachSettings.systemPromptReset' => 'إعادة تعيين',
			'coachSettings.temperatureLabel' => 'درجة الحرارة',
			'coachSettings.save' => 'تم',
			'coachSettings.detectedTitle' => 'تم اكتشاف نموذج محلي',
			'coachSettings.detectedBody' => 'يعمل خادم ذكاء اصطناعي محلي على هذا الـ Mac. هل تريد تشغيل المدرّب بخصوصية كاملة؟',
			'coachSettings.detectedAction' => 'استخدام المحلي',
			'coachSettings.detectedDismiss' => 'ليس الآن',
			'coachSettings.activeCloud' => ({required Object model}) => 'السحابة · ${model}',
			'coachSettings.activeLocal' => ({required Object model}) => 'محلي · ${model}',
			'coachSettings.activeLocalNoModel' => 'محلي · اختر نموذجًا',
			'coachSettings.cloudSection' => 'OpenRouter الخاص بك',
			'coachSettings.serverSettings' => 'إعدادات الخادم…',
			'coachSettings.settingsSectionLabel' => 'مدرّب الذكاء الاصطناعي',
			'coachSettings.settingsTitle' => 'مدرّب الذكاء الاصطناعي',
			_ => null,
		} ?? switch (path) {
			'coachSettings.settingsSubtitle' => 'اختر المحرّك الذي يشغّل مدرّبك ووجّهه إلى خادم محلي لخصوصية كاملة.',
			'coachSettings.settingsRowStatus' => 'المحرّك النشط',
			'coachSettings.settingsRowConfigure' => 'المحرّك والخادم المحلي',
			'coachSettings.cloudKeyMissing' => 'لا يوجد مفتاح بعد — لن يردّ هذا المحرّك. اربط حساب OpenRouter الخاص بك أدناه، أو انتقل إلى Evolve AI، أو استخدم خادمًا محليًا.',
			'coachSettings.temperatureLower' => 'خفض درجة الحرارة',
			'coachSettings.temperatureRaise' => 'رفع درجة الحرارة',
			'coachSettings.sendMessage' => 'إرسال',
			'coachSettings.stopResponse' => 'إيقاف',
			'coachSettings.startOllama' => 'تشغيل Ollama',
			'coachSettings.getOllama' => 'الحصول على Ollama',
			'coachSettings.startingOllama' => 'جارٍ تشغيل Ollama…',
			'coachSettings.ollamaOfflineTitle' => 'Ollama غير مُشغّل',
			'coachSettings.ollamaOfflineBody' => 'شغّل خادمك المحلي للدردشة بخصوصية — دون الحاجة إلى الطرفية.',
			'coachSettings.ollamaNotInstalledTitle' => 'Ollama غير مُثبَّت',
			'coachSettings.ollamaNotInstalledBody' => 'ثبّت تطبيق Ollama المجاني ثم اضغط تشغيل.',
			'coachSettings.ollamaStartTimeout' => 'يستغرق وقتًا أطول من المتوقع — تحقّق من أيقونة Ollama في شريط القوائم (قد يتطلب التشغيل الأول موافقة).',
			'coachSettings.ollamaStartingBody' => 'قد يستغرق ذلك بضع ثوانٍ…',
			'coachSettings.ollamaStartFailed' => 'تعذّر تشغيل Ollama — جرّب فتحه من مجلد التطبيقات.',
			'coachSettings.ollamaDownloadFailed' => 'تعذّر فتح المتصفح — تفضّل بزيارة ollama.com/download',
			'coachSettings.backendStandard' => 'Evolve AI',
			'coachSettings.standardDesc' => 'مُضمَّن في Evolve Pro. نشغّل Gemini 2.5 Flash نيابةً عنك — بلا مفاتيح وبلا إعداد. يُرسَل السياق الذي تشاركه إلى المزوّد.',
			'coachSettings.activeStandard' => ({required Object model}) => 'Evolve AI · ${model}',
			'coachSettings.standardSection' => 'Evolve AI',
			'coachSettings.standardStatusReady' => 'مُضمَّن في Pro',
			'coachSettings.standardStatusNeedsPro' => 'يتطلب Pro',
			'coachSettings.standardStatusNeedsSignIn' => 'يلزم تسجيل الدخول',
			'coachSettings.standardStatusUnavailable' => 'غير متاح',
			'coachSettings.standardNeedsProNote' => 'Evolve AI جزء من Evolve Pro. اشترك لاستخدامه — أو اربط حساب OpenRouter الخاص بك، وهو مجاني.',
			'coachSettings.standardNeedsSignInNote' => 'سجّل الدخول لاستخدام Evolve AI. اشتراكك يفتحه على كل أجهزتك.',
			'coachSettings.standardUnavailableNote' => 'Evolve AI غير متاح في هذه النسخة. اربط حساب OpenRouter الخاص بك أو استخدم نموذجًا محليًا.',
			'coachSettings.standardPrivateNote' => 'يحتاج Evolve AI إلى حساب Evolve، والوضع الخاص لا يحتفظ بحساب. اربط حساب OpenRouter الخاص بك أو استخدم نموذجًا محليًا — كلاهما يعمل هنا.',
			'tour.back' => 'رجوع',
			'tour.next' => 'التالي',
			'tour.continueLabel' => 'متابعة',
			'tour.finish' => 'إنهاء',
			'tour.welcomeTitle' => 'مرحبًا بك في Evolve',
			'tour.welcomeBody' => 'لنقم بجولة سريعة في مساحة عملك — من نظرتك اليومية العامة وصولًا إلى مدرّب الذكاء الاصطناعي. لن يستغرق الأمر سوى لحظات.',
			'tour.welcomeStart' => 'ابدأ الجولة',
			'tour.doneTitle' => 'كل شيء جاهز',
			'tour.doneBody' => 'هذا كل التطبيق. ابدأ من أي مكان عبر الشريط الجانبي — ويمكنك إعادة الجولة في أي وقت من الإعدادات.',
			'tour.doneButton' => 'ابدأ الآن',
			'tour.overviewOrientationTitle' => 'نظرتك العامة',
			'tour.overviewOrientationDesc' => 'هذه قاعدتك اليومية — لمحة عن يومك بمجرد فتح Evolve.',
			'tour.overviewCheckinTitle' => 'تسجيل الوصول اليومي',
			'tour.overviewCheckinDesc' => 'سجّل كيف يسير يومك. مع الوقت يكشف كيف ترتبط حالتك المزاجية بعاداتك وأهدافك.',
			'tour.overviewHabitsTitle' => 'عادات اليوم',
			'tour.overviewHabitsDesc' => 'العادات التي خططت لها اليوم موجودة هنا — علّمها عند إنجازها.',
			'tour.overviewGoalsTitle' => 'الأهداف قيد التركيز',
			'tour.overviewGoalsDesc' => 'تظهر هنا الأهداف التي تركّز عليها حتى لا يفوتك شيء.',
			'tour.habitsOrientationTitle' => 'صفحة العادات',
			'tour.habitsOrientationDesc' => 'هنا تبني بروتوكولك اليومي وتتابع مدى انتظامك.',
			'tour.habitsAddTitle' => 'أضف عادة',
			'tour.habitsAddDesc' => 'أنشئ عادة جديدة هنا — بالاسم والفئة واللون وتذكير اختياري.',
			'tour.habitsCheckoffTitle' => 'علّمها كمنجزة',
			'tour.habitsCheckoffDesc' => 'علّم هذا المربع لإكمال عادة اليوم. هذا كل ما يلزم للحفاظ على السلسلة.',
			'tour.habitsStreakTitle' => 'السلاسل والسجل',
			'tour.habitsStreakDesc' => 'شاهد سلسلتك تنمو وألقِ نظرة على آخر سبعة أيام دفعة واحدة.',
			'tour.habitsCalendarTitle' => 'عرض التقويم',
			'tour.habitsCalendarDesc' => 'انتقل إلى التقويم لمراجعة سجلك حسب الأسبوع أو الشهر أو السنة — أو حياتك كلها.',
			'tour.insightsOrientationTitle' => 'إحصاءاتك',
			'tour.insightsOrientationDesc' => 'تابع اتجاه عاداتك وأهدافك عبر الزمن وأين تنحرف.',
			'tour.insightsFilterTitle' => 'التصفية حسب العادة',
			'tour.insightsFilterDesc' => 'ركّز الإحصاءات على عادة واحدة أو أبقِ النظرة الشاملة.',
			'tour.insightsTabsTitle' => 'أقسام الإحصاءات',
			'tour.insightsTabsDesc' => 'بدّل بين الأقسام للاتجاهات والتنبيهات وتقدّم العادات ومزاجك.',
			'tour.goalsOrientationTitle' => 'صفحة الأهداف',
			'tour.goalsOrientationDesc' => 'حدّد وتابع أهدافك الأكبر — ما تبني نحوه عاداتك اليومية.',
			'tour.goalsPlanTitle' => 'نوع التخطيط',
			'tour.goalsPlanDesc' => 'اختر كيف تخطّط — يوميًا أو أسبوعيًا أو لمدى أطول — بما يناسب طريقة تفكيرك في أهدافك.',
			'tour.goalsAddTitle' => 'أضف هدفًا',
			'tour.goalsAddDesc' => 'أنشئ هدفًا جديدًا هنا وامنحه غاية تسعى إليها.',
			'tour.goalsCheckTitle' => 'إنجاز أو إخفاق',
			'tour.goalsCheckDesc' => 'علّم الهدف كمنجز أو فائت. كل نتيجة تغذّي أداءك مع الوقت.',
			'tour.goalsStatsTitle' => 'الأداء',
			'tour.goalsStatsDesc' => 'فعّل إحصاءات الأداء لترى مستواك مقابل أهدافك.',
			'tour.coachOrientationTitle' => 'مدرّبك بالذكاء الاصطناعي',
			'tour.coachOrientationDesc' => 'إرشاد مخصّص مبني على عاداتك وأهدافك الحقيقية — هنا على جهاز Mac الخاص بك.',
			'tour.coachModelTitle' => 'اختر المحرّك',
			'tour.coachModelDesc' => 'اختر نموذج الذكاء الاصطناعي — سحابتنا أو نموذج محلي يعمل بخصوصية على جهاز Mac. إعدادات الخادم هنا أيضًا.',
			'tour.coachContextTitle' => 'ما يراه المدرّب',
			'tour.coachContextDesc' => 'تحكّم في ما إذا كان بإمكان المدرّب استخدام عاداتك وأهدافك لتخصيص نصائحه.',
			'tour.coachSuggestionsTitle' => 'مقترحات للبدء',
			'tour.coachSuggestionsDesc' => 'لا تعرف من أين تبدأ؟ اضغط أحد هذه الاقتراحات للانطلاق.',
			'tour.coachInputTitle' => 'اسأل أي شيء',
			'tour.coachInputDesc' => 'اكتب سؤالك هنا واضغط إرسال. بهذا تنتهي الجولة — استمتع بـ Evolve!',
			'palette.searchHint' => 'ابحث عن الأهداف والعادات والإجراءات…',
			'palette.groupSuggested' => 'مقترحات',
			'palette.groupThisWeek' => 'هذا الأسبوع',
			'palette.groupGoals' => 'الأهداف',
			'palette.groupHabits' => 'العادات',
			'palette.groupActions' => 'إجراءات',
			'palette.groupSections' => 'الانتقال إلى',
			'palette.goToThisWeek' => 'الانتقال إلى هذا الأسبوع',
			'palette.createGoalBlank' => 'إنشاء هدف',
			'palette.createGoal' => ({required Object title}) => 'إنشاء هدف «${title}»',
			'palette.createHabit' => ({required Object title}) => 'إنشاء عادة «${title}»',
			'palette.goToPeriod' => ({required Object period}) => 'الانتقال إلى ${period}',
			'palette.switchToDark' => 'التبديل إلى المظهر الداكن',
			'palette.switchToLight' => 'التبديل إلى المظهر الفاتح',
			'palette.manageCategories' => 'إدارة فئات الأهداف',
			'palette.replayTour' => 'إعادة الجولة التعريفية',
			'palette.noResults' => ({required Object query}) => 'لا نتائج لـ «${query}»',
			'palette.rowOpen' => 'فتح',
			'palette.rowComplete' => 'وضع علامة مكتمل',
			'palette.rowReschedule' => 'إعادة الجدولة للفترة التالية',
			'palette.deleteGoalTitle' => 'حذف الهدف؟',
			'palette.deleteGoalMessage' => ({required Object title}) => 'سيتم حذف «${title}» نهائيًا.',
			'palette.deleteHabitTitle' => 'حذف العادة؟',
			'palette.deleteHabitMessage' => ({required Object title}) => 'سيتم حذف «${title}» نهائيًا.',
			'palette.footerNavigate' => 'تنقل',
			'palette.footerOpen' => 'فتح',
			'palette.footerMenu' => 'قائمة',
			'palette.footerClose' => 'إغلاق',
			_ => null,
		};
	}
}
