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
	@override late final _Translations$auth$de auth = _Translations$auth$de._(_root);
	@override late final _Translations$privateAi$de privateAi = _Translations$privateAi$de._(_root);
	@override late final _Translations$privateData$de privateData = _Translations$privateData$de._(_root);
	@override late final _Translations$namePrompt$de namePrompt = _Translations$namePrompt$de._(_root);
}

// Path: auth
class _Translations$auth$de extends Translations$auth$en {
	_Translations$auth$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get continuePrivately => 'Privat auf diesem Mac fortfahren';
}

// Path: privateAi
class _Translations$privateAi$de extends Translations$privateAi$en {
	_Translations$privateAi$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get consentTitle => 'Senden an die KI erlauben';
	@override String get consentBody => 'Im privaten Modus bleiben deine Daten auf deinem Gerät. Um den KI-Coach zu nutzen, werden die Gewohnheiten und Ziele, die du teilst, an einen externen KI-Anbieter (OpenRouter) gesendet. Möchtest du fortfahren?';
	@override String get cancel => 'Abbrechen';
	@override String get accept => 'Akzeptieren';
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

/// The flat map containing all translations for locale <de>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsDe {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'auth.continuePrivately' => 'Privat auf diesem Mac fortfahren',
			'privateAi.consentTitle' => 'Senden an die KI erlauben',
			'privateAi.consentBody' => 'Im privaten Modus bleiben deine Daten auf deinem Gerät. Um den KI-Coach zu nutzen, werden die Gewohnheiten und Ziele, die du teilst, an einen externen KI-Anbieter (OpenRouter) gesendet. Möchtest du fortfahren?',
			'privateAi.cancel' => 'Abbrechen',
			'privateAi.accept' => 'Akzeptieren',
			'privateData.deleteTitle' => 'Private Daten löschen',
			'privateData.deleteMessage' => 'Möchtest du wirklich die gesamte verschlüsselte lokale Datenbank löschen? Dieser Vorgang ist unwiderruflich und die Daten können nicht wiederhergestellt werden.',
			'privateData.deleteSuccess' => 'Private Daten gelöscht.',
			'privateData.deleteFailed' => 'Vorgang fehlgeschlagen.',
			'privateData.exportDoneTitle' => 'Export abgeschlossen',
			'privateData.exportDoneClipboard' => 'Das JSON ist in der Zwischenablage: Linux unterstützt keine Dateifreigabe.',
			'privateData.exportDoneShare' => 'Das JSON wurde an die Teilen-Auswahl gesendet.',
			'namePrompt.title' => 'Wie heißt du?',
			'namePrompt.subtitle' => 'Gib deinen Namen ein, um das Dashboard zu personalisieren.',
			'namePrompt.hint' => 'z. B. Simo',
			'namePrompt.save' => 'Speichern und fortfahren',
			_ => null,
		};
	}
}
