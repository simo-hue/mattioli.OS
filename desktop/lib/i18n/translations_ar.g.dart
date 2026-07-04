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
	@override late final _Translations$namePrompt$ar namePrompt = _Translations$namePrompt$ar._(_root);
}

// Path: auth
class _Translations$auth$ar extends Translations$auth$en {
	_Translations$auth$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get continuePrivately => 'المتابعة في الوضع الخاص على هذا الـ Mac';
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

/// The flat map containing all translations for locale <ar>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsAr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'auth.continuePrivately' => 'المتابعة في الوضع الخاص على هذا الـ Mac',
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
			'namePrompt.title' => 'ما اسمك؟',
			'namePrompt.subtitle' => 'أدخل اسمك لتخصيص لوحة المعلومات.',
			'namePrompt.hint' => 'مثال: Simo',
			'namePrompt.save' => 'حفظ ومتابعة',
			_ => null,
		};
	}
}
