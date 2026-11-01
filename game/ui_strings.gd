class_name UiStrings
extends RefCounted
## Enregistre les textes pour `tr()`. La localisation elle-même reste hors scope.

const PATH: String = "res://data/config/strings_fr.json"
const LOCALE: String = "fr"


static func register() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_error("Textes illisibles : %s" % PATH)
		return
	var strings: Dictionary = parsed
	var translation: Translation = Translation.new()
	translation.locale = LOCALE
	for key: String in strings:
		var text: String = strings[key]
		translation.add_message(key, text)
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale(LOCALE)
