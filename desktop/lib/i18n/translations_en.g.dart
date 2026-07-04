///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'translations.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$auth$en auth = Translations$auth$en.internal(_root);
	late final Translations$privateAi$en privateAi = Translations$privateAi$en.internal(_root);
	late final Translations$privateData$en privateData = Translations$privateData$en.internal(_root);
	late final Translations$namePrompt$en namePrompt = Translations$namePrompt$en.internal(_root);
}

// Path: auth
class Translations$auth$en {
	Translations$auth$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Continue privately on this Mac'
	String get continuePrivately => 'Continue privately on this Mac';
}

// Path: privateAi
class Translations$privateAi$en {
	Translations$privateAi$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Allow sending to the AI'
	String get consentTitle => 'Allow sending to the AI';

	/// en: 'In Private mode your data stays on your device. To use the AI Coach, the habits and goals you choose to share are sent to an external AI provider (OpenRouter). Do you want to proceed?'
	String get consentBody => 'In Private mode your data stays on your device. To use the AI Coach, the habits and goals you choose to share are sent to an external AI provider (OpenRouter). Do you want to proceed?';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Accept'
	String get accept => 'Accept';
}

// Path: privateData
class Translations$privateData$en {
	Translations$privateData$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Delete private data'
	String get deleteTitle => 'Delete private data';

	/// en: 'Are you sure you want to delete the entire encrypted local database? This action is irreversible and the data cannot be recovered.'
	String get deleteMessage => 'Are you sure you want to delete the entire encrypted local database? This action is irreversible and the data cannot be recovered.';

	/// en: 'Private data deleted.'
	String get deleteSuccess => 'Private data deleted.';

	/// en: 'Operation failed.'
	String get deleteFailed => 'Operation failed.';

	/// en: 'Export complete'
	String get exportDoneTitle => 'Export complete';

	/// en: 'The JSON is on the clipboard: Linux does not support file sharing.'
	String get exportDoneClipboard => 'The JSON is on the clipboard: Linux does not support file sharing.';

	/// en: 'The JSON was sent to the share sheet.'
	String get exportDoneShare => 'The JSON was sent to the share sheet.';
}

// Path: namePrompt
class Translations$namePrompt$en {
	Translations$namePrompt$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'What is your name?'
	String get title => 'What is your name?';

	/// en: 'Enter your name to personalize the dashboard.'
	String get subtitle => 'Enter your name to personalize the dashboard.';

	/// en: 'e.g. Simo'
	String get hint => 'e.g. Simo';

	/// en: 'Save and continue'
	String get save => 'Save and continue';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'auth.continuePrivately' => 'Continue privately on this Mac',
			'privateAi.consentTitle' => 'Allow sending to the AI',
			'privateAi.consentBody' => 'In Private mode your data stays on your device. To use the AI Coach, the habits and goals you choose to share are sent to an external AI provider (OpenRouter). Do you want to proceed?',
			'privateAi.cancel' => 'Cancel',
			'privateAi.accept' => 'Accept',
			'privateData.deleteTitle' => 'Delete private data',
			'privateData.deleteMessage' => 'Are you sure you want to delete the entire encrypted local database? This action is irreversible and the data cannot be recovered.',
			'privateData.deleteSuccess' => 'Private data deleted.',
			'privateData.deleteFailed' => 'Operation failed.',
			'privateData.exportDoneTitle' => 'Export complete',
			'privateData.exportDoneClipboard' => 'The JSON is on the clipboard: Linux does not support file sharing.',
			'privateData.exportDoneShare' => 'The JSON was sent to the share sheet.',
			'namePrompt.title' => 'What is your name?',
			'namePrompt.subtitle' => 'Enter your name to personalize the dashboard.',
			'namePrompt.hint' => 'e.g. Simo',
			'namePrompt.save' => 'Save and continue',
			_ => null,
		};
	}
}
