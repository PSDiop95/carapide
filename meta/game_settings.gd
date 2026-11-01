class_name GameSettings
extends RefCounted
## Réglages sauvegardés. Le jeu n'a pas encore de son : musique et effets sont seulement mémorisés.

const MUSIC_KEY: String = "setting_music"
const EFFECTS_KEY: String = "setting_effects"
const VIBRATIONS_KEY: String = "setting_vibrations"
const ON: int = 1
const OFF: int = 0


static func is_enabled(save: SaveService, key: String) -> bool:
	return save.get_int(key, ON) == ON


## Ordre des paramètres imposé par `toggled.connect(...bind(save, key))`.
static func set_enabled(enabled: bool, save: SaveService, key: String) -> void:
	save.set_int(key, ON if enabled else OFF)
	if key == VIBRATIONS_KEY:
		apply_vibrations(save)


## Le service décide : le jeu continue d'appeler vibrate() sans connaître le réglage.
static func apply_vibrations(save: SaveService) -> void:
	var service: HapticsService = (Engine.get_main_loop() as SceneTree).root.get_node("Services").get("haptics")
	service.enabled = is_enabled(save, VIBRATIONS_KEY)
