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
}

// Path: auth
class _Translations$auth$es extends Translations$auth$en {
	_Translations$auth$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get continuePrivately => 'Continúa en modo privado en este Mac';
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

/// The flat map containing all translations for locale <es>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEs {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'auth.continuePrivately' => 'Continúa en modo privado en este Mac',
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
			_ => null,
		};
	}
}
