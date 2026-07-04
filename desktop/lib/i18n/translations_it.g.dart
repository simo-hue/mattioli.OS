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
	@override late final _Translations$namePrompt$it namePrompt = _Translations$namePrompt$it._(_root);
}

// Path: auth
class _Translations$auth$it extends Translations$auth$en {
	_Translations$auth$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get continuePrivately => 'Continua in modalità privata su questo Mac';
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

/// The flat map containing all translations for locale <it>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsIt {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'auth.continuePrivately' => 'Continua in modalità privata su questo Mac',
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
			'namePrompt.title' => 'Come ti chiami?',
			'namePrompt.subtitle' => 'Inserisci il tuo nome per personalizzare la dashboard.',
			'namePrompt.hint' => 'Es. Simo',
			'namePrompt.save' => 'Salva e continua',
			_ => null,
		};
	}
}
