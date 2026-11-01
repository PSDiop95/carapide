class_name SaveService
extends RefCounted
## Interface de sauvegarde clé/valeur. Implémentation par défaut : mémoire.

var _values: Dictionary = {}


func get_int(key: String, default_value: int) -> int:
	var raw: float = _values.get(key, default_value)
	return int(raw)


func set_int(key: String, value: int) -> void:
	_values[key] = value
